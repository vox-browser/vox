// Copyright (c) 2020-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of NavigableContainer.{h,cpp}, HTMLIFrameElement.{h,cpp},
// HTMLObjectElement.{h,cpp}, and HTMLEmbedElement.{h,cpp}. Creating a platform
// browsing context and fetching an object resource are host operations exposed
// as hooks; all surrounding HTML state machines are represented here.
@[has_globals]
module html

import dom
import platform

pub enum InitialInsertion {
	no
	yes
}

pub struct EmbeddedDocument {
pub mut:
	url                        dom.URL
	origin                     dom.Origin
	active_sandboxing_flags    SandboxingFlagSet
	content_type               string = 'text/html'
	completely_loaded          bool
	ready_for_post_load_tasks  bool
	anything_delays_load_event bool
	body_needs_style_update    bool
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
	has_pending_navigations                  bool
	ongoing_navigation_is_navigation         bool
	last_referrer_policy                     ReferrerPolicy = .strict_origin_when_cross_origin
	last_srcdoc                              ?string
	last_navigation_replaced_current_entry   bool
	current_navigation_was_initial_insertion bool
	active_window_proxy                      ?&dom.WindowProxy
}

pub fn (navigable &ChildNavigable) has_session_history_entry_and_ready_for_navigation() bool {
	return navigable.has_session_history_entry_and_ready
}

pub fn (mut navigable ChildNavigable) set_has_session_history_entry_and_ready_for_navigation() {
	navigable.has_session_history_entry_and_ready = true
}

// https://html.spec.whatwg.org/multipage/iframe-embed-object.html#potentially-delays-the-load-event
pub fn (navigable &ChildNavigable) delays_the_load_event_of_its_container() bool {
	if navigable.active_document == unsafe { nil } {
		return true
	}
	if !navigable.active_document.ready_for_post_load_tasks || navigable.is_delaying_load_events {
		return true
	}
	return navigable.active_document.anything_delays_load_event
}

pub struct EmbeddedNavigationRequest {
pub:
	url               dom.URL
	referrer_policy   ReferrerPolicy
	srcdoc            ?string
	replace_history   bool
	initial_insertion InitialInsertion
}

pub type EmbeddedNavigationHook = fn(EmbeddedNavigationRequest) !

@[heap]
pub struct NavigableContainerModel {
mut:
	base_url_                      dom.URL
	owner_origin_                  dom.Origin
	document_                      ?&dom.Document
	name_                          string
	src_                           string
	content_navigable_             ?&ChildNavigable
	creation_sandboxing_flags_     SandboxingFlagSet
	potentially_delays_load_event_ bool = true
	navigation_hook_               ?EmbeddedNavigationHook
}

__global navigable_container_instances []&NavigableContainerModel

pub fn NavigableContainerModel.create(base_url dom.URL, owner_origin dom.Origin) &NavigableContainerModel {
	// The instance list is process-wide. A container created in scratch
	// storage is made persistent; one in a document arena leaves the list
	// when that arena is released, as upstream's weak instance set does.
	transient := platform.transient_arena_entered()
	storage := if transient { unsafe { &platform.RetainedArena(nil) } } else { platform.current_retained_arena() }
	record_storage := platform.enter_persistent_if(transient)
	container := &NavigableContainerModel{
		base_url_: base_url
		owner_origin_: owner_origin
	}
	platform.leave_persistent(record_storage)
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	navigable_container_instances << container
	if storage != unsafe { nil } {
		mut owner := unsafe { &platform.RetainedArena(storage) }
		owner.add_cleanup(fn [container] () { remove_navigable_container_instance(container) })
	}
	return container
}

fn remove_navigable_container_instance(container &NavigableContainerModel) {
	for index, candidate in navigable_container_instances {
		if voidptr(candidate) == voidptr(container) {
			navigable_container_instances.delete(index)
			return
		}
	}
}

pub fn navigable_container_all_instances() []&NavigableContainerModel {
	return navigable_container_instances.clone()
}

