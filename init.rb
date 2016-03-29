require 'redmine'
require_dependency 'redmine_omniauth_github/hooks'

Redmine::Plugin.register :redmine_omniauth_github do
  name 'Redmine Omniauth Github plugin'
  author 'Marek Hulan'
  description 'This is a plugin for Redmine registration through github'
  version '0.0.3'
  url 'https://github.com/ares/redmine_omniauth_github'
  author_url 'https://github.com/ares'

  settings :default => {
    :client_id => "",
    :client_secret => "",
    :github_oauth_autentication => false,
    :allowed_domains => "",
    :github_self_registration => "-1"
  }, :partial => 'settings/github_settings'
end
