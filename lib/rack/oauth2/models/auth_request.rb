module Rack
  module OAuth2
    class AuthServer

      # Authorization request. Represents request on behalf of client to access
      # particular scope. Use this to keep state from incoming authorization
      # request to grant/deny redirect.
      class AuthRequest

        include CouchPotato::Persistence
        include FixScope, SetRedirectUri

        property :client_id
        property :response_type
        property :state
        property :scope
        property :grant_code
        property :authorized_at
        property :revoked
        property :token
        property :redirect_uri
        property :access_token


        view :by_client_id, :key =>  :client_id

        def client
          @client ||= database.load client_id
        end

        # Grant access to the specified identity.
        def grant!(identity)
          raise ArgumentError, "Must supply a identity" unless identity
          return if revoked
          client or return
          self.authorized_at = Time.now.to_i
          if response_type == "code" # Requested authorization code
            access_grant = AccessGrant.new(:identity =>  identity, :client_id =>  client_id, :scope =>  scope, :redirect_uri =>  redirect_uri)
            database.save access_grant, false
            database.save self, false do |a|
              a.grant_code = access_grant.code
            end
          else # Requested access token
            access_token = AccessToken.get_token_for(identity, client, scope)
            database.save self, false do |a|
              a.access_token = access_token.token
            end
          end
          true
        end

        # Deny access.
        def deny!
          database.save self, false do |a|
            a.authorized_at = Time.now.to_i
          end
        end
      end

    end
  end
end
