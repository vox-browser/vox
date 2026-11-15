// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Rust generate_yield_from's synchronous path. The compiler keeps the received
// completion and iterator across yields. The host step implements observable
// next/throw/return calls; yielded iterator results retain their own identity.
fn (mut generator BytecodeGenerator) yield_from_expression(mut vm VM, iterable Operand) !Operand {
	iterator := generator.temporary()
	generator.emit(Instruction{op: .get_sync_iterator, dst: iterator, lhs: iterable})
	received := generator.temporary()
	kind := generator.temporary()
	generator.emit(Instruction{op: .mov, dst: received, lhs: generator.constant(js_undefined())})
	generator.emit(Instruction{op: .mov, dst: kind, lhs: generator.constant(Value.from_i32(i32(GeneratorResumeKind.normal)))})
	start := u32(generator.executable.instructions.len)
	packet := generator.temporary()
	generator.emit(Instruction{op: .generator_delegate_step, dst: packet, lhs: iterator, rhs: received, src: kind})
	done := generator.temporary()
	generator.emit(Instruction{op: .get_property, dst: done, lhs: packet, rhs: generator.constant(Value.from_string(vm.create_string_from_str('done')))})
	finished := generator.emit(Instruction{op: .jump_if_true, lhs: done})
	inner_result := generator.temporary()
	generator.emit(Instruction{op: .get_property, dst: inner_result, lhs: packet, rhs: generator.constant(Value.from_string(vm.create_string_from_str('value')))})
	generator.emit(Instruction{op: .yield_iterator_result, lhs: inner_result})
	generator.emit(Instruction{op: .get_generator_resume_value, dst: received})
	generator.emit(Instruction{op: .get_generator_resume_kind, dst: kind})
	generator.emit(Instruction{op: .jump, target: start})
	generator.patch(finished)
	generator.emit(Instruction{op: .get_property, dst: received, lhs: packet, rhs: generator.constant(Value.from_string(vm.create_string_from_str('value')))})
	returning := generator.temporary()
	generator.emit(Instruction{op: .get_property, dst: returning, lhs: packet, rhs: generator.constant(Value.from_string(vm.create_string_from_str('return')))})
	normal := generator.emit(Instruction{op: .jump_if_false, lhs: returning})
	generator.emit_return(received)
	generator.patch(normal)
	return received
}

fn generator_delegate_packet(mut vm VM, value Value, done bool, returning bool) Value {
	mut packet := Object.create(vm.realm(), none)
	packet.class_name = '#GeneratorDelegateResult'
	packet.define_direct_property(PropertyName.from_str('value'), value, 0)
	packet.define_direct_property(PropertyName.from_str('done'), Value.from_bool(done), 0)
	packet.define_direct_property(PropertyName.from_str('return'), Value.from_bool(returning), 0)
	return Value.from_object(packet)
}

fn generator_delegate_step(mut vm VM, wrapper Value, received Value, kind_value Value) !Value {
	if !wrapper.is_object() { return vm.throw_error(.internal_error, 'Invalid delegated iterator record') }
	mut iterator := wrapper.as_object().iterator_record or { return vm.throw_error(.internal_error, 'Missing delegated iterator record') }
	if !kind_value.is_number() || kind_value.number !in [f64(0), 1, 2] { return vm.throw_error(.internal_error, 'Invalid generator resume completion') }
	kind := GeneratorResumeKind(int(kind_value.number))
	mut result := js_undefined()
	if kind == .normal {
		result = call(mut vm, iterator.next_method, Value.from_object(iterator.iterator), [received])!
	} else {
		method := iterator.iterator.get_method(mut vm, PropertyName.from_str(if kind == .throw_ { 'throw' } else { 'return' }))!
		if method.is_undefined() {
			if kind == .return_ {
				iterator.done = true
				return generator_delegate_packet(mut vm, received, true, true)
			}
			iterator_close(mut vm, iterator, normal_completion(js_undefined())).release_error()!
			return vm.throw_error(.type_error, 'Delegated iterator does not have a throw method')
		}
		result = call(mut vm, method, Value.from_object(iterator.iterator), [received])!
	}
	if !result.is_object() { return vm.throw_error_type(.type_error, .iterable_next_bad_return) }
	if !iterator_complete(mut vm, result.as_object())! {
		return generator_delegate_packet(mut vm, result, false, false)
	}
	iterator.done = true
	value := iterator_value(mut vm, result.as_object())!
	return generator_delegate_packet(mut vm, value, true, kind == .return_)
}
