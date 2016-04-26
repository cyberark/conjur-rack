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
        }.tap do |e|
          e['HTTP_X_CONJUR_PRIVILEGE'] = privilege if privilege
          e['HTTP_X_FORWARDED_FOR'] = remote_ip if remote_ip
          e['HTTP_CONJUR_AUDIT_ROLES'] = audit_roles if audit_roles
          e['HTTP_CONJUR_AUDIT_RESOURCES'] = audit_resources if audit_resources
        end
      }
      let(:basic_64) { Base64.strict_encode64(token.to_json) }
      let(:token) { { "data" => "foobar" } }
      let(:sample_account) { "someacc" }
      let(:privilege) { nil }
      let(:remote_ip) { nil }
      let(:audit_roles) { nil }
      let(:audit_resources) { nil }

      context "of a valid token" do
          
        before(:each) {
          allow(Slosilo).to receive(:token_signer).and_return('authn:'+sample_account)
        }

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
                .with(token, sample_account, {:privilege => privilege, :remote_ip => remote_ip, :audit_roles => audit_roles, :audit_resources => audit_resources})
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
