module browserjs

import dom
import html
import os
import rand

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
			assert stats.compiler_invocations == 1 && stats.compiled_executables == 2
			assert activity.entries == 0
		} else {
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
			mut loop := settings.responsible_event_loop()
			for _ in 0 .. 16 {
				if !runtime.libjs_native_cache_pending_ { break }
				loop.process()
			}
			assert !runtime.libjs_native_cache_pending_
			assert runtime.native_code_cache_stats().compiler_invocations == 1
			assert runtime.native_code_cache_stats().compiled_executables == 3
		} else {
			assert runtime.native_code_cache_stats().cache_hits == 3
			assert runtime.native_code_cache_stats().cache_misses == 0
			assert !runtime.libjs_native_cache_pending_
		}
		runtime.close()
		document.finalize()
	}
}
