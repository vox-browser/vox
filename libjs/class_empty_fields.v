// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Empty public fields still define fresh writable/enumerable/configurable own
// data properties. Store computed keys once during ClassDefinitionEvaluation;
// initialize instance fields before a base body or just after a derived super.
fn (function &BaseClassFunction) initialize_empty_instance_fields(mut vm VM, mut object Object) ! {
	for key in function.instance_fields {
		vm.consume_execution_budget()!
		object.create_data_property_or_throw(mut vm, key, js_undefined())!
	}
}

fn record_empty_class_field(mut vm VM, target Value, key PropertyName, is_static bool) ! {
	mut function := target.as_function()
	if mut function is BaseClassFunction {
		if is_static { function.static_fields << key } else { function.instance_fields << key }
		return
	}
	return vm.throw_error(.internal_error, 'Field definition requires a class constructor')
}

fn initialize_empty_static_fields(mut vm VM, target Value) ! {
	function := target.as_function()
	if function is BaseClassFunction {
		mut object := function.object
		for key in function.static_fields {
			vm.consume_execution_budget()!
			object.create_data_property_or_throw(mut vm, key, js_undefined())!
		}
		return
	}
	return vm.throw_error(.internal_error, 'Static initialization requires a class constructor')
}
