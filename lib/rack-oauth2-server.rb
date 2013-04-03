require "rack/oauth2/auth_server"
require "rack/oauth2/sinatra" if defined?(Sinatra)
require "rack/oauth2/rails" if defined?(Rails)
require "rack/oauth2/auth_server/railtie" if defined?(Rails::Railtie)
