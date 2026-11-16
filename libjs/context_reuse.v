module libjs

// Only private synchronous-call allocations enter this pool. Public frame and
// value-view APIs mark their frames exposed, preserving their existing lifetime.
const reusable_context_count_limit = 64
const reusable_context_bytes_limit = uint(1024 * 1024)

pub struct ContextReuseActivity {
pub:
	reused    u64
	allocated u64
	exposed   u64
}

$if test {
	__global context_reuse_disabled_for_test bool
	__global context_reuse_diagnostic_for_test bool
	__global contexts_reused_for_test u64
	__global contexts_allocated_for_test u64
	__global contexts_exposed_for_test u64
	pub fn set_context_reuse_for_testing(enabled bool) {
		context_reuse_disabled_for_test = !enabled
	}
	pub fn diagnose_context_reuse_for_testing(enabled bool) ContextReuseActivity {
		previous := ContextReuseActivity{contexts_reused_for_test, contexts_allocated_for_test, contexts_exposed_for_test}
		contexts_reused_for_test = 0
		contexts_allocated_for_test = 0
		contexts_exposed_for_test = 0
		context_reuse_diagnostic_for_test = enabled
		return previous
	}
}

fn use_context_reuse() bool {
	$if test {
		if context_reuse_disabled_for_test || rounded_context_capacity_for_test { return false }
	}
	return true
}

fn expose_execution_context(context &ExecutionContext) {
	mut current := ?&ExecutionContext(context)
	for {
		frame := current or { break }
		mut owner := unsafe { &ExecutionContext(frame) }
		if owner.exposed { break }
		owner.exposed = true
		current = owner.caller_frame
	}
}

@[direct_array_access]
fn (mut context ExecutionContext) clear_for_reuse() {
	// The loop is bounded by this array's own length; no user code runs here.
	for index in 0 .. context.values.len { context.values[index] = js_undefined() }
	values := context.values
	unsafe { *context = ExecutionContext{ values: values, reusable: true } }
}

fn (mut stack InterpreterStack) allocate_reusable(registers u32, constants []Value, arguments u32) ?&ExecutionContext {
	if !use_context_reuse() { return stack.allocate(registers, constants, arguments) }
	count := u64(registers) + u64(constants.len) + arguments
	size := frame_size_in_bytes(count)
	new_top := stack.top_ + size
	if new_top > stack.limit { return none }
	for index := stack.recycled.len - 1; index >= 0; index-- {
		mut context := stack.recycled[index]
		if u64(context.values.len) != count { continue }
		stack.recycled.delete(index)
		stack.recycled_bytes -= size
		context.argument_count = arguments
		for slot in 0 .. int(if registers < reserved_register_count {
			registers
		} else {
			reserved_register_count
		}) {
			context.values[slot] = js_special_empty_value()
		}
		for slot, value in constants { context.values[int(registers) + slot] = value }
		context.frame_id = stack.next_frame_id
		stack.next_frame_id++
		context.stack_offset = stack.top_
		context.stack_allocated = true
		stack.contexts << context
		stack.top_ = new_top
		$if test {
			if context_reuse_diagnostic_for_test { contexts_reused_for_test++ }
		}
		return context
	}
	mut context := stack.allocate(registers, constants, arguments) or { return none }
	context.reusable = true
	$if test {
		if context_reuse_diagnostic_for_test { contexts_allocated_for_test++ }
	}
	return context
}

fn (mut stack InterpreterStack) recycle_context(mut context ExecutionContext) {
	if !use_context_reuse() || !context.reusable { return }
	if context.exposed {
		$if test {
			if context_reuse_diagnostic_for_test { contexts_exposed_for_test++ }
		}
		return
	}
	// Suspensions own saved copies, and inline linkage is kept on the ordinary
	// allocator. Do not retain an oversized buffer or an unbounded free list.
	if context.async_execution != none || context.generator_execution != none || context.caller_frame != none
		|| context.values.cap != context.values.len {
		return
	}
	size := frame_size_in_bytes(u64(context.values.len))
	if size > reusable_context_bytes_limit { return }
	// Admit new layouts when the pool is full instead of keeping a permanent
	// set of cold layouts. Every evicted record is already cleared/unexposed.
	for stack.recycled.len >= reusable_context_count_limit
		|| stack.recycled_bytes + size > reusable_context_bytes_limit {
		oldest := stack.recycled[0]
		stack.recycled_bytes -= frame_size_in_bytes(u64(oldest.values.len))
		stack.recycled.delete(0)
	}
	context.clear_for_reuse()
	stack.recycled << &context
	stack.recycled_bytes += size
}
