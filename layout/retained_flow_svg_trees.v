module layout

import css
import dom
import os

const disable_retained_flow_svg_trees = os.getenv('VOX_DISABLE_RETAINED_FLOW_SVG_TREES') != ''
const retained_flow_svg_tree_diagnostics = os.getenv('VOX_RETAINED_FLOW_SVG_TREE_DIAGNOSTICS') != ''

__global retained_flow_svg_tree_reported_document dom.UniqueNodeID

fn retained_flow_svg_node_is_ordinary(node &Node) bool {
	if disable_retained_flow_svg_trees || (!node.is_svg_box() && !node.is_svg_svg_box())
		|| node.document().is_svg_image_document() || node.is_floating()
		|| node.is_in_ua_internal_shadow_tree()
		|| !retained_layout_position_is_unshifted(node)
		|| !retained_simple_svg_style_is_closed(node) { return false }
	owner := node.dom_node() or { return false }
	mirror := owner.unsafe_layout_node() or { return false }
	if mirror.real_layout_handle() != voidptr(node) { return false }
	// A reference instance can bind a source DOM node elsewhere. Anonymous
	// HTML wrappers are ordinary, but the first DOM parent must still match.
	mut parent := node.parent()
	mut parent_matches := false
	for parent != none {
		candidate := parent or { break }
		if dom_parent := candidate.dom_node() {
			actual := owner.parent() or { return false }
			parent_matches = voidptr(dom_parent) == voidptr(actual)
			break
		}
		if !candidate.is_anonymous() { return false }
		parent = candidate.parent()
	}
	if !parent_matches { return false }
	style := node.computed_values()
	if style.has_animated_properties() || style.content_visibility() != .visible
		|| (!style.display().is_flow_inside() && !style.display().is_flow_root_inside()) {
		return false
	}
	if node.is_svg_svg_box() {
		element := owner.as_element() or { return false }
		box := node.as_box() or { return false }
		// These two fields are constructor snapshots rather than live DOM
		// geometry. Rebuild when SVG width/height/viewBox change their metrics.
		natural := negotiate_svg_natural_metrics(element)
		if box.natural_size_ != natural || box.auto_content_box_size_ != natural { return false }
	}
	return true
}

// Keep only closed shape trees already covered by the shared SVG source
// snapshot. Text, use/resource instances, animation elements and URL paints
// retain the full builder. Geometry and containing blocks are recomputed in
// the next LayoutState; no old SVG UsedValues or paths are replayed here.
fn collect_retained_flow_svg_elements(element &dom.Element, mut elements []&dom.Element) bool {
	if disable_retained_flow_svg_trees || element.local_name() != 'svg' { return false }
	mirror := element.as_node().unsafe_layout_node() or { return false }
	if mirror.real_layout_handle() == unsafe { nil } { return false }
	root := unsafe { &Node(mirror.real_layout_handle()) }
	input := retained_simple_svg_input(root) or { return false }
	for saved in input.elements {
		owner := saved.element
		dom_node := owner.as_node()
		if dom_node.needs_layout_tree_update_() || dom_node.child_needs_layout_tree_update_() { return false }
		computed := css.computed_properties_for_element(owner) or { return false }
		if computed.display().is_none() || computed.content_visibility() != .visible { return false }
		layout_node := dom_node.unsafe_layout_node() or { return false }
		if layout_node.real_layout_handle() == unsafe { nil } || layout_node.continuation_next() != none { return false }
		typed := unsafe { &Node(layout_node.real_layout_handle()) }
		if voidptr(typed.document()) != voidptr(owner.document())
			|| !retained_flow_svg_node_is_ordinary(typed)
			|| !retained_flow_style_matches(typed, computed)
			|| typed.display() != computed.display() { return false }
	}
	// Publish only after every element passes; partial rejection must leave
	// the HTML caller's counter traversal in its original DOM order.
	for saved in input.elements { elements << saved.element }
	return true
}

fn report_retained_flow_svg_tree(root &Node, elements []&dom.Element) {
	if !retained_flow_svg_tree_diagnostics || disable_retained_flow_svg_trees
		|| !elements.any(it.is_svg_element()) { return }
	identity := root.document().as_node().unique_id()
	if retained_flow_svg_tree_reported_document == identity { return }
	retained_flow_svg_tree_reported_document = identity
	eprintln('Vox retained SVG tree: reused closed SVG branch before fresh geometry; document=${root.document().url.serialize()}')
}
