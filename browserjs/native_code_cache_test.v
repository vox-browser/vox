module browserjs

import dom
import fetch
import html
import http
import libjs
import os
import rand
import time

fn test_libjs_document_second_open_uses_compiled_code_without_running_the_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-document-native-' + rand.uuid_v4())
	previous := os.getenv_opt('VOX_LIBJS_NATIVE_CACHE')
	previous_compiler := os.getenv_opt('VOX_LIBJS_NATIVE_COMPILER')
	os.setenv('VOX_LIBJS_NATIVE_CACHE', directory, true)
	defer {
		if value := previous {
			os.setenv('VOX_LIBJS_NATIVE_CACHE', value, true)
		} else {
			os.unsetenv('VOX_LIBJS_NATIVE_CACHE')
		}
		if value := previous_compiler {
			os.setenv('VOX_LIBJS_NATIVE_COMPILER', value, true)
		} else {
			os.unsetenv('VOX_LIBJS_NATIVE_COMPILER')
		}
		os.rmdir_all(directory) or {}
	}
	for visit in 0 .. 2 {
		os.setenv('VOX_LIBJS_NATIVE_COMPILER', if visit == 0 {
			'/usr/bin/clang'
		} else {
			'/usr/bin/false'
		}, true)
		mut document := html.parse_document('<body><p id="result">pending</p></body>')
		document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
		document.url = dom.URL{ value: 'https://github.com/vlang/v' }
		mut runtime := Runtime.create_with_engine(.libjs)
		runtime.install_libjs_document(document)!
		runtime.agent_vm.diagnose_native_code(true)!
		errors := runtime.run_document_scripts_collect_errors([ScriptSource{
			url:  'https://github.githubassets.com/assets/example.js'
			code: 'function answer(n){return n+2} document.getElementById("result").textContent=answer(40)+"";'
		}])
		assert errors.len == 0
		assert document.get_element_by_id('result')?.as_node().text_content()? == '42'
		stats := runtime.native_code_cache_stats()
		activity := runtime.agent_vm.diagnose_native_code(false)!
		if visit == 0 {
			assert runtime.frontend_code_cache_stats().misses == 1
			assert stats.compiler_invocations == 1 && stats.compiled_executables == 2
			assert activity.entries == 0
		} else {
			assert runtime.frontend_code_cache_stats().hits == 1
			assert stats.cache_hits == 2 && stats.cache_misses == 0
			assert stats.compiler_invocations == 0
			assert activity.entries == 2 && activity.fast_steps > 0
		}
		assert !runtime.native_context_initialized()
		runtime.close()
	}
}

fn test_bound_document_coalesces_first_visit_compilation_and_has_no_second_visit_idle_compile() {
	directory := os.join_path(os.temp_dir(), 'vox-document-idle-' + rand.uuid_v4())
	previous := os.getenv_opt('VOX_LIBJS_NATIVE_CACHE')
	os.setenv('VOX_LIBJS_NATIVE_CACHE', directory, true)
	defer {
		if value := previous {
			os.setenv('VOX_LIBJS_NATIVE_CACHE', value, true)
		} else {
			os.unsetenv('VOX_LIBJS_NATIVE_CACHE')
		}
		os.rmdir_all(directory) or {}
	}
	for visit in 0 .. 2 {
		address := dom.URL{ value: 'https://github.com/vlang/v' }
		mut document := html.create_navigation_document(address, address.origin(), none)!
		document.set_document_type(.html)
		document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
		mut runtime := Runtime.create_with_engine(.libjs)
		settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
		runtime.bind_scripting_environment(settings)!
		runtime.install_libjs_document(document)!
		assert runtime.run_document_scripts_collect_errors([
			ScriptSource{ url: 'https://github.githubassets.com/one.js', code: 'function answer(){return 42} globalThis.first=answer();' },
			ScriptSource{ url: 'https://github.githubassets.com/two.js', code: 'globalThis.second=first;' },
		]).len == 0
		assert runtime.native_code_cache_stats().compiler_invocations == 0
		if visit == 0 {
			assert runtime.libjs_native_cache_pending_
			assert runtime.frontend_code_cache_stats().misses == 2
			mut loop := settings.responsible_event_loop()
			for _ in 0 .. 16 {
				if !runtime.libjs_native_cache_pending_ { break }
				loop.process()
			}
			assert !runtime.libjs_native_cache_pending_
			assert runtime.native_code_cache_stats().compiler_invocations == 1
			assert runtime.native_code_cache_stats().compiled_executables == 3
		} else {
			assert runtime.frontend_code_cache_stats().hits == 2
			assert runtime.native_code_cache_stats().cache_hits == 3
			assert runtime.native_code_cache_stats().cache_misses == 0
			assert !runtime.libjs_native_cache_pending_
		}
		runtime.close()
		document.finalize()
	}
}

