module libjs

fn install_callable_global(mut vm VM, name string, behaviour NativeFunctionPointer) &Object {
	function := NativeFunction.create_raw(mut vm, vm.realm(), none, behaviour, 0,
		PropertyName.from_str(name), none)
	mut global := vm.get_global_object()
	global.define_direct_property(PropertyName.from_str(name), Value.from_object(function.object),
		7)
	return function.object
}

fn call_execution_sum(mut vm VM) !Value {
	mut result := Value.from_i32(0)
	for i in 0 .. vm.argument_count() {
		result = add(mut vm, result, vm.argument(i))!
	}
	return result
}

fn execute_call_source(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'calls.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 10000 })
}

fn test_compiled_native_calls_preserve_callee_argument_order_and_this() {
	for source, expected in {
		'hostSum(20,22);':                                                  '42'
		'hostSum();':                                                       '0'
		'hostSum(20n,22n);':                                                'mixed-number-error'
		'hostSum(hostSum(10,10),22);':                                      '42'
		'(0,hostSum)(20,22);':                                              '42'
		'var x=1; hostSum(x,x=41);':                                        '42'
		'var f=hostSum; f(20,(f=hostThis,22));':                            '42'
		'hostThis();':                                                      'undefined'
		'typeof hostSum;':                                                  '"function"'
		'var total=0; for(let i=0;i<7;i++) total=hostSum(total,i); total;': '21'
	} {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		install_callable_global(mut vm, 'hostSum', call_execution_sum)
		install_callable_global(mut vm, 'hostThis', fn (mut vm VM) !Value {
			return vm.this_value()
		})
		if expected == 'mixed-number-error' {
			if _ := execute_call_source(mut vm, source) {
				assert false
			} else {
				assert thrown_value(err).as_object().error_kind()? == .type_error
			}
		} else {
			assert execute_call_source(mut vm, source)!.str() == expected, source
		}
		assert vm.execution_context_stack().len == 1
		assert vm.interpreter_stack().depth() == 0
	}
}

fn test_call_failures_preserve_argument_side_effects_and_callsite_traceback() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	install_callable_global(mut vm, 'hostThrow', fn (mut vm VM) !Value {
		return vm.throw_error(.type_error, 'Native call failed')
	})
	if _ := execute_call_source(mut vm, 'hostThrow(42);') {
		assert false
	} else {
		object := thrown_value(err).as_object()
		trace := object.error_data?.stack_string(false)
		assert trace.contains('hostThrow') && trace.contains('calls.js')
	}
	if _ := execute_call_source(mut vm, 'var x=0; 7(x=42);') {
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()? == '7 is not a function'
	}
	assert execute_call_source(mut vm, 'x;')!.number == 42
	if _ := execute_call_source(mut vm, 'x=0; missing(x=42);') {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .reference_error
	}
	assert execute_call_source(mut vm, 'x;')!.number == 0
	assert vm.running_execution_context() == base
	assert vm.execution_context_stack().len == 1
	assert vm.interpreter_stack().depth() == 0
	assert vm.run_executable_depth() == 0
}

fn test_calls_validate_variable_argument_operands_and_secondary_destinations() {
	mut executable := &Executable{
		registers_and_locals_count: reserved_register_count + 1
		constants:                  [Value.from_i32(42)]
		identifier_table:           [utf16_string('host')]
		instructions:               [
			Instruction{
				op:  .get_callee_and_this
				dst: Operand.register(reserved_register_count)
				rhs: Operand.constant(0)
			},
			Instruction{
				op:  .end
				lhs: Operand.constant(0)
			},
		]
		bytecode_length:            2
	}
	if _ := executable.validate(0) {
		assert false
	} else {
		assert err.msg().contains('constant')
	}
	executable.instructions[0] = Instruction{
		op:        .call
		dst:       Operand.register(reserved_register_count)
		lhs:       Operand.constant(0)
		rhs:       Operand.constant(0)
		arguments: [Operand.register(999)]
	}
	if _ := executable.validate(0) {
		assert false
	} else {
		assert err.msg().contains('range')
	}
}

fn test_spread_calls_reject_the_program_before_creating_bindings() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	if _ := execute_call_source(mut vm, 'var changed=1; host(...arguments);') {
		assert false
	} else {
		assert !is_throw_completion(err) && err.msg().contains('spread call arguments')
	}
	assert !vm.get_global_object().has_own_property(PropertyName.from_str('changed'))
}
