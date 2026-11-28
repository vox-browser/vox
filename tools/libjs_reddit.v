module main

// Original-response Reddit script/DOM diagnostic. Browser layout, painting and
// native input require the separate production-browser check.
import browserjs
import crypto.sha256
import dom
import fetch
import html
import http
import json2
import libjs
import os
import time

struct RedditHeader {
	name  string
	value string
}

struct RedditResponse {
	status  int
	sha256  string
	headers []RedditHeader
}

struct RedditManifest {
	url       string
	responses map[string]RedditResponse
}

fn main() {
	if os.args.len !in [2, 3] { panic('Usage: libjs_reddit ARCHIVE [PROBE.js]') }
	archive := os.real_path(os.args[1])
	manifest := json2.decode[RedditManifest](os.read_file(os.join_path(archive, 'manifest.json'))!)!
	mut sources := map[string]string{}
	for url, response in manifest.responses {
		body := os.read_file(os.join_path(archive, 'bodies', response.sha256))!
		if sha256.hexhash(body) != response.sha256 { panic('Changed archive response: ${url}') }
		sources[url] = body
	}
	if os.getenv('VOX_LIBJS_NATIVE_CACHE') == '' { os.setenv('VOX_LIBJS_NATIVE_CACHE', '0', true) }
	address := dom.URL{ value: manifest.url }
	mut document := html.parse_navigation_document(sources[manifest.url], address, address.origin(), none)!
	mut runtime := browserjs.Runtime.create_with_engine(.libjs)
	defer {
		runtime.close()
		document.finalize()
	}
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	runtime.install_libjs_document(document)!
	runtime.install_performance_binding()!
	transport := &fetch.FetchHost{
		perform: fn [archive, manifest] (request &fetch.Request) !&fetch.Response {
			url := request.current_url().serialize()
			entry := manifest.responses[url] or { return error('Unarchived request: ${url}') }
			body := os.read_bytes(os.join_path(archive, 'bodies', entry.sha256))!
			if sha256.sum(body).hex() != entry.sha256 {
				return error('Changed archive response: ${url}')
			}
			mut response := fetch.Response.create()
			response.status = entry.status
			response.url_list = request.url_list.clone()
			for header in entry.headers {
				response.header_list.append(http.Header{ name: header.name, value: header.value })
			}
			response.set_body_bytes(body)
			return response
		}
	}
	mut host := browserjs.ModuleHost.create(settings, transport)
	host.install(mut runtime)!
	mut parent := unsafe { &dom.ParentNode(document) }
	elements := parent.get_elements_by_tag_name('script')
	mut scripts := []browserjs.ScriptSource{}
	for index in 0 .. elements.length() {
		element := elements.item(index) or { continue }
		type_ := element.get_attribute_value('type')
		if type_ !in ['', 'text/javascript', 'application/javascript'] { continue }
		src := element.get_attribute_value('src')
		url := if src == '' {
			manifest.url + '#inline-${index}'
		} else {
			(document.encoding_parse_url(src) or { panic('Invalid script URL') }).serialize()
		}
		scripts << browserjs.ScriptSource{
			url:              url
			code:             if src == '' {
				element.as_node().text_content() or { '' }
			} else {
				sources[url] or { panic('Unarchived script: ${url}') }
			}
			element:          element
			external_element: if src == '' { none } else { element }
		}
	}
	errors := runtime.run_document_scripts_collect_errors(scripts)
	for message in errors { eprintln(message) }
	document.update_readiness(.interactive)
	if document.claim_readiness_event('DOMContentLoaded') {
		unsafe { &dom.EventTarget(document) }.dispatch_event(dom.Event.create('DOMContentLoaded', dom.EventInit{ bubbles: true }))
	}
	document.update_readiness(.complete)
	if document.claim_readiness_event('load') {
		if window := document.get_window() {
			unsafe { &dom.EventTarget(window) }.dispatch_event(dom.Event.create('load', dom.EventInit{}))
		}
	}
	deadline := time.sys_mono_now() + time.second
	mut loop := settings.responsible_event_loop()
	loop.spin_until(fn [deadline] () bool { return time.sys_mono_now() >= deadline })
	for message in runtime.take_libjs_messages() { eprintln(message) }
	println(runtime.evaluate_host('JSON.stringify({jquery:typeof $,togglecomment:typeof togglecomment,open_menu:typeof open_menu,close_menu:typeof close_menu})')!)
	$if test {
		if os.getenv('VOX_REDDIT_BUILTIN_PROFILE') != '' {
			libjs.profile_builtin_calls_for_testing(true)
			libjs.profile_regexp_patterns_for_testing(true)
		}
	}
	if os.args.len == 3 { println(runtime.evaluate_host(os.read_file(os.args[2])!)!) }
	$if test {
		if path := os.getenv_opt('VOX_REDDIT_BUILTIN_PROFILE') {
			os.write_file(path, json2.encode(libjs.profile_builtin_calls_for_testing(false)))!
			os.write_file(path + '.regex.json', json2.encode(libjs.profile_regexp_patterns_for_testing(false)))!
		}
	}
	println(json2.encode(runtime.compiled_code_cache_audit()))
}
