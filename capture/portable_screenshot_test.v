module main

fn test_portable_screenshot_waits_until_its_deadline() {
	mut state := PortableScreenshotState{}
	assert state.ready_path(100) == none
	state.schedule('capture.png', 100, 20)
	assert state.ready_path(119) == none
	assert state.ready_path(120) or { panic('capture was not ready at its deadline') } == 'capture.png'
	assert state.ready_path(121) or { panic('capture stopped being ready') } == 'capture.png'
}

fn test_portable_screenshot_replacement_updates_path_and_deadline() {
	mut state := PortableScreenshotState{}
	state.schedule('first.png', 100, 20)
	state.schedule('replacement.png', 110, 30)
	assert state.ready_path(120) == none
	assert state.ready_path(139) == none
	assert state.ready_path(140) or { panic('replacement capture was not ready') } == 'replacement.png'
}

fn test_portable_screenshot_empty_path_cancels_only_its_owner() {
	mut first := PortableScreenshotState{}
	mut second := PortableScreenshotState{}
	first.schedule('first.png', 100, 10)
	second.schedule('second.png', 100, 20)
	assert first.ready_path(110) or { panic('first capture was not ready') } == 'first.png'
	assert second.ready_path(110) == none
	first.schedule('', 115, 0)
	assert first.ready_path(200) == none
	assert second.ready_path(120) or { panic('other capture was cancelled') } == 'second.png'
}

fn test_portable_screenshot_nonpositive_delays_are_immediately_ready() {
	mut state := PortableScreenshotState{}
	state.schedule('immediate.png', 100, 0)
	assert state.ready_path(100) or { panic('zero-delay capture was not ready') } == 'immediate.png'
	state.schedule('elapsed.png', 100, -20)
	assert state.ready_path(100) or { panic('elapsed capture was not ready') } == 'elapsed.png'
}
