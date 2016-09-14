require 'spec_helper'

require 'conjur/rack/authenticator'

describe Conjur::Rack::Authenticator do
  let(:app) { double(:app) }
  let(:options) { {} }
  let(:authenticator) { Conjur::Rack::Authenticator.new(app, options) }
  let(:call) { authenticator.call env }
  let(:privilege) { nil }
  let(:remote_ip) { nil }    
  let(:token_signer) { "authn:someacc" }
  let(:audit_roles) { nil }
  let(:audit_resources) { nil }
    
  shared_context "with authorization" do
    before {
      slosilo_class = class_double('Slosilo')
      stub_const('Slosilo', slosilo_class)
      allow(slosilo_class).to receive(:new).and_return(Module.new)
      allow(Slosilo).to receive(:token_signer).and_return(token_signer)
    }
    let(:env) {
      {
        'HTTP_AUTHORIZATION' => "Token token=\"#{basic_64}\""
      }.tap do |e|
        e['HTTP_X_CONJUR_PRIVILEGE'] = privilege if privilege
        e['HTTP_X_FORWARDED_FOR'] = remote_ip if remote_ip
        e['HTTP_CONJUR_AUDIT_ROLES'] = audit_roles if audit_roles
        e['HTTP_CONJUR_AUDIT_RESOURCES'] = audit_resources if audit_resources
      end
    }
    let(:basic_64) { Base64.strict_encode64(token.to_json) }
    let(:token) { { "data" => "foobar" } }
  end
  
  context "#call" do
    context "with Conjur authorization" do
      include_context "with authorization"

      context "of a valid token" do
          
        it 'launches app' do
          expect(app).to receive(:call).with(env).and_return app
          expect(call).to eq(app)
        end

        context 'Authable provides module method conjur_user' do
          let(:stubuser) { "some value" }
          before {
            allow(app).to receive(:call) { Conjur::Rack.user }
          }

          context 'when called in app context' do
            subject {
              expect(Conjur::Rack::User).to receive(:new)
                .with(token, 'someacc', {:privilege => privilege, :remote_ip => remote_ip, :audit_roles => audit_roles, :audit_resources => audit_resources})
                .and_return(stubuser)
              expect(Conjur::Rack).to receive(:user).and_call_original
              call
            }
            
            shared_examples_for 'returns User built from token' do
              it { should == stubuser }
            end
            
            it_should_behave_like 'returns User built from token'
            
            context 'with X-Conjur-Privilege' do
              let(:privilege) { "elevate" }
              it_should_behave_like 'returns User built from token'
            end
            
            context 'with X-Forwarded-For' do
              let(:remote_ip) { "66.0.0.1" }
              it_should_behave_like 'returns User built from token'
            end
            
            context 'with Conjur-Audit-Roles' do
              let (:audit_roles) { 'user%3Acook' }
              it_should_behave_like 'returns User built from token'
            end

            context 'with Conjur-Audit-Resources' do
              let (:audit_resources) { 'food%3Abacon' }
              it_should_behave_like 'returns User built from token'
            end

          end

          context 'called out of app context' do
            it { expect { Conjur::Rack.user }.to raise_error('No Conjur identity for current request') }
          end
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
  context "to a protected path" do
    context "without authorization" do
      let(:env) { { 'SCRIPT_NAME' => '/pathname' } }
      it "returns a 401 error" do
        expect(call).to eq([401, {"Content-Type"=>"text/plain", "Content-Length"=>"21"}, ["Authorization missing"]])
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
end
