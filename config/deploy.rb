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

namespace :bundler do
  task :ensure_bundler_installed do
    run "gem install bundler --no-ri --no-rdoc"
  end

  task :install do
    run "cd #{release_path} && bundle install --without=development --binstubs"

    on_rollback do
      if previous_release
        run "cd #{previous_release} && bundle install --without=development --binstubs"
      else
        logger.important "No previous release to roll back to, bundler rollback skipped."
      end
    end
  end
end

after "deploy:setup", "bundler:ensure_bundler_installed"
after "deploy:update_code", "bundler:install"

namespace :deploy do
  task :start do
    run "god -c /etc/god/all.god"
  end

  task :stop do
    run "god terminate"
  end

  task :restart do
    run "god restart nagios_unicorn; god restart resque"
  end
end

