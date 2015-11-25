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
    
  shared_context "with authorization" do
    before {
      stub_const 'Slosilo', Module.new 
      Slosilo.stub token_signer: token_signer
    }
    let(:env) {
      {
        'HTTP_AUTHORIZATION' => "Token token=\"#{basic_64}\""
      }.tap do |e|
        e['HTTP_X_CONJUR_PRIVILEGE'] = privilege if privilege
        e['HTTP_X_FORWARDED_FOR'] = remote_ip if remote_ip
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
          app.should_receive(:call).with(env).and_return app
          call.should == app
        end

        context 'Authable provides module method conjur_user' do
          let(:stubuser) { "some value" }
          before {
            app.stub(:call) { Conjur::Rack.user }
          }

          context 'when called in app context' do
            let(:invoke) {
              Conjur::Rack::User.should_receive(:new).
                with(token, 'someacc', privilege, remote_ip).
                and_return(stubuser)
              Conjur::Rack.should_receive(:user).and_call_original
              call
            }
            
            shared_examples_for 'returns User built from token' do
              specify { 
                invoke.should == stubuser      
              }
            end
            
            it_should_behave_like 'returns User built from token'
            
            context 'with X-Conjur-Privilege' do
              let(:privilege) { "sudo" }
              it_should_behave_like 'returns User built from token'
            end
            
            context 'with X-Forwarded-For' do
              let(:remote_ip) { "66.0.0.1" }
              it_should_behave_like 'returns User built from token'
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
      context "of 'own' token" do
        it "returns ENV['CONJUR_ACCOUNT']" do
          expect(ENV).to receive(:[]).with("CONJUR_ACCOUNT").and_return("test-account")
          expect(app).to receive(:call) do |*args|
            expect(Conjur::Rack.identity?).to be(true)
            expect(Conjur::Rack.user.account).to eq('test-account')
            :done
          end
          Slosilo.stub token_signer: 'own'
          call.should == :done
        end
        it "requires ENV['CONJUR_ACCOUNT']" do
          expect(ENV).to receive(:[]).with("CONJUR_ACCOUNT").and_return(nil)
          Slosilo.stub token_signer: 'own'
          call.should == [401, {"Content-Type"=>"text/plain", "Content-Length"=>"26"}, ["Unathorized: Invalid token"]]
        end
      end
    end
  end
  context "to a protected path" do
    context "without authorization" do
      let(:env) { { 'SCRIPT_NAME' => '/pathname' } }
      it "returns a 401 error" do
        call.should == [401, {"Content-Type"=>"text/plain", "Content-Length"=>"21"}, ["Authorization missing"]]
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
        call.should == :done
      end
    end
    context "with authorization" do
      include_context "with authorization"
      it "processes the authorization" do
        expect(app).to receive(:call) do |*args|
          expect(Conjur::Rack.identity?).to be(true)
          :done
        end
        call.should == :done
      end
    end
  end
  context "to an unprotected path" do
    let(:except) { [ /^\/foo/ ] }
    let(:env) { { 'SCRIPT_NAME' => '', 'PATH_INFO' => '/foo/bar' } }
    before {
      options[:except] = except
      app.should_receive(:call).with(env).and_return app
    }
    context "without authorization" do
      it "proceeds" do
        call.should == app
        expect(Conjur::Rack.identity?).to be(false)
      end
    end
    context "with authorization" do
      include_context "with authorization"
      it "ignores the authorization" do
        call.should == app
        expect(Conjur::Rack.identity?).to be(false)
      end
    end
  end
end
