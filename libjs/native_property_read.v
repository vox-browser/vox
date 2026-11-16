module libjs

// The generated library supplies only instruction/layout integers. Runtime
// values and callbacks always come from the current invocation, never disk.

$if test {
	__global native_property_reads_disabled bool
	pub fn set_native_property_reads_for_testing(enabled bool) { native_property_reads_disabled = !enabled }
}

fn use_native_property_reads() bool {
	$if test { if native_property_reads_disabled { return false } }
	return true
}

fn native_property_helpers() string {
	sample := NativeInvocation{vm: unsafe { nil }, executable: unsafe { nil }}
	offset := uint(&sample.property_read_step) - uint(&sample)
	return '#include <string.h>
typedef uint32_t (*PropertyRead)(void*,void*);
_Static_assert(sizeof(PropertyRead)==${sizeof(voidptr)}, "Property callback size");
static PropertyRead property_reader(void *state) {
 PropertyRead fn; memcpy(&fn,(char*)state+${offset},sizeof(fn)); return fn;
}'
}

fn native_property_plan(instruction Instruction, executable &Executable, pc u32) ?string {
	if !use_native_property_reads() || instruction.op != .get_property { return none }
	lhs := instruction.lhs.slot(executable, 0, false) or { return none }
	rhs := instruction.rhs.slot(executable, 0, false) or { return none }
	dst := instruction.dst.slot(executable, 0, true) or { return none }
	return '${pc},${lhs},${rhs},${dst},${instruction.lhs.raw},${instruction.rhs.raw},${instruction.dst.raw},${executable.registers_and_locals_count},${executable.constants.len},${executable.local_index_base},${executable.local_variable_names.len}'
}

@[inline]
fn native_property_layout_matches(executable &Executable, plan &u32) bool {
	return unsafe { executable.registers_and_locals_count == plan[7]
		&& u32(executable.constants.len) == plan[8]
		&& executable.local_index_base == plan[9]
		&& u32(executable.local_variable_names.len) == plan[10] }
}

fn native_property_step(opaque voidptr, opaque_plan voidptr) u32 {
	mut invocation := unsafe { &NativeInvocation(opaque) }
	plan := unsafe { &u32(opaque_plan) }
	pc := unsafe { plan[0] }
	executable := invocation.executable
	if pc >= u32(executable.instructions.len) {
		invocation.failure = error('Native property instruction out of range')
		return 0xffffffff
	}
	instruction := &executable.instructions[pc]
	if !use_native_property_reads() || !use_native_dynamic_dispatch()
		|| instruction.op != .get_property || !native_property_layout_matches(executable, plan)
		|| instruction.lhs.raw != unsafe { plan[4] }
		|| instruction.rhs.raw != unsafe { plan[5] }
		|| instruction.dst.raw != unsafe { plan[6] } {
		return native_slow_step(opaque, pc)
	}
	mut vm := invocation.vm
	mut frame := vm.current_context()
	frame.program_counter = pc
	if mut tier := vm.native_tier {
		if tier.diagnostics { tier.activity.slow_steps++ }
	}
	vm.consume_execution_budget() or {
		invocation.failure = err
		return 0xffffffff
	}
	if mut tier := vm.native_tier {
		if tier.diagnostics {
			tier.activity.direct_slow_steps++
			tier.activity.specialized_property_steps++
		}
	}
	vm.execute_planned_property(executable, plan, instruction.strict) or {
		if is_throw_completion(err) && vm.handle_exception(pc, thrown_value(err)) == .continue_in_this_executable {
			return frame.program_counter
		}
		invocation.failure = err
		return 0xffffffff
	}
	frame.program_counter = pc + 1
	return pc + 1
}

fn (mut vm VM) execute_planned_property(executable &Executable, plan &u32, strict bool) ! {
	mut frame := vm.current_context()
	left := frame.checked_dispatch_value(unsafe { plan[1] })!
	if left.is_special_empty_value() {
		return vm.throw_error(.internal_error, 'Bytecode read an uninitialized operand')
	}
	right := frame.checked_dispatch_value(unsafe { plan[2] })!
	if right.is_special_empty_value() {
		return vm.throw_error(.internal_error, 'Bytecode read an uninitialized operand')
	}
	result := vm.execute_property_read(left, right, strict)!
	// A getter/coercion hook can call the embedder. Resolve a changed destination
	// after that callback just as the generic instruction handler does.
	instruction := &executable.instructions[unsafe { plan[0] }]
	dst := if instruction.dst.raw == unsafe { plan[6] } && native_property_layout_matches(executable, plan) {
		unsafe { plan[3] }
	} else { instruction.dst.slot(executable, frame.argument_count, true)! }
	frame.store_dispatch_value(dst, result)!
}
