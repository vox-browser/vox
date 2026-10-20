module layout

import dom
import html
import platform

fn test_foreign_text_caches_do_not_borrow_the_entered_document_arena() {
	$if !prealloc { return }
	mut foreign := html.parse_document('<!doctype html><section style="display:flow-root"><p>Reusable foreign text</p></section>')
	_ = layout_document_typed_in_viewport(foreign, 320, 240)
	foreign_layout := document_layout_result(foreign) or { panic('missing foreign layout') }
	mut pending := [foreign_layout.root]
	mut text := unsafe { &TextNode(nil) }
	for pending.len > 0 {
		node := pending.pop()
		if found := node.as_text_node() {
			if found.text_for_rendering() != '' { text = found; break }
		}
		for child in node.children() { pending << child }
	}
	assert voidptr(text) != unsafe { nil }
	text.cached_utf16_code_units_ = none
	text.cached_grapheme_boundaries_ = []int{}
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	owner := document.native_storage()
	mut allocations := document.enter_native_storage()
	assert cache_uses_entered_document_storage(document)
	assert !cache_uses_entered_document_storage(foreign)
	assert foreign_layout.state.block_layouts_.len > 0
	assert !block_paint_caches_use_entered_document_storage(foreign_layout.state)
	iterator := TextNodeChunkIterator.new(text, true, false)
	assert iterator.code_units.len > 0
	assert !owner.arena.contains(iterator.code_units.data)
	assert !owner.arena.contains(text.cached_grapheme_boundaries_.data)
	units := unsafe { iterator.code_units }
	allocations.finish()
	document.finalize()
	document.release_native_storage()
	assert units[0] == u16(`R`)
	foreign.destroy_a_document_and_its_descendants()
	foreign.finalize()
}

fn test_native_text_segmentation_and_intrinsic_cache_vectors_belong_to_the_document() {
	$if !prealloc { return }
	url := dom.URL{value:'https://text-cache.example/'}
	mut document := html.create_navigation_document(url, url.origin(), none)!
	document.enable_native_storage()
	owner := document.native_storage()
	mut allocations := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><style>
main{display:flex;width:200px}span{display:inline-block}
</style><main><div>Retained multilingual words אבג <span>atomic sizing words</span></div></main>')
	allocations.finish()
	enable_native_paint_tree_storage(document)
	_ = layout_document_typed_in_viewport(document, 320, 240)
	result := document_layout_result(document) or { panic('missing layout') }
	mut pending := [result.root]
	mut texts := 0
	mut intrinsic := 0
	for pending.len > 0 {
		node := pending.pop()
		for child in node.children() { pending << child }
		if text := node.as_text_node() {
			if units := text.cached_utf16_code_units_ {
				if units.len > 0 { assert owner.arena.contains(units.data) }
			}
			if chunks := text.cached_inline_chunks_ {
				if chunks.len > 0 { assert owner.arena.contains(chunks.data) }
			}
			if text.cached_grapheme_boundaries_.len > 0 {
				assert owner.arena.contains(text.cached_grapheme_boundaries_.data)
			}
			if text.cached_intrinsic_text_shapes_.len > 0 {
				assert owner.arena.contains(text.cached_intrinsic_text_shapes_.data)
				intrinsic++
			}
			texts++
		}
	}
	assert texts > 0 && intrinsic > 0
	display := document.record_viewport_display_list() or { panic('missing recording') }
	assert display_list_commands(display).any(it.text.contains('Retained'))
	handle := document.layout_engine_handle()
	document.destroy_a_document_and_its_descendants()
	document.finalize()
	retire_native_document_layout(handle)
	document.release_native_storage()
	for _ in 0 .. 100 {
		if owner.arena.usage().capacity == 0 { break }
		platform.pump_native_events(0.01)
	}
	assert owner.arena.usage().capacity == 0
}
