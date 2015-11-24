require "conjur/rack/user"

module Conjur
  module Rack
    def self.identity?
      !Thread.current[:conjur_rack_identity].nil?
    end
    
    def self.user
      User.new(identity[0], identity[1], privilege, remote_ip)
    end
    
    def self.identity
      Thread.current[:conjur_rack_identity] or raise "No Conjur identity for current request"
    end
    
    def self.privilege
      Thread.current[:conjur_rack_privilege]
    end
    
    def self.remote_ip
      Thread.current[:conjur_rack_remote_ip]
    end
  
    class Authenticator
      class AuthorizationError < SecurityError
      end
      class SignatureError < SecurityError
      end
      
      attr_reader :app, :options
      
      # +options+:
      # :except :: a list of request path patterns for which to skip authentication.
      # :optional :: request path patterns for which authentication is optional.
      def initialize app, options = {}
        @app = app
        @options = options
      end

      # threadsafe accessors, values are established explicitly below
      def env; Thread.current[:rack_env] ; end
      def token; Thread.current[:conjur_rack_token] ; end
      def account; Thread.current[:conjur_rack_account]; end
      def privilege; Thread.current[:conjur_rack_privilege]; end
      def remote_ip; Thread.current[:conjur_rack_remote_ip]; end
 
      def call rackenv
        # never store request-specific variables as application attributes 
        Thread.current[:rack_env] = rackenv
        if authenticate?
          begin
            identity = verify_authorization_and_get_identity # [token, account]
            if identity
              Thread.current[:conjur_rack_token] = identity[0]
              Thread.current[:conjur_rack_account] = identity[1]
              Thread.current[:conjur_rack_identity] = identity
              Thread.current[:conjur_rack_privilege] = conjur_privilege
              Thread.current[:conjur_rack_remote_ip] = remote_ip
            end
          rescue SecurityError, RestClient::Exception
            return error 401, $!.message
          end
        end
        begin
          @app.call rackenv
        ensure
          Thread.current[:rack_env] = nil
          Thread.current[:conjur_rack_identity] = nil
          Thread.current[:conjur_rack_token] = nil
          Thread.current[:conjur_rack_account] = nil
          Thread.current[:conjur_rack_privilege] = nil
          Thread.current[:conjur_rack_remote_ip] = nil
        end
      end
      
      protected
      
      def validate_token_and_get_account token
        failure = SignatureError.new("Unathorized: Invalid token")
        raise failure unless (signer = Slosilo.token_signer token)
        raise failure unless signer =~ /\Aauthn:(.+)\z/
        return $1
      end
      
      def error status, message
        [status, { 'Content-Type' => 'text/plain', 'Content-Length' => message.length.to_s }, [message] ]
      end
      
      def verify_authorization_and_get_identity
        if authorization.to_s[/^Token token="(.*)"/]
          token = JSON.parse(Base64.decode64($1))
          account = validate_token_and_get_account(token)
          return [token, account]
        else
          if optional_paths.find{|p| p.match(path)}.nil?
            raise AuthorizationError.new("Authorization missing")
          else
            nil
          end
        end
      end
      
      def authenticate?
        if options[:except]
          options[:except].find{|p| p.match(path)}.nil?
        else
          true
        end
      end
      
      def optional_paths
        options[:optional] || []
      end

      def conjur_privilege
        env['HTTP_X_CONJUR_PRIVILEGE']
      end
      
      def authorization
        env['HTTP_AUTHORIZATION']
      end
      
      def remote_ip
        require 'rack/request'
        ::Rack::Request.new(env).ip
      end
      
      def path
        [ env['SCRIPT_NAME'], env['PATH_INFO'] ].join
      end
    end
  end
end
