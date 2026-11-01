module layout

import css
import dom
import html
import os

const disable_retained_block_images = os.getenv('VOX_DISABLE_RETAINED_BLOCK_IMAGES') != ''
const retained_block_image_diagnostics = os.getenv('VOX_RETAINED_BLOCK_IMAGE_DIAGNOSTICS') != ''

__global retained_block_image_reported bool

struct RetainedBlockImageInput {
	source string
	natural css.SizeWithAspectRatio
}

fn retained_block_image_input(node &Node) ?RetainedBlockImageInput {
	if disable_retained_block_images || !node.is_image_box() || node.has_children() { return none }
	box := node.as_image_box() or { return none }
	if box.uses_content_replacement() { return none }
	owner := node.dom_node() or { return none }
	if !owner.is_html_image_element() { return none }
	element := owner.as_element() or { return none }
	// Nested SVG documents and unavailable/broken images retain the ordinary
	// layout path. Read the live provider, not the ImageBox's pre-relayout size.
	if available_html_svg_image_document(element) != none { return none }
	natural := available_html_image_natural_size(element) or { return none }
	image := unsafe { &dom.HTMLImageElement(element) }
	return RetainedBlockImageInput{
		source: html.html_image_element_current_src(image)
		natural: natural
	}
}

fn report_retained_block_image_reuse(inputs []RetainedInlineInput) {
	if !retained_block_image_diagnostics || retained_block_image_reported { return }
	for input in inputs {
		if input.image != none {
			retained_block_image_reported = true
			eprintln('Vox retained block images: reused decoded image geometry')
			return
		}
	}
}
