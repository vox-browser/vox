module webassembly

import libjs

@[heap]
struct BytecodeTrapVisitObservation {
mut:
	calls   int
	pointer voidptr
}

fn test_source_bytecode_trap_visitor_borrows_the_actual_owned_external_payload_and_ignores_other_alternatives() {
	info_value := libjs.StackInfo.new()
	info := &info_value
	mut interpreter := BinaryMachineBytecodeInterpreter.create(info)
	observation := &BytecodeTrapVisitObservation{}
	visitor := BinaryMachineHostVisitOps{
		visit_trap: fn [observation] (mut external BinaryExternallyManagedTrap) {
			mut owner := unsafe { &BytecodeTrapVisitObservation(observation) }
			owner.calls++
			owner.pointer = unsafe { voidptr(&external) }
			external.data[0] = 91
		}
	}
	assert !interpreter.did_trap()
	interpreter.visit_external_resources(visitor)
	interpreter.set_trap_message('actual message')
	interpreter.visit_external_resources(visitor)
	interpreter.set_trap(BinaryMachineTrap{ data: BinaryUncaughtException{ address: 41 } })
	interpreter.visit_external_resources(visitor)
	assert observation.calls == 0
	mut original := BinaryExternallyManagedTrap{}
	original.data[0] = 73
	interpreter.set_trap(BinaryMachineTrap{ data: original })
	interpreter.visit_external_resources(visitor)
	assert observation.calls == 1
	if interpreter.trap_ is BinaryMachineTrap {
		if interpreter.trap_.data is BinaryExternallyManagedTrap {
			assert interpreter.trap_.data.data[0] == 91
			assert observation.pointer == voidptr(&interpreter.trap_.data)
		} else {
			assert false
		}
	} else {
		assert false
	}
	assert original.data[0] == 73
	interpreter.clear_trap()
	interpreter.visit_external_resources(visitor)
	assert !interpreter.did_trap() && observation.calls == 1
}

fn test_source_bytecode_conditional_traps_preserve_existing_state_on_success_and_clear_original_errors() {
	info_value := libjs.StackInfo.new()
	info := &info_value
	mut interpreter := BinaryMachineBytecodeInterpreter.create(info)
	created := interpreter.set_trap_message('first')
	assert created && interpreter.did_trap() && interpreter.trap().format() == 'first'
	passed := interpreter.trap_if_not(true, 'ignored')
	assert !passed && interpreter.trap().format() == 'first'
	failed := interpreter.trap_if_not(false, 'second')
	assert failed && interpreter.trap().format() == 'second'
	interpreter.clear_trap()
	interpreter.clear_trap()
	assert !interpreter.did_trap()
}

fn test_source_bytecode_native_stack_guard_retains_its_actual_stack_info_owner_and_source_failure_message() {
	info_value := libjs.StackInfo.new()
	info := &info_value
	mut interpreter := BinaryMachineBytecodeInterpreter.create(info)
	assert voidptr(interpreter.stack_info_) == voidptr(info)
	zero := interpreter.trap_if_insufficient_native_stack_space(0)
	assert !zero && !interpreter.did_trap()
	exhausted := interpreter.trap_if_insufficient_native_stack_space(~uint(0))
	assert exhausted && interpreter.trap().format() == 'STACK-EXHAUSTION'
	passed := interpreter.trap_if_insufficient_native_stack_space(0)
	assert !passed && interpreter.trap().format() == 'STACK-EXHAUSTION'
	interpreter.clear_trap()
	default_failed := interpreter.trap_if_insufficient_native_stack_space_default()
	assert !default_failed && !interpreter.did_trap()
}
