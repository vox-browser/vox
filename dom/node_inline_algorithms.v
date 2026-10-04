// Copyright (c) 2026, libweb_v contributors
//
// SPDX-License-Identifier: BSD-2-Clause
//
// Inline Node, ChildNode, NonDocumentTypeChildNode, and SlottableMixin entry
// points translated from Libraries/LibWeb/DOM.
module dom

fn (n &Node) element_has_namespace_and_local_name(namespace_ string, local_names []string) bool {
	element := n.as_element() or { return false }
	return element.namespace_uri() or { '' } == namespace_ && element.local_name() in local_names
}

fn (n &Node) is_html_element_with_any_local_name(local_names []string) bool {
	return n.element_has_namespace_and_local_name(namespace_html_uri, local_names)
}

fn (n &Node) is_svg_element_with_any_local_name(local_names []string) bool {
	return n.element_has_namespace_and_local_name(namespace_svg_uri, local_names)
}

// The C++ methods are virtual type predicates. The V representation stores
// the concrete interface in NodeType plus the element's namespace/local name,
// so the dynamic result is recovered from those values.
pub fn (n &Node) requires_svg_container() bool {
	return n.is_svg_element() && !n.is_svg_svg_element()
}

pub fn (n &Node) is_svg_container() bool {
	return n.is_svg_svg_element()
}

pub fn (n &Node) is_svg_element() bool {
	element := n.as_element() or { return false }
	return element.is_svg_element()
}

pub fn (n &Node) is_svg_graphics_element() bool {
	return n.is_svg_element_with_any_local_name([
		'a',
		'circle',
		'clipPath',
		'defs',
		'ellipse',
		'foreignObject',
		'g',
		'image',
		'line',
		'mask',
		'path',
		'polygon',
		'polyline',
		'rect',
		'svg',
		'switch',
		'symbol',
		'text',
		'textPath',
		'tspan',
		'use',
		'view',
	])
}

pub fn (n &Node) is_svg_mask_element() bool {
	return n.is_svg_element_with_any_local_name(['mask'])
}

pub fn (n &Node) is_svg_script_element() bool {
	return n.is_svg_element_with_any_local_name(['script'])
}

pub fn (n &Node) is_svg_style_element() bool {
	return n.is_svg_element_with_any_local_name(['style'])
}

pub fn (n &Node) is_svg_svg_element() bool {
	return n.is_svg_element_with_any_local_name(['svg'])
}

pub fn (n &Node) is_svg_symbol_element() bool {
	return n.is_svg_element_with_any_local_name(['symbol'])
}

pub fn (n &Node) is_svg_use_element() bool {
	return n.is_svg_element_with_any_local_name(['use'])
}

pub fn (n &Node) is_svg_view_element() bool {
	return n.is_svg_element_with_any_local_name(['view'])
}

pub fn (n &Node) is_svg_a_element() bool {
	return n.is_svg_element_with_any_local_name(['a'])
}

pub fn (n &Node) is_svg_g_element() bool {
	return n.is_svg_element_with_any_local_name(['g'])
}

pub fn (n &Node) is_svg_switch_element() bool {
	return n.is_svg_element_with_any_local_name(['switch'])
}

pub fn (n &Node) is_svg_foreign_object_element() bool {
	return n.is_svg_element_with_any_local_name(['foreignObject'])
}

pub fn (n &Node) is_dom_node() bool {
	return true
}

pub fn (n &Node) is_html_element() bool {
	element := n.as_element() or { return false }
	return element.is_html_element()
}

pub fn (n &Node) is_html_html_element() bool {
	return n.is_html_element_with_any_local_name(['html'])
}

pub fn (n &Node) is_html_anchor_element() bool {
	return n.is_html_element_with_any_local_name(['a'])
}

pub fn (n &Node) is_html_area_element() bool {
	return n.is_html_element_with_any_local_name(['area'])
}

pub fn (n &Node) is_html_base_element() bool {
	return n.is_html_element_with_any_local_name(['base'])
}

pub fn (n &Node) is_html_meta_element() bool {
	return n.is_html_element_with_any_local_name(['meta'])
}

pub fn (n &Node) is_html_body_element() bool {
	return n.is_html_element_with_any_local_name(['body'])
}

pub fn (n &Node) is_html_head_element() bool {
	return n.is_html_element_with_any_local_name(['head'])
}

pub fn (n &Node) is_html_heading_element() bool {
	return n.is_html_element_with_any_local_name(['h1', 'h2', 'h3', 'h4', 'h5', 'h6'])
}

pub fn (n &Node) is_html_input_element() bool {
	return n.is_html_element_with_any_local_name(['input'])
}

pub fn (n &Node) is_html_link_element() bool {
	return n.is_html_element_with_any_local_name(['link'])
}

pub fn (n &Node) is_html_media_element() bool {
	return n.is_html_element_with_any_local_name(['audio', 'video'])
}

pub fn (n &Node) is_html_optgroup_element() bool {
	return n.is_html_element_with_any_local_name(['optgroup'])
}

pub fn (n &Node) is_html_option_element() bool {
	return n.is_html_element_with_any_local_name(['option'])
}

pub fn (n &Node) is_html_progress_element() bool {
	return n.is_html_element_with_any_local_name(['progress'])
}

pub fn (n &Node) is_html_script_element() bool {
	return n.is_html_element_with_any_local_name(['script'])
}

