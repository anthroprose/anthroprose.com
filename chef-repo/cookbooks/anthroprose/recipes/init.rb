config = data_bag_item('anthroprose', 'config')

node.default['mysql']['server_root_password'] = config["mysql_root_password"]
node.default['mysql']['server_debian_password'] = config["mysql_root_password"]
node.default['mysql']['server_repl_password'] = config["mysql_root_password"]
node.default['wordpress']['db']['password'] = config["mysql_root_password"]
node.default['wordpress']['keys']['auth'] = config["wordpress_keys_hash"]
node.default['wordpress']['keys']['secure_auth'] = config["wordpress_keys_hash"]
node.default['wordpress']['keys']['logged_in'] = config["wordpress_keys_hash"]
node.default['wordpress']['keys']['nonce'] = config["wordpress_keys_hash"]
node.default['diaspora']['facebook']['enable'] = config["diaspora_facebook_enable"]||'false'
node.default['diaspora']['facebook']['app_id'] = config["diaspora_facebook_app_id"]||''
node.default['diaspora']['facebook']['secret'] = config["diaspora_facebook_secret"]||''