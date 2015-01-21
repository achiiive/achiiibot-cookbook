#
# Cookbook Name:: achiiibot
# Recipe:: default
#
# Copyright (C) 2014 achiiive.com
#
# All rights reserved - Do Not Redistribute
#
include_recipe 'git'
include_recipe 'nodejs::nodejs_from_package'
include_recipe 'redis::install'
include_recipe 'monit'
include_recipe 'sudo'

install_dir = node.achiiibot.install_dir
user_name = node.achiiibot.user_name
group_name = node.achiiibot.group_name
src_dir = "#{install_dir}/src/achiiibot"

adapter = node.achiiibot.adapter

init_script = "/etc/init.d/achiiibot"
pidfile = node.achiiibot.pidfile

user user_name do
  home install_dir
end

group group_name do
  members user_name
end

directory install_dir do
  owner user_name
  group group_name
  recursive true
  mode 0755
end

package 'libexpat1-dev' do
  action :install
end

package 'libicu-dev' do
  action :install
end

nodejs_npm 'coffee-script'
nodejs_npm 'xml2js' do
  version '0.1.14'
end

nodejs_npm 'hubot' do
  version '2.6.4'
end

nodejs_npm 'hubot-suddendeath'

file "#{install_dir}/wrapper_script.sh" do
  content <<-EOC
  cd #{src_dir}
  bin/hubot --adapter #{adapter} --name #{user_name}
  EOC
  user user_name
  group group_name
  mode 0700
end

monit_monitrc "achiiibot" do
  variables(
    {
      pidfile: pidfile,
      start_script: "#{init_script} start",
      stop_script: "#{init_script} stop",
      restart_script: "#{init_script} restart",
    }
  )
end

deploy_key 'github achiiibot repository key' do
  provider Chef::Provider::DeployKeyGithub
  credentials({token: 'ea4a203ecf9336d636a49b0e65ec034a09d2f7a2'})

  repo 'achiiive/achiiibot-hipchat'
  owner user_name
  group group_name
  path "#{install_dir}/.ssh"
  action :add
end

ssh_known_hosts 'github.com' do
  user user_name
end
ssh_config 'github.com' do
  options 'IdentityFile' => "#{install_dir}/.ssh/#{user_name}"
  user user_name
end

directory "#{install_dir}/src" do
  owner user_name
  group group_name
end

git src_dir do
  repository 'git@github.com:achiiive/achiiibot-hipchat.git'
  # checkout_branch 'master'
  user user_name
  group group_name
  action :sync
end

template init_script do
  source "achiiibot_init.erb"
  mode 00755
  owner "root"
  group "root"
  variables(
    {
      pidfile: pidfile,
      adapter: adapter,
      hubot_hipchat_jid: node.achiiibot.hubot_hipchat_jid,
      hubot_hipchat_password: node.achiiibot.hubot_hipchat_password,
      hubot_jenkins_url: node.achiiibot.jenkins_url,
      hubot_jenkins_auth: node.achiiibot.jenkins_auth,
      hubot_newrelic_api_key: node.achiiibot.hubot_newrelic_api_key
    }
  )
end

execute "install dependencies for achiiibot" do
  cwd src_dir
  user user_name
  group group_name
  command <<-EOC
  sudo -S npm install
  EOC
  if File.exist?(pidfile)
    notifies :restart, "service[achiiibot]", :immediately
  else
    notifies :start, "service[achiiibot]", :immediately
  end
end

service 'achiiibot' do
  action :nothing
  init_command init_script
  supports :status => true, :restart => true, :reload => false
  notifies :run, "execute[monitor achiiibot]"
end

execute 'monitor achiiibot' do
  command <<-EOC
  monit
  monit monitor achiiibot
  EOC
  action :nothing
end
