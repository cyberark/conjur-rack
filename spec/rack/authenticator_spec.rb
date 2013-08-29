require 'spec_helper'

require 'conjur/rack/authenticator'

describe Conjur::Rack::Authenticator do
  let(:app) { double(:app) }
  let(:options) { {} }
  let(:authenticator) { Conjur::Rack::Authenticator.new(app, options) }
  let(:call) { authenticator.call env }
  
  context "#call" do
    context "with Conjur authorization" do
      before{ stub_const 'Slosilo', Module.new }
      let(:env) {
        {
          'HTTP_AUTHORIZATION' => "Token token=\"#{basic_64}\""
        }
      }
      let(:basic_64) { Base64.strict_encode64(token.to_json) }
      let(:token) { { "data" => "foobar" } }
      let(:sample_account) { "someacc" }

      context "of a valid token" do
          
        before(:each) {
          Slosilo.stub token_signer: 'authn:'+sample_account
        }

        it 'launches app' do
          app.should_receive(:call).with(env).and_return app
          call.should == app
        end

        context 'Authable provides module method conjur_user' do

          let(:stubuser) { "some value" }

          context 'when called in app context' do
            it 'returns User built from token' do
              app.stub(:call) { Conjur::Rack.user }
              Conjur::Rack::User.should_receive(:new).
                with(token, sample_account).and_return(stubuser)
              Conjur::Rack.should_receive(:user).and_call_original
              call.should == stubuser      
            end
          end

          context 'called out of app context' do
            it { lambda { Conjur::Rack.user }.should raise_error }
          end
        end
      end
      context "of an invalid token" do
        it "returns a 401 error" do
          Slosilo.stub token_signer: nil
          call.should == [401, {"Content-Type"=>"text/plain", "Content-Length"=>"26"}, ["Unathorized: Invalid token"]]
        end
      end
      context "of a token invalid for authn" do
        it "returns a 401 error" do
          Slosilo.stub token_signer: 'a-totally-different-key'
          call.should == [401, {"Content-Type"=>"text/plain", "Content-Length"=>"26"}, ["Unathorized: Invalid token"]]
        end
      end
    end
  end
  context "without authorization" do
    context "to a protected path" do
      let(:env) { { 'SCRIPT_NAME' => '/pathname' } }
      it "returns a 401 error" do
        call.should == [401, {"Content-Type"=>"text/plain", "Content-Length"=>"21"}, ["Authorization missing"]]
      end
    end
    context "to an unprotected path" do
      let(:except) { [ /^\/foo/ ] }
      let(:env) { { 'SCRIPT_NAME' => '', 'PATH_INFO' => '/foo/bar' } }
      it "proceeds" do
        options[:except] = except
        app.should_receive(:call).with(env).and_return app
        call.should == app
      end
    end
  end
end
