// Copyright (c) 2020-2026, Ladybird contributors.
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Page/Page.{h,cpp}. PageClient IPC calls are recorded as
// ClientEvent values so the browser/embedder boundary is deterministic.
module page

import compositor
import dom
import editing
import loader
import math

pub enum PendingDialog {
	none
	alert
	confirm
	prompt
}

pub enum PendingNonBlockingDialog {
	none
	color_picker
	file_picker
	select
}

pub enum MuteState {
	unmuted
	muted
}

pub enum ScreenWakeLockState {
	released
	acquired
}

pub enum CaseSensitivity {
	case_sensitive
	case_insensitive
}

pub enum WrapAround {
	yes
	no
}

pub enum ClearSelectionOnNoMatch {
	yes
	no
}

pub struct FindInPageQuery {
pub:
	string_          string
	case_sensitivity CaseSensitivity = .case_insensitive
	wrap_around      WrapAround      = .yes
	clear_selection_on_no_match ClearSelectionOnNoMatch = .yes
}

pub struct FindInPageResult {
pub:
	current_match_index uint
	total_match_count   ?uint
}

pub struct SearchDocument {
pub:
	id   string
	url  string
	text string
}

pub struct FindMatch {
pub:
	document_id string
	start       int
	end         int
	range       ?&dom.Range
}

pub struct ClientEvent {
pub:
	name string
	text string
}

pub struct MediaElementState {
pub mut:
	playing                      bool
	muted                        bool
	looping                      bool
	controls                     bool
	fullscreen                   bool
	document_id                  dom.UniqueNodeID
	playing_audio                bool
	is_video                     bool
	has_video_sink               bool
	video_sink_attached          bool
	video_sink_is_ticking        bool = true
	video_sink_sync_count        u64
	video_sink_restore_count     u64
	video_sink_detach_count      u64
	video_paint_facts_push_count u64
	page_mute_change_count       u64
}

pub enum CanvasContextKind {
	none
	canvas_2d
	webgl
}

pub struct CanvasElementState {
pub mut:
	context_kind                 CanvasContextKind
	dirty                        bool
	content_generation           u64
	prepare_call_count           u64
	context_prepare_count        u64
	paint_facts_push_count       u64
	backing_storage_loss_count   u64
	webgl_restore_count          u64
	webgl_connection_loss_count u64
	webgl_context_lost           bool
}

pub enum ContextMenuRequestKind {
	page
	image
	link
	media
}

pub struct ContextMenuRequest {
pub:
	kind   ContextMenuRequestKind = .page
	target &dom.Node = unsafe { nil }
}

pub enum FullscreenPromiseState {
	pending
	fulfilled
	rejected
}

@[heap]
pub struct FullscreenPromise {
pub mut:
	state FullscreenPromiseState
	error string
}

pub enum FullscreenOperationKind {
	enter
	exit
}

struct PendingFullscreenOperation {
	kind             FullscreenOperationKind
	document_id      string
	element_id       string
	element_document string
	ready            bool
	initial_error    string
	resize           bool
	promise          &FullscreenPromise
}

struct ScreenshotTask {
	node_id ?dom.UniqueNodeID
}

struct PendingGeolocationRequest {
	callback GeolocationPositionCallback @[required]
	type_    GeolocationRequestType
}

@[heap]
pub struct Page {
	dom.Page
pub mut:
	event_handler  &EventHandler = &EventHandler{}
	client_events  []ClientEvent
	documents      []SearchDocument
	media_elements map[u64]MediaElementState
	selected_match ?FindMatch
mut:
	client_                                      &PageClient = &PageClient{}
	media_element_callbacks_                     map[u64]dom.MediaElementPageCallbacks
	device_scale                                 f64 = 1
	top_level_traversable_                       string
	focused_navigable_                           string
	history_delta_                               int
	is_scripting_enabled_                        bool = true
	should_block_pop_ups_                        bool = true
	enable_autoscroll_                           bool = true
	enable_primary_paste_                        bool = true
	async_scrolling_enabled_                     bool
	is_webdriver_active_                         bool
	is_hovering_link_                            bool
	is_in_tooltip_area_                          bool
	current_cursor_                              string = 'arrow'
	window_position_                             PixelPoint
	window_size_                                 PixelSize
	window_rect_observer_                        ?fn (PixelRect)
	window_rect_completion_observer_             ?fn (PixelRect, u64)
	pending_dialog_                              PendingDialog
	pending_dialog_text_                         ?string
	pending_dialog_default_                      string
	pending_dialog_response_                     ?string
	on_pending_dialog_closed_                    ?fn ()
	pending_non_blocking_dialog_                 PendingNonBlockingDialog
	pending_non_blocking_target_                 string
	next_clipboard_request_id                    u64
	pending_clipboard_requests                   map[u64]bool
	pending_geolocation_requests                 map[u64]PendingGeolocationRequest
	next_geolocation_request_id                  u64
	active_geolocation_request_id                ?u64
	canvas_elements_                             map[u64]CanvasElementState
	media_context_element_                       ?u64
	context_menu_request_                        ?ContextMenuRequest
	active_screen_wake_lock_count_               uint
	mute_state_                                  MuteState
	user_style_                                  ?string
	preferred_color_scheme_override_for_testing_ ?string
	attached_documents_                          []&dom.Document
	wheel_event_listener_state_generation_       u64
	needs_beforeunload_check_                    bool = true
	local_root_navigable_                        ?&dom.Navigable
	mouse_event_tracking_navigable_              ?&dom.Navigable
	compositor_context_                          ?&compositor.CompositorContextHandle
	last_find_query_                             ?FindInPageQuery
	last_find_url_                               string
	find_match_index_                            uint
	listen_for_dom_mutations_                    bool
	viewport_fullscreen_                         bool
	fullscreen_ipc_sent_                         bool
	processing_fullscreen_                       bool
	pending_fullscreen_operations_               []PendingFullscreenOperation
	fullscreen_elements_                         map[string]string
	screenshot_tasks_                            []ScreenshotTask
	history_executor_                            &HistoryExecutor = &HistoryExecutor{}
}

