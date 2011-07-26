set :application, "nagios_automation"

set :scm, :git
set :repository, "git@github.com:cloudspace/nagios-automation.git"
set :branch, "master"
set :deploy_via, :remote_cache
set :keep_releases, 5

set :bundle_flags,    "--deployment --quiet --binstubs=sbin"
require 'bundler/capistrano'

set :user, "root"
set :use_sudo, false
ssh_options[:forward_agent] = true
ssh_options[:paranoid] = false

role :app, "na.cloudspace.com"
set :deploy_to, "/srv/#{application}"


namespace :log_level do
	['debug', 'info'].each do |level|
		desc "Sets the app's log level to #{level}"
		task level.to_sym do
			run "cd #{current_path} ; sed -i.bak 's/log_level:.*/log_level: #{level}/g' config/app_config.yaml"

			deploy.api.restart
			deploy.resque.restart
		end
	end
end

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

