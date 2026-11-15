// SPDX-License-Identifier: BSD-2-Clause
module libjs

// ClassDefinitionEvaluation / Rust bytecode codegen.rs: base classes with
// ordinary, static and accessor methods and empty public fields. Field
// initializers/private elements, static blocks and super property references
// remain explicit unsupported boundaries.
fn (mut generator BytecodeGenerator) class_expression(mut vm VM, data &ClassData) !Operand {
	previous_strict := generator.strict
	generator.strict = true
	defer { generator.strict = previous_strict }
	for element in data.elements {
		match element.kind {
			ClassElementMethod { if element.kind.key.kind.tag == .private_identifier_expr { return generator.unsupported('private class methods') } }
			ClassElementField {
				if element.kind.key.kind.tag == .private_identifier_expr { return generator.unsupported('private class fields') }
				if element.kind.initializer != none { return generator.unsupported('class field initializers') }
			}
			ClassElementStaticInit { return generator.unsupported('class static initialization') }
		}
	}
	generator.emit(Instruction{ op: .enter_scope })
	generator.scope_depth++
	name := if identifier := data.name { identifier.name } else { Utf16String.new() }
	if data.name != none { generator.emit(Instruction{ op: .create_immutable_binding, identifier: generator.identifier(name) }) }
	parent := if expression := data.super_class { generator.expression(mut vm, &expression)! } else { generator.constant(js_undefined()) }
	body := if expression := data.constructor { generator.expression(mut vm, &expression)! } else { generator.constant(js_undefined()) }
	result := generator.temporary()
	source_index := u32(generator.executable.class_source_spans.len)
	generator.executable.class_source_spans << ClassSourceSpan{ start: data.source_text_start, end: data.source_text_end }
	generator.emit(Instruction{ op: .new_class, dst: result, lhs: body, rhs: generator.constant(Value.from_string(vm.create_string(name))), src: parent, strict: data.super_class != none, identifier: source_index })
	prototype := generator.temporary()
	generator.emit(Instruction{ op: .get_property, dst: prototype, lhs: result, rhs: generator.constant(Value.from_string(vm.create_string_from_str('prototype'))) })
	for element in data.elements {
		previous_range := generator.range
		generator.range = element.range
		if element.kind is ClassElementField {
			raw_key := generator.expression(mut vm, &element.kind.key)!
			key := generator.temporary()
			generator.emit(Instruction{op: .to_property_key, dst: key, lhs: raw_key})
			generator.emit(Instruction{op: .record_empty_class_field, lhs: result, rhs: key, identifier: if element.kind.is_static { u32(1) } else { 0 }})
			generator.range = previous_range
			continue
		}
		method := element.kind as ClassElementMethod
		raw_key := generator.expression(mut vm, &method.key)!
		key := generator.temporary()
		generator.emit(Instruction{ op: .to_property_key, dst: key, lhs: raw_key })
		function := generator.temporary()
		generator.emit(Instruction{ op: .new_class_method, dst: function, lhs: key, rhs: generator.constant(Value.from_i32(i32(method.method_kind))), identifier: method.function.kind.function_id.id })
		generator.emit(Instruction{ op: .define_class_method, lhs: if method.is_static { result } else { prototype }, rhs: key, src: function, identifier: u32(method.method_kind) })
		generator.range = previous_range
	}
	if data.name != none { generator.emit(Instruction{ op: .initialize_binding, lhs: result, identifier: generator.identifier(name), strict: true }) }
	generator.emit(Instruction{op: .initialize_empty_static_fields, lhs: result})
	generator.scope_depth--
	generator.emit(Instruction{ op: .leave_scope })
	return result
}

@[heap]
struct BaseClassFunction {
	object &Object
	realm_ &Realm
	body Value
	name Utf16String
	derived bool
mut:
	instance_fields []PropertyName
	static_fields []PropertyName
}

fn (function &BaseClassFunction) realm() ?&Realm { return function.realm_ }
fn (function &BaseClassFunction) name_for_call_stack() Utf16String { return function.name }

fn (mut function BaseClassFunction) internal_call(mut vm VM, this_value Value, arguments []Value) !Value {
	return vm.throw_error(.type_error, 'Class constructor cannot be invoked without new')
}

