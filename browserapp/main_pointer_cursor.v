module main

import css
import dom
import painting
import sokol.sapp

// EventHandler::update_cursor() gives resize chrome precedence, then resolves
// the hit element's inherited CSS cursor. In particular, the UA :link rule
// supplies pointer even when hit testing lands on a nested label or text node.
fn browser_mouse_cursor_for_hit(hit ?dom.HitTestResult, resize ?painting.ResizeCursor) sapp.MouseCursor {
	if resize != none { return mouse_cursor_for_resize_handle(resize) }
	value := hit or { return .arrow }
	mut element := value.element
	if element == unsafe { nil } && value.node != unsafe { nil } {
		element = value.node.as_element() or {
			value.node.parent_element() or { return .arrow }
		}
	}
	if element == unsafe { nil } { return .arrow }
	computed := css.computed_properties_for_element(element) or { return .arrow }
	auto_cursor := if element.as_node().is_editable_or_editing_host()
		|| (value.node != unsafe { nil } && value.node.is_text() && computed.user_select() != .none_) {
		sapp.MouseCursor.ibeam
	} else {
		sapp.MouseCursor.arrow
	}
	// Custom cursor images retain their terminal keyword as the native fallback.
	cursors := computed.cursor()
	return browser_mouse_cursor_for_keyword(cursors.last().keyword, auto_cursor)
}

fn browser_mouse_cursor_for_keyword(keyword string, auto_cursor sapp.MouseCursor) sapp.MouseCursor {
	return match keyword {
		'auto' { auto_cursor }
		'pointer' { .pointing_hand }
		'text', 'vertical-text' { .ibeam }
		'crosshair', 'cell' { .crosshair }
		'move', 'all-scroll' { .resize_all }
		'col-resize', 'e-resize', 'w-resize', 'ew-resize' { .resize_ew }
		'row-resize', 'n-resize', 's-resize', 'ns-resize' { .resize_ns }
		'ne-resize', 'sw-resize', 'nesw-resize' { .resize_nesw }
		'nw-resize', 'se-resize', 'nwse-resize' { .resize_nwse }
		'not-allowed', 'no-drop' { .not_allowed }
		else { .arrow }
	}
}
