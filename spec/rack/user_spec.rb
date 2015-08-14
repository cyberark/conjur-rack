require 'spec_helper'

describe Conjur::Rack::User do
  let(:login){ 'admin' }
  let(:token){ {'data' => login} }
  let(:account){ 'acct' }
  let(:privilege) { nil }
  let(:remote_ip) { nil }
  
  subject{ described_class.new token, account, privilege, remote_ip }
  
  its(:token){ should == token }
  its(:account){ should == account }
  its(:conjur_account){ should == account }
  its(:login){ should == token['data'] }
  
  it "aliases setter for account to conjur_account" do
    subject.conjur_account = "changed!"
    subject.account.should == "changed!"
  end
  
  describe '#new_assocation' do
    let(:associate){ Class.new }
    let(:params){{foo: 'bar'}}
    it "calls cls.new with params including userid: login" do
      associate.should_receive(:new).with(params.merge(userid: subject.login))
      subject.new_association(associate, params)
    end
  end
  
  describe '#roleid' do
    let(:login){ tokens.join('/') }
    context "when login contains one token 'foobar'" do
      let(:tokens){ ['foobar'] }
      its(:roleid){ should == "#{account}:user:#{login}" } 
    end
    context "when login contains tokens ['foo', 'bar']" do
      let(:tokens){ ["foos", "bar"] }
      its(:roleid){ should == "#{account}:#{tokens[0]}:#{tokens[1]}"}
    end
    context "when login contains tokens ['foo','bar','baz']" do
      let(:tokens){ ['foo', 'bar', 'baz'] }
      its(:roleid){ should == "#{account}:#{tokens[0]}:#{tokens[1]}/#{tokens[2]}" }
    end
  end
  
  describe '#role' do
    let(:roleid){ 'the role id' }
    let(:api){ double('conjur api') }
    before do
      subject.stub(:roleid).and_return roleid
      subject.stub(:api).and_return api
    end
    
    it 'passes roleid to api.role' do
      api.should_receive(:role).with(roleid).and_return 'the role'
      subject.role.should == 'the role'
    end
  end
  
  describe "#global_reveal?" do
    context "with global privilege" do
      let(:privilege) { "reveal" }
      let(:api){ Conjur::API.new_from_token "the-token" }
      before do
        subject.stub(:api).and_return api
      end
      it "checks the API function global_privilege_permitted?" do
        api.should_receive(:resource).with("!:!:conjur").and_return resource = double(:resource)
        resource.should_receive(:permitted?).with("reveal").and_return true
        expect(subject.global_reveal?).to be_true
        # The result is cached
        subject.global_reveal?
      end
    end
    context "without a global privilege" do
      it "simply returns nil" do
        expect(subject.global_reveal?).to be_false
      end
    end
  end
  
  describe '#api' do
    context "when given a class" do
      let(:cls){ double('API class') }
      it "calls cls.new_from_token with its token" do
        cls.should_receive(:new_from_token).with(token).and_return 'the api'
        subject.api(cls).should == 'the api'
      end
    end
    context 'when not given args' do
      shared_examples_for "builds the api" do
        specify {
          subject.api.should == 'the api'
        }
      end
      
      context "with no extra args" do
        before {
          Conjur::API.should_receive(:new_from_token).with(token).and_return 'the api'
        }
        it_should_behave_like "builds the api"
      end
      context "with remote_ip" do
        let(:remote_ip) { "the-ip" }
        before {
          Conjur::API.should_receive(:new_from_token).with(token, 'the-ip').and_return 'the api'
        }
        it_should_behave_like "builds the api"
      end
      context "with privilege" do
        let(:privilege) { "sudo" }
        before {
          Conjur::API.should_receive(:new_from_token).with(token).and_return api = double(:api)
          expect(api).to receive(:with_privilege).with("sudo").and_return('the api')
        }
        it_should_behave_like "builds the api"
      end
    end
  end
end