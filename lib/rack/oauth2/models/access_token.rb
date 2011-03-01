module Rack
  module OAuth2
    class Server

      # Access token. This is what clients use to access resources.
      #
      # An access token is a unique code, associated with a client, an identity
      # and scope. It may be revoked, or expire after a certain period.
      class AccessToken
        
        include CouchPotato::Persistence
        include FixScope
        
        property :client_id
        property :identity
        property :token
        property :scope
        property :expires_at
        property :revoked
        property :last_access
        property :prev_access
        
        view :by_client_id, :key =>  :client_id
        view :by_id, :key =>  :_id
        view :not_revoked_by_identiy_client_id_and_scope, :key =>  [:identity, :client_id, :scope], :conditions =>  '!doc.revoked'
        view :by_token, :key =>  :token
        view :by_identity, :key =>  :identity
        view :by_revoked, :key =>  :revoked
        view :by_client_id_and_revoked, :key =>  [:client_id, :revoked]
        view :by_created_at, :key =>  :created_at
        view :by_client_id_and_created_at, :key =>  [:client_id, :created_at]
        
        before_create :generate_token
        
        def generate_token
          self.token = Server.secure_random
        end
        
        def client
          @client ||= database.load client_id
        end
        
        class << self
          # Get an access token (create new one if necessary).
          def get_token_for(identity, client, scope)
            raise ArgumentError, "Identity must be String or Integer" unless String === identity || Integer === identity
            scope = Utils.normalize_scope(scope) & client.scope # Only allowed scope
            unless token = Server.database.view(AccessToken.not_revoked_by_identiy_client_id_and_scope([identity, client.id, scope])).first
              token = AccessToken.new(:database =>  Server.database, :client_id=>client.id, :identity=>identity, :scope=>scope)
              Server.database.save token, false
            end
            token
          end

          # def historical(filter = {})
          #   days = filter[:days] || 60
          #   select = { :$gt=> { :created_at=>Time.now - 86400 * days } }
          #   select = {}
          #   if filter[:client_id]
          #     select[:client_id] = BSON::ObjectId(filter[:client_id].to_s)
          #   end
          #   raw = Server::AccessToken.collection.group("function (token) { return { ts: Math.floor(token.created_at / 86400) } }",
          #     select, { :granted=>0 }, "function (token, state) { state.granted++ }")
          #   raw.sort { |a, b| a["ts"] - b["ts"] }
          # end
        end

        # Updates the last access timestamp.
        def access!
          today = (Time.now.to_i / 3600) * 3600
          if last_access.nil? || last_access < today
            self.last_access = today
            database.save self, false
          end
        end

        # Revokes this access token.
        def revoke!
          self.revoked = Time.now.to_i
          database.save self, false
        end
      end
    end
  end
end
