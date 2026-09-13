module svg

import dom

pub type ImageFetchDecodeHook = fn (string) !DecodedImageData

pub enum ResourceState {
	unavailable
	loading
	ready
	failed
}

pub struct ImageResource {
pub mut:
	href             string
	state            ResourceState
	intrinsic_width  ?f64
	intrinsic_height ?f64
}

pub fn (mut image ImageResource) update_href(href string) {
	image.href = href
	image.state = if href.len == 0 { .unavailable } else { .loading }
	image.intrinsic_width = none
	image.intrinsic_height = none
}

pub fn (mut image ImageResource) complete(width f64, height f64) {
	if image.state != .loading {
		return
	}
	image.intrinsic_width = width
	image.intrinsic_height = height
	image.state = .ready
}

pub fn (image ImageResource) intrinsic_aspect_ratio() ?f64 {
	width := image.intrinsic_width or { return none }
	height := image.intrinsic_height or { return none }
	if height == 0 {
		return none
	}
	return width / height
}

pub struct UseReference {
pub mut:
	href      string
	state     ResourceState
	target_id string
	shadow    ?Element
}

pub fn (mut reference UseReference) process_url(href string, document map[string]Element) {
	reference.href = href
	reference.shadow = none
	reference.target_id = ''
	if href.len == 0 {
		reference.state = .unavailable
		return
	}
	if href.starts_with('#') {
		reference.target_id = decode_fragment_identifier(href[1..])
		target := document[reference.target_id] or {
			reference.state = .failed
			return
		}
		mut visiting := map[string]bool{}
		if !valid_use_reference_tag(target.tag)
			|| use_target_has_cycle(reference.target_id, document, mut visiting) {
			reference.state = .failed
			return
		}
		reference.shadow = clone_element_tree(target)
		reference.state = .ready
		return
	}
	reference.state = .loading
}

fn use_target_has_cycle(id string, document map[string]Element, mut visiting map[string]bool) bool {
	if visiting[id] {
		return true
	}
	target := document[id] or { return false }
	visiting[id] = true
	if element_has_use_cycle(target, document, mut visiting) {
		visiting.delete(id)
		return true
	}
	visiting.delete(id)
	return false
}

fn element_has_use_cycle(element Element, document map[string]Element, mut visiting map[string]bool) bool {
	if element.tag == 'use' {
		href := element.href()
		if id := local_fragment_identifier(href) {
			if use_target_has_cycle(id, document, mut visiting) {
				return true
			}
		}
	}
	for child in element.children {
		if element_has_use_cycle(child, document, mut visiting) {
			return true
		}
	}
	return false
}

pub fn clone_element_tree(element Element) Element {
	mut cloned_children := []Element{cap: element.children.len}
	for child in element.children {
		cloned_children << clone_element_tree(child)
	}
	return Element{
		tag: element.tag
		attributes: element.attributes.clone()
		children: cloned_children
		text: element.text
		image_resource: element.image_resource
		decoded_image_data_: element.decoded_image_data_
		current_frame_index_: element.current_frame_index_
		image_fetch_decode_hook_: element.image_fetch_decode_hook_
	}
}

pub struct ScriptResource {
pub mut:
	href      string
	text      string
	processed bool
	external  bool
}

pub fn (mut script ScriptResource) process() ?string {
	if script.processed {
		return none
	}
	script.processed = true
	script.external = script.href.len > 0
	if script.external {
		return script.href
	}
	return script.text
}

pub struct DecodedImageData {
pub:
	viewbox               ?ViewBox
	width                 ?f64
	height                ?f64
	surface_bytes         []u8
	display_list_commands []string
	frame_count           int = 1
}

pub fn (image DecodedImageData) intrinsic_width() ?f64 {
	return image.width
}

pub fn (image DecodedImageData) intrinsic_height() ?f64 {
	return image.height
}

pub fn (image DecodedImageData) intrinsic_aspect_ratio() ?f64 {
	if width := image.width {
		if height := image.height {
			if width > 0 && height > 0 {
				return width / height
			}
		}
	}
	if box := image.viewbox {
		if box.width != 0 && box.height != 0 {
			return box.width / box.height
		}
	}
	return none
}

pub fn (image DecodedImageData) frame(_ int, width int, height int) ?&dom.DecodedImageFrame_ {
	if width <= 0 || height <= 0 || image.surface_bytes.len == 0 {
		return none
	}
	return dom.DecodedImageFrame_.create(&dom.Bitmap_{
		width: width
		height: height
		pitch: width * 4
		data: image.surface_bytes.clone()
	})
}
