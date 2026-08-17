// Copyright (c) 2020-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of NavigableContainer.{h,cpp}, HTMLIFrameElement.{h,cpp},
// HTMLObjectElement.{h,cpp}, and HTMLEmbedElement.{h,cpp}. Creating a platform
// browsing context and fetching an object resource are host operations exposed
// as hooks; all surrounding HTML state machines are represented here.
module html

import dom

pub enum InitialInsertion {
	no
	yes
}

pub struct EmbeddedDocument {
pub mut:
	url                       dom.URL
	origin                    dom.Origin
	content_type              string = 'text/html'
	completely_loaded         bool
	ready_for_post_load_tasks bool
}

@[heap]
pub struct ChildNavigable {
pub mut:
	active_document                          &EmbeddedDocument = unsafe { nil }
	target_name                              string
	history                                  []dom.URL
	has_session_history_entry_and_ready      bool
	is_delaying_load_events                  bool
	has_been_destroyed                       bool
	last_referrer_policy                     ReferrerPolicy = .strict_origin_when_cross_origin
	last_srcdoc                              ?string
	last_navigation_replaced_current_entry   bool
	current_navigation_was_initial_insertion bool
}

pub struct EmbeddedNavigationRequest {
pub:
	url               dom.URL
	referrer_policy   ReferrerPolicy
	srcdoc            ?string
	replace_history   bool
	initial_insertion InitialInsertion
}

pub type EmbeddedNavigationHook = fn (EmbeddedNavigationRequest) !

@[heap]
pub struct NavigableContainerModel {
mut:
	base_url_                      dom.URL
	owner_origin_                  dom.Origin
	name_                          string
	src_                           string
	content_navigable_             ?&ChildNavigable
	potentially_delays_load_event_ bool
	navigation_hook_               ?EmbeddedNavigationHook
}

pub fn NavigableContainerModel.create(base_url dom.URL, owner_origin dom.Origin) &NavigableContainerModel {
	return &NavigableContainerModel{
		base_url_:     base_url
		owner_origin_: owner_origin
	}
}

pub fn (mut container NavigableContainerModel) set_navigation_hook(hook ?EmbeddedNavigationHook) {
	container.navigation_hook_ = hook
}

pub fn (mut container NavigableContainerModel) set_name(value string) {
	container.name_ = value
}

pub fn (mut container NavigableContainerModel) set_src(value string) {
	container.src_ = value
}

pub fn (container &NavigableContainerModel) content_navigable() ?&ChildNavigable {
	return container.content_navigable_
}

// https://html.spec.whatwg.org/multipage/document-sequences.html#create-a-new-child-navigable
pub fn (mut container NavigableContainerModel) create_new_child_navigable() &ChildNavigable {
	document := &EmbeddedDocument{
		url:    dom.URL{
			value: 'about:blank'
		}
		origin: container.owner_origin_
	}
	navigable := &ChildNavigable{
		active_document: document
		target_name:     container.name_
		history:         [document.url]
	}
	container.content_navigable_ = navigable
	return navigable
}

// https://html.spec.whatwg.org/multipage/browsers.html#concept-bcc-content-document
pub fn (container &NavigableContainerModel) content_document() ?&EmbeddedDocument {
	mut navigable := container.content_navigable_ or { return none }
	if !navigable.active_document.origin.is_same_origin(container.owner_origin_) {
		return none
	}
	return navigable.active_document
}

pub fn (container &NavigableContainerModel) content_document_without_origin_check() ?&EmbeddedDocument {
	navigable := container.content_navigable_ or { return none }
	return navigable.active_document
}

pub fn (container &NavigableContainerModel) get_svg_document() ?&EmbeddedDocument {
	document := container.content_document() or { return none }
	return if ascii_lowercase_string(document.content_type) == 'image/svg+xml' {
		document
	} else {
		none
	}
}