fn test_reused_module_syntax_keeps_live_bindings_and_globals_in_the_new_realm() {
	directory := os.join_path(os.temp_dir(), 'vox-module-syntax-' + rand.uuid_v4())
	previous := os.getenv_opt('VOX_LIBJS_NATIVE_CACHE')
	os.setenv('VOX_LIBJS_NATIVE_CACHE', directory, true)
	defer {
		if value := previous {
			os.setenv('VOX_LIBJS_NATIVE_CACHE', value, true)
		} else {
			os.unsetenv('VOX_LIBJS_NATIVE_CACHE')
		}
		os.rmdir_all(directory) or {}
	}
	mut prior_syntax := voidptr(unsafe { nil })
	for visit in 0 .. 2 {
		mut document := html.parse_document('<body></body>')
		mut runtime := Runtime.create_with_engine(.libjs)
		runtime.install_libjs_document(document)!
		url := 'https://github.githubassets.com/state.js'
		assert runtime.run_document_scripts_collect_errors([ScriptSource{
			url:         url
			source_type: .module
			code:        'export var value=40;export function add(n){value+=n;return value} add(2);'
		}]).len == 0
		module_record := runtime.libjs_modules_[url] or { panic('Missing module') }
		mut vm := runtime.agent_vm
		assert module_record.local_export_value(mut vm, 'value')!.number == 42
		if visit == 0 {
			prior_syntax = voidptr(module_record.parsed)
		} else {
			assert voidptr(module_record.parsed) == prior_syntax
		}
		add := module_record.local_export_value(mut vm, 'add')!
		assert libjs.call(mut vm, add, libjs.js_undefined(), [libjs.Value.from_i32(1)])!.number == 43
		runtime.close()
	}
}

fn test_frontend_cache_preserves_parser_limits_and_respects_cache_disable() {
	directory := os.join_path(os.temp_dir(), 'vox-syntax-options-' + rand.uuid_v4())
	previous := os.getenv_opt('VOX_LIBJS_NATIVE_CACHE')
	os.setenv('VOX_LIBJS_NATIVE_CACHE', directory, true)
	defer {
		if value := previous {
			os.setenv('VOX_LIBJS_NATIVE_CACHE', value, true)
		} else {
			os.unsetenv('VOX_LIBJS_NATIVE_CACHE')
		}
		os.rmdir_all(directory) or {}
	}
	mut document := html.parse_document('<body></body>')
	mut runtime := Runtime.create_with_engine(.libjs)
	runtime.install_libjs_document(document)!
	code := '('.repeat(40) + '42' + ')'.repeat(40)
	wide := runtime.prepare_libjs_frontend(code, .script, libjs.ParseOptions{ max_recursion_depth: 256 })
	assert !wide.has_errors()
	narrow := runtime.prepare_libjs_frontend(code, .script, libjs.ParseOptions{ max_recursion_depth: 32 })
	assert narrow.has_errors() && narrow.reached_recursion_limit
	runtime.close()
	os.setenv('VOX_LIBJS_NATIVE_CACHE', '0', true)
	mut disabled := Runtime.create_with_engine(.libjs)
	disabled.install_libjs_document(document)!
	assert !disabled.libjs_native_cache_enabled_
	assert !disabled.prepare_libjs_frontend(code, .script, libjs.ParseOptions{ max_recursion_depth: 256 }).has_errors()
	assert disabled.frontend_code_cache_stats().hits == 0
	disabled.close()
}

fn test_cached_import_syntax_builds_fresh_dependency_records_and_updates_the_new_document() {
	directory := os.join_path(os.temp_dir(), 'vox-import-syntax-' + rand.uuid_v4())
	previous := os.getenv_opt('VOX_LIBJS_NATIVE_CACHE')
	os.setenv('VOX_LIBJS_NATIVE_CACHE', directory, true)
	defer {
		if value := previous {
			os.setenv('VOX_LIBJS_NATIVE_CACHE', value, true)
		} else {
			os.unsetenv('VOX_LIBJS_NATIVE_CACHE')
		}
		os.rmdir_all(directory) or {}
	}
	for visit in 0 .. 2 {
		address := dom.URL{ value: 'https://native-revisit.test/page' }
		mut document := html.parse_navigation_document('<body><p id=result>pending</p></body>', address, address.origin(), none)!
		document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
		mut runtime := Runtime.create_with_engine(.libjs)
		settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
		runtime.bind_scripting_environment(settings)!
		runtime.install_libjs_document(document)!
		transport := &fetch.FetchHost{
			perform: fn (request &fetch.Request) !&fetch.Response {
				mut response := fetch.Response.create()
				response.url_list = request.url_list.clone()
				response.header_list.append(http.Header{ name: 'Content-Type', value: 'text/javascript' })
				response.set_body_bytes('export var n=40;export function next(){return ++n}'.bytes())
				return response
			}
		}
		mut host := ModuleHost.create(settings, transport)
		host.install(mut runtime)!
		assert runtime.run_document_scripts_collect_errors([ScriptSource{
			url:         'https://native-revisit.test/main.js'
			source_type: .module
			code:        'import {n,next} from "./dep.js";next();document.getElementById("result").textContent=n+"";'
		}]).len == 0
		deadline := time.sys_mono_now() + 5 * time.second
		mut loop := settings.responsible_event_loop()
		loop.spin_until(fn [runtime, deadline] () bool {
			return !runtime.has_pending_module_scripts() || time.sys_mono_now() >= deadline
		})
		assert !runtime.has_pending_module_scripts()
		assert host.errors().len == 0
		assert document.get_element_by_id('result')?.as_node().text_content()? == '41'
		if visit == 1 {
			assert runtime.frontend_code_cache_stats().hits == 2
		}
		runtime.close()
		document.finalize()
	}
}
