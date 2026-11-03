module main

import adblock
import dom
import fetch
import html
import http
import os
import requestserver
import time

fn script_cache_test_headers() []adblock.ResponseHeader {
	return [adblock.ResponseHeader{name:'Content-Type',value:'text/javascript'},
		adblock.ResponseHeader{name:'Cache-Control',value:'public, max-age=31536000, immutable'},
		adblock.ResponseHeader{name:'Date',value:time.utc().http_header_string()}]
}

fn test_cached_scripts_require_public_fresh_immutable_response_and_actual_provenance() {
	previous := os.getenv_opt('LADYBIRD_CACHE_DIR')
	cache := os.join_path(os.temp_dir(), 'vox-script-cache-${os.getpid()}-${time.sys_mono_now()}')
	os.setenv('LADYBIRD_CACHE_DIR', cache, true)
	defer {
		if value := previous { os.setenv('LADYBIRD_CACHE_DIR',value,true) } else { os.unsetenv('LADYBIRD_CACHE_DIR') }
		os.rmdir_all(cache) or {}
	}
	address := 'https://module-cache.example/module.js'
	mut request := fetch.Request.create()
	request.url_list = [dom.URL{value:address}]
	request.destination = .script
	headers := script_cache_test_headers()
	cache_resource_response_headers_with_status(address,address,'export const value=42;',headers,200)
	response := browser_cached_script_response(request) or { panic('cached public module') }
	assert response.body?.bytes().bytestr() == 'export const value=42;'
	assert response.url_list == request.url_list
	for mode in [fetch.CacheMode.no_store,.no_cache,.reload,.force_cache,.only_if_cached] {
		request.cache_mode = mode
		assert browser_cached_script_response(request) == none
	}
	request.cache_mode = .default
	request.destination = none
	assert browser_cached_script_response(request) != none
	request.destination = .image
	assert browser_cached_script_response(request) == none
	request.destination = .worker
	assert browser_cached_script_response(request) != none
	request.method = 'POST'
	assert browser_cached_script_response(request) == none
	request.method = 'GET'
	for name in ['Authorization','Range'] {
		request.header_list.append(http.Header{name:name,value:'test'})
		assert browser_cached_script_response(request) == none
		request.header_list = http.HeaderList.create()
	}
	for control in ['private, max-age=31536000, immutable','public, max-age=31536000','public, max-age=31536000, immutable, no-cache','public, immutable, max-age=0','public, immutable, max-age=9223372036854775807'] {
		mut changed := headers.clone()
		changed[1] = adblock.ResponseHeader{name:'Cache-Control',value:control}
		cache_resource_response_headers_with_status(address,address,'module',changed,200)
		assert browser_cached_script_response(request) == none
	}
	for extra in [adblock.ResponseHeader{name:'Vary',value:'Cookie'},adblock.ResponseHeader{name:'Set-Cookie',value:'key=value'},adblock.ResponseHeader{name:'Age',value:'31536000'}] {
		mut changed := headers.clone()
		changed << extra
		cache_resource_response_headers_with_status(address,address,'module',changed,200)
		assert browser_cached_script_response(request) == none
	}
	mut expired := headers.clone()
	expired[2] = adblock.ResponseHeader{name:'Date',value:'Sat, 01 Jan 2000 00:00:00 GMT'}
	cache_resource_response_headers_with_status(address,address,'module',expired,200)
	assert browser_cached_script_response(request) == none
	cache_resource_response_headers_with_status(address,'https://other.example/module.js','module',headers,200)
	assert browser_cached_script_response(request) == none
	cache_resource_response_headers_with_status(address,address,'module',headers,404)
	assert browser_cached_script_response(request) == none
	cache_resource_response_headers_with_status(address,address,'module',headers,200)
	os.rm(browser_cache_entry_path(cache,'resources',address)+'.headers.json')!
	assert browser_cached_script_response(request) == none
}

@[heap]
struct ScriptCacheFetchProbe {
mut:
	finished bool
	error bool
	body string
}

