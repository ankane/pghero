# config valid only for current version of Capistrano
lock '3.4.0'

#set :application, 'my_app_name'
set :application, 'twighorse'
#set :repo_url, 'git@example.com:me/my_repo.git'
set :repo_url, 'git@github.com:brucebotes/pghero.git'


# Default branch is :master
#ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default deploy_to directory is /var/www/my_app_name
# set :deploy_to, '/var/www/my_app_name'
set :deploy_to, "/home/ubuntu/pghero"

# Default value for :scm is :git
set :scm, :git

# Default value for :format is :pretty
set :format, :pretty

# Default value for :log_level is :debug
set :log_level, :debug

# Default value for :pty is false
#set :pty, true

# Default value for :linked_files is []
#set :linked_files, fetch(:linked_files, []).push('Gemfile')

# Default value for linked_dirs is []
#et :linked_dirs, fetch(:linked_dirs, []).push('log', 'wiki')

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
set :keep_releases, 5

# two additional settings from Rails 3 in action
#set :user, "vagrant"
#set :group, "vagrant"
#set :use_sudo, false
set :user, 'ubuntu'

namespace :deploy do
  task :start do ; end
  task :stop do ; end
  # desc "Restart the application"
  # task :restart, :roles => :app, :except => { :no_release => true } do
  #   run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
  # end

  # desc "Copy the database.yml file into the latest release"
  # task :copy_in_database_yml do
  #   run "cp #{shared_path}/config/database.yml #{latest_release}/config/"
  # end

  # before "deploy:assets:precompile", "deploy:copy_in_database_yml"

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end
end
