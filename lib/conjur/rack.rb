require "conjur/rack/version"
require "conjur/rack/authenticator"
require "conjur/rack/path_prefix"
require 'ipaddr'

module ConjurRequest
  def trusted_proxy?(ip)
    if proxies
      proxies.any? { |p| p.include?(ip) }
    else
      super
    end
  end

  def proxies
    @proxies ||= (ENV['TRUSTED_PROXIES'] || '').split(',').collect { |cidr| IPAddr.new(cidr) }
  end
end

module Rack
  class Request
    prepend ConjurRequest
  end
end




    
