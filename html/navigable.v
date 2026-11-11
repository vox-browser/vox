// Copyright (c) 2022-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Literal translation of Libraries/LibWeb/HTML/Navigable.{h,cpp}. The DOM
// Navigable remains the cross-module identity object; NavigableModel owns the
// HTML session-history, browsing-context, navigation, and viewport state.
@[has_globals]
module html

import css
import compositor
import dom
import editing
import fetch
import highresolutiontime
import http
import math
import mimesniff
import page
import painting
import platform
import rand

__global (
	html_all_navigable_models = []&NavigableModel{}
	html_next_navigable_id    u64
)

pub enum NavigableOngoingNavigationKind {
	empty
	traversal
	navigation
}

pub struct NavigableOngoingNavigation {
pub:
	kind NavigableOngoingNavigationKind
	id   string
}

pub struct TargetSnapshotParams {
pub:
	sandboxing_flags                SandboxingFlagSet
	iframe_element_referrer_policy ReferrerPolicy = .empty_string
}

pub struct ChosenNavigable {
pub:
	navigable   ?&NavigableModel
	window_type WindowType
}

pub struct NavigableNavigateParams {
pub:
	url                  dom.URL
	source_document      &dom.Document = unsafe { nil }
	navigation_id        ?string
	document_resource    DocumentResource = EmptyDocumentResource{}
	history_handling     NavigationHistoryBehavior = .auto
	navigation_api_state ?SerializationRecord
	user_involvement     dom.UserNavigationInvolvement = .none
	source_element       ?&dom.Element
	initial_insertion    InitialInsertion = .no
	referrer_policy      ReferrerPolicy = .empty_string
}

pub type NavigableJavaScriptURLHook = fn (string, &dom.Document) ?string

pub type NavigablePasteHook = fn (string)

pub type NavigablePaintHook = fn ()

pub type NavigableScreenshotHook = fn (dom.Rect)

pub type NavigableNavigationFetchHook = fn (&fetch.Request) !&fetch.Response

@[heap]
pub struct NavigationParams {
pub:
	id                     ?string
	navigable              &NavigableModel
	request                ?&fetch.Request
	response               &fetch.Response
	fetch_controller       ?&fetch.FetchController
	origin                 dom.Origin
	policy_container       &PolicyContainer
	final_sandboxing_flags SandboxingFlagSet
	opener_policy          dom.OpenerPolicy
	about_base_url         ?dom.URL
	user_involvement                       dom.UserNavigationInvolvement
	was_created_via_cross_origin_redirects bool
}

@[heap]
pub struct NonFetchSchemeNavigationParams {
pub:
	id                               ?string
	navigable                        &NavigableModel
	url                              dom.URL
	target_snapshot_sandboxing_flags SandboxingFlagSet
	source_has_transient_activation  bool
	initiator_origin                 dom.Origin
	user_involvement                 dom.UserNavigationInvolvement
}

pub struct NavigableNavigationParamsResult {
pub:
	navigation_params ?&NavigationParams
	non_fetch_params  ?&NonFetchSchemeNavigationParams
	network_error     ?string
}

fn navigable_noop_presentation_callback(_ RenderingRect, _ int) {}

@[heap]
pub struct NavigableModel {
mut:
	host_                                &dom.Navigable
	id_                                  string
	parent_                              ?&NavigableModel
	context_                             ?&BrowsingContextModel
	current_session_history_entry_       ?&SessionHistoryEntry
	active_session_history_entry_        ?&SessionHistoryEntry
	session_history_entries_             []&SessionHistoryEntry
	ongoing_navigation_                  NavigableOngoingNavigation
	pending_navigations_                 []NavigableNavigateParams
	delaying_load_events_                bool
	navigation_load_event_guard_         ?dom.DocumentLoadEventDelayer
	is_created_by_web_content_           bool
	has_session_history_entry_and_ready_ bool
	focused_                             bool
	needs_repaint_                       bool = true
	ready_to_paint_                      bool
	pending_set_browser_zoom_request_    bool
	should_show_line_box_borders_        bool
	force_dark_enabled_                  bool
	force_dark_foreground_threshold_     i32 = 150
	force_dark_background_threshold_     i32 = 205
	last_pasted_text_                    string
	paint_count_                         u64
	screenshot_count_                    u64
	javascript_url_hook_                 ?NavigableJavaScriptURLHook
	paste_hook_                          ?NavigablePasteHook
	paint_hook_                          ?NavigablePaintHook
	screenshot_hook_                     ?NavigableScreenshotHook
	navigation_fetch_hook_               ?NavigableNavigationFetchHook
	navigation_fetch_host_               ?&fetch.FetchHost
	navigation_fetch_controller_         ?&fetch.FetchController
	document_created_hook_               ?fn (&dom.Document)
	backing_store_manager_               &painting.BackingStoreManager = unsafe { nil }
	event_handler_                       &page.EventHandler = unsafe { nil }
	rendering_thread_                    &RenderingThread = unsafe { nil }
	is_svg_page_                         bool
	main_thread_smooth_scrolls_          []MainThreadSmoothScroll
}

fn navigable_backing_store_shrink_callback(target voidptr) {
	mut model := unsafe { &NavigableModel(target) }
	model.resize_backing_stores_if_needed(false)
}

fn navigable_backing_store_allocation_callback(target voidptr, front_id int, back_id int) {
	page_ := unsafe { &dom.Page(target) }
	page_.client_page_did_allocate_backing_stores(front_id, back_id)
}

fn same_navigable_model(a &NavigableModel, b &NavigableModel) bool {
	return voidptr(a) == voidptr(b)
}

fn same_dom_navigable(a &dom.Navigable, b &dom.Navigable) bool {
	return voidptr(a) == voidptr(b)
}

pub fn navigable_model_for_host(host &dom.Navigable) ?&NavigableModel {
	for model in html_all_navigable_models {
		if same_dom_navigable(model.host_, host) {
			return model
		}
	}
	return none
}

fn navigable_model_for_context(context &BrowsingContextModel) ?&NavigableModel {
	for model in html_all_navigable_models {
		if model_context := model.context_ {
			if voidptr(model_context) == voidptr(context) {
				return model
			}
		}
	}
	return none
}

pub fn all_navigable_models() []&NavigableModel {
	return html_all_navigable_models.clone()
}

fn navigable_model_scroll_viewport_box(target voidptr, position dom.CSSPixelPoint_) {
	mut model := unsafe { &NavigableModel(target) }
	model.perform_scroll_of_viewport_scrolling_box(css.CSSPixelPoint.from_values(position.x(), position.y()))
}

fn navigable_model_perform_viewport_scroll(target voidptr, position dom.CSSPixelPoint_) &dom.Promise {
	mut model := unsafe { &NavigableModel(target) }
	return model.perform_a_scroll_of_the_viewport(css.CSSPixelPoint.from_values(position.x(), position.y()))
}

fn navigable_model_is_focused(target voidptr) bool {
	model := unsafe { &NavigableModel(target) }
	return model.is_focused()
}

fn navigable_model_active_document_changed(target voidptr, document ?&dom.Document) {
	mut model := unsafe { &NavigableModel(target) }
	if entry := model.active_session_history_entry_ {
		if state := entry.document_state {
			mut mutable_state := unsafe { &DocumentState(state) }
			if value := document {
				mutable_state.set_document_id(value.unique_id())
			} else {
				mutable_state.set_document_id(none)
			}
		}
	}
}

fn navigable_model_set_needs_repaint(target voidptr) {
	mut model := unsafe { &NavigableModel(target) }
	model.set_needs_repaint()
}

fn navigable_model_render_screenshot(target voidptr, config dom.PaintConfig, _ ?dom.UniqueNodeID) []u8 {
	mut model := unsafe { &NavigableModel(target) }
	model.render_screenshot(config)
	// Native painting owns the shareable bitmap. The model callback records the
	// render and leaves transport bytes empty when no native surface is attached.
	return []
}

fn navigable_model_reset_mouse_input_tracking(target voidptr) {
	mut model := unsafe { &NavigableModel(target) }
	mut event_handler := model.event_handler_
	event_handler.reset_mouse_input_tracking()
}

fn navigable_model_has_session_history_entry_and_ready(target voidptr) bool {
	model := unsafe { &NavigableModel(target) }
	return model.has_session_history_entry_and_ready_for_navigation()
}

fn navigable_model_delays_container_load_event(target voidptr) bool {
	model := unsafe { &NavigableModel(target) }
	return model.delays_the_load_event_of_its_container()
}

fn navigable_model_force_dark_enabled(target voidptr) bool {
	model := unsafe { &NavigableModel(target) }
	return model.force_dark_enabled()
}

fn (model &NavigableModel) system_visibility_state() dom.VisibilityState {
	if context := model.context_ {
		if traversable := context.top_level_traversable() {
			return traversable.system_visibility_state()
		}
	}
	// Browsing contexts created directly by the translated host do not have the
	// separate TraversableNavigable adapter installed. Preserve the host-visible
	// state used by that path.
	return .visible
}

fn connect_navigable_model_to_host(model &NavigableModel) {
	mut host := unsafe { &dom.Navigable(model.host_) }
	host.html_model_handle_ = voidptr(model)
	host.viewport_scroll_callback_ = navigable_model_scroll_viewport_box
	host.perform_scroll_callback_ = navigable_model_perform_viewport_scroll
	host.perform_scroll_options_callback_ = navigable_model_perform_viewport_scroll_options
	host.perform_element_scroll_callback_ = navigable_model_perform_element_scroll
	host.is_focused_callback_ = navigable_model_is_focused
	host.active_document_changed_ = navigable_model_active_document_changed
	host.set_needs_repaint_callback_ = navigable_model_set_needs_repaint
	host.render_screenshot_callback_ = navigable_model_render_screenshot
	host.reset_mouse_input_tracking_callback_ = navigable_model_reset_mouse_input_tracking
	host.has_session_history_entry_and_ready_callback_ = navigable_model_has_session_history_entry_and_ready
	host.delays_container_load_event_callback_ = navigable_model_delays_container_load_event
	host.force_dark_enabled_callback_ = navigable_model_force_dark_enabled
	host.choose_a_navigable_callback_ = navigable_model_choose_a_navigable
	host.navigate_callback_ = navigable_model_navigate
	host.page_navigate_callback_ = navigable_model_navigate_from_page
	host.reload_callback_ = navigable_model_reload
	host.download_hyperlink_callback_ = navigable_model_download_hyperlink
}

fn navigable_model_choose_a_navigable(target voidptr, name string, no_opener dom.TokenizedFeatureNoOpener) ?&dom.Navigable {
	mut model := unsafe { &NavigableModel(target) }
	chosen := model.choose_a_navigable(name, no_opener == .yes) or { return none }
	navigable := chosen.navigable or { return none }
	return navigable.host_
}

fn navigable_model_navigate(target voidptr, url dom.URL, source_document &dom.Document, referrer_policy string, user_involvement dom.UserNavigationInvolvement) ! {
	mut model := unsafe { &NavigableModel(target) }
	model.navigate(NavigableNavigateParams{
		url: url
		source_document: source_document
		referrer_policy: referrer_policy_from_string(referrer_policy) or { ReferrerPolicy.empty_string }
		user_involvement: user_involvement
	})!
}

fn navigable_model_navigate_from_page(target voidptr, params dom.PageNavigationParams) ! {
	mut model := unsafe { &NavigableModel(target) }
	resource := if value := params.document_resource { DocumentResource(value) } else { DocumentResource(EmptyDocumentResource{}) }
	model.navigate(NavigableNavigateParams{
		url: params.url
		history_handling: match params.history_handling { .auto { NavigationHistoryBehavior.auto } .push { NavigationHistoryBehavior.push } .replace { NavigationHistoryBehavior.replace } }
		document_resource: resource
		navigation_id: params.navigation_id
		user_involvement: .browser_ui
	})!
}

