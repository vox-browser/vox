module main

import dom
import layout
import page
import painting

struct BrowserDocumentPointerHit {
	document &dom.Document
	position page.PixelPoint
	hit      ?dom.HitTestResult
}

// CSSOM hit testing stops at the container. Platform pointer input enters the
// active child instead, preserving that child's client-coordinate space.
fn browser_document_pointer_hit(document &dom.Document, position page.PixelPoint) BrowserDocumentPointerHit {
	mut current := document
	mut point := position
	mut visited := []voidptr{}
	for {
		visited << voidptr(current)
		viewport := current.paintable_box() or {
			return BrowserDocumentPointerHit{ document: current, position: point }
		}
		hit := viewport.hit_test(point.x, point.y, .exact)
		result := BrowserDocumentPointerHit{ document: current, position: point, hit: hit }
		value := hit or { return result }
		if value.chrome_widget_id != '' || value.element == unsafe { nil } { return result }
		element := value.element
		if !element.is_html_element() || element.local_name() !in ['iframe', 'frame', 'object'] {
			return result
		}
		navigable := element.as_node().content_navigable() or { return result }
		mut child := unsafe { &dom.Document(navigable.active_document() or { return result }) }
		if !child.is_fully_active() || voidptr(child) in visited { return result }
		local := layout.navigable_container_pointer_position(element, painting.Point{point.x, point.y}) or { return result }
		child.update_layout(.event_handler_handle_mouse_move)
		if child.paintable_box() == none { return result }
		current = child
		point = page.PixelPoint{local.x, local.y}
	}
}
