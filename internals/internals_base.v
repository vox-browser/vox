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
	sdl_input_event_pumps     int
	garbage_collections       int
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
