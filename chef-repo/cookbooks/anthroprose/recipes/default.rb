config = data_bag_item(node['databag'], config)

node['mysql']['server']['server_root_password'] = config["mysql_root_password"]
node['mysql']['server']['server_debian_password'] = config["mysql_root_password"]
node['mysql']['server']['server_repl_password'] = config["mysql_root_password"]
node['wordpress']['db']['password'] = config["mysql_root_password"]
node['wordpress']['keys']['auth'] = config["wordpress_keys_hash"]
node['wordpress']['keys']['secure_auth'] = config["wordpress_keys_hash"]
node['wordpress']['keys']['logged_in'] = config["wordpress_keys_hash"]
node['wordpress']['keys']['nonce'] = config["wordpress_keys_hash"]


Array(node['dependencies']).each do |p|
  package p do
    action :install
  end
end

php_pear_channel "pear.phpunit.de" do
   action :discover
end

php_pear_channel "pear.symfony.com" do
   action :discover
end


############### Horde

hc = php_pear_channel "pear.horde.org" do
   action :discover
end

directory "#{node['horde']['directory']}" do
  owner "www-data"
  group "www-data"
  mode "0775"
  action :create
  recursive true
end

script "pear_horde_role" do
  interpreter "bash"
  timeout 3600
  user "root"
  group "root"
  code <<-EOH
	pear install horde/horde_role
	echo "#{node['horde']['directory']}"|pear run-scripts horde/Horde_Role
  EOH
end

php_pear "webmail" do
   channel hc.channel_name
   preferred_state "stable"
   action :install
end

service "uwsgi" do
  supports :status => true, :restart => true, :reload => true
  action [ :enable, :start ]
end

script "create_databases" do
  interpreter "bash"
  timeout 3600
  user "root"
  group "root"
  code <<-EOH
    /usr/bin/mysql -u root -p\"#{node['mysql']['server_root_password']}\" -e "CREATE DATABASE IF NOT EXISTS #{node['wordpress']['db']['database']}"
    /usr/bin/mysql -u root -p\"#{node['mysql']['server_root_password']}\" -e "CREATE DATABASE IF NOT EXISTS #{node['horde']['db']['database']}"
  EOH
end

execute "setup-horde-db" do
  command "/usr/bin/horde-db-migrate;touch #{node['horde']['directory']}/db.log"
  creates "#{node['horde']['directory']}/db.log"
end

template "#{node['horde']['directory']}/config/conf.php" do
  source "conf.php.erb"
  owner "www-data"
  group "www-data"
  mode "0775"
  variables()
end

execute "touch_logs" do
  command "chown -R www-data:www-data #{node['horde']['directory']};chmod -R g+rw #{node['horde']['directory']}"
end

################# Wordpress
require 'digest/sha1'
require 'open-uri'
local_file = "#{Chef::Config[:file_cache_path]}/wordpress-latest.tar.gz"
latest_sha1 = open('http://wordpress.org/latest.tar.gz.sha1') {|f| f.read }
unless File.exists?(local_file) && ( Digest::SHA1.hexdigest(File.read(local_file)) == latest_sha1 )
  remote_file "#{Chef::Config[:file_cache_path]}/wordpress-latest.tar.gz" do
    source "http://wordpress.org/latest.tar.gz"
    mode "0644"
  end
end
 
directory "#{node['wordpress']['dir']}" do
  owner "root"
  group "root"
  mode "0755"
  action :create
  recursive true
end

execute "untar-wordpress" do
  cwd node['wordpress']['dir']
  command "tar --strip-components 1 -xzf #{Chef::Config[:file_cache_path]}/wordpress-latest.tar.gz"
  creates "#{node['wordpress']['dir']}/wp-settings.php"
end

execute "mysql-install-wp-privileges" do
  command "/usr/bin/mysql -u root -p\"#{node['mysql']['server_root_password']}\" < #{node['mysql']['conf_dir']}/wp-grants.sql"
  action :nothing
end

template "#{node['mysql']['conf_dir']}/wp-grants.sql" do
  source "grants.sql.erb"
  owner "root"
  group "root"
  mode "0600"
  variables(
    :user => node['wordpress']['db']['user'],
    :password => node['wordpress']['db']['password'],
    :database => node['wordpress']['db']['database']
  )
  notifies :run, "execute[mysql-install-wp-privileges]", :immediately
end

