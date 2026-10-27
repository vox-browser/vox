// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// Configuration.h: ownership, operand routing and accessors;
// Configuration.cpp::reset_after_invoke. Frame installation/execution follows
// separately after the actual compiled-function-table and call owners.
module webassembly

pub enum BinarySourceAddressMix {
	all_registers
	all_call_records
	all_stack
	any
}

pub struct BinaryMachineActiveConfigurations {
pub mut:
	entries map[voidptr]bool
}

@[heap]
pub struct BinaryMachineConfiguration {
pub mut:
	regs [8]BinaryMachineValue
mut:
	store_                          &BinaryMachineStore
	value_stack_                    BinaryMachineValueStack
	call_record_stack_              BinaryMachineValueStack
	label_stack_                    []BinaryMachineLabel
	frame_stack_                    []BinaryMachineFrame
	owned_locals_stack_             []BinaryMachineArguments
	call_argument_freelist_         []BinaryMachineArguments
	depth_                          uint
	ip_                             u64
	should_limit_instruction_count_ bool
	locals_base_                    &BinaryMachineValue           = unsafe { nil }
	call_record_base_               &BinaryMachineValue           = unsafe { nil }
	memory_instances_               &&BinaryMachineMemoryInstance = unsafe { nil }
	global_instances_               &&BinaryMachineGlobalInstance = unsafe { nil }
	compiled_call_result_scratch_   BinaryMachineValue
}

pub fn BinaryMachineConfiguration.create(mut store BinaryMachineStore) &BinaryMachineConfiguration {
	configuration := &BinaryMachineConfiguration{
		store_:                  &store
		value_stack_:            *BinaryMachineValueStack.create()
		call_record_stack_:      *BinaryMachineValueStack.create()
		label_stack_:            []BinaryMachineLabel{cap: 64}
		call_argument_freelist_: []BinaryMachineArguments{cap: 16}
	}
	store.register_configuration(configuration)
	return configuration
}

// Source unregisters in its destructor, then destroys members in reverse
// declaration order. V owners invoke this boundary once before releasing it.
pub fn (mut configuration BinaryMachineConfiguration) destroy() {
	configuration.store_.unregister_configuration(&configuration)
	// C++ destroys each owned inner Vector before releasing the outer storage.
	for index in 0 .. configuration.call_argument_freelist_.len {
		configuration.call_argument_freelist_[index].destroy()
	}
	for index in 0 .. configuration.owned_locals_stack_.len {
		configuration.owned_locals_stack_[index].destroy()
	}
	unsafe {
		configuration.call_argument_freelist_.free()
		configuration.owned_locals_stack_.free()
		configuration.frame_stack_.free()
		configuration.label_stack_.free()
	}
	configuration.call_record_stack_.destroy()
	configuration.value_stack_.destroy()
}

pub fn (mut store BinaryMachineStore) register_configuration(configuration &BinaryMachineConfiguration) {
	store.active_configurations_.entries[voidptr(configuration)] = true
}

pub fn (mut store BinaryMachineStore) unregister_configuration(configuration &BinaryMachineConfiguration) {
	store.active_configurations_.entries.delete(voidptr(configuration))
}

pub fn (store &BinaryMachineStore) active_configurations() &BinaryMachineActiveConfigurations {
	return &store.active_configurations_
}

pub fn (configuration &BinaryMachineConfiguration) store() &BinaryMachineStore {
	return configuration.store_
}

pub fn (mut configuration BinaryMachineConfiguration) frame() &BinaryMachineFrame {
	assert configuration.frame_stack_.len > 0
	return unsafe { &configuration.frame_stack_[configuration.frame_stack_.len - 1] }
}

pub fn (mut configuration BinaryMachineConfiguration) ip() &u64 { return &configuration.ip_ }

pub fn (mut configuration BinaryMachineConfiguration) depth() &uint {
	return &configuration.depth_
}

pub fn BinaryMachineConfiguration.locals_base_offset() uint {
	return __offsetof(BinaryMachineConfiguration, locals_base_)
}

pub fn BinaryMachineConfiguration.memory_instances_offset() uint {
	return __offsetof(BinaryMachineConfiguration, memory_instances_)
}

pub fn BinaryMachineConfiguration.global_instances_offset() uint {
	return __offsetof(BinaryMachineConfiguration, global_instances_)
}

pub fn BinaryMachineConfiguration.compiled_call_result_scratch_offset() uint {
	return __offsetof(BinaryMachineConfiguration, compiled_call_result_scratch_)
}

pub fn BinaryMachineConfiguration.value_stack_base_offset() uint {
	return __offsetof(BinaryMachineConfiguration, value_stack_) + BinaryMachineValueStack.base_offset()
}

pub fn BinaryMachineConfiguration.value_stack_top_offset() uint {
	return __offsetof(BinaryMachineConfiguration, value_stack_) + BinaryMachineValueStack.top_offset()
}

pub fn BinaryMachineConfiguration.call_record_base_offset() uint {
	return __offsetof(BinaryMachineConfiguration, call_record_base_)
}

pub fn (mut configuration BinaryMachineConfiguration) value_stack() &BinaryMachineValueStack {
	return &configuration.value_stack_
}

pub fn (configuration &BinaryMachineConfiguration) locals_base() &BinaryMachineValue {
	return configuration.locals_base_
}