pub fn navigable_container_navigable_container_with_content_navigable(navigable &ChildNavigable) ?&NavigableContainerModel {
	for container in navigable_container_instances {
		if content_navigable := container.content_navigable() {
			if content_navigable == navigable {
				return container
			}
		}
	}
	return none
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

pub fn (mut container NavigableContainerModel) set_creation_sandboxing_flags(flags SandboxingFlagSet) {
	container.creation_sandboxing_flags_ = flags
}

pub fn (container &NavigableContainerModel) content_navigable() ?&ChildNavigable {
	return container.content_navigable_
}

// https://html.spec.whatwg.org/multipage/document-sequences.html#create-a-new-child-navigable
pub fn (mut container NavigableContainerModel) create_new_child_navigable() &ChildNavigable {
	document := &EmbeddedDocument{
		url: dom.URL{
			value: 'about:blank'
		}
		origin: determine_the_origin(dom.url_about_blank(), container.creation_sandboxing_flags_, container.owner_origin_)
		active_sandboxing_flags: container.creation_sandboxing_flags_
	}
	navigable := &ChildNavigable{
		active_document: document
		target_name: container.name_
		history: [document.url]
		active_window_proxy: &dom.WindowProxy{}
	}
	container.content_navigable_ = navigable
	container_pointer := voidptr(&container)
	navigable_pointer := voidptr(navigable)
	queue_a_task(.navigation_and_traversal, main_thread_event_loop(), none, fn [container_pointer, navigable_pointer] () {
		mut mutable_container := unsafe { &NavigableContainerModel(container_pointer) }
		mut current := mutable_container.content_navigable_ or { return }
		if voidptr(current) != navigable_pointer || current.has_been_destroyed {
			return
		}
		mutable_container.mark_content_navigable_ready()
	})
	return navigable
}

// https://html.spec.whatwg.org/multipage/browsers.html#concept-bcc-content-document
pub fn (container &NavigableContainerModel) content_document() ?&EmbeddedDocument {
	mut navigable := container.content_navigable_ or { return none }
	// During navigation there is a window after the old active document is
	// destroyed and before its replacement is installed.
	if navigable.active_document == unsafe { nil } {
		return none
	}
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

pub fn (container &NavigableContainerModel) content_window() ?&dom.WindowProxy {
	navigable := container.content_navigable_ or { return none }
	return navigable.active_window_proxy
}

pub fn navigable_container_content_window(container &NavigableContainerModel) ?&dom.WindowProxy {
	return container.content_window()
}

pub fn navigable_container_shared_attribute_processing_steps_for_iframe_and_frame(container &NavigableContainerModel, initial_insertion InitialInsertion, inclusive_ancestor_urls []dom.URL) ?dom.URL {
	mut mutable_container := unsafe { &NavigableContainerModel(container) }
	return mutable_container.shared_attribute_processing_steps(initial_insertion, inclusive_ancestor_urls)
}

// https://html.spec.whatwg.org/multipage/iframe-embed-object.html#shared-attribute-processing-steps-for-iframe-and-frame-elements
pub fn (mut container NavigableContainerModel) shared_attribute_processing_steps(initial_insertion InitialInsertion, inclusive_ancestor_urls []dom.URL) ?dom.URL {
	mut navigable := container.content_navigable_ or { return none }
	if initial_insertion == .yes
		&& (navigable.has_pending_navigations || navigable.ongoing_navigation_is_navigation) {
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

	// Only the initial insertion replaces an incomplete initial document.
	// Attribute-driven navigations may run before the previous document fires
	// load, but must still create a new history entry.
	replace := initial_insertion == .yes && !navigable.active_document.completely_loaded
	request := EmbeddedNavigationRequest{
		url: url
		referrer_policy: referrer_policy
		srcdoc: srcdoc
		replace_history: replace
		initial_insertion: initial_insertion
	}
	if hook := container.navigation_hook_ {
		navigable.ongoing_navigation_is_navigation = true
		hook(request) or {
			navigable.ongoing_navigation_is_navigation = false
			return err
		}
		navigable.ongoing_navigation_is_navigation = false
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
	if document := container.document_ {
		document.schedule_html_parser_end_check()
	}
}

pub fn (mut container NavigableContainerModel) set_potentially_delays_load_event(value bool) {
	container.potentially_delays_load_event_ = value
	if !value {
		if document := container.document_ {
			document.schedule_html_parser_end_check()
		}
	}
}

pub fn (mut container NavigableContainerModel) set_potentially_delays_the_load_event(value bool) {
	container.set_potentially_delays_load_event(value)
}

pub fn (container &NavigableContainerModel) is_navigable_container() bool {
	_ = container
	return true
}

// https://html.spec.whatwg.org/multipage/iframe-embed-object.html#potentially-delays-the-load-event
pub fn (container &NavigableContainerModel) currently_delays_the_load_event() bool {
	if !container.content_navigable_has_session_history_entry_and_ready_for_navigation() {
		return true
	}
	if !container.potentially_delays_load_event_ {
		return false
	}
	navigable := container.content_navigable_ or { return false }
	return navigable.delays_the_load_event_of_its_container()
}

fn navigable_container_load_event_delay_callback(target voidptr) bool {
	if target == unsafe { nil } {
		return false
	}
	return unsafe { &NavigableContainerModel(target) }.currently_delays_the_load_event()
}

fn navigable_container_active_window_proxy_callback(target voidptr) ?&dom.WindowProxy {
	if target == unsafe { nil } {
		return none
	}
	return unsafe { &NavigableContainerModel(target) }.content_window()
}

pub fn attach_navigable_container_load_event_delay_hook(element &dom.Element, container &NavigableContainerModel) {
	mut mutable_container := unsafe { &NavigableContainerModel(container) }
	mutable_container.document_ = element.document()
	mut node := element.as_node()
	node.set_load_event_delay_hook(dom.NodeLoadEventDelayHook{
		target: voidptr(container)
		callback: navigable_container_load_event_delay_callback
	})
	node.set_active_window_proxy_hook(dom.NodeActiveWindowProxyHook{
		target: voidptr(container)
		callback: navigable_container_active_window_proxy_callback
	})
}

pub fn (mut container NavigableContainerModel) mark_content_navigable_ready() {
	mut navigable := container.content_navigable_ or { return }
	navigable.set_has_session_history_entry_and_ready_for_navigation()
	if document := container.document_ {
		document.schedule_html_parser_end_check()
	}
}

pub fn (container &NavigableContainerModel) content_navigable_has_session_history_entry_and_ready_for_navigation() bool {
	navigable := container.content_navigable_ or { return false }
	return navigable.has_session_history_entry_and_ready_for_navigation()
}

pub fn navigable_container_content_navigable_has_session_history_entry_and_ready_for_navigation(container &NavigableContainerModel) bool {
	return container.content_navigable_has_session_history_entry_and_ready_for_navigation()
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
	lazy_load_resumption_steps_         ?fn()
	element_                           ?&dom.HTMLIFrameElement
	event_target_                       &dom.EventTarget = unsafe { nil }
	event_counts_                       map[string]int
	pending_resource_start_time_        ?f64
	iframe_fullscreen_flag_             bool
}

pub fn HTMLIFrameElementModel.create(base_url dom.URL, owner_origin dom.Origin) &HTMLIFrameElementModel {
	return &HTMLIFrameElementModel{
		container: NavigableContainerModel.create(base_url, owner_origin)
		event_target_: dom.EventTarget.new()
	}
}

// Return the HTMLIFrameElement state associated with a concrete DOM iframe,
// materializing the translated NavigableContainer state on first use.
pub fn html_iframe_element_model_for_dom_element(element &dom.HTMLIFrameElement) &HTMLIFrameElementModel {
	if element.iframe_element_model_ != unsafe { nil } {
		return unsafe { &HTMLIFrameElementModel(element.iframe_element_model_) }
	}
	dom_element := unsafe { &dom.Element(element) }
	mut model := HTMLIFrameElementModel.create(dom_element.document().base_url(), dom_element.document().origin())
	model.element_ = element
	model.container.set_name(dom_element.get_attribute_value('name'))
	model.container.set_src(dom_element.get_attribute_value('src'))
	model.srcdoc_ = dom_element.get_attribute('srcdoc')
	model.set_sandbox(dom_element.get_attribute('sandbox'))
	model.loading_lazy_ = dom_element.get_attribute_value('loading').to_lower() == 'lazy'
	model.referrer_policy_ = referrer_policy_from_string(dom_element.get_attribute_value('referrerpolicy')) or {
		ReferrerPolicy.empty_string
	}
	attach_navigable_container_load_event_delay_hook(dom_element, model.container)
	mut mutable_element := unsafe { &dom.HTMLIFrameElement(element) }
	mutable_element.iframe_element_model_ = model
	return model
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
	iframe.container.set_creation_sandboxing_flags(iframe.iframe_sandboxing_flag_set_)
}

pub fn (iframe &HTMLIFrameElementModel) iframe_sandboxing_flag_set() SandboxingFlagSet {
	return iframe.iframe_sandboxing_flag_set_
}

pub fn (iframe &HTMLIFrameElementModel) pending_resource_start_time() ?f64 {
	return iframe.pending_resource_start_time_
}

pub fn (mut iframe HTMLIFrameElementModel) set_pending_resource_start_time(value ?f64) {
	iframe.pending_resource_start_time_ = value
}

pub fn (mut iframe HTMLIFrameElementModel) set_iframe_fullscreen_flag(value bool) {
	iframe.iframe_fullscreen_flag_ = value
}

pub fn (iframe &HTMLIFrameElementModel) iframe_fullscreen_flag() bool {
	return iframe.iframe_fullscreen_flag_
}

pub fn (iframe &HTMLIFrameElementModel) supports_dimension_attributes() bool {
	_ = iframe
	return true
}

pub fn (mut iframe HTMLIFrameElementModel) set_referrer_policy(policy ReferrerPolicy) {
	iframe.referrer_policy_ = policy
}

pub fn (mut iframe HTMLIFrameElementModel) post_connection(document_is_fully_active bool, inclusive_ancestor_urls []dom.URL) ! {
	if !document_is_fully_active {
		return
	}
	if sandbox := iframe.sandbox_ {
		iframe.iframe_sandboxing_flag_set_ = parse_a_sandboxing_directive(sandbox)
	}
	iframe.container.set_creation_sandboxing_flags(iframe.iframe_sandboxing_flag_set_)
	iframe.container.create_new_child_navigable()
	iframe.process_the_iframe_attributes(.yes, inclusive_ancestor_urls)!
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
				iframe_ptr.container.navigate_an_iframe_or_frame(dom.URL{ value: 'about:srcdoc' }, iframe_ptr.referrer_policy_, srcdoc, initial_insertion) or {
					iframe_ptr.fire_event('error')
					return
				}
				iframe_ptr.run_iframe_load_event_steps()
			}
			iframe.set_current_navigation_was_lazy_loaded(true)
			return
		}
		iframe.container.navigate_an_iframe_or_frame(dom.URL{ value: 'about:srcdoc' }, iframe.referrer_policy_, srcdoc, initial_insertion)!
		iframe.run_iframe_load_event_steps()
		return
	}
	url := iframe.container.shared_attribute_processing_steps(initial_insertion, inclusive_ancestor_urls) or { return }
	if initial_insertion == .yes && url.serialize() == 'about:blank' {
		iframe.run_iframe_load_event_steps()
		return
	}
	iframe.set_current_navigation_was_lazy_loaded(false)
	if iframe.loading_lazy_ {
		mut iframe_ptr := &iframe
		iframe.lazy_load_resumption_steps_ = fn [mut iframe_ptr, url, initial_insertion] () {
			iframe_ptr.container.navigate_an_iframe_or_frame(url, iframe_ptr.referrer_policy_, none, initial_insertion) or {
				iframe_ptr.fire_event('error')
				return
			}
			iframe_ptr.run_iframe_load_event_steps()
		}
		iframe.set_current_navigation_was_lazy_loaded(true)
		return
	}
	iframe.container.navigate_an_iframe_or_frame(url, iframe.referrer_policy_, none, initial_insertion)!
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
	// document.open() owns these flags on the actual child Document. The
	// standalone EmbeddedDocument record has no parser or stream lifecycle.
	if element := iframe.element_ {
		dom_element := unsafe { &dom.Element(element) }
		if navigable := dom_element.as_node().content_navigable() {
			mut child := navigable.active_document() or { return }
			if child.should_mute_iframe_load() { return }
			child.set_iframe_load_in_progress(true)
			defer { child.set_iframe_load_in_progress(false) }
			iframe.fire_event('load')
			return
		}
	}
	if iframe.container.content_navigable() == none {
		return
	}
	iframe.fire_event('load')
}

pub fn html_iframe_element_attribute_changed(element &dom.HTMLIFrameElement, name string, old_value ?string, value ?string, namespace_ ?string) {
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.attribute_changed(name, old_value, value, namespace_)
	if namespace_ != none {
		return
	}
	mut model := html_iframe_element_model_for_dom_element(element)
	match name.to_lower() {
		'name' {
			mut container := model.container
			container.set_name(value or { '' })
		}
		'src' { model.set_src(value or { '' }) }
		'srcdoc' { model.set_srcdoc(value) }
		'sandbox' { model.set_sandbox(value) }
		'loading' { model.set_loading_lazy((value or { '' }).to_lower() == 'lazy') }
		'referrerpolicy' {
			model.set_referrer_policy(referrer_policy_from_string(value or { '' }) or {
				ReferrerPolicy.empty_string
			})
		}
		'width', 'height' {
			mut node := unsafe { &dom.Node(dom_element.as_node()) }
			node.invalidate_style(.html_iframe_element_geometry_change)
		}
		'marginwidth', 'marginheight' {
			if mut child_document := model.container.content_document_without_origin_check() {
				child_document.body_needs_style_update = true
			}
		}
		else {}
	}
}

pub fn html_iframe_element_removed_from(element &dom.HTMLIFrameElement, old_parent ?&dom.Node, old_root &dom.Node) {
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.removed_from(old_parent, old_root)
	mut model := html_iframe_element_model_for_dom_element(element)
	model.removed_from_document()
}

pub fn html_iframe_element_default_tab_index_value(_ &dom.HTMLIFrameElement) int {
	return 0
}

pub fn htmli_frame_element_attribute_changed(element &dom.HTMLIFrameElement, name string, old_value ?string, value ?string, namespace_ ?string) {
	html_iframe_element_attribute_changed(element, name, old_value, value, namespace_)
}

pub fn htmli_frame_element_removed_from(element &dom.HTMLIFrameElement, old_parent ?&dom.Node, old_root &dom.Node) {
	html_iframe_element_removed_from(element, old_parent, old_root)
}

pub fn htmli_frame_element_default_tab_index_value(element &dom.HTMLIFrameElement) int {
	return html_iframe_element_default_tab_index_value(element)
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
	bitmap       ?&dom.Bitmap_
}

pub type ObjectResourceFetchHook = fn(dom.URL) !ObjectResourceResponse

@[heap]
pub struct HTMLObjectElementModel {
pub mut:
	container &NavigableContainerModel
mut:
	element_             ?&dom.HTMLObjectElement
	data_                string
	type_                string
	classid_             ?string
	connected_           bool = true
	fully_active_        bool = true
	blocked_by_ancestor_ bool
	representation_      ObjectRepresentation = .unknown
	image_data_          ?&dom.Bitmap_
	fetch_hook_          ?ObjectResourceFetchHook
	event_target_        &dom.EventTarget = unsafe { nil }
	event_counts_        map[string]int
	form_control_        ?&FormAssociatedElement
	resource_response_   ?ObjectResourceResponse
	visible_in_viewport_ bool = true
}

pub fn HTMLObjectElementModel.create(base_url dom.URL, owner_origin dom.Origin) &HTMLObjectElementModel {
	mut container := NavigableContainerModel.create(base_url, owner_origin)
	container.set_potentially_delays_load_event(true)
	return &HTMLObjectElementModel{
		container: container
		event_target_: dom.EventTarget.new()
	}
}

fn (mut object HTMLObjectElementModel) fire_event(name string) {
	object.event_counts_[name]++
	event := dom.Event.create(name, dom.EventInit{})
	if element := object.element_ {
		unsafe { &dom.EventTarget(element) }
		.dispatch_event(event)
	} else {
		object.event_target_.dispatch_event(event)
	}
}

fn object_dom_element(element &dom.HTMLObjectElement) &dom.Element {
	return unsafe { &dom.Element(element) }
}

pub fn html_object_element_model_for_dom_element(element &dom.HTMLObjectElement) &HTMLObjectElementModel {
	if element.object_element_model_ != unsafe { nil } {
		return unsafe { &HTMLObjectElementModel(element.object_element_model_) }
	}
	dom_element := object_dom_element(element)
	mut model := HTMLObjectElementModel.create(dom_element.document().base_url(), dom_element.document().origin())
	model.element_ = element
	model.data_ = dom_element.get_attribute_value('data')
	model.type_ = dom_element.get_attribute_value('type')
	model.classid_ = dom_element.get_attribute('classid')
	model.connected_ = dom_element.as_node().is_connected()
	model.fully_active_ = dom_element.document().is_fully_active()
	model.form_control_ = FormAssociatedElement.create(dom_element)
	attach_navigable_container_load_event_delay_hook(dom_element, model.container)
	mut mutable_element := unsafe { &dom.HTMLObjectElement(element) }
	mutable_element.object_element_model_ = voidptr(model)
	return model
}

pub fn (object &HTMLObjectElementModel) event_count(name string) int {
	return object.event_counts_[name]
}

pub fn (mut object HTMLObjectElementModel) set_fetch_hook(hook ?ObjectResourceFetchHook) {
	object.fetch_hook_ = hook
}

pub fn (object &HTMLObjectElementModel) has_fetch_hook() bool {
	return object.fetch_hook_ != none
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

pub fn (object &HTMLObjectElementModel) image_data() ?&dom.Bitmap_ {
	return object.image_data_
}

pub fn (object &HTMLObjectElementModel) is_listed() bool {
	_ = object
	return true
}

pub fn (object &HTMLObjectElementModel) is_html_object_element() bool {
	_ = object
	return true
}

pub fn (object &HTMLObjectElementModel) to_html_element() ?&dom.Element {
	if element := object.element_ {
		return unsafe { &dom.Element(element) }
	}
	return none
}

pub fn (object &HTMLObjectElementModel) current_frame_index() uint {
	_ = object
	return 0
}

pub fn (object &HTMLObjectElementModel) decoded_image_data() ?DecodedImageData {
	bitmap := object.image_data_ or { return none }
	return BitmapDecodedImageData.create([
		BitmapDecodedImageFrame{ frame: dom.DecodedImageFrame_.create(bitmap) },
	], 0, false)
}

fn object_mime_essence(value string) string {
	return ascii_lowercase_string(value.split(';')[0].trim_space())
}

fn object_mime_is_image(value string) bool {
	return object_mime_essence(value).starts_with('image/')
}

fn object_mime_is_document(value string) bool {
	essence := object_mime_essence(value)
	return essence == 'text/html' || essence == 'application/xhtml+xml' || essence == 'image/svg+xml' || essence.ends_with('+xml')
}

// https://html.spec.whatwg.org/multipage/iframe-embed-object.html#object-type-detection
pub fn (mut object HTMLObjectElementModel) run_object_representation_steps() {
	if object.has_ancestor_media_element_or_object_element_not_showing_fallback_content() || !object.connected_ || !object.fully_active_ || object.blocked_by_ancestor_ || object.classid_ != none {
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
		object.resource_did_fail()
		return
	}
	if response.status < 200 || response.status >= 300 {
		object.resource_did_fail()
		return
	}
	object.resource_did_load(response)
}

pub fn (object &HTMLObjectElementModel) has_ancestor_media_element_or_object_element_not_showing_fallback_content() bool {
	element := object.element_ or { return object.blocked_by_ancestor_ }
	mut ancestor := object_dom_element(element).as_node().parent_element()
	for ancestor != none {
		candidate := ancestor or { break }
		if candidate.is_html_element() && candidate.local_name() in ['audio', 'video'] {
			return true
		}
		if candidate.is_html_element() && candidate.local_name() == 'object' {
			ancestor_object := unsafe { &dom.HTMLObjectElement(candidate) }
			ancestor_model := html_object_element_model_for_dom_element(ancestor_object)
			if ancestor_model.representation() != .children {
				return true
			}
		}
		ancestor = candidate.as_node().parent_element()
	}
	return object.blocked_by_ancestor_
}

pub fn (mut object HTMLObjectElementModel) queue_element_task_to_run_object_representation_steps() {
	if object.element_ != none && !object.fully_active_ {
		return
	}
	if object.element_ != none {
		mut document := unsafe { &dom.Document(object.container_document()) }
		document.increment_number_of_things_delaying_the_load_event()
		object.run_object_representation_steps()
		document.decrement_number_of_things_delaying_the_load_event()
		return
	}
	object.run_object_representation_steps()
}

fn (object &HTMLObjectElementModel) container_document() &dom.Document {
	if element := object.element_ {
		return object_dom_element(element).document()
	}
	return unsafe { nil }
}

pub fn (mut object HTMLObjectElementModel) resource_did_fail() {
	object.fire_event('error')
	object.run_object_representation_fallback_steps()
}

pub fn (mut object HTMLObjectElementModel) resource_did_load(response ObjectResourceResponse) {
	object.resource_response_ = response
	mut resource_type := if response.content_type != '' {
		object_mime_essence(response.content_type)
	} else {
		object_mime_essence(object.type_)
	}
	if resource_type == 'application/octet-stream' {
		resource_type = ''
	}
	if resource_type == '' && response.bitmap != none {
		resource_type = 'image/unknown'
	}
	if resource_type == '' && response.body.len > 0 {
		trimmed := response.body.bytestr().trim_space().to_lower()
		if trimmed.starts_with('<!doctype html') || trimmed.starts_with('<html') {
			resource_type = 'text/html'
		}
	}
	if resource_type == '' {
		object.run_object_representation_fallback_steps()
		return
	}
	object.run_object_representation_handler_steps(response, resource_type)
}

pub fn (mut object HTMLObjectElementModel) run_object_representation_handler_steps(response ObjectResourceResponse, resource_type string) {
	url := dom.dom_url_parse(object.data_, object.container.base_url_, 'UTF-8') or {
		object.run_object_representation_fallback_steps()
		return
	}
	if object_mime_is_document(resource_type) && !object_mime_is_image(resource_type) {
		if object.container.content_navigable() == none {
			object.container.create_new_child_navigable()
		}
		object.container.navigate_an_iframe_or_frame(url, .strict_origin_when_cross_origin, none, .no) or {
			object.fire_event('error')
			object.run_object_representation_fallback_steps()
			return
		}
		if mut document := object.container.content_document_without_origin_check() {
			document.content_type = object_mime_essence(resource_type)
		}
		object.image_data_ = none
		object.run_object_representation_completed_steps(.content_navigable)
		return
	}
	if object_mime_is_image(resource_type) {
		object.container.destroy_the_child_navigable()
		object.resource_response_ = response
		object.load_image()
		return
	}
	object.run_object_representation_fallback_steps()
}

pub fn (mut object HTMLObjectElementModel) run_object_representation_completed_steps(representation ObjectRepresentation) {
	if representation != .content_navigable {
		object.fire_event('load')
	}
	object.update_layout_and_child_objects(representation)
}

pub fn (mut object HTMLObjectElementModel) run_object_representation_fallback_steps() {
	object.container.destroy_the_child_navigable()
	object.image_data_ = none
	object.resource_response_ = none
	object.update_layout_and_child_objects(.children)
}

pub fn (mut object HTMLObjectElementModel) load_image() {
	response := object.resource_response_ or {
		object.run_object_representation_fallback_steps()
		return
	}
	bitmap := response.bitmap or {
		object.run_object_representation_fallback_steps()
		return
	}
	object.image_data_ = bitmap
	object.run_object_representation_completed_steps(.image)
}

pub fn (mut object HTMLObjectElementModel) update_layout_and_child_objects(representation ObjectRepresentation) {
	if representation == .children {
		if element := object.element_ {
			for child_node in object_dom_element(element).as_node().children_as_vector() {
				child := child_node.as_element() or { continue }
				if child.is_html_element() && child.local_name() == 'object' {
					mut child_model := html_object_element_model_for_dom_element(unsafe {
						&dom.HTMLObjectElement(child)
					})
					child_model.queue_element_task_to_run_object_representation_steps()
				}
			}
		}
	}
	object.representation_ = representation
	if element := object.element_ {
		dom_element := object_dom_element(element)
		mut node := unsafe { &dom.Node(dom_element.as_node()) }
		node.invalidate_style(.html_object_element_update_layout_and_child_objects)
		if parent := dom_element.as_node().parent() {
			mut mutable_parent := unsafe { &dom.Node(parent) }
			mutable_parent.set_needs_layout_tree_update(true, .html_object_element_update_layout_and_child_objects)
		}
	}
}

pub fn (object &HTMLObjectElementModel) is_image_available() bool {
	return object.image_data_ != none
}

pub fn (object &HTMLObjectElementModel) intrinsic_width() ?f64 {
	bitmap := object.image_data_ or { return none }
	return f64(bitmap.width)
}

pub fn (object &HTMLObjectElementModel) intrinsic_height() ?f64 {
	bitmap := object.image_data_ or { return none }
	return f64(bitmap.height)
}

pub fn (object &HTMLObjectElementModel) intrinsic_aspect_ratio() ?f64 {
	bitmap := object.image_data_ or { return none }
	if bitmap.height == 0 {
		return none
	}
	return f64(bitmap.width) / f64(bitmap.height)
}

pub fn (object &HTMLObjectElementModel) current_image_frame_sized(_ int, _ int) ?&dom.DecodedImageFrame_ {
	bitmap := object.image_data_ or { return none }
	return dom.DecodedImageFrame_.create(bitmap)
}

pub fn (mut object HTMLObjectElementModel) set_visible_in_viewport(visible bool) {
	object.visible_in_viewport_ = visible
}

pub fn html_object_element_form_associated_element_attribute_changed(element &dom.HTMLObjectElement, name string, old_value ?string, value ?string, namespace_ ?string) {
	html_element_attribute_changed(unsafe { &dom.HTMLElement(element) }, name, old_value, value, namespace_)
	if namespace_ != none {
		return
	}
	dom_element := object_dom_element(element)
	mut model := unsafe {
		&HTMLObjectElementModel(html_object_element_model_for_dom_element(element))
	}
	match name.to_lower() {
		'data' { model.set_data(value or { '' }) }
		'type' { model.set_type(value or { '' }) }
		'classid' { model.set_classid(value) }
		'form' {
			if mut form_control := model.form_control_ {
				form_control.form_node_attribute_changed(name)
			}
		}
		else {}
	}
	should_rerun := name == 'classid' || (name == 'data' && !dom_element.has_attribute('classid')) || (name == 'type' && !dom_element.has_attribute('classid') && !dom_element.has_attribute('data'))
	if should_rerun {
		model.connected_ = dom_element.as_node().is_connected()
		model.fully_active_ = dom_element.document().is_fully_active()
		model.queue_element_task_to_run_object_representation_steps()
	}
}

pub fn html_object_element_form_associated_element_was_removed(element &dom.HTMLObjectElement, _ ?&dom.Node) {
	mut model := unsafe {
		&HTMLObjectElementModel(html_object_element_model_for_dom_element(element))
	}
	model.container.destroy_the_child_navigable()
	if mut form_control := model.form_control_ {
		form_control.form_node_was_removed()
	}
}

pub fn html_object_element_data(element &dom.HTMLObjectElement) string {
	value := object_dom_element(element).get_attribute('data') or { return '' }
	url := object_dom_element(element).document().encoding_parse_url(value) or { return '' }
	return url.to_string()
}

pub fn html_object_element_set_data(element &dom.HTMLObjectElement, data string) {
	mut dom_element := object_dom_element(element)
	old_value := dom_element.get_attribute('data')
	dom_element.set_attribute_value('data', data)
	html_object_element_form_associated_element_attribute_changed(element, 'data', old_value, data, none)
}

pub fn html_object_element_has_ancestor_media_element_or_object_element_not_showing_fallback_content(element &dom.HTMLObjectElement) bool {
	return html_object_element_model_for_dom_element(element).has_ancestor_media_element_or_object_element_not_showing_fallback_content()
}

pub fn html_object_element_queue_element_task_to_run_object_representation_steps(element &dom.HTMLObjectElement) {
	mut model := unsafe {
		&HTMLObjectElementModel(html_object_element_model_for_dom_element(element))
	}
	dom_element := object_dom_element(element)
	model.connected_ = dom_element.as_node().is_connected()
	model.fully_active_ = dom_element.document().is_fully_active()
	model.queue_element_task_to_run_object_representation_steps()
}

pub fn html_object_element_resource_did_fail(element &dom.HTMLObjectElement) {
	mut model := html_object_element_model_for_dom_element(element)
	model.resource_did_fail()
}

pub fn html_object_element_resource_did_load(element &dom.HTMLObjectElement, response ObjectResourceResponse) {
	mut model := html_object_element_model_for_dom_element(element)
	model.resource_did_load(response)
}

pub fn html_object_element_run_object_representation_handler_steps(element &dom.HTMLObjectElement, response ObjectResourceResponse, resource_type string) {
	mut model := html_object_element_model_for_dom_element(element)
	model.run_object_representation_handler_steps(response, resource_type)
}

pub fn html_object_element_run_object_representation_completed_steps(element &dom.HTMLObjectElement, representation ObjectRepresentation) {
	mut model := html_object_element_model_for_dom_element(element)
	model.run_object_representation_completed_steps(representation)
}

pub fn html_object_element_run_object_representation_fallback_steps(element &dom.HTMLObjectElement) {
	mut model := html_object_element_model_for_dom_element(element)
	model.run_object_representation_fallback_steps()
}

pub fn html_object_element_load_image(element &dom.HTMLObjectElement) {
	mut model := html_object_element_model_for_dom_element(element)
	model.load_image()
}

pub fn html_object_element_update_layout_and_child_objects(element &dom.HTMLObjectElement, representation ObjectRepresentation) {
	mut model := html_object_element_model_for_dom_element(element)
	model.update_layout_and_child_objects(representation)
}

pub fn html_object_element_default_tab_index_value(_ &dom.HTMLObjectElement) int {
	return 0
}

pub fn html_object_element_image_data(element &dom.HTMLObjectElement) ?&dom.Bitmap_ {
	return html_object_element_model_for_dom_element(element).image_data()
}

pub fn html_object_element_is_image_available(element &dom.HTMLObjectElement) bool {
	return html_object_element_model_for_dom_element(element).is_image_available()
}

pub fn html_object_element_intrinsic_width(element &dom.HTMLObjectElement) ?f64 {
	return html_object_element_model_for_dom_element(element).intrinsic_width()
}

pub fn html_object_element_intrinsic_height(element &dom.HTMLObjectElement) ?f64 {
	return html_object_element_model_for_dom_element(element).intrinsic_height()
}

pub fn html_object_element_intrinsic_aspect_ratio(element &dom.HTMLObjectElement) ?f64 {
	return html_object_element_model_for_dom_element(element).intrinsic_aspect_ratio()
}

pub fn html_object_element_current_image_frame_sized(element &dom.HTMLObjectElement, width int, height int) ?&dom.DecodedImageFrame_ {
	return html_object_element_model_for_dom_element(element).current_image_frame_sized(width, height)
}

pub fn html_object_element_set_visible_in_viewport(element &dom.HTMLObjectElement, visible bool) {
	mut model := html_object_element_model_for_dom_element(element)
	model.set_visible_in_viewport(visible)
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
