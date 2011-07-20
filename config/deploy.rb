require 'bundler/capistrano'

set :application, "nagios_automation"

set :scm, :git
set :repository, "git@github.com:cloudspace/nagios-automation.git"
set :branch, "master"
set :deploy_via, :remote_cache
set :keep_releases, 5

set :user, "root"
set :use_sudo, false
ssh_options[:forward_agent] = true
ssh_options[:paranoid] = false

role :app, "na.cloudspace.com"
set :deploy_to, "/srv/#{application}"

namespace :deploy do
  task :start do
    run "start god"
  end

	task :stop do
		run "stop god"
	end

	task :restart do
		run "restart god"
	end

	namespace :api do
		task :stop do
			run "god stop unicorn"
		end

		task :restart do
			run "god restart unicorn"
		end
	end
	
	namespace :resque do
		task :stop do
			run "god stop resque"
		end

		task :restart do
			run "god restart resque"
		end
	end
end

after "deploy:symlink", "deploy:api:restart"
after "deploy:symlink", "deploy:resque:restart"

