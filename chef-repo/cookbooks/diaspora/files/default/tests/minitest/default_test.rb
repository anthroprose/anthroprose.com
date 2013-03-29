require 'minitest/spec'

describe_recipe 'diaspora::default' do

  # It's often convenient to load these includes in a separate helper along with
  # your own helper methods, but here we just include them directly:
  include MiniTest::Chef::Assertions
  include MiniTest::Chef::Context
  include MiniTest::Chef::Resources

#  describe "files" do   
#  end

#  describe "packages" do
#    it "check package installs" do
#    end
#  end

  describe "services" do

    it "running services" do
      service("mysql").must_be_running
      service("diaspora").must_be_running
    end

    it "enabled services" do
      service("mysql").must_be_enabled
      service("diaspora").must_be_enabled
    end

  end

  describe "users and groups" do

    it "creates a user for the daemon to run as" do
      user("diaspora").must_exist
    end
    
  end

end

