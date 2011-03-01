module Rack
  module OAuth2
    class Server

      class Client
        
        CouchPotato::Config.validation_framework = :active_model
        include CouchPotato::Persistence
        
        property :display_name
        property :link
        property :image_url
        property :redirect_uri
        property :notes
        property :scope
        property :revoked
        property :secret
        
        view :by_id, :key =>  :_id
        
        
        before_destroy :destroy_dependent
        
        def scope=(_scope)
          super Server::Utils.normalize_scope(_scope)
        end
        
        def redirect_uri=(_uri)
          if _uri
            super Server::Utils.parse_redirect_uri(_uri).to_s 
          else
            super nil
          end
        end
        
        def revoke!
          self.revoked = Time.now.to_i
          database.save self, false
          
          dependent_objects.each do |object|
            object.revoked = revoked
            database.save object, false
          end
        end
        
        private
        
        def destroy_dependent
          dependent_objects.each do |object|
            database.destroy object
          end
        end
        
        def dependent_objects
          [AuthRequest, AccessGrant, AccessToken].map do |klass|
            database.view(klass.by_client_id(id))
          end.flatten
        end

          # Lookup client by ID, display name or URL.
          # def lookup(field)
          #   id = BSON::ObjectId(field.to_s)
          #   Server.new_instance self, collection.find_one(id)
          # rescue BSON::InvalidObjectId
          #   Server.new_instance self, collection.find_one({ :display_name=>field }) || collection.find_one({ :link=>field })
          # end
      end
    end
  end
end
