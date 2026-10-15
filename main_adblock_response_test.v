module main

import adblock
import os
import time

fn test_native_cached_response_headers_are_rechecked_for_the_request_type() {
	previous := os.getenv_opt('LADYBIRD_CACHE_DIR')
	cache := os.join_path(os.temp_dir(), 'vox-pikabu-headers-${os.getpid()}-${time.sys_mono_now()}')
	os.setenv('LADYBIRD_CACHE_DIR', cache, true)
	defer {
		if value := previous { os.setenv('LADYBIRD_CACHE_DIR', value, true) }
		else { os.unsetenv('LADYBIRD_CACHE_DIR') }
		os.rmdir_all(cache) or {}
	}
	address := 'https://pikabu.ru/ajax/opaque'
	headers := [adblock.ResponseHeader{name: 'LLaSalBBubRRl', value: '1'}]
	cache_resource_response_headers(address, address, 'retained payload', headers)
	image := fetch_browser_resource(address, '', 'https://pikabu.ru/', 'image')!
	assert image.body == 'retained payload'
	assert image.response_headers == headers
	_ := fetch_browser_resource(address, '', 'https://pikabu.ru/', 'xmlhttprequest') or {
		assert err.msg().contains('responseheader=llasalbbubrrl'), err.msg()
		return
	}
	assert false, 'Cached bytes bypassed RU AdList response-header filtering'
}

fn test_native_preloaded_response_headers_block_before_payload_consumption() {
	resource := PreloadedResource{
		url: 'https://pikabu.ru/ajax/opaque'
		final_url: 'https://pikabu.ru/ajax/opaque'
		source_url: 'https://pikabu.ru/'
		request_type: 'image'
		body: 'advert payload'
		response_headers: [adblock.ResponseHeader{name: 'llasalbbubrrl', value: ''}]
	}
	allowed := filter_preloaded_resource(resource, resource.source_url, 'image')!
	assert allowed.body == resource.body
	_ := filter_preloaded_resource(resource, resource.source_url, 'xmlhttprequest') or {
		assert err.msg().contains('responseheader=llasalbbubrrl'), err.msg()
		return
	}
	assert false, 'Preloaded bytes bypassed RU AdList response-header filtering'
}
