module browserjs

fn test_javascript_core_evaluates_ecmascript_and_reports_exceptions() {
	mut runtime := Runtime.create()
	defer {
		runtime.close()
	}
	$if darwin {
		assert runtime.evaluate('JSON.stringify({ answer: 6 * 7 })')! == '{"answer":42}'
		assert runtime.evaluate('globalThis.answer = 41; "set"')! == 'set'
		assert runtime.evaluate('answer + 1')! == '42'
		if _ := runtime.evaluate('throw new Error("boom")') {
			assert false
		} else {
			assert err.msg().contains('boom')
		}
	} $else {
		assert runtime.evaluate('1 + 1') or { err.msg() }.contains('macOS')
	}
}

fn test_javascript_core_drains_promise_jobs_between_evaluations() {
	$if darwin {
		mut runtime := Runtime.create()
		defer {
			runtime.close()
		}
		assert runtime.evaluate('globalThis.promise_value = 0; Promise.resolve().then(() => promise_value = 42); promise_value')! == '0'
		assert runtime.evaluate('promise_value')! == '42'
	}
}

fn test_browser_preparation_retains_libjs_ast_and_positioned_early_errors() {
	script := prepare_script(ScriptSource{
		code: '"use strict"; const answer = 42;'
		url:  'https://example.test/app.js'
	})!
	assert script.frontend.is_strict_mode
	assert !script.frontend.has_errors()
	assert script.frontend.dump_ast()!.contains('VariableDeclaration')
	if _ := prepare_script(ScriptSource{
		code:          '\nlet duplicate; let duplicate;'
		url:           'https://example.test/broken.js'
		starting_line: 20
	})
	{
		assert false
	} else {
		assert err.msg().starts_with('SyntaxError: https://example.test/broken.js:21:')
	}
	module_script := prepare_script(ScriptSource{
		code:        'export default await Promise.resolve(42);'
		source_type: .module
	})!
	assert module_script.frontend.is_strict_mode
	assert module_script.frontend.has_top_level_await
}

fn test_browser_backend_handles_frontend_stack_limit_and_regex_validation() {
	$if darwin {
		mut runtime := Runtime.create()
		defer { runtime.close() }
		assert runtime.evaluate('"a' + [u8(0)].bytestr() + '😀".length')! == '4'
		located := prepare_script(ScriptSource{
			code:          'new Error("located").stack'
			url:           'https://example.test/located.js'
			starting_line: 12
		})!
		assert runtime.evaluate_prepared(located)!.contains('https://example.test/located.js:12:')
		if _ := runtime.evaluate_prepared(prepare_script(ScriptSource{
			code:          'throw new Error("located failure");'
			url:           'https://example.test/located.js'
			starting_line: 12
		})!)
		{
			assert false
		} else {
			assert err.msg().contains('Error: located failure\n')
			assert err.msg().contains('https://example.test/located.js:12:')
		}
		if _ := runtime.evaluate('throw { toString() { return "no stack"; }, get stack() { throw new Error("getter failure"); } };') {
			assert false
		} else {
			assert err.msg() == 'no stack'
		}
		deep := prepare_script(ScriptSource{ code: '('.repeat(40) + '42' + ')'.repeat(40) })!
		assert deep.frontend.reached_recursion_limit
		assert runtime.evaluate_prepared(deep)! == '42'
		for invalid in ['('.repeat(40) + '42' + ')'.repeat(39), '/[a-/'] {
			if _ := runtime.evaluate(invalid) {
				assert false
			} else {
				assert err.msg().contains('SyntaxError')
			}
		}
		module_script := prepare_script(ScriptSource{
			code:        'globalThis.leaked = true;'
			source_type: .module
		})!
		if _ := runtime.evaluate_prepared(module_script) {
			assert false
		} else {
			assert err.msg().contains('Module execution')
		}
		assert runtime.evaluate('typeof leaked')! == 'undefined'
	}
}

fn test_browser_runtime_owns_distinct_libjs_realms_and_restores_embedding_contexts() {
	mut first := Runtime.create()
	mut second := Runtime.create()
	defer { second.close() }
	assert voidptr(first.libjs_vm()) != voidptr(second.libjs_vm())
	assert voidptr(first.libjs_realm()) != voidptr(second.libjs_realm())
	assert first.libjs_vm().execution_context_stack().len == 1
	assert voidptr(first.libjs_vm().realm()) == voidptr(first.libjs_realm())
	$if darwin {
		assert first.evaluate('const owned = 42; owned')! == '42'
		if _ := first.evaluate('throw new Error("failure")') { assert false
		 }
		assert first.libjs_vm().execution_context_stack().len == 1
		assert first.libjs_vm().get_active_script_or_module().is_empty()
		assert second.evaluate('typeof owned')! == 'undefined'
	}
	first.close()
	first.close()
	assert !first.libjs_vm().has_running_execution_context()
	if _ := first.evaluate('1 + 1') {
		assert false
	} else {
		assert err.msg().contains('closed')
	}
}

fn test_document_programs_share_lexical_bindings_drain_jobs_and_isolate_errors() {
	$if darwin {
		mut runtime := Runtime.create()
		defer { runtime.close() }
		runtime.evaluate_host('globalThis.entries = []; globalThis.console = { error: value => entries.push(String(value)) };')!
		runtime.run_document_scripts([
			ScriptSource{
				code: 'const answer = 41; Promise.resolve().then(() => entries.push("promise"));'
			},
			ScriptSource{
				code: 'entries.push(answer + 1); ({ toString() { throw new Error("completion coerced"); } });'
			},
			ScriptSource{
				code: 'entries.push("must not run"); let duplicate; let duplicate;'
				url:  'broken.js'
			},
			ScriptSource{ code: 'throw new Error("runtime failure");' },
			ScriptSource{ code: 'entries.push("continued");' },
		])!
		entries := runtime.evaluate('JSON.stringify(entries)')!
		assert entries.starts_with('["promise",42,"SyntaxError: broken.js:')
		assert entries.contains('Error: runtime failure')
		assert entries.ends_with(',"continued"]')
		assert !entries.contains('must not run')
		assert !entries.contains('completion coerced')
	}
}