fn navigable_model_reload(target voidptr) {
	mut model := unsafe { &NavigableModel(target) }
	model.reload(none, .none)
}

fn navigable_model_download_hyperlink(target voidptr, url dom.URL,
	user_involvement dom.UserNavigationInvolvement, source_element &dom.Element,
	proposed_filename ?string, interface_origin dom.Origin) {
	mut model := unsafe { &NavigableModel(target) }
	model.download_the_hyperlink(url, user_involvement, source_element, proposed_filename,
		interface_origin)
}

// Binds the DOM identity created by Document/Window to the translated HTML
// state. Repeated calls preserve history and only refresh the context link.
pub fn NavigableModel.create(host &dom.Navigable, context ?&BrowsingContextModel) !&NavigableModel {
	if existing := navigable_model_for_host(host) {
		mut mutable_existing := unsafe { &NavigableModel(existing) }
		if value := context {
			mutable_existing.context_ = value
			mutable_existing.synchronize_host_container(value)
		}
		connect_navigable_model_to_host(existing)
		return existing
	}
	mut model := &NavigableModel{
		host_: host
		backing_store_manager_: &painting.BackingStoreManager{}
		event_handler_: &page.EventHandler{}
		rendering_thread_: RenderingThread.create(navigable_noop_presentation_callback)
	}
	model.backing_store_manager_ = painting.BackingStoreManager.create(voidptr(model), navigable_backing_store_shrink_callback)
	connect_navigable_model_to_host(model)
	// The list is process-wide; never grow it inside a document arena.
	persistent := platform.enter_persistent()
	html_all_navigable_models << model
	platform.leave_persistent(persistent)
	if value := context {
		model.context_ = value
		model.synchronize_host_container(value)
	}
	mut parent_model := ?&NavigableModel(none)
	if parent_host := host.parent() {
		if existing_parent := navigable_model_for_host(parent_host) {
			parent_model = existing_parent
		} else if value := context {
			if parent_context := value.parent() {
				parent_model = NavigableModel.create(parent_host, parent_context)!
			}
		}
	}
	document := host.active_document() or {
		return error('NavigableModel.create requires an active document')
	}
	model.is_svg_page_ = document.get_content_type() == 'image/svg+xml'
	state := &DocumentState{
		document: document
		document_id_: document.unique_id()
		origin: document.origin()
		navigable_target_name: if value := context { value.target_name() } else { '' }
		ever_populated: true
	}
	model.initialize_navigable(state, host.parent(), parent_model, document)!
	if local_parent := parent_model {
		model.inherit_page_state_from(local_parent)
	}
	return model
}

fn (mut model NavigableModel) synchronize_host_container(context &BrowsingContextModel) {
	mut host := unsafe { &dom.Navigable(model.host_) }
	if container := context.container() {
		host.container_ = unsafe { &dom.Node(container) }
		host.container_document_ = container.document()
	} else {
		host.container_ = none
		host.container_document_ = none
	}
}

pub fn (model &NavigableModel) host_navigable() &dom.Navigable {
	return model.host_
}

pub fn (model &NavigableModel) id() string {
	return model.id_
}

pub fn (model &NavigableModel) backing_store_manager() &painting.BackingStoreManager {
	return model.backing_store_manager_
}

pub fn (model &NavigableModel) page() ?&dom.Page {
	if context := model.context_ {
		if page_ := context.page() {
			return page_
		}
	}
	document := model.active_document() or { return none }
	page_ := document.page()
	if page_ == unsafe { nil } {
		return none
	}
	return page_
}

pub fn (model &NavigableModel) event_handler() &page.EventHandler {
	return model.event_handler_
}

pub fn (model &NavigableModel) rendering_thread() &RenderingThread {
	return model.rendering_thread_
}

pub fn (model &NavigableModel) is_svg_page() bool {
	return model.is_svg_page_
}

// https://html.spec.whatwg.org/multipage/document-sequences.html#initialize-the-navigable
pub fn (mut model NavigableModel) initialize_navigable(document_state &DocumentState, logical_parent ?&dom.Navigable, local_parent ?&NavigableModel, document &dom.Document) ! {
	model.id_ = '${html_next_navigable_id}'
	html_next_navigable_id++
	mut entry := &SessionHistoryEntry{
		url: document.url
		document_state: document_state
	}
	if logical_parent == none {
		entry.step = 0
	}
	model.current_session_history_entry_ = entry
	model.active_session_history_entry_ = entry
	model.session_history_entries_ = [entry]
	model.parent_ = local_parent
	model.has_session_history_entry_and_ready_ = logical_parent == none
	mut host := unsafe { &dom.Navigable(model.host_) }
	host.set_active_document(document)
	mut mutable_document_state := unsafe { &DocumentState(document_state) }
	mutable_document_state.set_document_id(document.unique_id())
	if parent := logical_parent {
		host.parent_ = parent
		host.traversable_navigable_ = parent.traversable_navigable() or { parent }
		host.is_top_level_traversable_ = false
	} else {
		host.parent_ = none
		host.traversable_navigable_ = model.host_
		host.is_top_level_traversable_ = true
	}
	mut mutable_document := unsafe { &dom.Document(document) }
	// 6. Set the initial visibility state from the navigable's traversable.
	mutable_document.set_initial_visibility_state(model.system_visibility_state())
	mutable_document.set_ready_to_run_scripts()
}

// Page-local state is inherited only when the logical parent is hosted by this
// V engine. A local root whose parent is remote receives page state from its
// host instead of downcasting that parent.
pub fn (mut model NavigableModel) inherit_page_state_from(parent &NavigableModel) {
	model.should_show_line_box_borders_ = parent.should_show_line_box_borders_
	model.force_dark_enabled_ = parent.force_dark_enabled_
	model.force_dark_foreground_threshold_ = parent.force_dark_foreground_threshold_
	model.force_dark_background_threshold_ = parent.force_dark_background_threshold_
}

// https://html.spec.whatwg.org/multipage/document-sequences.html#child-navigable
pub fn (model &NavigableModel) child_navigables() []&NavigableModel {
	mut children := []&NavigableModel{}
	for candidate in html_all_navigable_models {
		parent := candidate.parent_ or { continue }
		if !same_navigable_model(parent, model) {
			continue
		}
		entry := candidate.current_session_history_entry_ or { continue }
		if entry.step is SessionHistoryEntryPending {
			continue
		}
		children << candidate
	}
	return children
}

pub fn (model &NavigableModel) parent() ?&NavigableModel {
	return model.parent_
}

pub fn (model &NavigableModel) is_ancestor_of(other &NavigableModel) bool {
	mut ancestor := other.parent_
	for ancestor != none {
		candidate := ancestor or { break }
		if same_navigable_model(model, candidate) {
			return true
		}
		ancestor = candidate.parent_
	}
	return false
}

pub fn (model &NavigableModel) is_top_level_traversable() bool {
	return model.host_.parent() == none
}

pub fn (model &NavigableModel) is_traversable() bool {
	return model.is_top_level_traversable()
}

pub fn (model &NavigableModel) traversable_navigable() &NavigableModel {
	mut current := unsafe { model }
	for {
		current = current.parent_ or { return current }
	}
	return current
}

pub fn (model &NavigableModel) top_level_traversable() &NavigableModel {
	return model.traversable_navigable()
}

pub fn (model &NavigableModel) is_script_closable() bool {
	return model.is_top_level_traversable() && (model.is_created_by_web_content_ || model.get_session_history_entries().len == 1)
}

pub fn (mut model NavigableModel) set_is_created_by_web_content(value bool) {
	model.is_created_by_web_content_ = value
}

pub fn (mut model NavigableModel) set_closing(value bool) {
	model.host_.set_closing(value)
}

pub fn (model &NavigableModel) is_closing() bool {
	return model.host_.is_closing()
}

pub fn (mut model NavigableModel) set_delaying_load_events(value bool) {
	model.delaying_load_events_ = value
	// The flag belongs to the navigable even when its container document is
	// hosted elsewhere. A local container observes it through the navigable
	// boundary and needs another parser-end check after either transition.
	if container_document := model.container_document() {
		container_document.schedule_html_parser_end_check()
	}
}

pub fn (model &NavigableModel) is_delaying_load_events() bool {
	return model.delaying_load_events_
}

// https://html.spec.whatwg.org/multipage/iframe-embed-object.html#potentially-delays-the-load-event
pub fn (model &NavigableModel) delays_the_load_event_of_its_container() bool {
	document := model.active_document() or { return true }
	if !document.document_ready_for_post_load_tasks() || model.is_delaying_load_events() {
		return true
	}
	return document.anything_is_delaying_the_load_event()
}

pub fn (mut model NavigableModel) set_navigation_load_event_guard(parent_document &dom.Document) {
	model.clear_navigation_load_event_guard()
	mut mutable_parent := unsafe { &dom.Document(parent_document) }
	model.navigation_load_event_guard_ = dom.DocumentLoadEventDelayer.new(mut mutable_parent)
}

pub fn (mut model NavigableModel) clear_navigation_load_event_guard() {
	if mut guard := model.navigation_load_event_guard_ {
		guard.finish()
	}
	model.navigation_load_event_guard_ = none
}

pub fn NavigableModel.navigable_with_active_document(document &dom.Document) ?&NavigableModel {
	host := document.navigable() or { return none }
	return navigable_model_for_host(host)
}

pub fn (model &NavigableModel) current_session_history_entry() ?&SessionHistoryEntry {
	return model.current_session_history_entry_
}

pub fn (model &NavigableModel) active_session_history_entry() ?&SessionHistoryEntry {
	return model.active_session_history_entry_
}

pub fn (mut model NavigableModel) set_current_session_history_entry(entry ?&SessionHistoryEntry) {
	model.current_session_history_entry_ = entry
}

