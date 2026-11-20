module browserjs

import libjs
import os
import platform

// The document's external scripts were parsed on the main thread when they
// ran; only modules fetched through the module loader used the parse workers.
// Start a worker parse as soon as a script body arrives instead. Execution
// reuses the result only when it is ready, error-free and parsed from the
// same text (prepare_libjs_frontend_with checks this); otherwise the main
// thread parses as before. VOX_LIBJS_SCRIPT_PREPARSE=0 is the same-binary
// control.
const libjs_script_preparse_disabled = os.getenv('VOX_LIBJS_SCRIPT_PREPARSE') == '0'

pub fn (runtime &Runtime) preparse_libjs_document_script(url string, body string) {
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
		// The script already ran and was parsed on this thread.
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
