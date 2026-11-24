// SPDX-License-Identifier: BSD-2-Clause
module libjs

// codegen.rs::generate_object_expression: the prototype setter syntax is
// distinct from an ordinary property named __proto__. Computed keys must be
// converted before evaluating the value, including its observable hooks.
fn (mut generator BytecodeGenerator) object_literal(mut vm VM, properties []ObjectProperty) !Operand {
	dst := generator.temporary()
	// `identifier` reserves storage for the literal's properties (object_create.v).
	generator.emit(Instruction{ op: .new_object, dst: dst, identifier: u32(properties.len) })
	// Constant names defined so far. A spread or computed key may define any
	// name, so later definitions keep the runtime duplicate check after one.
	mut defined_names := []Utf16String{}
	mut dynamic_names := false
	// Index the properties: a `for x in` loop copies each ~650-byte ObjectProperty.
	for property_index in 0 .. properties.len {
		property := unsafe { &properties[property_index] }
		if property.property_type == .proto_setter {
			value := generator.expression(mut vm, &(property.value or { return error('Missing prototype value') }))!
			generator.emit(Instruction{ op: .set_object_literal_prototype, lhs: dst, rhs: value })
			continue
		}
		if property.property_type == .spread {
			dynamic_names = true
			value := generator.expression(mut vm, &property.key)!
			generator.emit(Instruction{op: .copy_data_properties, lhs: dst, rhs: value})
			continue
		}
		constant_name := literal_property_name(property)
		fresh_name := !dynamic_names && if name := constant_name { !defined_names.any(it == name) } else { false }
		if name := constant_name { defined_names << name } else { dynamic_names = true }
		raw_key := if !property.is_computed && property.key.kind.tag == .identifier_expr {
			generator.constant(Value.from_string(vm.create_string(identifier_name(&property.key)!)))
		} else {
			generator.expression(mut vm, &property.key)!
		}
		// ToPropertyKey of an identifier, string or numeric key has no side effect,
		// so define_property converts that constant itself. A computed key is
		// converted before its value is evaluated, as the evaluation order requires.
		mut key := raw_key
		if property.is_computed {
			key = generator.temporary()
			generator.emit(Instruction{ op: .to_property_key, dst: key, lhs: raw_key })
		}
		expression := property.value or { return error('Missing property value') }
		mut value := Operand{}
		if property.is_method {
			value = generator.temporary()
			generator.emit(Instruction{op: .new_class_method, dst: value, lhs: key,
				rhs: generator.constant(Value.from_i32(i32(property.property_type))), identifier: expression.kind.function_id.id})
			// The shared method-definition instruction's flag selects enumerable
			// object-literal descriptors; class methods leave it false.
			generator.emit(Instruction{op: .define_class_method, lhs: dst, rhs: key, src: value,
				identifier: u32(property.property_type), strict: true})
			continue
		} else if expression.kind.tag == .function_expr && generator.executable.parsed_source.function_table.get(expression.kind.function_id).name == none {
			value = generator.temporary()
			generator.emit(Instruction{ op: .new_function_with_name, dst: value, identifier: expression.kind.function_id.id, lhs: key })
		} else {
			value = generator.expression(mut vm, &expression)!
		}
		// annex_b marks a name that no earlier definition in this literal can have
		// created, so the fresh ordinary object needs no duplicate lookup.
		generator.emit(Instruction{ op: .define_property, lhs: dst, rhs: key, src: value, annex_b: fresh_name })
	}
	return dst
}

// The property name of an identifier or string key that cannot be an array
// index; numeric spellings keep the runtime check.
fn literal_property_name(property &ObjectProperty) ?Utf16String {
	if property.is_computed { return none }
	name := if property.key.kind.tag == .identifier_expr {
		identifier_name(&property.key) or { return none }
	} else if property.key.kind.tag == .string_literal {
		property.key.kind.string_value
	} else {
		return none
	}
	if name.data.len > 0 && name.data.all(it >= `0` && it <= `9`) { return none }
	return name
}
