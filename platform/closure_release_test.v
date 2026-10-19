module platform

#include "@DIR/closure_release_test.h"

$if gcboehm ? {
	fn C.vox_closure_release_watch(owner voidptr)
	fn C.vox_closure_release_run_worker(work fn ())
	fn C.vox_closure_release_owner_alive() u32
}

@[heap]
struct ClosureReleaseCapture {
	bytes []u8
}

fn closure_release_call(callback fn (int) int) int {
	return callback(1)
}

fn closure_release_capture() &ClosureReleaseCapture {
	capture := &ClosureReleaseCapture{
		bytes: []u8{len: 4096}
	}
	$if gcboehm ? {
		C.vox_closure_release_watch(voidptr(capture))
	}
	return capture
}

fn closure_release_kept() {
	capture := closure_release_capture()
	assert closure_release_call(fn [capture] (value int) int {
		return value + capture.bytes.len
	}) == 4097
}

fn closure_release_released() {
	capture := closure_release_capture()
	callback := fn [capture] (value int) int {
		return value + capture.bytes.len
	}
	assert closure_release_call(callback) == 4097
	release_closure(voidptr(callback))
	// Releasing it again, or releasing a plain function, changes nothing.
	release_closure(voidptr(callback))
	release_closure(voidptr(closure_release_call))
	assert closure_release_call(fn (value int) int {
		return value + 1
	}) == 2
}

// A closure passed to another function keeps its capture after the call
// returns; releasing it frees the capture.
fn test_released_closure_frees_its_capture() {
	$if gcboehm ? {
		C.vox_closure_release_run_worker(closure_release_kept)
		assert C.vox_closure_release_owner_alive() == 1
		C.vox_closure_release_run_worker(closure_release_released)
		assert C.vox_closure_release_owner_alive() == 0
	} $else {
		closure_release_kept()
		closure_release_released()
	}
}
