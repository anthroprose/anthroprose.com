#!/bin/bash
git pull
sudo chef-solo -c ~/anthroprose/chef-repo/config/solo.rb -j ~/anthroprose/chef-repo/roles/anthroprose.json