template "#{node['wordpress']['dir']}/wp-config.php" do
  source "wp-config.php.erb"
  owner "root"
  group "root"
  mode "0777"
  variables(
    :user => node['wordpress']['db']['user'],
    :password => node['wordpress']['db']['password'],
    :database => node['wordpress']['db']['database'],
    :auth_key => node['wordpress']['keys']['auth_key'],
    :secure_auth_key => node['wordpress']['keys']['secure_auth_key'],
    :logged_in_key => node['wordpress']['keys']['logged_in_key'],
    :nonce_key => node['wordpress']['keys']['nonce_key']
  )
end


############################## TinyRSS
directory "#{node['tinytinyrss']['dir']}" do
  owner "root"
  group "root"
  mode "0755"
  action :create
  recursive true
end

remote_file "#{Chef::Config[:file_cache_path]}/tinytinyrss.tgz" do
  source "https://github.com/gothfox/Tiny-Tiny-RSS/archive/1.7.4.tar.gz"
  mode "0644"
end


execute "untar-tinyrss" do
  cwd node['tinytinyrss']['dir']
  command "tar --strip-components 1 -xzf #{Chef::Config[:file_cache_path]}/tinytinyrss.tgz"
  creates "#{node['tinytinyrss']['dir']}/index.php"
end

############################ Diaspora

gem_package('bundler') do
  :install
end

git "/opt/diaspora" do
  repository "git://github.com/diaspora/diaspora.git"
  branch "master"
  action :sync
  user 'root'
  group 'root'
end

script "install_diaspora" do
  not_if { File.exists?("/opt/diaspora/config/diaspora.yml") }
  interpreter "bash"
  timeout 3600
  user "root"
  group "root"
  cwd "/opt/diaspora/"
  code <<-EOH
    bundle install
  EOH
end

template "/opt/diaspora/config/diaspora.yml" do
  source "diaspora.yml.erb"
  owner "root"
  group "root"
  mode "0777"
  variables()
end

script "install_diaspora_db" do
  not_if { File.exists?("/opt/diaspora/log/development.log") }
  interpreter "bash"
  timeout 3600
  user "root"
  group "root"
  cwd "/opt/diaspora/"
  code <<-EOH
    bundle exec rake db:schema:load_if_ruby --trace
  EOH
end

directory "/etc/nginx/ssl/" do
  owner "root"
  group "root"
  mode "0755"
  action :create
  recursive true
end

Array(node['nginx']['sites']).each do |u|

	Chef::Log.info "Generating site configuration for: " << u['domain']

  if u.has_key?('uwsgi_port') then
  	template "/etc/uwsgi/apps-enabled/#{u['domain']}.ini" do
  	  source "uwsgi.erb"
  	  owner "root"
  	  group "root"
  	  variables(
  		:port => u['uwsgi_port'],
  		:directory => u['directory']
  	  )
      notifies :restart, "service[uwsgi]"
  	end
	end
	
	template "/etc/nginx/sites-enabled/#{u['domain']}.conf" do
	  source "nginx-site.erb"
	  owner "root"
	  group "root"
	  variables(
		:uwsgi_port => u['uwsgi_port']||'',
		:directory => u['directory'],
		:domain => u['domain'],
		:proxy => u['proxy']||'false',
		:proxy_location => u['proxy_location']||''
	  )
	  notifies :restart, "service[nginx]"
	end
	
  script "create-ssl-certs-#{u['domain']}" do
    not_if { File.exists?("/etc/nginx/ssl/#{u[:domain]}.crt") }
    interpreter "bash"
    timeout 3600
    user "root"
    group "root"
    cwd "/etc/nginx/ssl/"
    code <<-EOH
      openssl req -new -x509 -nodes -out /etc/nginx/ssl/#{u[:domain]}.crt -keyout /etc/nginx/ssl/#{u[:domain]}.key -subj \"/C=US/ST=TX/L=Austin/O=#{u[:domain]}/OU=#{u[:domain]}/CN=#{u[:domain]}/emailAddress=webmaster@#{u[:domain]}\"
    EOH
  end

end

####################### Dovecot
template "/etc/dovecot/dovecot-sql.conf" do
  source "dovecot-sql.conf.erb"
  owner "root"
  group "root"
  mode "0777"
  variables()
end

template "/etc/dovecot/conf.d/auth-master.conf" do
  source "auth-master.conf.erb"
  owner "root"
  group "root"
  mode "0777"
  variables()
end