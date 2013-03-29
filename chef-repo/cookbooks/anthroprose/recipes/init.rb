config = data_bag_item(node['databag'], config)

node['mysql']['server']['server_root_password'] = config["mysql_root_password"]
node['mysql']['server']['server_debian_password'] = config["mysql_root_password"]
node['mysql']['server']['server_repl_password'] = config["mysql_root_password"]
node['wordpress']['db']['password'] = config["mysql_root_password"]
node['wordpress']['keys']['auth'] = config["wordpress_keys_hash"]
node['wordpress']['keys']['secure_auth'] = config["wordpress_keys_hash"]
node['wordpress']['keys']['logged_in'] = config["wordpress_keys_hash"]
node['wordpress']['keys']['nonce'] = config["wordpress_keys_hash"]