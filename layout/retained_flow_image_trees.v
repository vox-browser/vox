module layout

import dom
import html
import os

const disable_retained_flow_image_trees = os.getenv('VOX_DISABLE_RETAINED_FLOW_IMAGE_TREES') != ''
const retained_flow_image_tree_diagnostics = os.getenv('VOX_RETAINED_FLOW_IMAGE_TREE_DIAGNOSTICS') != ''
const disable_extended_image_trees = os.getenv('VOX_DISABLE_EXTENDED_IMAGE_TREES') != ''

__global retained_flow_image_tree_reported bool
__global retained_extended_image_tree_reported bool

// Reuse only the tree structure. finish_document_layout refreshes the live
// image provider and computes geometry in a fresh LayoutState. Pending requests
// still select an ImageBox. Recheck that selection and SVG availability on every
// reuse; broken/alt-text, SVG and CSS replacement images keep the full builder.
fn retained_flow_raster_image_is_ordinary(node &Node) bool {
	if disable_retained_flow_image_trees || node.has_children() { return false }
	if node.is_fixed_position() || (disable_extended_image_trees && node.is_absolutely_positioned()) {
		return false
	}
	box := node.as_image_box() or { return false }
	if box.uses_content_replacement() || box.svg_image_document() != none { return false }
	owner := node.dom_node() or { return false }
	if !owner.is_html_image_element() { return false }
	element := owner.as_element() or { return false }
	if available_html_svg_image_document(element) != none { return false }
	image := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
	return image.is_image_available() || (!disable_extended_image_trees && image.is_image_pending())
}

fn report_retained_flow_image_tree(elements []&dom.Element) {
	if !retained_flow_image_tree_diagnostics { return }
	if !retained_flow_image_tree_reported && elements.any(it.as_node().is_html_image_element()) {
		retained_flow_image_tree_reported = true
		eprintln('Vox retained image tree: reused unchanged raster image branch before fresh geometry')
	}
	if retained_extended_image_tree_reported { return }
	for element in elements {
		if !element.as_node().is_html_image_element() { continue }
		mirror := element.as_node().unsafe_layout_node() or { continue }
		if mirror.real_layout_handle() == unsafe { nil } { continue }
		node := unsafe { &Node(mirror.real_layout_handle()) }
		image := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
		if node.is_absolutely_positioned() || !image.is_image_available() {
			retained_extended_image_tree_reported = true
			eprintln('Vox retained extended image tree: reused pending or absolute image branch')
			return
		}
	}
}
