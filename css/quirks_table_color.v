// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause

module css

import dom

fn is_quirks_table(element dom.AbstractElement) bool {
	return element.document().in_quirks_mode() && element.pseudo_element() == none
		&& element.element().is_html_element() && element.element().local_name() == 'table'
}

fn is_quirks_html_root(node &dom.Node) bool {
	if !node.document().in_quirks_mode() { return false }
	element := node.as_element() or { return false }
	root := node.document().document_element() or { return false }
	return voidptr(element) == voidptr(root) && element.is_html_element()
		&& element.local_name() == 'html'
}

// This is the quirks definition of the body's identity, which deliberately
// ignores frameset elements and later body siblings.
fn quirks_table_body(document &dom.Document) ?&dom.Element {
	root := document.document_element() or { return none }
	if !root.is_html_element() || root.local_name() != 'html' { return none }
	for child in root.as_node().children {
		element := child.as_element() or { continue }
		if element.is_html_element() && element.local_name() == 'body' { return element }
	}
	return none
}

fn is_quirks_table_body(node &dom.Node) bool {
	if !node.document().in_quirks_mode() { return false }
	element := node.as_element() or { return false }
	if !element.is_html_element() || element.local_name() != 'body' { return false }
	body := quirks_table_body(node.document()) or { return false }
	return voidptr(element) == voidptr(body)
}

fn quirks_body_used_color(body &dom.Element) ?Color {
	computed := computed_properties_for_element(body) or { return none }
	return ColorResolutionContext.for_computed_properties(computed, body.document()).current_color
}

fn resolve_quirks_table_color(element dom.AbstractElement, mut cascaded CascadedProperties) {
	index := cascaded.winning_entry_index(.color)
	if index < 0 { return }
	entry := cascaded.entry_node(index).entry
	if (computed_interpolation_style_value_keyword(entry.property.value) or { Keyword.invalid }) != .libweb_quirk_inherit {
		return
	}
	mut value := computed_interpolation_property_initial_value(.color)
	if is_quirks_table(element) && element.element().is_connected() {
		if body := quirks_table_body(element.document()) {
			if color := quirks_body_used_color(body) {
				// Freeze the body's used color in its own color scheme. A table's
				// different scheme must not reinterpret the body's system color.
				value = dom_style_value_from_value_logic(StyleValue(ColorStyleValue.create(color)))
			}
		}
	}
	cascaded.set_property(.color, value, entry.property.important, entry.origin,
		entry.layer_name, entry.source, entry.source_shadow_root)
}

fn quirks_body_color_state(document &dom.Document) (u64, ?Color) {
	body := quirks_table_body(document) or { return u64(0), none }
	return u64(body.as_node().unique_id().value()), quirks_body_used_color(body)
}

fn quirks_body_colors_equal(left ?Color, right ?Color) bool {
	if first := left {
		second := right or { return false }
		return first == second
	}
	return right == none
}

fn (s &StyleComputer) quirks_body_color_changed() bool {
	identity, color := quirks_body_color_state(s.document_)
	return identity != s.quirks_body_identity_
		|| !quirks_body_colors_equal(color, s.quirks_body_used_color_)
}

fn (mut s StyleComputer) remember_quirks_body_color() bool {
	identity, color := quirks_body_color_state(s.document_)
	changed := identity != s.quirks_body_identity_
		|| !quirks_body_colors_equal(color, s.quirks_body_used_color_)
	s.quirks_body_identity_ = identity
	s.quirks_body_used_color_ = color
	return changed
}

// Sampling runs before Document.update_style checks pending invalidations.
// Body color can reach a table outside the body's descendant tree, so mark
// those dependencies for that same style-update continuation.
fn (s &StyleComputer) invalidate_animated_quirks_table_colors() {
	if !s.document_.in_quirks_mode() || !s.quirks_body_color_changed() { return }
	s.document_.as_node().for_each_shadow_including_inclusive_descendant(fn (node &dom.Node) dom.TraversalDecision {
		if element := node.as_element() {
			if element.is_html_element() && element.local_name() == 'table' {
				mut mutable_node := unsafe { &dom.Node(node) }
				mutable_node.set_needs_style_update(true)
			}
		}
		return .@continue
	})
}
