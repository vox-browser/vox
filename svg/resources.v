@[has_globals]
module svg

import dom

pub type ImageFetchDecodeHook = fn (string) !&DecodedImageData

pub type DecodedImageUpdateHook = fn (u64)

__global (
	svg_next_vector_content_identity u64
)

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

@[heap]
pub struct DecodedImageData {
pub:
	viewbox               ?ViewBox
	width                 ?f64
	height                ?f64
	surface_bytes         []u8
	display_list_commands []string
	frame_count           int = 1
mut:
	vector_content_identity_             u64
	cached_rendered_frames               map[string]&dom.DecodedImageFrame_
	is_recording_display_list_           bool
	has_pending_client_notification_     bool
	notification_hook_                   ?DecodedImageUpdateHook
	delivered_client_notification_count_ u64
}

pub fn DecodedImageData.next_vector_content_identity() u64 {
	if svg_next_vector_content_identity == 0 {
		svg_next_vector_content_identity = 1
	}
	identity := svg_next_vector_content_identity
	svg_next_vector_content_identity++
	return identity
}

fn (mut image DecodedImageData) ensure_vector_content_identity() {
	if image.vector_content_identity_ == 0 {
		image.vector_content_identity_ = DecodedImageData.next_vector_content_identity()
	}
}

pub fn (image &DecodedImageData) vector_content_identity() u64 {
	return image.vector_content_identity_
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

pub fn (mut image DecodedImageData) frame(_ int, width int, height int) ?&dom.DecodedImageFrame_ {
	if width <= 0 || height <= 0 || image.surface_bytes.len == 0 {
		return none
	}
	key := '${width}x${height}'
	if frame := image.cached_rendered_frames[key] {
		return frame
	}
	if image.cached_rendered_frames.len > 10 {
		for cached_key, _ in image.cached_rendered_frames {
			image.cached_rendered_frames.delete(cached_key)
			break
		}
	}
	frame := dom.DecodedImageFrame_.create(&dom.Bitmap_{
		width: width
		height: height
		pitch: width * 4
		data: image.surface_bytes.clone()
	})
	image.cached_rendered_frames[key] = frame
	return frame
}

pub fn (mut image DecodedImageData) current_frame(width int, height int) ?&dom.DecodedImageFrame_ {
	return image.frame(0, width, height)
}

pub fn (mut image DecodedImageData) default_frame(width int, height int) ?&dom.DecodedImageFrame_ {
	// Animated SVG is not supported yet, matching upstream's current fallback.
	return image.current_frame(width, height)
}

pub fn (image &DecodedImageData) external_memory_size() usize {
	mut size := usize(image.surface_bytes.len)
	for _, frame in image.cached_rendered_frames {
		frame_size := usize(frame.bitmap().data.len)
		if usize(-1) - size < frame_size {
			return usize(-1)
		}
		size += frame_size
	}
	return size
}

pub fn (image &DecodedImageData) has_active_view_box() bool {
	return image.viewbox != none
}

pub fn (mut image DecodedImageData) begin_recording_display_list() {
	image.is_recording_display_list_ = true
}

pub fn (mut image DecodedImageData) end_recording_display_list() {
	image.is_recording_display_list_ = false
}

pub fn (mut image DecodedImageData) invalidate_cached_rendering() {
	image.vector_content_identity_ = DecodedImageData.next_vector_content_identity()
	image.cached_rendered_frames.clear()
}

pub fn (mut image DecodedImageData) did_request_frame() {
	if image.is_recording_display_list_ {
		return
	}
	image.invalidate_cached_rendering()
	image.has_pending_client_notification_ = true
}

pub fn (mut image DecodedImageData) set_notification_hook(hook DecodedImageUpdateHook) {
	image.notification_hook_ = hook
}

// Ladybird dispatches this on the next event-loop turn. The portable SVG layer
// exposes the same coalesced pending state so its host can deliver it at its
// event-loop boundary.
pub fn (mut image DecodedImageData) deliver_pending_client_notification() bool {
	if !image.has_pending_client_notification_ {
		return false
	}
	image.has_pending_client_notification_ = false
	image.delivered_client_notification_count_++
	if hook := image.notification_hook_ {
		hook(image.vector_content_identity_)
	}
	return true
}

pub fn (image &DecodedImageData) has_pending_client_notification() bool {
	return image.has_pending_client_notification_
}

pub fn (image &DecodedImageData) delivered_client_notification_count() u64 {
	return image.delivered_client_notification_count_
}
