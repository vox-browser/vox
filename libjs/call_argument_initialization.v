module libjs

$if test {
	__global direct_call_arguments_disabled bool
	__global directly_copied_argument_values u64
	pub fn set_direct_call_arguments_for_testing(enabled bool) { direct_call_arguments_disabled = !enabled }
}

fn use_direct_call_arguments() bool {
	$if test { if direct_call_arguments_disabled { return false } }
	return true
}

fn (mut context ExecutionContext) copy_call_arguments(arguments []Value) {
	if use_direct_call_arguments() && context.initialize_call_arguments(arguments) {
		$if test {
			if context_reuse_diagnostic_for_test { directly_copied_argument_values += u64(arguments.len) }
		}
		return
	}
	for index, argument in arguments { context.set_argument(u32(index), argument) }
}

// Private call setup copies before executing author code. Preserve partial
// copies, untouched slots and the old forward-copy semantics for overlapping
// inputs. Invalid layouts return to the original checked setters.
@[inline]
fn (mut context ExecutionContext) initialize_call_arguments(arguments []Value) bool {
	if arguments.len < 0 || context.values.len < 0
		|| u64(context.argument_count) > u64(context.values.len)
		|| u64(arguments.len) > u64(context.argument_count) { return false }
	if arguments.len == 0 { return true }
	unsafe {
		mut target := &(&Value(context.values.data))[context.values.len - int(context.argument_count)]
		source := &Value(arguments.data)
		bytes := uint(arguments.len) * uint(sizeof(Value))
		if arguments.len <= 4 {
			for index in 0 .. arguments.len { target[index] = source[index] }
		} else if uint(source) + bytes <= uint(target) || uint(target) + bytes <= uint(source) {
			vmemcpy(target, source, int(bytes))
		} else {
			for index in 0 .. arguments.len { target[index] = source[index] }
		}
	}
	return true
}
