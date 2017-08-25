require 'spec_helper'

require 'conjur/rack/authenticator'

describe Conjur::Rack::Authenticator do
  describe "#call" do
    include_context "with authenticator"
    context "to an unprotected path" do
      let(:except) { [ /^\/foo/ ] }
      let(:env) { { 'SCRIPT_NAME' => '', 'PATH_INFO' => '/foo/bar' } }
      before {
        options[:except] = except
        expect(app).to receive(:call).with(env).and_return app
      }
      context "without authorization" do
        it "proceeds" do
          expect(call).to eq(app)
          expect(Conjur::Rack.identity?).to be(false)
        end
      end
      context "with authorization" do
        include_context "with authorization"
        it "ignores the authorization" do
          expect(call).to eq(app)
          expect(Conjur::Rack.identity?).to be(false)
        end
      end
    end

    context "to a protected path" do
      let(:env) { { 'SCRIPT_NAME' => '/pathname' } }
      context "without authorization" do
        it "returns a 401 error" do
          expect(call).to eq([401, {"Content-Type"=>"text/plain", "Content-Length"=>"21"}, ["Authorization missing"]])
        end
      end
      context "with Conjur authorization" do
        include_context "with authorization"
        context "of a valid token" do
          it 'launches app' do
            expect(app).to receive(:call).with(env).and_return app
            expect(call).to eq(app)
          end
        end
        context "of an invalid token" do
          it "returns a 401 error" do
            allow(Slosilo).to receive(:token_signer).and_return(nil)
            expect(call).to eq([401, {"Content-Type"=>"text/plain", "Content-Length"=>"27"}, ["Unauthorized: Invalid token"]])
          end
        end
        context "of a token invalid for authn" do
          it "returns a 401 error" do
            allow(Slosilo).to receive(:token_signer).and_return('a-totally-different-key')
            expect(call).to eq([401, {"Content-Type"=>"text/plain", "Content-Length"=>"27"}, ["Unauthorized: Invalid token"]])
          end
        end
        context "of 'own' token" do
          it "returns ENV['CONJUR_ACCOUNT']" do
            expect(ENV).to receive(:[]).with("CONJUR_ACCOUNT").and_return("test-account")
            expect(app).to receive(:call) do |*args|
              expect(Conjur::Rack.identity?).to be(true)
              expect(Conjur::Rack.user.account).to eq('test-account')
              :done
            end
            allow(Slosilo).to receive(:token_signer).and_return('own')
            expect(call).to eq(:done)
          end
          it "requires ENV['CONJUR_ACCOUNT']" do
            expect(ENV).to receive(:[]).with("CONJUR_ACCOUNT").and_return(nil)
            allow(Slosilo).to receive(:token_signer).and_return('own')
            expect(call).to eq([401, {"Content-Type"=>"text/plain", "Content-Length"=>"27"}, ["Unauthorized: Invalid token"]])
          end
        end
      end

      context "with junk in token" do
        let(:env) { { 'HTTP_AUTHORIZATION' => 'Token token="open sesame"' } }
        it "returns 401" do
          expect(call).to eq([401, {"Content-Type"=>"text/plain", "Content-Length"=>"29"}, ["Malformed authorization token"]])
        end
      end

      context "with JSON junk in token" do
        let(:env) { { 'HTTP_AUTHORIZATION' => 'Token token="eyJmb28iOiAiYmFyIn0="' } }
        before do
          slosilo_class = class_double('Slosilo')
          stub_const('Slosilo', slosilo_class)
          allow(slosilo_class).to receive(:new).and_return(Module.new)
          allow(Slosilo).to receive(:token_signer).and_return(nil)
        end

        it "returns 401" do
            expect(call).to eq([401, {"Content-Type"=>"text/plain", "Content-Length"=>"27"}, ["Unauthorized: Invalid token"]])
        end
      end
    end
    context "to an optional path" do
      let(:optional) { [ /^\/foo/ ] }
      let(:env) { { 'SCRIPT_NAME' => '', 'PATH_INFO' => '/foo/bar' } }
      before {
        options[:optional] = optional
      }
      context "without authorization" do
        it "proceeds" do
          expect(app).to receive(:call) do |*args|
            expect(Conjur::Rack.identity?).to be(false)
            :done
          end
          expect(call).to eq(:done)
        end
      end
      context "with authorization" do
        include_context "with authorization"
        it "processes the authorization" do
          expect(app).to receive(:call) do |*args|
            expect(Conjur::Rack.identity?).to be(true)
            :done
          end
          expect(call).to eq(:done)
        end
      end
    end
  end
end
