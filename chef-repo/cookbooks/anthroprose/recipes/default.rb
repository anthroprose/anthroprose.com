execute "hostname" do
  command "echo #{node['nginx']['default_domain']} > /etc/hostname;hostname -F /etc/hostname"
  creates "#{node['tinytinyrss']['dir']}/db.log"
end

execute "enable_ip_forwarding" do
  command "sudo sysctl -w net.ipv4.ip_forward=1"
end

template "/etc/rc.local" do
  source "rc.local.erb"
  owner "root"
  group "root"
end

Array(node['dependencies']).each do |p|
  package p do
    action :install
  end
end

################ EBS Storage Volume
script "filesystem_format" do
  only_if { File.exists?("/dev/sdh1") }
  not_if { File.exists?(node['encfs']['dir']) }
  interpreter "bash"
  user "root"
  cwd "/tmp"
  code <<-EOH
  mkfs.xfs -f /dev/sdh1
  echo /dev/sdh1 /opt xfs rw,noatime,nodiratime 0 0 >> /etc/fstab
  EOH
end

directory node['encfs']['dir'] do
  owner "root"
  group "root"
  mode "0755"
  action :create
  recursive true
end

mount node['encfs']['dir'] do
  only_if { File.exists?("/dev/sdh1") }
  device "/dev/sdh1"
  fstype "xfs"
  action :mount
end

execute "filesystem_initfs" do
  creates "/var/log/initfs.touch"
  command "dracut -H -f /boot/initramfs-$(uname -r).img $(uname -r);touch /var/log/initfs.touch"
  action :run
end

############### DBs

script "create_databases" do
  interpreter "bash"
  timeout 3600
  user "root"
  group "root"
  code <<-EOH
    /usr/bin/mysql -u root -p\"#{node['mysql']['server_root_password']}\" -e "CREATE DATABASE IF NOT EXISTS #{node['wordpress']['db']['database']}"
    /usr/bin/mysql -u root -p\"#{node['mysql']['server_root_password']}\" -e "CREATE DATABASE IF NOT EXISTS #{node['tinytinyrss']['db']['database']}"
    /usr/bin/mysql -u root -p\"#{node['mysql']['server_root_password']}\" -e "CREATE DATABASE IF NOT EXISTS #{node['roundcube']['db']['database']}"
  EOH
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

template "#{node['tinytinyrss']['dir']}/config.php" do
  source "config.php.erb"
  owner "root"
  group "root"
  mode "0755"
  variables()
end

directory "#{node['tinytinyrss']['dir']}/cache/images" do
  owner "root"
  group "root"
  mode "0777"
  action :create
  recursive true
end

directory "#{node['tinytinyrss']['dir']}/cache/export" do
  owner "root"
  group "root"
  mode "0777"
  action :create
  recursive true
end

directory "#{node['tinytinyrss']['dir']}/feed-icons" do
  owner "root"
  group "root"
  mode "0777"
  action :create
  recursive true
end

directory "#{node['tinytinyrss']['dir']}/lock" do
  owner "root"
  group "root"
  mode "0777"
  action :create
  recursive true
end

execute "setup-tinytinyrss-db" do
  command "mysql -uroot -p#{node['mysql']['server_root_password']} #{node['tinytinyrss']['db']['database']} < #{node['tinytinyrss']['dir']}/schema/ttrss_schema_mysql.sql;touch #{node['tinytinyrss']['dir']}/db.log"
  creates "#{node['tinytinyrss']['dir']}/db.log"
end

cron "tty-rss" do
  user "www-data"
  hour "*"
  minute "30"
  command "cd #{node['tinytinyrss']['dir']} && /usr/bin/php #{node['tinytinyrss']['dir']}/update.php -feeds >/dev/null 2>&1"  
end


############################### RoundCube

directory "#{node['roundcube']['dir']}" do
  owner "www-data"
  group "www-data"
  mode "0775"
  action :create
  recursive true
end

remote_file "#{Chef::Config[:file_cache_path]}/roundcube.tgz" do
  source "http://downloads.sourceforge.net/project/roundcubemail/roundcubemail/0.9.2/roundcubemail-0.9.2.tar.gz"
  mode "0644"
