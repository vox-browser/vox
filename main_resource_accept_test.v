module main

import adblock
import browsernet
import net
import os
import time

fn serve_accept_variants(mut listener net.TcpListener) []string {
	mut accepts := []string{}
	for _ in 0 .. 2 {
		mut socket := listener.accept() or { panic(err) }
		socket.set_read_timeout(3 * time.second)
		mut bytes := []u8{len: 8192}
		length := socket.read(mut bytes) or { panic(err) }
		mut accept := ''
		for line in bytes[..length].bytestr().split('\r\n') {
			if line.to_lower().starts_with('accept:') { accept = line.all_after(':').trim_space() }
		}
		accepts << accept
		body := if accept == '*/*' { 'other' } else { 'image' }
		socket.write_string('HTTP/1.1 200 OK\r\nVary: Origin, Accept\r\nContent-Length: 5\r\nConnection: close\r\n\r\n${body}') or { panic(err) }
		socket.close() or {}
	}
	return accepts
}

fn test_accept_variants_refresh_legacy_entries_and_keep_separate_disk_and_preload_identities() {
	previous := os.getenv_opt('LADYBIRD_CACHE_DIR')
	cache := os.join_path(os.temp_dir(), 'vox-accept-variants-${os.getpid()}-${time.sys_mono_now()}')
	os.setenv('LADYBIRD_CACHE_DIR', cache, true)
	defer {
		if value := previous {
			os.setenv('LADYBIRD_CACHE_DIR', value, true)
		} else {
			os.unsetenv('LADYBIRD_CACHE_DIR')
		}
		os.rmdir_all(cache) or {}
	}
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(5 * time.second)
	defer { listener.close() or {} }
	address := 'http://${listener.addr()!}/negotiated'
	server := spawn serve_accept_variants(mut listener)
	headers := [adblock.ResponseHeader{ name: 'Vary', value: 'Origin, Accept' }]
	cache_resource_response_headers(address, address, 'legacy JPEG', headers)
	assert fetch_browser_resource(address, '', address, 'image')!.body == 'image'
	assert fetch_browser_resource(address, '', address, 'script')!.body == 'other'
	assert fetch_browser_resource(address, '', address, 'image')!.body == 'image'
	assert fetch_browser_resource(address, '', address, 'script')!.body == 'other'
	assert read_cached_resource(resource_accept_cache_key(address, 'image'))? == 'image'
	assert read_cached_resource(resource_accept_cache_key(address, 'script'))? == 'other'
	preloaded := PreloadedResource{
		url:              address
		final_url:        address
		source_url:       address
		request_type:     'image'
		body:             'wrong representation'
		response_headers: headers
	}
	assert filter_preloaded_resource(preloaded, address, 'script')!.body == 'other'
	assert server.wait() == [browsernet.request_accept_header('image'), '*/*']
}

fn test_vary_accept_matches_complete_case_insensitive_header_tokens() {
	assert resource_response_varies_on_accept([adblock.ResponseHeader{ name: 'vary', value: 'Origin, aCcEpT' }])
	assert !resource_response_varies_on_accept([adblock.ResponseHeader{ name: 'Vary', value: 'Accept-Language' }])
}
