module layout

import css
import dom
import html
import os

const disable_retained_flow_images = os.getenv('VOX_DISABLE_RETAINED_FLOW_IMAGES') != ''
const retained_flow_image_diagnostics = os.getenv('VOX_RETAINED_FLOW_IMAGE_DIAGNOSTICS') != ''

__global retained_flow_images_reported_document dom.UniqueNodeID

struct RetainedFlowImageInput {
	source  string
	natural css.SizeWithAspectRatio
}

// Tree reuse preserves the ImageBox's constructor inputs, not image pixels.
// Paint still reads the live provider, and layout still resets replaced boxes.
// Unavailable network images have zero natural size only while neither the
// provider nor the synchronous SVG resource store can supply image metadata.
fn retained_flow_image_input(node &Node) ?RetainedFlowImageInput {
	if disable_retained_flow_images || !node.is_image_box() || node.has_children() { return none }
	box := node.as_image_box() or { return none }
	if box.uses_content_replacement() || box.svg_image_document_ != none
		|| box.source_resolution_ != 1 {
		return none
	}
	owner := node.dom_node() or { return none }
	if !owner.is_html_image_element() { return none }
	element := owner.as_element() or { return none }
	if available_html_svg_image_document(element) != none { return none }
	mut source := image_source_selected_from_attributes(element)
	mut natural := css.SizeWithAspectRatio{
		width:  CSSPixels.new(0)
		height: CSSPixels.new(0)
	}
	if available := available_html_image_natural_size(element) {
		image := unsafe { &dom.HTMLImageElement(element) }
		current_source := html.html_image_element_current_src(image)
		if current_source != '' { source = current_source }
		natural = available
	}
	// Data/file resources can change without the image model changing. Keep
	// them on the builder path. HTTP intrinsic fallback supplies only SVG;
	// use the same loader/MIME checks instead of guessing from a suffix. The
	// constructor checks this store even when a raster provider is available.
	if !source.starts_with('https://') && !source.starts_with('http://') { return none }
	if svg_image_source_for_source(node.document(), source) != none { return none }
	if source != box.source_ || natural != box.natural_size_
		|| natural != box.auto_content_box_size_ {
		return none
	}
	return RetainedFlowImageInput{ source: source, natural: natural }
}

fn report_retained_flow_image_reuse(root &Node, inputs []RetainedInlineInput) {
	if !retained_flow_image_diagnostics || disable_retained_flow_images { return }
	document := root.document()
	identity := document.as_node().unique_id()
	if retained_flow_images_reported_document == identity { return }
	for input in inputs {
		if input.flow_image != none {
			retained_flow_images_reported_document = identity
			eprintln('Vox retained flow images: reused subtree with unchanged image inputs; document=${document.url.serialize()}')
			return
		}
	}
}
