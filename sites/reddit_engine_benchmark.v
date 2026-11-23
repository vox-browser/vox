module main

import adblock
import browserjs
import crypto.sha256
import css
import dom
import html
import json2
import libjs
import os
import time

$if vox_reddit_engine_benchmark ? {
	fn reddit_benchmark_test_build() bool {
		$if test { return true }
		return false
	}

	// Opt-in original-script/DOM benchmark. The recovered listing fixture adds a
	// representative nested comment and menu; this is not a rendered discussion.

	#include "@VMODROOT/sites/engine_peak_rss.h"

	fn C.vox_hn_self_peak_rss_bytes() u64

	#include "@VMODROOT/sites/engine_callback_cpu.h"

	fn C.vox_hn_thread_cpu_ns() u64

	struct RedditBenchmarkResponse {
		sha256 string
	}

	struct RedditBenchmarkArchive {
		url       string
		responses map[string]RedditBenchmarkResponse
	}

	struct RedditEngineVisit {
		mode                   string
		test_build             bool
		cycles                 int
		initialization_ms      f64
		first_cycle_ms         f64
		callback_ms            f64
		callback_thread_cpu_ns u64
		compile_finish_ms      f64
		total_ms               f64
		self_peak_rss_bytes    u64
		collapse_verified      bool
		classes_restored       bool
		probe_verified         bool
		native_context         bool
		manifest_sha256        string
		page_sha256            string
		cache                  libjs.NativeCacheStats
		activity               libjs.NativeCodeActivity
	}

	fn reddit_engine_toggle(document &dom.Document, runtime &browserjs.Runtime, button &dom.Element) ! {
		if runtime.engine == .libjs {
			event := dom.MouseEvent.create('click', dom.MouseEventInit{
				EventModifierInit: dom.EventModifierInit{
					UIEventInit: dom.UIEventInit{
						EventInit: dom.EventInit{ bubbles: true, cancelable: true }
					}
				}
			})
			unsafe { &dom.EventTarget(button) }.dispatch_event(unsafe { &dom.Event(event) })
			if event.default_prevented() { return error('Unexpected cancellation of Reddit click') }
		} else {
			key := runtime.canvas_element_key_for_binding(button) or { return error('Missing toggle identity') }
			encoded := runtime.evaluate_host('__ladybirdDispatch("click","",{key:${json2.encode(key)}})')!
			mut messages := []string{}
			commit := apply_compact_dom_task(document, encoded, runtime, mut messages)!
			if javascript_default_prevented(encoded) || messages.len != 0 {
				return error('Native Reddit click failed task audit: ${encoded}; ${messages}')
			}
			if navigation := commit.navigation {
				if navigation != 'javascript:void(0)' {
					return error('Unexpected navigation: ${navigation}')
				}
			}
		}
	}

	fn reddit_engine_visit(mode string, cycles int, diagnostic bool, archive RedditBenchmarkArchive,
		bodies map[string]string, manifest_sha string) !RedditEngineVisit {
		markup := bodies[archive.url] or { return error('Missing archived HTML') }
		engine := if mode in ['jsc', 'v8'] {
			browserjs.Engine.javascriptcore
		} else {
			browserjs.Engine.libjs
		}
		started := time.sys_mono_now()
		address := dom.URL{ value: archive.url }
		mut document := html.parse_navigation_document(markup, address, address.origin(), none)!
		// parse_navigation_document already owns its actual HTML browsing context.
		// Replacing it with a bare DOM context breaks WindowProxy/activation identity.
		mut runtime := browserjs.Runtime.create_with_engine(engine)
		defer {
			runtime.close()
			document.finalize()
		}
		mut scripts := []browserjs.ScriptSource{}
		mut parent := unsafe { &dom.ParentNode(document) }
		elements := parent.get_elements_by_tag_name('script')
		for index in 0 .. elements.length() {
			element := elements.item(index) or { return error('Missing script') }
			if element.get_attribute_value('type') !in ['', 'text/javascript', 'application/javascript'] {
				continue
			}
			src := element.get_attribute_value('src')
			url := if src == '' {
				archive.url + '#inline-${index}'
			} else {
				(document.encoding_parse_url(src) or { return error('Invalid script URL') }).serialize()
			}
			scripts << browserjs.ScriptSource{
				url:              url
				code:             if src == '' {
					element.as_node().text_content() or { '' }
				} else {
					bodies[url] or { return error('Missing original script: ${url}') }
				}
				element:          element
				external_element: if src == '' { none } else { element }
			}
		}
		mut messages := []string{}
		if navigation := run_document_script_sources(document, archive.url, scripts, runtime, mut messages) {
			return error('Unexpected startup navigation: ${navigation}')
		}
		if engine == .libjs {
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
		}
		initialization_ms := f64(time.sys_mono_now() - started) / 1e6
		// The fixture's added self-reporting probe invokes the real handlers once
		// during initialization. Check that all engines did the same successful work.
		probe := runtime.evaluate_host('JSON.stringify({jquery:typeof $,togglecomment:typeof togglecomment,open_menu:typeof open_menu,close_menu:typeof close_menu,result:JSON.parse(document.getElementById("vox-result").textContent)})')!
		for expected in ['"jquery":"function"', '"togglecomment":"function"', '"open_menu":"function"',
			'"close_menu":"function"', '"collapsed":true', '"expanded":true', '"menu_open":true',
			'"menu_closed":true'] {
			if !probe.contains(expected) { return error('Initialization/probe mismatch: ${probe}') }
		}
		for message in messages {
			if !message.contains('VOX_REDDIT_PROBE ') && !message.contains('Error fetching badge indicator data') {
				return error('Reddit startup diagnostic: ${message}')
			}
		}
		rows := css.query_selector_all(document.as_node(), '#vox-check .comment')
		if rows.len != 2 { return error('Expected two representative comments') }
		classes := rows.map(it.get_attribute_value('class'))
		button := css.query_selector(document.as_node(), '#vox-toggle') or { return error('Missing toggle') }
		mut vm := runtime.libjs_vm()
		if diagnostic && engine == .libjs { vm.diagnose_native_code(true)! }
		first_started := time.sys_mono_now()
		reddit_engine_toggle(document, runtime, button)!
		collapse_ms := f64(time.sys_mono_now() - first_started) / 1e6
		if !rows[0].class_names().contains('collapsed') || button.as_node().text_content() or { '' } != '[+]' {
			return error('First measured cycle failed collapse')
		}
		expand_started := time.sys_mono_now()
		reddit_engine_toggle(document, runtime, button)!
		first_cycle_ms := collapse_ms + f64(time.sys_mono_now() - expand_started) / 1e6
		if !rows[0].class_names().contains('noncollapsed') {
			return error('First measured cycle failed expansion')
		}
		cpu_started := C.vox_hn_thread_cpu_ns()
		callback_started := time.sys_mono_now()
		for _ in 0 .. cycles {
			reddit_engine_toggle(document, runtime, button)!
			reddit_engine_toggle(document, runtime, button)!
		}
		callback_ms := f64(time.sys_mono_now() - callback_started) / 1e6
		cpu_finished := C.vox_hn_thread_cpu_ns()
		if cpu_started == ~u64(0) || cpu_finished == ~u64(0) || cpu_finished < cpu_started {
			return error('CPU clock failed')
		}
		activity := if engine == .libjs {
			vm.diagnose_native_code(false)!
		} else {
			libjs.NativeCodeActivity{}
		}
		finish_started := time.sys_mono_now()
		cache := if engine == .libjs { vm.flush_native_code_cache()! } else { libjs.NativeCacheStats{} }
		compile_finish_ms := f64(time.sys_mono_now() - finish_started) / 1e6
		self_peak := if os.getenv('VOX_REDDIT_ENGINE_MEMORY') == '1' {
			C.vox_hn_self_peak_rss_bytes()
		} else {
			u64(0)
		}
		for index, row in rows {
			if row.get_attribute_value('class') != classes[index] {
				return error('Comment classes not restored')
			}
		}
		if button.as_node().text_content() or { '' } != '[–]' {
			return error('Expand label not restored')
		}
		for message in runtime.take_libjs_messages() {
			if !message.contains('Error fetching badge indicator data') {
				return error('Callback diagnostic: ${message}')
			}
		}
		if vm.interpreter_stack().depth() != 0 || runtime.native_context_initialized() != (engine != .libjs) {
			return error('Retained frame or unexpected engine fallback')
		}
		return RedditEngineVisit{
			mode:                   mode
			test_build:             reddit_benchmark_test_build()
			cycles:                 cycles
			initialization_ms:      initialization_ms
			first_cycle_ms:         first_cycle_ms
			callback_ms:            callback_ms
			callback_thread_cpu_ns: cpu_finished - cpu_started
			compile_finish_ms:      compile_finish_ms
			total_ms:               initialization_ms + first_cycle_ms + callback_ms + compile_finish_ms
			self_peak_rss_bytes:    self_peak
			collapse_verified:      true
			classes_restored:       true
			probe_verified:         true
			native_context:         runtime.native_context_initialized()
			manifest_sha256:        manifest_sha
			page_sha256:            sha256.hexhash(markup)
			cache:                  cache
			activity:               activity
		}
	}

	fn reddit_engine_benchmark_main() ! {
		mode := os.getenv('VOX_REDDIT_ENGINE_BENCHMARK')
		if mode == '' { return }
		if mode !in ['v8', 'jsc', 'libjs-cold', 'libjs-warm'] { panic('Invalid Reddit benchmark mode') }
		$if vox_v8 ? {
			if mode == 'jsc' { panic('JSC needs the default backend build') }
		} $else {
			if mode == 'v8' { panic('V8 needs -d vox_v8') }
		}
		cycles := os.getenv('VOX_REDDIT_ENGINE_CYCLES').int()
		if cycles < 1 { panic('Expected positive cycle count') }
		adblock.set_enabled(false)
		if mode == 'libjs-warm' { os.setenv('VOX_LIBJS_NATIVE_COMPILER', '/usr/bin/false', true) }
		path := os.getenv('VOX_REDDIT_ENGINE_ARCHIVE')
		manifest := os.read_file(os.join_path(path, 'manifest.json'))!
		archive := json2.decode[RedditBenchmarkArchive](manifest)!
		mut bodies := map[string]string{}
		for url, response in archive.responses {
			body := os.read_file(os.join_path(path, 'bodies', response.sha256))!
			if sha256.hexhash(body) != response.sha256 { panic('Changed archived response: ${url}') }
			bodies[url] = body
		}
		println(json2.encode(reddit_engine_visit(mode, cycles, os.getenv('VOX_REDDIT_ENGINE_DIAGNOSTIC') == '1',
			archive, bodies, sha256.hexhash(manifest))!))
	}
}
