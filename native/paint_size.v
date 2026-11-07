module main

import gg

fn sync_native_browser_paint_size(mut context gg.Context, size gg.Size) {
	$if macos {
		if context.native_rendering && size.width > 0 && size.height > 0 {
			// Sokol reports its parent view's size. Cocoa paints into a child
			// whose bounds can differ after AppKit constrains a tall window.
			// Every native Y conversion must use that actual drawing surface.
			context.width = size.width
			context.height = size.height
		}
	}
}
