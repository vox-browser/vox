module libjs

fn execute_boolean_reference(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'boolean-reference.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 10000})
}

fn test_boolean_primitive_properties_use_the_prototype_and_temporary_wrapper() {
	for source, expected in {
		'true.valueOf();': 'true'
		'false.toString();': '"false"'
		'(false)["valueOf"]();': 'false'
		'false.constructor === Boolean;': 'true'
		'true.missing;': 'undefined'
		'true.extra=42; true.extra;': 'undefined'
		'delete true.extra;': 'true'
		'delete false.valueOf; false.valueOf();': 'false'
	} {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		assert execute_boolean_reference(mut vm, source)!.str() == expected, source
	}
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	if _ := execute_boolean_reference(mut vm, '"use strict"; true.extra=42;') {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

@[heap]
struct BooleanReceiverTrace {
mut:
	receivers []Value
	values []Value
}

fn test_boolean_inherited_accessors_preserve_primitive_receivers_and_abrupt_completions() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut trace := &BooleanReceiverTrace{}
	mut prototype := vm.realm().boolean_prototype_record()
	prototype.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('receiver'), fn [mut trace] (mut vm VM) !Value {
		trace.receivers << vm.this_value()
		assert vm.this_value().is_boolean()
		return vm.this_value()
	}, fn [mut trace] (mut vm VM) !Value {
		trace.receivers << vm.this_value()
		trace.values << vm.argument(0)
		return js_undefined()
	}, attribute_configurable, vm.realm().function_prototype)
	assert execute_boolean_reference(mut vm, 'false.receiver;')! == Value.from_bool(false)
	assert execute_boolean_reference(mut vm, '"use strict"; true.receiver=42;')!.number == 42
	assert trace.receivers == [Value.from_bool(false), Value.from_bool(true)]
	assert trace.values == [Value.from_i32(42)]
	assert !prototype.has_own_property(PropertyName.from_str('extra'))
	prototype.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('abrupt'), fn (mut vm VM) !Value {
		assert !vm.this_value().as_bool()
		return throw_completion(Value.from_i32(17))
	}, unsafe { nil }, 0, vm.realm().function_prototype)
	if _ := execute_boolean_reference(mut vm, 'false.abrupt;') {
		assert false
	} else { assert thrown_value(err).number == 17 }
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
