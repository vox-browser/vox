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

fn test_call_argument_workspace_pool_is_bounded_and_releases_references() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut stack := vm.interpreter_stack()
	value := Value.from_object(Object.create(vm.realm(), none))
	mut buffers := []&CallArgumentWorkspace{}
	for _ in 0 .. call_argument_workspace_limit + 5 {
		mut buffer := stack.acquire_call_argument_workspace()
		buffer.values[0] = value
		buffers << buffer
	}
	assert stack.call_argument_workspaces.len == call_argument_workspace_limit
	assert vm.heap_roots().contains(value.cell)
	for index := buffers.len - 1; index >= 0; index-- {
		mut buffer := buffers[index]
		stack.release_call_argument_workspace(mut buffer, 1)
		assert buffer.values[0].is_undefined()
	}
	assert stack.call_argument_depth == 0
	mut reused := stack.acquire_call_argument_workspace()
	assert voidptr(reused) == voidptr(buffers[0])
	for item in reused.values { assert item.is_undefined() }
	stack.release_call_argument_workspace(mut reused, 0)
}
