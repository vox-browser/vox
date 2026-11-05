// SPDX-License-Identifier: BSD-2-Clause
module browserjs

// Check only a conservative Script-parseable subset of keyword-free modules.
// A failed check (including lexical errors and unsupported top-level await
// forms) takes the original lexer/catch path, preserving its source fallback.
// This API checks syntax without evaluating the program. The native module
// loader still parses and executes the rewritten source with the Module goal.
fn (host &ModuleHost) can_skip_keyword_free_module_lexer(source string, is_module bool) bool {
	if disable_keyword_free_module_lexer || !is_module || host.runtime == unsafe { nil }
		|| host.runtime.closed || host.runtime.context == unsafe { nil }
		|| module_source_may_need_specifier_lexer(source) { return false }
	value := js_source_string(source)
	defer { C.JSStringRelease(value) }
	mut exception := unsafe { nil }
	return C.vox_jsc_JSCheckScriptSyntax(host.runtime.context, value, unsafe { nil }, 1,
		&exception) && exception == unsafe { nil }
}
