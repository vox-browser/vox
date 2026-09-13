// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of InternalsBase.cpp/.h. PlatformState is the explicit Page /
// PageClient boundary used by the remaining internals objects.
module internals

import dom

pub enum InputActionKind {
	key_down
	mouse_down
	mouse_up
	mouse_move
	wheel
	pinch
	paste
	commit_text
	drag_start
	drag_move
	drop
}

pub struct InputAction {
pub:
	kind        InputActionKind
	x           f64
	y           f64
	delta_x     f64
	delta_y     f64
	scale       f64
	button      u16
	click_count u16
	modifiers   u16
	key         string
	code_point  u32
	text        string
	mime_type   string
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

@[heap]
pub struct PlatformState {
pub mut:
	active                    bool = true
	headless_                 bool
	current_url               string
	top_level_url             string
	time_zone                 string = 'UTC'
	current_cursor_           string = 'default'
	input_actions             []InputAction
	web_ui_messages           []WebUIMessage
	test_done_text            string
	test_timeout_ms           f64
	ref_metadata_json         string
	test_variants_json        string
	cookie_expiry_offset      i64
	http_memory_cache_enabled bool = true
	browser_zoom              f64  = 1.0
	device_pixel_ratio        f64  = 1.0
	echo_server_port          u16
	display_list_dump         string
	stacking_context_dump     string
	gc_graph_dump             string
	highlighted_node          ?&dom.Node
	hit_test_result           ?HitTestResult
	associated_document       ?&dom.Document
	sdl_input_event_pumps     int
	garbage_collections       int
	force_dark_enabled        bool
	show_line_box_borders     bool
	force_dark_foreground     i32
	force_dark_background     i32
	visual_context_force_rebuilds               u64
	visual_context_incremental_update_count     u64
	visual_context_pending_dirty_box_count      u64
	layout_tree_pre_order_label_violation_count u64
	layout_tree_pre_order_relabel_count         u64
	visual_context_tree_node_count              u64
	visual_context_tree_dead_node_count         u64
	visual_context_tree_structural_epoch        u64
	visual_context_tree_node_capacity           u64
	visual_context_node_indices_                map[i64]VisualContextNodeIndices
	mismatched_visual_context_updates           u64
	partial_layout_count_                       u64
	full_layout_count_                          u64
	layout_run_cache_hit_count_                 u64
	table_cell_measurement_cache_miss_count_    u64
	intrinsic_measurement_count_                u64
	accumulated_visual_context_tree_build_count_ u64
	display_list_trace_active                   bool
	display_list_trace                          string
	recorded_display_list_blocks_wheel          bool
	record_display_list_requests                u64
	last_record_display_list_paint_overlay      bool
	last_record_display_list_cold               bool
	needs_repaint_                              bool
	needs_display_list_record_                  bool
	screen_wake_lock_active_                    bool
	stacking_context_verification_report        string
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
