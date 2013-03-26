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
    /usr/bin/mysqladmin -u root -p\"#{node['mysql']['server_root_password']}\" CREATE DATABASE IF NOT EXISTS #{node['wordpress']['db']['database']}
    /usr/bin/mysqladmin -u root -p\"#{node['mysql']['server_root_password']}\" CREATE DATABASE IF NOT EXISTS #{node['horde']['db']['database']}
  EOH
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

log "Navigate to 'http://#{node['nginx']['default_domain']}/wp-admin/install.php' to complete wordpress installation" do
  action :nothing
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
