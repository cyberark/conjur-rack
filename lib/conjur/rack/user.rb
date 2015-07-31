require 'conjur/api'

module Conjur
  module Rack
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

      def login
        token["data"] or raise "No data field in token"
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
    end
  end
end