fn page_did_create_document_callback(target voidptr, document &dom.Document) {
	mut model := unsafe { &Page(target) }
	model.register_attached_document(document)
	model.client_.page_did_create_new_document(document.url_string())
}

fn page_is_scripting_enabled_callback(target voidptr) bool {
	return unsafe { &Page(target) }.is_scripting_enabled()
}

fn page_has_media_element_playing_audio_callback(target voidptr, document &dom.Document) bool {
	model := unsafe { &Page(target) }
	return model.has_media_element_playing_audio(document)
}

fn page_media_element_audio_state_changed_callback(target voidptr, document &dom.Document, media_id dom.UniqueNodeID, playing bool) {
	mut model := unsafe { &Page(target) }
	id := u64(media_id.value())
	mut state := model.media_elements[id] or { MediaElementState{} }
	state.document_id = document.unique_id()
	state.playing_audio = playing
	model.media_elements[id] = state
}

fn page_did_change_audio_play_state_callback(target voidptr, playing bool) {
	mut model := unsafe { &Page(target) }
	model.client_.page_did_change_audio_play_state(if playing { 'playing' } else { 'paused' })
}

fn page_is_audio_muted_callback(target voidptr) bool {
	return unsafe { &Page(target) }.page_mute_state() == .muted
}

fn page_set_audio_muted_callback(target voidptr, muted bool) {
	mut model := unsafe { &Page(target) }
	model.set_page_mute_state(if muted { .muted } else { .unmuted })
}

fn page_register_actual_media_element_callback(target voidptr, document &dom.Document, media_id dom.UniqueNodeID, callbacks dom.MediaElementPageCallbacks) {
	if callbacks.target == unsafe { nil } { return }
	mut model := unsafe { &Page(target) }
	id := u64(media_id.value())
	mut state := model.media_elements[id] or { MediaElementState{} }
	state.document_id = document.unique_id()
	model.register_media_element(id, state)
	model.media_element_callbacks_[id] = callbacks
}

fn page_unregister_actual_media_element_callback(target voidptr, media_id dom.UniqueNodeID) {
	mut model := unsafe { &Page(target) }
	model.unregister_media_element(u64(media_id.value()))
}

fn page_create_screen_wake_lock_handle_callback(target voidptr) voidptr {
	mut model := unsafe { &Page(target) }
	return voidptr(ScreenWakeLockHandle.create(mut model))
}

fn page_did_request_color_picker_callback(target voidptr, input_target string, current_color string) {
	mut model := unsafe { &Page(target) }
	model.did_request_color_picker(input_target, current_color)
}

fn page_did_request_file_picker_callback(target voidptr, input_target string, filter string, multiple bool) {
	mut model := unsafe { &Page(target) }
	model.did_request_file_picker(input_target, filter, multiple)
}

fn page_did_update_resource_count_callback(target voidptr, count int) {
	mut model := unsafe { &Page(target) }
	model.client_.page_did_update_resource_count(i32(count))
}

fn page_did_change_title_callback(target voidptr, title string) {
	mut model := unsafe { &Page(target) }
	model.client_.page_did_change_title(title)
}

fn page_device_pixel_scale_callback(target voidptr) f64 {
	model := unsafe { &Page(target) }
	return model.device_scale
}

fn page_preferred_color_scheme_callback(target voidptr) string {
	model := unsafe { &Page(target) }
	return model.preferred_color_scheme()
}

fn page_user_style_callback(target voidptr) ?string {
	model := unsafe { &Page(target) }
	return model.user_style()
}

fn page_did_allocate_backing_stores_callback(target voidptr, front_id int, back_id int) {
	mut model := unsafe { &Page(target) }
	front_store := SharedBackingStore.create([])
	back_store := SharedBackingStore.create([])
	model.client_.page_did_allocate_backing_stores(i32(front_id), front_store, i32(back_id), back_store)
}

fn page_request_frame_callback(target voidptr) {
	mut model := unsafe { &Page(target) }
	model.client_.request_frame()
}

fn page_has_rendering_opportunity_callback(target voidptr) bool {
	model := unsafe { &Page(target) }
	return model.client_.has_rendering_opportunity()
}

fn page_will_begin_rendering_update_callback(target voidptr) {
	mut model := unsafe { &Page(target) }
	model.client_.will_begin_rendering_update()
}

fn page_did_finish_rendering_update_callback(target voidptr) {
	mut model := unsafe { &Page(target) }
	model.client_.did_finish_rendering_update()
}

fn page_local_root_navigable_callback(target voidptr) ?&dom.Navigable {
	model := unsafe { &Page(target) }
	return model.local_root_navigable_
}

fn page_did_request_external_url_callback(target voidptr, url string, initiator_origin string, has_transient_activation bool) {
	mut model := unsafe { &Page(target) }
	model.client_.page_did_request_external_url(url, initiator_origin, has_transient_activation)
}

fn page_did_update_editing_history_callback(target voidptr, can_undo bool, can_redo bool) {
	mut model := unsafe { &Page(target) }
	model.client_.page_did_update_editing_history_state(can_undo, can_redo)
}

