require "couch_potato"
require "openssl"
require "rack/oauth2/auth_server/errors"
require "rack/oauth2/auth_server/utils"

module Rack
  module OAuth2
    class AuthServer

      class << self
        # A CouchPotato::Database object.
        attr_accessor :database

        def secure_random
          OpenSSL::Random.random_bytes(32).unpack("H*")[0]
        end
      end
    end
  end
end


require "rack/oauth2/models/fix_scope"
require "rack/oauth2/models/set_redirect_uri"
require "rack/oauth2/models/client"
require "rack/oauth2/models/auth_request"
require "rack/oauth2/models/access_grant"
require "rack/oauth2/models/access_token"

