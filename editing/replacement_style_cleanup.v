// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Editing/ReplacementStyleCleanup.{h,cpp}.
module editing

import css
import dom

fn collect_inserted_styled_elements(node &dom.Node, mut elements []&dom.Element) {
	if element := node.as_element() {
		if element.has_attribute('style') {
			elements << element
		}
	}
	for child in node.children_as_vector() {
		collect_inserted_styled_elements(child, mut elements)
	}
}

fn computed_property_values_are_equivalent(property_id css.PropertyID, styles css.ComputedStylePair) bool {
	with_inline := styles.with_inline.property(property_id, .no) or { return false }
	without_inline := styles.without_inline.property(property_id, .no) or { return false }
	if with_inline == without_inline {
		return true
	}
	return with_inline.css_text == without_inline.css_text
}

pub fn remove_redundant_styles_from_inserted_content(mut inserted_content InsertedContent) {
	mut styled_elements := []&dom.Element{}
	for node in inserted_content.nodes() {
		collect_inserted_styled_elements(node, mut styled_elements)
	}

	for element in styled_elements {
		if element.as_node().parent() == none {
			continue
		}
		inline_style := css.inline_style_for_element(element) or { continue }
		styles := css.computed_styles_with_and_without_inline(element) or { continue }
		mut retained_properties := []css.CSSStyleProperty{cap: inline_style.properties.len}
		for property in inline_style.properties {
			property_id := css.property_id_from_string(property.name) or {
				retained_properties << property
				continue
			}
			if !computed_property_values_are_equivalent(property_id, styles) {
				retained_properties << property
			}
		}
		if retained_properties.len == inline_style.properties.len {
			continue
		}

		mut retained_style := css.CSSStyleProperties.create()
		retained_style.properties = retained_properties
		retained_style.custom_properties = inline_style.custom_properties.clone()
		serialized_style := retained_style.serialized()
		if serialized_style != '' {
			set_attribute_value(element, 'style', serialized_style)
			continue
		}

		should_unwrap := element.is_html_element() && element.local_name() == 'span'
			&& element.attribute_list_size() == 1 && element.as_node().has_children()
		first_child := element.as_node().first_child()
		last_child := element.as_node().last_child()
		remove_attribute(element, 'style')
		if !should_unwrap {
			continue
		}
		first := first_child or { continue }
		last := last_child or { continue }
		unwrap_node_preserving_ranges(element.as_node())
		inserted_content.did_replace_node_range(element.as_node(), first, last)
	}
}
