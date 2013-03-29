maintainer        "Alex Corley"
maintainer_email  "anthroprose@gmail.com"
license           "Apache 2.0"
description       "Basic Diaspora Install"
version           "0.0.1"
recipe            "diaspora", "Diaspora Install"

depends           "mysql"
depends           "chef_handler"
depends           "minitest-handler"
depends           "user"
depends           "nginx"

%w{ centos fedora redhat amazon ubuntu }.each do |os|
  supports os
end
