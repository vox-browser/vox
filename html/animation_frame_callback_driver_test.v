module html

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
