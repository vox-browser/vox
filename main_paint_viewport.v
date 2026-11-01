module main

import os

// Retain a same-binary control for precise-scroll comparisons.
const disable_replay_viewport_top_reuse = os.getenv('VOX_DISABLE_REPLAY_VIEWPORT_TOP_REUSE') != ''

@[inline]
fn (app &BrowserApp) paint_replay_viewport_top(frame_top f32) f32 {
	if disable_replay_viewport_top_reuse { return app.page_top() }
	return frame_top
}
