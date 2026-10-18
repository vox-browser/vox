// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// PageClient's browser/embedder boundary. Upstream supplies no-op defaults for
// these virtuals; the V model additionally records calls for deterministic
// tests without inventing IPC transport.
module page

import compositor
import fetch
import streams

pub struct NewWebViewResult {
pub:
	page_id       string
	window_handle string
}

pub struct WorkerAgentResponse {
pub:
	worker_handle        string
	request_server_handle string
	image_decoder_handle string
}

@[heap]
pub struct PageClient {
pub mut:
	events                              []ClientEvent
	// Embedders that never read `events` turn recording off; otherwise every
	// frame request would grow the log for the life of the page.
	record_events_                      bool = true
	screenshots                         [][]u8
	id_                                 u64 = 1
	connection_open_                    bool = true
	has_focus_                          bool = true
	active_devtools_client_             bool
	preferred_color_scheme_             string = 'auto'
	preferred_contrast_                 string = 'auto'
	preferred_motion_                   string = 'auto'
	palette_is_dark_                    bool
	zoom_level_                         f64 = 1
	screen_rect_                        PixelRect
	request_frame_hook_                 ?fn ()
	compositor_supported_               bool
	compositor_host_                    ?&compositor.CompositorHost
	maximum_frames_per_second_        f64 = 60
	next_cross_process_id_             u64 = 1
	pending_root_navigable_id_         ?u64
	manual_rendering_opportunities_    bool
	rendering_update_requested_        bool
	rendering_opportunity_granted_     bool = true
	rendering_opportunity_for_update_  bool
	last_rendering_frame_time_ns_      i64
	last_rendering_frame_interval_ms_  f64
	downloads_                         map[u64]DownloadState
	download_controllers_              map[u64]&fetch.FetchController
	download_readers_                  map[u64]&streams.ReadableStreamDefaultReader
	canceled_downloads_                map[u64]bool
	next_download_id_                  u64 = 1
	external_url_requests_             []ExternalURLRequest
	request_server_connection_lost_    bool
	worker_request_server_loss_count_  u64
	hsts_policies_                     map[string]HSTSPolicy
	storage_usage_                     map[string]u64
	storage_changes_                   []StorageChange
	indexed_database_updates_          []IndexedDatabaseUpdate
	session_history_entries_           map[string]SessionHistoryEntryState
	system_visibility_state_           string = 'hidden'
	ui_process_session_history_        string = '{}'
	captured_session_history_snapshot_ ?string
	session_store_tab_registered_      bool
	session_store_tab_state_           string = '{}'
	history_operation_requests_        []HistoryOperationRequest
	child_navigable_unload_requests_   []u64
	child_frames_                      map[u64]ChildFrameState
	navigation_population_failures_    []NavigationPopulationFailure
	editing_history_can_undo_          bool
	editing_history_can_redo_          bool
	background_color_                  string
	clipboard_items_                   []ClipboardItem
	primary_paste_request_count_       u64
	paste_action_completion_count_     u64
	primary_selection_                 string
	worker_exceptions_                 []WorkerException
	javascript_sources_                []JavaScriptSource
	broadcast_channel_messages_        []string
	worker_agents_                     map[u64]WorkerAgentState
	next_worker_agent_id_              u64 = 1
	listen_for_dom_mutations_          bool
	pending_dom_mutations_             []ClientEvent
	history_executor_                  &HistoryExecutor = &HistoryExecutor{}
}

pub fn PageClient.create() &PageClient { return &PageClient{} }

pub fn (client &PageClient) palette_is_dark() bool { return client.palette_is_dark_ }
pub fn (client &PageClient) preferred_color_scheme() string { return client.preferred_color_scheme_ }
pub fn (client &PageClient) preferred_contrast() string { return client.preferred_contrast_ }
pub fn (client &PageClient) preferred_motion() string { return client.preferred_motion_ }
pub fn (client &PageClient) zoom_level() f64 { return client.zoom_level_ }
pub fn (client &PageClient) screen_rect() PixelRect { return client.screen_rect_ }

pub fn (client &PageClient) supports_compositor() bool { return client.compositor_supported_ }

pub fn (mut client PageClient) ensure_compositor_host() {
	if !client.supports_compositor() || client.compositor_host_ != none {
		return
	}
	client.compositor_host_ = compositor.new_compositor_host()
	client.record('ensure-compositor-host', '')
}

pub fn (client &PageClient) compositor_host() ?&compositor.CompositorHost {
	return client.compositor_host_
}

