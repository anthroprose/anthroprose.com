#!/bin/bash
sudo apt-get update
sudo apt-get -y install git ruby1.9.1 ruby1.9.1-dev build-essential
sudo gem install chef --no-ri --no-rdoc
git clone https://github.com/anthroprose/anthroprose.com.git ./anthroprose
cd anthroprose
echo "Please create a config.json inside of ./chef-repo/data_bags/anthroprose/"