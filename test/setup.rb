require "bundler"
Bundler.setup
require "test/unit"
require "rack/test"
require "shoulda"
require "timecop"
require "ap"
require "json"
require "logger"
require 'couch_potato'
$: << File.dirname(__FILE__) + "/../lib"
$: << File.expand_path(File.dirname(__FILE__) + "/..")

CouchPotato::Config.validation_framework = :active_model

couchrest_db = CouchRest.database('rack_oauth2_test')
couchrest_db.delete! rescue nil
couchrest_db.create!
DATABASE = CouchPotato::Database.new(couchrest_db)

require "rack/oauth2/server"
require "rack/oauth2/server/admin"

ENV["RACK_ENV"] = "test"

FRAMEWORK = ENV["FRAMEWORK"] || "sinatra"

$logger = Logger.new("test.log")
$logger.level = Logger::DEBUG
Rack::OAuth2::Server::Admin.configure do |config|
  config.set :logger, $logger
  config.set :logging, true
  config.set :raise_errors, true
  config.set :dump_errors, true
  config.oauth.logger = $logger
end


case FRAMEWORK
when "sinatra", nil

  require "sinatra/base"
  puts "Testing with Sinatra #{Sinatra::VERSION}"
  require File.dirname(__FILE__) + "/sinatra/my_app"
  
  class Test::Unit::TestCase
    def app
      Rack::Builder.new do
        map("/oauth/admin") { run Server::Admin }
        map("/") { run MyApp }
      end
    end

    def config
      MyApp.oauth
    end
  end

when "rails"

  RAILS_ENV = "test"
  RAILS_ROOT = File.dirname(__FILE__) + "/rails3"
  begin
    require "rails"
  rescue LoadError
  end

  if defined?(Rails::Railtie)
    # Rails 3.x
    require "rack/oauth2/server/railtie"
    require File.dirname(__FILE__) + "/rails3/config/environment"
    puts "Testing with Rails #{Rails.version}"
  
    class Test::Unit::TestCase
      def app
        ::Rails.application
      end

      def config
        ::Rails.configuration.oauth
      end
    end
  end
else
  puts "Unknown framework #{FRAMEWORK}"
  exit(-1)
end


class Test::Unit::TestCase
  include Rack::Test::Methods
  include Rack::OAuth2

  def setup
    Server.database = DATABASE
    
    Server.database.couchrest_database.delete! rescue nil
    Server.database.couchrest_database.create!
    
    Server::Admin.scope = %{read write}
    @client = Server.register(:display_name=>"UberClient", :redirect_uri=>"http://uberclient.dot/callback", :scope=>%w{read write oauth-admin})
  end

  attr_reader :client, :end_user
end
