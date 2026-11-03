module layout

import dom
import html

fn equal_text_cache_storage_document() !&dom.Document {
	url := dom.URL{ value: 'https://equal-text-cache.test/' }
	mut document := html.create_navigation_document(url, url.origin(), none)!
	document.enable_native_storage()
	mut allocations := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><p><span id="stamp">2 days ago</span></p><main>' +
		'<p>Unchanged <b>comment</b> text.</p>'.repeat(256) + '</main>')
	allocations.finish()
	enable_native_paint_tree_storage(document)
	_ = layout_document_typed_in_viewport(document, 400, 300)
	return document
}

fn retire_equal_text_cache_storage_document(mut document dom.Document) {
	handle := document.layout_engine_handle()
	document.destroy_a_document_and_its_descendants()
	document.finalize()
	retire_native_document_layout(handle)
	document.release_native_storage()
}

fn equal_text_cache_storage_trial(discard bool) !i64 {
	mut document := equal_text_cache_storage_document()!
	defer { retire_equal_text_cache_storage_document(mut document) }
	mut result := document_layout_result(document) or { return error('missing layout') }
	mut owner := document.enter_native_storage()
	defer { owner.finish() }
	storage := document.native_storage()
	before := storage.arena.usage().used
	for _ in 0 .. 16 {
		if discard { result.equal_text_cache = unsafe { nil } }
		result.remember_native_equal_text_inputs(400, 300)
	}
	return storage.arena.usage().used - before
}

fn test_native_equal_text_cache_refill_reuses_its_wide_validation_vector() {
	$if !prealloc {
		return
	}
	control := equal_text_cache_storage_trial(true)!
	candidate := equal_text_cache_storage_trial(false)!
	println('Native equal text index: retained=${candidate} control=${control} bytes')
	assert candidate < 64 * 1024
	assert candidate * 4 < control
}

fn test_real_relayout_moves_only_the_private_equal_text_index_and_keeps_snapshots() {
	$if !prealloc {
		return
	}
	mut document := equal_text_cache_storage_document()!
	defer { retire_equal_text_cache_storage_document(mut document) }
	previous := document_layout_result(document)?
	cache := previous.equal_text_cache
	assert cache != unsafe { nil }
	buffer := cache.inputs.data
	count := cache.inputs.len
	assert count > 256
	old_display := document.record_display_list()?
	scene := retain_display_list_scene(old_display)
	defer { release_display_list_scene(scene) }
	old_commands := old_display.dump()
	mut stamp := document.get_element_by_id('stamp')?.as_node()
	stamp.set_text_content('Changed timestamp')!
	document.update_layout(.debugging)
	current := document_layout_result(document)?
	assert voidptr(current) != voidptr(previous)
	assert previous.equal_text_cache == unsafe { nil }
	assert voidptr(current.equal_text_cache) == voidptr(cache)
	assert current.equal_text_cache.inputs.data == buffer
	assert current.equal_text_cache.inputs.len == count
	old_snapshot_matches := old_display.dump() == old_commands
	assert old_snapshot_matches
	mut saw_changed_text := false
	for input in current.equal_text_cache.inputs {
		if input.dom_text == 'Changed timestamp' {
			assert input.text == 'Changed timestamp'
			assert input.dom_connected
			saw_changed_text = true
		}
	}
	assert saw_changed_text
	stamp.set_text_content('')!
	stamp.set_text_content('Changed timestamp')!
	document.update_layout(.debugging)
	assert document.layout_engine_handle() == voidptr(current)
}

fn test_tree_only_layout_does_not_publish_an_old_equal_text_validation_index() {
	$if !prealloc {
		return
	}
	mut document := equal_text_cache_storage_document()!
	defer { retire_equal_text_cache_storage_document(mut document) }
	assert document_layout_result(document)?.equal_text_cache != unsafe { nil }
	// A native host keeps its presented projection until adopting a new one,
	// including across a geometry-only diagnostic update.
	projection := retain_document_paint_tree(document)
	defer { release_paint_tree(projection) }
	mut stamp := document.get_element_by_id('stamp')?.as_node()
	stamp.set_text_content('Changed for a tree dump')!
	_ = run_document_layout_for_tree_dump(document, 400, 300)?
	assert document_layout_result(document)?.equal_text_cache == unsafe { nil }
}
