module browserjs

fn test_libjs_backend_executes_bytecode_and_keeps_javascriptcore_uninitialized() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	assert runtime.engine == .libjs
	assert runtime.context == unsafe { nil }
	assert runtime.evaluate('const answer=41; answer+1;')! == '42'
	assert runtime.evaluate('answer;')! == '41'
	assert runtime.evaluate('var x=0; for(let i=0;i<7;i++) x+=i; x*2;')! == '42'
	assert runtime.evaluate('undefined;')! == 'undefined'
	assert runtime.evaluate('NaN !== NaN;')! == 'true'
	assert runtime.evaluate('this === globalThis;')! == 'true'
	if _ := runtime.evaluate('answer=0;') {
		assert false
	} else {
		assert err.msg().starts_with('TypeError:')
	}
	assert runtime.libjs_vm().execution_context_stack().len == 1
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
	runtime.close()
	if _ := runtime.evaluate('1;') {
		assert false
	} else {
		assert err.msg().contains('closed')
	}
}

fn test_libjs_backend_isolates_errors_and_never_falls_back_to_javascriptcore() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	errors := runtime.run_document_scripts_collect_errors([
		ScriptSource{ code: 'const x=40;' },
		ScriptSource{ code: 'var leaked=1; class C {}', url: 'unsupported.js' },
		ScriptSource{ code: 'let duplicate; let duplicate;', url: 'syntax.js' },
		ScriptSource{ code: 'throw 42;', url: 'throw.js' },
		ScriptSource{ code: 'var result=x+2;' },
	])
	assert errors.len == 3
	assert errors[0].contains('unsupported.js:1:') && errors[0].contains('not translated')
	assert errors[1].contains('SyntaxError: syntax.js:1:')
	assert errors[2].contains('42')
	assert runtime.evaluate('result;')! == '42'
	assert runtime.evaluate('typeof leaked;')! == 'undefined'
	assert runtime.context == unsafe { nil }
	for source in ['('.repeat(40) + '42' + ')'.repeat(40), '/a/', '/[a-/'] {
		if _ := runtime.evaluate(source) {
			assert false
		} else {
			assert err.msg().contains('limit') || err.msg().contains('not translated')
				|| err.msg().contains('SyntaxError')
		}
	}
	if _ := runtime.evaluate_host('class Unsupported {}') {
		assert false
	} else {
		assert err.msg().contains('not translated')
	}
	assert runtime.context == unsafe { nil }
}

fn test_document_execution_rejects_modules_before_frontend_preparation() {
	module_source := ScriptSource{
		code:        'export default ;'
		url:         'unsupported-module.js'
		source_type: .module
	}
	// The explicit AST API still parses modules and reports syntax errors.
	if _ := prepare_script(module_source) {
		assert false
	} else {
		assert err.msg().starts_with('SyntaxError: unsupported-module.js:')
	}
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	errors := runtime.run_document_scripts_collect_errors([
		module_source,
		ScriptSource{ code: 'var continued_after_module = 42;' },
	])
	assert errors == ['Module execution is not yet implemented by the browser JavaScript backend']
	assert runtime.evaluate('continued_after_module;')! == '42'
	runtime.close()
	assert runtime.run_document_scripts_collect_errors([module_source]) == ['JavaScript runtime is closed']
	$if darwin || linux {
		mut browser_runtime := Runtime.create()
		defer { browser_runtime.close() }
		browser_runtime.evaluate_host('globalThis.entries = []; globalThis.console = { error: value => entries.push(String(value)) };')!
		browser_runtime.run_document_scripts([
			module_source,
			ScriptSource{ code: 'entries.push("continued");' },
		])!
		assert browser_runtime.evaluate('JSON.stringify(entries)')! == '["Module execution is not yet implemented by the browser JavaScript backend","continued"]'
	}
}

fn test_libjs_backend_executes_bigint_and_translated_property_reads() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	assert runtime.evaluate('2n ** 100n;')! == '1267650600228229401496703205376'
	assert runtime.evaluate('var big=1n; big++; ++big;')! == '3'
	assert runtime.evaluate('9007199254740993n > 9007199254740992;')! == 'true'
	assert runtime.evaluate('"A😀".length;')! == '3'
	assert runtime.evaluate('globalThis.Infinity === Infinity;')! == 'true'
	assert runtime.evaluate('globalThis["undefined"];')! == 'undefined'
	assert runtime.evaluate('globalThis.runtimeAnswer=parseInt("2a",16); ++globalThis.runtimeAnswer;')! == '43'
	assert runtime.evaluate('"runtimeAnswer" in globalThis;')! == 'true'
	assert runtime.evaluate('delete globalThis.runtimeAnswer;')! == 'true'
	assert runtime.evaluate('"runtimeAnswer" in globalThis;')! == 'false'
	assert runtime.evaluate('isFinite(parseFloat("1.23tail")) && !isNaN(parseInt("42"));')! == 'true'
	assert runtime.evaluate('decodeURIComponent(encodeURIComponent("hello 😀"));')! == 'hello 😀'
	if _ := runtime.evaluate('1n + 1;') {
		assert false
	} else {
		assert err.msg().starts_with('TypeError:')
	}
	assert runtime.evaluate('42n;')! == '42'
	assert runtime.context == unsafe { nil }
	assert runtime.libjs_vm().execution_context_stack().len == 1
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_libjs_backend_preserves_source_urls_and_starting_lines() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	script := prepare_script(ScriptSource{
		code:          '\nconst x=1; x=2;'
		url:           'https://example.test/limited.js'
		starting_line: 12
	})!
	if _ := runtime.evaluate_prepared(script) {
		assert false
	} else {
		assert err.msg().starts_with('TypeError:')
		assert err.msg().contains('https://example.test/limited.js:13:')
	}
	unsupported := prepare_script(ScriptSource{
		code:          '\n(class {});'
		url:           'https://example.test/unsupported.js'
		starting_line: 20
	})!
	if _ := runtime.evaluate_prepared(unsupported) {
		assert false
	} else {
		assert err.msg().contains('https://example.test/unsupported.js:21:')
	}
}

fn test_engine_selection_keeps_javascriptcore_available() {
	assert parse_engine('javascriptcore')! == .javascriptcore
	assert parse_engine('libjs')! == .libjs
	if _ := parse_engine('unknown') {
		assert false
	} else {
		assert err.msg().contains('javascriptcore or libjs')
	}
	$if darwin || linux {
		mut runtime := Runtime.create_with_engine(.javascriptcore)
		defer { runtime.close() }
		assert runtime.engine == .javascriptcore
		assert runtime.context != unsafe { nil }
		assert runtime.evaluate('JSON.stringify({answer:42})')! == '{"answer":42}'
	}
}

fn test_javascript_core_evaluates_ecmascript_and_reports_exceptions() {
	mut runtime := Runtime.create()
	defer {
		runtime.close()
	}
	$if darwin || linux {
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
	$if darwin || linux {
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
	$if darwin || linux {
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
	$if darwin || linux {
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
	$if darwin || linux {
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
