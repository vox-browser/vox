module browserjs

import browsersettings
import html
import libjs
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
	runtime.agent_vm.enable_native_code_cache(directory, compiler) or {
		eprintln('LibJS native cache unavailable: ${err.msg()}')
		return
	}
	runtime.libjs_native_cache_enabled_ = true
}

pub fn (runtime &Runtime) native_code_cache_stats() libjs.NativeCacheStats {
	return runtime.agent_vm.native_code_cache_stats()
}

fn (mut runtime Runtime) flush_document_native_cache() {
	if !runtime.libjs_native_cache_enabled_ || runtime.libjs_native_cache_failed_ { return }
	runtime.agent_vm.flush_native_code_cache() or {
		// A compiler/cache failure must not turn valid author code into an error
		// or retry its side effects. Existing cached entries remain usable.
		runtime.libjs_native_cache_failed_ = true
		eprintln('LibJS native cache compilation failed: ${err.msg()}')
	}
}

fn (runtime &Runtime) schedule_document_native_cache() {
	mut owner := unsafe { &Runtime(runtime) }
	if !owner.libjs_native_cache_enabled_ || owner.libjs_native_cache_pending_
		|| owner.libjs_native_cache_failed_ || owner.closed {
		return
	}
	if !owner.agent_vm.native_code_cache_is_idle()
		|| owner.native_code_cache_stats().pending_executables == 0 {
		return
	}
	if settings := owner.scripting_settings_ {
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		owner.libjs_native_cache_pending_ = true
		html.queue_a_task(.idle_task, settings.responsible_event_loop(), settings.responsible_document(), fn [owner] () {
			mut runtime := unsafe { &Runtime(owner) }
			runtime.libjs_native_cache_pending_ = false
			if !runtime.closed { runtime.flush_document_native_cache() }
		})
	} else {
		// Embedders without an HTML event loop still get the same first/second
		// visit semantics, with compilation after the outer script returns.
		owner.flush_document_native_cache()
	}
}
