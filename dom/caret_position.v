module dom

// https://drafts.csswg.org/cssom-view/#caretposition
@[heap]
pub struct CaretPosition {
	offset_node_ &Node
	offset_      u32
	client_rect_ ?DOMRect
}

pub fn CaretPosition.create(offset_node &Node, offset u32,
	client_rect ?CSSPixelRect_) &CaretPosition {
	return &CaretPosition{
		offset_node_: offset_node
		offset_: offset
		client_rect_: if rect := client_rect {
			DOMRect.construct_impl(rect.x_, rect.y_, rect.width_, rect.height_)
		} else {
			none
		}
	}
}

pub fn (position &CaretPosition) offset_node() &Node {
	return position.offset_node_
}

pub fn (position &CaretPosition) offset() u32 {
	return position.offset_
}

pub fn (position &CaretPosition) get_client_rect() ?DOMRect {
	return position.client_rect_
}

pub struct CaretPositionFromPointOptions {
pub:
	shadow_roots []&ShadowRoot
}

fn shadow_root_is_allowed_for_caret_position(shadow_root &ShadowRoot,
	options CaretPositionFromPointOptions) bool {
	root_node := unsafe { &Node(shadow_root) }
	for allowed_shadow_root in options.shadow_roots {
		allowed_node := unsafe { &Node(allowed_shadow_root) }
		if root_node.is_shadow_including_inclusive_ancestor_of(allowed_node) {
			return true
		}
	}
	return false
}

// https://drafts.csswg.org/cssom-view/#dom-document-caretpositionfrompoint
pub fn (mut d Document) caret_position_from_point(x f64, y f64,
	options_list ...CaretPositionFromPointOptions) ?&CaretPosition {
	viewport := d.viewport_rect()
	if x < 0 || y < 0 || x > viewport.width || y > viewport.height {
		return none
	}

	d.update_layout(.document_caret_position_from_point)
	paintable := d.paintable_box() or { return none }
	hit := paintable.hit_test(x, y, .text_cursor) or { return none }
	if hit.node == unsafe { nil } {
		return none
	}

	options := if options_list.len > 0 {
		options_list[0]
	} else {
		CaretPositionFromPointOptions{}
	}
	mut start_node := hit.node
	mut start_offset := hit.index_in_node
	mut root := start_node.root()
	for {
		shadow_root := root.as_shadow_root() or { break }
		if shadow_root_is_allowed_for_caret_position(shadow_root, options) {
			break
		}
		host := shadow_root.host() or { return none }
		host_parent := host.as_node().parent() or { return none }
		start_offset = host.as_node().index()
		start_node = host_parent
		root = start_node.root()
	}

	return CaretPosition.create(start_node, u32(start_offset), hit.caret_rect)
}
