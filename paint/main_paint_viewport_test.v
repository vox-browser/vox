module main

import browserbookmarks

fn test_paint_replay_uses_the_frame_viewport_then_observes_new_chrome_geometry() {
	mut app := BrowserApp{bookmarks: &browserbookmarks.Store{}}
	first_frame := app.page_top()
	assert first_frame == 60
	app.bookmarks.visible = true
	assert app.page_top() == 88
	// A frame's existing commands and clips keep the origin selected by its
	// caller, even if a callback changes bookmark visibility during replay.
	assert app.paint_replay_viewport_top(first_frame) == first_frame
	next_frame := app.page_top()
	assert app.paint_replay_viewport_top(next_frame) == 88
	app.chrome_debug = true
	assert app.page_top() == 120
	assert app.paint_replay_viewport_top(next_frame) == 88
	assert app.paint_replay_viewport_top(app.page_top()) == 120
}
