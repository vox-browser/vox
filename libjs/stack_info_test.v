module libjs

fn stack_info_measure_thread_snapshot(original StackInfo) (uint, uint, uint) {
	actual := StackInfo.new()
	return original.size_free(), actual.size_free(), actual.size
}

fn test_source_stack_info_uses_actual_frame_even_for_another_thread_stack_snapshot() {
	info := StackInfo.new()
	stack_worker := spawn stack_info_measure_thread_snapshot(info)
	from_original, from_current, current_size := stack_worker.wait()
	// Source size_free is raw unsigned frame-address subtraction. It does not
	// turn an out-of-range frame into zero by consulting top/size metadata.
	assert from_original > 0
	assert from_current > 0 && from_current < current_size
	assert info.top == info.base + info.size
}
