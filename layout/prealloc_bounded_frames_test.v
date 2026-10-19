module layout

import dom
import html
import platform

// Under -prealloc nothing allocated from a thread's base arena is ever freed,
// so per-frame work must use arenas or reuse retained storage. After warm-up,
// compositor-only animations (an element's transform or opacity, and a
// pseudo-element's transform) may only add a small amount of persistent
// storage per frame.
// Without -prealloc the frames still run; the base arena is not measured.
const bounded_frames_styles = '<!doctype html><style>html,body{margin:0}
@keyframes move{from{transform:translateX(0)}to{transform:translateX(100px)}}
@keyframes fade{from{opacity:0.2}to{opacity:0.9}}
@keyframes tint{from{background-color:red}to{background-color:blue}}
@keyframes ink{from{color:red}to{color:blue}}
.t{width:20px;height:20px;background:green;animation:move 1s linear infinite}
.o{width:20px;height:20px;background:green;animation:fade 1s linear infinite}
.c{width:20px;height:20px;animation:tint 1s linear infinite}
.k{width:60px;height:20px;animation:ink 1s linear infinite}
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

// Native windows record only the viewport, which culls entries on each frame.
fn record_bounded_frame(mut document dom.Document, viewport_only bool) {
	list := if viewport_only { document.record_viewport_display_list() } else { document.record_display_list() }
	_ = list or { panic('missing frame paint') }
}

fn run_bounded_frames(class string, viewport_only bool) BoundedFramesResult {
	mut markup := bounded_frames_styles
	for _ in 0 .. 10 {
		markup += '<div class="${class}">x</div>'
	}
	markup += '<p>Some text that does not animate.</p>'
	mut document := html.parse_document(markup)
	_ = layout_document_typed_in_viewport(document, 320, 4000)
	record_bounded_frame(mut document, viewport_only)
	mut before := i64(0)
	for frame in 0 .. bounded_frames_warmup + bounded_frames_measured {
		if frame == bounded_frames_warmup {
			before = platform.thread_arena_usage().used
		}
		document.update_animations_and_send_events(f64(frame) * 16.7)
		document.update_layout(.html_event_loop_rendering_update)
		record_bounded_frame(mut document, viewport_only)
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
	for viewport_only in [false, true] {
		for class in ['t', 'o', 'p'] {
			result := run_bounded_frames(class, viewport_only)
			$if prealloc {
				// Poisoned arenas are never reused, by design.
				if platform.arenas_poisoned() {
					continue
				}
				assert result.bytes_per_frame <= bounded_frames_budget, '${class} viewport=${viewport_only}: ${result.bytes_per_frame} persistent bytes per frame'
				// The layout result holds the current scene; earlier ones are reset
				// and kept as spares rather than accumulating.
				assert result.live_scenes == 1, '${class}: ${result.live_scenes} live scenes'
				assert result.spare_scenes <= display_list_scene_spares
			}
		}
	}
}

// Repaint animations still re-record their boxes on every frame (see
// docs/PREALLOC_MEMORY.md), so they have no budget yet; their samples must
// still be safe to retire, including colors resolved while sampling.
fn test_repaint_animation_frames_keep_one_live_scene() {
	for viewport_only in [false, true] {
		for class in ['c', 'k'] {
			result := run_bounded_frames(class, viewport_only)
			$if prealloc {
				assert result.live_scenes == 1, '${class}: ${result.live_scenes} live scenes'
			}
		}
	}
}
