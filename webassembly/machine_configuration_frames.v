// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// Configuration.h::set_frame/set_frame_lightweight/CallFrameHandle and
// Configuration.cpp::unwind_impl. These install real records without execution.
module webassembly

pub enum BinaryIsTailcall {
	no
	yes
}

pub fn (mut configuration BinaryMachineConfiguration) set_frame(is_tailcall BinaryIsTailcall, module_ &BinaryMachineModuleInstance, mut locals BinaryMachineArguments, expression &BinaryExpression, arity uint) {
	configuration.owned_locals_stack_ << BinaryMachineArguments.move_construct(mut locals)
	index := configuration.owned_locals_stack_.len - 1
	locals_ptr := configuration.owned_locals_stack_[index].data()
	configuration.frame_stack_ << BinaryMachineFrame.create(module_, locals_ptr, expression, arity, true)
	mut frame := configuration.frame()
	mut owner := unsafe { &BinaryMachineModuleInstance(module_) }
	configuration.locals_base_ = locals_ptr
	configuration.memory_instances_ = owner.resolved_memories(configuration.store_)
	configuration.global_instances_ = owner.resolved_globals(configuration.store_)
	frame.set_compiled_fn_table(owner.compiled_fn_table(configuration.store_))
	mut continuation := uint(expression.instructions.len) - 1
	if expression.compiled_instructions.dispatches.len > 0 {
		continuation = uint(expression.compiled_instructions.dispatches.len) - 1
	}
	label := BinaryMachineLabel.create(arity, u32(continuation), configuration.value_stack_.size(), unsafe { nil })
	frame.set_label_index(uint(configuration.label_stack_.len))
	if hint := expression.stack_usage_hint {
		configuration.value_stack_.ensure_capacity(hint + configuration.value_stack_.size())
	}
	depth := expression.compiled_instructions.max_label_depth
	if depth > 0 {
		configuration.label_stack_.ensure_cap(int(depth) + configuration.label_stack_.len)
	}
	configuration.label_stack_ << label
	if is_tailcall == .yes && configuration.call_record_base_ != unsafe { nil } {
		configuration.call_record_stack_.release_to(configuration.call_record_base_)
	}
	size := expression.compiled_instructions.max_call_rec_size
	if size > 0 {
		configuration.call_record_base_ = configuration.call_record_stack_.allocate(size)
	} else {
		configuration.call_record_base_ = unsafe { nil }
	}
}

pub fn (mut configuration BinaryMachineConfiguration) set_frame_lightweight(module_ &BinaryMachineModuleInstance, locals_ptr &BinaryMachineValue, expression &BinaryExpression, arity uint, max_call_rec_size uint) {
	if module_ == unsafe { nil } { panic('Source VERIFY: lightweight frame needs a module') }
	same_module := configuration.frame_stack_.len > 0 && voidptr(configuration.frame().module()) == voidptr(module_)
	mut owner := unsafe { &BinaryMachineModuleInstance(module_) }
	mut table := unsafe { &BinaryMachineCompiledFunctionTable(nil) }
	if same_module {
		table = configuration.frame().compiled_fn_table()
	} else {
		table = owner.compiled_fn_table(configuration.store_)
	}
	configuration.frame_stack_ << BinaryMachineFrame.create(module_, locals_ptr, expression, arity, false)
	mut frame := configuration.frame()
	frame.set_compiled_fn_table(table)
	configuration.locals_base_ = unsafe { locals_ptr }
	if !same_module {
		configuration.memory_instances_ = owner.resolved_memories(configuration.store_)
		configuration.global_instances_ = owner.resolved_globals(configuration.store_)
	}
	if hint := expression.stack_usage_hint {
		configuration.value_stack_.ensure_capacity(configuration.value_stack_.size() + hint)
	}
	if max_call_rec_size > 0 {
		configuration.call_record_base_ = configuration.call_record_stack_.allocate(max_call_rec_size)
	}
	// Source leaves the current record pointer intact for a zero-sized call and
	// pushes no label: native compiled code owns its structured control flow.
}

pub fn (mut configuration BinaryMachineConfiguration) unwind_impl() {
	configuration.depth_--
	mut released := BinaryMachineArguments{}
	popped_module := configuration.frame().module()
	owned := configuration.frame().owns_locals()
	if owned {
		index := configuration.owned_locals_stack_.len - 1
		released = BinaryMachineArguments.move_construct(mut configuration.owned_locals_stack_[index])
		configuration.owned_locals_stack_.delete(index)
	}
	configuration.frame_stack_.delete(configuration.frame_stack_.len - 1)
	if configuration.frame_stack_.len == 0 {
		configuration.locals_base_ = unsafe { nil }
		configuration.memory_instances_ = unsafe { nil }
		configuration.global_instances_ = unsafe { nil }
	} else {
		caller := configuration.frame()
		if caller.owns_locals() {
			index := configuration.owned_locals_stack_.len - 1
			configuration.locals_base_ = configuration.owned_locals_stack_[index].data()
		} else {
			configuration.locals_base_ = caller.locals_data()
		}
		if voidptr(caller.module()) != voidptr(popped_module) {
			mut owner := unsafe { &BinaryMachineModuleInstance(caller.module()) }
			configuration.memory_instances_ = owner.resolved_memories(configuration.store_)
			configuration.global_instances_ = owner.resolved_globals(configuration.store_)
		}
	}
	if owned {
		configuration.release_arguments_allocation(mut released)
		// Source Optional's Vector destructor frees a rejected/full freelist entry.
		released.destroy()
	}
}

pub struct BinaryMachineCallFrameHandle {
	configuration          &BinaryMachineConfiguration
	saved_call_record_base &BinaryMachineValue
	saved_call_record_mark &BinaryMachineValue
}

pub fn BinaryMachineCallFrameHandle.create(mut configuration BinaryMachineConfiguration) BinaryMachineCallFrameHandle {
	result := BinaryMachineCallFrameHandle{
		configuration:          &configuration
		saved_call_record_base: configuration.call_record_base_
		saved_call_record_mark: configuration.call_record_stack_.mark()
	}
	configuration.depth_++
	configuration.call_record_base_ = unsafe { nil }
	return result
}

// Call exactly once, normally through defer, after installing a frame. This is
// the V boundary for the source C++ destructor's automatic stack unwinding.
pub fn (handle &BinaryMachineCallFrameHandle) destroy() {
	mut configuration := unsafe { &BinaryMachineConfiguration(handle.configuration) }
	configuration.call_record_stack_.release_to(handle.saved_call_record_mark)
	configuration.call_record_base_ = handle.saved_call_record_base
	configuration.unwind_impl()
}
