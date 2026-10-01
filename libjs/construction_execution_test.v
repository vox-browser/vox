module libjs

fn execute_construction_source(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'construction.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 10000 })
}

fn test_compiled_boolean_calls_construction_binding_and_instance_checks() {
	for source, expected in {
		'Boolean();': 'false'
		'Boolean("false");': 'true'
		'new Boolean().valueOf();': 'false'
		'(new Boolean).valueOf();': 'false'
		'new globalThis.Boolean(false).toString();': '"false"'
		'new globalThis["Boolean"](42).valueOf();': 'true'
		'new Boolean(false) instanceof Boolean;': 'true'
		'Boolean.prototype instanceof Boolean;': 'false'
		'new Boolean(new Boolean(false)).valueOf();': 'true'
		'new (Boolean.bind(null, false))(true).valueOf();': 'false'
		'new (Boolean.bind(null, true).bind(null, false))().valueOf();': 'true'
		'var B=Boolean.bind(null); new B(42) instanceof B;': 'true'
		'Boolean.prototype.constructor === Boolean;': 'true'
		'Boolean.toString();': '"function Boolean() { [native code] }"'
	} {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		assert execute_construction_source(mut vm, source)!.str() == expected, source
		assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
	}
}

fn test_compiled_new_preserves_callee_and_argument_values_before_later_mutations() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	function := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype,
		boolean_constructor_call, fn (mut vm VM, new_target &Object) !&Object {
			assert vm.argument_count() == 3
			assert vm.argument(0).number == 1 && vm.argument(1).number == 41 && vm.argument(2).is_null()
			mut result := Object.create(vm.realm(), none)
			result.define_direct_property(PropertyName.from_str('answer'),
				add(mut vm, vm.argument(0), vm.argument(1))!, 7)
			result.define_direct_property(PropertyName.from_str('newTarget'), Value.from_object(new_target), 7)
			return result
		}, 3, PropertyName.from_str('Build'))
	mut global := vm.get_global_object()
	global.define_direct_property(PropertyName.from_str('Build'), Value.from_object(function.object), 7)
	assert execute_construction_source(mut vm,
		'var C=Build; var i=1; var result=new C(i,i=41,C=null); result.answer;')!.number == 42
	assert execute_construction_source(mut vm, 'result.newTarget === Build;')!.as_bool()
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_compiled_new_evaluates_arguments_before_constructor_validation_and_propagates_abrupt_gets() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	for source in ['new parseInt(globalThis.changed=42);', 'new 42(globalThis.changed=42);',
		'new (Boolean.bind(null).call)(globalThis.changed=42);'] {
		if _ := execute_construction_source(mut vm, source) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
		assert vm.get_global_object().get(mut vm, PropertyName.from_str('changed'))!.number == 42
	}
	mut global := vm.get_global_object()
	global.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('Bad'), fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(17))
	}, unsafe { nil }, 0, vm.realm().function_prototype)
	global.define_direct_property(PropertyName.from_str('changed'), Value.from_i32(0), 7)
	if _ := execute_construction_source(mut vm, 'new Bad(globalThis.changed=42);') {
		assert false
	} else {
		assert thrown_value(err).number == 17
	}
	assert global.get(mut vm, PropertyName.from_str('changed'))!.number == 0
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	assert execute_construction_source(mut vm, 'new Boolean(true).valueOf();')!.as_bool()
}

fn test_construct_instructions_validate_argument_operands_and_spread_programs_fail_before_execution() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse('new Boolean(42);', vm.realm(), 'construct-operands.js', unsafe { nil })!
	mut executable := script.compile(mut vm)!
	mut found := false
	for mut instruction in executable.instructions {
		if instruction.op == .construct {
			found = true
			instruction.arguments[0] = Operand.register(executable.registers_and_locals_count)
		}
	}
	assert found
	if _ := executable.validate(0) { assert false } else { assert err.msg().len > 0 }
	if _ := execute_construction_source(mut vm, 'globalThis.changed=42; new Boolean(...missing);') {
		assert false
	} else {
		assert !is_throw_completion(err) && err.msg().contains('spread call arguments')
	}
	assert !vm.get_global_object().has_own_property(PropertyName.from_str('changed'))
}
