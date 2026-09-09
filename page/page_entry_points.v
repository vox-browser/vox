// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Remaining Page entry points, routing to the deterministic state models in
// page.v and event_handler.v.
module page

import painting

pub enum PageDragEventType {
	start
	move
	end
}

pub fn (p &Page) client() &PageClient { return p.client_ }

pub fn (p &Page) palette() string { return if p.client_.palette_is_dark() { 'dark' } else { 'default' } }

pub fn (p &Page) web_exposed_screen_area() PixelRect {
	return p.client_.screen_rect()
}

pub fn (p &Page) web_exposed_available_screen_area() PixelRect {
	return p.web_exposed_screen_area()
}

pub fn (p &Page) preferred_color_scheme() string {
	preferred_scheme := p.client_.preferred_color_scheme()
	if preferred_scheme == 'auto' {
		return if p.client_.palette_is_dark() { 'dark' } else { 'light' }
	}
	return preferred_scheme
}
pub fn (p &Page) preferred_contrast() string { return p.client_.preferred_contrast() }
pub fn (p &Page) preferred_motion() string { return p.client_.preferred_motion() }

pub fn (p &Page) device_to_css_size(size PixelSize) PixelSize {
	return PixelSize{width: size.width / p.device_scale, height: size.height / p.device_scale}
}

pub fn (p &Page) chrome_metrics() painting.ChromeMetrics {
	return painting.new_chrome_metrics(p.client_.zoom_level()) or { panic(err) }
}

pub fn (mut p Page) handle_mouseup(target ?InputTarget, _ PixelPoint, _ u32, _ u32,
	_ u32) EventResult {
	return p.event_handler.handle_mouseup(target)
}

pub fn (mut p Page) handle_mousedown(target ?InputTarget, _ PixelPoint, _ u32, _ u32,
	_ u32, click_count int) EventResult {
	return p.event_handler.handle_mousedown(target, click_count)
}

pub fn (mut p Page) handle_mousemove(target ?InputTarget, screen PixelPoint, _ u32,
	_ u32) EventResult {
	return p.event_handler.handle_mousemove(target, screen)
}

pub fn (mut p Page) handle_mouseleave() EventResult {
	return p.event_handler.handle_mouseleave()
}

pub fn (mut p Page) handle_mousewheel(target ?InputTarget, _ PixelPoint, _ u32, _ u32,
	_ u32, _ f64, _ f64) EventResult {
	return p.event_handler.handle_mousewheel(target)
}

pub fn (mut p Page) handle_drag_and_drop_event(type_ PageDragEventType, target ?DragTarget,
	files []SelectedFile, cancelled bool, requested_effect DragEffect) EventResult {
	return match type_ {
		.start { p.event_handler.drag_and_drop.handle_drag_start(files, cancelled, requested_effect) }
		.move { p.event_handler.drag_and_drop.handle_drag_move(target, cancelled, false, false,
			requested_effect) }
		.end { p.event_handler.drag_and_drop.handle_drag_end(cancelled, false, requested_effect) }
	}
}

pub fn (mut p Page) handle_pinch_event(position PixelPoint, scale f64) EventResult {
	PinchEvent.decode(position, scale) or { return .dropped }
	return .handled
}

pub fn (mut p Page) handle_keydown(key int, modifiers u32, code_point u32,
	repeat bool) EventResult {
	return p.event_handler.handle_keydown(key, code_point, modifiers, repeat, false)
}

pub fn (mut p Page) handle_keyup(_ int, _ u32, _ u32, _ bool) EventResult {
	return p.event_handler.handle_keyup(false)
}

pub fn (mut p Page) handle_sdl_input_events() {
	p.client_events << ClientEvent{name: 'poll-sdl-input-events'}
}

pub fn (p &Page) top_level_browsing_context() string {
	return p.top_level_traversable_
}

pub fn (mut p Page) did_update_window_rect() {
	if observer := p.window_rect_observer_ {
		observer(PixelRect{
			x: p.window_position_.x
			y: p.window_position_.y
			width: p.window_size_.width
			height: p.window_size_.height
		})
	}
}

