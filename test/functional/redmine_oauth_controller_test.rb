require File.expand_path('../../test_helper', __FILE__)

class RedmineOauthControllerTest < ActionController::TestCase
  include Helpers::MailHelper
  def setup
    @default_user_credentials = { :firstname => 'Cool',
                                  :lastname => 'User',
                                  :mail => 'user@somedomain.com'}
    @default_response_body = {:name => 'Cool User',
                              :login => 'cooluser',
                              :email => 'user@somedomain.com'}
    @default_emails_response_body = [{:email => @default_response_body[:email], :verified => true, :primary => true}]
    @unverified_emails_response_body = [{:email => @default_response_body[:email], :verified => false, :primary => true}]
    User.current = nil
    OAuth2::Client.any_instance.stubs(:get_token => OAuth2::AccessToken.new('code', 'redirect_uri'))
  end

  #creates a new user with the credentials listed in the options and fills in the missing data by default data
  def new_user options = {}
    User.where(@default_user_credentials.merge(options).except(:mail)).delete_all
    user = User.new @default_user_credentials.merge(options)
    user.login = options[:login] || 'cool_user'
    user
  end

  #creates a new user with the credentials listed in the options and fills in the missing data by default data
  def set_response_body_stub options = {}
    user_response = OAuth2::Response.new(nil)
    user_response.stubs(:body => @default_response_body.merge(options).to_json)
    emails_response = OAuth2::Response.new(nil)
    if options.fetch(:verified_email, nil) == false
      emails_response.stubs(:body => @unverified_emails_response_body.to_json)
    else
      emails_response.stubs(:body => @default_emails_response_body.to_json)
    end
    OAuth2::AccessToken.any_instance.stubs(:get).with('https://api.github.com/user').returns(user_response)
    OAuth2::AccessToken.any_instance.stubs(:get).with('https://api.github.com/user/emails', :headers => {"Accept" => "application/vnd.github.v3.full+json"}).returns(emails_response)
  end

  def test_oauth_github_with_disabled_oauth_authentification
    with_settings plugin_redmine_omniauth_github: { 'oauth_authentification' => nil } do
      get :oauth_github
      assert_redirected_to signin_path
    end
  end

  def test_oauth_github_callback_for_existing_non_active_user
    Setting.self_registration = '2'
    user = new_user :status => User::STATUS_REGISTERED
    assert user.save
    set_response_body_stub
    get :oauth_github_callback
    assert_redirected_to signin_path
  end

  def test_oauth_github_callback_for_existing_active_user
    user = new_user
    user.activate
    assert user.save
    set_response_body_stub
    get :oauth_github_callback
    assert_redirected_to :controller => 'my', :action => 'page'
  end

  def test_oauth_github_callback_for_new_user_with_valid_credentials_and_selfregistration_enabled
    Setting.self_registration = '3'
    set_response_body_stub
    get :oauth_github_callback
    assert_redirected_to :controller => 'my', :action  => 'account'
    user = User.find_by_mail(@default_response_body[:email])
    assert_equal user.mail, @default_response_body[:email]
    assert_equal user.login, @default_response_body[:login]
  end

  def test_oauth_github_callback_for_new_user_with_valid_credentials_and_selfregistration_disabled
    Setting.self_registration = '2'
    set_response_body_stub
    get :oauth_github_callback
    assert_redirected_to signin_path
  end

  def test_oauth_github_callback_with_new_user_with_invalid_oauth_provider
    Setting.self_registration = '3'
    set_response_body_stub :verified_email => false
    get :oauth_github_callback
    assert_redirected_to signin_path
  end

  def test_oauth_github_callback_with_new_user_created_with_email_activation_should_have_a_token
    Setting.self_registration = '1'
    set_response_body_stub
    get :oauth_github_callback
    assert_redirected_to :signin
    user = User.find_by_mail(@default_user_credentials[:mail])
    assert user
    token = Token.find_by_user_id_and_action(user.id, 'register')
    assert token
  end

  def test_oauth_github_callback_with_new_user_created_with_manual_activation
    Setting.self_registration = '2'
    set_response_body_stub
    get :oauth_github_callback
    assert_redirected_to :signin
    user = User.find_by_mail(@default_user_credentials[:mail])
    assert user
    assert_equal User::STATUS_REGISTERED, user.status
  end

  def test_oauth_github_callback_with_not_allowed_email_domain
    with_settings plugin_redmine_omniauth_github: { 'allowed_domains' => "twinslash.com", 'github_self_registration' => '3' } do
      set_response_body_stub
      get :oauth_github_callback
      assert_redirected_to :signin
    end
  end

  def test_oauth_github_callback_with_allowed_email_domain
    with_settings plugin_redmine_omniauth_github: { 'allowed_domains' => parse_email(@default_response_body[:email])[:domain], 'github_self_registration' => '3' } do
      set_response_body_stub
      get :oauth_github_callback
      assert_redirected_to :controller => 'my', :action => 'account'
    end
  end
end
