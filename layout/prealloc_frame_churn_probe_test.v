module layout

import css
import html
import os
import platform

const churn_probe_styles = '<!doctype html><style>html,body{margin:0}
@keyframes move{from{transform:translateX(0)}to{transform:translateX(100px)}}
@keyframes fade{from{opacity:0.2}to{opacity:1}}
@keyframes tint{from{background-color:red}to{background-color:blue}}
@keyframes grow{from{width:10px}to{width:100px}}
@keyframes shine{from{background-position:-200px 0}to{background-position:200px 0}}
.none{width:20px;height:20px;background:green}
.t{width:20px;height:20px;background:green;animation:move 1s linear infinite}
.o{width:20px;height:20px;background:green;animation:fade 1s linear infinite}
.c{width:20px;height:20px;animation:tint 1s linear infinite}
.g{height:20px;background:green;animation:grow 1s linear infinite}
.s{width:200px;height:20px;background:linear-gradient(90deg,#eee 0,#ccc 50%,#eee 100%);background-size:400px 20px;animation:shine 1s linear infinite}
.p{position:relative;overflow:hidden;width:60px;height:20px}.p::before{content:"";position:absolute;inset:0;background:linear-gradient(90deg,transparent,#fff,transparent);animation:move 1s linear infinite}
</style>'

fn churn_probe_used() i64 {
	return platform.thread_arena_usage().used
}

fn churn_probe_run(class string, count int) string {
	mut markup := churn_probe_styles
	for _ in 0 .. count {
		markup += '<div class="${class}">x</div>'
	}
	markup += '<p>Some text that does not animate.</p>'
	mut document := html.parse_document(markup)
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 4000)
	_ = document.record_display_list() or { panic('missing paint') }
	mut sampling := i64(0)
	mut style_layout := i64(0)
	mut recording := i64(0)
	frames := 100
	_ = css.arena_probe_take()
	for frame in 0 .. frames + 10 {
		t0 := churn_probe_used()
		document.update_animations_and_send_events(f64(frame) * 16.7)
		t1 := churn_probe_used()
		document.update_layout(.html_event_loop_rendering_update)
		t2 := churn_probe_used()
		_ = document.record_display_list() or { panic('missing frame paint') }
		t3 := churn_probe_used()
		if frame >= 10 {
			sampling += t1 - t0
			style_layout += t2 - t1
			recording += t3 - t2
		}
	}
	slots := css.arena_probe_take()
	mut slot_text := []string{}
	for index, value in slots {
		if value != 0 { slot_text << '${index}:${value / frames}' }
	}
	stats := css.animation_sample_stats(document)
	return '${class} x${count}: ${stats} slots=${slot_text.join(',')} sampling=${sampling / frames} style_layout=${style_layout / frames} recording=${recording / frames} total=${(sampling + style_layout + recording) / frames}'
}

fn test_prealloc_frame_churn_probe() {
	if os.getenv('VOX_PREALLOC_PROBE') != '1' { return }
	mut lines := []string{}
	for class in ['t', 'o', 'c', 's', 'p'] {
		lines << churn_probe_run(class, 10)
	}
	output := os.getenv_opt('VOX_PREALLOC_PROBE_DIR') or { os.join_path(os.dir(os.dir(@FILE)), 'Build', 'prealloc-memory') }
	os.mkdir_all(output) or { panic(err) }
	os.write_file(os.join_path(output, 'churn.txt'), lines.join('\n') + '\n') or { panic(err) }
}

fn test_prealloc_struct_sizes() {
	if os.getenv('VOX_PREALLOC_PROBE') != '1' { return }
	output := os.getenv_opt('VOX_PREALLOC_PROBE_DIR') or { os.join_path(os.dir(os.dir(@FILE)), 'Build', 'prealloc-memory') }
	os.mkdir_all(output) or { panic(err) }
	os.write_file(os.join_path(output, 'sizes.txt'), 'ComputedLayoutCache=${css.computed_layout_cache_size()} ComputedProperties=${css.computed_properties_size()}\n') or { panic(err) }
}
