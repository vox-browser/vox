// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Rust bytecode/codegen.rs::generate_object_binding_pattern. Binding names are
// created before evaluating the initializer; each property/default then runs in
// order and initializes its own binding. Array/assignment/parameter patterns
// remain separate code-generation paths.
fn (mut generator BytecodeGenerator) initialize_declaration_target(mut vm VM, target VariableDeclaratorTarget, value Operand, lexical bool) ! {
	if target is IdentifierVarTarget {
		generator.store_declared_binding(target.identifier.name, value, lexical)
		return
	}
	if target is BindingPatternVarTarget {
		generator.object_binding_pattern(mut vm, target.pattern, value, lexical)!
	}
}

fn (mut generator BytecodeGenerator) store_declared_binding(name Utf16String, value Operand, lexical bool) {
	generator.emit(Instruction{ op: if lexical {
		OpCode.initialize_binding
	} else {
		OpCode.set_variable
	}, lhs: value, identifier: generator.identifier(name), strict: generator.strict })
}

fn (mut generator BytecodeGenerator) binding_entry_name(entry BindingEntry) ?Utf16String {
	if identifier := entry.alias.identifier { return identifier.name }
	if entry.alias.kind == .none_kind {
		if identifier := entry.name.identifier { return identifier.name }
	}
	return none
}

fn (mut generator BytecodeGenerator) initialize_binding_entry(mut vm VM, entry BindingEntry, value Operand, lexical bool) ! {
	if pattern := entry.alias.binding_pattern {
		generator.object_binding_pattern(mut vm, pattern, value, lexical)!
		return
	}
	if name := generator.binding_entry_name(entry) {
		generator.store_declared_binding(name, value, lexical)
		return
	}
	return generator.unsupported('binding pattern target')
}

fn (mut generator BytecodeGenerator) object_binding_pattern(mut vm VM, pattern BindingPattern, value Operand, lexical bool) ! {
	generator.check_compile_stack()!
	if pattern.kind != .object { return generator.unsupported('array destructuring declaration') }
	generator.emit(Instruction{ op: .require_object_coercible, lhs: value })
	mut excluded := []Operand{}
	for entry in pattern.entries {
		if entry.is_rest {
			rest := generator.temporary()
			generator.emit(Instruction{ op: .copy_object_excluding_keys, dst: rest, lhs: value, arguments: excluded.clone() })
			generator.initialize_binding_entry(mut vm, entry, rest, lexical)!
			continue
		}
		key_value := if identifier := entry.name.identifier {
			generator.constant(Value.from_string(vm.create_string(identifier.name)))
		} else if expression := entry.name.expression {
			generator.expression(mut vm, &expression)!
		} else {
			return error('Missing object binding property name')
		}
		key := generator.temporary()
		generator.emit(Instruction{ op: .to_property_key, dst: key, lhs: key_value })
		excluded << key
		property := generator.temporary()
		generator.emit(Instruction{ op: .get_property, dst: property, lhs: value, rhs: key, strict: generator.strict })
		if initializer := entry.initializer {
			missing := generator.temporary()
			generator.emit(Instruction{ op: .strict_equals, dst: missing, lhs: property, rhs: generator.constant(js_undefined()) })
			skip := generator.emit(Instruction{ op: .jump_if_false, lhs: missing })
			mut initial := Operand{}
			if initializer.kind.tag == .function_expr && generator.executable.parsed_source.function_table.get(initializer.kind.function_id).name == none && generator.binding_entry_name(entry) != none {
				name := generator.binding_entry_name(entry) or { return error('Missing default binding name') }
				initial = generator.temporary()
				generator.emit(Instruction{ op: .new_function_with_name, dst: initial, identifier: initializer.kind.function_id.id, lhs: generator.constant(Value.from_string(vm.create_string(name))) })
			} else {
				initial = generator.expression(mut vm, &initializer)!
			}
			generator.emit(Instruction{ op: .mov, dst: property, lhs: initial })
			generator.patch(skip)
		}
		generator.initialize_binding_entry(mut vm, entry, property, lexical)!
	}
}

// Object.cpp::CopyDataProperties, used by object rest. Excluded names have
// already been converted to property keys before the property's GetV. Capture
// own keys once, but recheck each descriptor and invoke getters in that order.
fn copy_object_excluding_keys(mut vm VM, source Value, excluded []PropertyName) !&Object {
	mut target := Object.create(vm.realm(), vm.realm().object_prototype)
	object := source.to_object_with_prototypes(mut vm, realm_primitive_prototypes())!
	for key in object.own_property_keys() {
		vm.consume_execution_budget()!
		if excluded.any(it.equals(key)) { continue }
		descriptor := object.internal_get_own_property(key) or { continue }
		if !(descriptor.enumerable or { false }) { continue }
		value := object.get(mut vm, key)!
		target.create_data_property_or_throw(mut vm, key, value)!
	}
	return target
}
