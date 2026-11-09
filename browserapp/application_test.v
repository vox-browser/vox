module main

import platform

fn test_application_coalesces_filter_cleanup_and_stops_it_on_close() {
	mut application := new_app()
	defer { application.close() }
	assert application.filter_cleanup_timer == none
	application.arm_filter_memory_cleanup()
	timer := application.filter_cleanup_timer or { panic('missing filter cleanup timer') }
	assert timer.is_active()
	assert timer.has_activity_root()
	assert timer.interval() == 1000
	assert !timer.is_single_shot()
	application.arm_filter_memory_cleanup()
	assert voidptr(application.filter_cleanup_timer?) == voidptr(timer)
	application.portable_screenshot.schedule('pending.png', 10, 5)

	application.close()
	assert application.closed
	assert application.filter_cleanup_timer == none
	assert !timer.is_active()
	assert !timer.has_activity_root()
	assert application.portable_screenshot.ready_path(15) == none
	// Repeated teardown and late frame callbacks cannot restart app services.
	application.close()
	application.arm_filter_memory_cleanup()
	application.schedule_native_screenshot('after-close.png')
	assert application.filter_cleanup_timer == none
	assert application.portable_screenshot.pending == none
}

fn test_standalone_browsers_have_independent_application_services() {
	mut first := BrowserApp{}
	mut second := BrowserApp{}
	defer {
		first.application.close()
		second.application.close()
	}
	assert voidptr(first.application) != voidptr(second.application)
	first.application.arm_filter_memory_cleanup()
	second.application.arm_filter_memory_cleanup()
	first_timer := first.application.filter_cleanup_timer or { panic('missing first timer') }
	second_timer := second.application.filter_cleanup_timer or { panic('missing second timer') }
	assert voidptr(first_timer) != voidptr(second_timer)
	first.application.portable_screenshot.schedule('first.png', 10, 5)
	second.application.portable_screenshot.schedule('second.png', 20, 5)
	assert first.application.portable_screenshot.ready_path(15)? == 'first.png'
	assert second.application.portable_screenshot.ready_path(15) == none

	first.application.close()
	assert !first_timer.is_active()
	assert second_timer.is_active()
	assert !second.application.closed
	assert second.application.portable_screenshot.ready_path(25)? == 'second.png'
}

fn test_application_and_filter_timer_outlive_the_creating_scratch_arena() {
	$if !prealloc {
		return
	}
	mut scratch := platform.new_arena('application service ownership')
	defer { scratch.release() }
	entry := scratch.enter()
	mut application := new_app()
	application.arm_filter_memory_cleanup()
	timer := application.filter_cleanup_timer or { panic('missing persistent timer') }
	scratch.leave(entry)
	defer { application.close() }
	assert !scratch.contains(voidptr(application))
	assert !scratch.contains(voidptr(timer))
	scratch.reset()
	assert timer.is_active()
	assert timer.interval() == 1000
	application.close()
	assert !timer.is_active()
	assert !timer.has_activity_root()
}
