// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import html
import os
import platform
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

fn test_native_cache_compiler_can_wait_for_a_browser_timer() {
	$if macos || linux {
		for close_while_compiling in [false, true] {
			check_native_cache_with_blocked_compiler(close_while_compiling)!
		}
	}
}

fn check_native_cache_with_blocked_compiler(close_while_compiling bool) ! {
	directory := os.join_path(os.temp_dir(), 'vox-native-background-' + rand.uuid_v4())
	os.mkdir_all(directory)!
	compiler := os.join_path(directory, 'compiler')
	started := os.join_path(directory, 'started')
	release := os.join_path(directory, 'release')
	os.write_file(compiler, '#!/bin/sh\n'
		+ 'touch ' + os.quoted_path(started) + '\n'
		+ 'attempts=0\n'
		+ 'while [ ! -e ' + os.quoted_path(release) + ' ]; do\n'
		+ '    attempts=$((attempts + 1))\n'
		+ '    [ "$attempts" -lt 250 ] || exit 3\n'
		+ '    sleep 0.02\n'
		+ 'done\n'
		+ 'exec clang "$@"\n')!
	os.chmod(compiler, 0o755)!
	previous_cache := os.getenv_opt('VOX_LIBJS_NATIVE_CACHE')
	previous_compiler := os.getenv_opt('VOX_LIBJS_NATIVE_COMPILER')
	os.setenv('VOX_LIBJS_NATIVE_CACHE', directory, true)
	os.setenv('VOX_LIBJS_NATIVE_COMPILER', compiler, true)
	defer {
		if value := previous_cache { os.setenv('VOX_LIBJS_NATIVE_CACHE', value, true) }
		else { os.unsetenv('VOX_LIBJS_NATIVE_CACHE') }
		if value := previous_compiler { os.setenv('VOX_LIBJS_NATIVE_COMPILER', value, true) }
		else { os.unsetenv('VOX_LIBJS_NATIVE_COMPILER') }
		os.rmdir_all(directory) or {}
	}
	address := dom.URL{ value: 'https://native-compiler.test/' }
	mut document := html.parse_navigation_document('<body></body>', address, address.origin(), none)!
	mut runtime := Runtime.create_with_engine(.libjs)
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	runtime.install_libjs_document(document)!
	mut loop := settings.responsible_event_loop()
	source := [ScriptSource{ url: 'https://native-compiler.test/script.js', code: 'function sum(a, b) { return a+b }; globalThis.answer=sum(40,2)' }]
	assert runtime.run_document_scripts_collect_errors(source).len == 0
	abi_path := os.join_path(directory, runtime.native_code_cache_stats().abi)
	mut timer := platform.Timer.create_repeating(20, fn [mut runtime, started, release, close_while_compiling] () {
		if !os.exists(started) || os.exists(release) { return }
		// The timer and the VM must run while the compiler is still waiting.
		assert (runtime.evaluate_host('answer') or { '' }) == '42'
		assert runtime.native_code_cache_stats().compiler_invocations == 0
		if close_while_compiling { runtime.close() }
		os.write_file(release, '') or { panic(err) }
	})
	timer.start()
	deadline := time.sys_mono_now() + 8 * time.second
	loop.spin_until(fn [runtime, abi_path, deadline, close_while_compiling] () bool {
		if time.sys_mono_now() >= deadline { return true }
		if !close_while_compiling { return !runtime.libjs_native_cache_pending_ }
		files := os.ls(abi_path) or { return false }
		return files.filter(it.ends_with('.json')).len == 2
	})
	timer.stop()
	platform.release_closure(voidptr(timer.on_timeout))
	timer.on_timeout = unsafe { nil }
	assert os.exists(release)
	if !close_while_compiling {
		assert runtime.native_code_cache_stats().compiler_invocations == 1
		assert runtime.native_code_cache_stats().compiled_executables == 2
		assert runtime.evaluate_host('sum(20, 22)')! == '42'
		runtime.close()
	}
	files := os.ls(abi_path)!
	assert files.filter(it.ends_with('.json')).len == 2
	document.finalize()
}
