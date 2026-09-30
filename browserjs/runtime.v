module browserjs

import libjs
import json2

pub struct ScriptSource {
pub:
	code          string
	url           string
	starting_line int              = 1
	source_type   libjs.SourceType = .script
}

@[heap]
pub struct PreparedScript {
pub:
	source   ScriptSource
	frontend &libjs.ParsedSource
}

// Retain the translated AST and scope analysis at the browser's engine boundary.
// The backend must still validate RegExp patterns and input beyond the V parser's
// recursion budget; neither of those limits is an ECMAScript syntax error.
pub fn prepare_script(source ScriptSource) !&PreparedScript {
	if source.starting_line < 1 {
		return error('Script starting line must be positive')
	}
	parsed := libjs.parse_source(source.code, source.source_type)
	if parsed.has_errors() && !parsed.reached_recursion_limit {
		diagnostic := parsed.diagnostics[0]
		filename := if source.url == '' { '<script>' } else { source.url }
		line := u64(source.starting_line) + diagnostic.line - 1
		return error('SyntaxError: ${filename}:${line}:${diagnostic.column + 1}: ${diagnostic.message}')
	}
	return &PreparedScript{source, parsed}
}

// Runtime embeds the LibJS frontend and a JavaScriptCore execution backend.
// Bytecode generation, builtin objects and module execution are still pending in V.
pub struct Runtime {
	agent_vm &libjs.VM
	realm    &libjs.Realm
mut:
	context voidptr
	closed  bool
}

pub fn Runtime.create() &Runtime {
	mut agent_vm := libjs.VM.create()
	realm_context := libjs.create_simple_execution_context(mut agent_vm)
	mut context := unsafe { nil }
	$if darwin {
		context = create_javascript_core_context()
	}
	return &Runtime{
		agent_vm: agent_vm
		realm:    realm_context.realm or { panic('browser realm was not initialized') }
		context:  context
	}
}

pub fn (runtime &Runtime) libjs_vm() &libjs.VM {
	return runtime.agent_vm
}

pub fn (runtime &Runtime) libjs_realm() &libjs.Realm {
	return runtime.realm
}

pub fn (runtime &Runtime) evaluate(source string) !string {
	return runtime.evaluate_prepared(prepare_script(ScriptSource{ code: source })!)
}

pub fn (runtime &Runtime) evaluate_prepared(script &PreparedScript) !string {
	return runtime.execute_prepared(script, true)
}

fn (runtime &Runtime) execute_prepared(script &PreparedScript, stringify_result bool) !string {
	if runtime.closed {
		return error('JavaScript runtime is closed')
	}
	if script.source.source_type == .module {
		return error('Module execution is not yet implemented by the browser JavaScript backend')
	}
	// Associate this host execution with the translated Script/Realm records.
	// These are embedding contexts; JavaScriptCore still owns its JS call frames,
	// global bindings and promise reactions until the interpreter is translated.
	mut vm := unsafe { &libjs.VM(runtime.agent_vm) }
	mut execution := libjs.ExecutionContext.create(0, [], 0)
	execution.realm = runtime.realm
	global_environment := runtime.realm.global_environment_record()
	execution.lexical_environment = libjs.Environment(global_environment)
	execution.variable_environment = libjs.Environment(global_environment)
	if !script.frontend.has_errors() {
		execution.script_or_module = libjs.ScriptOrModule.from_script(&libjs.Script{
			realm:          runtime.realm
			filename:       script.source.url
			host_defined:   voidptr(runtime)
			parsed:         script.frontend
			is_strict_mode: script.frontend.is_strict_mode
		})
	}
	vm.push_execution_context_checked(mut execution)!
	defer {
		vm.pop_execution_context()
	}
	return runtime.evaluate_backend(script.source, stringify_result)
}

// Host-generated bootstrap and DOM dispatch code has its own trusted boundary;
// it must not consume the much smaller translated parser stack budget.
pub fn (runtime &Runtime) evaluate_host(source string) !string {
	return runtime.evaluate_backend(ScriptSource{ code: source }, true)
}

fn (runtime &Runtime) evaluate_backend(source ScriptSource, stringify_result bool) !string {
	if runtime.closed {
		return error('JavaScript runtime is closed')
	}
	$if darwin {
		if runtime.context == unsafe { nil } {
			return error('JavaScriptCore context creation failed')
		}
		return evaluate_with_javascript_core(runtime.context, source, stringify_result)
	} $else {
		return error('JavaScript evaluation is currently available on macOS only')
	}
}

// Each script runs as a separate global program, followed by the backend's
// microtask checkpoint. One failed script must not prevent later scripts or
// the document's readiness events. Do not coerce discarded completion values.
pub fn (runtime &Runtime) run_document_scripts(sources []ScriptSource) ! {
	for source in sources {
		script := prepare_script(source) or {
			runtime.evaluate_host('console.error(${json2.encode(err.msg())})')!
			continue
		}
		runtime.execute_prepared(script, false) or {
			runtime.evaluate_host('console.error(${json2.encode(err.msg())})')!
		}
	}
}

pub fn (mut runtime Runtime) close() {
	if runtime.closed {
		return
	}
	$if darwin {
		if runtime.context != unsafe { nil } {
			release_javascript_core_context(runtime.context)
			runtime.context = unsafe { nil }
		}
	}
	mut vm := unsafe { &libjs.VM(runtime.agent_vm) }
	vm.clear_execution_context_stack()
	runtime.closed = true
}
