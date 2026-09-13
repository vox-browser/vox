// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of InternalsBase.cpp/.h. PlatformState is the explicit Page /
// PageClient boundary used by the remaining internals objects.
module internals

import dom
import html
import compositor

pub enum InputActionKind {
	key_down
	key_up
	mouse_down
	mouse_up
	mouse_move
	mouse_leave
	wheel
	pinch
	paste
	paste_from_clipboard
	commit_text
	set_marked_text
	commit_input_method_text
	unmark_text
	drag_start
	drag_move
	drop
}

pub enum WheelDeltaPrecision {
	coarse
	precise
}

pub enum ScrollGesturePhase {
	none_
	ongoing
	momentum
	ended
}

pub struct ClipboardFile {
pub:
	name      string
	mime_type string
	data      string
}

// Cookie storage is owned by PageClient upstream. Keep its observable test
// representation at the translated embedder boundary as well.
pub struct PlatformCookie {
pub:
	url       dom.URL
	name      string
	value     string
	domain    string
	path      string = '/'
	secure    bool
	host_only bool = true
}

pub struct InputAction {
pub:
	kind               InputActionKind
	x                  f64
	y                  f64
	delta_x            f64
	delta_y            f64
	scale              f64
	button             u16
	click_count        u16
	modifiers          u16
	key                string
	code_point         u32
	text               string
	mime_type          string
	precise            bool
	gesture            ScrollGesturePhase
	replacement_start  i32
	replacement_length i32
}

pub struct HitTestResult {
pub:
	node          ?&dom.Node
	index_in_node int
}

pub struct VisualContextNodeIndices {
pub:
	spatial                           []u32
	clips                             []u32
	effects                           []u32
	needs_compositor_effects_layer    bool
	needs_compositor_background_frame bool
}

pub struct LayoutTreeBuildStats {
pub:
	builds                           u64
	last_build_rebuilt_subtree_roots u64
	last_build_escaped_rebuild_roots u64
}

pub struct LayoutTreeComparison {
pub:
	matches     bool
	incremental string
	full        string
}

pub struct StyleEngineTransactionReactions {
pub:
	whole_document bool
	elements       []string
}

pub struct StyleGroupSharingState {
pub:
	shared_with_parent bool
	is_default         bool
}

