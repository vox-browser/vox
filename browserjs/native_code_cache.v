module browserjs

import browsersettings
import libjs
import json2
import os
import platform

// Every LibJS document uses its profile's persistent executable cache. Ordinary
// standalone Runtime.evaluate calls and the JavaScriptCore backend are unaffected.
fn (mut runtime Runtime) initialize_document_native_cache() {
	if runtime.engine != .libjs || runtime.libjs_native_cache_enabled_ { return }
	choice := os.getenv('VOX_LIBJS_NATIVE_CACHE')
	if choice in ['0', 'off'] { return }
	directory := if choice != '' && choice != '1' {
		choice
	} else {
		os.join_path(os.dir(browsersettings.default_path()), 'libjs-native-code')
	}
	compiler := os.getenv_opt('VOX_LIBJS_NATIVE_COMPILER') or { 'clang' }
	runtime.agent_vm.enable_native_code_cache_with_options(directory, compiler, libjs.NativeCodeCacheOptions{
		generated_code_identity: os.getenv('VOX_LIBJS_NATIVE_GENERATED_CODE_CACHE') == '1'
	}) or {
		eprintln('LibJS native cache unavailable: ${err.msg()}')
		return
	}
	runtime.libjs_native_cache_enabled_ = true
	runtime.libjs_native_cache_partition_ = os.real_path(directory)
	if os.getenv('VOX_LIBJS_NATIVE_DIAGNOSTICS') == '1' {
		runtime.agent_vm.diagnose_native_code(true) or {
			eprintln('LibJS native cache diagnostics unavailable: ${err.msg()}')
		}
	}
}

pub fn (runtime &Runtime) native_code_cache_stats() libjs.NativeCacheStats {
	return runtime.agent_vm.native_code_cache_stats()
}

fn (mut runtime Runtime) flush_document_native_cache() {
	if !runtime.libjs_native_cache_enabled_ || runtime.libjs_native_cache_failed_ { return }
	for runtime.has_pending_native_module_templates() { runtime.prepare_native_module_templates_batch() }
	runtime.agent_vm.flush_native_code_cache() or {
		// A compiler/cache failure must not turn valid author code into an error
		// or retry its side effects. Existing cached entries remain usable.
		runtime.libjs_native_cache_failed_ = true
		eprintln('LibJS native cache compilation failed: ${err.msg()}')
	}
	runtime.agent_vm.persist_native_lookup_index() or {
		eprintln('LibJS native lookup index was not saved: ${err.msg()}')
	}
}

fn (runtime &Runtime) write_final_native_cache_audit() {
	path := os.getenv('VOX_LIBJS_NATIVE_CACHE_FINAL_AUDIT_PATH')
	if path == '' || !runtime.libjs_native_cache_enabled_ { return }
	os.write_file(path, json2.encode(runtime.compiled_code_cache_audit()) + '\n') or {
		eprintln('LibJS final native cache audit failed: ${err.msg()}')
	}
}

fn (runtime &Runtime) schedule_document_native_cache() {
	mut owner := unsafe { &Runtime(runtime) }
	if !owner.libjs_native_cache_enabled_
		|| owner.libjs_native_cache_failed_ || owner.closed {
		return
	}
	if !owner.agent_vm.native_code_cache_is_idle()
		|| (owner.native_code_cache_stats().pending_executables == 0 && !owner.has_pending_native_module_templates()) {
		return
	}
	if owner.scripting_settings_ != none {
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		owner.libjs_native_cache_pending_ = true
		// An idle task can run between asynchronous module/fetch deliveries.
		// Coalesce until author work is quiet so compilation does not interrupt
		// initial hydration while the next response is still in flight.
		if owner.libjs_native_cache_timer_ == unsafe { nil } {
			owner.libjs_native_cache_timer_ = platform.Timer.create_single_shot(1000, fn [owner] () {
				mut runtime := unsafe { &Runtime(owner) }
				if runtime.closed { return }
				if !runtime.agent_vm.native_code_cache_is_idle() || runtime.has_pending_module_scripts() || runtime.has_pending_libjs_fetches() {
					runtime.libjs_native_cache_timer_.start()
					return
				}
				runtime.libjs_native_cache_pending_ = false
				runtime.flush_document_native_cache_batch()
				if !runtime.libjs_native_cache_failed_ && (runtime.native_code_cache_stats().pending_executables>0 || runtime.has_pending_native_module_templates()) {
					runtime.libjs_native_cache_pending_ = true
					runtime.libjs_native_cache_timer_.start()
				}
			})
		}
		owner.libjs_native_cache_timer_.restart()
	} else {
		// Embedders without an HTML event loop still get the same first/second
		// visit semantics, with compilation after the outer script returns.
		owner.flush_document_native_cache()
	}
}

fn (mut runtime Runtime) flush_document_native_cache_batch() {
	if !runtime.libjs_native_cache_enabled_ || runtime.libjs_native_cache_failed_ { return }
	runtime.prepare_native_module_templates_batch()
	runtime.agent_vm.flush_native_code_cache_batch() or {
		runtime.libjs_native_cache_failed_ = true
		eprintln('LibJS native cache compilation failed: ${err.msg()}')
	}
}

fn (mut runtime Runtime) stop_document_native_cache_timer() {
	if runtime.libjs_native_cache_timer_ == unsafe { nil } { return }
	mut timer := runtime.libjs_native_cache_timer_
	timer.stop()
	callback := timer.on_timeout
	timer.on_timeout = unsafe { nil }
	runtime.libjs_native_cache_timer_ = unsafe { nil }
	runtime.libjs_native_cache_pending_ = false
	platform.release_closure(voidptr(callback))
}
