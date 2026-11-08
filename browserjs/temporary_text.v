module browserjs

import platform

// A synchronous text result with an explicit retirement boundary. Published
// host state must own any strings it keeps after finish().
pub struct TemporaryText {
pub:
	value string
mut:
	workspace platform.ThreadScratchScope
}

pub fn (text TemporaryText) finish() { text.workspace.finish() }

pub fn (runtime &Runtime) evaluate_host_temporary_text(source string) !TemporaryText {
	if runtime.engine == .libjs { return TemporaryText{value: runtime.evaluate(source)!} }
	if runtime.closed { return error('JavaScript runtime is closed') }
	$if darwin || linux || windows {
		if runtime.context == unsafe { nil } { return error('JavaScriptCore context creation failed') }
		runtime.prepare_html_script()
		defer { runtime.clean_up_html_script() }
		return evaluate_javascript_core_text(runtime.context, ScriptSource{code:source}, true, false, true)
	} $else {
		return error('JavaScript evaluation is currently available on macOS only')
	}
}
