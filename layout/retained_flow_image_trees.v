module layout

import dom
import os

const disable_retained_flow_image_trees = os.getenv('VOX_DISABLE_RETAINED_FLOW_IMAGE_TREES') != ''
const retained_flow_image_tree_diagnostics = os.getenv('VOX_RETAINED_FLOW_IMAGE_TREE_DIAGNOSTICS') != ''

__global retained_flow_image_tree_reported bool

// Reuse only the tree structure. finish_document_layout refreshes the live
// image provider and computes geometry in a fresh LayoutState. Unavailable,
// SVG, generated and CSS replacement images keep the complete builder path.
fn retained_flow_raster_image_is_ordinary(node &Node) bool {
	if disable_retained_flow_image_trees || node.has_children() { return false }
	box := node.as_image_box() or { return false }
	if box.uses_content_replacement() || box.svg_image_document() != none { return false }
	owner := node.dom_node() or { return false }
	if !owner.is_html_image_element() { return false }
	element := owner.as_element() or { return false }
	return available_html_svg_image_document(element) == none
		&& available_html_image_natural_size(element) != none
}

fn report_retained_flow_image_tree(elements []&dom.Element) {
	if !retained_flow_image_tree_diagnostics || retained_flow_image_tree_reported { return }
	if elements.any(it.as_node().is_html_image_element()) {
		retained_flow_image_tree_reported = true
		eprintln('Vox retained image tree: reused unchanged raster image branch before fresh geometry')
	}
}
