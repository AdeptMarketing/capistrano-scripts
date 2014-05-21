# WordPress Capistrano deployment

## basic setup stuff ##

# http://help.github.com/deploy-with-capistrano/
set :application, "APPLICATION NAME"
set :repository, "git@bitbucket.org:AdeptMarketing/REPOSITORY"
set :scm, "git"
default_run_options[:pty] = true

# use our keys, make sure we grab submodules, try to keep a remote cache
set :ssh_options, { :forward_agent => true }
set :deploy_via, :checkout
set :use_sudo, false
set :git_enable_submodules, false

set :branch, 'master'
set :branch, $1 if `git branch` =~ /\* (\S+)\s/m

## multi-stage deploy process ##

# `cap staging deploy`
task :staging do
  set :user, "deploy"
  role :web, "SUBDOMAIN.domain.com", :primary => true
  set :app_environment, "staging"
  set :keep_releases, 2
  set :deploy_to, "/var/www/vhosts/DOMAIN/httpdocs"
end

# `cap production deploy`
task :production do
  set :user, "SITEPRODUSER"
  role :web, "DOMAIN"
  set :app_environment, "production"
  set :branch, "master"
  set :keep_releases, 5
  set :deploy_to, "/var/www/vhosts/DOMAIN/httpdocs"
end

namespace :deploy do

  task :finalize_update, :except => { :no_release => true } do
    transaction do
      run "chmod -R g+w #{releases_path}/#{release_name}"
      #run "ln -s #{shared_path}/blogs.dir #{release_path}/wp-content/blogs.dir"
      run "ln -s #{shared_path}/uploads #{release_path}/wp-content/uploads"
      run "ln -s #{shared_path}/wp-config.php #{release_path}/wp-config.php"

      # If production is running PHP-FPM, we'll need to restart it upon deployment
      # Requires the following in the sudoers file:
      # {the :user, typically "deploy"} ALL = NOPASSWD: /etc/init.d/php5-fpm
      if app_environment == "production"
        #run "sudo /etc/init.d/php5-fpm restart"

      # Prevent non-production environments from getting crawled
      else
        run "ln -s #{shared_path}/robots.txt #{release_path}/robots.txt"
      end
    end
  end

  after "deploy", "deploy:cleanup"

end