module webdriver

import x.json2

fn test_error_table_and_response_preserve_protocol_codes() {
	error_value := WebDriverError.from_code(.no_such_element, 'gone')
	assert error_value.http_status == 404
	assert error_value.code == 'no such element'
	protocol_error := failure(.unknown_method, 'bad verb').err or { panic('missing error') }
	assert protocol_error.http_status == 405
	assert !success('ok').is_error()
	with_data := WebDriverError.from_code_with_data(.unknown_error, 'details', json2.Any('payload'))
	data := with_data.data or { panic('missing data') }
	assert data is string
	assert data as string == 'payload'
}

fn test_timeout_deserialization_is_transactional_and_nullable() {
	configuration := deserialize_timeouts(json_value_from_text('{"script":12,"pageLoad":null,"ignored":-1}')) or {
		panic(err)
	}
	assert (configuration.script_timeout or { 0 }) == 12
	assert configuration.page_load_timeout == none
	deserialize_timeouts(json_value_from_text('{"implicit":-1}')) or {
		assert err.msg().contains('Invalid timeout')
		return
	}
	assert false
}

fn test_proxy_validation_checks_keys_types_and_schemes() {
	proxy := deserialize_proxy(json_value_from_text('{"proxyType":"manual","httpProxy":"http://localhost:8080","noProxy":["localhost"]}')) or {
		panic(err)
	}
	proxy_type := proxy['proxyType'] or { panic('missing') }
	assert proxy_type is string
	assert proxy_type as string == 'manual'
	deserialize_proxy(json_value_from_text('{"sslProxy":"http://wrong"}')) or {
		assert err.msg().contains('wrong URL scheme')
		return
	}
	assert false
}

fn test_proxy_url_scheme_must_start_with_an_ascii_letter() {
	deserialize_proxy(json_value_from_text('{"proxyType":"manual","httpProxy":"1http://localhost"}')) or {
		assert err.msg().contains('wrong URL scheme')
		return
	}
	assert false
}

fn test_prompt_behavior_string_and_object_forms() {
	legacy := deserialize_unhandled_prompt_behavior('accept and notify') or { panic(err) }
	assert legacy[.fallback_default].handler == .accept
	assert legacy[.fallback_default].notify
	structured := deserialize_unhandled_prompt_behavior(json_value_from_text('{"alert":"ignore","confirm":"dismiss"}')) or {
		panic(err)
	}
	assert structured[.alert] == PromptHandlerConfiguration{
		handler: .ignore
		notify: true
	}
	serialized := serialize_user_prompt_handler(structured)
	assert serialized is map[string]json2.Any
}

fn test_fallback_default_prompt_key_is_only_valid_in_string_form() {
	deserialize_unhandled_prompt_behavior(json_value_from_text('{"fallbackDefault":"accept"}')) or {
		assert err.msg().contains('not a valid prompt type')
		return
	}
	assert false
}
