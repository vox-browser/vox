module platform

#include "@DIR/native_event_fairness_test.h"

fn C.vox_fairness_create() voidptr
fn C.vox_fairness_delivered(voidptr) i32
fn C.vox_fairness_destroy(voidptr)

fn test_native_pump_drains_a_ready_completion_chain_within_its_time_budget() {
	$if !macos { return }
	state := C.vox_fairness_create()
	defer { C.vox_fairness_destroy(state) }
	pump_native_events(0.005)
	assert C.vox_fairness_delivered(state) == 5
}