fn page_history_action_callback(target voidptr, redo bool) EventResult {
	model := unsafe { &Page(target) }
	root := model.local_root_navigable_ or { return .dropped }
	document := root.active_document() or { return .dropped }
	result := editing.perform_history_action(document, if redo { .redo } else { .undo })
	return if result == .handled { .handled } else { .dropped }
}

fn page_select_all_callback(target voidptr) EventResult {
	model := unsafe { &Page(target) }
	root := model.local_root_navigable_ or { return .dropped }
	document := root.active_document() or { return .dropped }
	selection := document.get_selection() or { return .dropped }
	if input_target := document.active_input_events_target(none) {
		input_target.select_all()
	} else if body := document.body() {
		mut mutable_selection := unsafe { &dom.Selection(selection) }
		mutable_selection.select_all_children(unsafe { &dom.Node(body) }) or { return .dropped }
	}
	return .handled
}

fn page_clipboard_insert_callback(target voidptr, plain_text string, html ?string) EventResult {
	model := unsafe { &Page(target) }
	root := model.local_root_navigable_ or { return .dropped }
	document := root.active_document() or { return .dropped }
	input_target := document.active_input_events_target(none) or { return .dropped }
	input_target.handle_insert_from_clipboard(dom.input_type_insert_from_paste, plain_text,
		html)
	return .handled
}

fn page_word_jump_modifier() u32 {
	$if macos {
		return dom.modifier_alt
	} $else {
		return dom.modifier_ctrl
	}
}

fn page_editing_key_action_callback(target voidptr, original_key int, code_point u32, original_modifiers u32) bool {
	model := unsafe { &Page(target) }
	root := model.local_root_navigable_ or { return false }
	document := root.active_document() or { return false }
	input_target := document.active_input_events_target(none) or { return false }
	mut key := original_key
	mut modifiers := original_modifiers
	collapse := if modifiers & dom.modifier_shift != 0 { dom.CollapseSelection.no } else { dom.CollapseSelection.yes }
	$if macos {
		if modifiers & dom.modifier_super != 0 {
			if key == 37 {
				key = 35
				modifiers &= ~dom.modifier_super
			} else if key == 39 {
				key = 36
				modifiers &= ~dom.modifier_super
			} else if key == 38 {
				input_target.move_cursor_to_start_of_document(collapse)
				return true
			} else if key == 40 {
				input_target.move_cursor_to_end_of_document(collapse)
				return true
			}
		}
	}
	if input_type := input_type_for_delete_key(key) {
		input_target.handle_delete(input_type)
		return true
	}
	if key == 37 || key == 39 {
		if modifiers & page_word_jump_modifier() != 0 {
			if key == 37 {
				input_target.decrement_cursor_position_to_previous_word(collapse)
			} else {
				input_target.increment_cursor_position_to_next_word(collapse)
			}
		} else if key == 37 {
			input_target.decrement_cursor_position_offset(collapse)
		} else {
			input_target.increment_cursor_position_offset(collapse)
		}
		return true
	}
	if key == 38 || key == 40 {
		if key == 38 {
			input_target.decrement_cursor_position_to_previous_line(collapse)
		} else {
			input_target.increment_cursor_position_to_next_line(collapse)
		}
		return true
	}
	if (key == 33 || key == 34) && modifiers & dom.modifier_shift != 0 {
		if key == 33 {
			input_target.move_cursor_to_previous_page(.no)
		} else {
			input_target.move_cursor_to_next_page(.no)
		}
		return true
	}
	if key == 35 || key == 36 {
		focused_is_textarea := if focused := document.focused_area() {
			if element := focused.as_element() { element.local_name() == 'textarea' } else { false }
		} else {
			false
		}
		plain_home_or_end := modifiers & ~(dom.modifier_shift | dom.modifier_keypad) == 0
		action := if focused_is_textarea && plain_home_or_end {
			if key == 35 {
				dom.InputEventsTargetNavigationAction.line_start
			} else {
				dom.InputEventsTargetNavigationAction.line_end
			}
		} else if key == 35 {
			dom.InputEventsTargetNavigationAction.start
		} else {
			dom.InputEventsTargetNavigationAction.end
		}
		input_target.navigate(action, collapse)
		return true
	}
	if key == 13 {
		significant_modifiers := modifiers & ~dom.modifier_keypad
		if significant_modifiers !in [u32(0), dom.modifier_shift] {
			return false
		}
		mut input_type := if significant_modifiers == dom.modifier_shift {
			dom.input_type_insert_line_break
		} else {
			dom.input_type_insert_paragraph
		}
		if input_target.text_control_selection() != none {
			input_type = dom.input_type_insert_line_break
		} else if selection := document.get_selection() {
			if range := selection.range() {
				if range.start_container().editing_host_is_plaintext_only() {
					input_type = dom.input_type_insert_line_break
				}
			}
		}
		if input_target.handle_return_key(input_type) != .handled {
			input_target.handle_insert(input_type, '\n')
		}
		return true
	}
	if !should_ignore_keydown_event(int(code_point), modifiers) {
		input_target.handle_insert(dom.input_type_insert_text, rune(code_point).str())
		return true
	}
	return false
}

