module layout

import html
import math

// An opacity sample between two nonzero values keeps the paint plan and the
// recorded phase commands; replay scales the commands to the new cumulative
// opacity. The result must match a recording made from scratch.
fn test_opacity_samples_scale_cached_commands_like_a_fresh_recording() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}
@keyframes fade{from{opacity:0.2}to{opacity:0.9}}
#outer{opacity:0.5}
.f{width:40px;height:20px;background:green;color:blue;animation:fade 1s linear infinite}
</style><div id="outer"><div class="f">text<span style="opacity:0.5">inner</span></div></div><div class="f"></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	_ = document.record_display_list() or { panic('missing paint') }
	mut recorded_buckets := []voidptr{}
	for frame in 0 .. 12 {
		document.update_animations_and_send_events(f64(frame) * 37.0)
		document.update_layout(.html_event_loop_rendering_update)
		incremental := record_retained_display_list(mut document) or { panic('missing frame paint') }
		incremental_dump := incremental.dump()
		incremental_opacity := display_list_commands(incremental).map(it.opacity)
		mut result := document_layout_result(document) or { panic('missing layout result') }
		if recorded_buckets.len > 0 {
			// The phase commands recorded by the previous fresh recording were
			// replayed, not recorded again.
			assert result.paint_phase_commands.len == recorded_buckets.len
			for index, bucket in result.paint_phase_commands {
				assert voidptr(bucket.data) == recorded_buckets[index], 'frame ${frame}'
			}
			assert result.record_scratch.entry_opacity_scales.len > 0
		}
		result.paint_phase_commands = [][]PaintCommand{}
		result.paint_phase_cache_valid = false
		result.display_list = unsafe { nil }
		result.needs_repaint = true
		document.invalidate_display_list()
		fresh := record_retained_display_list(mut document) or { panic('missing fresh paint') }
		assert fresh.dump() == incremental_dump, 'frame ${frame}'
		fresh_opacity := display_list_commands(fresh).map(it.opacity)
		assert fresh_opacity.len == incremental_opacity.len
		for index, opacity in fresh_opacity {
			assert math.abs(opacity - incremental_opacity[index]) < 1e-9, 'frame ${frame} command ${index}'
		}
		recorded_buckets.clear()
		for bucket in result.paint_phase_commands {
			recorded_buckets << voidptr(bucket.data)
		}
	}
}
