module libjs

$if test {
	__global call_argument_workspaces_disabled bool
	pub fn set_call_argument_workspaces_for_testing(enabled bool) { call_argument_workspaces_disabled = !enabled }
}

fn use_call_argument_workspaces() bool {
	$if test { if call_argument_workspaces_disabled { return false } }
	return true
}

const call_argument_workspace_limit = 64
const call_argument_workspace_capacity = 8

@[heap]
struct CallArgumentWorkspace {
mut:
	// Keep the fixed-width slots with their owner. Borrowed argument views
	// use this storage only until the synchronous call returns.
	values [call_argument_workspace_capacity]Value = [call_argument_workspace_capacity]Value{init: js_undefined()}
}

fn (mut stack InterpreterStack) acquire_call_argument_workspace() &CallArgumentWorkspace {
	depth := stack.call_argument_depth
	buffer := if depth < call_argument_workspace_limit {
		if depth == stack.call_argument_workspaces.len {
			stack.call_argument_workspaces << &CallArgumentWorkspace{}
		}
		stack.call_argument_workspaces[depth]
	} else { &CallArgumentWorkspace{} }
	stack.call_argument_depth++
	return buffer
}

fn (mut stack InterpreterStack) release_call_argument_workspace(mut buffer CallArgumentWorkspace, count int) {
	if stack.call_argument_depth <= 0 { panic('Call argument workspace depth underflow') }
	stack.call_argument_depth--
	if stack.call_argument_depth < stack.call_argument_workspaces.len
		&& voidptr(stack.call_argument_workspaces[stack.call_argument_depth]) != voidptr(buffer) {
		panic('Call argument workspaces must be released in call order')
	}
	for index in 0 .. count { buffer.values[index] = js_undefined() }
}

fn (frame &ExecutionContext) adjacent_call_registers(executable &Executable, operands []Operand) ?[]Value {
	if frame.exposed || operands.len == 0 { return none }
	first := operands[0].raw
	end := u64(first) + u64(operands.len)
	// A register run stays in operand tag zero and inside the live frame.
	if end > 0x20000000 || end > executable.registers_and_locals_count
		|| end > u64(frame.values.len) { return none }
	values := unsafe { &Value(frame.values.data) }
	for index, operand in operands {
		slot := first + u32(index)
		if operand.raw != slot || unsafe { values[slot].is_special_empty_value() } {
			return none
		}
	}
	return unsafe { borrow_argument_values(&values[first], operands.len) }
}

// Concrete callees copy before author code runs. Empty calls need no backing
// storage, and adjacent registers can be read directly during the copy. Other
// layouts use independent scratch buffers that are cleared after the call.
fn (mut vm VM) execute_reused_argument_call(instruction &Instruction, executable &Executable, target Value, receiver Value) !Value {
	count := instruction.arguments.len
	if count < 0 || count > call_argument_workspace_capacity {
		return error('Call argument workspace count out of range')
	}
	if count == 0 {
		return call(mut vm, target, receiver, unsafe { borrow_argument_values(nil, 0) })
	}
	frame := vm.current_context()
	if arguments := frame.adjacent_call_registers(executable, instruction.arguments) {
		return call(mut vm, target, receiver, arguments)
	}
	mut stack := vm.interpreter_stack()
	mut buffer := stack.acquire_call_argument_workspace()
	defer { stack.release_call_argument_workspace(mut buffer, count) }
	mut arguments := unsafe { borrow_argument_values(&buffer.values[0], count) }
	for index, operand in instruction.arguments {
		value := frame.checked_dispatch_value(operand.slot(executable, frame.argument_count, false)!)!
		if value.is_special_empty_value() { return vm.throw_error(.internal_error, 'Bytecode read an uninitialized argument') }
		arguments[index] = value
	}
	if mut tier := vm.native_tier { if tier.diagnostics { tier.activity.argument_workspace_calls++ } }
	return call(mut vm, target, receiver, arguments)
}
