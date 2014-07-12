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

install_dir = node.achiiibot.install_dir
user_name = node.achiiibot.user_name
group_name = node.achiiibot.group_name
src_dir = "#{install_dir}/src/achiiibot"

hubot_hipchat_jid = node.achiiibot.hubot_hipchat_jid
hubot_hipchat_password = node.achiiibot.hubot_hipchat_password

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

nodejs_npm 'hubot' do
  version '2.6.4'
end

nodejs_npm 'hubot-suddendeath'

file "#{install_dir}/wrapper_script.sh" do
  content <<-EOC
  cd #{src_dir}
  export HUBOT_HIPCHAT_JID=#{hubot_hipchat_jid}
  export HUBOT_HIPCHAT_PASSWORD=#{hubot_hipchat_password}
  export HUBOT_JENKINS_URL=#{node.achiiibot.jenkins_url}
  export HUBOT_JENKINS_AUTH=#{node.achiiibot.jenkins_auth}
  bin/hubot --adapter hipchat --name #{user_name}
  EOC
  user user_name
  group group_name
  mode 0700
end

monit_monitrc "achiiibot" do
  variables(
    {
      matching: "^node\s.+hubot", # Used to find achiiibot process
      start_script: "/bin/sh #{install_dir}/wrapper_script.sh",
      stop_script: "/usr/bin/killall node -s SIGINT"
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

execute "install dependencies for achiiibot" do
  cwd src_dir
  user user_name
  group group_name
  command <<-EOC
  npm install
  EOC
  notifies :start, "service[achiiibot]"
end

service 'achiiibot' do
  start_command "/bin/sh #{install_dir}/wrapper_script.sh"
  action :start
end
