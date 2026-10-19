// Copyright (c) 2022, the SerenityOS developers.
// Copyright (c) 2024, Andreas Kling <andreas@ladybird.org>
// SPDX-License-Identifier: BSD-2-Clause

// Window.cpp AnimationFrameProvider binding. The owning Window and HTML
// rendering loop own scheduling; this adapter only retains actual JSC values.
module browserjs

import dom
import html

pub type AnimationFrameReplayHook = fn (&Runtime) !

@[heap]
struct AnimationFrameHostRecord {
	function voidptr
mut:
	handle u32
}

@[heap]
pub struct AnimationFrameHost {
	window   &html.WindowModel
	settings &html.EnvironmentSettingsObject
	replay   ?AnimationFrameReplayHook
mut:
	runtime   &Runtime = unsafe { nil }
	records   map[u32]&AnimationFrameHostRecord
	installed bool
	closed    bool
}

pub fn AnimationFrameHost.create(document &dom.Document, replay ?AnimationFrameReplayHook) !&AnimationFrameHost {
	if document.relevant_settings_object() == unsafe { nil } {
		_ = html.WindowModel.create_top_level(document, none, '')!
	}
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	window_pointer := document.get_window() or {
		return error('AnimationFrameProvider requires its owning Window')
	}
	window := unsafe { &html.WindowModel(window_pointer) }
	return &AnimationFrameHost{
		window:   window
		settings: settings
		replay:   replay
	}
}

pub fn (mut host AnimationFrameHost) close() {
	if host.closed { return }
	host.closed = true
	mut window := unsafe { &html.WindowModel(host.window) }
	for handle, record in host.records {
		window.cancel_animation_frame(handle)
		host.runtime.release_javascript_value(record.function)
	}
	host.records = {}
}
