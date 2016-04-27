# v2.2.0

* resolve 'own' token to CONJUR_ACCOUNT env var
* add #optional paths to Conjur::Rack authenticator
	
# v2.1.0

* Add handling for `Conjur-Audit-Roles` and `Conjur-Audit-Resources`

# v2.0.0

* Change `global_sudo?` to `global_elevate?`

# v1.4.0

* Add `validated_global_privilege` helper function to get the global privilege, if any, which has been submitted with the request and verified by the Conjur server.

# v1.3.0

* Add handling for `X-Forwarded-For` and `X-Conjur-Privilege`
