Array(node['dependencies']).each do |p|
  package p do
    action :install
  end
end
