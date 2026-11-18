module libjs

import platform

fn test_call_argument_workspaces_do_not_accumulate_per_call_buffers() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype,
		fn (mut vm VM) !Value { return vm.argument(0) }, 1, PropertyName.from_str('pass'), none)
	target := Value.from_object(function.object)
	executable := &Executable{registers_and_locals_count: 6,
		constants: [Value.from_i32(42)], instructions: [Instruction{op: .call, arguments: [Operand.constant(0)]}]}
	mut frame := ExecutionContext.create(6, executable.constants, 0)
	frame.realm = vm.realm()
	vm.push_execution_context_checked(mut frame)!
	defer { vm.pop_execution_context(); set_call_argument_workspaces_for_testing(true) }
	for enabled in [false, true] {
		set_call_argument_workspaces_for_testing(enabled)
		assert vm.execute_call_instruction(&executable.instructions[0], executable, target, js_undefined())!.as_i32() == 42
		before := platform.thread_arena_usage().used
		for _ in 0 .. 10000 {
			assert vm.execute_call_instruction(&executable.instructions[0], executable, target, js_undefined())!.as_i32() == 42
		}
		$if prealloc {
			growth := platform.thread_arena_usage().used - before
			if enabled { assert growth < 4096, 'argument call retained ${growth} bytes' }
			else { assert growth >= 10000 * 128 }
		}
	}
}

fn test_call_argument_workspaces_preserve_nested_calls_retained_views_and_owning_fallbacks() {
	for enabled in [false, true] {
		set_call_argument_workspaces_for_testing(enabled)
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.profile_native_code()!
		vm.diagnose_native_code(true)!
		mut script := Script.parse('function pass(x){return arguments}function add(x,y){return x+y}var a=pass(41),b=pass(42);var held;var proxy=new Proxy(function(){},{apply(t,r,args){held=args;return args[0]}});proxy(43);var threw=false;try{(function(x){throw x})(44)}catch(e){threw=e===44}function many(a,b,c,d,e,f,g,h,i){return i}a[0]===41&&b[0]===42&&add(add(20,20),2)===42&&held[0]===43&&threw&&many(1,2,3,4,5,6,7,8,9)===9',
			vm.realm(), 'stack-arguments.js', unsafe { nil })!
		assert vm.run(mut script)!.as_bool()
		assert (vm.diagnose_native_code(false)!.argument_workspace_calls > 0) == enabled
		assert vm.interpreter_stack().depth() == 0
	}
	set_call_argument_workspaces_for_testing(true)
}

fn test_adjacent_call_arguments_borrow_only_initialized_live_registers() {
	executable := &Executable{
		registers_and_locals_count: 8
		constants: [Value.from_i32(99)]
	}
	mut frame := ExecutionContext.create(8, executable.constants, 0)
	frame.values[5] = Value.from_i32(11)
	frame.values[6] = Value.from_i32(31)
	frame.values[7] = js_special_empty_value()
	regs := [Operand.register(5), Operand.register(6)]
	arguments := frame.adjacent_call_registers(executable, regs) or { panic('Expected adjacent registers') }
	assert arguments.data == unsafe { voidptr(&frame.values[5]) }
	assert arguments[0].as_i32() == 11 && arguments[1].as_i32() == 31
	assert frame.adjacent_call_registers(executable, [regs[1], regs[0]]) == none
	assert frame.adjacent_call_registers(executable, [regs[1], Operand.register(7)]) == none
	assert frame.adjacent_call_registers(executable, [Operand.constant(0)]) == none
	assert frame.adjacent_call_registers(executable, [Operand.register(8)]) == none
	frame.exposed = true
	assert frame.adjacent_call_registers(executable, regs) == none
}

fn test_argumentless_native_calls_skip_workspaces_with_an_exposed_caller() {
	set_call_argument_workspaces_for_testing(true)
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype,
		fn (mut vm VM) !Value {
			assert vm.argument_count() == 0
			assert vm.argument(0).is_undefined()
			return vm.this_value()
		}, 0, PropertyName.from_str('receiver'), none)
	executable := &Executable{registers_and_locals_count: 5, instructions: [Instruction{op: .call}]}
	mut frame := ExecutionContext.create(5, []Value{}, 0)
	frame.realm = vm.realm()
	vm.push_execution_context_checked(mut frame)!
	defer { vm.pop_execution_context() }
	for exposed in [false, true] {
		frame.exposed = exposed
		result := vm.execute_call_instruction(&executable.instructions[0], executable,
			Value.from_object(function.object), Value.from_i32(42))!
		assert result.as_i32() == 42
		assert vm.interpreter_stack().call_argument_workspaces.len == 0
		assert vm.interpreter_stack().call_argument_depth == 0
	}
}

fn test_call_argument_workspace_pool_is_bounded_and_releases_references() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut stack := vm.interpreter_stack()
	value := Value.from_object(Object.create(vm.realm(), none))
	mut buffers := []&CallArgumentWorkspace{}
	for _ in 0 .. call_argument_workspace_limit + 5 {
		mut buffer := stack.acquire_call_argument_workspace()
		for index in 0 .. call_argument_workspace_capacity {
			assert buffer.values[index].is_undefined()
			buffer.values[index] = value
		}
		buffers << buffer
	}
	assert stack.call_argument_workspaces.len == call_argument_workspace_limit
	assert vm.heap_roots().contains(value.cell)
	for index := buffers.len - 1; index >= 0; index-- {
		mut buffer := buffers[index]
		stack.release_call_argument_workspace(mut buffer, call_argument_workspace_capacity)
		for item in buffer.values { assert item.is_undefined() }
	}
	assert stack.call_argument_depth == 0
	assert !vm.heap_roots().contains(value.cell)
	mut reused := stack.acquire_call_argument_workspace()
	assert voidptr(reused) == voidptr(buffers[0])
	for item in reused.values { assert item.is_undefined() }
	stack.release_call_argument_workspace(mut reused, 0)
}

fn test_call_argument_workspace_clears_slots_after_operand_error() {
	set_call_argument_workspaces_for_testing(true)
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype,
		fn (mut vm VM) !Value { return js_undefined() }, 2, PropertyName.from_str('callee'), none)
	executable := &Executable{
		registers_and_locals_count: 6
		constants: [Value.from_object(Object.create(vm.realm(), none))]
		instructions: [
			Instruction{op: .call, arguments: [Operand.constant(0), Operand.register(5)]},
		]
	}
	mut frame := ExecutionContext.create(6, executable.constants, 0)
	frame.realm = vm.realm()
	frame.values[5] = js_special_empty_value()
	vm.push_execution_context_checked(mut frame)!
	defer { vm.pop_execution_context() }
	vm.execute_call_instruction(&executable.instructions[0], executable,
		Value.from_object(function.object), js_undefined()) or {
		assert is_throw_completion(err)
		stack := vm.interpreter_stack()
		assert stack.call_argument_depth == 0
		assert stack.call_argument_workspaces.len == 1
		for value in stack.call_argument_workspaces[0].values { assert value.is_undefined() }
		return
	}
	assert false, 'Expected the second operand to reject an uninitialized value'
}
