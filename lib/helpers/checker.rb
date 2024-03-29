module Helpers
  module Checker
    def allowed_domain_for? email
      allowed_domains = Setting.plugin_redmine_omniauth_github['allowed_domains']
      return unless allowed_domains
      allowed_domains = allowed_domains.split
      return true if allowed_domains.empty?
      allowed_domains.include?(parse_email(email)[:domain])
    end
  end
end