pub fn Page.create(device_scale f64) !&Page {
	if device_scale <= 0 || math.is_nan(device_scale) || math.is_inf(device_scale, 0) {
		return error('device pixel scale must be finite and positive')
	}
	mut model := &Page{
		device_scale: device_scale
	}
	model.client_.history_executor_ = model.history_executor_
	model.event_handler.client_ = model.client_
	model.event_handler.set_history_action_callback(voidptr(model), page_history_action_callback)
	model.event_handler.set_select_all_callback(voidptr(model), page_select_all_callback)
	model.event_handler.set_clipboard_insert_callback(voidptr(model), page_clipboard_insert_callback)
	model.event_handler.set_editing_key_action_callback(voidptr(model), page_editing_key_action_callback)
	model.Page = dom.Page{
		target: voidptr(model)
		did_create_document_callback: page_did_create_document_callback
		did_update_resource_count_callback: page_did_update_resource_count_callback
		did_change_title_callback: page_did_change_title_callback
		device_pixel_scale_callback: page_device_pixel_scale_callback
		did_allocate_backing_stores_callback: page_did_allocate_backing_stores_callback
		did_update_editing_history_callback: page_did_update_editing_history_callback
		preferred_color_scheme_callback: page_preferred_color_scheme_callback
		prefers_reduced_transparency_callback: page_prefers_reduced_transparency_callback
		user_style_callback: page_user_style_callback
		request_frame_callback: page_request_frame_callback
		has_rendering_opportunity_callback: page_has_rendering_opportunity_callback
		will_begin_rendering_update_callback: page_will_begin_rendering_update_callback
		did_finish_rendering_update_callback: page_did_finish_rendering_update_callback
		local_root_navigable_callback: page_local_root_navigable_callback
		find_from_window_callback: page_find_from_window_callback
		has_media_element_playing_audio_callback: page_has_media_element_playing_audio_callback
		media_element_audio_state_changed_callback: page_media_element_audio_state_changed_callback
		did_change_audio_play_state_callback: page_did_change_audio_play_state_callback
		is_audio_muted_callback: page_is_audio_muted_callback
		set_audio_muted_callback: page_set_audio_muted_callback
		register_actual_media_element_callback: page_register_actual_media_element_callback
		unregister_actual_media_element_callback: page_unregister_actual_media_element_callback
		create_screen_wake_lock_handle_callback: page_create_screen_wake_lock_handle_callback
		did_request_color_picker_callback: page_did_request_color_picker_callback
		did_request_file_picker_callback: page_did_request_file_picker_callback
		did_request_external_url_callback: page_did_request_external_url_callback
		is_scripting_enabled_callback: page_is_scripting_enabled_callback
	}
	return model
}

pub fn (p &Page) history_executor() &HistoryExecutor {
	return p.history_executor_
}

pub fn (p &Page) enable_autoscroll() bool {
	return p.enable_autoscroll_
}

pub fn (mut p Page) set_enable_autoscroll(value bool) {
	p.enable_autoscroll_ = value
}

pub fn (p &Page) enable_primary_paste() bool {
	return p.enable_primary_paste_
}

pub fn (mut p Page) set_enable_primary_paste(value bool) {
	p.enable_primary_paste_ = value
	p.event_handler.primary_paste_enabled_ = value
}

pub fn (p &Page) async_scrolling_enabled() bool {
	return p.async_scrolling_enabled_
}

pub fn (mut p Page) set_async_scrolling_enabled(value bool) {
	p.async_scrolling_enabled_ = value
}

pub fn (p &Page) wheel_event_listener_state_generation() u64 {
	return p.wheel_event_listener_state_generation_
}

pub fn (p &Page) has_compositor_host() bool {
	return p.client_.compositor_host() != none
}

pub fn (mut p Page) ensure_compositor_host() {
	p.client_.ensure_compositor_host()
}

pub fn (p &Page) compositor_host() &compositor.CompositorHost {
	return p.client_.compositor_host() or { panic('Page has no compositor host') }
}

pub fn (mut p Page) set_compositor_context(context ?&compositor.CompositorContextHandle) {
	p.compositor_context_ = context
}

pub fn (mut p Page) invalidate_compositor_wheel_event_listener_state() {
	p.wheel_event_listener_state_generation_++
	if !p.async_scrolling_enabled_ || !p.top_level_traversable_is_initialized() {
		return
	}
	if context := p.compositor_context_ {
		mut mutable_context := unsafe { context }
		mutable_context.invalidate_wheel_event_listener_state(p.wheel_event_listener_state_generation_)
	}
}

fn (mut p Page) register_attached_document(document &dom.Document) {
	for attached in p.attached_documents_ {
		if voidptr(attached) == voidptr(document) {
			return
		}
	}
	p.attached_documents_ << document
	p.update_needs_beforeunload_check()
}

pub fn (mut p Page) set_top_level_traversable(id string) ! {
	if p.top_level_traversable_ != '' {
		return error('top-level traversable replacement is not allowed')
	}
	if id == '' {
		return error('top-level traversable must have an identity')
	}
	p.top_level_traversable_ = id
	p.update_needs_beforeunload_check()
}

pub fn (p &Page) needs_beforeunload_check() bool {
	return p.needs_beforeunload_check_
}

pub fn (mut p Page) update_needs_beforeunload_check() {
	mut needs_check := false
	root := p.local_root_navigable_ or {
		needs_check = true
		if p.needs_beforeunload_check_ != needs_check {
			p.needs_beforeunload_check_ = needs_check
			p.client_.page_did_change_needs_beforeunload_check(needs_check)
		}
		return
	}
	active_document := root.active_document() or {
		needs_check = true
		if p.needs_beforeunload_check_ != needs_check {
			p.needs_beforeunload_check_ = needs_check
			p.client_.page_did_change_needs_beforeunload_check(needs_check)
		}
		return
	}
	if active_navigable := active_document.navigable() {
		if voidptr(active_navigable) != voidptr(root) {
			needs_check = true
		}
	} else {
		needs_check = true
	}
	if !needs_check {
		for navigable in active_document.inclusive_descendant_navigables() {
			document := navigable.active_document() or { continue }
			window := document.get_window() or { continue }
			if unsafe { &dom.EventTarget(window) }.has_event_listener('beforeunload') {
				needs_check = true
				break
			}
		}
	}
	if p.needs_beforeunload_check_ == needs_check {
		return
	}
	p.needs_beforeunload_check_ = needs_check
	p.client_.page_did_change_needs_beforeunload_check(needs_check)
}

