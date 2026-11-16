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

@[heap]
struct CallArgumentWorkspace {
mut:
	values []Value
}

fn (mut stack InterpreterStack) acquire_call_argument_workspace() &CallArgumentWorkspace {
	depth := stack.call_argument_depth
	buffer := if depth < call_argument_workspace_limit {
		if depth == stack.call_argument_workspaces.len {
			stack.call_argument_workspaces << &CallArgumentWorkspace{values: []Value{len: 8}}
		}
		stack.call_argument_workspaces[depth]
	} else { &CallArgumentWorkspace{values: []Value{len: 8}} }
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

// Concrete callees copy before author code runs. Nested calls get independent
// buffers; deep calls beyond the retained bound get fresh storage. Callee copies
// may outlive the call; clear our private slots before making the buffer reusable.
fn (mut vm VM) execute_reused_argument_call(instruction &Instruction, executable &Executable, target Value, receiver Value) !Value {
	count := instruction.arguments.len
	if count < 0 || count > 8 { return error('Call argument workspace count out of range') }
	mut stack := vm.interpreter_stack()
	mut buffer := stack.acquire_call_argument_workspace()
	defer { stack.release_call_argument_workspace(mut buffer, count) }
	mut arguments := unsafe { borrow_argument_values(&buffer.values[0], count) }
	frame := vm.current_context()
	for index, operand in instruction.arguments {
		value := frame.checked_dispatch_value(operand.slot(executable, frame.argument_count, false)!)!
		if value.is_special_empty_value() { return vm.throw_error(.internal_error, 'Bytecode read an uninitialized argument') }
		arguments[index] = value
	}
	if mut tier := vm.native_tier { if tier.diagnostics { tier.activity.argument_workspace_calls++ } }
	return call(mut vm, target, receiver, arguments)
}