fn (mut function BaseClassFunction) internal_construct(mut vm VM, arguments []Value, new_target &Object) !&Object {
	if function.derived {
		if function.body.is_undefined() {
			parent := function.object.internal_get_prototype_of() or { return vm.throw_error(.type_error, 'Superclass is not a constructor') }
			mut object := construct(mut vm, Value.from_object(parent), arguments, new_target)!
			function.initialize_empty_instance_fields(mut vm, mut object)!
			return object
		}
		mut body := function.body.as_function()
		if mut body is ECMAScriptFunction {
			return body.call_with_new_target(mut vm, js_undefined(), arguments, Value.from_object(new_target), &function)!.as_object()
		}
		return error('Invalid class constructor body')
	}
	prototype := get_prototype_from_constructor(mut vm, new_target, fn (realm &Realm) &Object { return realm.object_prototype_record() })!
	mut object := Object.create(function.realm_, prototype)
	function.initialize_empty_instance_fields(mut vm, mut object)!
	if function.body.is_undefined() { return object }
	mut body := function.body.as_function()
	if mut body is ECMAScriptFunction {
		returned := body.call_with_new_target(mut vm, Value.from_object(object), arguments, Value.from_object(new_target), &function)!
		return if returned.is_object() { returned.as_object() } else { object }
	}
	return error('Invalid class constructor body')
}

fn create_base_class(mut vm VM, executable &Executable, index u32, body Value, name Value, parent Value, derived bool) !Value {
	mut constructor_parent := vm.realm().function_prototype
	mut prototype_parent := vm.realm().object_prototype
	if derived {
		if parent.is_null() { prototype_parent = none }
		else {
			if !parent.is_constructor() { return vm.throw_error(.type_error, 'Superclass is not a constructor or null') }
			constructor_parent = parent.as_object()
			prototype := parent.as_object().get(mut vm, PropertyName.from_str('prototype'))!
			if !prototype.is_object() && !prototype.is_null() { return vm.throw_error(.type_error, 'Superclass prototype must be an object or null') }
			prototype_parent = if prototype.is_object() { ?&Object(prototype.as_object()) } else { none }
		}
	}
	mut object := Object.create(vm.realm(), constructor_parent)
	object.class_name = 'Function'
	function := &BaseClassFunction{ object: object, realm_: vm.realm(), body: body, name: name.as_string().utf16, derived: derived }
	object.callable = FunctionObject(function)
	object.constructor = ConstructorFunction(function)
	length := if body.is_function() { body.as_object().get(mut vm, PropertyName.from_str('length'))!.number } else { 0.0 }
	object.set_function_length(length)
	object.set_function_name(mut vm, PropertyName.from_utf16(function.name), none)
	span := executable.class_source_spans[index]
	code := executable.source_code or { return error('Class executable has no source') }
	units := code.code.as_slice()
	if span.start > span.end || span.end > u32(units.len) { return error('Class source range is out of bounds') }
	object.function_source_text = utf16_string_from_code_units(units[int(span.start)..int(span.end)])
	mut prototype := Object.create(vm.realm(), prototype_parent)
	prototype.define_direct_property(PropertyName.from_str('constructor'), Value.from_object(object), attribute_writable | attribute_configurable)
	object.define_direct_property(PropertyName.from_str('prototype'), Value.from_object(prototype), 0)
	return Value.from_object(object)
}

fn define_class_method(mut vm VM, target Value, name Value, function_value Value, kind u32, enumerable bool) ! {
	mut target_object := target.as_object()
	key := name.to_property_key(mut vm)!
	if kind == 0 {
		target_object.define_property_or_throw(mut vm, key, PropertyDescriptor{ value: function_value, writable: true, enumerable: enumerable, configurable: true })!
	} else if kind == 1 {
		target_object.define_property_or_throw(mut vm, key, PropertyDescriptor{ getter: function_value, enumerable: enumerable, configurable: true })!
	} else {
		target_object.define_property_or_throw(mut vm, key, PropertyDescriptor{ setter: function_value, enumerable: enumerable, configurable: true })!
	}
}
