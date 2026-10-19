module http

fn test_h2_reader_wake_consumes_signal_once_and_retains_descriptors_until_wait_finishes() {
	$if windows { return }
	wake := C.vox_h2_wake_create()
	assert wake != unsafe { nil }
	assert C.vox_h2_wake_wait(C.vox_h2_wake_retain(wake), -1, 0) == 0
	// The writer never blocks, including when its wake pipe is full.
	for _ in 0 .. 100000 { C.vox_h2_wake_signal(wake) }
	assert C.vox_h2_wake_wait(C.vox_h2_wake_retain(wake), -1, 0) > 0
	assert C.vox_h2_wake_wait(C.vox_h2_wake_retain(wake), -1, 0) == 0
	retained := C.vox_h2_wake_retain(wake)
	C.vox_h2_wake_close(wake)
	// A closed reader must observe a negative result with current V's int ABI.
	assert C.vox_h2_wake_wait(retained, -1, 0) == -2
}
