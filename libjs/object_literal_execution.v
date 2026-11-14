// SPDX-License-Identifier: BSD-2-Clause
module libjs

// codegen.rs::generate_object_expression: the prototype setter syntax is
// distinct from an ordinary property named __proto__. Computed keys must be
// converted before evaluating the value, including its observable hooks.
fn (mut generator BytecodeGenerator) object_literal(mut vm VM, properties []ObjectProperty) !Operand {
	dst := generator.temporary()
	generator.emit(Instruction{ op: .new_object, dst: dst })
	for property in properties {
		if property.property_type == .proto_setter {
			value := generator.expression(mut vm, &(property.value or { return error('Missing prototype value') }))!
			generator.emit(Instruction{ op: .set_object_literal_prototype, lhs: dst, rhs: value })
			continue
		}
		if property.property_type != .key_value {
			return generator.unsupported('object accessor or spread')
		}
		raw_key := if !property.is_computed && property.key.kind.tag == .identifier_expr {
			generator.constant(Value.from_string(vm.create_string(identifier_name(&property.key)!)))
		} else {
			generator.expression(mut vm, &property.key)!
		}
		key := generator.temporary()
		generator.emit(Instruction{ op: .to_property_key, dst: key, lhs: raw_key })
		expression := property.value or { return error('Missing property value') }
		mut value := Operand{}
		if !property.is_method && expression.kind.tag == .function_expr && generator.executable.parsed_source.function_table.get(expression.kind.function_id).name == none {
			value = generator.temporary()
			generator.emit(Instruction{ op: .new_function_with_name, dst: value, identifier: expression.kind.function_id.id, lhs: key })
		} else {
			value = generator.expression(mut vm, &expression)!
		}
		generator.emit(Instruction{ op: .define_property, lhs: dst, rhs: key, src: value })
	}
	return dst
}