pub fn (mut p Page) did_request_alert(message string) bool {
	if !p.request_dialog(.alert, message, '') {
		return false
	}
	p.client_.page_did_request_alert(message)
	return true
}

pub fn (mut p Page) did_request_confirm(message string) bool {
	if !p.request_dialog(.confirm, message, '') {
		return false
	}
	p.client_.page_did_request_confirm(message)
	return true
}

pub fn (mut p Page) did_request_prompt(message string, default_value string) bool {
	if !p.request_dialog(.prompt, message, default_value) {
		return false
	}
	p.client_.page_did_request_prompt(message, default_value)
	return true
}

pub fn (mut p Page) alert_closed() {
	if p.pending_dialog_ == .alert { p.close_dialog(true, none) }
}
pub fn (mut p Page) confirm_closed(accepted bool) {
	if p.pending_dialog_ == .confirm { p.close_dialog(accepted, none) }
}
pub fn (mut p Page) prompt_closed(response ?string) {
	if p.pending_dialog_ == .prompt { p.close_dialog(response != none, response) }
}

pub fn (mut p Page) dismiss_dialog(on_closed fn ()) {
	p.on_pending_dialog_closed_ = on_closed
	match p.pending_dialog_ {
		.alert { p.client_.page_did_request_accept_dialog() }
		.confirm, .prompt { p.client_.page_did_request_dismiss_dialog() }
		.none {}
	}
}

pub fn (mut p Page) accept_dialog(on_closed fn ()) {
	p.on_pending_dialog_closed_ = on_closed
	if p.pending_dialog_ != .none {
		p.client_.page_did_request_accept_dialog()
	}
}

pub fn (mut p Page) on_pending_dialog_closed() {
	p.pending_dialog_ = .none
	p.pending_dialog_text_ = none
	p.client_events << ClientEvent{name: 'pending-dialog-closed'}
	if on_closed := p.on_pending_dialog_closed_ {
		p.on_pending_dialog_closed_ = none
		on_closed()
	}
}

pub fn (mut p Page) did_request_color_picker(target string, current_color string) {
	if p.request_non_blocking_dialog(.color_picker, target) {
		p.client_.page_did_request_color_picker(current_color)
	}
}

pub fn (mut p Page) color_picker_update(value ?string, final bool) {
	if p.pending_non_blocking_dialog_ != .color_picker {
		return
	}
	if final { p.close_non_blocking_dialog(.color_picker) }
	if actual := value { p.client_events << ClientEvent{name: 'color-picker-update', text: actual} }
}

pub fn (mut p Page) did_request_file_picker(target string, filter string, multiple bool) {
	if p.request_non_blocking_dialog(.file_picker, target) {
		p.client_.page_did_request_file_picker(filter, multiple)
	}
}

pub fn (mut p Page) file_picker_closed(files []SelectedFile) {
	if p.close_non_blocking_dialog(.file_picker) == none {
		return
	}
	p.client_events << ClientEvent{name: 'file-picker-closed', text: files.len.str()}
}

pub fn (mut p Page) did_request_select_dropdown(target string, position PixelPoint,
	minimum_width f64, items []string) {
	if p.request_non_blocking_dialog(.select, target) {
		p.client_.page_did_request_select_dropdown(position, minimum_width, items)
	}
}

pub fn (mut p Page) select_dropdown_closed(selected ?u32) {
	if p.close_non_blocking_dialog(.select) == none {
		return
	}
	p.client_events << ClientEvent{
		name: 'select-dropdown-closed'
		text: if value := selected { value.str() } else { '' }
	}
}

pub fn (p &Page) for_each_media_element(callback fn (u64, MediaElementState)) {
	for id, state in p.media_elements { callback(id, state) }
}

pub fn (mut p Page) update_all_media_element_video_sinks() {
	p.client_events << ClientEvent{name: 'update-media-video-sinks', text: p.media_elements.len.str()}
}

pub fn (mut p Page) register_canvas_element(id u64) {
	if id !in p.canvas_elements_ { p.canvas_elements_ << id }
}

