// SPDX-License-Identifier: BSD-2-Clause
module libjs

// DefineField / InitializeInstanceElements. Computed keys and initializer
// closures are retained once; values are evaluated for each new receiver.
struct ClassFieldDefinition {
	key PropertyName
	initializer Value
	private_name ?PrivateName
}

fn create_class_field_initializer(mut vm VM, source &Executable, index u32, key PropertyName) !&Object {
	object := create_ecmascript_function_data(mut vm, source, source.class_field_initializers[index], false, make_function_name(key, none), false)!
	mut function := Value.from_object(object).as_function()
	if mut function is ECMAScriptFunction { function.field_initializer_name = key }
	return object
}

fn (field ClassFieldDefinition) define(mut vm VM, mut object Object) ! {
	vm.consume_execution_budget()!
	value := if field.initializer.is_undefined() { js_undefined() }
		else { call(mut vm, field.initializer, Value.from_object(&object), [])! }
	if name := field.private_name { object.private_field_add(mut vm, name, value)! }
	else { object.create_data_property_or_throw(mut vm, field.key, value)! }
}

fn (function &BaseClassFunction) initialize_empty_instance_fields(mut vm VM, mut object Object) ! {
	initialize_class_private_methods(mut vm, mut object, function.instance_private_methods)!
	for field in function.instance_fields {
		field.define(mut vm, mut object)!
	}
}

fn record_class_field(mut vm VM, target Value, key PropertyName, initializer Value, is_static bool, is_private bool) ! {
	mut function := target.as_function()
	if mut function is BaseClassFunction {
		field := ClassFieldDefinition{key: key, initializer: initializer, private_name: if is_private { ?PrivateName(resolve_class_private_name(mut vm, key.to_value(mut vm))!) } else { none }}
		if is_static { function.static_fields << field } else { function.instance_fields << field }
		return
	}
	return vm.throw_error(.internal_error, 'Field definition requires a class constructor')
}

fn initialize_empty_static_fields(mut vm VM, target Value) ! {
	function := target.as_function()
	if function is BaseClassFunction {
		mut object := function.object
		initialize_class_private_methods(mut vm, mut object, function.static_private_methods)!
		for field in function.static_fields {
			field.define(mut vm, mut object)!
		}
		return
	}
	return vm.throw_error(.internal_error, 'Static initialization requires a class constructor')
}