pub fn (mut p Page) set_local_root_navigable(navigable &dom.Navigable) ! {
	if p.local_root_navigable_ != none {
		return error('local root navigable replacement is not allowed')
	}
	p.local_root_navigable_ = navigable
	p.update_needs_beforeunload_check()
}

pub fn (p &Page) has_local_root_navigable() bool {
	return p.local_root_navigable_ != none
}

pub fn (p &Page) local_root_navigable() &dom.Navigable {
	return p.local_root_navigable_ or { panic('Page has no local root navigable') }
}

pub fn (mut p Page) set_marked_text_from_input_method(text string) {
	mut navigable := p.local_root_navigable_ or { return }
	navigable.set_marked_text_from_input_method(text)
}

pub fn (mut p Page) commit_text_from_input_method(text string, replacement_start i32,
	replacement_length i32) {
	mut navigable := p.local_root_navigable_ or { return }
	navigable.commit_text_from_input_method(text, replacement_start, replacement_length)
}

pub fn (mut p Page) unmark_text_from_input_method() {
	mut navigable := p.local_root_navigable_ or { return }
	navigable.unmark_text_from_input_method()
}

pub fn (mut p Page) set_mouse_event_tracking_navigable(navigable &dom.Navigable) {
	p.mouse_event_tracking_navigable_ = navigable
}

pub fn (mut p Page) queue_screenshot_task(node_id ?dom.UniqueNodeID) {
	p.screenshot_tasks_ << ScreenshotTask{
		node_id: node_id
	}
	if root := p.local_root_navigable_ {
		root.set_needs_repaint()
	}
	p.client_.request_frame()
}

pub fn (mut p Page) process_screenshot_requests() {
	for p.screenshot_tasks_.len > 0 {
		task := p.screenshot_tasks_[0]
		p.screenshot_tasks_.delete(0)
		root := p.local_root_navigable_ or {
			p.client_.page_did_take_screenshot([])
			continue
		}
		if node_id := task.node_id {
			node := dom.Node.from_unique_id(node_id) or {
				p.client_.page_did_take_screenshot([])
				continue
			}
			mut document := unsafe { &dom.Document(node.document()) }
			document.update_layout(.process_screenshot)
			layout_node := node.layout_node() or {
				p.client_.page_did_take_screenshot([])
				continue
			}
			if layout_node.paintables().len == 0 {
				p.client_.page_did_take_screenshot([])
				continue
			}
			bytes := root.render_screenshot(dom.PaintConfig{
				canvas_fill_rect: layout_node.border_box_
			}, node_id)
			p.client_.page_did_take_screenshot(bytes)
			continue
		}
		document := root.active_document() or {
			p.client_.page_did_take_screenshot([])
			continue
		}
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.update_layout(.process_screenshot)
		layout_viewport := document.layout_node() or {
			p.client_.page_did_take_screenshot([])
			continue
		}
		if layout_viewport.root_layout_node() == none {
			p.client_.page_did_take_screenshot([])
			continue
		}
		bytes := root.render_screenshot(dom.PaintConfig{
			paint_overlay: true
			canvas_fill_rect: document.viewport_rect()
		}, none)
		p.client_.page_did_take_screenshot(bytes)
	}
}

pub fn (p &Page) top_level_traversable_is_initialized() bool {
	return p.top_level_traversable_ != ''
}

pub fn (p &Page) top_level_traversable() string {
	assert p.top_level_traversable_is_initialized()
	return p.top_level_traversable_
}

pub fn (p &Page) focused_navigable() string {
	return if p.focused_navigable_ != '' { p.focused_navigable_ } else { p.top_level_traversable_ }
}

pub fn (mut p Page) set_focused_navigable(id string) {
	p.focused_navigable_ = id
}

pub fn (mut p Page) navigable_document_destroyed(id string) {
	if p.focused_navigable_ == id {
		p.focused_navigable_ = ''
	}
}

pub fn (mut p Page) load(url string) {
	parsed := dom.dom_url_parse(url, dom.url_about_blank(), 'UTF-8') or { return }
	p.load_with_history_and_navigation_id(parsed, .auto, none)
}

// Page::load() intentionally ignores the navigation exception result.
pub fn (mut p Page) load_with_history_and_navigation_id(url dom.URL, history_handling dom.NavigationHistoryBehavior, navigation_id ?string) {
	p.local_root_navigable().navigate_from_page(dom.PageNavigationParams{
		url: url
		history_handling: history_handling
		navigation_id: navigation_id
	}) or {}
}

pub fn (mut p Page) load_html(html string) {
	p.load_html_with_navigation_id(html, none)
}

pub fn (mut p Page) load_html_with_navigation_id(html string, navigation_id ?string) {
	p.local_root_navigable().navigate_from_page(dom.PageNavigationParams{
		url: dom.URL{value: 'about:srcdoc'}
		document_resource: html
		navigation_id: navigation_id
	}) or {}
}

