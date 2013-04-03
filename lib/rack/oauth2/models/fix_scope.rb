module Rack
  module OAuth2
    module FixScope
      def self.included(base)
        base.class_eval do
          before_create :fix_scope
        end
      end

      private

      def fix_scope
        self.scope = AuthServer::Utils.normalize_scope(scope) & client.scope
      end
    end
  end
end
