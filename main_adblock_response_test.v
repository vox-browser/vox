module main

import adblock
import net
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

fn serve_adblock_redirect_provenance_refresh(mut listener net.TcpListener) []string {
	mut requests := []string{}
	for _ in 0 .. 2 {
		mut socket := listener.accept() or { panic(err) }
		socket.set_read_timeout(2 * time.second)
		mut bytes := []u8{len: 4096}
		length := socket.read(mut bytes) or { panic(err) }
		requests << bytes[..length].bytestr().all_before('\r\n')
		socket.write_string('HTTP/1.1 200 OK\r\nContent-Length: 5\r\nConnection: close\r\n\r\nfresh') or { panic(err) }
		socket.close() or {}
	}
	return requests
}

fn test_native_redirected_cache_and_preload_require_the_intermediate_header_provenance() {
	previous := os.getenv_opt('LADYBIRD_CACHE_DIR')
	cache := os.join_path(os.temp_dir(), 'vox-redirect-headers-${os.getpid()}-${time.sys_mono_now()}')
	os.setenv('LADYBIRD_CACHE_DIR', cache, true)
	defer {
		if value := previous { os.setenv('LADYBIRD_CACHE_DIR', value, true) }
		else { os.unsetenv('LADYBIRD_CACHE_DIR') }
		os.rmdir_all(cache) or {}
	}
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(5 * time.second)
	defer { listener.close() or {} }
	server := spawn serve_adblock_redirect_provenance_refresh(mut listener)
	base := 'http://${listener.addr()!}'
	source := 'https://pikabu.ru/'
	// The final headers cannot prove that an intermediate redirect's headers
	// would still be allowed for this consumer, even with the same URL/type.
	cache_resource_response_headers('${base}/cached', '${base}/end', 'old redirect payload', [])
	assert fetch_browser_resource('${base}/cached', '', source, 'xmlhttprequest')!.body == 'fresh'
	preloaded := PreloadedResource{
		url: '${base}/preloaded'
		final_url: '${base}/end'
		source_url: source
		request_type: 'xmlhttprequest'
		body: 'old preloaded redirect payload'
		response_headers: []
	}
	assert filter_preloaded_resource(preloaded, source, 'xmlhttprequest')!.body == 'fresh'
	assert server.wait() == ['GET /cached HTTP/1.1', 'GET /preloaded HTTP/1.1']
}
