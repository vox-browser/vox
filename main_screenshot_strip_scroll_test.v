module main

// capture_screenshot.sh captures a viewport taller than the window in strips,
// each scrolled to its offset within that viewport. A document whose content is
// shorter than the viewport, such as one laid out only with absolutely
// positioned rows, must still scroll to the strip's offset.
fn test_screenshot_strips_scroll_to_their_offset_past_short_content() {
	mut app := BrowserApp{
		content_height:             0
		viewport_height:            768
		screenshot_viewport_height: 768
		screenshot_scroll_y:        192
	}
	window_height := 576 + app.chrome_height()
	assert app.maximum_scroll(window_height) == 192
	app.set_scroll_y(192, window_height)
	assert app.scroll_y == 192
	// Relayout clamps against the full screenshot viewport, which the document
	// fits in, without undoing the strip's offset.
	app.set_scroll_y(app.scroll_y, app.viewport_height + app.chrome_height())
	assert app.scroll_y == 192
	// Ordinary browsing keeps the document's own range.
	mut browsing := BrowserApp{
		content_height:  100
		viewport_height: 768
	}
	assert browsing.maximum_scroll(576 + browsing.chrome_height()) == 0
}