pub fn (mut p Page) reload() {
	p.local_root_navigable().reload()
}

fn (p &Page) active_document_url() string {
	root := p.local_root_navigable_ or { return '' }
	return (root.active_document_url() or { return '' }).serialize()
}

pub fn (mut p Page) traverse_the_history_by_delta(delta int) {
	p.history_delta_ += delta
	p.client_events << ClientEvent{
		name: 'history-delta'
		text: delta.str()
	}
}

pub fn (p &Page) device_to_css_point(point PixelPoint) PixelPoint {
	return PixelPoint{
		x: point.x / p.device_scale
		y: point.y / p.device_scale
	}
}

pub fn (p &Page) css_to_device_point(point PixelPoint) PixelPoint {
	return PixelPoint{
		x: point.x * p.device_scale
		y: point.y * p.device_scale
	}
}

pub fn (p &Page) css_to_device_rect(rect PixelRect) PixelRect {
	return PixelRect{
		x:      rect.x * p.device_scale
		y:      rect.y * p.device_scale
		width:  rect.width * p.device_scale
		height: rect.height * p.device_scale
	}
}

pub fn (p &Page) device_to_css_rect(rect PixelRect) PixelRect {
	return PixelRect{
		x:      math.round(rect.x / p.device_scale)
		y:      math.round(rect.y / p.device_scale)
		width:  math.floor(rect.width / p.device_scale)
		height: math.floor(rect.height / p.device_scale)
	}
}

pub fn (p &Page) enclosing_device_rect(rect PixelRect) PixelRect {
	return PixelRect{
		x:      math.floor(rect.x * p.device_scale)
		y:      math.floor(rect.y * p.device_scale)
		width:  math.ceil(rect.width * p.device_scale)
		height: math.ceil(rect.height * p.device_scale)
	}
}

pub fn (p &Page) rounded_device_rect(rect PixelRect) PixelRect {
	return PixelRect{
		x:      math.round(rect.x * p.device_scale)
		y:      math.round(rect.y * p.device_scale)
		width:  math.round(rect.width * p.device_scale)
		height: math.round(rect.height * p.device_scale)
	}
}

pub fn (mut p Page) set_window_rect(position PixelPoint, size PixelSize) {
	p.window_position_ = position
	p.window_size_ = size
	p.client_events << ClientEvent{
		name: 'window-rect'
		text: '${position.x},${position.y},${size.width},${size.height}'
	}
}

pub fn (mut p Page) request_dialog(kind PendingDialog, message string, default_value string) bool {
	if kind == .none || p.pending_dialog_ != .none {
		return false
	}
	p.pending_dialog_ = kind
	p.pending_dialog_default_ = default_value
	if message != '' {
		p.pending_dialog_text_ = message
	}
	p.client_events << ClientEvent{
		name: 'dialog:${kind}'
		text: message
	}
	return true
}

pub fn (mut p Page) close_dialog(accepted bool, response ?string) bool {
	if p.pending_dialog_ == .none {
		return false
	}
	match p.pending_dialog_ {
		.alert {
			p.pending_dialog_response_ = ''
		}
		.confirm {
			p.pending_dialog_response_ = if accepted { 'true' } else { 'false' }
		}
		.prompt {
			p.pending_dialog_response_ = if accepted {
				response or { p.pending_dialog_default_ }
			} else {
				none
			}
		}
		else {}
	}
	p.client_events << ClientEvent{
		name: 'dialog-closed'
	}
	p.on_pending_dialog_closed()
	return true
}

pub fn (p &Page) pending_dialog() PendingDialog {
	return p.pending_dialog_
}

pub fn (p &Page) pending_dialog_response() ?string {
	return p.pending_dialog_response_
}

pub fn (mut p Page) request_non_blocking_dialog(kind PendingNonBlockingDialog, target string) bool {
	if kind == .none || p.pending_non_blocking_dialog_ != .none {
		return false
	}
	p.pending_non_blocking_dialog_ = kind
	p.pending_non_blocking_target_ = target
	p.client_events << ClientEvent{
		name: 'picker:${kind}'
		text: target
	}
	return true
}

pub fn (mut p Page) close_non_blocking_dialog(kind PendingNonBlockingDialog) ?string {
	if p.pending_non_blocking_dialog_ != kind {
		return none
	}
	target := p.pending_non_blocking_target_
	p.pending_non_blocking_dialog_ = .none
	p.pending_non_blocking_target_ = ''
	return target
}

pub fn (mut p Page) request_clipboard_entries() u64 {
	id := p.next_clipboard_request_id
	p.next_clipboard_request_id++
	p.pending_clipboard_requests[id] = true
	p.client_events << ClientEvent{
		name: 'clipboard-request'
		text: id.str()
	}
	return id
}

pub fn (mut p Page) retrieved_clipboard_entries(id u64) bool {
	if id !in p.pending_clipboard_requests {
		return false
	}
	p.pending_clipboard_requests.delete(id)
	return true
}

pub fn (mut p Page) register_media_element(id u64, state MediaElementState) {
	p.media_elements[id] = state
}

pub fn (mut p Page) unregister_media_element(id u64) {
	p.media_elements.delete(id)
	p.media_element_callbacks_.delete(id)
	if current := p.media_context_element_ {
		if current == id {
			p.media_context_element_ = none
		}
	}
}

pub fn (mut p Page) request_media_context_menu(id u64) bool {
	if id !in p.media_elements {
		return false
	}
	p.media_context_element_ = id
	return true
}