pub fn (mut p Page) unregister_canvas_element(id u64) {
	p.canvas_elements_ = p.canvas_elements_.filter(it != id)
}

pub fn (p &Page) for_each_canvas_element(callback fn (u64)) {
	for id in p.canvas_elements_ { callback(id) }
}

pub fn (mut p Page) present_all_canvas_element_surfaces() {
	p.client_events << ClientEvent{name: 'present-canvas-surfaces', text: p.canvas_elements_.len.str()}
}

pub fn (mut p Page) did_request_media_context_menu(id u64, position PixelPoint, target string,
	modifiers u32, details string) {
	p.media_context_element_ = id
	p.client_.page_did_request_media_context_menu(position, target, modifiers, details)
}

pub fn (mut p Page) toggle_media_play_state() { p.toggle_media_property('play') }
pub fn (mut p Page) toggle_media_mute_state() { p.toggle_media_property('mute') }
pub fn (mut p Page) toggle_media_loop_state() { p.toggle_media_property('loop') }
pub fn (mut p Page) toggle_media_fullscreen_state() { p.toggle_media_property('fullscreen') }
pub fn (mut p Page) toggle_media_controls_state() { p.toggle_media_property('controls') }

pub fn (p &Page) media_context_menu_element() ?u64 { return p.media_context_element_ }

pub fn (p &Page) documents_in_active_window() []SearchDocument {
	return p.documents.clone()
}

pub fn (mut p Page) perform_find_in_page_query(query FindInPageQuery,
	direction int) FindInPageResult {
	return p.perform_find(query, direction)
}

pub fn (mut p Page) update_find_in_page_selection(matches []FindMatch) {
	p.selected_match = if matches.len > 0 { matches[0] } else { none }
}

pub fn (p &Page) is_scripting_enabled() bool { return p.is_scripting_enabled_ }
pub fn (mut p Page) set_is_scripting_enabled(value bool) { p.is_scripting_enabled_ = value }
pub fn (p &Page) should_block_pop_ups() bool { return p.should_block_pop_ups_ }
pub fn (mut p Page) set_should_block_pop_ups(value bool) { p.should_block_pop_ups_ = value }
pub fn (p &Page) is_webdriver_active() bool { return p.is_webdriver_active_ }
pub fn (mut p Page) set_is_webdriver_active(value bool) { p.is_webdriver_active_ = value }
pub fn (p &Page) is_hovering_link() bool { return p.is_hovering_link_ }
pub fn (mut p Page) set_is_hovering_link(value bool) { p.is_hovering_link_ = value }
pub fn (p &Page) is_in_tooltip_area() bool { return p.is_in_tooltip_area_ }
pub fn (mut p Page) set_is_in_tooltip_area(value bool) { p.is_in_tooltip_area_ = value }
pub fn (p &Page) current_cursor() string { return p.current_cursor_ }
pub fn (mut p Page) set_current_cursor(value string) { p.current_cursor_ = value }
pub fn (p &Page) window_position() PixelPoint { return p.window_position_ }
pub fn (mut p Page) set_window_position(value PixelPoint) { p.window_position_ = value }
pub fn (p &Page) window_size() PixelSize { return p.window_size_ }
pub fn (mut p Page) set_window_size(value PixelSize) { p.window_size_ = value }
pub fn (mut p Page) set_window_rect_observer(observer ?fn (PixelRect)) {
	p.window_rect_observer_ = observer
}
pub fn (p &Page) has_pending_dialog() bool { return p.pending_dialog_ != .none }
pub fn (p &Page) pending_dialog_text() ?string { return p.pending_dialog_text_ }
pub fn (_ &Page) pdf_viewer_supported() bool { return false }
pub fn (p &Page) last_find_in_page_query() ?FindInPageQuery { return p.last_find_query_ }
pub fn (p &Page) listen_for_dom_mutations() bool { return p.listen_for_dom_mutations_ }
pub fn (mut p Page) set_listen_for_dom_mutations(value bool) { p.listen_for_dom_mutations_ = value }
