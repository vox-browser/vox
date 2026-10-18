module layout

import html
import platform

// Under -prealloc nothing allocated from a thread's base arena is ever freed,
// so per-frame work must use arenas or reuse retained storage. After warm-up,
// compositor-only animations (an element's transform and a pseudo-element's
// transform) may only add a small amount of persistent storage per frame.
// Without -prealloc the frames still run; the base arena is not measured.
const bounded_frames_styles = '<!doctype html><style>html,body{margin:0}
@keyframes move{from{transform:translateX(0)}to{transform:translateX(100px)}}
.t{width:20px;height:20px;background:green;animation:move 1s linear infinite}
.p{position:relative;overflow:hidden;width:60px;height:20px}.p::before{content:"";position:absolute;inset:0;background:linear-gradient(90deg,transparent,#fff,transparent);animation:move 1s linear infinite}
</style>'

const bounded_frames_warmup = 30
const bounded_frames_measured = 120
// Animation iteration events and similar rare work stay well below this.
const bounded_frames_budget = i64(256)

struct BoundedFramesResult {
	bytes_per_frame i64
	live_scenes     int
	spare_scenes    int
}

fn run_bounded_frames(class string) BoundedFramesResult {
	mut markup := bounded_frames_styles
	for _ in 0 .. 10 {
		markup += '<div class="${class}">x</div>'
	}
	markup += '<p>Some text that does not animate.</p>'
	mut document := html.parse_document(markup)
	_ = layout_document_typed_in_viewport(document, 320, 4000)
	_ = document.record_display_list() or { panic('missing paint') }
	mut before := i64(0)
	for frame in 0 .. bounded_frames_warmup + bounded_frames_measured {
		if frame == bounded_frames_warmup {
			before = platform.thread_arena_usage().used
		}
		document.update_animations_and_send_events(f64(frame) * 16.7)
		document.update_layout(.html_event_loop_rendering_update)
		_ = document.record_display_list() or { panic('missing frame paint') }
	}
	grown := platform.thread_arena_usage().used - before
	mut result := document_layout_result(document) or { panic('missing layout result') }
	pool := result.scene_pool_()
	return BoundedFramesResult{
		bytes_per_frame: grown / bounded_frames_measured
		live_scenes:     pool.live.len
		spare_scenes:    pool.free.len
	}
}

fn test_compositor_animation_frames_reuse_bounded_storage() {
	for class in ['t', 'p'] {
		result := run_bounded_frames(class)
		$if prealloc {
			// Poisoned arenas are never reused, by design.
			if platform.arenas_poisoned() {
				continue
			}
			assert result.bytes_per_frame <= bounded_frames_budget, '${class}: ${result.bytes_per_frame} persistent bytes per frame'
			// The layout result holds the current scene; earlier ones are reset
			// and kept as spares rather than accumulating.
			assert result.live_scenes == 1, '${class}: ${result.live_scenes} live scenes'
			assert result.spare_scenes <= display_list_scene_spares
		}
	}
}
