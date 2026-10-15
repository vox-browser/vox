module browsernet

import adblock
import net.http

fn test_pikabu_response_header_blocks_payload_before_browser_return() {
	request := adblock.Request{
		url:          'https://pikabu.ru/ajax/opaque'
		source_url:   'https://pikabu.ru/'
		request_type: 'xmlhttprequest'
	}
	assert !adblock.check(request).blocked
	mut response := http.Response{
		status_code: 200
		body:        'advert payload'
	}
	response.header.add_custom('Llasalbbubrrl', '1')!
	response.header.add_custom('Llasalbbubrrl', '2')!
	headers := response_headers(response)
	assert headers.len == 2
	assert headers[0].value == '1'
	assert headers[1].value == '2'
	filter_response(request, response) or {
		assert err.msg().starts_with('Blocked by adblock:'), err.msg()
		assert err.msg().contains('responseheader=llasalbbubrrl')
		return
	}
	assert false, 'Pikabu ad response headers were ignored'
}

fn test_pikabu_ordinary_response_and_non_xhr_header_response_remain_allowed() {
	response := http.Response{
		status_code: 200
		body:        'ordinary story'
	}
	filter_response(adblock.Request{
		url:          'https://pikabu.ru/ajax/stories'
		source_url:   'https://pikabu.ru/'
		request_type: 'xmlhttprequest'
	}, response)!
	mut script := response
	script.header.add_custom('llasalbbubrrl', '')!
	filter_response(adblock.Request{
		url:          'https://pikabu.ru/ajax/opaque'
		source_url:   'https://pikabu.ru/'
		request_type: 'script'
	}, script)!
}