fn (mut client PageClient) record(name string, text string) {
	if !client.record_events_ {
		return
	}
	client.events << ClientEvent{name: name, text: text}
}

// set_event_recording controls whether calls are logged in `events`, which
// exists for deterministic tests. Turning it off discards the log.
pub fn (mut client PageClient) set_event_recording(enabled bool) {
	client.record_events_ = enabled
	if !enabled {
		client.events.clear()
	}
}

pub fn (mut client PageClient) set_request_frame_hook(hook ?fn ()) {
	client.request_frame_hook_ = hook
}

pub fn (mut client PageClient) request_frame() {
	client.rendering_update_requested_ = true
	client.record('request-frame', '')
	if hook := client.request_frame_hook_ {
		hook()
	}
}

pub fn (_ PageClient) is_url_suitable_for_same_process_navigation(_ string, _ string) bool { return true }
pub fn (mut client PageClient) request_new_process_for_navigation(url string) { client.record('request-new-process-for-navigation', url) }
pub fn (mut client PageClient) page_did_change_title(value string) { client.record('change-title', value) }
pub fn (mut client PageClient) page_did_change_url(value string) { client.record('change-url', value) }
pub fn (mut client PageClient) page_did_request_refresh() { client.record('request-refresh', '') }
pub fn (mut client PageClient) page_did_request_resize_window(value PixelSize, completion_ids ...u64) { client.record('request-resize-window', '${value.width},${value.height}${window_request_completion_suffix(completion_ids)}') }
pub fn (mut client PageClient) page_did_request_reposition_window(value PixelPoint, completion_ids ...u64) { client.record('request-reposition-window', '${value.x},${value.y}${window_request_completion_suffix(completion_ids)}') }
pub fn (mut client PageClient) page_did_request_restore_window() { client.record('request-restore-window', '') }
pub fn (mut client PageClient) page_did_request_maximize_window(completion_ids ...u64) { client.record('request-maximize-window', window_request_completion_text(completion_ids)) }
pub fn (mut client PageClient) page_did_request_minimize_window() { client.record('request-minimize-window', '') }
pub fn (mut client PageClient) page_did_request_fullscreen_window() { client.record('request-fullscreen-window', '') }
pub fn (mut client PageClient) page_did_request_exit_fullscreen() { client.record('request-exit-fullscreen', '') }
pub fn (mut client PageClient) page_did_start_loading(url string, is_redirect bool) { client.record('start-loading', '${url}:${is_redirect}') }
pub fn (mut client PageClient) page_did_create_new_document(document string) { client.record('create-new-document', document) }
pub fn (mut client PageClient) page_did_change_active_document_in_top_level_browsing_context(document string) { client.record('change-active-document', document) }
pub fn (mut client PageClient) page_did_finish_loading(url string) { client.record('finish-loading', url) }
pub fn (mut client PageClient) page_did_request_cursor_change(cursor string) { client.record('request-cursor-change', cursor) }
pub fn (mut client PageClient) page_did_request_context_menu(position PixelPoint) { client.record('request-context-menu', '${position.x},${position.y}') }
pub fn (mut client PageClient) page_did_request_link_context_menu(_ PixelPoint, url string, target string, modifiers u32) { client.record('request-link-context-menu', '${url}:${target}:${modifiers}') }
pub fn (mut client PageClient) page_did_request_image_context_menu(_ PixelPoint, url string, target string, modifiers u32, _ ?[]u8) { client.record('request-image-context-menu', '${url}:${target}:${modifiers}') }
pub fn (mut client PageClient) page_did_request_media_context_menu(_ PixelPoint, target string, modifiers u32, details string) { client.record('request-media-context-menu', '${target}:${modifiers}:${details}') }
pub fn (mut client PageClient) page_did_click_link(url string, target string, modifiers u32) { client.record('click-link', '${url}:${target}:${modifiers}') }
pub fn (mut client PageClient) page_did_middle_click_link(url string, target string, modifiers u32) { client.record('middle-click-link', '${url}:${target}:${modifiers}') }
pub fn (mut client PageClient) page_did_request_tooltip_override(_ PixelPoint, text string) { client.record('request-tooltip-override', text) }
pub fn (mut client PageClient) page_did_stop_tooltip_override() { client.record('stop-tooltip-override', '') }
pub fn (mut client PageClient) page_did_enter_tooltip_area(text string) { client.record('enter-tooltip-area', text) }
pub fn (mut client PageClient) page_did_leave_tooltip_area() { client.record('leave-tooltip-area', '') }
pub fn (mut client PageClient) page_did_hover_link(url string) { client.record('hover-link', url) }
pub fn (mut client PageClient) page_did_unhover_link() { client.record('unhover-link', '') }
pub fn (mut client PageClient) page_did_change_favicon(bytes []u8) { client.record('change-favicon', bytes.len.str()) }
pub fn (mut client PageClient) page_did_request_alert(message string) { client.record('request-alert', message) }
pub fn (mut client PageClient) page_did_request_confirm(message string) { client.record('request-confirm', message) }
pub fn (mut client PageClient) page_did_request_prompt(message string, default_value string) { client.record('request-prompt', '${message}:${default_value}') }
pub fn (mut client PageClient) page_did_request_set_prompt_text(value string) { client.record('set-prompt-text', value) }
pub fn (mut client PageClient) page_did_request_accept_dialog() { client.record('accept-dialog', '') }
pub fn (mut client PageClient) page_did_request_dismiss_dialog() { client.record('dismiss-dialog', '') }
pub fn (_ PageClient) page_did_request_document_cookie_version(_ u64) ?u64 { return none }
pub fn (mut client PageClient) page_did_receive_document_cookie_version_buffer(value []u8) { client.record('cookie-version-buffer', value.len.str()) }
pub fn (mut client PageClient) page_did_request_document_cookie_version_index(document_id u64, domain string) { client.record('cookie-version-index-request', '${document_id}:${domain}') }
pub fn (mut client PageClient) page_did_receive_document_cookie_version_index(document_id u64, index u64) { client.record('cookie-version-index', '${document_id}:${index}') }
pub fn (_ PageClient) page_did_request_all_cookies_webdriver(_ string) []string { return [] }
pub fn (_ PageClient) page_did_request_all_cookies_cookiestore(_ string) []string { return [] }
pub fn (_ PageClient) page_did_request_named_cookie(_ string, _ string) ?string { return none }
pub fn (_ PageClient) page_did_request_cookie(_ string, _ string) string { return '' }
pub fn (mut client PageClient) page_did_set_cookie(url string, cookie string, source string) { client.record('set-cookie', '${url}:${cookie}:${source}') }
pub fn (mut client PageClient) page_did_update_cookie(cookie string) { client.record('update-cookie', cookie) }
pub fn (mut client PageClient) page_did_expire_cookies_with_time_offset(offset i64) { client.record('expire-cookies', offset.str()) }
pub fn (_ PageClient) page_did_request_storage_item(_ string, _ string, _ string) ?string { return none }
pub fn (mut client PageClient) page_did_set_storage_item(endpoint string, storage_key string, bottle_key string, value string) bool { client.record('set-storage-item', '${endpoint}:${storage_key}:${bottle_key}:${value}'); return false }
pub fn (mut client PageClient) page_did_remove_storage_item(endpoint string, storage_key string, bottle_key string) { client.record('remove-storage-item', '${endpoint}:${storage_key}:${bottle_key}') }
pub fn (_ PageClient) page_did_request_storage_keys(_ string, _ string) []string { return [] }
pub fn (mut client PageClient) page_did_clear_storage(endpoint string, storage_key string) { client.record('clear-storage', '${endpoint}:${storage_key}') }
pub fn (mut client PageClient) page_did_update_resource_count(count i32) { client.record('update-resource-count', count.str()) }
pub fn (_ PageClient) page_did_request_new_web_view(_ bool, _ string, _ bool) NewWebViewResult { return NewWebViewResult{} }
pub fn (mut client PageClient) page_did_request_activate_tab() { client.record('request-activate-tab', '') }
pub fn (mut client PageClient) page_did_close_top_level_traversable() { client.record('close-top-level-traversable', '') }
pub fn (mut client PageClient) page_did_update_navigation_buttons_state(back bool, forward bool) { client.record('navigation-buttons-state', '${back}:${forward}') }
pub fn (mut client PageClient) page_did_allocate_backing_stores(front_id i32, _ &SharedBackingStore, back_id i32, _ &SharedBackingStore) { client.record('allocate-backing-stores', '${front_id}:${back_id}') }
pub fn (mut client PageClient) page_did_request_color_picker(color string) { client.record('request-color-picker', color) }
pub fn (mut client PageClient) page_did_request_file_picker(filter string, multiple bool) { client.record('request-file-picker', '${filter}:${multiple}') }
pub fn (mut client PageClient) page_did_request_select_dropdown(position PixelPoint, minimum_width f64, items []string) { client.record('request-select-dropdown', '${position.x},${position.y}:${minimum_width}:${items.len}') }
pub fn (mut client PageClient) page_did_finish_test(text string) { client.record('finish-test', text) }
pub fn (mut client PageClient) page_did_set_test_timeout(milliseconds f64) { client.record('set-test-timeout', milliseconds.str()) }
pub fn (mut client PageClient) page_did_receive_reference_test_metadata(value string) { client.record('reference-test-metadata', value) }
pub fn (mut client PageClient) page_did_receive_test_variant_metadata(value string) { client.record('test-variant-metadata', value) }
pub fn (mut client PageClient) page_did_set_browser_zoom(factor f64) { client.record('set-browser-zoom', factor.str()) }
pub fn (mut client PageClient) page_did_set_device_pixel_ratio_for_testing(ratio f64) { client.record('set-device-pixel-ratio', ratio.str()) }
pub fn (mut client PageClient) page_did_change_theme_color(color string) { client.record('change-theme-color', color) }
pub fn (mut client PageClient) page_did_insert_clipboard_entry(value string, presentation_style string) { client.record('insert-clipboard-entry', '${presentation_style}:${value}') }
pub fn (mut client PageClient) page_did_request_clipboard_entries(request_id u64) { client.record('request-clipboard-entries', request_id.str()) }
pub fn (mut client PageClient) page_did_change_audio_play_state(value string) { client.record('change-audio-play-state', value) }
pub fn (mut client PageClient) page_did_change_screen_wake_lock_state(state ScreenWakeLockState) { client.record('change-screen-wake-lock-state', state.str()) }
pub fn (mut client PageClient) page_did_change_needs_beforeunload_check(needs_check bool) { client.record('change-needs-beforeunload-check', needs_check.str()) }
pub fn (mut client PageClient) page_did_request_geolocation_position(request_id u64) { client.record('request-geolocation-position', request_id.str()) }
pub fn (mut client PageClient) page_did_cancel_geolocation_position_request(request_id u64) { client.record('cancel-geolocation-position', request_id.str()) }
pub fn (mut client PageClient) page_did_start_geolocation_position_watch(request_id u64) { client.record('start-geolocation-position-watch', request_id.str()) }
pub fn (mut client PageClient) page_did_stop_geolocation_position_watch(request_id u64) { client.record('stop-geolocation-position-watch', request_id.str()) }
pub fn (mut client PageClient) page_did_start_network_request(request_id u64, url string, method string, headers []string, body []u8, initiator ?string) { client.record('start-network-request', '${request_id}:${method}:${url}:${headers.len}:${body.len}:${initiator or { '' }}') }
pub fn (mut client PageClient) page_did_receive_network_response_headers(request_id u64, status u32, reason ?string, headers []string) { client.record('network-response-headers', '${request_id}:${status}:${reason or { '' }}:${headers.len}') }
pub fn (mut client PageClient) page_did_receive_network_response_body(request_id u64, data []u8) { client.record('network-response-body', '${request_id}:${data.len}') }
pub fn (mut client PageClient) page_did_finish_network_request(request_id u64, body_size u64, timing string, network_error ?string) { client.record('finish-network-request', '${request_id}:${body_size}:${timing}:${network_error or { '' }}') }
pub fn (_ PageClient) request_worker_agent(_ string) WorkerAgentResponse { return WorkerAgentResponse{} }
pub fn (mut client PageClient) page_did_mutate_dom(type_ string, target string, added []string, removed []string, previous ?string, next ?string, attribute ?string) {
	client.pending_dom_mutations_ << ClientEvent{
		name: 'mutate-dom'
		text: '${type_}:${target}:${added.len}:${removed.len}:${previous or { '' }}:${next or { '' }}:${attribute or { '' }}'
	}
}
pub fn (mut client PageClient) page_did_paint(rect PixelRect, bitmap_id i32) { client.record('paint', '${rect.x},${rect.y},${rect.width},${rect.height}:${bitmap_id}') }
pub fn (mut client PageClient) page_did_take_screenshot(data []u8) {
	client.screenshots << data.clone()
	client.record('take-screenshot', data.len.str())
}
pub fn (mut client PageClient) received_message_from_web_ui(name string, data string) { client.record(name, data) }
pub fn (_ PageClient) is_svg_page_client() bool { return false }
