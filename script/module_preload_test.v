module main

import browserjs
import dom
import fetch
import html
import http
import time

// Holds every module request until the test answers it.
@[heap]
struct ModulePreloadTestNetwork {
mut:
	urls    []string
	pending []voidptr
}

fn module_preload_test_transport(network &ModulePreloadTestNetwork) &fetch.FetchHost {
	return &fetch.FetchHost{
		perform: fn (_ &fetch.Request) !&fetch.Response { panic('blocking network transport was used') }
		perform_async_with_params: fn [network] (_ &fetch.FetchParams, request &fetch.Request) &fetch.PendingResponse {
			mut state := unsafe { &ModulePreloadTestNetwork(network) }
			mut actual := unsafe { &fetch.Request(request) }
			pending := fetch.PendingResponse.create(mut actual, none)
			state.urls << request.current_url().serialize()
			state.pending << voidptr(pending)
			return pending
		}
	}
}

fn module_preload_test_answer(network &ModulePreloadTestNetwork, index int, body ?string) {
	mut pending := unsafe { &fetch.PendingResponse(network.pending[index]) }
	if source := body {
		mut response := fetch.Response.create()
		response.header_list.append(http.Header{ name: 'Content-Type', value: 'text/javascript' })
		response.set_body_bytes(source.bytes())
		pending.resolve(response)
	} else {
		pending.resolve(fetch.Response.network_error('connection reset'))
	}
}

fn module_preload_test_spin(settings &html.EnvironmentSettingsObject, limit time.Duration, condition fn () bool) {
	deadline := time.sys_mono_now() + limit
	mut loop := settings.responsible_event_loop()
	loop.spin_until(fn [condition, deadline] () bool {
		return condition() || time.sys_mono_now() >= deadline
	})
}

fn module_preload_test_requests(network &ModulePreloadTestNetwork, count int) fn () bool {
	return fn [network, count] () bool { return network.urls.len >= count }
}

fn module_preload_test_answered(runtime &browserjs.Runtime, value int) fn () bool {
	return fn [runtime, value] () bool {
		return (runtime.evaluate_host('globalThis.preloadAnswer===${value}') or { 'false' }) == 'true'
	}
}

const module_preload_test_importer = 'import {value} from "./dep.js";globalThis.preloadAnswer=value;'

fn module_preload_test_import(runtime &browserjs.Runtime, origin string) {
	mut active := unsafe { &browserjs.Runtime(runtime) }
	assert active.run_document_scripts_collect_errors([browserjs.ScriptSource{
		source_type: .module
		url:         '${origin}/root.js'
		code:        module_preload_test_importer
	}]) == []string{}
}

fn test_import_joins_an_in_flight_module_preload() {
	$if !darwin { return }
	origin := 'https://preload-join.test'
	address := dom.URL{ value: '${origin}/page' }
	mut document := html.create_navigation_document(address, address.origin(), none)!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	network := &ModulePreloadTestNetwork{}
	mut host := browserjs.ModuleHost.create(settings, module_preload_test_transport(network))
	host.install(mut runtime)!
	host.preload('${origin}/dep.js', html.default_script_fetch_options())
	module_preload_test_spin(settings, 5 * time.second, module_preload_test_requests(network, 1))
	assert network.urls == ['${origin}/dep.js']
	// The importer is parsed before the preload answers; its import waits for
	// the preload instead of requesting the module again.
	module_preload_test_import(runtime, origin)
	module_preload_test_spin(settings, 100 * time.millisecond, module_preload_test_requests(network, 2))
	assert network.urls.len == 1
	module_preload_test_answer(network, 0, 'export const value=42;')
	module_preload_test_spin(settings, 5 * time.second, module_preload_test_answered(runtime, 42))
	assert runtime.evaluate_host('globalThis.preloadAnswer')! == '42'
	assert network.urls == ['${origin}/dep.js']
	assert host.errors() == []string{}
}

fn test_completed_module_preload_supplies_a_later_import_from_the_module_map() {
	$if !darwin { return }
	origin := 'https://preload-map.test'
	address := dom.URL{ value: '${origin}/page' }
	mut document := html.create_navigation_document(address, address.origin(), none)!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	network := &ModulePreloadTestNetwork{}
	mut host := browserjs.ModuleHost.create(settings, module_preload_test_transport(network))
	host.install(mut runtime)!
	key := '${origin}/dep.js'
	host.preload(key, html.default_script_fetch_options())
	module_preload_test_spin(settings, 5 * time.second, module_preload_test_requests(network, 1))
	module_preload_test_answer(network, 0, 'export const value=7;')
	module_preload_test_spin(settings, 5 * time.second, fn [settings, key] () bool {
		return settings.module_map().get(dom.URL{ value: key }, 'javascript-or-wasm') != none
	})
	assert settings.module_map().get(dom.URL{ value: key }, 'javascript-or-wasm') != none
	// Preloading a module that is already in the map does nothing.
	host.preload(key, html.default_script_fetch_options())
	module_preload_test_import(runtime, origin)
	module_preload_test_spin(settings, 5 * time.second, module_preload_test_answered(runtime, 7))
	assert runtime.evaluate_host('globalThis.preloadAnswer')! == '7'
	assert network.urls == [key]
	assert host.errors() == []string{}
}

