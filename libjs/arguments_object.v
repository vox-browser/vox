// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Runtime/ArgumentsObject.cpp and AbstractOperations.cpp. Parameter bindings
// have stable indices in this port's declarative environment. Keep the actual
// environment alive when an arguments object escapes its call frame.
@[heap]
struct ArgumentsObject {
mut:
	environment &FunctionEnvironment
	parameter_map map[u32]int
}

fn (arguments &ArgumentsObject) mapped_binding(key PropertyName) ?int {
	if key.is_number() {
		if index := arguments.parameter_map[key.number] { return index }
	}
	return none
}

fn (arguments &ArgumentsObject) mapped_value(key PropertyName) ?Value {
	index := arguments.mapped_binding(key) or { return none }
	return arguments.environment.bindings[index].value
}

fn (mut arguments ArgumentsObject) define_own_property(mut object Object, key PropertyName, descriptor PropertyDescriptor) bool {
	binding := arguments.mapped_binding(key)
	mut adjusted := descriptor
	if binding != none && descriptor.is_data_descriptor() && descriptor.value == none
		&& descriptor.writable == ?bool(false) {
		adjusted.value = arguments.mapped_value(key)
	}
	if !object.ordinary_define_own_property(key, adjusted) { return false }
	if index := binding {
		if descriptor.is_accessor_descriptor() {
			arguments.parameter_map.delete(key.number)
		} else {
			if value := descriptor.value { arguments.environment.bindings[index].value = value }
			if descriptor.writable == ?bool(false) { arguments.parameter_map.delete(key.number) }
		}
	}
	return true
}

fn create_arguments_object(mut vm VM, function &ECMAScriptFunction, environment &FunctionEnvironment, values []Value) !&Object {
	realm := function.realm_
	mut object := Object.create(realm, realm.object_prototype)
	object.class_name = 'Arguments'
	object.is_arguments_object = true
	object.define_direct_property(PropertyName.from_str('length'), Value.from_i32(values.len),
		attribute_writable | attribute_configurable)
	for index, value in values {
		object.define_direct_property(PropertyName.from_number(u32(index)), value,
			attribute_writable | attribute_enumerable | attribute_configurable)
	}
	// Use the intrinsic, even if user code replaces Array.prototype.values.
	object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_iterator()),
		realm.array_prototype_values, attribute_writable | attribute_configurable)
	if function.data.is_strict_mode {
		thrower := realm.throw_type_error_function or { panic('Missing ThrowTypeError intrinsic') }
		object.define_direct_property(PropertyName.from_str('callee'),
			Value.from_accessor(Accessor.create(thrower, thrower, none)), 0)
	} else {
		mut arguments := &ArgumentsObject{ environment: environment }
		mut seen := map[string]bool{}
		for index := function.data.parameters.len - 1; index >= 0; index-- {
			binding := function.data.parameters[index].binding as IdentifierBinding
			name := binding.identifier.name
			if name.str() in seen { continue }
			seen[name.str()] = true
			if index < values.len {
				arguments.parameter_map[u32(index)] = environment.find_binding_index(name)
			}
		}
		object.arguments_object = arguments
		object.define_direct_property(PropertyName.from_str('callee'), Value.from_object(function.object),
			attribute_writable | attribute_configurable)
	}
	return object
}

fn (function &ECMAScriptFunction) needs_arguments_binding() bool {
	if function.data.is_arrow_function { return false }
	scope := function.data.body.kind.scope or { return false }
	if data := scope.function_scope_data {
		return !data.has_argument_parameter && !data.has_function_named_arguments
			&& !data.has_lexically_declared_arguments
	}
	return true
}