pub fn (mut model NavigableModel) set_active_session_history_entry(entry ?&SessionHistoryEntry) {
	model.active_session_history_entry_ = entry
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#save-persisted-state
pub fn (mut model NavigableModel) save_persisted_state_to_active_session_history_entry() {
	mut entry := model.active_session_history_entry_ or { return }
	position := model.viewport_scroll_offset()
	entry.set_scroll_position_data(SessionHistoryEntryScrollPositionData{
		viewport_scroll_position: dom.CSSPixelPoint_{
			x_: position.x().to_double()
			y_: position.y().to_double()
		}
	})
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#restore-scroll-position-data
pub fn (mut model NavigableModel) restore_scroll_position_data(entry &SessionHistoryEntry) {
	position := entry.scroll_position_data.viewport_scroll_position or { return }
	model.perform_scroll_of_viewport_scrolling_box(css.CSSPixelPoint.from_values(position.x(),
		position.y()))
	model.clamp_viewport_scroll_offset()
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#restore-persisted-user-state
pub fn (mut model NavigableModel) restore_persisted_state_from_session_history_entry(entry &SessionHistoryEntry) {
	if entry.scroll_restoration_mode != .auto {
		return
	}
	if window := model.active_window() {
		if window.navigation().suppress_scroll_restoration_during_ongoing_navigation() {
			return
		}
	}
	model.restore_scroll_position_data(entry)
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#getting-session-history-entries
pub fn (model &NavigableModel) get_session_history_entries() []&SessionHistoryEntry {
	return model.session_history_entries_.clone()
}

pub fn (model &NavigableModel) get_the_target_history_entry(target_step int) ?&SessionHistoryEntry {
	mut result := ?&SessionHistoryEntry(none)
	mut result_step := -1
	for entry in model.get_session_history_entries() {
		step := match entry.step {
			int { entry.step as int }
			SessionHistoryEntryPending {
				continue
			}
		}
		if step <= target_step && step > result_step {
			result = entry
			result_step = step
		}
	}
	return result
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#activate-history-entry
pub fn (mut model NavigableModel) activate_history_entry(entry ?&SessionHistoryEntry, new_document &dom.Document) {
	value := entry or { return }
	if previous := model.active_session_history_entry_ {
		if voidptr(previous) != voidptr(value) {
			model.save_persisted_state_to_active_session_history_entry()
		}
	}
	model.active_session_history_entry_ = value
	model.set_active_document(new_document)
	mut document := unsafe { &dom.Document(new_document) }
	document.make_active()
	// 6. Set the initial visibility state from the navigable's traversable.
	document.set_initial_visibility_state(model.system_visibility_state())
	document.set_ready_to_run_scripts()
	if document.document_ready_for_post_load_tasks() {
		model.clear_navigation_load_event_guard()
		if container_document := model.container_document() {
			container_document.schedule_html_parser_end_check()
		}
	}
	if document.document_completely_loaded_deferred() {
		document.completely_finish_loading()
	}
	if mut context := model.context_ {
		context.set_active_document(new_document)
	}
	model.restore_persisted_state_from_session_history_entry(value)
	if model.ongoing_navigation_.kind == .empty {
		notify_navigation_complete(model.host_)
	}
}

pub fn (model &NavigableModel) active_document() ?&dom.Document {
	return model.host_.active_document()
}

pub fn (model &NavigableModel) active_document_id() ?dom.UniqueNodeID {
	document := model.active_document() or { return none }
	return document.unique_id()
}

pub fn (mut model NavigableModel) set_active_document(document ?&dom.Document) {
	mut host := unsafe { &dom.Navigable(model.host_) }
	host.set_active_document(document)
}

pub fn (model &NavigableModel) active_browsing_context() ?&BrowsingContextModel {
	document := model.active_document() or { return none }
	native := document.get_browsing_context() or { return none }
	return browsing_context_model_for_native(native)
}

pub fn (model &NavigableModel) active_window_proxy() ?&WindowProxyModel {
	native := model.host_.active_window_proxy() or { return none }
	return window_proxy_model_for_native(native)
}

pub fn (model &NavigableModel) active_window() ?&WindowModel {
	proxy := model.active_window_proxy() or { return none }
	return proxy.window()
}

pub fn (model &NavigableModel) target_name() string {
	entry := model.active_session_history_entry_ or { return '' }
	state := entry.document_state or { return '' }
	return state.navigable_target_name
}

pub fn (model &NavigableModel) container() ?&dom.Element {
	context := model.context_ or { return none }
	return context.container()
}

pub fn (model &NavigableModel) container_document() ?&dom.Document {
	if container := model.container() {
		return container.document()
	}
	return model.host_.container_document()
}

pub fn (model &NavigableModel) is_focused() bool {
	return model.focused_
}

pub fn (mut model NavigableModel) set_focused(value bool) {
	model.focused_ = value
}

pub fn (model &NavigableModel) ongoing_navigation() NavigableOngoingNavigation {
	return model.ongoing_navigation_
}

// https://html.spec.whatwg.org/multipage/document-sequences.html#ongoing-navigation
pub fn (mut model NavigableModel) set_ongoing_navigation(value NavigableOngoingNavigation) {
	if model.ongoing_navigation_ == value {
		return
	}
	if mut controller := model.navigation_fetch_controller_ {
		model.navigation_fetch_controller_ = none
		controller.stop_fetch()
	}
	model.inform_the_navigation_api_about_aborting_navigation()
	was_traversal := model.ongoing_navigation_.kind == .traversal
	model.ongoing_navigation_ = value
	if value.kind == .empty && model.delaying_load_events_ {
		model.set_delaying_load_events(false)
	}
	notify_ongoing_navigation_changed(model.host_)
	if was_traversal && value.kind != .traversal {
		for model.pending_navigations_.len > 0 {
			params := model.pending_navigations_[0]
			model.pending_navigations_.delete(0)
			model.begin_navigation(params)
		}
	}
}

fn (model &NavigableModel) find_a_navigable_by_target_name(name string) ?&NavigableModel {
	current_context := model.context_ or { return none }
	for candidate in html_all_navigable_models {
		if candidate.target_name() != name {
			continue
		}
		candidate_context := candidate.context_ or { continue }
		current_document := model.active_document() or { return none }
		source_snapshot_params := snapshot_source_snapshot_params(current_document)
		if current_context.is_familiar_with(candidate_context) && model.allowed_by_sandboxing_to_navigate(candidate, source_snapshot_params) {
			return candidate
		}
	}
	return none
}

// https://html.spec.whatwg.org/multipage/document-sequences.html#the-rules-for-choosing-a-navigable
pub fn (mut model NavigableModel) choose_a_navigable(name string, no_opener bool) !ChosenNavigable {
	lower_name := ascii_lowercase_string(name)
	mut chosen := ?&NavigableModel(none)
	mut window_type := WindowType.existing_or_none
	if lower_name == '' || lower_name == '_self' {
		chosen = &model
	} else if lower_name == '_parent' {
		chosen = model.parent_ or { &model }
	} else if lower_name == '_top' {
		chosen = model.traversable_navigable()
	} else if lower_name != '_blank' && !no_opener {
		chosen = model.find_a_navigable_by_target_name(name)
	}
	if chosen == none {
		current_document := model.active_document() or {
			return ChosenNavigable{ window_type: window_type }
		}
		mut document := dom.Document.create(dom.url_about_blank())
		document.set_document_type(.html)
		document.set_content_type('text/html')
		document.set_origin(current_document.origin())
		document.set_is_initial_about_blank(true)
		document.populate_with_html_head_and_body()!
		target_name := if lower_name == '_blank' { '' } else { name }
		context := BrowsingContextModel.create(document, none, target_name)
		if !no_opener {
			mut mutable_context := unsafe { &BrowsingContextModel(context) }
			mutable_context.set_opener(model.context_)
		}
		if source_context := model.context_ {
			if mut group := source_context.group() {
				group.append_model(context)
			}
		}
		_ = WindowModel.create(document, context)!
		chosen = navigable_model_for_context(context)
		if mut chosen_model := chosen {
			chosen_model.is_created_by_web_content_ = true
		}
		window_type = if no_opener { .new_with_no_opener } else { .new_and_unrestricted }
	}
	return ChosenNavigable{
		navigable: chosen
		window_type: window_type
	}
}

pub fn (mut model NavigableModel) set_javascript_url_hook(hook ?NavigableJavaScriptURLHook) {
	model.javascript_url_hook_ = hook
}

pub fn (mut model NavigableModel) set_paste_hook(hook ?NavigablePasteHook) {
	model.paste_hook_ = hook
}

pub fn (mut model NavigableModel) set_paint_hook(hook ?NavigablePaintHook) {
	model.paint_hook_ = hook
}

pub fn (mut model NavigableModel) set_screenshot_hook(hook ?NavigableScreenshotHook) {
	model.screenshot_hook_ = hook
}

pub fn (mut model NavigableModel) set_navigation_fetch_hook(hook ?NavigableNavigationFetchHook) {
	model.navigation_fetch_hook_ = hook
}

fn cloned_policy_container(container &PolicyContainer) &PolicyContainer {
	clone := container.clone()
	return &clone
}

fn history_policy_container_value(value HistoryPolicyContainer) ?&PolicyContainer {
	match value {
		dom.PolicyContainer {
			return cloned_policy_container(&value)
		}
		DocumentStateClient {
			return none
		}
	}
}

// https://html.spec.whatwg.org/multipage/browsers.html#determining-navigation-params-policy-container
fn determine_navigation_params_policy_container(response_url dom.URL, history_policy_container ?&PolicyContainer, initiator_policy_container ?&PolicyContainer, parent_policy_container ?&PolicyContainer, response_policy_container ?&PolicyContainer) &PolicyContainer {
	if container := history_policy_container {
		return cloned_policy_container(container)
	}
	if url_matches_about_srcdoc(response_url) {
		if container := parent_policy_container {
			return cloned_policy_container(container)
		}
		return &PolicyContainer{}
	}
	if fetch.is_local_url(response_url) {
		if container := initiator_policy_container {
			return cloned_policy_container(container)
		}
	}
	if container := response_policy_container {
		return cloned_policy_container(container)
	}
	return &PolicyContainer{}
}

// https://html.spec.whatwg.org/multipage/browsers.html#obtain-coop
fn obtain_an_opener_policy(response &fetch.Response, reserved_client ?&EnvironmentSettingsObject) dom.OpenerPolicy {
	client := reserved_client or { return dom.OpenerPolicy{} }
	if is_non_secure_context(client.environment()) {
		return dom.OpenerPolicy{}
	}
	value := ascii_lowercase_string(response.header_list.get('Cross-Origin-Opener-Policy') or {
		return dom.OpenerPolicy{}
	}).split(';')[0].trim_space()
	return dom.OpenerPolicy{
		value: match value {
			'same-origin' { .same_origin }
			'same-origin-allow-popups' { .same_origin_allow_popups }
			'same-origin-plus-coep' { .same_origin_plus_coep }
			else { .unsafe_none }
		}
	}
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#hand-off-to-external-software
// FIXME: `resource` can also be a response: https://fetch.spec.whatwg.org/#concept-response
fn hand_off_to_external_software(resource dom.URL, navigable &NavigableModel, sandboxing_flags SandboxingFlagSet, has_transient_activation bool, initiator_origin dom.Origin) {
	// 1. If all of the following are true:
	//    - navigable is not a top-level traversable;
	//    - sandboxFlags has its sandboxed custom protocols navigation browsing context flag set; and
	//    - sandboxFlags has its sandboxed top-level navigation with user activation browsing context flag set, or
	//      hasTransientActivation is false,
	//    then return without invoking the external software package.
	if !navigable.is_top_level_traversable() && sandboxing_flags.contains(.sandboxed_custom_protocols)
		&& (sandboxing_flags.contains(.sandboxed_top_level_navigation_with_user_activation)
		|| !has_transient_activation) {
		return
	}

	// 2. Perform the appropriate handoff of resource while attempting to mitigate the risk that this is an attempt to
	//    exploit the target software. For example, user agents could prompt the user to confirm that initiatorOrigin is
	//    to be allowed to invoke the external software in question. In particular, if hasTransientActivation is false,
	//    then the user agent should not invoke the external software package without prior user confirmation.
	page_ := navigable.page() or { return }
	page_.client_page_did_request_external_url(resource.value, initiator_origin.value, has_transient_activation)
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#attempt-to-create-a-non-fetch-scheme-document
fn attempt_to_create_a_non_fetch_scheme_document(params &NonFetchSchemeNavigationParams) ?&dom.Document {
	// 1. Let url be navigationParams's URL.
	url := params.url

	// 2. Let navigable be navigationParams's navigable.
	navigable := params.navigable

	// 3. If url is to be handled using a mechanism that does not affect navigable, e.g., because url's scheme is
	//    handled externally, then:
	// AD-HOC: Checking if there is external software to hand-off to is done asynchronously, so we don't know here if it
	//         will succeed or not. Only a few cases reject it early. Whether a URL went unhandled is decided by the
	//         embedder, so an equivalent of step 4 belongs there.
	// 1. Hand-off to external software given url, navigable, navigationParams's target snapshot sandboxing flags,
	//    navigationParams's source snapshot has transient activation, and navigationParams's initiator origin.
	hand_off_to_external_software(url, navigable, params.target_snapshot_sandboxing_flags,
		params.source_has_transient_activation, params.initiator_origin)

	// 2. Return null.
	return none
}

fn csp_derived_sandboxing_flags(container &PolicyContainer) SandboxingFlagSet {
	mut flags := SandboxingFlagSet{}
	for policy in container.csp_list {
		if policy.disposition != .enforce {
			continue
		}
		for directive in policy.directives {
			if ascii_lowercase_string(directive.name) == 'sandbox' {
				flags = flags.union(parse_a_sandboxing_directive(SandboxingDirective(directive.value)))
			}
		}
	}
	return flags
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#create-navigation-params-from-a-srcdoc-resource
fn create_navigation_params_from_a_srcdoc_resource(entry &SessionHistoryEntry, navigable &NavigableModel, target_snapshot_params TargetSnapshotParams, user_involvement dom.UserNavigationInvolvement, navigation_id ?string) !&NavigationParams {
	state := entry.document_state or { return error('InvalidStateError: srcdoc entry has no document state') }
	resource := match state.resource {
		string { state.resource as string }
		else {
			return error('InvalidStateError: srcdoc entry resource is not a string')
		}
	}
	mut response := fetch.Response.create()
	srcdoc_url := dom.URL{ value: 'about:srcdoc' }
	response.url_list = [srcdoc_url]
	response.header_list.append(http.Header{
		name: 'Content-Type'
		value: 'text/html'
	})
	response.set_body_bytes(resource.bytes())
	creator := navigable.container_document() or { navigable.active_document() or { return error('Missing srcdoc creator') } }
	history_container := history_policy_container_value(state.history_policy_container)
	parent_policy := cloned_policy_container(creator.policy_container())
	policy_container := determine_navigation_params_policy_container(srcdoc_url, history_container, none, parent_policy, none)
	final_flags := target_snapshot_params.sandboxing_flags.union(csp_derived_sandboxing_flags(policy_container))
	response_origin := determine_the_origin(response.url(), final_flags, creator.origin())
	return &NavigationParams{
		id: navigation_id
		navigable: navigable
		response: response
		origin: response_origin
		policy_container: policy_container
		final_sandboxing_flags: final_flags
		opener_policy: dom.OpenerPolicy{}
		about_base_url: creator.base_url()
		user_involvement: user_involvement
	}
}

// The Fetch module is synchronous at this host boundary. This is the same
// redirect loop as the upstream continuation-based implementation.
fn perform_navigation_params_fetch(mut request fetch.Request, navigable &NavigableModel, navigation_id ?string, fetch_hook NavigableNavigationFetchHook) !&fetch.Response {
	for redirect_count in 0 .. 21 {
		if expected_id := navigation_id {
			ongoing := navigable.ongoing_navigation()
			if ongoing.kind != .navigation || ongoing.id != expected_id {
				return error('AbortError: ongoing navigation changed')
			}
		}
		mut response := fetch_hook(&request)!
		if response.url_list.len == 0 {
			response.url_list = request.url_list.clone()
		}
		location_result := response.location_url(request.current_url().fragment())!
		location := location_result.url or { return response }
		if !fetch.is_http_or_https_scheme(location.scheme()) {
			request.url_list << location
			return response
		}
		if redirect_count == 20 {
			return error('NetworkError: too many navigation redirects')
		}
		request.url_list << location
	}
	return error('NetworkError: navigation redirect loop did not terminate')
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#create-navigation-params-by-fetching
fn create_navigation_params_by_fetching(entry &SessionHistoryEntry, navigable &NavigableModel, source_snapshot_params SourceSnapshotParams, target_snapshot_params TargetSnapshotParams, user_involvement dom.UserNavigationInvolvement, navigation_id ?string, fetch_hook NavigableNavigationFetchHook) !NavigableNavigationParamsResult {
	state := entry.document_state or { return error('InvalidStateError: navigation entry has no document state') }
	if !fetch.is_fetch_scheme(entry.url.scheme()) {
		return NavigableNavigationParamsResult{
			non_fetch_params: &NonFetchSchemeNavigationParams{
				id: navigation_id
				navigable: navigable
				url: entry.url
				target_snapshot_sandboxing_flags: target_snapshot_params.sandboxing_flags
				source_has_transient_activation: source_snapshot_params.has_transient_activation
				initiator_origin: state.initiator_origin or { entry.url.origin() }
				user_involvement: user_involvement
			}
		}
	}
	mut request := create_navigation_fetch_request(entry, navigable, source_snapshot_params)!
	response := perform_navigation_params_fetch(mut request, navigable, navigation_id, fetch_hook) or {
		return NavigableNavigationParamsResult{ network_error: err.msg() }
	}
	return navigation_params_from_fetch_response(entry, navigable, source_snapshot_params, target_snapshot_params, user_involvement, navigation_id, request, response)
}

fn create_navigation_fetch_request(entry &SessionHistoryEntry, navigable &NavigableModel, source_snapshot_params SourceSnapshotParams) !&fetch.Request {
	state := entry.document_state or { return error('Missing navigation document state') }
	mut request := fetch.Request.create()
	request.set_url(entry.url)
	if client := source_snapshot_params.fetch_client {
		request.set_client(client)
	}
	request.destination = .document
	request.target_is_nested_navigable = !navigable.is_top_level_traversable()
	request.credentials_mode = .include
	request.use_url_credentials = true
	request.redirect_mode = .manual
	request.mode = .navigate
	request.referrer_policy = state.request_referrer_policy.to_string()
	request.referrer = match state.request_referrer {
		RequestReferrerClient {
			fetch.Referrer{
				sentinel: if state.request_referrer == RequestReferrerClient.no_referrer {
					fetch.ReferrerSentinel.no_referrer
				} else {
					fetch.ReferrerSentinel.client
				}
			}
		}
		dom.URL {
			fetch.Referrer{
				url: state.request_referrer as dom.URL
			}
		}
	}
	if navigable.is_top_level_traversable() {
		request.top_level_navigation_initiator_origin = state.initiator_origin
		request.user_agent_initiated = state.user_agent_initiated
	}
	if request.client == none {
		request.origin = fetch.RequestOrigin{
			is_client: false
			origin: dom.origin_create_opaque()
		}
		request.referrer = fetch.Referrer{ sentinel: .no_referrer }
	}
	// Re-fetch an entry with the origin that created it, rather than the page
	// asking to traverse or reload it. This also preserves a resubmitted POST's
	// Origin header. Opaque initiators retain the ordinary fetch behavior.
	if initiator_origin := state.initiator_origin {
		if !initiator_origin.is_opaque() {
			request.origin = fetch.RequestOrigin{ is_client: false, origin: initiator_origin }
		}
	}
	match state.resource {
		POSTResource {
			post := state.resource as POSTResource
			request.method = 'POST'
			request.body = fetch.RequestBody{
				kind: .bytes
				bytes: post.request_body or { []u8{} }
			}
			mut content_type := match post.request_content_type {
				.application_x_www_form_urlencoded { 'application/x-www-form-urlencoded' }
				.multipart_form_data { 'multipart/form-data' }
				.text_plain { 'text/plain' }
			}
			for directive in post.request_content_type_directives {
				content_type += '; ${directive.type_}=${directive.value}'
			}
			request.header_list.append(http.Header{ name: 'Content-Type', value: content_type })
		}
		else {}
	}
	request.reload_navigation = state.reload_pending
	request.history_navigation = !state.reload_pending && state.ever_populated
	request.user_activation = source_snapshot_params.has_transient_activation
	return request
}

fn navigation_params_from_fetch_response(entry &SessionHistoryEntry, navigable &NavigableModel, source_snapshot_params SourceSnapshotParams, target_snapshot_params TargetSnapshotParams, user_involvement dom.UserNavigationInvolvement, navigation_id ?string, request &fetch.Request, response &fetch.Response) !NavigableNavigationParamsResult {
	state := entry.document_state or { return error('Missing navigation document state') }
	if response.is_network_error() {
		return NavigableNavigationParamsResult{
			network_error: response.network_error_message or { 'navigation fetch failed' }
		}
	}
	current_url := request.current_url()
	mut mutable_entry := unsafe { &SessionHistoryEntry(entry) }
	mutable_entry.url = current_url
	if !fetch.is_fetch_scheme(current_url.scheme()) {
		return NavigableNavigationParamsResult{
			non_fetch_params: &NonFetchSchemeNavigationParams{
				id: navigation_id
				navigable: navigable
				url: current_url
				target_snapshot_sandboxing_flags: target_snapshot_params.sandboxing_flags
				source_has_transient_activation: source_snapshot_params.has_transient_activation
				initiator_origin: current_url.origin()
				user_involvement: user_involvement
			}
		}
	}
	response_policy_container := create_a_policy_container_from_fetch_response(response)
	final_flags := target_snapshot_params.sandboxing_flags.union(csp_derived_sandboxing_flags(response_policy_container))
	response_url := response.url() or { current_url }
	response_origin := determine_the_origin(response_url, final_flags, state.initiator_origin)
	history_container := history_policy_container_value(state.history_policy_container)
	initiator_container := cloned_policy_container(&source_snapshot_params.source_policy_container)
	result_policy_container := determine_navigation_params_policy_container(response_url, history_container, initiator_container, none, response_policy_container)
	return NavigableNavigationParamsResult{
		navigation_params: &NavigationParams{
			id: navigation_id
			navigable: navigable
			request: request
			response: response
			origin: response_origin
			policy_container: result_policy_container
			final_sandboxing_flags: final_flags
			opener_policy: obtain_an_opener_policy(response, none)
			about_base_url: state.about_base_url
			user_involvement: user_involvement
			was_created_via_cross_origin_redirects: response.fetch_response_redirect_taint() != .same_origin
		}
	}
}

fn fetch_referrer_to_document_referrer(referrer fetch.Referrer) RequestReferrer {
	if url := referrer.url {
		return url
	}
	return if referrer.sentinel == .no_referrer {
		RequestReferrerClient.no_referrer
	} else {
		RequestReferrerClient.client
	}
}

// Helper for populate_session_history_entry_document, steps 7 and 8.
fn finalize_session_history_entry(entry &SessionHistoryEntry, received_navigation_params NavigableNavigationParamsResult, save_extra_document_state bool, completion_steps ?fn ()) {
	if document := entry.document() {
		if state := entry.document_state {
			mut mutable_state := unsafe { &DocumentState(state) }
			mutable_state.ever_populated = true
			if save_extra_document_state {
				mutable_state.origin = document.origin()
				if url_requires_storing_the_policy_container_in_history(document.url) {
					if params := received_navigation_params.navigation_params {
						mutable_state.history_policy_container = params.policy_container.clone()
					}
				}
			}
			request_referrer_is_client := mutable_state.request_referrer is RequestReferrerClient && mutable_state.request_referrer as RequestReferrerClient == .client
			if request_referrer_is_client {
				if params := received_navigation_params.navigation_params {
					if request := params.request {
						mutable_state.request_referrer = fetch_referrer_to_document_referrer(request.referrer)
					}
				}
			}
		}
	}
	if callback := completion_steps {
		callback()
	}
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#populate-the-session-history-entry's-document
pub fn (mut model NavigableModel) populate_session_history_entry_document(entry &SessionHistoryEntry, source_snapshot_params SourceSnapshotParams, target_snapshot_params TargetSnapshotParams, user_involvement dom.UserNavigationInvolvement, navigation_id ?string, navigation_params ?&NavigationParams, completion_steps ?fn ()) {
	_ = source_snapshot_params
	_ = target_snapshot_params
	_ = user_involvement
	mut state := entry.document_state or {
		new_state := &DocumentState{}
		mut mutable_entry := unsafe { &SessionHistoryEntry(entry) }
		mutable_entry.document_state = new_state
		new_state
	}
	mut installed_window_before_load := false
	if state.document == none {
		mut document := dom.Document.create(entry.url)
		if owner := model.page() {
			document.set_page(owner)
		}
		xml_type := navigation_response_xml_type(navigation_params)
		text_type := navigation_response_text_type(navigation_params)
		if type_ := xml_type {
			document.set_document_type(.xml)
			document.set_content_type(type_.essence())
		} else if type_ := text_type {
			document.set_document_type(.html)
			document.set_content_type(type_.essence())
			document.set_parser_cannot_change_the_mode(true)
			document.set_quirks_mode(.no)
		} else {
			document.set_document_type(.html)
			document.set_content_type('text/html')
		}
		document.set_origin(state.origin or { entry.url.origin() })
		document.set_about_base_url(state.about_base_url)
		document.set_navigation_id(navigation_id)
		document.set_allow_declarative_shadow_roots(true)
		if params := navigation_params {
			document.set_active_sandboxing_flag_bits(params.final_sandboxing_flags.bits)
			document.set_was_created_via_cross_origin_redirects(params.was_created_via_cross_origin_redirects)

			// Create and initialize a Document object, step 8: Let loadTimingInfo be a new document load timing info with
			// its navigation start time set to navigationParams's response's timing info's start time.
			// AD-HOC: Non-fetch navigations do not have timing info, so use the time at which the response was created.
			// NB: The navigation fetch here keeps no fetch timing info, so every navigation takes that branch. A window
			//     settings object's cross-origin isolated capability is always "No" for now.
			response_creation_time := f64(params.response.fetch_response_monotonic_response_time()) / 1e6
			navigation_start_time := highresolutiontime.coarsen_time(response_creation_time, false)
			document.set_load_timing_info(dom.DocumentLoadTimingInfo{
				navigation_start_time: navigation_start_time
				dom_loading_time: highresolutiontime.coarsen_time(highresolutiontime.unsafe_shared_current_time() - navigation_start_time,
					false)
			})
		}
		state.set_document(document)
		if context := model.context_ {
			document.set_cached_navigable(model.host_)
			context.associate_native_identity_with_document(document)
			mut mutable_context := unsafe { &BrowsingContextModel(context) }
			mutable_context.set_active_document(document)
			// Upstream creates the Window and its environment settings before
			// loading/parsing the response body.
			_ = WindowModel.create(document, context) or { unsafe { nil } }
			installed_window_before_load = true
			if params := navigation_params {
				settings_pointer := document.relevant_settings_object()
				if settings_pointer != unsafe { nil } {
					mut settings := unsafe { &EnvironmentSettingsObject(settings_pointer) }
					settings.set_policy_container(params.policy_container)
				}
			}
		}
		if hook := model.document_created_hook_ { hook(document) }
		mut payload := document.enter_native_storage()
		match state.resource {
			string {
				markup := state.resource as string
				if xml_type != none {
					parse_navigated_xml_document(document, markup)
				} else if type_ := text_type {
					if document.document_ready_to_run_scripts() {
						parse_navigated_text_document(document, markup, type_)
					} else {
						document_pointer := voidptr(document)
						document.set_deferred_parser_start(fn [document_pointer, markup, type_] () {
							document := unsafe { &dom.Document(document_pointer) }
							mut payload := document.enter_native_storage()
							parse_navigated_text_document(document, markup, type_)
							payload.finish()
						})
					}
				} else if document.document_ready_to_run_scripts() {
					parse_html_from_a_string(document, markup)
				} else {
					document_pointer := voidptr(document)
					document.set_deferred_parser_start(fn [document_pointer, markup] () {
						document := unsafe { &dom.Document(document_pointer) }
						mut payload := document.enter_native_storage()
						parse_html_from_a_string(document, markup)
						payload.finish()
					})
				}
			}
			EmptyDocumentResource {
				document.populate_with_html_head_and_body() or {}
			}
			POSTResource {
				// Fetching a POST resource is a host boundary. The document is still
				// initialized so response processing can populate it later.
				document.populate_with_html_head_and_body() or {}
			}
		}
		payload.finish()
		state.origin = document.origin()
		state.ever_populated = true
	}
	document := state.document or { return }
	if context := model.context_ {
		context.associate_native_identity_with_document(document)
		mut mutable_context := unsafe { &BrowsingContextModel(context) }
		mutable_context.set_active_document(document)
		if !installed_window_before_load {
			// Cross-document navigation installs a fresh Window while retaining the
			// browsing context's WindowProxy identity.
			_ = WindowModel.create(document, context) or { unsafe { nil } }
		}
	}
	if callback := completion_steps {
		callback()
	}
}

// https://html.spec.whatwg.org/multipage/document-lifecycle.html#read-xml
// The XML MIME type of a navigation response, when it has one.
fn navigation_response_xml_type(navigation_params ?&NavigationParams) ?mimesniff.MimeType {
	params := navigation_params or { return none }
	response := params.response.unsafe_response()
	type_ := fetch.extract_mime_type(response.header_list) or { return none }
	if !type_.is_xml() || type_.is_html() { return none }
	return type_
}

// Use the same literal-text tokenizer as DOM's text document loader. Parsing
// a text response as HTML would interpret tags and numeric references in it.
fn navigation_response_text_type(navigation_params ?&NavigationParams) ?mimesniff.MimeType {
	params := navigation_params or { return none }
	type_ := fetch.extract_mime_type(params.response.unsafe_response().header_list) or { return none }
	if type_.is_javascript() || type_.is_json() || type_.essence() in ['text/css', 'text/plain', 'text/vtt'] { return type_ }
	return none
}

fn parse_navigated_text_document(document &dom.Document, source string, type_ mimesniff.MimeType) {
	encoding_name := dom_loaded_text_parse_callback(unsafe { nil }, document, source.bytes(), type_.parameters()['charset'], document.url) or { return }
	mut owner := unsafe { &dom.Document(document) }
	owner.set_encoding(encoding_name)
}

fn parse_navigated_xml_document(document &dom.Document, source string) {
	mut owner := unsafe { &dom.Document(document) }
	// A malformed document keeps what was built before the error, as no
	// error document is translated for this path yet.
	parse_xml_document_source(document, source) or {}
	// The end steps of the HTML parser, which the XML parser has no state for.
	owner.update_readiness(.interactive)
	owner.update_readiness(.complete)
	owner.set_page_showing(true)
	owner.completely_finish_loading()
	owner.set_ready_for_post_load_tasks(true)
	if host := document.navigable() {
		if navigable := navigable_model_for_host(host) {
			mut mutable_navigable := unsafe { &NavigableModel(navigable) }
			mutable_navigable.clear_navigation_load_event_guard()
		}
	}
}

fn urls_differ_only_by_fragment(a dom.URL, b dom.URL) bool {
	mut left := a
	mut right := b
	left.set_fragment(none)
	right.set_fragment(none)
	return left == right && a.serialize() != b.serialize()
}

fn resolved_history_handling(behavior NavigationHistoryBehavior, document &dom.Document) HistoryHandlingBehavior {
	return match behavior {
		.push { .push }
		.replace { .replace }
		.auto {
			if document.get_is_initial_about_blank() {
				HistoryHandlingBehavior.replace
			} else {
				HistoryHandlingBehavior.push
			}
		}
	}
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#the-navigation-must-be-a-replace
pub fn navigation_must_be_a_replace(url dom.URL, document &dom.Document) bool {
	return url.scheme() == 'javascript' || document.get_is_initial_about_blank()
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#navigate
pub fn (mut model NavigableModel) navigate(params NavigableNavigateParams) ! {
	if model.has_been_destroyed() {
		return
	}
	if !model.has_session_history_entry_and_ready_ {
		model.pending_navigations_ << params
		return
	}
	if model.ongoing_navigation_.kind == .traversal {
		model.pending_navigations_ << params
		return
	}
	active_document := model.active_document() or {
		return error('InvalidStateError: navigable has no active document')
	}
	source_snapshot_params := snapshot_source_snapshot_params(params.source_document)
	if params.source_document == unsafe { nil } {
		assert params.user_involvement == .browser_ui
	} else {
		assert params.user_involvement != .browser_ui
		if !model.allowed_by_sandboxing_to_navigate(&model, source_snapshot_params) {
			return error('SecurityError: source is not allowed to navigate target')
		}
	}
	history_handling := resolved_history_handling(params.history_handling, active_document)
	if urls_differ_only_by_fragment(active_document.url, params.url) {
		model.navigate_to_a_fragment(params.url, history_handling, params.user_involvement, params.source_element, params.navigation_api_state, params.navigation_id or { rand.uuid_v4() })
		return
	}
	model.begin_navigation(params)
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#beginning-navigation
fn (mut model NavigableModel) begin_navigation(params NavigableNavigateParams) {
	if model.has_been_destroyed() {
		return
	}
	navigation_id := params.navigation_id or { rand.uuid_v4() }
	model.set_ongoing_navigation(NavigableOngoingNavigation{
		kind: .navigation
		id: navigation_id
	})
	active_document := model.active_document() or {
		model.set_ongoing_navigation(NavigableOngoingNavigation{})
		return
	}
	source_snapshot_params := snapshot_source_snapshot_params(params.source_document)
	initiator_origin := if params.source_document != unsafe { nil } { params.source_document.origin() }
		else if params.url.scheme() == 'javascript' { active_document.origin() }
		else { dom.origin_create_opaque() }
	history_handling := resolved_history_handling(params.history_handling, active_document)
	if params.url.scheme() == 'javascript' {
		model.navigate_to_a_javascript_url(params.url, history_handling, source_snapshot_params, initiator_origin, params.user_involvement, params.initial_insertion, navigation_id)
		return
	}
	mut state := &DocumentState{
		origin: params.url.origin()
		initiator_origin: initiator_origin
		user_agent_initiated: params.source_document == unsafe { nil }
		request_referrer_policy: params.referrer_policy
		resource: params.document_resource
		ever_populated: false
		navigable_target_name: model.target_name()
	}
	mut entry := &SessionHistoryEntry{
		url: params.url
		document_state: state
	}
	if serialized_state := params.navigation_api_state {
		entry.navigation_api_state = serialized_state
	}
	mut received_navigation_params := NavigableNavigationParamsResult{}
	if url_matches_about_blank(params.url) {
		creator := if params.source_document != unsafe { nil } { params.source_document } else { active_document }
		mut response := fetch.Response.create()
		response.url_list = [params.url]
		response.header_list.append(http.Header{name: 'Content-Type', value: 'text/html'})
		response.set_body_bytes([]u8{})
		flags := model.snapshot_target_snapshot_params().sandboxing_flags
		received_navigation_params = NavigableNavigationParamsResult{
			navigation_params: &NavigationParams{
				id: navigation_id
				navigable: &model
				response: response
				origin: determine_the_origin(params.url, flags, creator.origin())
				policy_container: cloned_policy_container(creator.policy_container())
				final_sandboxing_flags: flags
				about_base_url: creator.base_url()
				user_involvement: params.user_involvement
			}
		}
	} else if params.url.serialize() == 'about:srcdoc' && params.document_resource is string {
		navigation_params := create_navigation_params_from_a_srcdoc_resource(entry, &model, model.snapshot_target_snapshot_params(), params.user_involvement, navigation_id) or {
			model.set_ongoing_navigation(NavigableOngoingNavigation{})
			return
		}
		received_navigation_params = NavigableNavigationParamsResult{
			navigation_params: navigation_params
		}
	} else if !fetch.is_fetch_scheme(params.url.scheme()) {
		received_navigation_params = NavigableNavigationParamsResult{
			non_fetch_params: &NonFetchSchemeNavigationParams{
				id: navigation_id, navigable: &model, url: params.url,
				target_snapshot_sandboxing_flags: model.snapshot_target_snapshot_params().sandboxing_flags,
				source_has_transient_activation: source_snapshot_params.has_transient_activation,
				initiator_origin: initiator_origin, user_involvement: params.user_involvement
			}
		}
	} else if host := model.navigation_fetch_host_ {
		model.start_navigation_fetch(entry, params, source_snapshot_params, model.snapshot_target_snapshot_params(), history_handling, navigation_id, host)
		return
	} else if fetch_hook := model.navigation_fetch_hook_ {
		received_navigation_params = create_navigation_params_by_fetching(entry, &model, source_snapshot_params, model.snapshot_target_snapshot_params(), params.user_involvement, navigation_id, fetch_hook) or {
			model.set_ongoing_navigation(NavigableOngoingNavigation{})
			return
		}
	}
	model.finish_navigation_fetch(entry, params, source_snapshot_params, model.snapshot_target_snapshot_params(), history_handling, navigation_id, received_navigation_params)
}

fn (mut model NavigableModel) finish_navigation_fetch(entry &SessionHistoryEntry, params NavigableNavigateParams, source_snapshot_params SourceSnapshotParams, target_snapshot_params TargetSnapshotParams, history_handling HistoryHandlingBehavior, navigation_id string, received_navigation_params NavigableNavigationParamsResult) {
	// A pending response belongs to this navigation alone. Completion must not
	// commit into a destroyed context or clear a newer navigation's identity.
	if model.has_been_destroyed() || model.active_browsing_context() == none
		|| model.ongoing_navigation_.kind != .navigation || model.ongoing_navigation_.id != navigation_id { return }
	if received_navigation_params.network_error != none {
		model.set_ongoing_navigation(NavigableOngoingNavigation{})
		return
	}
	mut state := entry.document_state or { return }
	initiator_origin := state.initiator_origin or { dom.origin_create_opaque() }
	if non_fetch := received_navigation_params.non_fetch_params {
		state.set_document(attempt_to_create_a_non_fetch_scheme_document(non_fetch))
		if state.document == none {
			model.set_ongoing_navigation(NavigableOngoingNavigation{})
			return
		}
	}
	if navigation_params := received_navigation_params.navigation_params {
		if !navigation_response_allows_embedding(navigation_params) {
			model.set_ongoing_navigation(NavigableOngoingNavigation{})
			return
		}
		state.origin = navigation_params.origin
		state.about_base_url = navigation_params.about_base_url
		response := navigation_params.response.unsafe_response()
		if parse_content_disposition(response.header_list).is_attachment {
			model.handle_navigation_response_as_download(navigation_params,
				source_snapshot_params.allows_downloading, initiator_origin, []u8{})
			model.set_ongoing_navigation(NavigableOngoingNavigation{})
			model.set_delaying_load_events(false)
			return
		}
		if body := navigation_params.response.fetch_response_body() {
			state.resource = body.bytes().bytestr()
		}
	}
	model.populate_session_history_entry_document(entry, source_snapshot_params, target_snapshot_params, params.user_involvement, navigation_id, received_navigation_params.navigation_params, none)
	finalize_session_history_entry(entry, received_navigation_params, true, none)
	new_document := entry.document() or {
		model.set_ongoing_navigation(NavigableOngoingNavigation{})
		return
	}
	finalize_a_cross_document_navigation(&model, history_handling, params.user_involvement, entry, new_document, none)
}

fn (mut model NavigableModel) commit_navigation_entry(entry &SessionHistoryEntry, history_handling HistoryHandlingBehavior, document &dom.Document) {
	// The session history list is owned by the navigable, not the document.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut next_step := 0
	for existing in model.session_history_entries_ {
		if existing.step is int {
			next_step = math.max(next_step, (existing.step as int) + 1)
		}
	}
	mut mutable_entry := unsafe { &SessionHistoryEntry(entry) }
	match history_handling {
		.push {
			mutable_entry.step = next_step
			model.session_history_entries_ << entry
		}
		.replace {
			if current := model.current_session_history_entry_ {
				mutable_entry.step = current.step
				for index, candidate in model.session_history_entries_ {
					if voidptr(candidate) == voidptr(current) {
						model.session_history_entries_[index] = entry
						break
					}
				}
			} else {
				mutable_entry.step = next_step
				model.session_history_entries_ << entry
			}
		}
	}
	model.current_session_history_entry_ = entry
	model.set_ongoing_navigation(NavigableOngoingNavigation{})
	model.activate_history_entry(entry, document)
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#finalize-a-cross-document-navigation
pub fn finalize_a_cross_document_navigation(navigable &NavigableModel, history_handling HistoryHandlingBehavior, user_involvement dom.UserNavigationInvolvement, history_entry &SessionHistoryEntry, pending_document ?&dom.Document, on_complete ?TraversableHistoryStepCompletion) {
	_ = user_involvement
	if navigable.has_been_destroyed() {
		complete_history_step(on_complete, .applied)
		return
	}
	mut model := unsafe { &NavigableModel(navigable) }
	if parent_document := model.container_document() {
		model.set_navigation_load_event_guard(parent_document)
	}
	model.set_delaying_load_events(false)
	new_document := pending_document or {
		complete_history_step(on_complete, .applied)
		return
	}
	active_document := model.active_document() or {
		complete_history_step(on_complete, .applied)
		return
	}
	if model.host_.parent() == none {
		mut is_auxiliary_with_opener := false
		if context := model.context_ {
			is_auxiliary_with_opener = context.is_auxiliary()
				&& context.opener_browsing_context() != none
		}
		if !is_auxiliary_with_opener && !new_document.origin().is_same_origin(active_document.origin()) {
			if state := history_entry.document_state {
				mut mutable_state := unsafe { &DocumentState(state) }
				mutable_state.navigable_target_name = ''
			}
		}
	}
	if history_handling == .push {
		if active := model.active_session_history_entry_ {
			if active.step is int {
				active_step := active.step as int
				mut retained := []&SessionHistoryEntry{}
				for candidate in model.session_history_entries_ {
					match candidate.step {
						int {
							if candidate.step as int <= active_step {
								retained << candidate
							}
						}
						SessionHistoryEntryPending { retained << candidate }
					}
				}
				model.session_history_entries_ = retained
			}
		}
	} else if current := model.active_session_history_entry_ {
		if new_state := history_entry.document_state {
			if old_state := current.document_state {
				if new_origin := new_state.origin {
					if old_origin := old_state.origin {
						if new_origin.is_same_origin(old_origin) {
							mut mutable_entry := unsafe { &SessionHistoryEntry(history_entry) }
							mutable_entry.navigation_api_key = current.navigation_api_key
						}
					}
				}
			}
		}
	}
	model.commit_navigation_entry(history_entry, history_handling, new_document)
	if container := model.container() {
		mut node := unsafe { &dom.Node(container.as_node()) }
		node.set_needs_layout_update(.finalize_a_cross_document_navigation)
	}
	complete_history_step(on_complete, .applied)
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#url-and-history-update-steps
pub fn perform_url_and_history_update_steps(document &dom.Document, new_url dom.URL, serialized_data ?SerializationRecord, history_handling_ HistoryHandlingBehavior) ! {
	model_pointer := NavigableModel.navigable_with_active_document(document) or {
		return error('InvalidStateError: document has no navigable')
	}
	mut model := unsafe { &NavigableModel(model_pointer) }
	active_entry := model.active_session_history_entry() or {
		return error('InvalidStateError: navigable has no active history entry')
	}
	model.save_persisted_state_to_active_session_history_entry()
	// The navigable's session history outlives the document whose script
	// pushed or replaced this entry; keep the entry and its payload persistent.
	persistent := platform.enter_persistent()
	new_entry := &SessionHistoryEntry{
		url: persistent_session_history_url(new_url)
		classic_history_api_state: persistent_serialization_record(serialized_data or {
			active_entry.classic_history_api_state
		})
		document_state: active_entry.document_state
		scroll_restoration_mode: active_entry.scroll_restoration_mode
		scroll_position_data: active_entry.scroll_position_data
	}
	platform.leave_persistent(persistent)
	history_handling := if document.get_is_initial_about_blank() {
		HistoryHandlingBehavior.replace
	} else {
		history_handling_
	}
	mut mutable_document := unsafe { &dom.Document(document) }
	if history_handling == .push {
		mut history := mutable_document.history()
		history.index++
		history.length = history.index + 1
	}
	document_entry := &dom.SessionHistoryEntry{
		url: new_url
		classic_history_api_state: dom.DOMSerializationRecord{
			data: new_entry.classic_history_api_state.data.clone()
		}
	}
	if serialized_data != none {
		mutable_document.restore_the_history_object_state(document_entry)
	}
	mutable_document.set_url(new_url)
	mutable_document.set_latest_entry(document_entry)
	active_document := model.active_document() or {
		return error('InvalidStateError: navigable has no active document')
	}
	model.commit_navigation_entry(new_entry, history_handling, active_document)
	if mut window := model.active_window() {
		mut navigation := unsafe { &Navigation(window.navigation()) }
		navigation.update_the_navigation_api_entries_for_a_same_document_navigation(new_entry, if history_handling == .push {
			.push
		} else {
			.replace
		})
	}
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#scroll-to-fragid
fn (mut model NavigableModel) navigate_to_a_fragment(url dom.URL, history_handling HistoryHandlingBehavior, user_involvement dom.UserNavigationInvolvement, source_element ?&dom.Element, navigation_api_state ?SerializationRecord, navigation_id string) {
	_ = user_involvement
	_ = source_element
	model.set_ongoing_navigation(NavigableOngoingNavigation{
		kind: .navigation
		id: navigation_id
	})
	current := model.current_session_history_entry_ or {
		model.set_ongoing_navigation(NavigableOngoingNavigation{})
		return
	}
	model.save_persisted_state_to_active_session_history_entry()
	// Fragment entries join the navigable's session history, which outlives
	// the document that navigated.
	persistent := platform.enter_persistent()
	mut entry := current.clone()
	entry.url = persistent_session_history_url(url)
	platform.leave_persistent(persistent)
	if state := entry.document_state {
		mut mutable_state := unsafe { &DocumentState(state) }
		mutable_state.set_document(model.active_document())
	}
	if value := navigation_api_state {
		entry.navigation_api_state = value
	}
	active_document := model.active_document() or {
		model.set_ongoing_navigation(NavigableOngoingNavigation{})
		return
	}
	model.commit_navigation_entry(entry, history_handling, active_document)
	if mut document := model.active_document() {
		document.set_url(url)
		document.try_to_scroll_to_the_fragment()
	}
}

// `javascript:` execution is supplied by the embedding script runtime. A
// string result becomes a replacement HTML document, as required by HTML.
pub fn (mut model NavigableModel) evaluate_javascript_url(url dom.URL, new_document_origin dom.Origin, user_involvement dom.UserNavigationInvolvement, navigation_id string) ?&dom.Document {
	_ = user_involvement
	active_document := model.active_document() or { return none }
	if active_document.as_node().is_scripting_disabled() {
		return none
	}
	if javascript_url_is_blocked_by_csp(active_document,url) { return none }
	hook := model.javascript_url_hook_ or { return none }
	source := javascript_url_source(url)
	result := hook(source, active_document) or { return none }
	// A javascript: replacement retains the target's creation sandbox as well
	// as restrictions imposed by the active document's CSP policy container.
	final_sandbox_flags := model.snapshot_target_snapshot_params().sandboxing_flags.union(
		csp_derived_sandboxing_flags(active_document.policy_container()))
	mut document := dom.Document.create(active_document.url)
	document.set_document_type(.html)
	document.set_content_type('text/html')
	document.set_active_sandboxing_flag_bits(final_sandbox_flags.bits)
	document.set_origin(new_document_origin)
	document.set_navigation_id(navigation_id)
	document.set_allow_declarative_shadow_roots(true)
	parse_html_from_a_string(document, result)
	return document
}

fn (mut model NavigableModel) navigate_to_a_javascript_url(url dom.URL, history_handling HistoryHandlingBehavior, source_snapshot_params SourceSnapshotParams, initiator_origin dom.Origin, user_involvement dom.UserNavigationInvolvement, initial_insertion InitialInsertion, navigation_id string) {
	_ = source_snapshot_params
	_ = initial_insertion
	document := model.evaluate_javascript_url(url, initiator_origin, user_involvement, navigation_id) or {
		model.set_ongoing_navigation(NavigableOngoingNavigation{})
		return
	}
	mut user_agent_initiated := false
	if old_entry := model.active_session_history_entry_ {
		if old_state := old_entry.document_state {
			user_agent_initiated = old_state.user_agent_initiated
		}
	}
	state := &DocumentState{
		document: document
		document_id_: document.unique_id()
		user_agent_initiated: user_agent_initiated
		origin: initiator_origin
		ever_populated: true
		navigable_target_name: model.target_name()
	}
	entry := &SessionHistoryEntry{
		url: document.url
		document_state: state
	}
	model.commit_navigation_entry(entry, history_handling, document)
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#reload
pub fn (mut model NavigableModel) reload(navigation_api_state ?SerializationRecord, user_involvement dom.UserNavigationInvolvement) {
	current := model.current_session_history_entry_ or { return }
	mut entry := current.clone()
	if state := entry.document_state {
		mut mutable_state := unsafe { &DocumentState(state) }
		mutable_state.reload_pending = true
		mutable_state.set_document(none)
	}
	if value := navigation_api_state {
		entry.navigation_api_state = value
	}
	model.set_ongoing_navigation(NavigableOngoingNavigation{
		kind: .navigation
		id: rand.uuid_v4()
	})
	active_document := model.active_document() or { return }
	source_snapshot_params := snapshot_source_snapshot_params(active_document)
	model.populate_session_history_entry_document(entry, source_snapshot_params, model.snapshot_target_snapshot_params(), user_involvement, model.ongoing_navigation_.id, none, none)
	document := entry.document() or {
		model.set_ongoing_navigation(NavigableOngoingNavigation{})
		return
	}
	// A reload rebuilds child navigables from the replacement document. Do not
	// carry the previous document's child history identities into that tree.
	// This mutates only the cloned entry, so a failed reload leaves the active
	// entry and its child histories intact.
	if reloaded_state := entry.document_state {
		mut mutable_reloaded_state := unsafe { &DocumentState(reloaded_state) }
		mutable_reloaded_state.nested_histories.clear()
		mutable_reloaded_state.reload_pending = false
	}
	model.commit_navigation_entry(entry, .replace, document)
}

pub fn (model &NavigableModel) allowed_by_sandboxing_to_navigate(target &NavigableModel, source_snapshot_params SourceSnapshotParams) bool {
	if same_navigable_model(model, target) || model.is_ancestor_of(target) {
		return true
	}
	if target.is_ancestor_of(model) {
		if !target.is_top_level_traversable() {
			return true
		}
		if source_snapshot_params.has_transient_activation && source_snapshot_params.sandboxing_flags.contains(.sandboxed_top_level_navigation_with_user_activation) {
			return false
		}
		if !source_snapshot_params.has_transient_activation && source_snapshot_params.sandboxing_flags.contains(.sandboxed_top_level_navigation_without_user_activation) {
			return false
		}
		return true
	}
	if source_snapshot_params.sandboxing_flags.contains(.sandboxed_navigation) {
		return false
	}
	return true
}

pub fn (model &NavigableModel) snapshot_target_snapshot_params() TargetSnapshotParams {
	context := model.active_browsing_context() or { return TargetSnapshotParams{} }
	return TargetSnapshotParams{
		sandboxing_flags: determine_the_creation_sandboxing_flags(context, model.container())
	}
}

pub fn (model &NavigableModel) viewport_scroll_offset() css.CSSPixelPoint {
	document := model.active_document() or { return css.CSSPixelPoint.from_values(0, 0) }
	rect := document.viewport_rect()
	return css.CSSPixelPoint.from_values(rect.x, rect.y)
}

pub fn (model &NavigableModel) viewport_size() css.CSSPixelSize {
	document := model.active_document() or { return css.CSSPixelSize.from_values(0, 0) }
	rect := document.viewport_rect()
	return css.CSSPixelSize.from_values(rect.width, rect.height)
}

pub fn (model &NavigableModel) viewport_rect() css.CSSPixelRect {
	document := model.active_document() or { return css.CSSPixelRect.new(0, 0, 0, 0) }
	rect := document.viewport_rect()
	return css.CSSPixelRect.new(rect.x, rect.y, rect.width, rect.height)
}

fn (mut model NavigableModel) resize_backing_stores_if_needed(resizing bool) bool {
	viewport := model.viewport_size()
	device_scale := if page_ := model.page() {
		page_.device_pixels_per_css_pixel()
	} else {
		1.0
	}
	device_viewport := painting.IntSize{
		width: int(viewport.width().to_double() * device_scale)
		height: int(viewport.height().to_double() * device_scale)
	}
	mut manager := model.backing_store_manager_
	if !manager.resize_if_needed(device_viewport, resizing, model.is_top_level_traversable(), model.is_svg_page_) {
		return false
	}
	front_id := int(manager.front_bitmap_id)
	back_id := int(manager.back_bitmap_id)
	mut allocation := ?RenderingBackingStoreAllocation(none)
	if model.is_top_level_traversable() {
		if page_ := model.page() {
			allocation = RenderingBackingStoreAllocation{
				target: voidptr(page_)
				callback: navigable_backing_store_allocation_callback
			}
		}
	}
	model.rendering_thread_.update_backing_stores(RenderingSize{
		width: device_viewport.width
		height: device_viewport.height
	}, front_id, back_id, allocation)
	return true
}

fn (mut model NavigableModel) scroll_offset_did_change() {
	if mut document := model.active_document() {
		document.append_pending_scroll_event(dom.PendingScrollEvent{
			target: document.as_node()
			type_: 'scroll'
		})
	}
}

pub fn (model &NavigableModel) to_top_level_rect(input css.CSSPixelRect) css.CSSPixelRect {
	position := model.to_top_level_position(input.location())
	return css.CSSPixelRect.new(position.x().to_double(), position.y().to_double(), input.width.to_double(), input.height.to_double())
}

pub fn (model &NavigableModel) to_top_level_position(input css.CSSPixelPoint) css.CSSPixelPoint {
	mut x := input.x().to_double()
	mut y := input.y().to_double()
	mut current := unsafe { model }
	for !current.is_top_level_traversable() {
		container := current.container() or { return css.CSSPixelPoint.from_values(0, 0) }
		rect := container.get_bounding_client_rect()
		x += rect.x
		y += rect.y
		current = current.parent_ or { break }
	}
	return css.CSSPixelPoint.from_values(x, y)
}

// https://drafts.csswg.org/cssom-view/#resizing-viewports
pub fn (mut model NavigableModel) set_viewport_size(size css.CSSPixelSize) {
	document := model.active_document() or { return }
	old_rect := document.viewport_rect()
	width := size.width().to_double()
	height := size.height().to_double()
	if old_rect.width == width && old_rect.height == height {
		return
	}
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_viewport_rect(dom.Rect{old_rect.x, old_rect.y, width, height})
	if !model.is_svg_page_ {
		model.backing_store_manager_.restart_resize_timer()
		model.resize_backing_stores_if_needed(true)
		model.pending_set_browser_zoom_request_ = false
	}
	mutable_document.set_needs_repaint()
	mutable_document.inform_all_viewport_clients_about_the_current_viewport_rect()
	model.needs_repaint_ = true
}

pub fn (mut model NavigableModel) clamp_viewport_scroll_offset() {
	document := model.active_document() or { return }
	if !document.layout_is_up_to_date() || document.layout_node() == none {
		return
	}
	viewport := document.viewport_rect()
	paintable := document.as_node().paintable_box() or { return }
	clamped := paintable.clamp_scroll_offset(dom.CSSPixelPoint_{x_: viewport.x, y_: viewport.y})
	if clamped.x() != viewport.x || clamped.y() != viewport.y {
		model.perform_scroll_of_viewport_scrolling_box(css.CSSPixelPoint.from_values(clamped.x(), clamped.y()))
	}
}

pub fn (mut model NavigableModel) perform_scroll_of_viewport_scrolling_box(position css.CSSPixelPoint) {
	document := model.active_document() or { return }
	viewport := document.viewport_rect()
	x := position.x().to_double()
	y := position.y().to_double()
	if x == viewport.x && y == viewport.y {
		mut loop := main_thread_event_loop()
		loop.schedule()
		return
	}
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_viewport_rect(dom.Rect{x, y, viewport.width, viewport.height})
	model.scroll_offset_did_change()
	mutable_document.set_needs_repaint()
	mutable_document.invalidate_scroll_state()
	mutable_document.inform_all_viewport_clients_about_the_current_viewport_rect()
	model.needs_repaint_ = true
	mut loop := main_thread_event_loop()
	loop.schedule()
}

pub fn (model &NavigableModel) has_a_rendering_opportunity() bool {
	if main_thread_event_loop().running_synchronous_rendering_update_ {
		return true
	}
	page_ := model.page() or { return false }
	return page_.client_has_rendering_opportunity()
}

pub fn (model &NavigableModel) is_local_root() bool {
	page_ := model.page() or { return false }
	root := page_.local_root_navigable() or { return false }
	return same_dom_navigable(root, model.host_)
}

pub fn (mut model NavigableModel) inform_the_navigation_api_about_child_navigable_destruction() {
	model.inform_the_navigation_api_about_aborting_navigation()
	model.set_ongoing_navigation(NavigableOngoingNavigation{})
}

fn (mut model NavigableModel) inform_the_navigation_api_about_aborting_navigation() {
	if mut window := model.active_window() {
		mut navigation := unsafe { &Navigation(window.navigation()) }
		navigation.abort_the_ongoing_navigation(dom.js_string('AbortError: navigation aborted'))
	}
}

pub fn (model &NavigableModel) selected_text() string {
	mut document := model.active_document() or { return '' }
	document.update_layout(.navigable_selected_text)
	selection := document.get_selection() or { return '' }
	if active_element := document.active_element() {
		if active_element.local_name() == 'input'
			&& form_element_input_type(active_element) == 'password' {
			return ''
		}
	}
	if form_text := selection.try_form_control_selected_text_for_stringifier() {
		return form_text
	}
	range := selection.range() or { return '' }
	return editing.serialize_range_as_plain_text_for_clipboard(range)
}

pub fn (model &NavigableModel) selected_html_for_clipboard() string {
	document := model.active_document() or { return '' }
	selection := document.get_selection() or { return '' }
	if selection.try_form_control_selected_text_for_stringifier() != none {
		return ''
	}
	range := selection.range() or { return '' }
	return editing.serialize_range_as_html_for_clipboard(range)
}

pub fn (model &NavigableModel) cut_selected_text() string {
	document := model.active_document() or { return '' }
	target := document.active_input_events_target(none) or { return '' }
	text := model.selected_text()
	if text == '' {
		return ''
	}
	target.handle_delete(dom.input_type_delete_by_cut)
	return text
}

pub fn (mut model NavigableModel) select_all() {
	document := model.active_document() or { return }
	selection := document.get_selection() or { return }
	if target := document.active_input_events_target(none) {
		target.select_all()
	} else if body := document.body() {
		mut mutable_selection := unsafe { &dom.Selection(selection) }
		mutable_selection.select_all_children(unsafe { &dom.Node(body) }) or {}
	}
}

pub fn (mut model NavigableModel) paste(text string) {
	if model.active_document() == none {
		return
	}
	model.last_pasted_text_ = text
	if hook := model.paste_hook_ {
		hook(text)
	}
}

pub fn (mut model NavigableModel) undo() {
	document := model.active_document() or { return }
	editing.perform_history_action(document, .undo)
}

pub fn (mut model NavigableModel) redo() {
	document := model.active_document() or { return }
	editing.perform_history_action(document, .redo)
}

pub fn (model &NavigableModel) last_pasted_text() string {
	return model.last_pasted_text_
}

pub fn (model &NavigableModel) snapshot_containing_block() css.CSSPixelRect {
	return model.viewport_rect()
}

pub fn (model &NavigableModel) snapshot_containing_block_size() css.CSSPixelSize {
	return model.snapshot_containing_block().size()
}

pub fn (model &NavigableModel) register_navigation_observer(observer &NavigationObserver) {
	mut host := unsafe { &dom.Navigable(model.host_) }
	handle := voidptr(observer)
	if handle !in host.navigation_observer_handles {
		host.navigation_observer_handles << handle
	}
}

pub fn (model &NavigableModel) unregister_navigation_observer(observer &NavigationObserver) {
	mut host := unsafe { &dom.Navigable(model.host_) }
	handle := voidptr(observer)
	host.navigation_observer_handles = host.navigation_observer_handles.filter(it != handle)
}

pub fn (mut model NavigableModel) stop_loading() {
	if mut document := model.active_document() {
		if document.get_unload_counter() == 0 && model.ongoing_navigation_.kind == .navigation {
			model.set_ongoing_navigation(NavigableOngoingNavigation{})
		}
		document.abort_a_document_and_its_descendants()
	}
}

pub fn (mut model NavigableModel) clear_pending_navigations() {
	model.pending_navigations_.clear()
}

pub fn (model &NavigableModel) has_session_history_entry_and_ready_for_navigation() bool {
	return model.has_session_history_entry_and_ready_
}

pub fn (mut model NavigableModel) set_has_session_history_entry_and_ready_for_navigation() {
	model.has_session_history_entry_and_ready_ = true
	if current := model.current_session_history_entry_ {
		if current.step is SessionHistoryEntryPending {
			mut mutable_current := unsafe { &SessionHistoryEntry(current) }
			parent_step := if parent := model.parent_ {
				if parent_entry := parent.current_session_history_entry_ {
					match parent_entry.step {
						int { parent_entry.step as int }
						SessionHistoryEntryPending { 0 }
					}
				} else {
					0
				}
			} else {
				0
			}
			mutable_current.step = parent_step
		}
	}
	for model.pending_navigations_.len > 0 {
		params := model.pending_navigations_[0]
		model.pending_navigations_.delete(0)
		model.begin_navigation(params)
	}
}

pub fn (mut model NavigableModel) ready_to_paint() {
	model.ready_to_paint_ = true
}

pub fn (mut model NavigableModel) record_display_list_and_scroll_state(_ dom.PaintConfig) {
	model.needs_repaint_ = false
	model.paint_count_++
	if hook := model.paint_hook_ {
		hook()
	}
}

pub fn (mut model NavigableModel) paint_next_frame() {
	if !model.is_top_level_traversable() || !model.ready_to_paint_ {
		return
	}
	model.record_display_list_and_scroll_state(dom.PaintConfig{})
}

pub fn (mut model NavigableModel) render_screenshot(_ dom.PaintConfig) {
	model.record_display_list_and_scroll_state(dom.PaintConfig{})
	model.screenshot_count_++
	if hook := model.screenshot_hook_ {
		rect := model.viewport_rect()
		hook(dom.Rect{rect.x.to_double(), rect.y.to_double(), rect.width.to_double(), rect.height.to_double()})
	}
}

pub fn (model &NavigableModel) paint_count() u64 {
	return model.paint_count_
}

pub fn (model &NavigableModel) screenshot_count() u64 {
	return model.screenshot_count_
}

pub fn (model &NavigableModel) needs_repaint() bool {
	return model.needs_repaint_
}

pub fn (mut model NavigableModel) set_needs_repaint() {
	model.needs_repaint_ = true
}

pub fn (mut model NavigableModel) scroll_viewport_by_delta(delta css.CSSPixelPoint) &dom.Promise {
	current := model.viewport_scroll_offset()
	return model.perform_a_scroll_of_the_viewport_with_snap_strategy(current.plus(delta),
		dom.ScrollSnapSelectionStrategy_{
			type_: .end_position_and_direction
			start_offset: dom.CSSPixelPoint_{ x_: current.x().to_double(), y_: current.y().to_double() }
			displacement: dom.CSSPixelPoint_{ x_: delta.x().to_double(), y_: delta.y().to_double() }
		})
}

// https://drafts.csswg.org/cssom-view/#viewport-perform-a-scroll
pub fn (mut model NavigableModel) perform_a_scroll_of_the_viewport(position css.CSSPixelPoint) &dom.Promise {
	return model.perform_a_scroll_of_the_viewport_with_snap_strategy(position,
		dom.ScrollSnapSelectionStrategy_{})
}

fn (mut model NavigableModel) perform_a_scroll_of_the_viewport_with_snap_strategy(position css.CSSPixelPoint,
	strategy dom.ScrollSnapSelectionStrategy_) &dom.Promise {
	return model.perform_a_scroll_of_the_viewport_with_options(position, .auto_, strategy)
}

pub fn (mut model NavigableModel) perform_a_scroll_of_the_viewport_with_options(position css.CSSPixelPoint,
	behavior dom.ScrollBehavior, strategy dom.ScrollSnapSelectionStrategy_) &dom.Promise {
	document := model.active_document() or {
		return model.resolved_scroll_promise()
	}
	mut mutable_document := unsafe { &dom.Document(document) }
	viewport := document.viewport_rect()
	mut layout_delta := dom.CSSPixelPoint_{x_: position.x().to_double() - viewport.x, y_: position.y().to_double() - viewport.y}
	if mut window := model.active_window() {
		if mut visual := window.visual_viewport() {
			dx := position.x().to_double() - visual.page_left()
			dy := position.y().to_double() - visual.page_top()
			visual_dx := math.min(viewport.width - visual.width(), math.max(0.0, visual.offset_left() + dx)) - visual.offset_left()
			visual_dy := math.min(viewport.height - visual.height(), math.max(0.0, visual.offset_top() + dy)) - visual.offset_top()
			layout_delta = dom.CSSPixelPoint_{x_: dx - visual_dx, y_: dy - visual_dy}
			visual_delta := css.CSSPixelPoint.from_values(visual_dx, visual_dy)
			visual.scroll_by(visual_delta)
			if visual_dx == 0 && visual_dy == 0 {
				mutable_document.set_needs_repaint()
			} else {
				mutable_document.append_pending_scroll_event(dom.PendingScrollEvent{event_target: unsafe { &dom.EventTarget(visual) }, type_: 'scrollend'})
			}
		}
	}
	mutable_document.update_layout(.navigable_viewport_scroll)
	requested := dom.CSSPixelPoint_{x_: viewport.x + layout_delta.x(), y_: viewport.y + layout_delta.y()}
	paintable := document.as_node().paintable_box() or { return model.resolved_scroll_promise() }
	clamped := paintable.clamp_scroll_offset(requested)
	destination := mutable_document.adjust_viewport_scroll_destination(clamped, strategy)
	if strategy.type_ == .end_position_and_direction {
		final_position := paintable.clamp_scroll_offset(destination.position)
		mutable_document.record_relative_scroll_for_queries(none, dom.CSSPixelPoint_{x_: final_position.x() - viewport.x, y_: final_position.y() - viewport.y})
	}
	return model.perform_main_thread_scroll(compositor.AsyncScrollNodeStableId{
		node_id: u64(document.as_node().unique_id())
		kind: .viewport
	}, paintable.clamp_scroll_offset(destination.position), behavior, document.document_element())
}

pub fn (mut model NavigableModel) reset_zoom() {
	if mut window := model.active_window() {
		if mut viewport := window.visual_viewport() {
			viewport.reset()
		}
	}
}

pub fn (model &NavigableModel) has_inclusive_ancestor_with_visibility_hidden() bool {
	mut current := unsafe { model }
	for {
		if container := current.container() {
			if computed := container.el_computed_properties() {
				if computed.visibility() == .hidden {
					return true
				}
			}
		}
		current = current.parent_ or { break }
	}
	return false
}

pub fn (model &NavigableModel) has_pending_navigations() bool {
	return model.pending_navigations_.len > 0
}

pub fn (mut model NavigableModel) set_has_been_destroyed() {
	if mut controller := model.navigation_fetch_controller_ {
		model.navigation_fetch_controller_ = none
		controller.stop_fetch()
	}
	if model.delaying_load_events_ { model.set_delaying_load_events(false) }
	mut host := unsafe { &dom.Navigable(model.host_) }
	host.set_has_been_destroyed()
	model.resolve_all_pending_main_thread_scrolls()
	model.inform_the_navigation_api_about_child_navigable_destruction()
}

pub fn (mut model NavigableModel) remove_from_all_navigables() {
	model.resolve_all_pending_main_thread_scrolls()
	model.set_active_document(none)
	// Remove in place: a filtered copy would reallocate the process-wide list
	// in the arena of whichever document is being torn down.
	for index, candidate in html_all_navigable_models {
		if voidptr(candidate) == voidptr(&model) {
			html_all_navigable_models.delete(index)
			break
		}
	}
}

pub fn (model &NavigableModel) has_been_destroyed() bool {
	return model.host_.has_been_destroyed()
}

pub fn (mut model NavigableModel) set_pending_set_browser_zoom_request(value bool) {
	model.pending_set_browser_zoom_request_ = value
}

pub fn (model &NavigableModel) pending_set_browser_zoom_request() bool {
	return model.pending_set_browser_zoom_request_
}

pub fn (mut model NavigableModel) set_should_show_line_box_borders(value bool) {
	model.should_show_line_box_borders_ = value
	model.set_needs_repaint()
	for child in model.child_navigables() {
		mut mutable_child := unsafe { &NavigableModel(child) }
		mutable_child.set_should_show_line_box_borders(value)
	}
}

pub fn (model &NavigableModel) should_show_line_box_borders() bool {
	return model.should_show_line_box_borders_
}

pub fn (model &NavigableModel) force_dark_enabled() bool {
	return model.force_dark_enabled_
}

pub fn (model &NavigableModel) force_dark_foreground_threshold() i32 {
	return model.force_dark_foreground_threshold_
}

pub fn (model &NavigableModel) force_dark_background_threshold() i32 {
	return model.force_dark_background_threshold_
}

fn force_dark_lists_dark_scheme(schemes []string) bool {
	return 'dark' in schemes
}

// The root element's color-scheme list wins when it has generated layout;
// otherwise the document's meta color-scheme list decides the opt-out.
pub fn (model &NavigableModel) active_document_opts_out_of_force_dark() bool {
	document := model.active_document() or { return false }
	if root := document.document_element() {
		if root.as_node().layout_node() != none {
			if computed := root.el_computed_properties() {
				if computed.color_scheme_only() {
					return true
				}
				schemes := computed.color_schemes()
				if schemes.len > 0 {
					return force_dark_lists_dark_scheme(schemes)
				}
			}
		}
	}
	if document.supported_color_schemes_are_only() {
		return true
	}
	if schemes := document.supported_color_schemes() {
		return force_dark_lists_dark_scheme(schemes)
	}
	return false
}

pub fn (model &NavigableModel) force_dark_applies_to_active_document() bool {
	return model.force_dark_enabled_ && !model.active_document_opts_out_of_force_dark()
}

pub fn (mut model NavigableModel) set_force_dark_enabled(value bool) {
	if model.force_dark_enabled_ == value {
		return
	}
	model.force_dark_enabled_ = value
	model.set_needs_repaint()
	if document := model.active_document() {
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.bump_style_environment_version()
		mutable_document.set_needs_media_query_evaluation()
		mutable_document.set_needs_full_style_update(true)
		mutable_document.set_needs_repaint()
	}
	for child in model.child_navigables() {
		mut mutable_child := unsafe { &NavigableModel(child) }
		mutable_child.set_force_dark_enabled(value)
	}
}

pub fn (mut model NavigableModel) set_force_dark_thresholds(foreground i32, background i32) {
	if model.force_dark_foreground_threshold_ == foreground
		&& model.force_dark_background_threshold_ == background {
		return
	}
	model.force_dark_foreground_threshold_ = foreground
	model.force_dark_background_threshold_ = background
	model.set_needs_repaint()
	if document := model.active_document() {
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.set_needs_repaint()
	}
	for child in model.child_navigables() {
		mut mutable_child := unsafe { &NavigableModel(child) }
		mutable_child.set_force_dark_thresholds(foreground, background)
	}
}
