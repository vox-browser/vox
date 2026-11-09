module main

import adblock
import net
import os
import time

fn test_response_storage_follows_cache_control_no_store() {
	assert !browser_response_forbids_storage([]adblock.ResponseHeader{})
	assert !browser_response_forbids_storage([adblock.ResponseHeader{ name: 'Cache-Control', value: 'max-age=60, public' }])
	assert !browser_response_forbids_storage([adblock.ResponseHeader{ name: 'Pragma', value: 'no-store' }])
	assert browser_response_forbids_storage([adblock.ResponseHeader{ name: 'Cache-Control', value: 'no-store' }])
	assert browser_response_forbids_storage([adblock.ResponseHeader{ name: 'cache-control', value: 'private, NO-STORE' }])
	assert browser_response_forbids_storage([
		adblock.ResponseHeader{ name: 'CACHE-CONTROL', value: 'max-age=60' },
		adblock.ResponseHeader{ name: 'Cache-Control', value: 'no-store' },
	])
}

// Serves `count` requests; `stored` is explicitly fresh and public, every other
// path is no-store. Returns the requested paths in order.
fn serve_storage_responses(mut listener net.TcpListener, count int) []string {
	mut paths := []string{}
	for _ in 0 .. count {
		mut socket := listener.accept() or { panic(err) }
		socket.set_read_timeout(3 * time.second)
		mut bytes := []u8{len: 8192}
		length := socket.read(mut bytes) or { panic(err) }
		path := bytes[..length].bytestr().all_after(' ').all_before(' ')
		paths << path
		control := if path == '/stored' { 'Cache-Control: public, max-age=60\r\n' } else { 'Cache-Control: no-store\r\n' }
		socket.write_string('HTTP/1.1 200 OK\r\n${control}Date: ${time.utc().http_header_string()}\r\nContent-Length: 5\r\nConnection: close\r\n\r\nfresh') or { panic(err) }
		socket.close() or {}
	}
	return paths
}

fn test_no_store_resources_are_refetched_and_never_kept_on_disk() {
	previous := os.getenv_opt('LADYBIRD_CACHE_DIR')
	cache := os.join_path(os.temp_dir(), 'vox-no-store-${os.getpid()}-${time.sys_mono_now()}')
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
	origin := 'http://${listener.addr()!}'
	server := spawn serve_storage_responses(mut listener, 3)
	// An earlier storable response for this key must not outlive a no-store one.
	replaced := '${origin}/replaced'
	cache_resource_response_headers_with_status(replaced, replaced, 'stale', []adblock.ResponseHeader{}, 200)
	assert read_cached_resource(replaced)? == 'stale'
	cache_resource_response_headers_with_status(replaced, replaced, 'fresh', [adblock.ResponseHeader{ name: 'Cache-Control', value: 'no-store' }], 200)
	assert read_cached_resource(replaced) == none
	assert disk_cached_browser_resource(replaced, origin, 'image') == none
	// Each no-store load reaches the network again; a storable one is reused.
	assert fetch_browser_resource('${origin}/private', '', origin, 'script')!.body == 'fresh'
	assert fetch_browser_resource('${origin}/private', '', origin, 'script')!.body == 'fresh'
	assert read_cached_resource('${origin}/private') == none
	assert fetch_browser_resource('${origin}/stored', '', origin, 'image')!.body == 'fresh'
	assert fetch_browser_resource('${origin}/stored', '', origin, 'image')!.body == 'fresh'
	assert read_cached_resource('${origin}/stored')? == 'fresh'
	assert server.wait() == ['/private', '/private', '/stored']
}

fn test_stored_no_store_entries_are_not_answered_from_disk() {
	previous := os.getenv_opt('LADYBIRD_CACHE_DIR')
	cache := os.join_path(os.temp_dir(), 'vox-legacy-no-store-${os.getpid()}-${time.sys_mono_now()}')
	os.setenv('LADYBIRD_CACHE_DIR', cache, true)
	defer {
		if value := previous {
			os.setenv('LADYBIRD_CACHE_DIR', value, true)
		} else {
			os.unsetenv('LADYBIRD_CACHE_DIR')
		}
		os.rmdir_all(cache) or {}
	}
	// Entries written before no-store was honored keep their header record.
	address := 'http://127.0.0.1:9/legacy.css'
	path := browser_cache_entry_path(browser_cache_root(), 'resources', address)
	assert try_write_browser_cache_entry(path, 'legacy body')
	assert try_write_browser_cache_entry(path + '.url', address)
	assert try_write_browser_cache_metadata(path + '.headers.json', '[{"name":"Cache-Control","value":"no-store"}]')
	assert read_cached_resource(address)? == 'legacy body'
	assert disk_cached_browser_resource(address, address, 'stylesheet') == none
	assert try_write_browser_cache_metadata(path + '.headers.json', '[{"name":"Cache-Control","value":"max-age=60"}]')
	// Removing no-store does not supply the missing status/receipt provenance.
	assert disk_cached_browser_resource(address, address, 'stylesheet') == none
	cache_resource_response_headers_with_status(address, address, 'new response', [
		adblock.ResponseHeader{ name: 'Cache-Control', value: 'public, max-age=60' },
		adblock.ResponseHeader{ name: 'Date', value: time.utc().http_header_string() },
	], 200)
	assert disk_cached_browser_resource(address, address, 'stylesheet')?.body == 'new response'
}
