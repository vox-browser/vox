module layout

import css
import dom
import os

const disable_retained_flow_items = os.getenv('VOX_DISABLE_RETAINED_FLOW_ITEMS') != ''
const retained_flow_item_diagnostics = os.getenv('VOX_RETAINED_FLOW_ITEM_DIAGNOSTICS') != ''

__global retained_flow_item_reported bool

struct RetainedFlowSubtree {
	root     &Node
	elements []&dom.Element
}

@[heap]
struct RetainedFlowValidationCache {
	inputs []RetainedInlineInput
	elements []&dom.Element
}

fn collect_retained_flow_validation_inputs(node &Node, root bool,
	mut inputs []RetainedInlineInput) bool {
	style := node.computed_values()
	revision := style.mutation_revision()
	if revision == 0 { return false }
	inputs << RetainedInlineInput{
		node: node
		style: style
		style_revision: revision
		child_count: node.child_count()
		parent_id: if root { u64(0) } else if parent := node.parent() { u64(voidptr(parent)) } else { 0 }
		sibling_index: node.index_in_parent_
		text: if text := node.as_text_node() { text.text_for_rendering() } else { '' }
	}
	for child in node.children() {
		if !collect_retained_flow_validation_inputs(child, false, mut inputs) { return false }
	}
	return true
}

fn retained_flow_validation_is_current(cache &RetainedFlowValidationCache) bool {
	if !retained_inline_inputs_are_current(cache.inputs) { return false }
	for element in cache.elements {
		computed := css.computed_properties_for_element(element) or { return false }
		mirror := element.as_node().unsafe_layout_node() or { return false }
		if mirror.real_layout_handle() == unsafe { nil } { return false }
		typed := unsafe { &Node(mirror.real_layout_handle()) }
		if !retained_flow_style_matches(typed, computed) { return false }
	}
	for input in cache.inputs {
		if dom_node := input.node.dom_node() {
			mirror := dom_node.unsafe_layout_node() or { return false }
			if mirror.real_layout_handle() != voidptr(input.node) { return false }
		}
		if text := input.node.as_text_node() {
			dom_node := input.node.dom_node() or { return false }
			data := dom_node.as_character_data() or { return false }
			if text.source_text_ != data.data() || text.source_range_length_ != none
				|| text.first_letter_ != none { return false }
		}
	}
	return true
}

// TreeBuilder's DOM invalidation flags identify the branches which need new
// boxes. Keep ordinary flow and text-only block grid/flex branches outside
// those mutations, including text shaping caches and live DOM layout boundaries.
// Formatting and geometry
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
	if !retained_tree_display_is_supported(computed.display()) {
		return none
	}
	mirror := dom_root.unsafe_layout_node() or { return none }
	if mirror.real_layout_handle() == unsafe { nil } { return none }
	root := unsafe { &Node(mirror.real_layout_handle()) }
	if (!root.is_block_container() && !root.is_inline_node()
		&& !retained_tree_is_block_formatting_container(root)) || root.is_anonymous() { return none }
	parent := root.parent() or { return none }
	if parent.is_anonymous() { return none }
	parent_dom := parent.dom_node() or { return none }
	dom_parent := dom_root.parent() or { return none }
	if voidptr(parent_dom) != voidptr(dom_parent) { return none }
	if root.flow_validation_cache_ != unsafe { nil }
		&& retained_flow_layout_node_is_ordinary(root)
		&& retained_flow_validation_is_current(root.flow_validation_cache_) {
		report_retained_flow_item(root)
		report_retained_formatting_tree(root)
		report_retained_flow_style_reuse(root, root.flow_validation_cache_.elements)
		return RetainedFlowSubtree{root: root, elements: root.flow_validation_cache_.elements}
	}
	mut elements := []&dom.Element{}
	if !collect_retained_flow_elements(element, mut elements, mut rejected) { return none }
	mut inputs := []RetainedInlineInput{}
	if collect_retained_flow_validation_inputs(root, true, mut inputs) {
		mut mutable_root := unsafe { &Node(root) }
		mutable_root.flow_validation_cache_ = &RetainedFlowValidationCache{
			inputs: inputs
			elements: elements
		}
	}
	report_retained_flow_item(root)
	report_retained_formatting_tree(root)
	report_retained_flow_style_reuse(root, elements)
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
		|| element.local_name() !in ['div', 'section', 'article', 'aside', 'header', 'footer', 'main', 'nav', 'p', 'span', 'a', 'strong', 'b', 'em', 'i', 's', 'del', 'small', 'code', 'pre', 'blockquote', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'ul', 'ol', 'li', 'time', 'br', 'form'] {
		return false
	}
	if value := computed.typed_property_value(.content) {
		if value.to_keyword() !in [.normal, .none_] { return false }
	}
	mirror := node.unsafe_layout_node() or { return false }
	if mirror.real_layout_handle() == unsafe { nil } || mirror.continuation_next() != none {
		return false
	}
	typed := unsafe { &Node(mirror.real_layout_handle()) }
	if voidptr(typed.document()) != voidptr(element.document()) {
		return false
	}
	if !retained_flow_layout_node_is_ordinary(typed) { return false }
	expects_inline_node := computed.display().is_inline_outside() && computed.display().is_flow_inside()
	if !typed.is_break_node() && typed.is_inline_node() != expects_inline_node { return false }
	for child in typed.children() {
		if !retained_flow_anonymous_layout_is_ordinary(child) { return false }
	}
	if typed.as_node_with_style() == none { return false }
	if !retained_flow_style_matches(typed, computed)
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
		|| node.is_absolutely_positioned() {
		return false
	}
	if node.is_flex_item() || node.is_grid_item_ {
		if disable_retained_flow_items { return false }
		parent := node.parent() or { return false }
		parent_node := parent.dom_node() or { return false }
		parent_element := parent_node.as_element() or { return false }
		parent_computed := css.computed_properties_for_element(parent_element) or { return false }
		// Keep the existing item role only while its formatting parent still
		// supplies that role. Layout runs again in a fresh state, so new tracks,
		// flex bases and containing-block sizes resolve normally.
		// The old parent box can still hold its previous style while its
		// replacement is being built. Read the freshly cascaded DOM style.
		if node.is_flex_item() != parent_computed.display().is_flex_inside()
			|| node.is_grid_item_ != parent_computed.display().is_grid_inside() { return false }
	}
	if !node.is_text_node() && !retained_tree_display_is_supported(node.display()) { return false }
	if node.display().is_grid_inside() {
		computed := node.computed_values()
		if computed.grid_template_columns().is_subgrid() || computed.grid_template_rows().is_subgrid() {
			return false
		}
	}
	if metrics := node.as_node_with_style_and_box_model_metrics() {
		if metrics.continuation_of_node() != none { return false }
	}
	return true
}

fn report_retained_flow_item(node &Node) {
	if retained_flow_item_diagnostics && !retained_flow_item_reported
		&& (node.is_flex_item() || node.is_grid_item_) {
		retained_flow_item_reported = true
		eprintln('Vox retained flow: reused unchanged formatting item')
	}
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