pub fn (mut p Page) acquire_screen_wake_lock() {
	was_inactive := p.active_screen_wake_lock_count_ == 0
	p.active_screen_wake_lock_count_++
	if was_inactive {
		p.client_.page_did_change_screen_wake_lock_state(.acquired)
	}
}

pub fn (mut p Page) release_screen_wake_lock() {
	assert p.active_screen_wake_lock_count_ > 0
	p.active_screen_wake_lock_count_--
	if p.active_screen_wake_lock_count_ == 0 {
		p.client_.page_did_change_screen_wake_lock_state(.released)
	}
}

pub fn (p &Page) is_screen_wake_lock_active() bool {
	return p.active_screen_wake_lock_count_ > 0
}

pub fn (mut p Page) record_context_menu_request(request ContextMenuRequest) {
	p.context_menu_request_ = request
}

pub fn (mut p Page) clear_context_menu_request() {
	p.context_menu_request_ = none
}

pub fn (mut p Page) take_context_menu_request() ?ContextMenuRequest {
	request := p.context_menu_request_ or { return none }
	p.context_menu_request_ = none
	return request
}

pub fn (mut p Page) toggle_media_property(property string) bool {
	id := p.media_context_element_ or { return false }
	mut state := p.media_elements[id] or { return false }
	match property {
		'play' { state.playing = !state.playing }
		'mute' { state.muted = !state.muted }
		'loop' { state.looping = !state.looping }
		'controls' { state.controls = !state.controls }
		'fullscreen' { state.fullscreen = !state.fullscreen }
		else { return false }
	}
	p.media_elements[id] = state
	return true
}

pub fn (mut p Page) toggle_page_mute_state() {
	p.set_page_mute_state(if p.mute_state_ == .muted { .unmuted } else { .muted })
}

pub fn (mut p Page) set_page_mute_state(mute_state MuteState) {
	if p.mute_state_ == mute_state {
		return
	}
	p.mute_state_ = mute_state
	mut adapter_document_ids := map[i64]bool{}
	for id in p.media_elements.keys() {
		mut state := p.media_elements[id] or { continue }
		state.page_mute_change_count++
		p.media_elements[id] = state
		if callbacks := p.media_element_callbacks_[id] {
			if callbacks.mute_state_changed != unsafe { nil } {
				callbacks.mute_state_changed(callbacks.target)
			}
		} else if state.playing_audio && !state.muted {
			adapter_document_ids[state.document_id.value()] = true
		}
	}
	// State-only media adapters have no concrete owner to deliver the transition.
	// Reschedule their documents without broadcasting to unrelated documents.
	for document in p.attached_documents_ {
		if document.unique_id().value() in adapter_document_ids {
			mut mutable_document := unsafe { &dom.Document(document) }
			mutable_document.audio_play_state_changed()
		}
	}
}

pub fn (p &Page) page_mute_state() MuteState {
	return p.mute_state_
}

pub fn (mut p Page) set_user_style(source string) {
	p.user_style_ = if source == '' { none } else { source }
	p.invalidate_user_style()
}

pub fn (mut p Page) set_content_blocking_enabled(enabled bool) {
	mut blocker := loader.ContentBlocker.the()
	if blocker.filtering_enabled() == enabled {
		return
	}
	has_cosmetic_rules := blocker.has_cosmetic_rules()
	blocker.set_filtering_enabled(enabled)
	if has_cosmetic_rules {
		p.invalidate_user_style()
	}
}

pub fn (mut p Page) invalidate_user_style() {
	for document in p.attached_documents_ {
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.style_scope().invalidate_user_style_sheet()
		mutable_document.bump_style_environment_version()
		mutable_document.set_needs_full_style_update(true)
	}
	p.client_events << ClientEvent{
		name: 'invalidate-style'
	}
}

pub fn (mut p Page) invalidate_style_for_preference_change() {
	for document in p.attached_documents_ {
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.bump_style_environment_version()
		mutable_document.set_needs_media_query_evaluation()
		mutable_document.set_needs_full_style_update(true)
	}
	p.client_events << ClientEvent{
		name: 'invalidate-preference-style'
	}
}

pub fn (p &Page) user_style() ?string {
	return p.user_style_
}

pub fn (mut p Page) clear_selection() {
	p.selected_match = none
	for document in p.rendered_search_documents() {
		if selection := document.get_selection() {
			mut mutable_selection := unsafe { &dom.Selection(selection) }
			mutable_selection.remove_all_ranges()
		}
	}
}

fn occurrences(document SearchDocument, query FindInPageQuery) []FindMatch {
	if query.string_ == '' {
		return []
	}
	haystack := if query.case_sensitivity == .case_insensitive {
		document.text.to_lower()
	} else {
		document.text
	}
	needle := if query.case_sensitivity == .case_insensitive {
		query.string_.to_lower()
	} else {
		query.string_
	}
	mut result := []FindMatch{}
	mut offset := 0
	for offset <= haystack.len - needle.len {
		relative := haystack[offset..].index(needle) or { break }
		start := offset + relative
		result << FindMatch{
			document_id: document.id
			start:       start
			end:         start + needle.len
		}
		offset = start + needle.len
	}
	return result
}

fn (p &Page) all_matches(query FindInPageQuery) []FindMatch {
	mut matches := []FindMatch{}
	for document in p.documents {
		matches << occurrences(document, query)
	}
	return matches
}

fn url_without_fragment(url string) string {
	index := url.index_u8(`#`)
	return if index < 0 { url } else { url[..index] }
}

