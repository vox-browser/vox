module libjs

// Translated from LibJS/Runtime/InterpreterStack.{h,cpp}: a bump allocator for
// execution contexts with an 8 MiB budget. Upstream carves frames out of one
// mmap'd region; here each frame is a heap record and the stack accounts for
// the bytes upstream would have consumed, so exhaustion behaves the same.

pub const interpreter_stack_size = uint(8 * 1024 * 1024)

pub struct InterpreterStack {
mut:
	contexts      []&ExecutionContext
	top_          uint
	limit         uint = interpreter_stack_size
	next_frame_id u64   = 1
}

pub fn InterpreterStack.new() InterpreterStack {
	return InterpreterStack{}
}

// top returns the current allocation mark.
pub fn (stack &InterpreterStack) top() uint {
	return stack.top_
}

pub fn (stack &InterpreterStack) depth() int {
	return stack.contexts.len
}

fn frame_size_in_bytes(tail_count u64) uint {
	alignment := uint(8)
	mut size := uint(sizeof(ExecutionContext)) + uint(tail_count) * uint(sizeof(Value))
	// Align up to alignof(ExecutionContext).
	size = (size + alignment - 1) & ~(alignment - 1)
	return size
}

pub fn (mut stack InterpreterStack) allocate(registers_and_locals_count u32, constants []Value, arguments_count u32) ?&ExecutionContext {
	tail_count := u64(registers_and_locals_count) + u64(constants.len) + u64(arguments_count)
	size := frame_size_in_bytes(tail_count)
	new_top := stack.top_ + size
	if new_top > stack.limit {
		return none
	}
	mut context := ExecutionContext.create(registers_and_locals_count, constants, arguments_count)
	context.frame_id = stack.next_frame_id
	stack.next_frame_id++
	context.stack_offset = stack.top_
	context.stack_allocated = true
	stack.contexts << context
	stack.top_ = new_top
	return context
}

// deallocate releases every frame allocated at or above the mark.
pub fn (mut stack InterpreterStack) deallocate(mark uint) {
	if mark > stack.top_ {
		panic('InterpreterStack.deallocate: mark ${mark} is above the top ${stack.top_}')
	}
	for stack.contexts.len > 0 && stack.contexts.last().stack_offset >= mark {
		mut released := stack.contexts.pop()
		released.stack_allocated = false
	}
	stack.top_ = mark
}

pub fn (mut stack InterpreterStack) deallocate_context(context &ExecutionContext) {
	if !context.stack_allocated {
		panic('InterpreterStack.deallocate_context: frame is not on the interpreter stack')
	}
	stack.deallocate(context.stack_offset)
}

pub fn (stack &InterpreterStack) is_exhausted() bool {
	return stack.top_ >= stack.limit
}

pub fn (stack &InterpreterStack) size_remaining() uint {
	return stack.limit - stack.top_
}
