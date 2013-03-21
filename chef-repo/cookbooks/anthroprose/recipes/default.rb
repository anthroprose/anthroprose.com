if node['users'] and node['users'] != '' then
  
  Array(node['users']).each do |u|
    username = u['username'] || u['id']
  
    user_account username do
      %w{comment uid gid home shell password system_user manage_home create_group
          ssh_keys ssh_keygen}.each do |attr|
        send(attr, u[attr]) if u[attr]
      end
      action u['action'].to_sym if u['action']
    end
  
    unless u['groups'].nil?
      u['groups'].each do |groupname|
        group groupname do
          members username
          append true
        end
      end
    end
  end
end
