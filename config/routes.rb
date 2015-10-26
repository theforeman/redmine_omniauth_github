get 'oauth/github', :to => 'redmine_oauth#oauth_github'
get 'oauth/github/callback', :to => 'redmine_oauth#oauth_github_callback', :as => 'oauth_github_callback'
