// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HTMLImageElement.{h,cpp}. Fetching/decoding is supplied by a
// host hook; source selection, request state, dimensions, promises, events,
// animation state, lazy-size rules, and request replacement live here.
module html

import dom

pub enum ImageLoadingAttribute {
	eager
	lazy
}

pub type HTMLImageFetchHook = fn (dom.URL) !DecodedImageData

@[heap]
pub struct HTMLImageElementModel {
mut:
	document_                  &dom.Document = unsafe { nil }
	base_url_                  dom.URL
	event_target_              &dom.EventTarget = unsafe { nil }
	src_                       ?string
	srcset_                    ?string
	sizes_                     ?string
	alt_                       ?string
	width_                     ?u32
	height_                    ?u32
	loading_                   ImageLoadingAttribute
	cors_setting_              CORSSettingAttribute
	source_set_                SourceSet
	last_selected_source_      ?string
	current_request_           &ImageRequest = unsafe { nil }
	pending_request_           ?&ImageRequest
	decoded_data_              ?SharedResourceImageData
	fetch_hook_                ?HTMLImageFetchHook
	current_frame_index_       usize
	loops_completed_           usize
	animation_stopped_         bool
	visible_in_viewport_       bool = true
	update_count_              u64
	event_counts_              map[string]int
	dimension_attribute_source ?&dom.Element
}

pub fn HTMLImageElementModel.create(document &dom.Document, base_url dom.URL) &HTMLImageElementModel {
	return &HTMLImageElementModel{
		document_:        document
		base_url_:        base_url
		event_target_:    dom.EventTarget.new()
		current_request_: ImageRequest.create(document)
	}
}

pub fn (image &HTMLImageElementModel) event_target() &dom.EventTarget {
	return image.event_target_
}

fn (mut image HTMLImageElementModel) fire_event(name string) {
	image.event_counts_[name]++
	image.event_target_.dispatch_event(dom.Event.create(name, dom.EventInit{}))
}

pub fn (image &HTMLImageElementModel) event_count(name string) int {
	return image.event_counts_[name]
}

pub fn (mut image HTMLImageElementModel) set_fetch_hook(hook ?HTMLImageFetchHook) {
	image.fetch_hook_ = hook
}

pub fn (mut image HTMLImageElementModel) set_src(value ?string) {
	image.src_ = value
}

pub fn (image &HTMLImageElementModel) src() string {
	return image.src_ or { '' }
}

pub fn (mut image HTMLImageElementModel) set_srcset(value ?string) {
	image.srcset_ = value
}

pub fn (mut image HTMLImageElementModel) set_sizes(value ?string) {
	image.sizes_ = value
}

pub fn (mut image HTMLImageElementModel) set_alt(value ?string) {
	image.alt_ = value
}

pub fn (image &HTMLImageElementModel) alt() string {
	return image.alt_ or { '' }
}

pub fn (image &HTMLImageElementModel) alternative_text() ?string {
	return image.alt_
}

pub fn (mut image HTMLImageElementModel) set_width(value u64) {
	image.width_ = if value > 2147483647 { u32(0) } else { u32(value) }
}

pub fn (mut image HTMLImageElementModel) set_height(value u64) {
	image.height_ = if value > 2147483647 { u32(0) } else { u32(value) }
}

pub fn (mut image HTMLImageElementModel) set_loading(value ImageLoadingAttribute) {
	image.loading_ = value
}

pub fn (mut image HTMLImageElementModel) set_crossorigin(value ?string) {
	image.cors_setting_ = cors_setting_attribute_from_keyword(value)
}

pub fn (image &HTMLImageElementModel) crossorigin() CORSSettingAttribute {
	return image.cors_setting_
}

pub fn (image &HTMLImageElementModel) uses_srcset_or_picture() bool {
	return image.srcset_ != none
}

fn image_source_size_from_sizes(sizes ?string) f64 {
	value := sizes or { return 100.0 }
	trimmed := ascii_lowercase_string(value.trim_space())
	if trimmed.ends_with('px') {
		return trimmed[..trimmed.len - 2].f64()
	}
	return 100.0
}

pub fn (mut image HTMLImageElementModel) update_source_set() {
	image.source_set_ = create_source_set(image.src_ or { '' }, image.srcset_ or { '' },
		image_source_size_from_sizes(image.sizes_))
}

pub fn (mut image HTMLImageElementModel) select_an_image_source() ?ImageSourceAndPixelDensity {
	image.update_source_set()
	if image.source_set_.is_empty() {
		return none
	}
	return image.source_set_.select_an_image_source()
}

pub fn (image &HTMLImageElementModel) source_set() SourceSet {
	return image.source_set_
}

