// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Editing/InlineInsertion.{h,cpp}.
module editing

import dom

pub struct InlineInsertionBoundary {
pub:
	boundary                dom.BoundaryPoint
	split_destination_style bool
}

fn is_dom_block_node(node &dom.Node) bool {
	if node.is_document() || node.is_document_fragment() {
		return true
	}
	element := node.as_element() or { return false }
	display := element.el_computed_properties() or {
		if element.is_html_element() {
			return element.local_name() !in ['a', 'abbr', 'b', 'bdi', 'bdo', 'big', 'blink',
				'br', 'button', 'cite', 'code', 'dfn', 'em', 'font', 'i', 'img', 'input', 'kbd',
				'label', 'mark', 'nobr', 'q', 'rp', 'rt', 'ruby', 's', 'samp', 'small', 'span',
				'strike', 'strong', 'sub', 'sup', 'tt', 'u', 'var']
		}
		return true
	}
	resolved := display.display()
	return !(resolved.is_inline_outside()
		&& (resolved.is_flow_inside() || resolved.is_flow_root_inside()
		|| resolved.is_table_inside())) && !resolved.is_none()
}

fn is_dom_inline_node(node &dom.Node) bool {
	return !is_dom_block_node(node)
}

fn has_only_allowed_attributes(element &dom.Element, allowed []string) bool {
	mut mutable_element := unsafe { &dom.Element(element) }
	attributes := mutable_element.attributes()
	for index := 0; index < attributes.length(); index++ {
		attribute := attributes.item(index) or { continue }
		if attribute.local_name() !in allowed {
			return false
		}
	}
	return true
}

fn is_dom_modifiable_element(node &dom.Node) bool {
	element := node.as_element() or { return false }
	if !element.is_html_element() {
		return false
	}
	name := element.local_name()
	if name in ['b', 'em', 'i', 's', 'span', 'strike', 'strong', 'sub', 'sup', 'u'] {
		return has_only_allowed_attributes(element, ['style'])
	}
	if name == 'font' {
		return has_only_allowed_attributes(element, ['style', 'color', 'face', 'size'])
	}
	return name == 'a' && has_only_allowed_attributes(element, ['style', 'href'])
}

pub fn prepare_inline_insertion_boundary(boundary_ dom.BoundaryPoint, containing_block &dom.Node) InlineInsertionBoundary {
	assert boundary_.node == containing_block || containing_block.is_ancestor_of(boundary_.node)
	mut boundary := boundary_

	for boundary.node != containing_block {
		if boundary.offset != boundary.node.length() || boundary.node.parent() == none {
			break
		}
		node := boundary.node
		mut parent := node.parent() or { break }
		boundary = dom.BoundaryPoint{
			node: parent
			offset: node.index() + 1
		}
	}

	mut highest_styled_inline_ancestor := unsafe { &dom.Node(nil) }
	mut ancestor := ?&dom.Node(boundary.node)
	for ancestor != none {
		current := ancestor or { break }
		if current == containing_block {
			break
		}
		if element := current.as_element() {
			if element.is_html_element() && element.local_name() in ['li', 'ul', 'ol'] {
				return InlineInsertionBoundary{
					boundary: boundary
				}
			}
		}
		if is_dom_inline_node(current) && is_dom_modifiable_element(current) {
			highest_styled_inline_ancestor = current
		}
		ancestor = current.parent()
	}
	if highest_styled_inline_ancestor == unsafe { nil }
		|| highest_styled_inline_ancestor.parent() == none {
		return InlineInsertionBoundary{
			boundary: boundary
		}
	}

	parent := highest_styled_inline_ancestor.parent() or {
		return InlineInsertionBoundary{
			boundary: boundary
		}
	}
	return InlineInsertionBoundary{
		boundary: split_inline_ancestors_at_boundary(boundary, parent)
		split_destination_style: true
	}
}
