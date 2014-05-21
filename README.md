Capistrano Scripts
==================

This repository contains templates for various Capistrano configurations. By default these live in config/deploy.rb but can be moved anywhere as long as the Capfile in the root of the repository knows where to look.

## Introduction to Capistrano

Capistrano is a deployment tool written in Ruby. It was designed to make deployments as painless as possible by automating common tasks like SSH-ing into the server and doing a `git pull`. It can also be used to run build scripts (compile assets, compile source, etc.).

To get started you'll need to install the capistrano gem (if it's not already present on your local machine) using `gem install capistrano`.

**Note:** These deployment scripts only work with Capistrano 2, the current version is Capistrano 3. You need to add the version flag when you install the Capistrano gem `-v 2.15.5`.

## Capify-ing a project

The first step when preparing a project to be deployed via Capistrano is to "capify" the project

```bash
$ cd {project root}
$ capify .
```

This will create a file named Capfile at the root of the repository and config/deploy.rb (if there is no config directory one will be created for you). Capfile tells Capistrano where to look for your deploy.rb; a default Capfile looks like:

```ruby
load 'deploy'
load 'config/deploy' # remove this line to skip loading any of the default tasks
```

If you want to move the deploy.rb file for whatever reason (maybe to keep it with other config files), you can move it and delete the /config directory as long as you update the path in Capfile:

```ruby
load 'deploy'

# Moved deploy.rb to live with other config files in app/etc/
load 'app/etc/deploy'
```

**Note:** Apparently Capistrano doesn't like it when deploy.rb is adjacent to the Capfile and named deploy.rb - the following directory/Capfile setup does not appear to work:

```
/project-root
  Capfile
  deploy.rb
```

```ruby
load 'deploy'
```

To get around it you can rename deploy.rb - let's say wp-deploy.rb for a WordPress site and load it with the following Capfile:

```ruby
load 'deploy'
load 'wp-deploy'
```

## Working with deploy.rb

The ruby script in deploy.rb controls how your app will be deployed.

### Defining remote environments

For each environment you wish to deploy to there should be a task defined for it that looks something like this:

```ruby
# `cap staging deploy`
task :dev do
  set :user, "deploy"
  role :web, "SUBDOMAIN.domain.com", :primary => true
  set :app_environment, "staging"
  set :keep_releases, 2
  set :deploy_to, "/var/www/vhosts/DOMAIN/httpdocs"
end
```

If you were setting up an environment named 'foo' for barbaz.com, your environment task might look something like:

```ruby
# `cap foo deploy`
task :foo do
  set :user, "deploy"
  role :web, "barbaz.domain.com"
  set :app_environment, "foo"
  set :keep_releases, 2
  set :deploy_to, "/var/www/vhosts/barbaz/httpdocs"
end
```