pub fn (mut image HTMLImageElementModel) update_the_image_data(restart_animations bool, maybe_omit_events bool) {
	image.update_count_++
	previous_url := image.current_request_.current_url()
	selection := image.select_an_image_source() or {
		image.pending_request_ = none
		image.current_request_.set_state(.broken)
		image.current_request_.set_current_url('')
		image.decoded_data_ = none
		if (image.src_ != none || image.srcset_ != none)
			&& (!maybe_omit_events || previous_url != '') {
			image.fire_event('error')
		}
		return
	}
	image.last_selected_source_ = selection.source.url
	url := dom.dom_url_parse(selection.source.url, image.base_url_, 'UTF-8') or {
		image.current_request_.set_state(.broken)
		image.pending_request_ = none
		if !maybe_omit_events || previous_url != '' {
			image.fire_event('error')
		}
		return
	}
	if previous_url == url.serialize() && image.current_request_.state() == .completely_available {
		if restart_animations {
			image.restart_the_animation()
		}
		return
	}
	mut request := ImageRequest.create(image.document_)
	request.set_current_url(url.serialize())
	request.set_current_pixel_density(f32(selection.pixel_density))
	request.set_state(.partially_available)
	image.pending_request_ = request
	fetch := image.fetch_hook_ or {
		request.set_state(.broken)
		image.pending_request_ = none
		image.current_request_ = request
		if !maybe_omit_events || previous_url != url.serialize() {
			image.fire_event('error')
		}
		return
	}

	decoded := fetch(url) or {
		request.set_state(.broken)
		image.pending_request_ = none
		image.current_request_ = request
		image.decoded_data_ = none
		if !maybe_omit_events || previous_url != url.serialize() {
			image.fire_event('error')
		}
		return
	}
	data := SharedResourceImageData{
		data: decoded
	}
	request.set_image_data(data)
	request.set_state(.completely_available)
	image.pending_request_ = none
	image.current_request_ = request
	image.decoded_data_ = data
	image.current_frame_index_ = 0
	image.loops_completed_ = 0
	image.animation_stopped_ = false
	if restart_animations {
		image.restart_the_animation()
	}
	if !maybe_omit_events || previous_url != url.serialize() {
		image.fire_event('load')
	}
}

pub fn (image &HTMLImageElementModel) complete() bool {
	if image.src_ == none && image.srcset_ == none {
		return true
	}
	if image.srcset_ == none && image.src_ or { '' } == '' {
		return true
	}
	return image.pending_request_ == none
		&& image.current_request_.state() in [.completely_available, .broken]
}

pub fn (image &HTMLImageElementModel) current_src() string {
	return image.current_request_.current_url()
}

pub fn (image &HTMLImageElementModel) decoded_image_data() ?DecodedImageData {
	data := image.decoded_data_ or { return none }
	return data.data
}

pub fn (image &HTMLImageElementModel) current_bitmap() ?&dom.ImmutableBitmap_ {
	data := image.decoded_data_ or { return none }
	return data.data.bitmap(image.current_frame_index_)
}

pub fn (image &HTMLImageElementModel) natural_width() u32 {
	data := image.decoded_data_ or { return 0 }
	width := data.data.intrinsic_width() or { return 0 }
	density := image.current_request_.current_pixel_density()
	if density <= 0 {
		return 0
	}
	return u32(width / f64(density))
}

pub fn (image &HTMLImageElementModel) natural_height() u32 {
	data := image.decoded_data_ or { return 0 }
	height := data.data.intrinsic_height() or { return 0 }
	density := image.current_request_.current_pixel_density()
	if density <= 0 {
		return 0
	}
	return u32(height / f64(density))
}

pub fn (image &HTMLImageElementModel) width() u32 {
	return image.width_ or { image.natural_width() }
}

pub fn (image &HTMLImageElementModel) height() u32 {
	return image.height_ or { image.natural_height() }
}

pub fn (image &HTMLImageElementModel) x() int {
	return 0
}

pub fn (image &HTMLImageElementModel) y() int {
	return 0
}

pub fn (image &HTMLImageElementModel) decode() &dom.Promise {
	if image.current_request_.state() == .completely_available && image.decoded_data_ != none {
		return dom.Promise.resolved(dom.js_undefined())
	}
	return dom.Promise.rejected(dom.js_string('EncodingError: image data is not available'))
}

pub fn (mut image HTMLImageElementModel) restart_the_animation() {
	image.current_frame_index_ = 0
	image.loops_completed_ = 0
	image.animation_stopped_ = false
}

pub fn (mut image HTMLImageElementModel) animate() {
	if image.animation_stopped_ {
		return
	}
	data := image.decoded_data_ or { return }
	frame_count := data.data.frame_count()
	if frame_count <= 1 {
		return
	}
	image.current_frame_index_ = (image.current_frame_index_ + 1) % frame_count
	if image.current_frame_index_ == frame_count - 1 {
		image.loops_completed_++
		loop_count := data.data.loop_count()
		if loop_count > 0 && image.loops_completed_ >= loop_count {
			image.animation_stopped_ = true
		}
	}
}

pub fn (image &HTMLImageElementModel) current_frame_index() usize {
	return image.current_frame_index_
}

pub fn (mut image HTMLImageElementModel) set_visible_in_viewport(visible bool) {
	image.visible_in_viewport_ = visible
}

pub fn (image &HTMLImageElementModel) allows_auto_sizes() bool {
	if image.loading_ != .lazy {
		return false
	}
	sizes := ascii_lowercase_string((image.sizes_ or { '' }).trim_space())
	return sizes == 'auto' || sizes.starts_with('auto,')
}

pub fn (image &HTMLImageElementModel) current_request() &ImageRequest {
	return image.current_request_
}

pub fn (image &HTMLImageElementModel) pending_request() ?&ImageRequest {
	return image.pending_request_
}

pub fn (mut image HTMLImageElementModel) set_dimension_attribute_source(source ?&dom.Element) {
	image.dimension_attribute_source = source
}

pub fn (image &HTMLImageElementModel) dimension_attribute_source() ?&dom.Element {
	return image.dimension_attribute_source
}
