module layout

import html
import os

const sites_probe_styles = '<!doctype html><style>html,body{margin:0}
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

fn test_prealloc_frame_sites_probe() {
	if os.getenv('VOX_PREALLOC_PROBE') != '1' { return }
	class := os.getenv_opt('PROBE_CLASS') or { 't' }
	trigger := os.getenv('VOX_PREALLOC_SAMPLE_TRIGGER')
	mut markup := sites_probe_styles
	for _ in 0 .. 10 {
		markup += '<div class="${class}">x</div>'
	}
	markup += '<p>Some text that does not animate.</p>'
	mut document := html.parse_document(markup)
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 4000)
	_ = document.record_display_list() or { panic('missing paint') }
	for frame in 0 .. 140 {
		if frame == 40 && trigger != '' {
			os.write_file(trigger, '') or {}
		}
		document.update_animations_and_send_events(f64(frame) * 16.7)
		document.update_layout(.html_event_loop_rendering_update)
		_ = document.record_display_list() or { panic('missing frame paint') }
	}
	if trigger != '' {
		os.rm(trigger) or {}
	}
}
