module layout

import css
import dom

struct RetainedFlowSubtree {
	root     &Node
	elements []&dom.Element
}

// TreeBuilder's DOM invalidation flags identify the branches which need new
// boxes. Keep ordinary flow branches outside those mutations, including their
// text shaping caches and live DOM layout boundaries. Formatting and geometry
// still run against a fresh LayoutState for the whole resulting tree.
fn reusable_clean_flow_subtree(element &dom.Element, mut rejected map[u64]bool) ?RetainedFlowSubtree {
	if rejected[u64(voidptr(element))] { return none }
	dom_root := element.as_node()
	if dom_root.needs_layout_tree_update_() || dom_root.child_needs_layout_tree_update_() {
		return none
	}
	// SVG references can instantiate one DOM subtree at several positions.
	// Namespace-bridging descendants keep independent boxes in the full builder.
	mut ancestor := dom_root.parent_or_shadow_host()
	for ancestor != none {
		current := ancestor or { break }
		if parent_element := current.as_element() {
			if !parent_element.is_html_element() { return none }
		}
		ancestor = current.parent_or_shadow_host()
	}
	computed := css.computed_properties_for_element(element) or { return none }
	// Display changes invalidate the parent which owns this insertion. A node
	// which just became unboxed can still have its previous principal box here.
	if !computed.display().is_flow_inside() {
		return none
	}
	mirror := dom_root.unsafe_layout_node() or { return none }
	if mirror.real_layout_handle() == unsafe { nil } { return none }
	root := unsafe { &Node(mirror.real_layout_handle()) }
	if (!root.is_block_container() && !root.is_inline_node()) || root.is_anonymous() { return none }
	parent := root.parent() or { return none }
	if parent.is_anonymous() { return none }
	parent_dom := parent.dom_node() or { return none }
	dom_parent := dom_root.parent() or { return none }
	if voidptr(parent_dom) != voidptr(dom_parent) { return none }
	mut elements := []&dom.Element{}
	if !collect_retained_flow_elements(element, mut elements, mut rejected) { return none }
	return RetainedFlowSubtree{
		root:     root
		elements: elements
	}
}

fn collect_retained_flow_elements(element &dom.Element, mut elements []&dom.Element, mut rejected map[u64]bool) bool {
	key := u64(voidptr(element))
	if rejected[key] { return false }
	mut eligible := false
	defer {
		if !eligible { rejected[key] = true }
	}
	node := element.as_node()
	if node.needs_layout_tree_update_() || node.child_needs_layout_tree_update_() { return false }
	computed := css.computed_properties_for_element(element) or { return false }
	if computed.display().is_none() {
		eligible = true
		return true
	}
	if !element.is_html_element() || element.shadow_root() != none
		|| element.rendered_in_top_layer() || computed.content_visibility() != .visible
		|| computed.position() !in [.static_, .relative]
		|| element.local_name() !in ['div', 'section', 'article', 'aside', 'header', 'footer', 'main', 'nav', 'p', 'span', 'a', 'strong', 'b', 'em', 'i', 's', 'del', 'small', 'code', 'pre', 'blockquote', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'ul', 'ol', 'li', 'time', 'br'] {
		return false
	}
	if value := computed.typed_property_value(.content) {
		if value.to_keyword() !in [.normal, .none_] { return false }
	}
	mirror := node.unsafe_layout_node() or { return false }
	if mirror.real_layout_handle() == unsafe { nil } || mirror.continuation_next_ != none {
		return false
	}
	typed := unsafe { &Node(mirror.real_layout_handle()) }
	if voidptr(typed.document()) != voidptr(element.document()) {
		return false
	}
	if !retained_flow_layout_node_is_ordinary(typed) { return false }
	if !typed.is_break_node() && typed.is_inline_node() != computed.display().is_inline_outside() { return false }
	for child in typed.children() {
		if !retained_flow_anonymous_layout_is_ordinary(child) { return false }
	}
	styled := typed.as_node_with_style() or { return false }
	if voidptr(styled.computed_values()) != voidptr(computed)
		|| typed.display() != computed.display() {
		return false
	}
	elements << element
	for child in node.children {
		if child_element := child.as_element() {
			if !collect_retained_flow_elements(child_element, mut elements, mut rejected) {
				return false
			}
		} else if child.is_text() {
			data := child.as_character_data() or { return false }
			text_mirror := child.unsafe_layout_node() or { return false }
			if text_mirror.real_layout_handle() == unsafe { nil } { return false }
			text := unsafe { &Node(text_mirror.real_layout_handle()) }.as_text_node() or {
				return false
			}
			if text.source_text_ != data.data() || text.source_range_length_ != none
				|| text.first_letter_ != none {
				return false
			}
		}
	}
	eligible = true
	return true
}

fn retained_flow_layout_node_is_ordinary(node &Node) bool {
	if node.is_generated_for_pseudo_element() || node.is_generated_text_node()
		|| node.is_replaced_element() || node.is_svg_box() || node.is_list_item_box()
		|| node.is_floating() || node.is_out_of_flow() || node.is_flex_item() || node.is_grid_item_ {
		return false
	}
	if !node.is_text_node() && !node.display().is_flow_inside() { return false }
	if metrics := node.as_node_with_style_and_box_model_metrics() {
		if metrics.continuation_of_node() != none { return false }
	}
	return true
}

fn retained_flow_anonymous_layout_is_ordinary(node &Node) bool {
	// DOM children are checked in DOM tree order, which counter resolution also
	// consumes. Anonymous flow wrappers belong to this same retained branch.
	if !retained_flow_layout_node_is_ordinary(node) { return false }
	if node.dom_node() != none { return true }
	for child in node.children() {
		if !retained_flow_anonymous_layout_is_ordinary(child) { return false }
	}
	return true
}
