require 'account_controller'
require 'json'

class RedmineOauthController < AccountController
  include Helpers::MailHelper
  include Helpers::Checker
  def oauth_github
    if Setting.plugin_redmine_omniauth_github[:github_oauth_authentication]
      session[:back_url] = params[:back_url]
      redirect_to oauth_client.auth_code.authorize_url(:redirect_uri => oauth_github_callback_url, :scope => scopes)
    else
      password_authentication
    end
  end

  def oauth_github_callback
    if params[:error]
      flash[:error] = l(:notice_access_denied)
      redirect_to signin_path
    else
      token = oauth_client.auth_code.get_token(params[:code], :redirect_uri => oauth_github_callback_url)
      user = token.get('https://api.github.com/user')
      emails = token.get('https://api.github.com/user/emails',
                         :headers => {'Accept' => 'application/vnd.github.v3.full+json'})
      user_info = JSON.parse(user.body)
      logger.error user_info
      emails = JSON.parse(emails.body)
      verified = emails.select { |e| e['verified'] }.map { |v| v['email'] }
      unverified = emails.select { |e| !e['verified'] }.map { |v| v['email'] }
      primary = emails.select { |e| e['primary'] }.first.try(:[], 'email')

      if (user = User.where(:mail => verified).first)
        checked_try_to_login user.mail, user_info
      else
        if User.where(:mail => unverified).blank? && verified.include?(primary)
          checked_try_to_login primary, user_info
        else
          flash[:error] = l(:notice_no_verified_email_we_could_use)
          redirect_to signin_path
        end
      end
    end
  end

  def checked_try_to_login(email, user)
    if allowed_domain_for?(email)
      try_to_login email, user
    else
      flash[:error] = l(:notice_domain_not_allowed, :domain => parse_email(email)[:domain])
      redirect_to signin_path
    end
  end

  def try_to_login email, info
   params[:back_url] = session[:back_url]
   session.delete(:back_url)
   user = User.find_or_initialize_by_mail(email)
    if user.new_record?
      # Self-registration off
      redirect_to(home_url) && return unless Setting.self_registration?
      # Create on the fly
      user.firstname, user.lastname = info["name"].split(' ') unless info['name'].nil?
      user.firstname ||= info[:given_name]
      user.lastname ||= info[:family_name]
      user.mail = email
      user.login = info['login']
      user.login ||= [user.firstname, user.lastname]*"."
      user.random_password
      user.register

      case Setting.self_registration
      when '1'
        register_by_email_activation(user) do
          onthefly_creation_failed(user)
        end
      when '3'
        register_automatically(user) do
          onthefly_creation_failed(user)
        end
      else
        register_manually_by_administrator(user) do
          onthefly_creation_failed(user)
        end
      end
    else
      # Existing record
      if user.active?
        successful_authentication(user)
      else
        account_pending(user)
      end
    end
  end

  def oauth_client
    @client ||= OAuth2::Client.new(settings[:client_id], settings[:client_secret],
      :site => 'https://github.com',
      :authorize_url => '/login/oauth/authorize',
      :token_url => '/login/oauth/access_token')
  end

  def settings
    @settings ||= Setting.plugin_redmine_omniauth_github
  end

  def scopes
    'user:email'
  end
end