pub fn (mut configuration BinaryMachineConfiguration) set_locals_base(base &BinaryMachineValue) {
	configuration.locals_base_ = unsafe { base }
}

pub fn (configuration &BinaryMachineConfiguration) local(index u32) &BinaryMachineValue {
	return unsafe { configuration.locals_base_ + index }
}

pub fn (configuration &BinaryMachineConfiguration) memory_instance(index uint) &BinaryMachineMemoryInstance {
	return unsafe { configuration.memory_instances_[index] }
}

pub fn (mut configuration BinaryMachineConfiguration) compiled_call_result_scratch() &BinaryMachineValue {
	return &configuration.compiled_call_result_scratch_
}

pub fn (configuration &BinaryMachineConfiguration) call_record_base() &BinaryMachineValue {
	return configuration.call_record_base_
}

pub fn (mut configuration BinaryMachineConfiguration) set_call_record_base(base &BinaryMachineValue) {
	configuration.call_record_base_ = unsafe { base }
}

pub fn (configuration &BinaryMachineConfiguration) call_record_entry(index uint) &BinaryMachineValue {
	return unsafe { configuration.call_record_base_ + index }
}

pub fn (mut configuration BinaryMachineConfiguration) setup_call_record(max_call_rec_size uint) {
	configuration.call_record_base_ = configuration.call_record_stack_.allocate(max_call_rec_size)
}

pub fn (mut configuration BinaryMachineConfiguration) enable_instruction_count_limit() {
	configuration.should_limit_instruction_count_ = true
}

pub fn (configuration &BinaryMachineConfiguration) should_limit_instruction_count() bool {
	return configuration.should_limit_instruction_count_
}

pub fn (mut configuration BinaryMachineConfiguration) push_to_destination(mix BinarySourceAddressMix, value BinaryMachineValue, destination BinaryRegisterOrStack) {
	slot := int(destination)
	match mix {
		.all_registers {
			configuration.regs[slot] = value
			return
		}
		.all_call_records {
			unsafe { configuration.call_record_base_[slot - int(BinaryRegisterOrStack.call_record)] = value }
			return
		}
		.all_stack {
			configuration.value_stack_.unchecked_append(value)
			return
		}
		.any {
			if (slot & ~7) == 0 {
				configuration.regs[slot] = value
				return
			}
		}
	}
	if mix == .any {
		if destination == .stack {
			configuration.value_stack_.unchecked_append(value)
			return
		}
		unsafe { configuration.call_record_base_[slot - int(BinaryRegisterOrStack.call_record)] = value }
		return
	}
	panic('Unreachable source address mix')
}

pub fn (configuration &BinaryMachineConfiguration) source_value(mix BinarySourceAddressMix, index u8, sources &BinaryRegisterOrStack) &BinaryMachineValue {
	source := unsafe { sources[index] }
	slot := int(source)
	match mix {
		.all_registers { return unsafe { &configuration.regs[slot] } }
		.all_call_records {
			return unsafe { configuration.call_record_base_ + slot - int(BinaryRegisterOrStack.call_record) }
		}
		.all_stack { return configuration.value_stack_.unsafe_last() }
		.any {
			if (slot & ~7) == 0 { return unsafe { &configuration.regs[slot] } }
		}
	}
	if mix == .any {
		if source == .stack { return configuration.value_stack_.unsafe_last() }
		return unsafe { configuration.call_record_base_ + slot - int(BinaryRegisterOrStack.call_record) }
	}
	panic('Unreachable source address mix')
}

pub fn (mut configuration BinaryMachineConfiguration) take_source(mix BinarySourceAddressMix, index u8, sources &BinaryRegisterOrStack) BinaryMachineValue {
	source := unsafe { sources[index] }
	slot := int(source)
	match mix {
		.all_registers { return configuration.regs[slot] }
		.all_call_records {
			return unsafe { configuration.call_record_base_[slot - int(BinaryRegisterOrStack.call_record)] }
		}
		.all_stack { return configuration.value_stack_.unsafe_take_last() }
		.any {
			if (slot & ~7) == 0 { return configuration.regs[slot] }
		}
	}
	if mix == .any {
		if source == .stack { return configuration.value_stack_.unsafe_take_last() }
		return unsafe { configuration.call_record_base_[slot - int(BinaryRegisterOrStack.call_record)] }
	}
	panic('Unreachable source address mix')
}

pub fn (mut configuration BinaryMachineConfiguration) reset_after_invoke() {
	configuration.value_stack_.reset_and_clear()
	configuration.call_record_stack_.reset_and_clear()
	configuration.label_stack_.clear()
	configuration.frame_stack_.clear()
	for index in 0 .. configuration.owned_locals_stack_.len {
		configuration.owned_locals_stack_[index].destroy()
	}
	for index in 0 .. configuration.call_argument_freelist_.len {
		configuration.call_argument_freelist_[index].destroy()
	}
	configuration.owned_locals_stack_.clear()
	configuration.call_argument_freelist_.clear()
	configuration.regs = [8]BinaryMachineValue{}
	configuration.depth_ = 0
	configuration.ip_ = 0
	configuration.locals_base_ = unsafe { nil }
	configuration.call_record_base_ = unsafe { nil }
	configuration.memory_instances_ = unsafe { nil }
	configuration.global_instances_ = unsafe { nil }
	configuration.compiled_call_result_scratch_ = BinaryMachineValue.from_i32(0)
}
