// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HTMLImageElement.{h,cpp}. Fetching/decoding is supplied by a
// host hook; source selection, request state, dimensions, promises, events,
// animation state, lazy-size rules, and request replacement live here.
@[has_globals]
module html

import aria
import css
import dom

pub enum ImageLoadingAttribute {
	eager
	lazy
}

pub type HTMLImageFetchHook = fn (dom.URL) !DecodedImageData

@[heap]
struct BatchingDispatcher {
mut:
	queue     []fn ()
	scheduled bool
}

__global html_image_batching_dispatcher &BatchingDispatcher

fn process_image_batch() {
	mut dispatcher := batching_dispatcher()
	dispatcher.process()
}

fn batching_dispatcher() &BatchingDispatcher {
	if html_image_batching_dispatcher == unsafe { nil } {
		html_image_batching_dispatcher = &BatchingDispatcher{}
	}
	return html_image_batching_dispatcher
}

fn (mut dispatcher BatchingDispatcher) enqueue(callback fn ()) {
	dispatcher.queue << callback
	if dispatcher.queue.len >= 16 {
		dispatcher.process()
		return
	}
	if !dispatcher.scheduled {
		dispatcher.scheduled = true
		queue_a_task(.networking, main_thread_event_loop(), none, process_image_batch)
	}
}

fn (mut dispatcher BatchingDispatcher) process() {
	queue := dispatcher.queue.clone()
	dispatcher.queue.clear()
	dispatcher.scheduled = false
	for callback in queue {
		callback()
	}
}

@[heap]
pub struct HTMLImageElementModel {
mut:
	element_                   ?&dom.HTMLImageElement
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
	last_seen_viewport_size_   [2]f64
	form_control_              ?&FormAssociatedElement
}

pub fn HTMLImageElementModel.create(document &dom.Document, base_url dom.URL) &HTMLImageElementModel {
	return &HTMLImageElementModel{
		document_: document
		base_url_: base_url
		event_target_: dom.EventTarget.new()
		current_request_: ImageRequest.create(document)
	}
}

pub fn (image &HTMLImageElementModel) event_target() &dom.EventTarget {
	return image.event_target_
}

fn (mut image HTMLImageElementModel) fire_event(name string) {
	image.event_counts_[name]++
	event := dom.Event.create(name, dom.EventInit{})
	if element := image.element_ {
		unsafe { &dom.EventTarget(element) }.dispatch_event(event)
	} else {
		image.event_target_.dispatch_event(event)
	}
}

fn image_dom_element(element &dom.HTMLImageElement) &dom.Element {
	return unsafe { &dom.Element(element) }
}

fn html_image_viewport_client_did_set_rect(target voidptr, viewport_rect dom.Rect) {
	mut image := unsafe { &HTMLImageElementModel(target) }
	image.did_set_viewport_rect(viewport_rect)
}

fn image_viewport_client(image &HTMLImageElementModel) dom.ViewportClient {
	return dom.ViewportClient{
		target: voidptr(image)
		did_set_viewport_rect: html_image_viewport_client_did_set_rect
	}
}

// Return the translated HTMLImageElement state associated with a concrete DOM
// image, materializing the state on first use just as initialize() does in C++.
pub fn html_image_element_model_for_dom_element(element &dom.HTMLImageElement) &HTMLImageElementModel {
	if element.image_element_model_ != unsafe { nil } {
		return unsafe { &HTMLImageElementModel(element.image_element_model_) }
	}
	dom_element := image_dom_element(element)
	mut model := HTMLImageElementModel.create(dom_element.document(), dom_element.document().base_url())
	model.element_ = element
	model.src_ = dom_element.get_attribute('src')
	model.srcset_ = dom_element.get_attribute('srcset')
	model.sizes_ = dom_element.get_attribute('sizes')
	model.alt_ = dom_element.get_attribute('alt')
	model.loading_ = if ascii_lowercase_string(dom_element.get_attribute_value('loading')) == 'lazy' {
		.lazy
	} else {
		.eager
	}
	model.cors_setting_ = cors_setting_attribute_from_keyword(dom_element.get_attribute('crossorigin'))
	model.form_control_ = FormAssociatedElement.create(dom_element)
	mut mutable_element := unsafe { &dom.HTMLImageElement(element) }
	mutable_element.image_element_model_ = voidptr(model)
	mut document := unsafe { &dom.Document(dom_element.document()) }
	document.register_viewport_client(image_viewport_client(model))
	return model
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
	if image.srcset_ != none {
		return true
	}
	if element := image.element_ {
		if parent := image_dom_element(element).as_node().parent_element() {
			return parent.is_html_element() && parent.local_name() == 'picture'
		}
	}
	return false
}

