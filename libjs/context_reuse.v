module libjs

import os

// Only private synchronous-call allocations enter this pool. Public frame and
// value-view APIs mark their frames exposed, preserving their existing lifetime.
const reusable_context_count_limit = 64
const reusable_context_bytes_limit = uint(1024 * 1024)

// call_body() frames are parked by body: a direct-mapped table of one cleared
// frame per slot, keyed by the executable. A same-body hit needs no pool scan
// and finds the body's constants still in place.
const parked_frame_slots = 256
const parked_frame_bytes_limit = uint(64 * 1024)

// Same-binary control: every frame goes through the general pool.
const pooled_frames_only = os.getenv('VOX_LIBJS_POOLED_FRAMES_ONLY') != ''

@[inline]
fn use_parked_frames() bool {
	$if test { if parked_frames_disabled_for_test { return false } }
	return !pooled_frames_only && use_context_reuse()
}

@[heap]
struct ParkedFrames {
mut:
	frames [parked_frame_slots]voidptr
	owners [parked_frame_slots]voidptr
}

@[inline]
fn parked_frame_slot(executable voidptr) int {
	key := u64(executable)
	return int(((key >> 4) ^ (key >> 12)) & u64(parked_frame_slots - 1))
}

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
	__global parked_frames_disabled_for_test bool
	__global parked_frame_hits_for_test u64
	pub fn set_parked_frames_for_testing(enabled bool) { parked_frames_disabled_for_test = !enabled }
	pub fn parked_frame_hits_for_testing() u64 {
		hits := parked_frame_hits_for_test
		parked_frame_hits_for_test = 0
		return hits
	}
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
		if constants.len > 0 && !context.held.holds(constants, registers, context.values.data) {
			context.release_held_constants()
			context.held = HeldConstants{
				constants: constants.data
				start:     registers
				count:     u32(constants.len)
				storage:   context.values.data
			}
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

// Constant operands are never written (Operand.slot() rejects them as
// destinations), and the executable keeps its constants alive, so a pooled
// frame may keep them in place for its next call of the same body.
struct HeldConstants {
	constants voidptr
	start     u32
	count     u32
	storage   voidptr
}

@[inline]
fn (held HeldConstants) holds(constants []Value, start u32, storage voidptr) bool {
	return held.constants == constants.data && held.start == start && held.count == u32(constants.len)
		&& held.storage == storage
}

// A frame reused by another body (or without constants) must not show the
// previous body's constants in its registers or arguments.
fn (mut context ExecutionContext) release_held_constants() {
	held := context.held
	if held.count != 0 && held.storage == context.values.data
		&& u64(held.start) + u64(held.count) <= u64(context.values.cap) {
		values := unsafe { &Value(context.values.data) }
		for index in held.start .. held.start + held.count {
			unsafe { values[index] = js_undefined() }
		}
	}
	context.held = HeldConstants{}
}

@[direct_array_access]
fn (mut context ExecutionContext) clear_for_reuse() {
	// The loop is bounded by this array's own length; no user code runs here.
	mut held := context.held
	if held.storage != context.values.data || u64(held.start) + u64(held.count) > u64(context.values.len) {
		held = HeldConstants{}
	}
	if use_direct_frame_clears() {
		context.clear_reused_values_around(held)
	} else {
		for index in 0 .. context.values.len { context.values[index] = js_undefined() }
		held = HeldConstants{}
	}
	values := context.values
	environment := context.recycle_call_environment()
	unsafe { *context = ExecutionContext{ values: values, reusable: true, cached_call_environment: environment, held: held } }
}

fn (mut stack InterpreterStack) allocate_reusable(registers u32, constants []Value, arguments u32) ?&ExecutionContext {
	if !use_context_reuse() { return stack.allocate(registers, constants, arguments) }
	count := u64(registers) + u64(constants.len) + arguments
	size := frame_size_in_bytes(count)
	new_top := stack.top_ + size
	if new_top > stack.limit { return none }
	index := stack.find_recycled_context(count)
	if index >= 0 {
		// The newest record is the usual match; take it without array.delete().
		mut context := if index == stack.recycled.len - 1 {
			pop_last(mut stack.recycled, 'empty context pool')
		} else {
			taken := stack.recycled[index]
			stack.recycled.delete(index)
			taken
		}
		stack.recycled_bytes -= context.recycled_context_bytes()
		unsafe { context.values.len = int(count) }
		context.argument_count = arguments
		if constants.len == 0 { context.release_held_constants() }
		if use_direct_context_initialization() && context.initialize_reused_values(registers, constants) {
			$if test { if context_reuse_diagnostic_for_test { contexts_initialized_directly_for_test++ } }
		} else {
			context.release_held_constants()
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

// call_body()'s frame: the body's parked frame when it fits, else the pool.
// Calling the same functions again and again is the common case, and a pool
// holding many layouts made every call scan it for a fit.
fn (mut stack InterpreterStack) allocate_body_frame(executable &Executable, arguments u32) ?&ExecutionContext {
	registers := executable.registers_and_locals_count
	if use_parked_frames() && stack.parked != unsafe { nil } {
		mut parked := stack.parked
		parked_slot := parked_frame_slot(executable)
		if parked.owners[parked_slot] == voidptr(executable) {
			mut context := unsafe { &ExecutionContext(parked.frames[parked_slot]) }
			count := u64(registers) + u64(executable.constants.len) + arguments
			capacity := u64(context.values.cap)
			new_top := stack.top_ + frame_size_in_bytes(count)
			// The pool's best-fit bound: at most a quarter spare.
			if capacity >= count && capacity < count + count / 4 + 1 && new_top <= stack.limit {
				parked.frames[parked_slot] = unsafe { nil }
				parked.owners[parked_slot] = unsafe { nil }
				$if test { parked_frame_hits_for_test++ }
				// allocate_reusable()'s reuse of a cleared record. The body's
				// constants are normally still held in place from its last call.
				constants := executable.constants
				unsafe { context.values.len = int(count) }
				context.argument_count = arguments
				if constants.len == 0 { context.release_held_constants() }
				if use_direct_context_initialization() && context.initialize_reused_values(registers, constants) {
					$if test { if context_reuse_diagnostic_for_test { contexts_initialized_directly_for_test++ } }
				} else {
					context.release_held_constants()
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
		}
	}
	return stack.allocate_reusable(registers, executable.constants, arguments)
}

@[direct_array_access]
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
	if use_parked_frames() && size <= parked_frame_bytes_limit && stack.parked != unsafe { nil } {
		if owner := context.executable {
			// Park it for the body's next call; a different body's frame in
			// the slot moves to the pool.
			mut parked := stack.parked
			slot := parked_frame_slot(owner)
			displaced := parked.frames[slot]
			context.clear_for_reuse()
			parked.frames[slot] = voidptr(&context)
			parked.owners[slot] = voidptr(owner)
			if displaced != unsafe { nil } {
				mut previous := unsafe { &ExecutionContext(displaced) }
				stack.pool_cleared_context(mut previous, previous.recycled_context_bytes())
			}
			return
		}
	}
	// pool_cleared_context(), kept inline on the pool's path.
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

// Admit new layouts when the pool is full instead of keeping a permanent set
// of cold layouts. Every evicted record is already cleared/unexposed.
fn (mut stack InterpreterStack) pool_cleared_context(mut context ExecutionContext, size uint) {
	for stack.recycled.len >= reusable_context_count_limit
		|| stack.recycled_bytes + size > reusable_context_bytes_limit {
		oldest := stack.recycled[0]
		stack.recycled_bytes -= oldest.recycled_context_bytes()
		stack.recycled.delete(0)
	}
	push_within_capacity(mut stack.recycled, &context)
	stack.recycled_bytes += size
}

// The parked frames (allocate_body_frame()), for root walks.
fn (stack &InterpreterStack) parked_contexts() []&ExecutionContext {
	mut contexts := []&ExecutionContext{}
	if stack.parked == unsafe { nil } { return contexts }
	for slot in 0 .. parked_frame_slots {
		frame := stack.parked.frames[slot]
		if frame != unsafe { nil } { contexts << unsafe { &ExecutionContext(frame) } }
	}
	return contexts
}
