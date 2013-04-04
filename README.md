anthroprose.com
===============

Source for anthroprose.com

Bootstrap your own box using chef-solo.

# Install

wget -O - https://github.com/anthroprose/anthroprose.com/blob/master/init.sh | bash

Create a file for: ~/anthroprose/chef-repo/data_bags/anthroprose/config.json

```json
{
	"id" : "config",
    "mysql_root_password" : "xxxxxxx",
    "wordpress_db_password" : "xxxxxxx",
    "wordpress_keys_hash" : "xxxxxxx",
    "diaspora_facebook_enable" : "false",
    "diaspora_facebook_app_id" : "",
    "diaspora_facebook_secret" : ""
}

```

# Updates

~/anthroprose/deploy.sh

----------------------------------------

# Highlights

* OpenVPN via UDP 54 (DNSMASQ for Coffee Shops and other places) (vpn.athroprose.com)
* Roundcube + IMAP (https://mail.anthroprose.com)
* Wordpress (http://www.anthroprose.com)
* TinyTinyRSS (https://reader.anthroprose.com)
* Diaspora (https://me.anthroprose.com)

----------------------------------------

## Packages
* Chef
* NginX
* MySQL
* PHP
* Python
* Ruby
* Dovecot