// https://html.spec.whatwg.org/multipage/iframe-embed-object.html#shared-attribute-processing-steps-for-iframe-and-frame-elements
pub fn (mut container NavigableContainerModel) shared_attribute_processing_steps(initial_insertion InitialInsertion, inclusive_ancestor_urls []dom.URL) ?dom.URL {
	mut navigable := container.content_navigable_ or { return none }
	if initial_insertion == .yes && navigable.history.len > 1 {
		return none
	}
	mut url := dom.URL{
		value: 'about:blank'
	}
	if container.src_ != '' {
		url = dom.dom_url_parse(container.src_, container.base_url_, 'UTF-8') or { url }
	}
	for ancestor_url in inclusive_ancestor_urls {
		if ancestor_url.serialize().split('#')[0] == url.serialize().split('#')[0] {
			return none
		}
	}
	if initial_insertion == .yes && url.serialize() == 'about:blank' {
		navigable.active_document.url = url
	}
	return url
}

// https://html.spec.whatwg.org/multipage/iframe-embed-object.html#navigate-an-iframe-or-frame
pub fn (mut container NavigableContainerModel) navigate_an_iframe_or_frame(url dom.URL, referrer_policy ReferrerPolicy, srcdoc ?string, initial_insertion InitialInsertion) ! {
	mut navigable := container.content_navigable_ or {
		return error('InvalidStateError: container has no content navigable')
	}

	replace := !navigable.active_document.completely_loaded
	request := EmbeddedNavigationRequest{
		url:               url
		referrer_policy:   referrer_policy
		srcdoc:            srcdoc
		replace_history:   replace
		initial_insertion: initial_insertion
	}
	if hook := container.navigation_hook_ {
		hook(request)!
	}
	navigable.active_document.url = url
	navigable.active_document.content_type = if srcdoc != none {
		'text/html'
	} else {
		navigable.active_document.content_type
	}
	navigable.last_referrer_policy = referrer_policy
	navigable.last_srcdoc = srcdoc
	navigable.last_navigation_replaced_current_entry = replace
	navigable.current_navigation_was_initial_insertion = initial_insertion == .yes
	if replace && navigable.history.len > 0 {
		navigable.history[navigable.history.len - 1] = url
	} else {
		navigable.history << url
	}
}

// https://html.spec.whatwg.org/multipage/document-sequences.html#destroy-a-child-navigable
pub fn (mut container NavigableContainerModel) destroy_the_child_navigable() {
	mut navigable := container.content_navigable_ or { return }
	if navigable.has_been_destroyed {
		return
	}
	navigable.has_been_destroyed = true
	navigable.is_delaying_load_events = false
	container.content_navigable_ = none
}

pub fn (mut container NavigableContainerModel) set_potentially_delays_load_event(value bool) {
	container.potentially_delays_load_event_ = value
}

// https://html.spec.whatwg.org/multipage/iframe-embed-object.html#potentially-delays-the-load-event
pub fn (container &NavigableContainerModel) currently_delays_the_load_event() bool {
	navigable := container.content_navigable_ or { return false }
	if !navigable.has_session_history_entry_and_ready {
		return true
	}
	if !container.potentially_delays_load_event_ {
		return false
	}
	return !navigable.active_document.ready_for_post_load_tasks || navigable.is_delaying_load_events
}

pub fn (mut container NavigableContainerModel) mark_content_navigable_ready() {
	mut navigable := container.content_navigable_ or { return }
	navigable.has_session_history_entry_and_ready = true
}

@[heap]
pub struct HTMLIFrameElementModel {
pub mut:
	container &NavigableContainerModel
mut:
	srcdoc_                             ?string
	sandbox_                            ?string
	iframe_sandboxing_flag_set_         SandboxingFlagSet
	referrer_policy_                    ReferrerPolicy = .strict_origin_when_cross_origin
	loading_lazy_                       bool
	current_navigation_was_lazy_loaded_ bool
	lazy_load_resumption_steps_         ?fn ()
	event_target_                       &dom.EventTarget = unsafe { nil }
	event_counts_                       map[string]int
}

pub fn HTMLIFrameElementModel.create(base_url dom.URL, owner_origin dom.Origin) &HTMLIFrameElementModel {
	return &HTMLIFrameElementModel{
		container:     NavigableContainerModel.create(base_url, owner_origin)
		event_target_: dom.EventTarget.new()
	}
}

fn (mut iframe HTMLIFrameElementModel) fire_event(name string) {
	iframe.event_counts_[name]++
	iframe.event_target_.dispatch_event(dom.Event.create(name, dom.EventInit{}))
}

