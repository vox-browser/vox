module layout

import html
import platform

fn test_pages_without_scroll_snap_do_not_allocate_indexes_or_paintable_snapshots() {
	mut document := html.parse_document('<!doctype html><main>' + '<div>ordinary content</div>'.repeat(64) + '</main>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	result := document_layout_result(document)?
	viewport := document.viewport_rect()
	before := platform.thread_arena_usage().used
	for _ in 0 .. 16 { resnap_document_scroll_containers(result) }
	$if prealloc { assert platform.thread_arena_usage().used - before < 4096 }
	assert document.viewport_rect() == viewport
}
