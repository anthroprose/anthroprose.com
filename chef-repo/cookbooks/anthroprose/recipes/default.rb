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

hc = php_pear_channel "pear.horde.org" do
   action :discover
end

directory "#{node['horde']['directory']}" do
  owner "root"
  group "root"
  mode "0755"
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

template "#{node['horde']['directory']}/config/conf.php" do
  source "conf.php.erb"
  owner "root"
  group "root"
  mode "0777"
  variables()
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

execute "touch_logs" do
  command "touch #{node['horde']['directory']}/config/conf.bak.php;chmod 777 #{node['horde']['directory']}/config/conf.bak.php"
end

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


execute "untar-wordpress" do
  cwd node['tinytinyrss']['dir']
  command "tar --strip-components 1 -xzf #{Chef::Config[:file_cache_path]}/tinytinyrss.tgz"
  creates "#{node['tinytinyrss']['dir']}/index.php"
end

Array(node['nginx']['sites']).each do |u|

	Chef::Log.info "Generating site configuration for: " << u['domain']

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
	
	template "/etc/nginx/sites-enabled/#{u['domain']}.conf" do
	  source "nginx-site.erb"
	  owner "root"
	  group "root"
	  variables(
		:uwsgi_port => u['uwsgi_port'],
		:directory => u['directory'],
		:domain => u['domain']
	  )
	  notifies :restart, "service[nginx]"
	end

end
