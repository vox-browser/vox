module browserjs

import libjs
import platform

pub struct JavaScriptURLCompletion {
pub:
	markup ?string
}

fn (runtime &Runtime) execute_libjs_classic(script &PreparedScript) !libjs.Value {
	// Realm-owned values outlive the browser's event/parser scratch arena.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if script.frontend.reached_recursion_limit {
		return error('LibJS frontend recursion limit reached; this program cannot be executed by the translated runtime')
	}
	mut vm := unsafe { &libjs.VM(runtime.agent_vm) }
	runtime.prepare_html_script()
	defer { runtime.clean_up_html_script() }
	mut record := &libjs.Script{
		realm: runtime.realm
		filename: if script.source.url == '' { '<script>' } else { script.source.url }
		starting_line: u32(script.source.starting_line)
		host_defined: voidptr(runtime)
		parsed: script.frontend
		is_strict_mode: script.frontend.is_strict_mode
	}
	return vm.run_with_limits(mut record, runtime.libjs_execution_limits()) or {
		return error(libjs_exception_message(err))
	}
}

// A javascript: navigation replaces the document only for a primitive String
// completion. Reading that completion must never run an object's coercion hooks.
pub fn (mut runtime Runtime) evaluate_javascript_url(source string) !JavaScriptURLCompletion {
	runtime.check_execution_support(.script)!
	if runtime.engine == .libjs {
		prepared := runtime.prepare_libjs_script(ScriptSource{code: source})!
		value := runtime.execute_libjs_classic(prepared)!
		return JavaScriptURLCompletion{markup: if value.is_string() { ?string(value.as_string().str()) } else { none }}
	}
	value := runtime.evaluate_host_value(source)!
	defer { runtime.release_javascript_value(value) }
	return JavaScriptURLCompletion{markup: if text := runtime.native_utf16_string(value) { ?string(text.str()) } else { none }}
}