fn test_credentialless_fetch_reuses_only_fresh_public_unvaried_responses() {
	previous := os.getenv_opt('LADYBIRD_CACHE_DIR')
	cache := os.join_path(os.temp_dir(), 'vox-public-fetch-cache-${os.getpid()}-${time.sys_mono_now()}')
	os.setenv('LADYBIRD_CACHE_DIR', cache, true)
	defer {
		if value := previous { os.setenv('LADYBIRD_CACHE_DIR',value,true) } else { os.unsetenv('LADYBIRD_CACHE_DIR') }
		os.rmdir_all(cache) or {}
	}
	address := 'https://public-cache.example/catalog.json'
	headers := [adblock.ResponseHeader{name:'Content-Type',value:'application/json'},
		adblock.ResponseHeader{name:'Cache-Control',value:'public, max-age=604800'},
		adblock.ResponseHeader{name:'Date',value:time.utc().http_header_string()}]
	cache_resource_response_headers_with_status(address,address,'{"items":[42]}',headers,200)
	mut request := fetch.Request.create()
	request.set_url(dom.URL{value:address})
	request.credentials_mode = .omit
	response := browser_cached_script_response(request) or { panic('fresh public Fetch response') }
	assert response.body?.bytes().bytestr() == '{"items":[42]}'
	for credentials in [fetch.CredentialsMode.same_origin,.include] {
		request.credentials_mode = credentials
		assert browser_cached_script_response(request) == none
	}
	request.credentials_mode = .omit
	for name in ['Cookie','Authorization','Range'] {
		request.header_list.append(http.Header{name:name,value:'test'})
		assert browser_cached_script_response(request) == none
		request.header_list = http.HeaderList.create()
	}
	for mode in [fetch.CacheMode.no_store,.no_cache,.reload] {
		request.cache_mode = mode
		assert browser_cached_script_response(request) == none
	}
	request.cache_mode = .default
	for extra in [adblock.ResponseHeader{name:'Vary',value:'Accept'},
		adblock.ResponseHeader{name:'Vary',value:'Cookie'},
		adblock.ResponseHeader{name:'Set-Cookie',value:'key=value'},
		adblock.ResponseHeader{name:'Age',value:'604800'}] {
		mut changed := headers.clone()
		changed << extra
		cache_resource_response_headers_with_status(address,address,'catalog',changed,200)
		assert browser_cached_script_response(request) == none
	}
	for control in ['max-age=604800','private, max-age=604800','public, max-age=604800, no-cache','public, no-store'] {
		mut changed := headers.clone()
		changed[1] = adblock.ResponseHeader{name:'Cache-Control',value:control}
		cache_resource_response_headers_with_status(address,address,'catalog',changed,200)
		assert browser_cached_script_response(request) == none
	}
}

fn test_fetch_with_credentials_reuses_public_immutable_assets_without_explicit_cookie_headers() {
	previous := os.getenv_opt('LADYBIRD_CACHE_DIR')
	cache := os.join_path(os.temp_dir(), 'vox-immutable-fetch-cache-${os.getpid()}-${time.sys_mono_now()}')
	os.setenv('LADYBIRD_CACHE_DIR', cache, true)
	defer {
		if value := previous { os.setenv('LADYBIRD_CACHE_DIR',value,true) } else { os.unsetenv('LADYBIRD_CACHE_DIR') }
		os.rmdir_all(cache) or {}
	}
	address := 'https://immutable-cache.example/icons.svg'
	mut headers := script_cache_test_headers()
	headers[0] = adblock.ResponseHeader{name:'Content-Type',value:'image/svg+xml'}
	cache_resource_response_headers_with_status(address,address,'<svg/>',headers,200)
	mut request := fetch.Request.create()
	request.set_url(dom.URL{value:address})
	for credentials in [fetch.CredentialsMode.same_origin,.include] {
		request.credentials_mode = credentials
		assert browser_cached_script_response(request)?.body?.bytes().bytestr() == '<svg/>'
		for name in ['Cookie','Authorization','Range'] {
			request.header_list.append(http.Header{name:name,value:'test'})
			assert browser_cached_script_response(request) == none
			request.header_list = http.HeaderList.create()
		}
	}
	for extra in [adblock.ResponseHeader{name:'Vary',value:'Cookie'},adblock.ResponseHeader{name:'Set-Cookie',value:'key=value'}] {
		mut changed := headers.clone()
		changed << extra
		cache_resource_response_headers_with_status(address,address,'<svg/>',changed,200)
		assert browser_cached_script_response(request) == none
	}
	headers[1] = adblock.ResponseHeader{name:'Cache-Control',value:'public, max-age=31536000'}
	cache_resource_response_headers_with_status(address,address,'<svg/>',headers,200)
	assert browser_cached_script_response(request) == none
}

