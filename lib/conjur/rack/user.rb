require 'conjur/api'

module Conjur
  module Rack
    User = Struct.new(:token, :account) do
      
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
        cls.new_from_token(token)
      end
    end
  end
end