fn (mut p Page) perform_find(query FindInPageQuery, delta int) FindInPageResult {
	if root := p.local_root_navigable_ {
		if document := root.active_document() {
			if document.get_window() != none { return p.perform_rendered_find(query, delta) }
		}
	}
	matches := p.all_matches(query)
	if matches.len == 0 {
		p.selected_match = none
		return FindInPageResult{
			total_match_count: uint(0)
		}
	}
	mut direction := delta
	// Page.cpp resets find navigation when the active document URL changes,
	// comparing URLs without their fragments. The first next/previous request
	// in the new document therefore selects its first match.
	if p.last_find_url_ != ''
		&& url_without_fragment(p.last_find_url_) != url_without_fragment(p.active_document_url()) {
		p.find_match_index_ = 0
		p.last_find_url_ = p.active_document_url()
		direction = 0
	}
	if direction > 0 {
		if p.find_match_index_ + 1 >= matches.len {
			if query.wrap_around == .no { return FindInPageResult{} }
			p.find_match_index_ = 0
		} else {
			p.find_match_index_++
		}
	} else if direction < 0 {
		if p.find_match_index_ == 0 {
			if query.wrap_around == .no { return FindInPageResult{} }
			p.find_match_index_ = uint(matches.len - 1)
		} else {
			p.find_match_index_--
		}
	}
	if p.find_match_index_ >= matches.len {
		p.find_match_index_ = 0
	}
	p.selected_match = matches[p.find_match_index_]
	return FindInPageResult{
		current_match_index: p.find_match_index_
		total_match_count:   uint(matches.len)
	}
}

pub fn (mut p Page) find_in_page(query FindInPageQuery) FindInPageResult {
	if !p.has_local_root_navigable() { return FindInPageResult{} }
	if query.string_ == '' {
		p.last_find_query_ = none
		p.clear_selection()
		return FindInPageResult{}
	}
	p.find_match_index_ = 0
	result := p.perform_find(query, 0)
	p.last_find_query_ = query
	p.last_find_url_ = p.active_document_url()
	return result
}

pub fn (mut p Page) find_in_page_next_match() FindInPageResult {
	query := p.last_find_query_ or { return FindInPageResult{} }
	if !p.has_local_root_navigable() { return FindInPageResult{} }
	return p.perform_find(query, 1)
}

pub fn (mut p Page) find_in_page_previous_match() FindInPageResult {
	query := p.last_find_query_ or { return FindInPageResult{} }
	if !p.has_local_root_navigable() { return FindInPageResult{} }
	return p.perform_find(query, -1)
}

pub fn (mut p Page) enqueue_fullscreen_enter(document_id string, element_id string, element_document string, ready bool, initial_error string) &FullscreenPromise {
	promise := &FullscreenPromise{}
	p.pending_fullscreen_operations_ << PendingFullscreenOperation{
		kind:             .enter
		document_id:      document_id
		element_id:       element_id
		element_document: element_document
		ready:            ready
		initial_error:    initial_error
		promise:          promise
	}
	p.process_pending_fullscreen_operations()
	return promise
}

pub fn (mut p Page) enqueue_fullscreen_exit(document_id string, resize bool) &FullscreenPromise {
	promise := &FullscreenPromise{}
	p.pending_fullscreen_operations_ << PendingFullscreenOperation{
		kind:        .exit
		document_id: document_id
		resize:      resize
		promise:     promise
	}
	p.process_pending_fullscreen_operations()
	return promise
}

pub fn (mut p Page) process_pending_fullscreen_operations() {
	if p.processing_fullscreen_ {
		return
	}
	p.processing_fullscreen_ = true
	for p.pending_fullscreen_operations_.len > 0 {
		op := p.pending_fullscreen_operations_[0]
		mut promise := op.promise
		if op.kind == .enter && op.initial_error == '' && !p.viewport_fullscreen_ {
			if !p.fullscreen_ipc_sent_ {
				p.client_events << ClientEvent{
					name: 'request-fullscreen-window'
				}
				p.fullscreen_ipc_sent_ = true
			}
			break
		}
		if op.kind == .exit && op.resize && p.viewport_fullscreen_ {
			if !p.fullscreen_ipc_sent_ {
				p.client_events << ClientEvent{
					name: 'request-exit-fullscreen'
				}
				p.fullscreen_ipc_sent_ = true
			}
			break
		}
		if op.kind == .enter {
			mut reason := op.initial_error
			if reason == '' && op.document_id != op.element_document {
				reason = 'ElementNodeDocIsNotPendingDoc'
			} else if reason == '' && !op.ready {
				reason = 'ElementReadyCheckFailed'
			}
			if reason != '' {
				promise.state = .rejected
				promise.error = reason
			} else {
				p.fullscreen_elements_[op.document_id] = op.element_id
				promise.state = .fulfilled
				p.client_events << ClientEvent{
					name: 'fullscreenchange'
					text: op.element_id
				}
			}
		} else {
			if op.document_id in p.fullscreen_elements_ {
				p.client_events << ClientEvent{
					name: 'fullscreenchange'
					text: p.fullscreen_elements_[op.document_id]
				}
				p.fullscreen_elements_.delete(op.document_id)
			}
			promise.state = .fulfilled
		}
		p.pending_fullscreen_operations_.delete(0)
	}
	p.processing_fullscreen_ = false
}

pub fn (mut p Page) set_viewport_is_fullscreen(value bool) {
	if p.viewport_fullscreen_ == value {
		return
	}
	p.viewport_fullscreen_ = value
	p.fullscreen_ipc_sent_ = false
	p.process_pending_fullscreen_operations()
}

pub fn (p &Page) viewport_is_fullscreen() bool {
	return p.viewport_fullscreen_
}
