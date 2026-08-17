module browserjs

// Runtime is the browser-embedding boundary for actual ECMAScript evaluation. LibWeb's translated
// Bindings module owns realm/host bookkeeping; on macOS the executable supplies JavaScriptCore as
// the bytecode engine, just as upstream Ladybird supplies LibJS at this boundary.
pub struct Runtime {
mut:
	context voidptr
}

pub fn Runtime.create() &Runtime {
	mut context := unsafe { nil }
	$if darwin {
		context = create_javascript_core_context()
	}
	return &Runtime{
		context: context
	}
}

pub fn (runtime &Runtime) evaluate(source string) !string {
	$if darwin {
		if runtime.context == unsafe { nil } {
			return error('JavaScriptCore context creation failed')
		}
		return evaluate_with_javascript_core(runtime.context, source)
	} $else {
		return error('JavaScript evaluation is currently available on macOS only')
	}
}

pub fn (mut runtime Runtime) close() {
	$if darwin {
		if runtime.context != unsafe { nil } {
			release_javascript_core_context(runtime.context)
			runtime.context = unsafe { nil }
		}
	}
}
