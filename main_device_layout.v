module main

import dom
import html
import os

fn browser_document_supports_device_layout(document &dom.Document) bool {
	return document.as_node().for_each_in_inclusive_subtree(fn (node &dom.Node) dom.TraversalDecision {
		if element := node.as_element() {
			if !element.is_html_element() || element.local_name() in ['iframe', 'object', 'embed',
				'canvas', 'video', 'audio'] {
				return .@break
			}
		}
		return .@continue
	}) != .@break
}

// Native Chromium windows use display density for layout as well as raster.
// Screenshot emulation retains its CSS-pixel layout unless explicitly asked
// to exercise the native display path.
fn browser_layout_coordinate_scale(document &dom.Document) f64 {
	$if macos {
		if os.getenv('LADYBIRD_SCREENSHOT_DELAY_SECONDS') != ''
			&& os.getenv('VOX_SCREENSHOT_NATIVE_LAYOUT') != '1' {
			return 1
		}
		// Embedded browsing contexts and SVG/MathML user-space layout still
		// consume CSS-pixel geometry. Keep that path until it is converted too.
		if browser_document_supports_device_layout(document) {
			return C.native_display_device_pixel_ratio()
		}
	}
	return 1
}

fn (mut app BrowserApp) sync_layout_coordinate_scale() {
	if app.document == unsafe { nil } || app.layout_tree_only { return }
	app.document.set_display_device_pixel_ratio(html.display_device_pixel_ratio())
	app.document.set_layout_coordinate_scale(browser_layout_coordinate_scale(app.document))
}
