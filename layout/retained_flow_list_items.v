module layout

import css
import dom

// List items keep their boxes across a tree rebuild only when their marker
// cannot depend on the item's ordinal or on resources: no marker, a string,
// or a cyclic counter style with one symbol (disc, circle, square), without
// list-style-image or authored ::marker content. The marker box must still
// carry the current ::marker style. Counters are resolved again for every
// retained list item (retained_flow_counters.v).

fn retained_flow_marker_style_is_static(element &dom.Element, list_item &css.ComputedProperties) bool {
	if image := list_item.typed_property_value(.list_style_image) {
		if image.is_abstract_image() { return false }
	}
	if marker := css.computed_properties_for_pseudo_element(element, .marker) {
		if value := marker.typed_property_value(.content) {
			if value.to_keyword() != .normal { return false }
		}
	}
	list_style_type := list_item.list_style_type_for_scope(css.style_scope_for_abstract_element(dom.AbstractElement.new(element, none)))
	return match list_style_type.kind {
		.none_, .string { true }
		.counter_style {
			style := list_style_type.counter_style or { return false }
			algorithm := style.algorithm_
			if algorithm is css.GenericCounterStyleAlgorithm {
				algorithm.type_ == .cyclic && algorithm.symbol_list.len == 1
			} else {
				false
			}
		}
	}
}

fn retained_flow_element_has_generated_pseudo_style_except_static_marker(element &dom.Element,
	computed &css.ComputedProperties) bool {
	static_marker := computed.display().is_list_item()
		&& retained_flow_marker_style_is_static(element, computed)
	for pseudo in [dom.PseudoElement.before, .after, .first_letter, .marker, .backdrop]! {
		if pseudo == .marker && static_marker { continue }
		if dom.AbstractElement.new(element, pseudo).computed_properties() != none { return true }
	}
	return false
}

fn retained_flow_list_item_box_is_static(node &Node) bool {
	owner := node.dom_node() or { return false }
	element := owner.as_element() or { return false }
	computed := css.computed_properties_for_element(element) or { return false }
	return computed.display().is_list_item() && retained_flow_marker_style_is_static(element, computed)
}

fn retained_flow_marker_box_is_static(node &Node) bool {
	parent := node.parent() or { return false }
	if !parent.is_list_item_box() || !retained_flow_list_item_box_is_static(parent) { return false }
	owner := parent.dom_node() or { return false }
	element := owner.as_element() or { return false }
	// The marker keeps the style it was built with; a restyled ::marker rebuilds.
	if marker := css.computed_properties_for_pseudo_element(element, .marker) {
		if voidptr(node.computed_values()) != voidptr(marker) { return false }
	}
	for child in node.children() {
		if !child.is_text_node() || child.children().len != 0 { return false }
	}
	return true
}