pub fn (n &Node) is_html_select_element() bool {
	return n.is_html_element_with_any_local_name(['select'])
}

pub fn (n &Node) is_html_style_element() bool {
	return n.is_html_element_with_any_local_name(['style'])
}

pub fn (n &Node) is_html_template_element() bool {
	return n.is_html_element_with_any_local_name(['template'])
}

pub fn (n &Node) is_html_table_element() bool {
	return n.is_html_element_with_any_local_name(['table'])
}

pub fn (n &Node) is_html_table_section_element() bool {
	return n.is_html_element_with_any_local_name(['tbody', 'tfoot', 'thead'])
}

pub fn (n &Node) is_html_table_row_element() bool {
	return n.is_html_element_with_any_local_name(['tr'])
}

pub fn (n &Node) is_html_table_cell_element() bool {
	return n.is_html_element_with_any_local_name(['td', 'th'])
}

pub fn (n &Node) is_html_title_element() bool {
	return n.is_html_element_with_any_local_name(['title'])
}

pub fn (n &Node) is_html_br_element() bool {
	return n.is_html_element_with_any_local_name(['br'])
}

pub fn (n &Node) is_html_button_element() bool {
	return n.is_html_element_with_any_local_name(['button'])
}

pub fn (n &Node) is_html_slot_element() bool {
	return n.is_html_element_with_any_local_name(['slot'])
}

pub fn (n &Node) is_html_embed_element() bool {
	return n.is_html_element_with_any_local_name(['embed'])
}

pub fn (n &Node) is_html_object_element() bool {
	return n.is_html_element_with_any_local_name(['object'])
}

pub fn (n &Node) is_html_form_element() bool {
	return n.is_html_element_with_any_local_name(['form'])
}

pub fn (n &Node) is_html_image_element() bool {
	return n.is_html_element_with_any_local_name(['img'])
}

pub fn (n &Node) is_html_iframe_element() bool {
	return n.is_html_element_with_any_local_name(['iframe'])
}

pub fn (n &Node) is_html_div_element() bool {
	return n.is_html_element_with_any_local_name(['div'])
}

pub fn (n &Node) is_html_span_element() bool {
	return n.is_html_element_with_any_local_name(['span'])
}

pub fn (n &Node) is_html_textarea_element() bool {
	return n.is_html_element_with_any_local_name(['textarea'])
}

pub fn (n &Node) is_html_frameset_element() bool {
	return n.is_html_element_with_any_local_name(['frameset'])
}

pub fn (n &Node) is_html_fieldset_element() bool {
	return n.is_html_element_with_any_local_name(['fieldset'])
}

pub fn (n &Node) is_html_li_element() bool {
	return n.is_html_element_with_any_local_name(['li'])
}

pub fn (n &Node) is_html_menu_element() bool {
	return n.is_html_element_with_any_local_name(['menu'])
}

pub fn (n &Node) is_html_olist_element() bool {
	return n.is_html_element_with_any_local_name(['ol'])
}

pub fn (n &Node) is_html_ulist_element() bool {
	return n.is_html_element_with_any_local_name(['ul'])
}

pub fn (n &Node) is_html_ol_ul_menu_element() bool {
	return n.is_html_element_with_any_local_name(['ol', 'ul', 'menu'])
}

pub fn (n &Node) is_navigable_container() bool {
	return n.is_html_element_with_any_local_name(['frame', 'iframe', 'object'])
}

pub fn (n &Node) is_lazy_loading() bool {
	return n.is_html_element_with_any_local_name(['iframe', 'img'])
}

pub fn (n &Node) registered_observer_list() []&RegisteredObserver {
	return n.registered_observer_list_
}

// V callbacks replace the C++ template parameter while preserving the same
// traversal and early-break behavior.
pub fn (n &Node) for_each_child_of_type_fallible(callback fn (&Node) !TraversalDecision) ! {
	for child in n.children {
		if callback(child)! == .@break {
			return
		}
	}
}

pub fn (n &Node) first_flat_tree_ancestor_of_type(predicate fn (&Node) bool) ?&Node {
	mut ancestor := n.flat_tree_parent()
	for {
		current := ancestor or { return none }
		if predicate(current) {
			return current
		}
		ancestor = current.flat_tree_parent()
	}
	return none
}

pub fn (n &Node) find_in_shadow_including_ancestry(predicate fn (&Node) bool) ?&Node {
	mut current := ?&Node(n)
	for {
		candidate := current or { return none }
		if predicate(candidate) {
			return candidate
		}
		current = candidate.parent_or_shadow_host_node()
	}
	return none
}

pub fn (mut n Node) remove_binding() {
	n.remove(false)
}

pub fn (n &Node) previous_element_in_pre_order() ?&Element {
	mut candidate := n.previous_in_pre_order()
	for {
		current := candidate or { return none }
		if element := current.as_element() {
			return element
		}
		candidate = current.previous_in_pre_order()
	}
	return none
}

pub fn (n &Node) next_element_in_pre_order() ?&Element {
	mut candidate := n.next_in_pre_order(none)
	for {
		current := candidate or { return none }
		if element := current.as_element() {
			return element
		}
		candidate = current.next_in_pre_order(none)
	}
	return none
}

pub fn (e &Element) slottable_as_node() &Node {
	return e.as_node()
}

pub fn (t &Text) slottable_as_node() &Node {
	return t.as_node()
}
