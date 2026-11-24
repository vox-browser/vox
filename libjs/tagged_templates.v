// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Realm's TemplateMap retains the actual parsed site, independently of function
// instance/executable identity. Equal text in separately parsed scripts is a
// different site; frontend reuse in another realm still gets fresh arrays.
@[heap]
struct TemplateObjectEntry {
	source &ParsedSource
	object &Object
}

// Rust/src/bytecode/codegen.rs::generate_tagged_template_literal.
fn (mut generator BytecodeGenerator) tagged_template(mut vm VM, expression &Expression) !Operand {
	tag := expression.kind.tag_expr() or { return error('Missing template tag') }
	literal := expression.kind.template_literal_expr() or { return error('Missing tagged template literal') }
	data := literal.kind.template_data() or { return error('Missing tagged template data') }
	callee, receiver := generator.call_reference(mut vm, tag)!
	mut strings := []Operand{}
	for index := 0; index < data.expressions.len; index += 2 {
		part := data.expressions[index]
		value := if part.kind.tag == .null_literal { js_undefined() } else { Value.from_string(vm.create_string(part.kind.literal_string())) }
		strings << generator.constant(value)
	}
	for raw in data.raw_strings { strings << generator.constant(Value.from_string(vm.create_string(raw))) }
	object := generator.temporary()
	generator.emit(Instruction{op: .get_template_object, dst: object, target: literal.range.start.offset, arguments: strings})
	mut arguments := [object]
	for index := 1; index < data.expressions.len; index += 2 {
		arguments << generator.expression(mut vm, &data.expressions[index])!
	}
	dst := generator.temporary()
	generator.emit(Instruction{op: .call, dst: dst, lhs: callee, rhs: receiver, arguments: arguments})
	return dst
}

// Interpreter's GetTemplateObject: intrinsic array creation and freezing cannot
// invoke author constructors, Array.from, Object.freeze or inherited setters.
fn (mut vm VM) get_template_object(executable &Executable, instruction Instruction) !Value {
	source := executable.parsed_source
	if source == unsafe { nil } { return vm.throw_error(.internal_error, 'Template object requires its parsed source') }
	mut realm := vm.realm()
	key := '${uint(voidptr(source))}:${instruction.target}'
	if entry := realm.template_objects[key] { return Value.from_object(entry.object) }
	if instruction.arguments.len % 2 != 0 { return vm.throw_error(.internal_error, 'Unpaired template strings') }
	count := instruction.arguments.len / 2
	frame := vm.current_context()
	mut cooked := []Value{cap: count}
	mut raw := []Value{cap: count}
	for index, operand in instruction.arguments {
		vm.consume_execution_budget()!
		value := frame.values[operand.slot(executable, frame.argument_count, false)!]
		if index < count { cooked << value } else { raw << value }
	}
	mut raw_array := ArrayObject.create_from(mut vm, realm, raw, realm.array_prototype_record())!.object
	mut object := ArrayObject.create_from(mut vm, realm, cooked, realm.array_prototype_record())!.object
	if !raw_array.set_integrity_level(mut vm, .frozen)! { return vm.throw_error(.internal_error, 'Cannot freeze template raw strings') }
	object.define_direct_property(PropertyName.from_str('raw'), Value.from_object(raw_array), 0)
	if !object.set_integrity_level(mut vm, .frozen)! { return vm.throw_error(.internal_error, 'Cannot freeze template strings') }
	realm.template_objects[key] = &TemplateObjectEntry{source: source, object: object}
	return Value.from_object(object)
}