fn test_cached_native_script_fetch_is_deferred_and_keeps_cors_and_filtering() {
	previous := os.getenv_opt('LADYBIRD_CACHE_DIR')
	cache := os.join_path(os.temp_dir(), 'vox-script-fetch-${os.getpid()}-${time.sys_mono_now()}')
	os.setenv('LADYBIRD_CACHE_DIR', cache, true)
	install_browser_script_resource_cache()
	defer {
		requestserver.install_native_response_cache_provider(none)
		if value := previous { os.setenv('LADYBIRD_CACHE_DIR',value,true) } else { os.unsetenv('LADYBIRD_CACHE_DIR') }
		os.rmdir_all(cache) or {}
	}
	for index, address in ['https://module-cache.example/allowed.js','https://module-cache.example/denied.js','https://www.google-analytics.com/analytics.js','https://catalog-cache.example/allowed.json','https://catalog-cache.example/denied.json','https://owner-module-cache.example/icons.svg'] {
		mut document := html.parse_document_with_url('<!doctype html>',dom.URL{value:'https://owner-module-cache.example/'})
		document.set_origin(document.url.origin())
		_ := html.WindowModel.create_top_level(document,none,'cached-script')!
		settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
		mut loop := settings.responsible_event_loop()
		mut connection := requestserver.CurlConnection.create()!
		mut headers := script_cache_test_headers()
		if index in [3,4] {
			headers[0] = adblock.ResponseHeader{name:'Content-Type',value:'application/json'}
			headers[1] = adblock.ResponseHeader{name:'Cache-Control',value:'public, max-age=604800'}
		}
		if index == 5 { headers[0] = adblock.ResponseHeader{name:'Content-Type',value:'image/svg+xml'} }
		if index !in [1,4] { headers << adblock.ResponseHeader{name:'Access-Control-Allow-Origin',value:'*'} }
		cache_resource_response_headers_with_status(address,address,'export const answer=42;',headers,200)
		mut request := fetch.Request.create()
		request.set_url(dom.URL{value:address})
		request.set_client(settings)
		request.destination = if index >= 3 { ?fetch.Destination(none) } else { .script }
		request.mode = .cors
		request.credentials_mode = if index == 5 { .same_origin } else { .omit }
		probe := &ScriptCacheFetchProbe{}
		_ := fetch.fetch(request,fetch.FetchAlgorithms.create(fetch.FetchAlgorithmsInput{
			process_response_consume_body: fn [probe] (response &fetch.Response, body fetch.BodyBytes) {
				mut result := unsafe { &ScriptCacheFetchProbe(probe) }
				result.finished = true
				result.error = response.is_network_error()
				result.body = body.bytes.bytestr()
			}
		}),connection.fetch_host(),.no)
		assert !probe.finished
		assert connection.active_request_count() == 0
		deadline := time.sys_mono_now()+4*time.second
		loop.spin_until(fn [probe,deadline] () bool { return probe.finished || time.sys_mono_now() >= deadline })
		assert probe.finished
		if index in [0,3,5] {
			assert !probe.error
			assert probe.body == 'export const answer=42;'
		} else if index in [1,4] {
			assert probe.error, 'cross-origin cached response without an allow-origin header'
			assert probe.body == ''
		} else {
			// A filter may supply a harmless script replacement rather than an
			// error. The cached tracker payload must never reach the consumer.
			assert probe.body != 'export const answer=42;'
		}
		assert connection.active_request_count() == 0
		connection.close()
		document.finalize()
	}
}

fn test_cached_script_completion_after_connection_close_is_a_network_error() {
	previous := os.getenv_opt('LADYBIRD_CACHE_DIR')
	cache := os.join_path(os.temp_dir(), 'vox-script-close-${os.getpid()}-${time.sys_mono_now()}')
	os.setenv('LADYBIRD_CACHE_DIR', cache, true)
	install_browser_script_resource_cache()
	defer {
		requestserver.install_native_response_cache_provider(none)
		if value := previous { os.setenv('LADYBIRD_CACHE_DIR',value,true) } else { os.unsetenv('LADYBIRD_CACHE_DIR') }
		os.rmdir_all(cache) or {}
	}
	address := 'https://module-cache.example/close.js'
	cache_resource_response_headers_with_status(address,address,'module',script_cache_test_headers(),200)
	mut request := fetch.Request.create()
	request.set_url(dom.URL{value:address})
	request.destination = .script
	mut connection := requestserver.CurlConnection.create()!
	pending := connection.start_fetch(fetch.FetchParams.create(request,fetch.FetchTimingInfo.create()),request)
	assert !pending.is_resolved()
	assert connection.active_request_count() == 0
	connection.close()
	mut loop := html.main_thread_event_loop()
	deadline := time.sys_mono_now()+4*time.second
	loop.spin_until(fn [pending,deadline] () bool { return pending.is_resolved() || time.sys_mono_now() >= deadline })
	assert pending.response()?.is_network_error()
}
