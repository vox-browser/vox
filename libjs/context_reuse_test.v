module libjs

@[heap]
struct ReuseCapture {
mut:
	frames []&ExecutionContext
	views  [][]Value
}

fn test_reused_contexts_reset_layout_values_flags_and_assign_fresh_ids() {
	set_context_reuse_for_testing(true)
	mut stack := InterpreterStack.new()
	mark := stack.top()
	mut first := stack.allocate_reusable(6, [Value.from_i32(7)], 2) or { panic('first') }
	identity := voidptr(first)
	value_storage := first.values.data
	id := first.frame_id
	first.values[5] = Value.from_i32(99)
	first.set_argument(0, Value.from_i32(42))
	first.this_value = Value.from_i32(80)
	first.program_counter = 99
	first.frame_initialized = true
	snapshot := first.copy()
	stack.deallocate(mark)
	assert stack.depth() == 0 && stack.recycled.len == 1
	assert first.this_value == none && first.program_counter == 0 && !first.frame_initialized
	second := stack.allocate_reusable(5, [Value.from_i32(21), Value.from_i32(22)], 2) or { panic('second') }
	assert voidptr(second) == identity && second.frame_id > id
	assert second.values.data == value_storage
	for index in 0 .. 5 {
		assert second.values[index].is_special_empty_value()
	}
	assert second.values[5].number == 21 && second.values[6].number == 22
	assert second.argument(0).is_undefined() && second.argument(1).is_undefined()
	assert snapshot.argument(0).number == 42 && snapshot.values[5].number == 99
	stack.deallocate(mark)
}

fn test_public_allocations_and_argument_views_keep_independent_lifetimes() {
	mut stack := InterpreterStack.new()
	mut public_frame := stack.allocate(0, [], 1) or { panic('public') }
	public_frame.set_argument(0, Value.from_i32(41))
	stack.deallocate(0)
	assert public_frame.argument(0).number == 41 && stack.recycled.len == 0
	mut borrowed := stack.allocate_reusable(0, [], 1) or { panic('borrowed') }
	borrowed.set_argument(0, Value.from_i32(42))
	values := borrowed.arguments()
	stack.deallocate(0)
	replacement := stack.allocate_reusable(0, [], 1) or { panic('replacement') }
	assert voidptr(replacement) != voidptr(borrowed) && values[0].number == 42
	assert public_frame.argument(0).number == 41
	stack.deallocate(0)
}

fn test_native_callbacks_can_retain_public_contexts_and_value_views() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut capture := &ReuseCapture{}
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut capture] (mut vm VM) !Value {
		frame := vm.running_execution_context()
		capture.frames << frame
		capture.views << frame.arguments()
		return vm.argument(0)
	}, 1, PropertyName.from_str('capture'), none)
	assert call(mut vm, Value.from_object(function.object), js_undefined(), [Value.from_i32(42)])!.number == 42
	assert call(mut vm, Value.from_object(function.object), js_undefined(), [Value.from_i32(99)])!.number == 99
	assert capture.frames.len == 2 && voidptr(capture.frames[0]) != voidptr(capture.frames[1])
	assert capture.frames[0].frame_id != capture.frames[1].frame_id
	assert capture.frames[0].argument(0).number == 42 && capture.views[0][0].number == 42
	assert !capture.frames[0].stack_allocated && !capture.frames[1].stack_allocated
}

fn test_public_stack_walk_preserves_parent_locals_after_return() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut capture := &ReuseCapture{}
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut capture] (mut vm VM) !Value {
		if capture.frames.len == 0 {
			capture.frames = vm.execution_contexts_top_to_bottom()
			for frame in capture.frames {
				if executable := frame.executable {
					if executable.local_variable_names.len > 0 {
						capture.views << frame.local_variables()
					}
				}
			}
		}
		return js_undefined()
	}, 0, PropertyName.from_str('probe'), none)
	mut global := vm.get_global_object()
	global.define_direct_property(PropertyName.from_str('probe'), Value.from_object(function.object), 7)
	mut script := Script.parse('function f(x){probe();return x}f(42)', vm.realm(), 'reuse-stack.js', unsafe { nil })!
	assert vm.run(mut script)!.number == 42
	mut again := Script.parse('f(99)', vm.realm(), 'reuse-again.js', unsafe { nil })!
	assert vm.run(mut again)!.number == 99
	assert capture.views.len > 0 && capture.views[0][0].number == 42
	for frame in capture.frames {
		assert frame.exposed
	}
}

