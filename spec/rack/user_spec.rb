require 'spec_helper'

describe Conjur::Rack::User do
  let(:login){ 'admin' }
  let(:token){ {'data' => login} }
  let(:account){ 'acct' }
  
  subject{ described_class.new token, account }
  
  its(:token){ should == token }
  its(:account){ should == account }
  its(:login){ should == token['data'] }
  
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
  
  describe '#api' do
    context "when given a class" do
      let(:cls){ double('API class') }
      it "calls cls.new_from_token with its token" do
        cls.should_receive(:new_from_token).with(token).and_return 'the api'
        subject.api(cls).should == 'the api'
      end
    end
    context 'when not given args' do
      it 'uses Conjur::API.new_from_token' do
        Conjur::API.should_receive(:new_from_token).with(token).and_return 'the api'
        subject.api.should == 'the api'
      end
    end
  end
end