pub fn (iframe &HTMLIFrameElementModel) event_count(name string) int {
	return iframe.event_counts_[name]
}

pub fn (iframe &HTMLIFrameElementModel) event_target() &dom.EventTarget {
	return iframe.event_target_
}

pub fn (mut iframe HTMLIFrameElementModel) set_navigation_hook(hook ?EmbeddedNavigationHook) {
	iframe.container.set_navigation_hook(hook)
}

pub fn (mut iframe HTMLIFrameElementModel) set_loading_lazy(value bool) {
	iframe.loading_lazy_ = value
}

pub fn (mut iframe HTMLIFrameElementModel) set_src(value string) {
	iframe.container.set_src(value)
	if iframe.container.content_navigable() != none && iframe.srcdoc_ == none {
		iframe.process_the_iframe_attributes(.no, []) or { iframe.fire_event('error') }
	}
}

pub fn (mut iframe HTMLIFrameElementModel) set_srcdoc(value ?string) {
	iframe.srcdoc_ = value
	if iframe.container.content_navigable() != none {
		iframe.process_the_iframe_attributes(.no, []) or { iframe.fire_event('error') }
	}
}

pub fn (iframe &HTMLIFrameElementModel) srcdoc() string {
	return iframe.srcdoc_ or { '' }
}

pub fn (mut iframe HTMLIFrameElementModel) set_sandbox(value ?string) {
	iframe.sandbox_ = value
	iframe.iframe_sandboxing_flag_set_ = if directive := value {
		parse_a_sandboxing_directive(directive)
	} else {
		SandboxingFlagSet{}
	}
}

pub fn (iframe &HTMLIFrameElementModel) iframe_sandboxing_flag_set() SandboxingFlagSet {
	return iframe.iframe_sandboxing_flag_set_
}

pub fn (mut iframe HTMLIFrameElementModel) set_referrer_policy(policy ReferrerPolicy) {
	iframe.referrer_policy_ = policy
}

pub fn (mut iframe HTMLIFrameElementModel) post_connection(document_is_fully_active bool, inclusive_ancestor_urls []dom.URL) ! {
	if !document_is_fully_active {
		return
	}
	iframe.container.create_new_child_navigable()
	if sandbox := iframe.sandbox_ {
		iframe.iframe_sandboxing_flag_set_ = parse_a_sandboxing_directive(sandbox)
	}
	iframe.process_the_iframe_attributes(.yes, inclusive_ancestor_urls)!
	iframe.container.mark_content_navigable_ready()
}

// https://html.spec.whatwg.org/multipage/iframe-embed-object.html#process-the-iframe-attributes
pub fn (mut iframe HTMLIFrameElementModel) process_the_iframe_attributes(initial_insertion InitialInsertion, inclusive_ancestor_urls []dom.URL) ! {
	if iframe.container.content_navigable() == none {
		return
	}
	if srcdoc := iframe.srcdoc_ {
		iframe.set_current_navigation_was_lazy_loaded(false)
		if iframe.loading_lazy_ {
			mut iframe_ptr := &iframe
			iframe.lazy_load_resumption_steps_ = fn [mut iframe_ptr, srcdoc, initial_insertion] () {
				iframe_ptr.container.navigate_an_iframe_or_frame(dom.URL{ value: 'about:srcdoc' },
					iframe_ptr.referrer_policy_, srcdoc, initial_insertion) or {
					iframe_ptr.fire_event('error')
					return
				}
				iframe_ptr.run_iframe_load_event_steps()
			}
			iframe.set_current_navigation_was_lazy_loaded(true)
			return
		}
		iframe.container.navigate_an_iframe_or_frame(dom.URL{ value: 'about:srcdoc' },
			iframe.referrer_policy_, srcdoc, initial_insertion)!
		iframe.run_iframe_load_event_steps()
		return
	}
	url := iframe.container.shared_attribute_processing_steps(initial_insertion,
		inclusive_ancestor_urls) or { return }
	if initial_insertion == .yes && url.serialize() == 'about:blank' {
		iframe.run_iframe_load_event_steps()
		return
	}
	iframe.set_current_navigation_was_lazy_loaded(false)
	if iframe.loading_lazy_ {
		mut iframe_ptr := &iframe
		iframe.lazy_load_resumption_steps_ = fn [mut iframe_ptr, url, initial_insertion] () {
			iframe_ptr.container.navigate_an_iframe_or_frame(url, iframe_ptr.referrer_policy_,
				none, initial_insertion) or {
				iframe_ptr.fire_event('error')
				return
			}
			iframe_ptr.run_iframe_load_event_steps()
		}
		iframe.set_current_navigation_was_lazy_loaded(true)
		return
	}
	iframe.container.navigate_an_iframe_or_frame(url, iframe.referrer_policy_, none,
		initial_insertion)!
	iframe.run_iframe_load_event_steps()
}

