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
          expect(app).to receive(:call).with(env).and_return app
          expect(call).to eq(app)
        end

        context 'Authable provides module method conjur_user' do

          let(:stubuser) { "some value" }

          context 'when called in app context' do
            it 'returns User built from token' do
              allow(app).to receive(:call) { Conjur::Rack.user }
              expect(Conjur::Rack::User).to receive(:new).
                with(token, sample_account).and_return(stubuser)
              expect(Conjur::Rack).to receive(:user).and_call_original
              expect(call).to eq(stubuser)      
            end
          end

          context 'called out of app context' do
            it { expect { Conjur::Rack.user }.to raise_error }
          end
        end
      end
      context "of an invalid token" do
        it "returns a 401 error" do
          Slosilo.stub token_signer: nil
          expect(call).to eq([401, {"Content-Type"=>"text/plain", "Content-Length"=>"26"}, ["Unathorized: Invalid token"]])
        end
      end
      context "of a token invalid for authn" do
        it "returns a 401 error" do
          Slosilo.stub token_signer: 'a-totally-different-key'
          expect(call).to eq([401, {"Content-Type"=>"text/plain", "Content-Length"=>"26"}, ["Unathorized: Invalid token"]])
        end
      end
    end
  end
  context "without authorization" do
    context "to a protected path" do
      let(:env) { { 'SCRIPT_NAME' => '/pathname' } }
      it "returns a 401 error" do
        expect(call).to eq([401, {"Content-Type"=>"text/plain", "Content-Length"=>"21"}, ["Authorization missing"]])
      end
    end
    context "to an unprotected path" do
      let(:except) { [ /^\/foo/ ] }
      let(:env) { { 'SCRIPT_NAME' => '', 'PATH_INFO' => '/foo/bar' } }
      it "proceeds" do
        options[:except] = except
        expect(app).to receive(:call).with(env).and_return app
        expect(call).to eq(app)
      end
    end
  end
end
