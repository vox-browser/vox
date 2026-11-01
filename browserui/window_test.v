module browserui

fn test_window_geometry_and_detach_keep_windows_visible_on_the_selected_display() {
	screens := [Frame{ x: -1200, width: 1200, height: 900 }, Frame{ width: 1920, height: 1080 }]
	frame := visible_frame(Frame{ x: -1500, y: -40, width: 800, height: 600 }, screens, 1, 100, 100, false)
	assert frame.x == -1200 && frame.y == 0
	test_frame := visible_frame(Frame{ width: 800, height: 600 }, screens, 0, 100, 100, true)
	assert test_frame.x == -800 && test_frame.y == 300
	detached := detached_frame(10, 1050, 800, 600, screens)
	assert detached.x == 0 && detached.y == 480
	assert !Frame{ width: 99, height: 600 }.valid()
}

fn test_window_state_preserves_normal_geometry_through_zoom_and_fullscreen() {
	mut state := WindowState{ normal: Frame{ width: 800, height: 600 } }
	assert state.update(0, Frame{ width: 1200, height: 900 }, true, false)
	assert state.maximized && state.normal.width == 800
	assert state.update(1, Frame{ width: 1200, height: 900 }, true, false)
	assert state.transitioning
	assert !state.update(0, Frame{ width: 1920, height: 1080 }, false, false)
	assert state.update(2, Frame{ width: 1920, height: 1080 }, false, false)
	assert state.fullscreen && state.normal.width == 800
	assert !state.update(3, Frame{}, false, false)
	assert state.update(4, Frame{ width: 800, height: 600 }, false, false)
	assert !state.fullscreen
	assert state.update(0, Frame{}, false, true)
	assert state.normal.width == 800
}

fn test_titlebar_double_click_policy_uses_time_and_position() {
	mut clicks := WindowClicks{}
	assert !clicks.press(1_000_000_000, 200, 10)
	assert clicks.press(1_200_000_000, 202, 11)
	assert !clicks.press(1_300_000_000, 202, 11)
	assert !clicks.press(1_400_000_000, 250, 11)
	assert !clicks.press(2_000_000_000, 250, 11)
}