pub fn (mut image HTMLImageElementModel) update_source_set() {
	if element := image.element_ {
		dom_element := image_dom_element(element)
		if parent := dom_element.as_node().parent_element() {
			if parent.is_html_element() && parent.local_name() == 'picture' {
				for child_node in parent.as_node().children_as_vector() {
					child := child_node.as_element() or { continue }
					if child == dom_element {
						break
					}
					if !child.is_html_element() || child.local_name() != 'source' || !child.has_attribute('srcset') {
						continue
					}
					mut source_set := parse_a_srcset_attribute(child.get_attribute_value('srcset'))
					if source_set.is_empty() {
						continue
					}
					if child.has_attribute('media') {
						media_query := css.parse_media_query(css.ParsingParams{
							document: dom_element.document()
						}, child.get_attribute_value('media')) or { continue }
						if !media_query.evaluate(dom_element.document()) {
							continue
						}
					}
					source_set.source_size = parse_a_sizes_attribute(dom_element, child.get_attribute_value('sizes'), element)
					if child.has_attribute('type')
						&& !is_supported_image_type(child.get_attribute_value('type')) {
						continue
					}
					source_set.normalize_source_densities(source_set.source_size)
					image.source_set_ = source_set
					if child.has_attribute('width') || child.has_attribute('height') {
						image.set_dimension_attribute_source(child)
					} else {
						image.set_dimension_attribute_source(none)
					}
					return
				}
			}
		}
		image.src_ = dom_element.get_attribute('src')
		image.srcset_ = dom_element.get_attribute('srcset')
		image.sizes_ = dom_element.get_attribute('sizes')
	}
	image.set_dimension_attribute_source(none)
	if element := image.element_ {
		dom_element := image_dom_element(element)
		image.source_set_ = create_source_set(image.src_ or { '' }, image.srcset_ or { '' }, parse_a_sizes_attribute(dom_element, image.sizes_ or { '' }, element))
		return
	}
	image.source_set_ = create_source_set(image.src_ or { '' }, image.srcset_ or { '' }, 100.0)
}

// https://html.spec.whatwg.org/multipage/images.html#update-the-source-set
fn update_the_source_set(element &dom.Element) {
	if !element.is_html_element() {
		return
	}
	if element.local_name() == 'img' {
		image_element := unsafe { &dom.HTMLImageElement(element) }
		mut model := html_image_element_model_for_dom_element(image_element)
		model.update_source_set()
	}
	// The upstream link-element branch remains a specification TODO.
}

fn is_supported_image_type(type_ string) bool {
	essence := ascii_lowercase_string(type_.split(';')[0].trim_space())
	if essence == '' {
		return true
	}
	return essence in ['image/bmp', 'image/gif', 'image/vnd.microsoft.icon', 'image/x-icon',
		'image/jpeg', 'image/jpg', 'image/pjpeg', 'image/jxl', 'image/png', 'image/apng',
		'image/x-png', 'image/tiff', 'image/tinyvg', 'image/webp', 'image/svg+xml']
}

pub fn (mut image HTMLImageElementModel) select_an_image_source() ?ImageSourceAndPixelDensity {
	if element := image.element_ {
		update_the_source_set(image_dom_element(element))
	} else {
		image.update_source_set()
	}
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
	image.update_the_image_data_impl(restart_animations, maybe_omit_events, image.update_count_)
}

