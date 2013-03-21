current_dir = File.dirname(__FILE__)
log_level                :info
log_location             STDOUT
node_name                "anthroprose"
client_key               "#{current_dir}/anthroprose.pem"
validation_client_name   "anthroprose-validator"
validation_key           "/home/ubuntu/.chef/anthroprose-validator.pem"
chef_server_url          "https://api.opscode.com/organizations/anthroprose"
cache_type               'BasicFile'
cache_options( :path => "#{ENV['HOME']}/.chef/checksums" )
cookbook_path            ["#{current_dir}/../cookbooks"]