fn (mut iframe HTMLIFrameElementModel) set_current_navigation_was_lazy_loaded(value bool) {
	iframe.current_navigation_was_lazy_loaded_ = value
	iframe.container.set_potentially_delays_load_event(!value)
}

pub fn (iframe &HTMLIFrameElementModel) current_navigation_was_lazy_loaded() bool {
	return iframe.current_navigation_was_lazy_loaded_
}

pub fn (mut iframe HTMLIFrameElementModel) resume_lazy_load() {
	if !iframe.current_navigation_was_lazy_loaded_ {
		return
	}
	iframe.lazy_load_resumption_steps_ = none
	iframe.loading_lazy_ = false
	iframe.set_current_navigation_was_lazy_loaded(false)
	iframe.process_the_iframe_attributes(.no, []) or { iframe.fire_event('error') }
}

pub fn (mut iframe HTMLIFrameElementModel) removed_from_document() {
	iframe.container.destroy_the_child_navigable()
}

pub fn (mut iframe HTMLIFrameElementModel) run_iframe_load_event_steps() {
	if iframe.container.content_navigable() == none {
		return
	}
	iframe.fire_event('load')
}

pub enum ObjectRepresentation {
	unknown
	children
	content_navigable
	image
}

pub struct ObjectResourceResponse {
pub:
	status       u16 = 200
	content_type string
	body         []u8
	bitmap       ?&dom.ImmutableBitmap_
}

pub type ObjectResourceFetchHook = fn (dom.URL) !ObjectResourceResponse

@[heap]
pub struct HTMLObjectElementModel {
pub mut:
	container &NavigableContainerModel
mut:
	data_                string
	type_                string
	classid_             ?string
	connected_           bool = true
	fully_active_        bool = true
	blocked_by_ancestor_ bool
	representation_      ObjectRepresentation = .unknown
	image_data_          ?&dom.ImmutableBitmap_
	fetch_hook_          ?ObjectResourceFetchHook
	event_target_        &dom.EventTarget = unsafe { nil }
	event_counts_        map[string]int
}

pub fn HTMLObjectElementModel.create(base_url dom.URL, owner_origin dom.Origin) &HTMLObjectElementModel {
	mut container := NavigableContainerModel.create(base_url, owner_origin)
	container.set_potentially_delays_load_event(true)
	return &HTMLObjectElementModel{
		container:     container
		event_target_: dom.EventTarget.new()
	}
}

fn (mut object HTMLObjectElementModel) fire_event(name string) {
	object.event_counts_[name]++
	object.event_target_.dispatch_event(dom.Event.create(name, dom.EventInit{}))
}

pub fn (object &HTMLObjectElementModel) event_count(name string) int {
	return object.event_counts_[name]
}

pub fn (mut object HTMLObjectElementModel) set_fetch_hook(hook ?ObjectResourceFetchHook) {
	object.fetch_hook_ = hook
}

pub fn (mut object HTMLObjectElementModel) set_environment(connected bool, fully_active bool, blocked_by_ancestor bool) {
	object.connected_ = connected
	object.fully_active_ = fully_active
	object.blocked_by_ancestor_ = blocked_by_ancestor
}

pub fn (mut object HTMLObjectElementModel) set_data(value string) {
	object.data_ = value
}

pub fn (object &HTMLObjectElementModel) data() string {
	return dom.dom_url_parse(object.data_, object.container.base_url_, 'UTF-8') or { return '' }.serialize()
}

pub fn (mut object HTMLObjectElementModel) set_type(value string) {
	object.type_ = value
}

pub fn (mut object HTMLObjectElementModel) set_classid(value ?string) {
	object.classid_ = value
}

