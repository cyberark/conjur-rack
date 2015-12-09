require 'spec_helper'

describe Conjur::Rack::User do
  let(:login){ 'admin' }
  let(:token){ {'data' => login} }
  let(:account){ 'acct' }
  
  subject(:user) { described_class.new token, account }
  
  it 'provides field accessors' do
    expect(user.token).to eq token
    expect(user.account).to eq account
    expect(user.conjur_account).to eq account
    expect(user.login).to eq login
  end
  
  it "aliases setter for account to conjur_account" do
    subject.conjur_account = "changed!"
    expect(subject.account).to eq("changed!")
  end
  
  describe '#new_assocation' do
    let(:associate){ Class.new }
    let(:params){{foo: 'bar'}}
    it "calls cls.new with params including userid: login" do
      expect(associate).to receive(:new).with(params.merge(userid: subject.login))
      subject.new_association(associate, params)
    end
  end
  
  describe '#roleid' do
    let(:login){ tokens.join('/') }

    context "when login contains one token" do
      let(:tokens) { %w(foobar) }

      it "is expanded to account:user:token" do
        expect(subject.roleid).to eq "#{account}:user:foobar"
      end
    end

    context "when login contains two tokens" do
      let(:tokens) { %w(foo bar) }

      it "is expanded to account:first:second" do
        expect(subject.roleid).to eq "#{account}:foo:bar"
      end
    end

    context "when login contains three tokens" do
      let(:tokens) { %w(foo bar baz) }

      it "is expanded to account:first:second/third" do
        expect(subject.roleid).to eq "#{account}:foo:bar/baz"
      end
    end
  end
  
  describe '#role' do
    let(:roleid){ 'the role id' }
    let(:api){ double('conjur api') }
    before do
      allow(subject).to receive(:roleid).and_return roleid
      allow(subject).to receive(:api).and_return api
    end
    
    it 'passes roleid to api.role' do
      expect(api).to receive(:role).with(roleid).and_return 'the role'
      expect(subject.role).to eq('the role')
    end
  end
  
  describe '#api' do
    context "when given a class" do
      let(:cls){ double('API class') }
      it "calls cls.new_from_token with its token" do
        expect(cls).to receive(:new_from_token).with(token).and_return 'the api'
        expect(subject.api(cls)).to eq('the api')
      end
    end
    context 'when not given args' do
      it 'uses Conjur::API.new_from_token' do
        expect(Conjur::API).to receive(:new_from_token).with(token).and_return 'the api'
        expect(subject.api).to eq('the api')
      end
    end
  end
  
  describe "invalid type payload" do
    let(:token){ { "data" => :alice } }
    it "process the login and attributes" do
      expect{ subject.login  }.to raise_error("Expecting String or Hash token data, got Symbol")
    end
  end
  
  describe "hash payload" do
    let(:token){ { "data" => { "login" => "alice", "capabilities" => { "fry" => "bacon" } } } }

    it "process the login and attributes" do
      original_token = token.deep_dup

      expect(subject.login).to eq('alice')
      expect(subject.attributes).to eq({"capabilities" => { "fry" => "bacon" }})

      expect(token).to eq original_token
    end
  end
end
