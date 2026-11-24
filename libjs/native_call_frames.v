module libjs

// Native builtin frames hold only their arguments: no registers, locals or
// constants. Upstream allocates them on the native stack for each call; here
// each native nesting depth keeps one frame record for the next call at that
// depth, so a builtin call neither searches nor refills the general frame pool.
// The record is accounted on the InterpreterStack exactly like a pooled frame.
// It is never `reusable`, so InterpreterStack.deallocate() leaves it out of
// the general pool; a record that was exposed or given suspension state is
// abandoned to its holders and the depth gets a fresh one.

const native_frame_minimum_capacity = 8

$if test {
	__global native_frame_slots_disabled_for_test bool
	__global native_frame_slots_reused_for_test u64
	pub fn set_native_frame_slots_for_testing(enabled bool) { native_frame_slots_disabled_for_test = !enabled }
	pub fn native_frame_slot_reuses_for_testing() u64 {
		count := native_frame_slots_reused_for_test
		native_frame_slots_reused_for_test = 0
		return count
	}
}

fn use_native_frame_slots() bool {
	$if test { if native_frame_slots_disabled_for_test { return false } }
	return use_context_reuse()
}

@[inline]
fn (mut stack InterpreterStack) allocate_native_frame(arguments u32) ?&ExecutionContext {
	new_top := stack.top_ + frame_size_in_bytes(u64(arguments))
	if new_top > stack.limit { return none }
	depth := stack.native_frame_depth
	mut context := unsafe { &ExecutionContext(nil) }
	if depth < stack.native_frames.len {
		context = stack.native_frames[depth]
	}
	if context != unsafe { nil } && u64(context.values.cap) >= u64(arguments) {
		// release_native_frame() cleared the previous call's values and state.
		unsafe { context.values.len = int(arguments) }
		context.argument_count = arguments
		$if test { native_frame_slots_reused_for_test++ }
	} else {
		capacity := if arguments < native_frame_minimum_capacity { u32(native_frame_minimum_capacity) } else { arguments }
		context = ExecutionContext.create(0, []Value{}, capacity)
		unsafe { context.values.len = int(arguments) }
		context.argument_count = arguments
		if depth < stack.native_frames.len {
			stack.native_frames[depth] = context
		} else {
			stack.native_frames << context
		}
	}
	context.frame_id = stack.next_frame_id
	stack.next_frame_id++
	context.stack_offset = stack.top_
	context.stack_allocated = true
	push_within_capacity(mut stack.contexts, context)
	stack.top_ = new_top
	stack.native_frame_depth = depth + 1
	return context
}

// Pops the native frame at `mark` (and anything a failed callee left above
// it), then clears it for the next call at this depth unless something still
// holds it.
@[inline]
fn (mut stack InterpreterStack) release_native_frame(mut context ExecutionContext, mark uint) {
	last := stack.contexts.len - 1
	if last >= 0 && voidptr(stack.contexts[last]) == voidptr(context) && context.stack_offset == mark {
		unsafe {
			stack.contexts[last] = nil
			stack.contexts.len = last
		}
		context.stack_allocated = false
		stack.top_ = mark
	} else {
		stack.deallocate(mark)
	}
	depth := stack.native_frame_depth - 1
	stack.native_frame_depth = depth
	if context.exposed || context.async_execution != none || context.generator_execution != none
		|| context.caller_frame != none {
		if depth < stack.native_frames.len && voidptr(stack.native_frames[depth]) == voidptr(context) {
			stack.native_frames[depth] = unsafe { nil }
		}
		return
	}
	// The record keeps its storage; only the logical length is reset.
	mut values := unsafe { context.values }
	unsafe {
		data := &Value(values.data)
		for index in 0 .. values.len { data[index] = js_undefined() }
		values.len = 0
		*context = ExecutionContext{
			values: values
		}
	}
}
