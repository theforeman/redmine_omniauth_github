## Redmine OmniAuth GitHub

This plugin is used to authenticate in redmine through Github.
It was more than inspired by redmine_omniauth_google see https://github.com/twinslash/redmine_omniauth_google

### Compatibility

It has been tested and/or should work with the following Redmine versions:

* 4.2
* 5.0

### Installation:

Choose folder /plugins, make command

```console
git clone https://github.com/theforeman/redmine_omniauth_github.git
```

Update gems and restart rails server.

### Registration

To make possible to authenticate via Github you must first to register application in Github

* Go to the [registration](https://github.com/settings/applications/new) link.
* When registering specify application name, for example, Redmine Oauth Github.
* Homepage URL is the url of your redmine installation
* Callback URL is the same url with "/oauth/github/callback" appended, e.g. "http://example.net/oauth/github/callback"
* Press the button "Register application".

The registrations is complete.

### Configuration

To make plugin to work properly

* Login as administrator. In top menu select "Administration". Choose menu item Plugins. In plugins list choose "Redmine Omniauth Github plugin". Press "Configure".
* Fill Сlient ID & Client Secret by corresponding values, obtained by Github.
* Put the check "Oauth authentification", to make it possible to login through Github. Click Apply. Users can now login via Github.

Additionaly
* Setup value Autologin in Settings on tab Authentication

### Other options

By default, all domains are allowed to authenticate through Github.
To limit login through Github for other domains you have to fill allowed domains in the text box field the "Allowed domains". Domains must be separated by newlines. For example:

```text
onedomain.com
otherdomain.com
```

### Work process

User goes to the login page (sign in) and clicks the button with Github image. The plugin redirects him to Github where user enters his the еmail & password from Github. Github redirects user back to plugins controller. Then the following cases:
1. If auto registration is enabled, user is redirected to 'my/page'
2. In other case user account is created and waited for admin activation
