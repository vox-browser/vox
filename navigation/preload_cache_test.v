module main

import adblock
import net
import os
import time

fn serve_uncached_navigation_script(mut listener net.TcpListener) {
	mut socket := listener.accept() or { panic(err) }
	defer { socket.close() or {} }
	socket.set_read_timeout(5 * time.second)
	mut bytes := []u8{len: 4096}
	length := socket.read(mut bytes) or { panic(err) }
	assert bytes[..length].bytestr().contains('GET /script.js ')
	body := 'globalThis.freshResponse=true;'
	socket.write_string('HTTP/1.1 200 OK\r\nContent-Type: text/javascript\r\nCache-Control: no-store\r\nContent-Length: ${body.len}\r\nConnection: close\r\n\r\n${body}') or { panic(err) }
}

fn test_navigation_refetches_no_store_inputs_retained_for_the_previous_page() {
	previous := os.getenv_opt('LADYBIRD_CACHE_DIR')
	cache_root := os.join_path(os.temp_dir(), 'vox-navigation-no-store-${os.getpid()}-${time.sys_mono_now()}')
	os.setenv('LADYBIRD_CACHE_DIR', cache_root, true)
	defer {
		if value := previous { os.setenv('LADYBIRD_CACHE_DIR', value, true) } else { os.unsetenv('LADYBIRD_CACHE_DIR') }
		os.rmdir_all(cache_root) or {}
	}
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(5 * time.second)
	defer { listener.close() or {} }
	origin := 'http://${listener.addr()!}'
	address := '${origin}/script.js'
	server := spawn serve_uncached_navigation_script(mut listener)
	mut pending := PendingPagePreload{loaded: LoadedPage{url: '${origin}/next'}, results: chan PreloadedResource{cap: 1}}
	stale := PreloadedResource{
		url: address
		final_url: address
		source_url: '${origin}/previous'
		request_type: 'script'
		body: 'globalThis.staleResponse=true;'
		response_headers: [adblock.ResponseHeader{name: 'Cache-Control', value: 'private, NO-STORE'}]
	}
	queue_navigation_preloads(mut pending, [address], {address: 'script'}, {address: stale})
	mut fresh := PreloadedResource{}
	select {
		value := <-pending.results { fresh = value }
		10 * time.second { panic('no-store navigation resource did not finish') }
	}
	assert fresh.error == '', fresh.error
	assert fresh.body == 'globalThis.freshResponse=true;'
	assert browser_response_forbids_storage(fresh.response_headers)
	server.wait()
	assert read_cached_resource(address) == none
	// Ordinary reusable responses keep their existing in-memory path.
	ordinary := PreloadedResource{...stale, body: 'reused', response_headers: []adblock.ResponseHeader{}}
	queue_navigation_preloads(mut pending, [address], {address: 'script'}, {address: ordinary})
	select {
		value := <-pending.results { assert value.body == 'reused', value.error }
		5 * time.second { panic('reusable navigation response did not finish') }
	}
}
