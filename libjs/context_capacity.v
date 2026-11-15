module libjs

// Frames have separate heap arrays in this port, with no size-class free list.
// Reserve exactly their fixed layout; extra capacity is never used by execution
// and otherwise increases clearing, allocation and conservative GC scanning.
pub struct ContextAllocationActivity {
pub:
	frames   u64
	slots    u64
	capacity u64
}

$if test {
	__global rounded_context_capacity_for_test bool
	__global context_allocation_diagnostic_for_test bool
	__global context_allocation_frames_for_test u64
	__global context_allocation_slots_for_test u64
	__global context_allocation_capacity_for_test u64
	pub fn set_exact_context_capacity_for_testing(enabled bool) {
		rounded_context_capacity_for_test = !enabled
	}
	pub fn diagnose_context_allocation_for_testing(enabled bool) ContextAllocationActivity {
		previous := ContextAllocationActivity{context_allocation_frames_for_test, context_allocation_slots_for_test, context_allocation_capacity_for_test}
		context_allocation_frames_for_test = 0
		context_allocation_slots_for_test = 0
		context_allocation_capacity_for_test = 0
		context_allocation_diagnostic_for_test = enabled
		return previous
	}
}

fn context_value_capacity(count int) int {
	mut capacity := count
	$if test {
		if rounded_context_capacity_for_test {
			capacity = if count <= 4 {
				4
			} else if count <= 16 {
				16
			} else if count <= 64 {
				64
			} else if count <= 128 {
				128
			} else if count <= 256 {
				256
			} else if count <= 512 {
				512
			} else {
				count
			}
		}
		if context_allocation_diagnostic_for_test {
			context_allocation_frames_for_test++
			context_allocation_slots_for_test += u64(count)
			context_allocation_capacity_for_test += u64(capacity)
		}
	}
	return capacity
}