fn test_failed_module_preload_lets_its_waiting_import_fetch_again() {
	$if !darwin { return }
	origin := 'https://preload-retry.test'
	address := dom.URL{ value: '${origin}/page' }
	mut document := html.create_navigation_document(address, address.origin(), none)!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	network := &ModulePreloadTestNetwork{}
	mut host := browserjs.ModuleHost.create(settings, module_preload_test_transport(network))
	host.install(mut runtime)!
	key := '${origin}/dep.js'
	host.preload(key, html.default_script_fetch_options())
	module_preload_test_spin(settings, 5 * time.second, module_preload_test_requests(network, 1))
	module_preload_test_import(runtime, origin)
	module_preload_test_answer(network, 0, none)
	module_preload_test_spin(settings, 5 * time.second, module_preload_test_requests(network, 2))
	assert network.urls == [key, key]
	assert settings.module_map().get(dom.URL{ value: key }, 'javascript-or-wasm') == none
	module_preload_test_answer(network, 1, 'export const value=5;')
	module_preload_test_spin(settings, 5 * time.second, module_preload_test_answered(runtime, 5))
	assert runtime.evaluate_host('globalThis.preloadAnswer')! == '5'
	assert host.errors() == []string{}
}

fn test_failed_module_preload_without_waiters_leaves_the_import_free_to_fetch() {
	$if !darwin { return }
	origin := 'https://preload-alone.test'
	address := dom.URL{ value: '${origin}/page' }
	mut document := html.create_navigation_document(address, address.origin(), none)!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	network := &ModulePreloadTestNetwork{}
	mut host := browserjs.ModuleHost.create(settings, module_preload_test_transport(network))
	host.install(mut runtime)!
	key := '${origin}/dep.js'
	host.preload(key, html.default_script_fetch_options())
	module_preload_test_spin(settings, 5 * time.second, module_preload_test_requests(network, 1))
	module_preload_test_answer(network, 0, none)
	module_preload_test_spin(settings, 100 * time.millisecond, fn () bool { return false })
	module_preload_test_import(runtime, origin)
	module_preload_test_spin(settings, 5 * time.second, module_preload_test_requests(network, 2))
	assert network.urls == [key, key]
	module_preload_test_answer(network, 1, 'export const value=3;')
	module_preload_test_spin(settings, 5 * time.second, module_preload_test_answered(runtime, 3))
	assert runtime.evaluate_host('globalThis.preloadAnswer')! == '3'
}

fn test_document_module_preloads_select_javascript_module_links_in_tree_order() {
	$if !darwin { return }
	mut document := parse_browser_navigation_document_with_response_time('<!doctype html><head>' +
		'<link rel="modulepreload" href="/a.js">' +
		'<link rel="modulepreload" href="b.js" crossorigin="use-credentials" integrity="sha256-x" referrerpolicy="no-referrer">' +
		'<link rel="stylesheet modulepreload" href="/sheet.js">' +
		'<link rel="modulepreload" href="/a.js">' +
		'<link rel="modulepreload" href="/style.css" as="style">' +
		'<link rel="modulepreload" href="/narrow.js" media="(max-width: 1px)">' +
		'<link rel="modulepreload" href="data:text/javascript,1">' +
		'<link rel="preload" href="/c.js" as="script">' +
		'</head><body><link rel="ModulePreload" href="https://cdn.test/d.js" as="script"></body>',
		dom.URL{ value: 'https://preload-links.test/dir/page' }, none, none, 1000)
	defer { document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	preloads := document_module_preloads(document, settings)
	assert preloads.map(it.url) == ['https://preload-links.test/a.js',
		'https://preload-links.test/dir/b.js', 'https://cdn.test/d.js']
	assert preloads[0].options.credentials_mode == .same_origin
	assert preloads[1].options.credentials_mode == .include
	assert preloads[1].options.integrity_metadata == 'sha256-x'
	assert preloads[1].options.referrer_policy == 'no-referrer'
	assert preloads[2].options.integrity_metadata == ''
}
