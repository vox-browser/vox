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
	direct_initializations u64
	direct_argument_values u64
}

$if test {
	__global context_reuse_disabled_for_test bool
	__global context_reuse_diagnostic_for_test bool
	__global contexts_reused_for_test u64
	__global contexts_allocated_for_test u64
	__global contexts_exposed_for_test u64
	__global direct_context_initialization_disabled bool
	__global contexts_initialized_directly_for_test u64
	pub fn set_direct_context_initialization_for_testing(enabled bool) {
		direct_context_initialization_disabled = !enabled
	}
	pub fn set_context_reuse_for_testing(enabled bool) {
		context_reuse_disabled_for_test = !enabled
	}
	pub fn diagnose_context_reuse_for_testing(enabled bool) ContextReuseActivity {
		previous := ContextReuseActivity{contexts_reused_for_test, contexts_allocated_for_test, contexts_exposed_for_test, contexts_initialized_directly_for_test, directly_copied_argument_values}
		contexts_reused_for_test = 0
		contexts_allocated_for_test = 0
		contexts_exposed_for_test = 0
		contexts_initialized_directly_for_test = 0
		directly_copied_argument_values = 0
		context_reuse_diagnostic_for_test = enabled
		return previous
	}
}

fn use_direct_context_initialization() bool {
	$if test { if direct_context_initialization_disabled { return false } }
	return true
}

// The pool has already checked the complete value count. Check the prefix once
// before using typed stores, and copy nonoverlapping constants as one block.
// Aliased constants retain the original reserved-reset/forward-copy ordering.
@[inline]
fn (mut context ExecutionContext) initialize_reused_values(registers u32, constants []Value) bool {
	if constants.len < 0 || context.values.len < 0
		|| u64(registers) + u64(constants.len) > u64(context.values.len) { return false }
	reserved := if registers < reserved_register_count { registers } else { reserved_register_count }
	unsafe {
		mut values := &Value(context.values.data)
		for slot in 0 .. int(reserved) { values[slot] = js_special_empty_value() }
		if constants.len > 0 {
			mut target := &values[registers]
			source := &Value(constants.data)
			bytes := uint(constants.len) * uint(sizeof(Value))
			if uint(source) + bytes <= uint(target) || uint(target) + bytes <= uint(source) {
				vmemcpy(target, source, int(bytes))
			} else {
				for slot in 0 .. constants.len { target[slot] = source[slot] }
			}
		}
	}
	return true
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
		expose_call_environment(frame)
		mut owner := unsafe { &ExecutionContext(frame) }
		if owner.exposed { break }
		owner.exposed = true
		current = owner.caller_frame
	}
}

@[direct_array_access]
fn (mut context ExecutionContext) clear_for_reuse() {
	// The loop is bounded by this array's own length; no user code runs here.
	if use_direct_frame_clears() { context.clear_reused_values() }
	else { for index in 0 .. context.values.len { context.values[index] = js_undefined() } }
	values := context.values
	environment := context.recycle_call_environment()
	unsafe { *context = ExecutionContext{ values: values, reusable: true, cached_call_environment: environment } }
}

fn (mut stack InterpreterStack) allocate_reusable(registers u32, constants []Value, arguments u32) ?&ExecutionContext {
	if !use_context_reuse() { return stack.allocate(registers, constants, arguments) }
	count := u64(registers) + u64(constants.len) + arguments
	size := frame_size_in_bytes(count)
	new_top := stack.top_ + size
	if new_top > stack.limit { return none }
	index := stack.find_recycled_context(count)
	if index >= 0 {
		mut context := stack.recycled[index]
		stack.recycled.delete(index)
		stack.recycled_bytes -= context.recycled_context_bytes()
		// Pool entries start with an exact-sized allocation. Recycling clears
		// the used prefix, and private execution never writes into its spare tail.
		unsafe { context.values.len = int(count) }
		context.argument_count = arguments
		if use_direct_context_initialization() && context.initialize_reused_values(registers, constants) {
			$if test { if context_reuse_diagnostic_for_test { contexts_initialized_directly_for_test++ } }
		} else {
			for slot in 0 .. int(if registers < reserved_register_count {
				registers
			} else {
				reserved_register_count
			}) {
				context.values[slot] = js_special_empty_value()
			}
			for slot, value in constants { context.values[int(registers) + slot] = value }
		}
		context.frame_id = stack.next_frame_id
		stack.next_frame_id++
		context.stack_offset = stack.top_
		context.stack_allocated = true
		push_within_capacity(mut stack.contexts, context)
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

fn (stack &InterpreterStack) find_recycled_context(count u64) int {
	mut best := -1
	// Allow up to 25% spare capacity so small calls leave larger frames available.
	mut best_capacity := count + count / 4 + 1
	for index := stack.recycled.len - 1; index >= 0; index-- {
		capacity := u64(stack.recycled[index].values.cap)
		if capacity == count { return index }
		if capacity > count && capacity < best_capacity {
			best = index
			best_capacity = capacity
		}
	}
	return best
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
	if context.async_execution != none || context.generator_execution != none || context.caller_frame != none {
		return
	}
	size := frame_size_in_bytes(u64(context.values.cap)) + if context.can_recycle_call_environment() { uint(sizeof(FunctionEnvironment)) } else { uint(0) }
	if size > reusable_context_bytes_limit { return }
	// Admit new layouts when the pool is full instead of keeping a permanent
	// set of cold layouts. Every evicted record is already cleared/unexposed.
	for stack.recycled.len >= reusable_context_count_limit
		|| stack.recycled_bytes + size > reusable_context_bytes_limit {
		oldest := stack.recycled[0]
		stack.recycled_bytes -= oldest.recycled_context_bytes()
		stack.recycled.delete(0)
	}
	context.clear_for_reuse()
	push_within_capacity(mut stack.recycled, &context)
	stack.recycled_bytes += size
}
