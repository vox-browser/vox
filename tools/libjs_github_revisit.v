module main

// An offline document/author-script initialization diagnostic, using original
// GitHub bytes and the browser's real LibJS DOM/module/performance host. It has
// no window, layout or paint and must not claim completed GitHub hydration.
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

struct RevisitResponseHeader {
	name  string
	value string
}

struct RevisitResponse {
	status  int
	sha256  string
	headers []RevisitResponseHeader
}

struct RevisitManifest {
	url       string
	responses map[string]RevisitResponse
}

@[heap]
struct RevisitRequests {
mut:
	urls []string
}

struct GithubRevisitResult {
	scope               string = 'offline original GitHub HTML/author-script initialization; native DOM/module host; no network, window, layout or paint'
	total_ms            f64
	initialization_ms   f64
	script_ms           f64
	cache_finish_ms     f64
	scripts             int
	requests            []string
	initial_errors      []string
	module_errors       []string
	javascript_messages []string
	title               string
	rows                u32
	commit_links        u32
	timeout             bool
	jsc_initialized     bool
	cache               libjs.NativeCacheStats
	frontend            browserjs.LibJSFrontendCacheStats
}

fn main() {
	if os.args.len !in [3, 4] {
		eprintln('Usage: libjs_github_revisit ARCHIVE_DIRECTORY CACHE_DIRECTORY [VISITS=2]')
		exit(2)
	}
	archive, cache := os.real_path(os.args[1]), os.args[2]
	manifest := json2.decode[RevisitManifest](os.read_file(os.join_path(archive, 'manifest.json')) or { panic(err) }) or { panic(err) }
	mapping := json2.decode[map[string]string](os.read_file(os.join_path(archive, 'source-map.json')) or { panic(err) }) or { panic(err) }
	mut sources := map[string]string{}
	for address, path in mapping {
		text := os.read_file(path) or { panic(err) }
		metadata := manifest.responses[address] or { panic('Missing archived response') }
		if sha256.hexhash(text) != metadata.sha256 { panic('Changed fixture: ${address}') }
		sources[address] = text
	}
	os.setenv('VOX_LIBJS_NATIVE_CACHE', cache, true)
	visits := if os.args.len == 4 { os.args[3].int() } else { 2 }
	if visits < 1 || visits > 2 { panic('Use one or two visits') }
	for visit in 0 .. visits {
		// The second opening must work even when starting a compiler is impossible.
		if visit > 0 { os.setenv('VOX_LIBJS_NATIVE_COMPILER', '/usr/bin/false', true) }
		result := open_github(manifest, sources, archive)
		println(json2.encode(result))
	}
}

fn open_github(manifest RevisitManifest, sources map[string]string, archive string) GithubRevisitResult {
	markup := sources[manifest.url] or { panic('Missing original HTML') }
	started := time.sys_mono_now()
	address := dom.URL{ value: manifest.url }
	mut document := html.parse_navigation_document(markup, address, address.origin(), none) or { panic(err) }
	// parse_navigation_document already establishes the real Window/Navigable
	// pair. Preserve its browsing-context identity for author History updates.
	mut runtime := browserjs.Runtime.create_with_engine(.libjs)
	defer {
		runtime.close()
		document.finalize()
	}
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings) or { panic(err) }
	runtime.install_libjs_document(document) or { panic(err) }
	runtime.install_performance_binding() or { panic(err) }
	seen := &RevisitRequests{}
	transport := &fetch.FetchHost{
		perform: fn [archive, manifest, seen] (request &fetch.Request) !&fetch.Response {
			mut requests := unsafe { &RevisitRequests(seen) }
			url := request.current_url().serialize()
			requests.urls << url
			metadata := manifest.responses[url] or { return error('Unarchived request: ${url}') }
			body := os.read_bytes(os.join_path(archive, 'bodies', metadata.sha256))!
			if sha256.sum(body).hex() != metadata.sha256 { return error('Changed response body: ${url}') }
			mut response := fetch.Response.create()
			response.status = metadata.status
			response.url_list = request.url_list.clone()
			for header in metadata.headers {
				response.header_list.append(http.Header{ name: header.name, value: header.value })
			}
			response.set_body_bytes(body)
			return response
		}
	}
	mut host := browserjs.ModuleHost.create(settings, transport)
	host.install(mut runtime) or { panic(err) }
	mut parent := unsafe { &dom.ParentNode(document) }
	elements := parent.get_elements_by_tag_name('script')
	mut scripts := []browserjs.ScriptSource{}
	for index in 0 .. elements.length() {
		element := elements.item(index) or { continue }
		type_ := element.get_attribute_value('type').to_lower()
		if type_ == 'importmap' {
			map_ := html.parse_import_map_string(element.as_node().text_content() or { '' }, address) or { panic(err) }
			mut scope := settings.universal_global_scope()
			scope.set_import_map(&map_)
			continue
		}
		if type_ !in ['', 'text/javascript', 'application/javascript', 'module'] { continue }
		src := element.get_attribute_value('src')
		if src != '' && src !in sources { panic('Unmapped top-level script: ${src}') }
		scripts << browserjs.ScriptSource{
			url:              if src == '' { manifest.url + '#inline-${index}' } else { src }
			code:             if src == '' {
				element.as_node().text_content() or { '' }
			} else {
				sources[src]
			}
			source_type:      if type_ == 'module' { .module } else { .script }
			element:          element
			external_element: if src == '' { none } else { element }
		}
	}
	initialization_ms := f64(time.sys_mono_now() - started) / 1e6
	script_start := time.sys_mono_now()
	errors := runtime.run_document_scripts_collect_errors(scripts)
	deadline := time.sys_mono_now() + 120 * time.second
	mut loop := settings.responsible_event_loop()
	loop.spin_until(fn [runtime, deadline] () bool {
		stats := runtime.native_code_cache_stats()
		return time.sys_mono_now() >= deadline
			|| (!runtime.has_pending_module_scripts() && !runtime.has_pending_libjs_fetches()
				&& (stats.pending_executables == 0 || stats.last_error != ''))
	})
	script_ms := f64(time.sys_mono_now() - script_start) / 1e6
	finish_start := time.sys_mono_now()
	mut vm := runtime.libjs_vm()
	stats := vm.flush_native_code_cache() or { panic(err) }
	finish_ms := f64(time.sys_mono_now() - finish_start) / 1e6
	total_ms := f64(time.sys_mono_now() - started) / 1e6
	links := parent.get_elements_by_tag_name('a')
	mut commit_links := u32(0)
	for index in 0 .. links.length() {
		if element := links.item(index) {
			if element.get_attribute_value('href').contains('/commit/') { commit_links++ }
		}
	}
	return GithubRevisitResult{
		total_ms:            total_ms
		initialization_ms:   initialization_ms
		script_ms:           script_ms
		cache_finish_ms:     finish_ms
		scripts:             scripts.len
		requests:            seen.urls
		initial_errors:      errors
		module_errors:       host.errors()
		javascript_messages: runtime.take_libjs_messages()
		title:               document.title()
		rows:                parent.get_elements_by_class_name('react-directory-row').length()
		commit_links:        commit_links
		timeout:             time.sys_mono_now() >= deadline
		jsc_initialized:     runtime.native_context_initialized()
		cache:               stats
		frontend:            runtime.frontend_code_cache_stats()
	}
}
