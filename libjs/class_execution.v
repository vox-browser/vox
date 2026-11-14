// SPDX-License-Identifier: BSD-2-Clause
module libjs

// ClassDefinitionEvaluation / Rust bytecode codegen.rs: base classes with
// ordinary, static and accessor methods. Heritage, fields, private names,
// static blocks and super references remain explicit unsupported boundaries.
fn (mut generator BytecodeGenerator) class_expression(mut vm VM, data &ClassData) !Operand {
	if data.super_class != none { return generator.unsupported('class heritage') }
	previous_strict := generator.strict
	generator.strict = true
	defer { generator.strict = previous_strict }
	for element in data.elements {
		method := element.kind
		if method !is ClassElementMethod { return generator.unsupported('class fields or static initialization') }
		if method.key.kind.tag == .private_identifier_expr { return generator.unsupported('private class methods') }
	}
	generator.emit(Instruction{ op: .enter_scope })
	generator.scope_depth++
	name := if identifier := data.name { identifier.name } else { Utf16String.new() }
	if data.name != none { generator.emit(Instruction{ op: .create_immutable_binding, identifier: generator.identifier(name) }) }
	body := if expression := data.constructor { generator.expression(mut vm, &expression)! } else { generator.constant(js_undefined()) }
	result := generator.temporary()
	source_index := u32(generator.executable.class_source_spans.len)
	generator.executable.class_source_spans << ClassSourceSpan{ start: data.source_text_start, end: data.source_text_end }
	generator.emit(Instruction{ op: .new_class, dst: result, lhs: body, rhs: generator.constant(Value.from_string(vm.create_string(name))), identifier: source_index })
	prototype := generator.temporary()
	generator.emit(Instruction{ op: .get_property, dst: prototype, lhs: result, rhs: generator.constant(Value.from_string(vm.create_string_from_str('prototype'))) })
	for element in data.elements {
		method := element.kind as ClassElementMethod
		previous_range := generator.range
		generator.range = element.range
		raw_key := generator.expression(mut vm, &method.key)!
		key := generator.temporary()
		generator.emit(Instruction{ op: .to_property_key, dst: key, lhs: raw_key })
		function := generator.temporary()
		generator.emit(Instruction{ op: .new_class_method, dst: function, lhs: key, rhs: generator.constant(Value.from_i32(i32(method.method_kind))), identifier: method.function.kind.function_id.id })
		generator.emit(Instruction{ op: .define_class_method, lhs: if method.is_static { result } else { prototype }, rhs: key, src: function, identifier: u32(method.method_kind) })
		generator.range = previous_range
	}
	if data.name != none { generator.emit(Instruction{ op: .initialize_binding, lhs: result, identifier: generator.identifier(name), strict: true }) }
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
}

fn (function &BaseClassFunction) realm() ?&Realm { return function.realm_ }
fn (function &BaseClassFunction) name_for_call_stack() Utf16String { return function.name }

fn (mut function BaseClassFunction) internal_call(mut vm VM, this_value Value, arguments []Value) !Value {
	return vm.throw_error(.type_error, 'Class constructor cannot be invoked without new')
}

fn (mut function BaseClassFunction) internal_construct(mut vm VM, arguments []Value, new_target &Object) !&Object {
	prototype := get_prototype_from_constructor(mut vm, new_target, fn (realm &Realm) &Object { return realm.object_prototype_record() })!
	object := Object.create(function.realm_, prototype)
	if function.body.is_undefined() { return object }
	returned := call(mut vm, function.body, Value.from_object(object), arguments)!
	return if returned.is_object() { returned.as_object() } else { object }
}

fn create_base_class(mut vm VM, executable &Executable, index u32, body Value, name Value) !Value {
	mut object := Object.create(vm.realm(), vm.realm().function_prototype)
	object.class_name = 'Function'
	function := &BaseClassFunction{ object: object, realm_: vm.realm(), body: body, name: name.as_string().utf16 }
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
	mut prototype := Object.create(vm.realm(), vm.realm().object_prototype)
	prototype.define_direct_property(PropertyName.from_str('constructor'), Value.from_object(object), attribute_writable | attribute_configurable)
	object.define_direct_property(PropertyName.from_str('prototype'), Value.from_object(prototype), 0)
	return Value.from_object(object)
}

fn define_class_method(mut vm VM, target Value, name Value, function_value Value, kind u32) ! {
	mut target_object := target.as_object()
	key := name.to_property_key(mut vm)!
	if kind == 0 {
		target_object.define_property_or_throw(mut vm, key, PropertyDescriptor{ value: function_value, writable: true, enumerable: false, configurable: true })!
	} else if kind == 1 {
		target_object.define_property_or_throw(mut vm, key, PropertyDescriptor{ getter: function_value, enumerable: false, configurable: true })!
	} else {
		target_object.define_property_or_throw(mut vm, key, PropertyDescriptor{ setter: function_value, enumerable: false, configurable: true })!
	}
}
