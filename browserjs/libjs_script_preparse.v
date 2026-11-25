module browserjs

import libjs
import os
import platform

const libjs_script_preparse_disabled = os.getenv('VOX_LIBJS_SCRIPT_PREPARSE') == '0'

// The fetch worker owns the detached arena until it publishes a clean parse.
// From then on the script loader owns it until execution or cancellation.
@[heap]
pub struct ClassicScriptFrontend {
mut:
	parsed &libjs.ParsedSource
	arena voidptr
	used bool
}

pub fn prepare_classic_script_frontend(body string) ?&ClassicScriptFrontend {
	if libjs_script_preparse_disabled || !libjs_background_parse_available()
		|| body.len < 32 * 1024 || body.len > libjs_frontend_cache_max_entry_bytes {
		return none
	}
	mut arena := voidptr(unsafe { nil })
	$if prealloc { arena = unsafe { prealloc_scope_begin() } }
	parsed := libjs.parse_source_with_options(body.clone(), .script, libjs_browser_parse_options)
	$if prealloc { unsafe { prealloc_scope_leave(arena) } }
	if parsed.has_errors() || parsed.reached_recursion_limit {
		$if prealloc { unsafe { prealloc_scope_free_after(arena) } }
		return none
	}
	return &ClassicScriptFrontend{parsed: parsed, arena: arena}
}

pub fn (mut frontend ClassicScriptFrontend) discard_unused() {
	// A consumed parse can be kept by compiled functions or the shared cache,
	// just like syntax prepared directly in persistent storage.
	if frontend.used { return }
	$if prealloc {
		if frontend.arena != unsafe { nil } {
			unsafe { prealloc_scope_free_after(frontend.arena) }
			frontend.arena = unsafe { nil }
		}
	}
	frontend.parsed = unsafe { nil }
}

pub fn (runtime &Runtime) preparse_libjs_document_module(url string, body string) {
	if libjs_script_preparse_disabled || runtime == unsafe { nil } || runtime.engine != .libjs
		|| runtime.closed || url == '' || body.len == 0 {
		return
	}
	mut host := runtime.module_host_ or { return }
	if host.closed || url in runtime.libjs_modules_ || url in host.libjs_preparsed
		|| url in host.libjs_preparsing {
		return
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	key := url.clone()
	source := body.clone()
	owner := voidptr(host)
	done := fn [owner, key] (parsed &libjs.ParsedSource) {
		mut host := unsafe { &ModuleHost(owner) }
		host.libjs_preparsing.delete(key)
		if host.closed { return }
		runtime := unsafe { &Runtime(host.runtime) }
		// The module already ran and was parsed on this thread.
		if key in runtime.libjs_modules_ { return }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		host.libjs_preparsed[key] = parsed
	}
	if !submit_libjs_module_parse(source, libjs.ParseOptions{ max_recursion_depth: 256 }, done) {
		platform.release_closure(voidptr(done))
		return
	}
	host.libjs_preparsing[key] = true
	host.libjs_background_parses++
}