@[heap]
pub struct PlatformState {
pub mut:
	active                                                  bool = true
	headless_                                               bool
	current_url                                             string
	top_level_url                                           string
	time_zone                                               string = 'UTC'
	current_cursor_                                         string = 'default'
	input_actions                                           []InputAction
	web_ui_messages                                         []WebUIMessage
	test_done_text                                          string
	test_timeout_ms                                         f64
	ref_metadata_json                                       string
	test_variants_json                                      string
	cookie_expiry_offset                                    i64
	cookies                                                 []PlatformCookie
	http_memory_cache_enabled                               bool = true
	browser_zoom                                            f64 = 1.0
	device_pixel_ratio                                      f64 = 1.0
	echo_server_port                                        u16
	display_list_dump                                       string
	stacking_context_dump                                   string
	gc_graph_dump                                           string
	highlighted_node                                        ?&dom.Node
	hit_test_result                                         ?HitTestResult
	associated_document                                     ?&dom.Document
	sdl_input_event_pumps                                   int
	garbage_collections                                     int
	javascript_bindings                                     map[string]dom.JSValue = map[string]dom.JSValue{}
	garbage_binding_names                                   []string
	has_completed_initial_paint_                            bool
	initial_paint_had_pending_fonts_                        bool
	force_dark_enabled                                      bool
	show_line_box_borders                                   bool
	force_dark_foreground                                   i32
	force_dark_background                                   i32
	visual_context_force_rebuilds                           u64
	visual_context_incremental_update_count                 u64
	visual_context_pending_dirty_box_count                  u64
	layout_tree_pre_order_label_violation_count             u64
	layout_tree_pre_order_relabel_count                     u64
	visual_context_tree_node_count                          u64
	visual_context_tree_dead_node_count                     u64
	visual_context_tree_structural_epoch                    u64
	visual_context_tree_node_capacity                       u64
	visual_context_node_indices_                            map[i64]VisualContextNodeIndices
	mismatched_visual_context_updates                       u64
	partial_layout_count_                                   u64
	full_layout_count_                                      u64
	layout_run_cache_hit_count_                             u64
	table_cell_measurement_cache_miss_count_                u64
	intrinsic_measurement_count_                            u64
	accumulated_visual_context_tree_build_count_            u64
	display_list_trace_active                               bool
	display_list_trace                                      string
	recorded_display_list_blocks_wheel                      bool
	record_display_list_requests                            u64
	last_record_display_list_paint_overlay                  bool
	last_record_display_list_cold                           bool
	needs_repaint_                                          bool
	needs_display_list_record_                              bool
	screen_wake_lock_active_                                bool
	stacking_context_verification_report                    string
	selected_text_for_clipboard_                            string
	clipboard_file                                          ?ClipboardFile
	current_caret_rect_                                     ?dom.Rect
	loaded_urls                                             []string
	request_server_connection_losses                        u64
	worker_request_server_connection_losses                 u64
	content_blockers_source                                 string
	content_blocking_enabled                                bool = true
	user_style_invalidations                                u64
	user_style_source                                       string
	preferred_color_scheme_override                         ?string
	page_has_focus                                          bool
	system_visibility_state                                 dom.VisibilityState = .visible
	hidden_document_timer_wake_up_interval_ms               f64
	hidden_document_intensive_wake_up_interval_ms           f64
	hidden_document_intensive_grace_period_once_loaded_ms   f64
	hidden_document_intensive_grace_period_while_loading_ms f64
	site_compatibility_source                               string
	experimental_interfaces_exposed                         bool
	autoplay_policy                                         string = 'block-audio'
	accessibility_tree_dump                                 string
	ui_process_session_history                              string
	session_history_navigable_id                            string
	captured_session_history                                string
	capture_session_history_snapshot_result                 bool = true
	restore_session_history_snapshot_result                 bool = true
	register_session_store_tab_result                       bool = true
	session_store_tab_state                                 string
	site_isolation_process_tree                             string
	remote_frame_process_crashes                            u64
	session_history_traversal_queue_flushes                 u64
	page_muted                                              bool
	page_media_elements                                     []&html.HTMLMediaElement
	geolocation_emulated_position                           html.EmulatedPositionData
	manual_rendering_opportunities                          bool
	last_injected_rendering_opportunity_ms                  f64
	compositor_animation_updates                            u64
	empty_animation_style_update_result                     bool
	compositor_animation_timer_arms                         u64
	compositor_animation_wakeup_frame_time_ms               f64
	force_visual_context_rebuild_on_animation               bool
	reentrant_animation_style_flush_node                    ?&dom.Node
	layout_tree_build_stats_                                LayoutTreeBuildStats
	incremental_layout_tree_dump                            string
	full_rebuild_layout_tree_dump                           string
	style_ffi_counters_                                     map[string]u64 = map[string]u64{}
	style_engine_counters_                                  map[string]u64 = map[string]u64{}
	style_engine_transaction_reactions_                     StyleEngineTransactionReactions
	style_engine_document_match_count                       f64 = -1
	style_engine_matched_rules_dump                         string
	style_ffi_counters_enabled                              bool
	style_update_requests                                   u64
	async_scrolling_display_list                            ?&compositor.CompositorDisplayList
	async_scrolling_visual_context_tree                     ?&compositor.VisualContextTree
	async_scrolling_scroll_state_snapshot                   compositor.CompositorScrollStateSnapshot
	recorded_async_scrolling_display_list                   ?&compositor.CompositorDisplayList
	compositor_visual_animations                            []compositor.VisualAnimation
	compositor_visual_animation_targets_are_valid           bool = true
	document_timeline_current_time                           ?f64
	compositor_animation_wakeup_timer_active                bool
	compositor_animation_observation_timer_active           bool
}

@[heap]
pub struct InternalsBase {
pub mut:
	platform &PlatformState
}

pub fn InternalsBase.new(platform &PlatformState) &InternalsBase {
	return &InternalsBase{
		platform: platform
	}
}

pub fn (base &InternalsBase) window() &PlatformState {
	return base.platform
}

pub fn (base &InternalsBase) page() &PlatformState {
	return base.platform
}
