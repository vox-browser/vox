// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Editing-host caret fallbacks introduced by the committed-layout EventHandler.
module page

import css
import dom

pub struct CaretPosition {
pub:
	boundary               dom.BoundaryPoint
	secondary_boundary     ?dom.BoundaryPoint
	layout_node            &dom.LayoutNode = unsafe { nil }
	user_select_used_value css.UserSelect = .auto_
}

fn node_has_committed_box(node &dom.Node) bool {
	layout_node := node.layout_node() or { return false }
	return layout_node.paintables().len > 0
}

fn node_committed_rect(node &dom.Node) ?dom.Rect {
	layout_node := node.layout_node() or { return none }
	if layout_node.paintables().len == 0 {
		return none
	}
	return layout_node.border_box_
}

fn rects_intersect(first dom.Rect, second dom.Rect) bool {
	return first.x < second.x + second.width && second.x < first.x + first.width
		&& first.y < second.y + second.height && second.y < first.y + first.height
}

fn node_is_focusable(node &dom.Node) bool {
	element := node.as_element() or { return false }
	return element.is_focusable()
}

fn collect_editing_hosts(root &dom.Node, mut hosts []&dom.Node) {
	if root.is_editing_host() {
		hosts << root
		if hosts.len > 1 {
			return
		}
	}
	for child in root.children_as_vector() {
		collect_editing_hosts(child, mut hosts)
		if hosts.len > 1 {
			return
		}
	}
}

pub fn associated_descendant_editing_host(node &dom.Node) ?&dom.Node {
	if node.is_editing_host() {
		return node
	}
	if node.is_editable() {
		editing_host := node.editing_host() or { return none }
		return if editing_host.is_editing_host() { editing_host } else { none }
	}

	hit_node_rect := node_committed_rect(node)
	mut ancestor := ?&dom.Node(node)
	for ancestor != none {
		current := ancestor or { break }
		mut editing_hosts := []&dom.Node{}
		collect_editing_hosts(current, mut editing_hosts)

		if editing_hosts.len == 1 {
			host := editing_hosts[0]
			if voidptr(current) == voidptr(node) {
				return host
			}
			if hit_rect := hit_node_rect {
				if host_rect := node_committed_rect(host) {
					if rects_intersect(hit_rect, host_rect) {
						return host
					}
				}
			}
		}
		if voidptr(current) != voidptr(node) && node_is_focusable(current) {
			break
		}
		ancestor = current.parent_or_shadow_host()
	}
	return none
}

fn has_editable_descendant(root &dom.Node) bool {
	for child in root.children_as_vector() {
		if (!child.is_uninteresting_whitespace_node() && child.is_editable())
			|| has_editable_descendant(child) {
			return true
		}
	}
	return false
}

fn find_first_editable_leaf(root &dom.Node) ?&dom.Node {
	if !root.is_uninteresting_whitespace_node() && root.is_editable()
		&& !has_editable_descendant(root) {
		return root
	}
	for child in root.children_as_vector() {
		if result := find_first_editable_leaf(child) {
			return result
		}
	}
	return none
}

pub fn first_editable_leaf_descendant(root &dom.Node) ?&dom.Node {
	return find_first_editable_leaf(root)
}

pub fn caret_position_from_editable_hit_node(hit_node &dom.Node) ?CaretPosition {
	mut boundary_node := ?&dom.Node(none)
	if hit_node.is_editable_or_editing_host() {
		boundary_node = hit_node
	} else if editing_host := associated_descendant_editing_host(hit_node) {
		boundary_node = first_editable_leaf_descendant(editing_host) or { editing_host }
	} else {
		return none
	}
	boundary := boundary_node or { return none }
	mut layout_node := boundary.layout_node() or { unsafe { nil } }
	if !node_has_committed_box(boundary) {
		layout_node = hit_node.layout_node() or { return none }
	}
	if layout_node == unsafe { nil } || layout_node.paintables().len == 0 {
		return none
	}
	return CaretPosition{
		boundary: dom.BoundaryPoint{
			node: boundary
			offset: 0
		}
		layout_node: layout_node
		user_select_used_value: if boundary.is_editing_host() { .contain } else { .auto_ }
	}
}

pub fn should_use_caret_position_from_editable_hit_node(caret_position ?CaretPosition, hit_node &dom.Node, editing_host &dom.Node) bool {
	if !hit_node.is_inclusive_descendant_of(editing_host) {
		return true
	}
	position := caret_position or { return true }
	if !position.boundary.node.is_inclusive_descendant_of(editing_host) {
		return true
	}
	if voidptr(position.boundary.node) == voidptr(editing_host)
		&& first_editable_leaf_descendant(editing_host) != none {
		return true
	}
	return false
}

pub fn user_select_used_value_for_caret_position(caret_position CaretPosition) css.UserSelect {
	if caret_position.boundary.node.is_editing_host() {
		return .contain
	}
	return caret_position.user_select_used_value
}
