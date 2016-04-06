require 'conjur/api'

module Conjur
  module Rack
    # Token data can be a string (which is the user login), or a Hash.
    # If it's a hash, it should contain the user login keyed by the string 'login'.
    # The rest of the payload is available as +attributes+.
    class User
      attr_accessor :token, :account, :privilege, :remote_ip
      
      def initialize(token, account, privilege = nil, remote_ip = nil)
        @token = token
        @account = account
        @privilege = privilege
        @remote_ip = remote_ip
      end
      
      # This file was accidently calling account conjur_account,
      # I'm adding an alias in case that's going on anywhere else.
      # -- Jon
      alias :conjur_account :account
      alias :conjur_account= :account=
      
      def new_association(cls, params = {})
        cls.new params.merge({userid: login})
      end
      
      # Returns the global privilege which was present on the request, if and only
      # if the user actually has that privilege.
      #
      # Returns nil if no global privilege was present in the request headers, 
      # or if a global privilege was present in the request headers, but the user doesn't
      # actually have that privilege according to the Conjur server.
      def validated_global_privilege
        unless @validated_global_privilege
          @privilege = nil if @privilege && !api.global_privilege_permitted?(@privilege)
          @validated_global_privilege = true
        end
        @privilege
      end
      
      # True if and only if the user has valid global 'reveal' privilege.
      def global_reveal?
        validated_global_privilege == "reveal"
      end
      
      # True if and only if the user has valid global 'elevate' privilege.
      def global_elevate?
        validated_global_privilege == "elevate"
      end
      
      def login
        parse_token

        @login
      end

      def attributes
        parse_token

        @attributes || {}
      end
      
      def roleid
        tokens = login.split('/')
        role_kind, roleid = if tokens.length == 1
          [ 'user', login ]
        else
          [ tokens[0], tokens[1..-1].join('/') ]
        end
        [ account, role_kind, roleid ].join(':')
      end
      
      def role
        api.role(roleid)
      end
      
      def api(cls = Conjur::API)
        args = [ token ]
        args.push remote_ip if remote_ip
        api = cls.new_from_token(*args)
        if privilege
          api.with_privilege(privilege)
        else
          api
        end
      end

      protected

      def parse_token
        return if @login

        data = token['data'] or raise "No data field in token"
        if data.is_a?(String)
          @login = token['data']
        elsif data.is_a?(Hash)
          @attributes = token['data'].clone
          @login = @attributes.delete('login') or raise "No 'login' field in token data"
        else
          raise "Expecting String or Hash token data, got #{data.class.name}"
        end
      end
    end
  end
end
