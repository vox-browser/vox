module html

import platform

struct FrameLog {
mut:
	times []f64
}

fn test_add_returns_incrementing_ids_and_has_callbacks() {
	mut driver := &AnimationFrameCallbackDriver{}
	assert driver.has_callbacks() == false
	id1 := driver.add(fn (now f64) {})
	id2 := driver.add(fn (now f64) {})
	assert id1 == u32(1)
	assert id2 == u32(2)
	assert driver.has_callbacks() == true
}

fn test_remove_reports_presence() {
	mut driver := &AnimationFrameCallbackDriver{}
	id := driver.add(fn (now f64) {})
	assert driver.remove(id) == true
	// Removing again reports false.
	assert driver.remove(id) == false
	assert driver.has_callbacks() == false
}

fn test_run_invokes_all_callbacks_with_now_then_clears() {
	mut driver := &AnimationFrameCallbackDriver{}
	mut log := &FrameLog{}
	driver.add(fn [mut log] (now f64) {
		log.times << now
	})
	driver.add(fn [mut log] (now f64) {
		log.times << now * 2
	})
	driver.run(10.0)
	assert log.times == [10.0, 20.0]
	// The queue is emptied after a run.
	assert driver.has_callbacks() == false

	// A second run with no callbacks does nothing.
	driver.run(99.0)
	assert log.times == [10.0, 20.0]
}

fn test_callback_scheduled_during_run_defers_to_next_frame() {
	mut driver := &AnimationFrameCallbackDriver{}
	mut log := &FrameLog{}
	// The callback re-registers itself; that registration must not run in the same frame.
	driver.add(fn [mut driver, mut log] (now f64) {
		log.times << now
		driver.add(fn [mut log] (later f64) {
			log.times << later
		})
	})
	driver.run(1.0)
	assert log.times == [1.0]
	assert driver.has_callbacks() == true
	driver.run(2.0)
	assert log.times == [1.0, 2.0]
}

fn frame_storage_noop(_ f64) {}

fn test_empty_and_repeated_animation_frames_reuse_callback_storage() {
	mut driver := &AnimationFrameCallbackDriver{}
	for _ in 0 .. 4 {
		driver.add(frame_storage_noop)
		driver.run(1)
	}
	before := platform.thread_arena_usage().used
	for _ in 0 .. 1024 {
		driver.run(2)
		driver.add(frame_storage_noop)
		driver.run(3)
	}
	$if prealloc {
		retained := platform.thread_arena_usage().used - before
		assert retained < 4096, '${retained} retained by repeated animation frames'
	}
	assert !driver.has_callbacks()
	assert driver.executing_callbacks_.len == 0
	assert !driver.running_
}

fn test_reentered_animation_frame_keeps_the_outer_batch_and_new_registrations() {
	mut driver := &AnimationFrameCallbackDriver{}
	mut log := &FrameLog{}
	driver.add(fn [mut driver, mut log] (_ f64) {
		log.times << 1
		driver.add(fn [mut driver, mut log] (_ f64) {
			log.times << 2
			driver.add(fn [mut log] (_ f64) { log.times << 4 })
		})
		driver.run(2)
	})
	driver.add(fn [mut log] (_ f64) { log.times << 3 })
	driver.run(1)
	assert log.times == [f64(1), 2, 3]
	assert driver.has_callbacks()
	driver.run(3)
	assert log.times == [f64(1), 2, 3, 4]
	assert !driver.has_callbacks()
}
