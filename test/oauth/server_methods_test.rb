require "test/setup"


# Tests the Server API
class ServerTest < Test::Unit::TestCase
  def setup
    super
  end

  context "get_auth_request" do
    setup do
      @request = AuthServer::AuthRequest.new(:database => DATABASE, :client_id => client.id, :scope => client.scope.join(" "),
        :redirect_uri => client.redirect_uri, :token => "token")
      DATABASE.save @request, false
     end

    should "return authorization request" do
      assert_equal @request.id, AuthServer.get_auth_request(@request.id).id
    end

    should "return nil if no request found" do
      assert !AuthServer.get_auth_request("4ce2488e3321e87ac1000004")
    end
  end


  context "get_client" do
    should "return authorization request" do
      assert_equal client.display_name, AuthServer.get_client(client.id).display_name
    end

    should "return nil if no client found" do
      assert !AuthServer.get_client("4ce2488e3321e87ac1000004")
    end
  end


  context "register" do
    context "no client ID" do
      setup do
        @client = AuthServer.register(:display_name=>"MyApp", :link=>"http://example.org", :image_url=>"http://example.org/favicon.ico",
                                  :redirect_uri=>"http://example.org/oauth/callback", :scope=>%w{read write})
      end

      should "create new client" do
        assert_equal 2, DATABASE.view(AuthServer::Client.by_id(:reduce => true))
        assert_contains DATABASE.view(AuthServer::Client.by_id).map(&:id), @client.id
      end

      should "set display name" do
        assert_equal "MyApp", AuthServer.get_client(@client.id).display_name
      end

      should "set link" do
        assert_equal "http://example.org", AuthServer.get_client(@client.id).link
      end

      should "set image URL" do
        assert_equal "http://example.org/favicon.ico", AuthServer.get_client(@client.id).image_url
      end

      should "set redirect URI" do
        assert_equal "http://example.org/oauth/callback", AuthServer.get_client(@client.id).redirect_uri
      end

      should "set scope" do
        assert_equal %w{read write}, AuthServer.get_client(@client.id).scope
      end

      should "assign client an ID" do
        assert_match /[0-9a-f]{24}/, @client.id.to_s
      end

      should "assign client a secret" do
        assert_match /[0-9a-f]{64}/, @client.secret
      end
    end

  context "with client ID" do

      context "no such client" do
        setup do
          @client = AuthServer.register(:id=>"4ce24c423321e88ac5000015", :secret=>"foobar", :display_name=>"MyApp")
        end

        should "create new client" do
          assert_equal 2, DATABASE.view(AuthServer::Client.by_id(:reduce => true))
        end

        should "should assign it the client identifier" do
          assert_equal "4ce24c423321e88ac5000015", @client.id.to_s
        end

        should "should assign it the client secret" do
          assert_equal "foobar", @client.secret
        end

        should "should assign it the other properties" do
          assert_equal "MyApp", @client.display_name
        end
      end

      context "existing client" do
        setup do
          AuthServer.register(:id=>"4ce24c423321e88ac5000015", :secret=>"foobar", :display_name=>"MyApp")
          @client = AuthServer.register(:id=>"4ce24c423321e88ac5000015", :secret=>"foobar", :display_name=>"Rock Star")
        end

        should "not create new client" do
          assert_equal 2, DATABASE.view(AuthServer::Client.by_id(:reduce => true))
        end

        should "should not change the client identifier" do
          assert_equal "4ce24c423321e88ac5000015", @client.id.to_s
        end

        should "should not change the client secret" do
          assert_equal "foobar", @client.secret
        end

        should "should change all the other properties" do
          assert_equal "Rock Star", @client.display_name
        end
      end

      context "secret mismatch" do
        setup do
          AuthServer.register(:id=>"4ce24c423321e88ac5000015", :secret=>"foobar", :display_name=>"MyApp")
        end

        should "raise error" do
          assert_raises RuntimeError do
            AuthServer.register(:id=>"4ce24c423321e88ac5000015", :secret=>"wrong", :display_name=>"MyApp")
          end
        end
      end

    end
  end

  context "access_grant" do
    setup do
      code = AuthServer.access_grant("Batman", client.id, %w{read})
      basic_authorize client.id, client.secret
      post "/oauth/access_token", :scope=>"read", :grant_type=>"authorization_code", :code=>code, :redirect_uri=>client.redirect_uri
      @token = JSON.parse(last_response.body)["access_token"]
    end

    should "resolve into an access token" do
      assert AuthServer.get_access_token(@token)
    end

    should "resolve into access token with grant identity" do
      assert_equal "Batman", AuthServer.get_access_token(@token).identity
    end

    should "resolve into access token with grant scope" do
      assert_equal %w{read}, AuthServer.get_access_token(@token).scope
    end

    should "resolve into access token with grant client" do
      assert_equal client.id, AuthServer.get_access_token(@token).client_id
    end

    context "with no scope" do
      setup { @code = AuthServer.access_grant("Batman", client.id) }

      should "pick client scope" do
        assert_equal %w{oauth-admin read write}, DATABASE.view(AuthServer::AccessGrant.by_code(@code)).first.scope
      end
    end

    context "no expiration" do
      setup do
        @code = AuthServer.access_grant("Batman", client.id)
      end

      should "not expire in a minute" do
        Timecop.travel 60 do
          basic_authorize client.id, client.secret
          post "/oauth/access_token", :scope=>"read", :grant_type=>"authorization_code", :code=>@code, :redirect_uri=>client.redirect_uri
          assert_equal 200, last_response.status
        end
      end

      should "expire after 5 minutes" do
        Timecop.travel 300 do
          basic_authorize client.id, client.secret
          post "/oauth/access_token", :scope=>"read", :grant_type=>"authorization_code", :code=>@code, :redirect_uri=>client.redirect_uri
          assert_equal 400, last_response.status
        end
      end
    end

    context "expiration set" do
      setup do
        @code = AuthServer.access_grant("Batman", client.id, nil, 1800)
      end

      should "not expire prematurely" do
        Timecop.travel 1750 do
          basic_authorize client.id, client.secret
          post "/oauth/access_token", :scope=>"read", :grant_type=>"authorization_code", :code=>@code, :redirect_uri=>client.redirect_uri
          assert_equal 200, last_response.status
        end
      end

      should "expire after specified seconds" do
        Timecop.travel 1800 do
          basic_authorize client.id, client.secret
          post "/oauth/access_token", :scope=>"read", :grant_type=>"authorization_code", :code=>@code, :redirect_uri=>client.redirect_uri
          assert_equal 400, last_response.status
        end
      end
    end

  end


  context "get_access_token" do
    setup { @token = AuthServer.token_for("Batman", client.id, %w{read}) }
    should "return authorization request" do
      assert_equal @token, AuthServer.get_access_token(@token).token
    end

    should "return nil if no client found" do
      assert !AuthServer.get_access_token("4ce2488e3321e87ac1000004")
    end

    context "with no scope" do
      setup { @token = AuthServer.token_for("Batman", client.id) }

      should "pick client scope" do
        assert_equal %w{oauth-admin read write}, DATABASE.view(AuthServer::AccessToken.by_token(@token)).first.scope
      end
    end
  end


  context "token_for" do
    setup { @token = AuthServer.token_for("Batman", client.id, %w{read write}) }

    should "return access token" do
      assert_match /[0-9a-f]{32}/, @token
    end

    should "associate token with client" do
      assert_equal client.id, AuthServer.get_access_token(@token).client_id
    end

    should "associate token with identity" do
      assert_equal "Batman", AuthServer.get_access_token(@token).identity
    end

    should "associate token with scope" do
      assert_equal %w{read write}, AuthServer.get_access_token(@token).scope
    end

    should "return same token for same parameters" do
      assert_equal @token, AuthServer.token_for("Batman", client.id, %w{write read})
    end

    should "return different token for different identity" do
      assert @token != AuthServer.token_for("Superman", client.id, %w{read write})
    end

    should "return different token for different client" do
      client = AuthServer.register(:display_name=>"MyApp")
      assert @token != AuthServer.token_for("Batman", client.id, %w{read write})
    end

    should "return different token for different scope" do
      assert @token != AuthServer.token_for("Batman", client.id, %w{read})
    end
  end


  context "list access tokens" do
    setup do
      @one = AuthServer.token_for("Batman", client.id, %w{read})
      @two = AuthServer.token_for("Superman", client.id, %w{read})
      @three = AuthServer.token_for("Batman", client.id, %w{write})
    end

    should "return all tokens for identity" do
      assert_contains AuthServer.list_access_tokens("Batman").map(&:token), @one
      assert_contains AuthServer.list_access_tokens("Batman").map(&:token), @three
    end

    should "not return tokens for other identities" do
      assert !AuthServer.list_access_tokens("Batman").map(&:token).include?(@two)
    end

  end

end