end

execute "untar-roundcube" do
  cwd node['roundcube']['dir']
  command "tar --strip-components 1 -xzf #{Chef::Config[:file_cache_path]}/roundcube.tgz"
  creates "#{node['roundcube']['dir']}/index.php"
end

template "#{node['roundcube']['dir']}/config/main.inc.php" do
  source "main.inc.php.erb"
  owner "www-data"
  group "www-data"
  mode "0775"
  variables()
end

template "#{node['roundcube']['dir']}/config/db.inc.php" do
  source "db.inc.php.erb"
  owner "www-data"
  group "www-data"
  mode "0775"
  variables()
end

########################## OwnCloud

directory "#{node['owncloud']['dir']}" do
  owner "www-data"
  group "www-data"
  mode "0775"
  action :create
  recursive true
end

remote_file "#{Chef::Config[:file_cache_path]}/owncloud.bz2" do
  source "http://download.owncloud.org/community/owncloud-5.0.9.tar.bz2"
  mode "0644"
end

execute "untar-owncloud" do
  cwd node['owncloud']['dir']
  command "tar --strip-components 1 -xjf #{Chef::Config[:file_cache_path]}/owncloud.bz2"
  creates "#{node['owncloud']['dir']}/index.php"
end

########################## NGINX

template "/etc/php5/cgi/php.ini" do
  source "php.ini.erb"
  owner "root"
  group "root"
  mode "0655"
  variables()
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
	
  script "create-ssl-certs-#{u['domain']}" do
    not_if { File.exists?("/etc/nginx/ssl/#{u[:domain]}.crt") }
    interpreter "bash"
    timeout 3600
    user "root"
    group "root"
    cwd "/etc/nginx/ssl/"
    code <<-EOH
      openssl req -new -x509 -nodes -out /etc/nginx/ssl/#{u[:domain]}.crt -keyout /etc/nginx/ssl/#{u[:domain]}.key -subj \"/C=#{node[:nginx][:ssl][:country]}/ST=#{node[:nginx][:ssl][:state]}/L=#{node[:nginx][:ssl][:city]}/O=#{u[:domain]}/OU=#{u[:domain]}/CN=#{u[:domain]}/emailAddress=webmaster@#{u[:domain]}\"
    EOH
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
    :https => u['https']||'false',
    :proxy_location => u['proxy_location']||''
    )
    notifies :restart, "service[nginx]"
  end
  
end

service "uwsgi" do
  supports :status => true, :restart => true, :reload => true
  action [ :enable, :start ]
end

####################### Dovecot
template "/etc/dovecot/dovecot.conf" do
  source "dovecot.conf.erb"
  owner "root"
  group "root"
  mode "0755"
  variables()
end

template "/etc/dovecot/conf.d/10-ssl.conf" do
  source "10-ssl.conf.erb"
  owner "root"
  group "root"
  mode "0755"
  variables()
end


############################# IPV6
#template "/etc/network/interfaces" do
#  source "interfaces.erb"
#  owner "root"
#  group "root"
#  mode "0755"
#  variables()
#end

#execute "ipv6-ifup" do
#  command "/sbin/ifup he-ipv6"
#end

######################## Backups
script "backup_setup" do
  creates "/mnt/backup"
  interpreter "bash"
  user "root"
  group "root"
  cwd "/tmp"
  code <<-EOH
    modprobe fuse
    adduser ubuntu fuse
    wget --no-check-certificate -P /tmp http://s3fs.googlecode.com/files/s3fs-1.71.tar.gz
    cd /tmp
    tar -zxvf s3fs-1.71.tar.gz
    cd s3fs-1.71
    ./configure
    make
    make install
    mkdir -p /mnt/backup
    /usr/local/bin/s3fs #{node['s3bucket']} /mnt/backup -ouse_cache=/tmp -ouid=`id -u ubuntu` -ogid=`id -g ubuntu` -oallow_other
    echo "s3fs##{node['s3bucket']} /mnt/backup fuse uid=`id -u ubuntu`,gid=`id -g ubuntu`,allow_other,use_cache=/tmp 0 0" >> /etc/fstab
  EOH
end