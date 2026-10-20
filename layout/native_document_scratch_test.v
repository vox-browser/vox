module layout

import dom
import html

fn test_native_document_recordings_keep_culling_and_refresh_temporaries_in_scratch() {
	url := dom.URL{value: 'https://scratch.example/'}
	mut document := html.create_navigation_document(url, url.origin(), none)!
	document.set_font_rendering_policy(.chromium)
	document.enable_native_storage()
	mut allocations := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><style>
@keyframes move { from { transform:translateX(0) } to { transform:translateX(20px) } }
div { width:20px;height:20px;background:green;animation:move 1s linear infinite }
</style>' + '<div>x</div>'.repeat(40))
	allocations.finish()
	defer {
		handle := document.layout_engine_handle()
		document.destroy_a_document_and_its_descendants()
		document.finalize()
		retire_native_document_layout(handle)
		document.release_native_storage()
	}
	enable_native_paint_tree_storage(document)
	_ = layout_document_typed_in_viewport(document, 320, 400)
	mut before := i64(0)
	for frame in 0 .. 50 {
		if frame == 10 {
			$if prealloc { before = document.native_storage().arena.usage().used }
		}
		document.update_animations_and_send_events(f64(frame) * 16.0)
		document.update_layout(.html_event_loop_rendering_update)
		_ = document.record_viewport_display_list() or { panic('missing viewport recording') }
	}
	$if prealloc {
		grown := document.native_storage().arena.usage().used - before
		assert grown < 64 * 1024, '${grown} bytes accumulated in document storage'
	}
}
