require 'conjur/api'

module Conjur
  module Rack
    # Token data can be a string (which is the user login), or a Hash.
    # If it's a hash, it should contain the user login keyed by the string 'login'.
    # The rest of the payload is available as +attributes+.
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
        cls.new_from_token(token)
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