pub fn (object &HTMLObjectElementModel) representation() ObjectRepresentation {
	return object.representation_
}

pub fn (object &HTMLObjectElementModel) image_data() ?&dom.ImmutableBitmap_ {
	return object.image_data_
}

fn object_mime_essence(value string) string {
	return ascii_lowercase_string(value.split(';')[0].trim_space())
}

fn object_mime_is_image(value string) bool {
	return object_mime_essence(value).starts_with('image/')
}

fn object_mime_is_document(value string) bool {
	essence := object_mime_essence(value)
	return essence == 'text/html' || essence == 'application/xhtml+xml'
		|| essence == 'image/svg+xml' || essence.ends_with('+xml')
}

// https://html.spec.whatwg.org/multipage/iframe-embed-object.html#object-type-detection
pub fn (mut object HTMLObjectElementModel) run_object_representation_steps() {
	if !object.connected_ || !object.fully_active_ || object.blocked_by_ancestor_
		|| object.classid_ != none {
		object.run_object_representation_fallback_steps()
		return
	}
	if object.data_ == '' {
		object.run_object_representation_fallback_steps()
		return
	}
	url := dom.dom_url_parse(object.data_, object.container.base_url_, 'UTF-8') or {
		object.fire_event('error')
		object.run_object_representation_fallback_steps()
		return
	}
	fetch := object.fetch_hook_ or {
		object.fire_event('error')
		object.run_object_representation_fallback_steps()
		return
	}

	response := fetch(url) or {
		object.fire_event('error')
		object.run_object_representation_fallback_steps()
		return
	}
	if response.status < 200 || response.status >= 300 {
		object.fire_event('error')
		object.run_object_representation_fallback_steps()
		return
	}
	mime := if response.content_type != '' { response.content_type } else { object.type_ }
	if object_mime_is_image(mime) {
		bitmap := response.bitmap or {
			object.fire_event('error')
			object.run_object_representation_fallback_steps()
			return
		}

		object.container.destroy_the_child_navigable()
		object.image_data_ = bitmap
		object.representation_ = .image
		object.fire_event('load')
		return
	}
	if object_mime_is_document(mime) {
		if object.container.content_navigable() == none {
			object.container.create_new_child_navigable()
		}
		object.container.navigate_an_iframe_or_frame(url, .strict_origin_when_cross_origin, none,
			.no) or {
			object.fire_event('error')
			object.run_object_representation_fallback_steps()
			return
		}
		if mut document := object.container.content_document_without_origin_check() {
			document.content_type = object_mime_essence(mime)
		}
		object.image_data_ = none
		object.representation_ = .content_navigable
		object.fire_event('load')
		return
	}
	object.run_object_representation_fallback_steps()
}

pub fn (mut object HTMLObjectElementModel) run_object_representation_fallback_steps() {
	object.container.destroy_the_child_navigable()
	object.image_data_ = none
	object.representation_ = .children
}

pub struct EmbeddedPresentationalHints {
pub mut:
	text_align    ?string
	width         ?f64
	height        ?f64
	margin_left   ?f64
	margin_right  ?f64
	margin_top    ?f64
	margin_bottom ?f64
	border_width  ?f64
}

// Shared legacy rendering hints used by embed/object. Values are CSS pixels;
// percentages are intentionally left to the CSS layer.
pub fn embedded_presentational_hints(attributes map[string]string, include_border bool) EmbeddedPresentationalHints {
	mut hints := EmbeddedPresentationalHints{}
	align := ascii_lowercase_string(attributes['align'])
	if align in ['center', 'middle'] {
		hints.text_align = align
	}
	if width := parse_non_negative_integer(attributes['width']) {
		hints.width = f64(width)
	}
	if height := parse_non_negative_integer(attributes['height']) {
		hints.height = f64(height)
	}
	if hspace := parse_non_negative_integer(attributes['hspace']) {
		hints.margin_left = f64(hspace)
		hints.margin_right = f64(hspace)
	}
	if vspace := parse_non_negative_integer(attributes['vspace']) {
		hints.margin_top = f64(vspace)
		hints.margin_bottom = f64(vspace)
	}
	if include_border {
		if border := parse_non_negative_integer(attributes['border']) {
			hints.border_width = f64(border)
		}
	}
	return hints
}
