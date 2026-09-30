module libjs

fn execute_bigint_source(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'bigint.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 10000 })
}

// Literal/operator cases from upstream Runtime/builtins/BigInt/bigint-basic.js
// and regress/string-to-number-and-bigint-non-decimal-prefixes.js, executed by
// the translated generator and interpreter rather than a host JavaScript engine.
fn test_compiled_bigint_literals_arithmetic_updates_and_comparisons() {
	for source, expected in {
		'typeof 1n;':                                                                                                 '"bigint"'
		'0xffn + 0O10n + 0B10n;':                                                                                     '265n'
		'0xffff_ffffn & -1n;':                                                                                        '4294967295n'
		'1_000_000n + 1n;':                                                                                           '1000001n'
		'12n + 34n;':                                                                                                 '46n'
		'12n - 34n;':                                                                                                 '-22n'
		'8n * 12n;':                                                                                                  '96n'
		'-123n / 10n;':                                                                                               '-12n'
		'-5n % 3n;':                                                                                                  '-2n'
		'2n ** 100n;':                                                                                                '1267650600228229401496703205376n'
		'45977665298704210987n + (714320987142450987412098743217984576n / 4598741987421098765327980n) * 987498743n;': '199365500239020623962n'
		'3n & -2n;':                                                                                                  '2n'
		'-3n & -2n;':                                                                                                 '-4n'
		'0n | -2n;':                                                                                                  '-2n'
		'5n ^ 3n;':                                                                                                   '6n'
		'~-1n;':                                                                                                      '0n'
		'~1n;':                                                                                                       '-2n'
		'5n << 2n;':                                                                                                  '20n'
		'-7n >> 1n;':                                                                                                 '-4n'
		'7n >> -2n;':                                                                                                 '28n'
		'var x=1n; x++;':                                                                                             '1n'
		'var x=1n; ++x;':                                                                                             '2n'
		'var x=2n; x--;':                                                                                             '2n'
		'var x=2n; --x;':                                                                                             '1n'
		'var x=2n; var y=x++ + ++x + x-- + --x; y;':                                                                  '12n'
		'var x=0n; x ||= 42n; x += 1n; x;':                                                                           '43n'
		'var x=6n; x &= 3n; x |= 8n; x ^= 1n; x <<= 2n; x >>= 1n; x;':                                                '22n'
		'!0n && !!(-1n);':                                                                                            'true'
		'"" + 123n;':                                                                                                 '"123"'
		'1n == 1;':                                                                                                   'true'
		'1n === 1;':                                                                                                  'false'
		'1n === 1n;':                                                                                                 'true'
		'1n == 1.23;':                                                                                                'false'
		'16n == " 0X10 ";':                                                                                           'true'
		'16n == "0x1_0";':                                                                                            'false'
		'0n == "0X";':                                                                                                'false'
		'1n < 1.23;':                                                                                                 'true'
		'1n < "1.23";':                                                                                               'false'
		'1n <= "1.23";':                                                                                              'false'
		'"0x" >= 1n;':                                                                                                'false'
		'1n < "0B10";':                                                                                               'true'
		'9007199254740993n > 9007199254740992;':                                                                      'true'
		'9007199254740993n == 9007199254740992;':                                                                     'false'
		'1000000000000000019884624838656n == 1e30;':                                                                  'true'
		'-1000000000000000019884624838657n < -1e30;':                                                                 'true'
		'0n < NumberMissing;':                                                                                        'reference-error'
	} {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		if expected == 'reference-error' {
			if _ := execute_bigint_source(mut vm, source) {
				assert false
			} else {
				assert thrown_value(err).as_object().error_kind()? == .reference_error
			}
			continue
		}
		assert execute_bigint_source(mut vm, source)!.str() == expected, source
		assert vm.execution_context_stack().len == 1
		assert vm.interpreter_stack().depth() == 0
	}
}

fn test_bigint_loops_preserve_numeric_type_and_completion_values() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert execute_bigint_source(mut vm,
		'var result=1n; for(let i=1n;i<=30n;i++) result*=i; result;')!.str() == '265252859812191058636308480000000n'
	assert execute_bigint_source(mut vm, 'result >>= 80n; result;')!.str() == '219412023n'
	assert execute_bigint_source(mut vm, 'var zero=0n; while(zero) result++; result;')!.str() == '219412023n'
}

fn test_compiled_bigint_errors_are_completions_with_tracebacks_and_clean_frames() {
	for source, expected in {
		'1n + 1;':            'Cannot use addition operator with BigInt and other type'
		'1n >>> 0n;':         'Cannot use unsigned right-shift operator with BigInt'
		'+1n;':               'Cannot convert BigInt to number'
		'1n / 0n;':           'Division by zero'
		'1n % 0n;':           'Division by zero'
		'2n ** -1n;':         'Exponent must be positive'
		'2n ** 4294967296n;': 'Maximum BigInt size exceeded'
		'2n << 4294967296n;': 'Maximum BigInt size exceeded'
	} {
		mut vm := VM.create()
		base := create_simple_execution_context(mut vm)
		if _ := execute_bigint_source(mut vm, source) {
			assert false
		} else {
			object := thrown_value(err).as_object()
			assert object.error_message()? == expected, source
			assert object.error_data?.stack_string(false).contains('bigint.js')
		}
		assert vm.running_execution_context() == base
		assert vm.execution_context_stack().len == 1
		assert vm.interpreter_stack().depth() == 0
		assert vm.run_executable_depth() == 0
		assert execute_bigint_source(mut vm, '42n;')!.str() == '42n'
	}
}
