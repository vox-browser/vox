// Copyright (c) 2020-2026, Ladybird contributors.
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Page/Page.{h,cpp}. PageClient IPC calls are recorded as
// ClientEvent values so the browser/embedder boundary is deterministic.
module page

import dom
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

pub enum CaseSensitivity {
	case_sensitive
	case_insensitive
}

pub enum WrapAround {
	yes
	no
}

pub struct FindInPageQuery {
pub:
	string_          string
	case_sensitivity CaseSensitivity = .case_insensitive
	wrap_around      WrapAround      = .yes
}

pub struct FindInPageResult {
pub:
	current_match_index usize
	total_match_count   ?usize
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
}

pub struct ClientEvent {
pub:
	name string
	text string
}

pub struct MediaElementState {
pub mut:
	playing    bool
	muted      bool
	looping    bool
	controls   bool
	fullscreen bool
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
	client_                        &PageClient = &PageClient{}
	device_scale                   f64 = 1
	top_level_traversable_         string
	focused_navigable_             string
	current_url_                   string
	history_delta_                 int
	is_scripting_enabled_          bool = true
	should_block_pop_ups_          bool = true
	is_webdriver_active_           bool
	is_hovering_link_              bool
	is_in_tooltip_area_            bool
	current_cursor_                string = 'arrow'
	window_position_               PixelPoint
	window_size_                   PixelSize
	window_rect_observer_          ?fn (PixelRect)
	pending_dialog_                PendingDialog
	pending_dialog_text_           ?string
	pending_dialog_default_        string
	pending_dialog_response_       ?string
	on_pending_dialog_closed_      ?fn ()
	pending_non_blocking_dialog_   PendingNonBlockingDialog
	pending_non_blocking_target_   string
	next_clipboard_request_id      u64
	pending_clipboard_requests     map[u64]bool
	canvas_elements_               []u64
	media_context_element_         ?u64
	mute_state_                    MuteState
	user_style_                    ?string
	last_find_query_               ?FindInPageQuery
	last_find_url_                 string
	find_match_index_              usize
	listen_for_dom_mutations_      bool
	viewport_fullscreen_           bool
	fullscreen_ipc_sent_           bool
	processing_fullscreen_         bool
	pending_fullscreen_operations_ []PendingFullscreenOperation
	fullscreen_elements_           map[string]string
}

fn page_did_create_document_callback(target voidptr, document &dom.Document) {
	mut model := unsafe { &Page(target) }
	model.client_.page_did_create_new_document(document.url_string())
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

fn page_did_allocate_backing_stores_callback(target voidptr, front_id int, back_id int) {
	mut model := unsafe { &Page(target) }
	front_store := SharedBackingStore.create([])
	back_store := SharedBackingStore.create([])
	model.client_.page_did_allocate_backing_stores(i32(front_id), front_store, i32(back_id), back_store)
}

pub fn Page.create(device_scale f64) !&Page {
	if device_scale <= 0 || math.is_nan(device_scale) || math.is_inf(device_scale, 0) {
		return error('device pixel scale must be finite and positive')
	}
	mut model := &Page{
		device_scale: device_scale
	}
	model.Page = dom.Page{
		target: voidptr(model)
		did_create_document_callback: page_did_create_document_callback
		did_update_resource_count_callback: page_did_update_resource_count_callback
		did_change_title_callback: page_did_change_title_callback
		device_pixel_scale_callback: page_device_pixel_scale_callback
		did_allocate_backing_stores_callback: page_did_allocate_backing_stores_callback
		preferred_color_scheme_callback: page_preferred_color_scheme_callback
	}
	return model
}

pub fn (mut p Page) set_top_level_traversable(id string) ! {
	if p.top_level_traversable_ != '' {
		return error('top-level traversable replacement is not allowed')
	}
	if id == '' {
		return error('top-level traversable must have an identity')
	}
	p.top_level_traversable_ = id
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
	p.current_url_ = url
	p.client_events << ClientEvent{
		name: 'navigate'
		text: url
	}
}

pub fn (mut p Page) load_html(html string) {
	p.current_url_ = 'about:srcdoc'
	p.client_events << ClientEvent{
		name: 'navigate-html'
		text: html
	}
}

pub fn (mut p Page) reload() {
	p.client_events << ClientEvent{
		name: 'reload'
		text: p.current_url_
	}
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
	p.mute_state_ = if p.mute_state_ == .muted { .unmuted } else { .muted }
}

pub fn (p &Page) page_mute_state() MuteState {
	return p.mute_state_
}

pub fn (mut p Page) set_user_style(source string) {
	p.user_style_ = source
	p.client_events << ClientEvent{
		name: 'invalidate-style'
	}
}

pub fn (p &Page) user_style() ?string {
	return p.user_style_
}

pub fn (mut p Page) clear_selection() {
	p.selected_match = none
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
	matches := p.all_matches(query)
	if matches.len == 0 {
		p.selected_match = none
		return FindInPageResult{
			total_match_count: usize(0)
		}
	}
	mut direction := delta
	// Page.cpp resets find navigation when the active document URL changes,
	// comparing URLs without their fragments. The first next/previous request
	// in the new document therefore selects its first match.
	if p.last_find_url_ != ''
		&& url_without_fragment(p.last_find_url_) != url_without_fragment(p.current_url_) {
		p.find_match_index_ = 0
		p.last_find_url_ = p.current_url_
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
			p.find_match_index_ = usize(matches.len - 1)
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
		total_match_count:   usize(matches.len)
	}
}

pub fn (mut p Page) find_in_page(query FindInPageQuery) FindInPageResult {
	if !p.top_level_traversable_is_initialized() || query.string_ == '' {
		p.last_find_query_ = none
		p.clear_selection()
		return FindInPageResult{}
	}
	p.find_match_index_ = 0
	result := p.perform_find(query, 0)
	p.last_find_query_ = query
	p.last_find_url_ = p.current_url_
	return result
}

pub fn (mut p Page) find_in_page_next_match() FindInPageResult {
	query := p.last_find_query_ or { return FindInPageResult{} }
	return p.perform_find(query, 1)
}

pub fn (mut p Page) find_in_page_previous_match() FindInPageResult {
	query := p.last_find_query_ or { return FindInPageResult{} }
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
