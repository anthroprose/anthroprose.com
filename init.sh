#!/bin/bash
sudo apt-get update
sudo apt-get install git ruby1.9.1 ruby1.9.1-dev build-essential
sudo gem install chef --no-ri --no-rdoc
git clone https://github.com/anthroprose/anthroprose.com.git ./anthroprose