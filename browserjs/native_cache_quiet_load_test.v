// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import html
import os
import rand
import time

fn test_document_cache_waits_for_later_html_work_before_its_first_compilation() {
	directory := os.join_path(os.temp_dir(), 'vox-native-quiet-load-' + rand.uuid_v4())
	previous := os.getenv_opt('VOX_LIBJS_NATIVE_CACHE')
	compiler := os.getenv_opt('VOX_LIBJS_NATIVE_COMPILER')
	os.setenv('VOX_LIBJS_NATIVE_CACHE', directory, true)
	os.setenv('VOX_LIBJS_NATIVE_COMPILER', '/usr/bin/clang', true)
	defer {
		if value := previous {
			os.setenv('VOX_LIBJS_NATIVE_CACHE', value, true)
		} else {
			os.unsetenv('VOX_LIBJS_NATIVE_CACHE')
		}
		if value := compiler {
			os.setenv('VOX_LIBJS_NATIVE_COMPILER', value, true)
		} else {
			os.unsetenv('VOX_LIBJS_NATIVE_COMPILER')
		}
		os.rmdir_all(directory) or {}
	}
	address := dom.URL{ value: 'https://quiet-load.test/' }
	document := html.parse_navigation_document('<body></body>', address, address.origin(), none)!
	mut runtime := Runtime.create_with_engine(.libjs)
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	runtime.install_libjs_document(document)!
	assert runtime.run_document_scripts_collect_errors([ScriptSource{ url: 'https://quiet-load.test/first.js', code: 'function first(){return 1}globalThis.firstValue=first()' }]).len == 0
	assert runtime.native_code_cache_stats().compiler_invocations == 0
	html.queue_a_task(.dom_manipulation, settings.responsible_event_loop(), document, fn [mut runtime] () {
		assert runtime.run_document_scripts_collect_errors([ScriptSource{ url: 'https://quiet-load.test/later.js', code: 'function later(){return 2}globalThis.laterValue=later()' }]).len == 0
		assert runtime.native_code_cache_stats().compiler_invocations == 0
	})
	mut loop := settings.responsible_event_loop()
	deadline := time.sys_mono_now() + 5 * time.second
	loop.spin_until(fn [runtime, deadline] () bool {
		return !runtime.libjs_native_cache_pending_ || time.sys_mono_now() >= deadline
	})
	assert runtime.evaluate_host('firstValue===1&&laterValue===2')! == 'true'
	stats := runtime.native_code_cache_stats()
	assert stats.compiler_invocations == 1 && stats.compiled_executables == 4
	timer := runtime.libjs_native_cache_timer_
	runtime.close()
	assert !timer.is_active() && timer.on_timeout == unsafe { nil }
}
