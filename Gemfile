source :gemcutter

gem "sinatra", "~> 1.2.6"
gem "resque", "~> 1.17.1"
gem "rake", "~> 0.9.0"
gem "erubis", "~> 2.7.0"
gem "ohai", "~> 0.6.4"
gem "mail", "~> 2.2.18"
gem "redis", "~> 2.2.1"

group :production do
	gem "unicorn", "~> 4.0.1", :require => nil
end

group :development do
  gem "shotgun", "~> 0.9", :require => nil
  gem "capistrano", "~> 2.6.0"
	gem "railsless-deploy", "~> 1.0.2", :require => nil
end

