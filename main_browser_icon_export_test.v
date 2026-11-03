module main

import os
import platform

fn test_repeated_bookmark_icon_exports_do_not_retain_decoding_work() {
	mut app := BrowserApp{}
	address := 'https://old.reddit.com/'
	path := app.browser_bookmark_icon_path(address, 901)
	assert path != '' && os.is_file(path)
	before := platform.thread_arena_usage().used
	for _ in 0 .. 1024 {
		assert app.browser_bookmark_icon_path(address, 901) == path
	}
	$if prealloc {
		allocated := platform.thread_arena_usage().used - before
		assert allocated < 1024, 'bookmark icon export retained ${allocated} bytes'
	}
	assert app.browser_bookmark_icon_path(address, -1) == ''
}

fn test_first_exported_icon_path_survives_its_callers_arena() {
	mut app := BrowserApp{}
	mut caller := platform.new_arena('bookmark icon export caller')
	entry := caller.enter()
	path := app.browser_bookmark_icon_path('https://en.wikipedia.org/', 902)
	owned := !caller.contains(path.str)
	caller.leave(entry)
	caller.release()
	assert owned
	assert path != ''
	assert os.is_file(path)
	bitmap := browser_decode_raster_image_bytes(os.read_bytes(path)!)!
	assert bitmap.width > 0 && bitmap.height > 0
	assert app.browser_bookmark_icon_path('https://en.wikipedia.org/', 902) == path
}
