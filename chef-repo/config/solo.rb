root = File.absolute_path(File.dirname(__FILE__))

file_cache_path root
cookbook_path root + '/../cookbooks'
data_bag_path root + '/../data_bags'
encrypted_data_bag_secret root + '/encrypted_data_bag_secret'

role_path nil
log_level :debug
http_proxy nil
http_proxy_user nil
http_proxy_pass nil
https_proxy nil
https_proxy_user nil
https_proxy_pass nil
no_proxy nil