Complete documentation for the Capistrano configuration variables can be found [in the Capistrano Github wiki](https://github.com/capistrano/capistrano/wiki/2.x-Significant-Configuration-Variables).


#### Suggested environment naming schemes

In order to keep environment names as consistent as possible here is a suggested convention for environment names:

* **staging:** The primary staging development (typically *.domain.com) for the site/app
* **production:** The production server(s)

You may certainly create other environments as needed but these environments (at least staging and production at this point) should *always* be present!

## Setting up the remote environment

When you're ready to deploy your site to a remote server you'll want to create the virtual host within Apache (if it doesn't already exist) and create the root directory for your deployment (e.g. /var/www/vhosts/example.com/httpdocs). If you haven't already, add the public SSH key for the user you're deploying as (on our staging box that user is "deploy", this should also be the `:user` defined in deploy.rb) as a deploy key on the Bitbucket/Github repository and ensure that the root deployment directory is writable by the deploying user. It's also important to add your public SSH key to the deploying user's authorized_keys file - without it you'll be prompted for a password (if your server permits password authentication) or denied access entirely.

Switch to your local server and run `cap {environment} deploy:setup`. This will attempt to connect to the server(s) defined in deploy.rb and create two subdirectories inside the root of your deployment: shared/ and releases/. For those who are more visual, consider the following:

```
/var/www/vhosts/example.com/httpdocs/
+ releases
+ shared
```

When the application is deployed a fresh copy of the app's git repository is cloned into releases (they're typically named with a timestamp but we'll use "release-#" in our examples). A symlink named "current" is also created adjacent to these directories and points to the newest release. After running our first `cap {environment} deploy` our directory will look like this:

```
/var/www/vhosts/example.com/httpdocs/
  current // symlink to /var/www/vhosts/example.com/httpdocs/releases/release-1
+ releases
 + release-1
+ shared
```

Each time we deploy a new copy is created and the current symlink updated to point to the latest release. After a certain number of releases old ones will be removed; this number is determined by the `:keep_releases` value in deploy.rb. If we ever have to rollback a deployment the symlink is simply re-pointed to the second-most recent deployment (you can also specify the release to rollback to, see [the Capistrano documentation](https://github.com/capistrano/capistrano/wiki/Capistrano-Tasks#deployrollback) for details).

To prevent logs, user-generated content, and other untracked items from being lost between deployments Capistrano allows you to create symlinks to these items in the shared/ directory. These symlinks should be created within the `:finalize_update` task within your deploy.rb file, a WordPress-based example is below for your reference:

```ruby
# Symlink shared/uploads to current/wp-content/uploads
task :finalize_update, :except => { :no_release => true } do
  transaction do
    run "chmod -R g+w #{releases_path}/#{release_name}"
    run "ln -s #{shared_path}/uploads #{release_path}/wp-content/uploads"
  end
end
```

### Breakdown of a typical Capistrano deployment

If you're confused about the order everything happens in a `cap {environment} deploy` this might help:

1. Capistrano SSH's as the deploying user (so your personal SSH pubkey should be in that user's authorized_keys file)
2. Change into the deployment directory and clone a new copy of the repository into releases/{timestamp} (so the deploying user must have pull privileges).
3. Run the `:finalize_update` task to create symlinks to shared/
4. Point the `current` symlink to the newly-created repo in releases/{timestamp}

## Deploying an application

Once Capistrano and the remote server are configured deploying an application should be as easy as `cap {environment} deploy`. For example, pushing code to production would be `cap production deploy` (from the root of the repository on your local machine).

### Rollbacks

If you ever find that your latest deployment has broken something and you need to rollback you can do so by running `cap {environment} deploy:rollback`. This isn't an excuse for deploying buggy/un-tested code but can save you in a pinch.

## Application-specific configuration

Below are the basic configurations for each of the templates in this repository.

### Drupal

### Laravel

After capify-ing a project move config/deploy.rb to app/config/deploy.rb (you can remove the now-empty /config directory) and update your Capfile accordingly:

```ruby
load 'deploy'
load 'app/config/deploy'
```

There are two major areas to be concerned with when deploying a Laravel app through Capistrano:

#### 1. /storage

Most of the directories in /storage are meant to be very temporary in nature (caches, generated files, etc.). Two directories in particular should be in our Capistrano shared directory:

1. storage/logs (log files should persist between deploys)
2. storage/sessions (if we remove these users would be logged out with each deploy!)

The Capistrano recipe will forcibly remove these directories from a new deployment before symlinking the versions in shared.

#### 2. /app/config

Laravel lets us do environment-specific directories for configuration. For example, if you're working with your local development database you should create app/config/development/database.php rather than editing app/config/database.php. Laravel is smart enough to recognize that if app/config/{environment}/{file} exists it should load that rather than app/config/{environment} (environment detection is in bootstrap/start.php).

#### Composer

When setting up a server it's important that [Composer](http://getcomposer.org/) is installed. As root, run the following (which should result in composer being in the deploy user's path):

```bash
$ curl -sS https://getcomposer.org/installer | php
$ mv composer.phar /usr/local/bin/composer
```

#### Shared resources

Your Capistrano shared directory should contain the following files/directories:

* config/ (containing only overrides - probably app.php and database.php at a minimum)
* logs/
* sessions/
* robots.txt (if not on production)

### Magento

To keep our configuration information in one place plan to put your deploy.rb file in app/etc/. Our template also uses some `magento:`-namespaced functions, which require the [magentify](https://github.com/alistairstead/Magentify) gem (`gem install magentify`). Your Capfile will look like this:

```ruby
load 'deploy'

# Requires the magentify gem
load Gem.find_files('mage.rb').last.to_s

# non-standard location for deploy.rb (normally config/deploy)
load 'app/etc/deploy'
```

Use this as a base `.gitignore` file:

```
# Keep the following files/directories out of the repository
/apc/*
/app/etc/local.xml
/downloader/*.cfg
/downloader/.cache/*
/errors/local.xml
/media/*
/var/*
/index.php

# SQL files
*.sql

# Hidden system files
*.DS_Store
*Thumbs.db

# SASS cache
*.sass-cache*
```

This means the following files will need to be created/populated in shared/:

* /apc (in instances where APC is being used)
* /media
* /var
* /index.php (clone from index.php.sample in the root of the repo)
* /local.xml

### WordPress

#### General git workflow

Most of the WordPress sites that are deployed via Git use the [workflow Steve defined in this blog post](http://stevegrunwell.com/blog/keeping-wordpress-under-version-control-with-git). This approach lends itself nicely to Capistrano deployments with one exception - the Htaccess trick to load production files into development won't work because wp-content/uploads will need to be completely out of the repository (so that it can be symlinked to shared/uploads). Put the following snippet in your main Htaccess file instead:

```apache
# Attempt to load files from production if they're not in our local version
<IfModule mod_rewrite.c>
  RewriteEngine on
  RewriteCond %{REQUEST_FILENAME} !-d
  RewriteCond %{REQUEST_FILENAME} !-f
  RewriteRule wp-content/uploads/(.*) http://{PRODUCTION_URL}/wp-content/uploads/$1 [NC,L]
</IfModule>
```

## Other notes

### Dealing with PHP-FPM

More and more of our servers are starting to use PHP-FPM which is great for performance but can be problematic with Capistrano deployments as the application pools often need to be restarted after a deployment. Fortunately, we have a work-around: granting the deploy user access to restart PHP-FPM!

In order for this to work in the securest way possible we need to add the following to the /etc/sudoers file on the target server (be sure you use the `visudo` command - **never** edit /etc/sudoers directly!):

```
deploy ALL = NOPASSWD: /etc/init.d/php5-fpm
```

This lets the deploy user (obviously change the username if our typical "deploy" isn't being used) start, stop, or restart PHP-FPM without a password. Once we have that, we can run `sudo /etc/init.d/php5-fpm restart` during our deployment.

#### Security considerations

It's obviously risky to give a non-root user the ability to take down the site, but I offer the following *other* ways that user, if compromised, could do the same thing:

* Edit/delete the site files
* Pull corrupted code
* Change/remove the configuration (wp-config.php, settings.xml, etc.)
* Change the Htaccess file to redirect all traffic to anywhere

Considering our servers typically disallow password-based authentication (meaning you need to either have root access or possess one of the teams' private SSH keys) it's really not much of an attack vector.

### Understanding `after` commands

Capistrano allows us to specify callbacks to execute before/after certain operations. For a practical example, consider this line in the Magento Capistrano template:

`after "deploy", "mage:cc", "mage:indexer", "deploy:cleanup"`

This tells Capistrano that after the `:deploy` task (e.g. `cap production deploy`) we should run (in order):

1. `cap {env} mage:cc # Clear the Magento cache`
2. `cap {env} mage:indexer # Refresh Magento indexes`
3. `cap {env} deploy:cleanup # Run default Capistrano clean-up actions`

See the [before/after page in the Capistrano documentation](https://github.com/capistrano/capistrano/wiki/2.x-DSL-Configuration-Tasks-After) for more specifics.

### Detecting changes on the remote server

In instances where the client has access to the server and could end up modifying the code (which would be overwritten upon the next deployment) you can use this snippet of code (within the `:deploy` namespace):

```ruby
desc <<-DESC
Check for changes to the current deployment and, if any are found, cancel the deployment.
DESC
task :detect_changes do
  git_status = capture( "cd #{deploy_to}/current && git status --porcelain" ).to_s.strip;
  abort "The following files have changed on the target server, unable to proceed:\n#{git_status}" unless git_status.empty?
end

before "deploy", "deploy:detect_changes"
```

This will check for any unchanged files on the remote server and, if `git status` returns anything the deployment will be aborted.

If your symlinks start coming up as untracked files you'll want to either a) add those symlink names to the repository's .gitignore file _OR_ append the symlinks to the local repository's .git/info/exclude file while you're creating them:

```ruby
task :finalize_update, :except => { :no_release => true } do
  transaction do
    ...
    run "ln -s #{shared_path}/test.txt #{release_path}/test.txt"
    run "echo 'test.txt' >> #{releases_path}/#{release_name}/.git/info/exclude"
    ...
  end
end
```

### Protecting deploy.rb

While it shouldn't really be necessary to hide our deploy.rb files (we use SSH keys and should be password free, we typically deploy to very common locations, etc. - nothing that a malicious person couldn't guess), it really isn't necessary for the web server to serve this file. The following Htaccess snippet will do the trick (obviously adjust the path as necessary):

```apache
# The web server shouldn't need to see deploy.rb
<Files config/deploy.rb>
  Order allow,deny
  Deny from all
</Files>
```

### Git submodules

If your site uses git submodules Capistrano can be configured to automatically initialize them by setting the `:git_enable_submodules` option. To enable submodules find the following line in the template you're using and set it to `true`:

```ruby
set :git_enable_submodules, false
```

### Robots.txt files

Since we don't want staging sites getting indexed it's in our best interest to use a robots.txt file to discourage crawlers. Drop this line in your `:finalize_update` task (it's already in some of the templates) and add the following robots.txt file to your shared/ directory:

```ruby
transaction do
  # your other symlinks

  # Prevent non-production environments from getting crawled
  unless app_environment == "production"
    run "ln -s #{shared_path}/robots.txt #{release_path}/robots.txt"
  end
end
```

```
User-agent: *
Disallow: /
```

### Deploying to Multiple Servers

This documentation still needs to be compiled.

### Deploying Code from a Specific Branch

This documentation still needs to be compiled.