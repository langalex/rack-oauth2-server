module Rack
  module OAuth2
    class AuthServer

      class Client

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

        def scope=(value)
          super AuthServer::Utils.normalize_scope(value)
        end

        def revoke!
          database.save self, false do |c|
            c.revoked = Time.now.to_i
          end

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
          #   AuthServer.new_instance self, collection.find_one(id)
          # rescue BSON::InvalidObjectId
          #   AuthServer.new_instance self, collection.find_one({ :display_name=>field }) || collection.find_one({ :link=>field })
          # end
      end
    end
  end
end