fn test_context_pool_bounds_and_stack_exhaustion_remain_enforced() {
	mut stack := InterpreterStack.new()
	for count in 0 .. 70 {
		assert stack.allocate_reusable(u32(count), [], 0) != none
	}
	stack.deallocate(0)
	assert stack.recycled.len <= reusable_context_count_limit && stack.recycled_bytes <= reusable_context_bytes_limit
	before := stack.recycled_bytes
	oversized_values := u32(reusable_context_bytes_limit / uint(sizeof(Value)) + 1)
	assert frame_size_in_bytes(oversized_values) > reusable_context_bytes_limit
	assert stack.allocate_reusable(oversized_values, [], 0) != none
	stack.deallocate(0)
	assert stack.recycled_bytes == before
	assert stack.allocate_reusable(1 << 20, [], 0) == none
	assert stack.depth() == 0 && stack.top() == 0
}

fn test_context_pool_admits_new_layouts_after_saturation() {
	mut stack := InterpreterStack.new()
	for count in 0 .. reusable_context_count_limit + 2 {
		assert stack.allocate_reusable(u32(count), [], 0) != none
		stack.deallocate(0)
	}
	diagnose_context_reuse_for_testing(true)
	assert stack.allocate_reusable(u32(reusable_context_count_limit + 1), [], 0) != none
	activity := diagnose_context_reuse_for_testing(false)
	assert activity.reused == 1 && activity.allocated == 0
	stack.deallocate(0)
	assert stack.recycled.len <= reusable_context_count_limit && stack.recycled_bytes <= reusable_context_bytes_limit
}

fn test_saved_stacks_and_trace_records_keep_contexts_stable() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut stack := vm.interpreter_stack()
	mut saved := stack.allocate_reusable(0, [], 1) or { panic('saved') }
	saved.set_argument(0, Value.from_i32(42))
	saved.program_counter = 17
	vm.push_execution_context_checked(mut saved)!
	vm.save_execution_context_stack()
	assert saved.exposed
	vm.restore_execution_context_stack()
	vm.pop_current_context()
	stack.deallocate(0)
	assert saved.argument(0).number == 42 && saved.program_counter == 17
	mut traced := stack.allocate_reusable(0, [], 1) or { panic('traced') }
	traced.set_argument(0, Value.from_i32(99))
	vm.push_execution_context_checked(mut traced)!
	trace := vm.stack_trace()
	vm.pop_current_context()
	stack.deallocate(0)
	replacement := stack.allocate_reusable(0, [], 1) or { panic('replacement') }
	assert voidptr(replacement) != voidptr(traced)
	assert trace[0].execution_context.argument(0).number == 99
	stack.deallocate(0)
}

fn test_public_pop_and_local_views_are_escape_barriers() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut stack := vm.interpreter_stack()
	mut frame := stack.allocate_reusable(6, [], 0) or { panic('frame') }
	frame.values[5] = Value.from_i32(42)
	vm.push_execution_context_checked(mut frame)!
	retained := vm.pop_execution_context()
	stack.deallocate(0)
	assert retained.values[5].number == 42
	mut locals_frame := stack.allocate_reusable(6, [], 0) or { panic('locals') }
	locals_frame.executable = &Executable{ registers_and_locals_count: 6, local_index_base: 5, local_variable_names: [utf16_string('x')] }
	locals_frame.values[5] = Value.from_i32(99)
	locals := locals_frame.local_variables()
	stack.deallocate(0)
	replacement := stack.allocate_reusable(6, [], 0) or { panic('replacement') }
	assert voidptr(replacement) != voidptr(locals_frame) && locals[0].number == 99
	assert retained.values[5].number == 42
	stack.deallocate(0)
}
