module libjs

fn run_test_source(mut vm VM, source_text string) !Value {
	source := source_text.replace('NULLISH', '?'.repeat(2))
	mut script := Script.parse(source, vm.realm(), 'execution.js', unsafe { nil }) or {
		return error(source + ': ' + err.msg())
	}
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 10000 })
}

fn test_compiled_expressions_preserve_order_short_circuiting_and_numeric_updates() {
	for source, expected in {
		'1 + 2 * 3 ** 2;':                                                   '19'
		'"1" + true + null;':                                                '"1truenull"'
		'var x = 1; x + (x = 2);':                                           '3'
		'var x = 1; x += (x = 2); x;':                                       '3'
		'var x = 0; false && (x = 1); true || (x = 2); 0 ?? (x = 3); x;':    '0'
		'null ?? 42;':                                                       '42'
		'0 || 42;':                                                          '42'
		'var x = 0; false ? (x=1) : (x=42); x;':                             '42'
		'var x = "41"; x++;':                                                '41'
		'var x = "41"; ++x;':                                                '42'
		'var x = 4; x--; --x;':                                              '2'
		'var x = 0; x ||= 42; x &&= 41; x NULLISH= 0; x;':                   '41'
		'const x = 0; x &&= 42; x;':                                         '0'
		'var x = 0; var y = null; y NULLISH= (x=42); x+y;':                  '84'
		'var x = 6; x &= 3; x |= 8; x ^= 1; x <<= 2; x >>= 1; x >>>= 1; x;': '11'
		'-1 >>> 0;':                                                         '4294967295'
		'1 << 33;':                                                          '2'
		'-4 >> 1;':                                                          '-2'
		'"42" == 42;':                                                       'true'
		'"42" === 42;':                                                      'false'
		'0/0 <= 1;':                                                         'false'
		'0/0 >= 1;':                                                         'false'
		'"10" < "2";':                                                       'true'
		'typeof unknown;':                                                   '"undefined"'
		'typeof null;':                                                      '"object"'
		'typeof this;':                                                      '"object"'
		'void (42);':                                                        'undefined'
		'~1;':                                                               '-2'
	} {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		result := run_test_source(mut vm, source)!
		assert result.str() == expected, source
	}
}

fn test_compiled_blocks_loops_hoisting_and_completion_values() {
	for source, expected in {
		'var x = 42; {let x = 1; x;} x;':                                                '42'
		'{var x = 42;} x;':                                                              '42'
		'var x; x;':                                                                     'undefined'
		'x; var x=42;':                                                                  'undefined'
		'var x = 0; if (true) x=42; else x=1; x;':                                       '42'
		'var x = 0; while (x < 42) x++; x;':                                             '42'
		'var x = 0; do {x++;} while (x < 42); x;':                                       '42'
		'var x = 0; for (let i=0; i<7; ++i) x+=i; x;':                                   '21'
		'var x = 0; for (var i=0; i<7; ++i) {if(i===3)continue; x+=i;} x;':              '18'
		'var x = 0; for(;;) {let y=42; {let z=1; x=y; break;}} x;':                      '42'
		'for (let i=0; i<2; i++) {let x=i;} typeof i;':                                  '"undefined"'
		'var x=0; while(x<3) {x++; {let y=1; if(x<3)continue;}} x;':                     '3'
		'var x=0; do {x++; if(x<3)continue;} while(x<3); x;':                            '3'
		'var x=0; for(var i=0;i<3;i++) {for(var j=0;j<3;j++){if(j===1)break; x++;}} x;': '3'
		'42; var x;':                                                                    '42'
		'42; {}':                                                                        '42'
		'42; if(false) 1;':                                                              'undefined'
		'42; if(true) {}':                                                               'undefined'
		'42; while(false) 1;':                                                           'undefined'
		'':                                                                              'undefined'
	} {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		assert run_test_source(mut vm, source)!.str() == expected, source
		assert vm.execution_context_stack().len == 1
		assert vm.interpreter_stack().depth() == 0
	}
}

fn test_global_bindings_persist_between_scripts_and_instantiation_checks_are_atomic() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	run_test_source(mut vm, 'const prefix="LibJS"; var count=1;')!
	assert run_test_source(mut vm, 'count++; prefix + count;')!.as_string().str() == 'LibJS2'
	for source in ['let fresh; let prefix;', 'var fresh; var prefix;', 'let fresh; let count;'] {
		if _ := run_test_source(mut vm, source) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .syntax_error
		}
		assert !vm.realm().global_environment_record().has_lexical_declaration(utf16_string('fresh'))
		assert !vm.get_global_object().has_own_property(PropertyName.from_utf16(utf16_string('fresh')))
	}
	assert run_test_source(mut vm, 'var count; count;')!.number == 2
	assert vm.interpreter_stack().depth() == 0
}

fn test_runtime_errors_preserve_tdz_const_strictness_tracebacks_and_stack_cleanup() {
	for source, kind in {
		'{ typeof x; let x=1; }':    ErrorKind.reference_error
		'{ x=1; let x; }':           ErrorKind.reference_error
		'const x=1; x=2;':           ErrorKind.type_error
		'"use strict"; unknown=42;': ErrorKind.reference_error
		'let x=x;':                  ErrorKind.reference_error
	} {
		mut vm := VM.create()
		base := create_simple_execution_context(mut vm)
		if _ := run_test_source(mut vm, source) {
			assert false
		} else {
			object := thrown_value(err).as_object()
			assert object.error_kind()? == kind, source
			assert object.error_data?.stack_string(false).contains('execution.js')
		}
		assert vm.running_execution_context() == base
		assert vm.execution_context_stack().len == 1
		assert vm.interpreter_stack().depth() == 0
		assert vm.run_executable_depth() == 0
	}
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	if _ := run_test_source(mut vm, '{let x=1; throw 42;}') {
		assert false
	} else {
		assert thrown_value(err).number == 42
	}
	assert run_test_source(mut vm, 'typeof x;')!.as_string().str() == 'undefined'
	assert run_test_source(mut vm, 'sloppy=42; sloppy;')!.number == 42
}

fn test_unsupported_programs_are_rejected_before_any_execution_or_declarations() {
	for source in ['var changed=1; class C {}', 'var changed=1; false && class {};',
		'var changed=1; document?.body;', 'var changed=1; try {} catch(e) {}',
		'var changed=1; [1,2,3];', 'var changed=1; var {x}=y;'] {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		if _ := run_test_source(mut vm, source) {
			assert false
		} else {
			assert !is_throw_completion(err) && err.msg().contains('not translated'), source
		}
		assert !vm.get_global_object().has_own_property(PropertyName.from_utf16(utf16_string('changed')))
		assert vm.interpreter_stack().depth() == 0
		assert vm.execution_generation() == 0
	}
}

fn test_compilation_caches_executable_and_preserves_utf16_and_source_locations() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse('"\\ud800" + "\\udc00";\n42;', vm.realm(), 'cached.js',
		unsafe { nil })!
	first := script.compile(mut vm)!
	second := script.compile(mut vm)!
	assert first == second
	assert first.source_code?.code == utf16_string(script.parsed.source_text)
	assert first.source_map[first.source_map.len - 2].source_range.start.line == 2
	assert vm.run(mut script)!.number == 42
	mut joined := Script.parse('"\\ud800" + "\\udc00";', vm.realm(), 'utf16.js', unsafe { nil })!
	assert vm.run(mut joined)!.as_string().utf16.data == [u16(0xd800), 0xdc00]
}
