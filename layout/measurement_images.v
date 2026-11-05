module layout

import css
import dom
import html
import os

const disable_extended_image_measurements = os.getenv('VOX_DISABLE_EXTENDED_IMAGE_MEASUREMENTS') != ''
const extended_image_measurement_diagnostics = os.getenv('VOX_EXTENDED_IMAGE_MEASUREMENT_DIAGNOSTICS') != ''

__global extended_image_measurement_reported bool

// These inputs belong only to the shared within-pass measurement pool. Pending
// images keep their blank ImageBox; absolute images keep their static-position
// geometry and still run final absolute layout. Never extend across-pass caches.
struct MeasurementImageInput {
	request u64
	request_state html.ImageRequestState
	request_url string
	pending_request u64
	source string
	src string
	srcset string
	sizes string
	available bool
	pending bool
	natural ?css.SizeWithAspectRatio
	box_source string
	box_natural css.SizeWithAspectRatio
	box_auto_size css.SizeWithAspectRatio
	box_resolution f64
}

fn measurement_image_input(node &Node) ?MeasurementImageInput {
	if disable_extended_image_measurements || disable_retained_block_images
		|| node.has_children() || node.is_fixed_position() { return none }
	box := node.as_image_box() or { return none }
	if box.uses_content_replacement() || box.svg_image_document() != none { return none }
	owner := node.dom_node() or { return none }
	if !owner.is_html_image_element() { return none }
	element := owner.as_element() or { return none }
	if available_html_svg_image_document(element) != none { return none }
	image := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
	available := image.is_image_available()
	pending := image.is_image_pending()
	if !available && !pending { return none }
	return MeasurementImageInput{
		request: u64(voidptr(image.current_request()))
		request_state: image.current_request().state()
		request_url: image.current_request().current_url()
		pending_request: if request := image.pending_request() { u64(voidptr(request)) } else { 0 }
		source: html.html_image_element_current_src(unsafe { &dom.HTMLImageElement(element) })
		src: element.get_attribute_value('src')
		srcset: element.get_attribute_value('srcset')
		sizes: element.get_attribute_value('sizes')
		available: available
		pending: pending
		natural: available_html_image_natural_size(element)
		box_source: box.source_
		box_natural: box.natural_size_
		box_auto_size: box.auto_content_box_size_
		box_resolution: box.source_resolution_
	}
}

fn own_image_measurement_input(input RetainedInlineInput) RetainedInlineInput {
	return RetainedInlineInput{
		...input
		text: input.text.clone()
		measurement_image: if image := input.measurement_image {
			MeasurementImageInput{
				...image
				request_url: image.request_url.clone()
				source: image.source.clone()
				src: image.src.clone()
				srcset: image.srcset.clone()
				sizes: image.sizes.clone()
				box_source: image.box_source.clone()
			}
		} else { none }
	}
}

fn report_extended_image_measurement(inputs []RetainedInlineInput) {
	if !extended_image_measurement_diagnostics || extended_image_measurement_reported { return }
	if inputs.any(it.measurement_image != none) {
		extended_image_measurement_reported = true
		eprintln('Vox extended image measurement: reused pending or absolute image geometry')
	}
}
