// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// AbstractMachine/Validator.h: Frame, StackEntry, polymorphic Stack and
// definite-local initialization logs. Instruction dispatch is a separate slice.
module webassembly

pub enum BinaryValidationFrameKind {
	block
	loop
	if_
	else_
	function_
	try_table
}

pub struct BinaryValidationFrame {
pub mut:
	type_                 BinaryDefinedType
	kind                  BinaryValidationFrameKind
	initial_size          int
	unreachable           bool
	local_init_log_height int
}

pub fn (frame BinaryValidationFrame) labels() []BinaryValueType {
	return if frame.kind == .loop {
		frame.type_.parameters.clone()
	} else {
		frame.type_.results.clone()
	}
}

pub struct BinaryStackEntry {
pub:
	concrete_type BinaryValueType
	is_known      bool
}

fn (entry BinaryStackEntry) slot_count() int {
	return if entry.is_known && entry.concrete_type.kind == .v128 { 2 } else { 1 }
}

pub fn (entry BinaryStackEntry) is_of_kind(kind BinaryValueKind) bool {
	return !entry.is_known || entry.concrete_type.kind == kind
}

pub fn (entry BinaryStackEntry) is_numeric() bool {
	return !entry.is_known || (!entry.concrete_type.is_reference() && entry.concrete_type.kind !in [
		.v128,
		.i8,
		.i16,
	])
}

pub fn (entry BinaryStackEntry) is_reference() bool {
	return !entry.is_known || entry.concrete_type.is_reference()
}

// StackEntry's source comparison is distinct from Stack::take's full matching.
fn binary_stack_entry_is_subtype(concrete BinaryValueType, expected BinaryValueType) bool {
	if concrete == expected { return true }
	if expected.kind == .function_reference && concrete.kind == .type_use_reference
		&& (expected.nullable || !concrete.nullable) {
		return true
	}
	if expected.nullable && !concrete.nullable {
		return BinaryValueType{ ...concrete, nullable: true } == expected
	}
	return false
}

pub fn (entry BinaryStackEntry) matches_type(type_ BinaryValueType) bool {
	return !entry.is_known || binary_stack_entry_is_subtype(entry.concrete_type, type_)
}

pub fn (entry BinaryStackEntry) matches_entry(other BinaryStackEntry) bool {
	return !entry.is_known || !other.is_known || binary_stack_entry_is_subtype(entry.concrete_type, other.concrete_type)
}

@[heap]
pub struct BinaryInstructionValidator {
pub mut:
	context           BinaryValidationContext
	frames            []BinaryValidationFrame
	local_initialized []bool
	local_init_log    []u32
}

pub fn (mut validator BinaryInstructionValidator) push_frame(frame BinaryValidationFrame) {
	validator.frames << BinaryValidationFrame{ ...frame, local_init_log_height: validator.local_init_log.len }
}

pub fn (mut validator BinaryInstructionValidator) mark_local_initialized(index u32) {
	if validator.local_initialized[index] { return }
	validator.local_initialized[index] = true
	validator.local_init_log << index
}

pub fn (mut validator BinaryInstructionValidator) roll_back_local_initializations(height int) {
	for validator.local_init_log.len > height {
		validator.local_initialized[validator.local_init_log.pop()] = false
	}
}

@[heap]
pub struct BinaryValidationStack {
	validator &BinaryInstructionValidator
	context   BinaryTypeContext
mut:
	entries        []BinaryStackEntry
	max_known_size int
	slot_count_    int
}

pub fn BinaryValidationStack.create(validator &BinaryInstructionValidator, context BinaryTypeContext) &BinaryValidationStack {
	return &BinaryValidationStack{ validator: validator, context: context }
}

pub fn (stack &BinaryValidationStack) size() int { return stack.entries.len }

fn (stack &BinaryValidationStack) slot_height() int { return stack.slot_count_ }

pub fn (stack &BinaryValidationStack) maximum_known_size() int { return stack.max_known_size }

pub fn (stack &BinaryValidationStack) is_empty() bool { return stack.entries.len == 0 }

pub fn (stack &BinaryValidationStack) last() BinaryStackEntry { return stack.entries.last() }

pub fn (stack &BinaryValidationStack) at(index int) BinaryStackEntry { return stack.entries[index] }

pub fn (stack &BinaryValidationStack) type_context() BinaryTypeContext { return stack.context }

pub fn (mut stack BinaryValidationStack) resize(size int) {
	for stack.entries.len > size {
		entry := stack.entries.pop()
		stack.slot_count_ -= entry.slot_count()
	}
	for stack.entries.len < size {
		stack.entries << BinaryStackEntry{}
		stack.slot_count_++
	}
	if size > stack.max_known_size { stack.max_known_size = size }
}

pub fn (mut stack BinaryValidationStack) take_last() !BinaryStackEntry {
	frame := stack.validator.frames.last()
	if stack.size() == frame.initial_size && frame.unreachable { return BinaryStackEntry{} }
	if stack.size() == frame.initial_size {
		return error('CompileError: invalid stack state, expected <any> but got <nothing>')
	}
	entry := stack.entries.pop()
	stack.slot_count_ -= entry.slot_count()
	return entry
}

pub fn (mut stack BinaryValidationStack) append(entry BinaryStackEntry) {
	stack.entries << entry
	stack.slot_count_ += entry.slot_count()
	if stack.size() > stack.max_known_size { stack.max_known_size = stack.size() }
}

pub fn (mut stack BinaryValidationStack) append_type(type_ BinaryValueType) {
	stack.append(BinaryStackEntry{ concrete_type: type_, is_known: true })
}

pub fn (mut stack BinaryValidationStack) take(type_ BinaryValueType) !BinaryStackEntry {
	entry := stack.take_last()!
	if entry.is_known && !matches_binary_value_type(entry.concrete_type, type_, stack.context) {
		return error('CompileError: invalid stack state')
	}
	return entry
}

pub fn (mut stack BinaryValidationStack) take_kinds(kinds []BinaryValueKind) ! {
	for kind in kinds { stack.take(BinaryValueType{ kind: kind })! }
}

pub fn (mut stack BinaryValidationStack) take_and_put(kinds []BinaryValueKind, kind BinaryValueKind) ! {
	stack.take_kinds(kinds)!
	stack.append_type(BinaryValueType{ kind: kind })
}

pub fn (mut stack BinaryValidationStack) release_vector() []BinaryStackEntry {
	stack.max_known_size = 0
	stack.slot_count_ = 0
	entries := stack.entries
	stack.entries = []BinaryStackEntry{}
	return entries
}
