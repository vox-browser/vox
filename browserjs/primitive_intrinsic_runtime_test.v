module browserjs

fn check_browser_primitive_intrinsics(mut runtime Runtime) ! {
	for source, expected in {
		'Boolean("false");': 'true'
		'false.toString();': 'false'
		'new Boolean(false).valueOf();': 'false'
		'new (Boolean.bind(null,true))().valueOf();': 'true'
		'new Boolean(false) instanceof Boolean.bind(null);': 'true'
		'Symbol().description;': 'undefined'
		'Symbol("").description;': ''
		'Symbol("key").toString();': 'Symbol(key)'
		'Symbol("key") === Symbol("key");': 'false'
		'Symbol.for("key") === Symbol.for("key");': 'true'
		'Symbol.keyFor(Symbol.for("key"));': 'key'
		'Symbol.iterator.description;': 'Symbol.iterator'
		'globalThis[Symbol.for("answer")]=42; globalThis[Symbol.for("answer")];': '42'
	} {
		assert runtime.evaluate(source)! == expected, source
	}
}

fn test_browser_libjs_primitive_intrinsics_execute_without_a_javascriptcore_context() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	check_browser_primitive_intrinsics(mut runtime)!
	assert runtime.context == unsafe { nil }
	assert runtime.libjs_vm().execution_context_stack().len == 1
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_browser_libjs_construction_errors_keep_source_locations_and_continue_later_scripts() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	errors := runtime.run_document_scripts_collect_errors([
		ScriptSource{code: 'new Symbol("key"); globalThis.leaked=1;', url: 'symbol-new.js'},
		ScriptSource{code: 'new parseInt("42");', url: 'function-new.js'},
		ScriptSource{code: 'Symbol.prototype.description;', url: 'symbol-brand.js'},
		ScriptSource{code: 'var answer=Boolean(new Boolean(false)) ? 42 : 0;', url: 'after.js'},
	])
	assert errors.len == 3
	for index, filename in ['symbol-new.js', 'function-new.js', 'symbol-brand.js'] {
		assert errors[index].contains('TypeError:') && errors[index].contains('${filename}:1:')
	}
	assert runtime.evaluate('typeof leaked;')! == 'undefined'
	assert runtime.evaluate('answer;')! == '42'
	assert runtime.context == unsafe { nil }
	assert runtime.libjs_vm().execution_context_stack().len == 1
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_browser_javascriptcore_selection_preserves_primitive_intrinsics() {
	$if darwin {
		mut runtime := Runtime.create_with_engine(.javascriptcore)
		defer { runtime.close() }
		check_browser_primitive_intrinsics(mut runtime)!
		assert runtime.context != unsafe { nil }
	}
}
