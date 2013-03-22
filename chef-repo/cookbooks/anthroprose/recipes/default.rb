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

script "pear_horde_role" do
  interpreter "bash"
  timeout 3600
  user "root"
  group "root"
  code <<-EOH
	pear install horde/horde_role
	expect -c "spawn pear run-scripts horde/Horde_Role;expect { \\"Filesystem\\" { send \\"#{node['horde']['directory']}\\n\\" } }"
  EOH
end

php_pear "webmail" do
   channel hc.channel_name
   preferred_state "beta"
   action :install
end

service "uwsgi" do
  supports :status => true, :restart => true, :reload => true
  action [ :enable, :start ]
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