pub fn (mut image HTMLImageElementModel) update_the_image_data_impl(restart_animations bool, maybe_omit_events bool, update_the_image_data_count u64) {
	if update_the_image_data_count != image.update_count_ || (image.element_ != none && !image.document_.is_fully_active()) {
		return
	}
	previous_url := image.current_request_.current_url()
	selection := image.select_an_image_source() or {
		image.pending_request_ = none
		image.current_request_.set_state(.broken)
		image.current_request_.set_current_url('')
		image.decoded_data_ = none
		if (image.src_ != none || image.srcset_ != none) && (!maybe_omit_events || previous_url != '') {
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
	return image.pending_request_ == none && image.current_request_.state() in [
		.completely_available,
		.broken,
	]
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
	element := image.element_ or { return 0 }
	return html_image_element_x(element)
}

pub fn (image &HTMLImageElementModel) y() int {
	element := image.element_ or { return 0 }
	return html_image_element_y(element)
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

pub fn (image &HTMLImageElementModel) to_html_element() ?&dom.Element {
	element := image.element_ or { return none }
	return image_dom_element(element)
}

pub fn (image &HTMLImageElementModel) is_html_image_element() bool {
	_ = image
	return true
}

pub fn (image &HTMLImageElementModel) supports_dimension_attributes() bool {
	_ = image
	return true
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
	if image.dimension_attribute_source == source {
		return
	}
	image.dimension_attribute_source = source
	if element := image.element_ {
		mut dom_image := unsafe { &dom.HTMLImageElement(element) }
		dom_image.dimension_attribute_source_ = source
		mut node := unsafe { &dom.Node(image_dom_element(element).as_node()) }
		node.set_needs_style_update(true)
	}
}

pub fn (image &HTMLImageElementModel) dimension_attribute_source() ?&dom.Element {
	return image.dimension_attribute_source
}

pub fn (mut image HTMLImageElementModel) set_source_set(source_set SourceSet) {
	image.source_set_ = source_set
}

pub fn (image &HTMLImageElementModel) immutable_bitmap() ?&dom.ImmutableBitmap_ {
	return image.current_bitmap()
}

pub fn (image &HTMLImageElementModel) default_image_bitmap_sized(_ int, _ int) ?&dom.ImmutableBitmap_ {
	data := image.current_request_.image_data() or { return none }
	return data.data.bitmap(0)
}

pub fn (image &HTMLImageElementModel) is_image_available() bool {
	return image.current_request_.is_available()
}

pub fn (image &HTMLImageElementModel) intrinsic_width() ?f64 {
	data := image.current_request_.image_data() or { return none }
	return data.data.intrinsic_width()
}

pub fn (image &HTMLImageElementModel) intrinsic_height() ?f64 {
	data := image.current_request_.image_data() or { return none }
	return data.data.intrinsic_height()
}

pub fn (image &HTMLImageElementModel) intrinsic_aspect_ratio() ?f64 {
	data := image.current_request_.image_data() or { return none }
	return data.data.intrinsic_aspect_ratio()
}

pub fn (image &HTMLImageElementModel) current_image_bitmap_sized(_ int, _ int) ?&dom.ImmutableBitmap_ {
	data := image.current_request_.image_data() or { return none }
	return data.data.bitmap(image.current_frame_index_)
}

// https://html.spec.whatwg.org/multipage/images.html#upgrade-the-pending-request-to-the-current-request
pub fn (mut image HTMLImageElementModel) upgrade_pending_request_to_current_request() {
	pending := image.pending_request_ or { return }
	image.current_request_ = pending
	image.pending_request_ = none
	image.decoded_data_ = pending.image_data()
}

pub fn (mut image HTMLImageElementModel) handle_failed_fetch() {
	image.fire_event('error')
}

// This is the translated completion boundary used by asynchronous hosts. The
// compact host hook completes synchronously, while SharedResourceRequest users
// can call this after their callbacks have populated image_request.
pub fn (mut image HTMLImageElementModel) add_callbacks_to_image_request(image_request &ImageRequest, maybe_omit_events bool, url_string string, previous_url string, update_the_image_data_count u64) {
	if update_the_image_data_count != image.update_count_ {
		return
	}
	if data := image_request.image_data() {
		mut request := unsafe { &ImageRequest(image_request) }
		request.set_state(.completely_available)
		pending_is_request := if pending := image.pending_request_ {
			pending == image_request
		} else {
			false
		}
		if pending_is_request {
			image.upgrade_pending_request_to_current_request()
		} else {
			image.current_request_ = image_request
		}
		image.decoded_data_ = data
		image.current_frame_index_ = 0
		image.loops_completed_ = 0
		image.animation_stopped_ = false
		if !maybe_omit_events || previous_url != url_string {
			image.fire_event('load')
		}
		if element := image.element_ {
			mut node := unsafe { &dom.Node(image_dom_element(element).as_node()) }
			node.set_needs_style_update(true)
			node.set_needs_layout_update(.html_image_element_update_the_image_data)
		}
		return
	}
	mut request := unsafe { &ImageRequest(image_request) }
	request.set_state(.broken)
	pending_is_request := if pending := image.pending_request_ {
		pending == image_request
	} else {
		false
	}
	if pending_is_request {
		image.upgrade_pending_request_to_current_request()
	}
	if !maybe_omit_events || previous_url != url_string {
		image.handle_failed_fetch()
	}
}

pub fn (mut image HTMLImageElementModel) did_set_viewport_rect(viewport_rect dom.Rect) {
	if viewport_rect.size() == image.last_seen_viewport_size_ {
		return
	}
	image.last_seen_viewport_size_ = viewport_rect.size()
	image.react_to_changes_in_the_environment()
}

// https://html.spec.whatwg.org/multipage/images.html#img-environment-changes
pub fn (mut image HTMLImageElementModel) react_to_changes_in_the_environment() {
	if !image.uses_srcset_or_picture() || image.pending_request_ != none {
		return
	}
	if image.element_ != none && !image.document_.is_fully_active() {
		return
	}
	selected := image.select_an_image_source() or { return }
	last_source := image.last_selected_source_ or { '' }
	if selected.source.url == last_source && f32(selected.pixel_density) == image.current_request_.current_pixel_density() {
		return
	}
	image.update_the_image_data(false, false)
	if element := image.element_ {
		mut node := unsafe { &dom.Node(image_dom_element(element).as_node()) }
		node.set_needs_style_update(true)
		node.set_needs_layout_update(.html_image_element_react_to_changes_in_the_environment)
	}
}

pub fn (mut image HTMLImageElementModel) adopted_from(old_document &dom.Document) {
	old_document_mut := unsafe { &dom.Document(old_document) }
	mut mutable_old_document := old_document_mut
	mutable_old_document.unregister_viewport_client(image_viewport_client(&image))
	if element := image.element_ {
		image.document_ = image_dom_element(element).document()
		image.base_url_ = image.document_.base_url()
	}
	mut document := unsafe { &dom.Document(image.document_) }
	document.register_viewport_client(image_viewport_client(&image))
	if mut form_control := image.form_control_ {
		form_control.reset_form_owner()
	}
}

pub fn html_image_element_adopted_from(element &dom.HTMLImageElement, old_document &dom.Document) {
	mut node := unsafe { &dom.Node(image_dom_element(element).as_node()) }
	node.adopted_from(old_document)
	mut model := html_image_element_model_for_dom_element(element)
	model.adopted_from(old_document)
}

pub fn html_image_element_alternative_text(element &dom.HTMLImageElement) ?string {
	return image_dom_element(element).get_attribute('alt')
}

pub fn html_image_element_form_associated_element_attribute_changed(element &dom.HTMLImageElement, name string, old_value ?string, value ?string, namespace_ ?string) {
	html_element_attribute_changed(unsafe { &dom.HTMLElement(element) }, name, old_value, value, namespace_)
	if namespace_ != none {
		return
	}
	mut model := html_image_element_model_for_dom_element(element)
	match name.to_lower() {
		'crossorigin' { model.set_crossorigin(value) }
		'src' {
			model.set_src(value)
			model.update_the_image_data(true, false)
		}
		'srcset' {
			model.set_srcset(value)
			model.update_the_image_data(true, false)
		}
		'sizes' { model.set_sizes(value) }
		'alt' {
			model.set_alt(value)
			mut node := unsafe { &dom.Node(image_dom_element(element).as_node()) }
			node.set_needs_layout_update(.html_image_element_update_the_image_data)
		}
		'loading' {
			model.set_loading(if ascii_lowercase_string(value or { '' }) == 'lazy' {
				.lazy
			} else {
				.eager
			})
		}
		'form' {
			if mut form_control := model.form_control_ {
				form_control.form_node_attribute_changed(name)
			}
		}
		else {}
	}
}

pub fn html_image_element_dimension_attribute_source(element &dom.HTMLImageElement) &dom.Element {
	model := html_image_element_model_for_dom_element(element)
	return model.dimension_attribute_source() or { image_dom_element(element) }
}

pub fn html_image_element_set_dimension_attribute_source(element &dom.HTMLImageElement, source ?&dom.Element) {
	mut model := html_image_element_model_for_dom_element(element)
	model.set_dimension_attribute_source(source)
}

pub fn html_image_element_immutable_bitmap(element &dom.HTMLImageElement) ?&dom.ImmutableBitmap_ {
	return html_image_element_model_for_dom_element(element).immutable_bitmap()
}

pub fn html_image_element_default_image_bitmap_sized(element &dom.HTMLImageElement, width int, height int) ?&dom.ImmutableBitmap_ {
	return html_image_element_model_for_dom_element(element).default_image_bitmap_sized(width, height)
}

pub fn html_image_element_is_image_available(element &dom.HTMLImageElement) bool {
	return html_image_element_model_for_dom_element(element).is_image_available()
}

pub fn html_image_element_intrinsic_width(element &dom.HTMLImageElement) ?f64 {
	return html_image_element_model_for_dom_element(element).intrinsic_width()
}

pub fn html_image_element_intrinsic_height(element &dom.HTMLImageElement) ?f64 {
	return html_image_element_model_for_dom_element(element).intrinsic_height()
}

pub fn html_image_element_intrinsic_aspect_ratio(element &dom.HTMLImageElement) ?f64 {
	return html_image_element_model_for_dom_element(element).intrinsic_aspect_ratio()
}

pub fn html_image_element_current_image_bitmap_sized(element &dom.HTMLImageElement, width int, height int) ?&dom.ImmutableBitmap_ {
	return html_image_element_model_for_dom_element(element).current_image_bitmap_sized(width, height)
}

pub fn html_image_element_set_visible_in_viewport(element &dom.HTMLImageElement, visible bool) {
	mut model := html_image_element_model_for_dom_element(element)
	model.set_visible_in_viewport(visible)
}

pub fn html_image_element_width(element &dom.HTMLImageElement) u32 {
	dom_element := image_dom_element(element)
	mut document := unsafe { &dom.Document(dom_element.document()) }
	document.update_layout_if_needed_for_node(dom_element.as_node(), .html_image_element_width)
	if layout_node := dom_element.as_node().layout_node() {
		if layout_node.has_geometry_ {
			return u32(layout_node.content_width_)
		}
	}
	if width := parse_non_negative_integer(dom_element.get_attribute_value('width')) {
		if width <= 2147483647 {
			return width
		}
	}
	return html_image_element_model_for_dom_element(element).natural_width()
}

pub fn html_image_element_set_width(element &dom.HTMLImageElement, width u64) {
	actual := if width > 2147483647 { u64(0) } else { width }
	mut dom_element := image_dom_element(element)
	old_value := dom_element.get_attribute('width')
	dom_element.set_attribute_value('width', actual.str())
	html_image_element_form_associated_element_attribute_changed(element, 'width', old_value, actual.str(), none)
	mut model := html_image_element_model_for_dom_element(element)
	model.set_width(actual)
}

pub fn html_image_element_height(element &dom.HTMLImageElement) u32 {
	dom_element := image_dom_element(element)
	mut document := unsafe { &dom.Document(dom_element.document()) }
	document.update_layout_if_needed_for_node(dom_element.as_node(), .html_image_element_height)
	if layout_node := dom_element.as_node().layout_node() {
		if layout_node.has_geometry_ {
			return u32(layout_node.content_height_)
		}
	}
	if height := parse_non_negative_integer(dom_element.get_attribute_value('height')) {
		if height <= 2147483647 {
			return height
		}
	}
	return html_image_element_model_for_dom_element(element).natural_height()
}

pub fn html_image_element_set_height(element &dom.HTMLImageElement, height u64) {
	actual := if height > 2147483647 { u64(0) } else { height }
	mut dom_element := image_dom_element(element)
	old_value := dom_element.get_attribute('height')
	dom_element.set_attribute_value('height', actual.str())
	html_image_element_form_associated_element_attribute_changed(element, 'height', old_value, actual.str(), none)
	mut model := html_image_element_model_for_dom_element(element)
	model.set_height(actual)
}

pub fn html_image_element_natural_width(element &dom.HTMLImageElement) u32 {
	return html_image_element_model_for_dom_element(element).natural_width()
}

pub fn html_image_element_natural_height(element &dom.HTMLImageElement) u32 {
	return html_image_element_model_for_dom_element(element).natural_height()
}

pub fn html_image_element_x(element &dom.HTMLImageElement) int {
	dom_element := image_dom_element(element)
	mut document := unsafe { &dom.Document(dom_element.document()) }
	document.update_layout_if_needed_for_node(dom_element.as_node(), .html_image_element_x)
	layout_node := dom_element.as_node().layout_node() or { return 0 }
	return if layout_node.has_geometry_ { int(layout_node.border_box_.x) } else { 0 }
}

pub fn html_image_element_y(element &dom.HTMLImageElement) int {
	dom_element := image_dom_element(element)
	mut document := unsafe { &dom.Document(dom_element.document()) }
	document.update_layout_if_needed_for_node(dom_element.as_node(), .html_image_element_y)
	layout_node := dom_element.as_node().layout_node() or { return 0 }
	return if layout_node.has_geometry_ { int(layout_node.border_box_.y) } else { 0 }
}

pub fn html_image_element_complete(element &dom.HTMLImageElement) bool {
	return html_image_element_model_for_dom_element(element).complete()
}

pub fn html_image_element_current_src(element &dom.HTMLImageElement) string {
	return html_image_element_model_for_dom_element(element).current_src()
}

pub fn html_image_element_decode(element &dom.HTMLImageElement) &dom.Promise {
	return html_image_element_model_for_dom_element(element).decode()
}

pub fn html_image_element_default_role(element &dom.HTMLImageElement) aria.Role {
	return if image_dom_element(element).get_attribute_value('alt') != '' {
		.image
	} else {
		.none_
	}
}

pub fn html_image_element_uses_srcset_or_picture(element &dom.HTMLImageElement) bool {
	return html_image_element_model_for_dom_element(element).uses_srcset_or_picture()
}

pub fn html_image_element_update_the_image_data(element &dom.HTMLImageElement, restart_animations bool, maybe_omit_events bool) {
	mut model := html_image_element_model_for_dom_element(element)
	model.update_the_image_data(restart_animations, maybe_omit_events)
}

pub fn html_image_element_update_the_image_data_impl(element &dom.HTMLImageElement, restart_animations bool, maybe_omit_events bool, update_the_image_data_count u64) {
	mut model := html_image_element_model_for_dom_element(element)
	model.update_the_image_data_impl(restart_animations, maybe_omit_events, update_the_image_data_count)
}

pub fn html_image_element_add_callbacks_to_image_request(element &dom.HTMLImageElement, image_request &ImageRequest, maybe_omit_events bool, url_string string, previous_url string, update_the_image_data_count u64) {
	mut model := html_image_element_model_for_dom_element(element)
	model.add_callbacks_to_image_request(image_request, maybe_omit_events, url_string, previous_url, update_the_image_data_count)
}

pub fn html_image_element_did_set_viewport_rect(element &dom.HTMLImageElement, viewport_rect dom.Rect) {
	mut model := html_image_element_model_for_dom_element(element)
	model.did_set_viewport_rect(viewport_rect)
}

pub fn html_image_element_react_to_changes_in_the_environment(element &dom.HTMLImageElement) {
	mut model := html_image_element_model_for_dom_element(element)
	model.react_to_changes_in_the_environment()
}

pub fn html_image_element_upgrade_pending_request_to_current_request(element &dom.HTMLImageElement) {
	mut model := html_image_element_model_for_dom_element(element)
	model.upgrade_pending_request_to_current_request()
}

pub fn html_image_element_handle_failed_fetch(element &dom.HTMLImageElement) {
	mut model := html_image_element_model_for_dom_element(element)
	model.handle_failed_fetch()
}

pub fn html_image_element_restart_the_animation(element &dom.HTMLImageElement) {
	mut model := html_image_element_model_for_dom_element(element)
	model.restart_the_animation()
}

pub fn html_image_element_select_an_image_source(element &dom.HTMLImageElement) ?ImageSourceAndPixelDensity {
	mut model := html_image_element_model_for_dom_element(element)
	return model.select_an_image_source()
}

pub fn html_image_element_set_source_set(element &dom.HTMLImageElement, source_set SourceSet) {
	mut model := html_image_element_model_for_dom_element(element)
	model.set_source_set(source_set)
}

pub fn html_image_element_animate(element &dom.HTMLImageElement) {
	mut model := html_image_element_model_for_dom_element(element)
	model.animate()
}

pub fn html_image_element_allows_auto_sizes(element &dom.HTMLImageElement) bool {
	return html_image_element_model_for_dom_element(element).allows_auto_sizes()
}

pub fn html_image_element_decoded_image_data(element &dom.HTMLImageElement) ?DecodedImageData {
	return html_image_element_model_for_dom_element(element).decoded_image_data()
}
