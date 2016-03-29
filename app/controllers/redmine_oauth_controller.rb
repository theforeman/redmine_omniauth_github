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
      flash[:error] = l(:notice_github_access_denied)
      redirect_to signin_path
    else
      token = nil
      begin
        token = oauth_client.auth_code.get_token(params[:code], :redirect_uri => oauth_github_callback_url)
      rescue OAuth2::Error => e
        flash[:error] = l(:notice_unable_to_obtain_github_credentials) + " " + e.description
        redirect_to signin_path
        return
      end
      user = token.get('https://api.github.com/user')
      emails = token.get('https://api.github.com/user/emails',
                         :headers => {'Accept' => 'application/vnd.github.v3.full+json'})
      user_info = JSON.parse(user.body)
      logger.error user_info
      emails = JSON.parse(emails.body)
      verified = emails.select { |e| e['verified'] }.map { |v| v['email'] }
      unverified = emails.select { |e| !e['verified'] }.map { |v| v['email'] }
      primary = emails.select { |e| e['primary'] }.first.try(:[], 'email')

      if Redmine::VERSION.to_s.starts_with?('2.')
        user = User.where(:mail => verified).first
      else
        user = User.joins(:email_addresses).where(:email_addresses => { :address => verified }).first
      end

      if user
        checked_try_to_login user.mail, user_info, user
      else
        if Redmine::VERSION.to_s.starts_with?('2.')
          unverified_found = User.find_by_mail(unverified).nil? && verified.include?(primary)
        else
          unverified_found = User.joins(:email_addresses).where(:email_addresses => { :address => unverified }).first
        end

        if unverified_found
          user = User.new
          checked_try_to_login primary, user_info, user
        else
          flash[:error] = l(:notice_no_verified_email_we_could_use)
          redirect_to signin_path
        end
      end
    end
  end

  def checked_try_to_login(email, info, user)
    if allowed_domain_for?(email)
      try_to_login email, info, user
    else
      flash[:error] = l(:notice_domain_not_allowed, :domain => parse_email(email)[:domain])
      redirect_to signin_path
    end
  end

  def try_to_login email, info, user
    params[:back_url] = session[:back_url]
    session.delete(:back_url)
    @user = user
    if @user.new_record?
      # Retrieve self-registration setting
      self_registration = settings[:github_self_registration]
      if self_registration == '-1'
        self_registration = Setting.self_registration || '0'
      end

      # Self-registration off
      redirect_to(home_url) && return unless self_registration != '0'
      # Create on the fly
      params = {}
      params["firstname"], params["lastname"] = info["name"].split(' ') unless info['name'].nil?
      params["firstname"] ||= info["login"]
      params["lastname"] ||= 'please_edit_me'
      params["mail"] = email

      @user.login = info["login"]
      @user.safe_attributes = params
      @user.admin = false
      @user.random_password
      @user.register

      case self_registration
      when '1'
        register_by_email_activation(@user) do
          onthefly_creation_failed(@user)
        end
      when '3'
        register_automatically(@user) do
          onthefly_creation_failed(@user)
        end
      else
        register_manually_by_administrator(@user) do
          onthefly_creation_failed(@user)
        end
      end
    else
      # Existing record
      if @user.active?
        @user.update_column(:last_login_on, Time.now)
        successful_authentication(@user)
      else
        account_pending(@user)
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
