config = data_bag_item('diaspora', 'config')
node.default['diaspora']['facebook']['enable'] = config["diaspora_facebook_enable"]||'false'
node.default['diaspora']['facebook']['app_id'] = config["diaspora_facebook_app_id"]||''
node.default['diaspora']['facebook']['secret'] = config["diaspora_facebook_secret"]||''

user_account 'diaspora' do
  comment       'diaspora'
  home          node[:diaspora][:dir]
  manage_home   false
  gid           %x[id -g www-data].to_i
end

gem_package('bundler') do
  :install
end

directory "#{node['diaspora']['dir']}" do
  owner "diaspora"
  group "www-data"
  mode "0775"
  action :create
  recursive true
end

git "#{node['diaspora']['dir']}" do
  repository "git://github.com/diaspora/diaspora.git"
  branch "master"
  action :sync
  user 'diaspora'
  group 'www-data'
end

script "install_diaspora" do
  not_if { File.exists?("#{node[:diaspora][:dir]}/config/diaspora.yml") }
  interpreter "bash"
  timeout 3600
  user "root"
  group "root"
  cwd "#{node['diaspora']['dir']}"
  code <<-EOH
    bundle install
  EOH
end

template "#{node['diaspora']['dir']}/config/database.yml" do
  source "database.yml.erb"
  owner "diaspora"
  group "www-data"
  mode "0775"
  variables()
end

template "#{node['diaspora']['dir']}/config/diaspora.yml" do
  source "diaspora.yml.erb"
    owner "diaspora"
  group "www-data"
  mode "0775"
  variables()
end

template "/etc/init.d/diaspora" do
  source "diaspora.init.d.erb"
  owner "root"
  group "root"
  mode "0755"
  variables()
end

script "install_diaspora_db" do
  not_if { File.exists?("#{node[:diaspora][:dir]}/log") }
  interpreter "bash"
  timeout 3600
  user "root"
  group "root"
  cwd "#{node['diaspora']['dir']}"
  code <<-EOH
    bundle exec rake db:create
    RAILS_ENV=production bundle exec rake db:create
    bundle exec rake db:schema:load
    RAILS_ENV=production bundle exec rake db:schema:load
    bundle exec rake assets:precompile
  EOH
end

directory "/var/log/diaspora" do
  owner "diaspora"
  group "www-data"
  mode "0775"
  action :create
  recursive true
end

service "diaspora" do
  supports :status => true, :restart => true, :reload => true
  action [ :enable, :start ]
end

if node['diaspora']['proxy_https'] == 'true' then
  
  directory "/etc/nginx/ssl/" do
    owner "root"
    group "root"
    mode "0755"
    action :create
    recursive true
  end
  
  script "create-ssl-certs-#{node['diaspora']['domain']}" do
    not_if { File.exists?("/etc/nginx/ssl/#{node[:diaspora][:domain]}.crt") }
    interpreter "bash"
    timeout 3600
    user "root"
    group "root"
    cwd "/etc/nginx/ssl/"
    code <<-EOH
      openssl req -new -x509 -nodes -out /etc/nginx/ssl/#{node[:diaspora][:domain]}.crt -keyout /etc/nginx/ssl/#{node[:diaspora][:domain]}.key -subj \"/C=#{node[:diaspora][:country]}/ST=#{node[:diaspora][:state]}/L=#{node[:diaspora][:city]}/O=#{node[:diaspora][:domain]}/OU=#{node[:diaspora][:domain]}/CN=#{node[:diaspora][:domain]}/emailAddress=#{node[:diaspora][:admin_email]}\"
    EOH
  end
  
end

template "/etc/nginx/sites-available/#{node['diaspora']['domain']}.conf" do
  source "nginx-site.erb"
  owner "root"
  group "root"
  variables(:domain => node['diaspora']['domain'], :https => node['diaspora']['proxy_https'], :proxy_location => node['diaspora']['proxy_location'])
  notifies :restart, "service[nginx]"
end
