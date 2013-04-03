module Rack
  module OAuth2
    class AuthServer

      # The access grant is a nonce, new grant created each time we need it and
      # good for redeeming one access token.
      class AccessGrant

        include CouchPotato::Persistence
        include FixScope, SetRedirectUri

        property :client_id
        property :expires_at
        property :granted_at
        property :identity
        property :scope
        property :redirect_uri
        property :access_token
        property :revoked

        view :by_client_id, :key =>  :client_id
        view :by_code, :key =>  :_id

        def code
          id
        end

        def client
          @client ||= database.load client_id
        end

        before_create :set_expires_at

        attr_accessor :expires
        def set_expires_at
          self.expires_at = Time.now.to_i + (expires || 300)
        end

        # Authorize access and return new access token.
        #
        # Access grant can only be redeemed once, but client can make multiple
        # requests to obtain it, so we need to make sure only first request is
        # successful in returning access token, futher requests raise
        # InvalidGrantError.
        def authorize!
          raise InvalidGrantError, "You can't use the same access grant twice" if access_token || revoked
          # access_token = database.view(AccessToken.not_revoked_by_identiy_client_id_and_scope([identity, client, scope])).first
          access_token = AccessToken.get_token_for(identity, client, scope)
          self.access_token = access_token.token
          self.granted_at = Time.now.to_i
          database.save self, false
          access_token
        end

        def revoke!
          self.revoked = Time.now.to_i
          database.save self, false
        end
      end
    end
  end
end
