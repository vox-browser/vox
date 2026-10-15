module adblock

fn test_response_header_filter_preserves_case_type_and_repeated_field_semantics() {
	mut engine :=
		new_engine('||pikabu.ru/ajax/$xmlhttprequest,responseheader=llasalbbubrrl\n||header.example^$responseheader=x-ad:yes\n')!
	defer { engine.close() }
	request := Request{
		url:          'https://pikabu.ru/ajax/obfuscated'
		source_url:   'https://pikabu.ru/'
		request_type: 'xmlhttprequest'
	}
	assert !engine.check(request).blocked
	assert !engine.check_response(request, []).blocked
	blocked := engine.check_response(request, [
		ResponseHeader{ name: 'LLaSalBBubRRl', value: '' },
	])
	assert blocked.error == '', blocked.error
	assert blocked.blocked
	assert blocked.rule.contains('responseheader=llasalbbubrrl')
	assert !engine.check_response(Request{
		url:          request.url
		source_url:   request.source_url
		request_type: 'script'
	}, [ResponseHeader{ name: 'llasalbbubrrl', value: '1' }]).blocked
	duplicate := Request{
		url:          'https://header.example/payload'
		source_url:   'https://pikabu.ru/'
		request_type: 'xmlhttprequest'
	}
	assert !engine.check_response(duplicate, [
		ResponseHeader{ name: 'X-Ad', value: 'no' },
		ResponseHeader{ name: 'x-ad', value: 'yes' },
	]).blocked
	assert engine.check_response(duplicate, [
		ResponseHeader{ name: 'X-Ad', value: 'yes' },
		ResponseHeader{ name: 'x-ad', value: 'no' },
	]).blocked
	assert !engine.check_response(Request{
		url: duplicate.url
		source_url: duplicate.source_url
		request_type: 'main_frame'
	}, [ResponseHeader{name: 'X-Ad', value: 'yes'}]).blocked
}

fn test_response_header_filters_respect_header_and_request_exceptions_and_important() {
	mut engine :=
		new_engine('||header.example^$responseheader=x-ad\n@@||header.example/header-allowed$xmlhttprequest,responseheader=x-safe\n@@||header.example/request-allowed$xmlhttprequest\n||header.example/important$important,responseheader=x-ad\n@@||header.example/important$xmlhttprequest\n')!
	defer { engine.close() }
	headers := [ResponseHeader{ name: 'X-Ad', value: '1' }, ResponseHeader{
		name:  'X-Safe'
		value: '1'
	}]
	for path in ['header-allowed', 'request-allowed'] {
		decision := engine.check_response(Request{
			url:          'https://header.example/${path}'
			source_url:   'https://pikabu.ru/'
			request_type: 'xmlhttprequest'
		}, headers)
		assert decision.error == '', decision.error
		assert !decision.blocked
		assert decision.exception
	}
	important := engine.check_response(Request{
		url:          'https://header.example/important'
		source_url:   'https://pikabu.ru/'
		request_type: 'xmlhttprequest'
	}, headers)
	assert important.error == '', important.error
	assert important.blocked
}
