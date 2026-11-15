// SPDX-License-Identifier: BSD-2-Clause
module libjs

// SuperCall evaluation retains GetSuperConstructor before argument evaluation;
// constructing the parent precedes BindThisValue, including a second super().
fn get_super_constructor(mut vm VM) !Value {
	environment := get_this_environment(vm)
	if environment is FunctionEnvironment {
		if constructor := environment.class_constructor {
			if parent := constructor.object.internal_get_prototype_of() { return Value.from_object(parent) }
			return js_null()
		}
	}
	return vm.throw_error(.reference_error, 'Super call requires a derived constructor')
}

fn construct_super(mut vm VM, constructor Value, arguments []Value) !Value {
	mut environment := get_this_environment(vm)
	if mut environment is FunctionEnvironment {
		if class_constructor := environment.class_constructor {
			if !class_constructor.derived { return vm.throw_error(.reference_error, 'Super call requires a derived constructor') }
			object := construct(mut vm, constructor, arguments, environment.new_target.as_object())!
			environment.bind_this_value(mut vm, Value.from_object(object))!
			return Value.from_object(object)
		}
	}
	return vm.throw_error(.reference_error, 'Super call requires a derived constructor')
}
