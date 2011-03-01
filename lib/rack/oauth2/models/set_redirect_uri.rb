module Rack
  module OAuth2
    module SetRedirectUri
      def self.included(base)
        base.class_eval do
          before_create :set_redirect_uri
        end
      end
  
      private
  
      def set_redirect_uri
        self.redirect_uri ||= client.redirect_uri
      end
    end
  end
end