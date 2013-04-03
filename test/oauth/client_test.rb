require "test/setup"

class ClientTest < Test::Unit::TestCase

  context "#redirect_uri=" do
    should "accept a blank redirect uri" do
      client = Rack::OAuth2::AuthServer::Client.new(:redirect_uri => '')
      assert_nil client.redirect_uri
    end

    should "raise an error if uri is not absolute" do
      assert_raise(Rack::OAuth2::AuthServer::InvalidRequestError) {
        client = Rack::OAuth2::AuthServer::Client.new(:redirect_uri => '/redirect')
      }
    end
  end
end
