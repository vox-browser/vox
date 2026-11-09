module layout

import css
import dom

fn snapshot_document_scroll_state_queries(_ voidptr, document &dom.Document, new_only bool) bool {
	mut containers := css.scroll_state_query_containers(document)
	if containers.len == 0 { return false }
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.update_paint_and_hit_testing_properties_if_needed()
	mut changed := false
	for mut entry in containers {
		if new_only && entry.has_been_snapshotted { continue }
		element := entry.element
		style := css.computed_properties_for_element(element)
		if !element.as_node().is_connected() || style == none
			|| !(style or { continue }).container_type().is_scroll_state_container {
			if element.as_node().is_connected() {
				changed = css.publish_scroll_state_query_snapshot(mut entry, css.ScrollStateQuerySnapshot{}) || changed
			}
			css.forget_scroll_state_query_container(document, element)
			continue
		}
		mut stuck := u8(0)
		mut snapped := u8(0)
		mut scrollable := u8(0)
		mut scrolled := u8(0)
		if mirror := element.as_node().unsafe_layout_node() {
			if result := document_layout_result(document) {
				if box := result.retained_box_for_layout(mirror.layout_handle) {
					if box.sticky_scroll_frame_index > 0 {
						offset := result.scroll_state_snapshot.device_offset_for_index(box.sticky_scroll_frame_index)
						if offset.y > 0 { stuck |= 1 } else if offset.y < 0 { stuck |= 4 }
						if offset.x > 0 { stuck |= 8 } else if offset.x < 0 { stuck |= 2 }
					}
				}
			}
			mut ancestor := mirror.containing_block_
			for ancestor != none {
				node := ancestor or { break }
				if node.is_scroll_container_ || node.is_viewport_ {
					snap_owner := if node.is_viewport_ { document.document_element() }
						else if owner := node.dom_node_ { owner.as_element() } else { none }
					owner_element := snap_owner or { break }
					owner_style := css.computed_properties_for_element(owner_element) or { break }
					if owner_style.scroll_snap_type().strictness == .none_ { break }
					if node.is_viewport_ {
						id := i64(element.as_node().unique_id())
						if document.viewport_snapped_areas_x().any(it.element_id == id) { snapped |= 1 }
						if document.viewport_snapped_areas_y().any(it.element_id == id) { snapped |= 2 }
					}
					if owner := node.dom_node_ {
						if paintable := owner.unsafe_paintable_box() {
							areas := paintable.snapped_areas()
							id := i64(element.as_node().unique_id())
							if areas.x.any(it.element_id == id) { snapped |= 1 }
							if areas.y.any(it.element_id == id) { snapped |= 2 }
						}
					}
					break
				}
				ancestor = node.containing_block_
			}
		}
		is_root := if root := document.document_element() { voidptr(root) == voidptr(element) } else { false }
		paintable := if is_root { unsafe { &dom.Node(document) }.unsafe_paintable_box() }
			else { element.as_node().unsafe_paintable_box() }
		if box := paintable {
			if box.scrollable || is_root {
				offset := if is_root { dom.CSSPixelPoint_{x_: document.viewport_rect().x, y_: document.viewport_rect().y} } else { box.scroll_offset() }
				minimum := box.minimum_scroll_offset()
				maximum := box.maximum_scroll_offset()
				if box.could_be_scrolled_vertically_by_wheel_event() {
					if offset.y() > minimum.y() { scrollable |= 1 }
					if offset.y() < maximum.y() { scrollable |= 4 }
				}
				if box.could_be_scrolled_horizontally_by_wheel_event() {
					if offset.x() > minimum.x() { scrollable |= 8 }
					if offset.x() < maximum.x() { scrollable |= 2 }
				}
				scrolled = css.relative_scroll_query_direction(element)
			}
		}
		changed = css.publish_scroll_state_query_snapshot(mut entry, css.ScrollStateQuerySnapshot{
			stuck: stuck, snapped: snapped, scrollable: scrollable, scrolled: scrolled
		}) || changed
	}
	return changed
}

fn record_document_relative_scroll(_ voidptr, document &dom.Document, element ?&dom.Element, delta dom.CSSPixelPoint_) {
	css.record_relative_scroll_for_queries(document, element, delta)
}
