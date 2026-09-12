module fetch

fn test_request_binding_enum_conversions() {
	assert referrer_policy_to_bindings('strict-origin') == 'strict-origin'
	assert referrer_policy_from_bindings('same-origin') == 'same-origin'
	assert request_destination_to_bindings(none) == ''
	assert request_destination_to_bindings(Destination.audio_worklet) == 'audioworklet'
	assert request_destination_to_bindings(Destination.text) == 'text'

	for mode in [Mode.same_origin, .cors, .no_cors, .navigate] {
		assert request_mode_to_bindings(mode) == mode
		assert request_mode_from_bindings(mode) == mode
	}
	for credentials in [CredentialsMode.omit, .same_origin, .include] {
		assert request_credentials_to_bindings(credentials) == credentials
		assert request_credentials_from_bindings(credentials) == credentials
	}
	for cache in [CacheMode.default, .no_store, .reload, .no_cache, .force_cache, .only_if_cached] {
		assert request_cache_to_bindings(cache) == cache
		assert request_cache_from_bindings(cache) == cache
	}
	for redirect in [RedirectMode.follow, .error, .manual] {
		assert request_redirect_to_bindings(redirect) == redirect
		assert request_redirect_from_bindings(redirect) == redirect
	}
	for priority in [Priority.high, .low, .auto] {
		assert request_priority_from_bindings(priority) == priority
	}
}

fn test_response_binding_enum_conversion() {
	for response_type in [ResponseType.basic, .cors, .default, .error, .opaque, .opaque_redirect] {
		assert response_type_to_bindings(response_type) == response_type
	}
}
