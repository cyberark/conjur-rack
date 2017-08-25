require 'rubygems'
$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
$:.unshift File.join(File.dirname(__FILE__), "lib")

# Allows loading of an environment config based on the environment
require 'rspec'
require 'rspec/its'
require 'securerandom'

RSpec.configure do |config|
end

RSpec.shared_context "with authenticator" do
  let(:options) { {} }
  let(:app) { double(:app) }
  let(:authenticator) { Conjur::Rack::Authenticator.new(app, options) }
  let(:call) { authenticator.call env }
end

RSpec.shared_context "with authorization" do
  include_context "with authenticator"
  let(:token_signer) { "authn:someacc" }
  let(:audit_resources) { nil }
  let(:privilege) { nil }
  let(:remote_ip) { nil }
  let(:audit_roles) { nil }

  before do
    allow(app).to receive(:call) { Conjur::Rack.user }
    slosilo_class = class_double('Slosilo')
    stub_const('Slosilo', slosilo_class)
    allow(slosilo_class).to receive(:new).and_return(Module.new)
    allow(Slosilo).to receive(:token_signer).and_return(token_signer)
  end

  let(:env) do
    {
      'HTTP_AUTHORIZATION' => "Token token=\"#{basic_64}\""
    }.tap do |e|
      e['HTTP_X_CONJUR_PRIVILEGE'] = privilege if privilege
      e['HTTP_X_FORWARDED_FOR'] = remote_ip if remote_ip
      e['HTTP_CONJUR_AUDIT_ROLES'] = audit_roles if audit_roles
      e['HTTP_CONJUR_AUDIT_RESOURCES'] = audit_resources if audit_resources
    end
  end

  let(:basic_64) { Base64.strict_encode64(token.to_json) }
  let(:token) { { "data" => "foobar" } }
end
