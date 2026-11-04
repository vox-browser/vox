module main

import dom
import html

fn browser_document_supports_device_layout(document &dom.Document) bool {
	root := document.as_node()
	mut current := root.first_child()
	mut hidden_by_element := map[u64]bool{}
	for {
		node := current or { break }
		if element := node.as_element() {
			svg_user_space := !retain_css_layout_for_svg && element.is_svg_element()
				&& element.local_name() != 'foreignObject'
			if (!element.is_html_element() && !svg_user_space)
				|| element.local_name() in ['iframe', 'object', 'embed', 'canvas', 'video', 'audio',
				'foreignObject'] {
				// display:none subtrees consume no layout coordinates. In particular,
				// cosmetic filtering of an ad frame must not reduce the precision
				// of text elsewhere in the document. Resolve current ancestor styles
				// just as the preload planner does, including live display changes.
				if !preload_element_has_no_display_box(element, mut hidden_by_element) {
					if retain_css_layout_for_svg && element.is_svg_element() {
						report_archived_svg_layout(document)
					}
					return false
				}
			}
		}
		current = node.next_in_pre_order(root)
	}
	return true
}

// Display density is also the screenshot's requested raster scale (1 by
// default). Both captures and windows use that density for eligible layout.
fn browser_layout_coordinate_scale(document &dom.Document) f64 {
	$if macos {
		// SVG descendants retain user units inside their scaled viewport.
		// Embedded documents, foreignObject and MathML retain CSS-pixel layout.
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
