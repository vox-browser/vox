module layout

import dom
import html

fn test_nested_inline_item_vectors_reuse_storage_without_growing_document() {
	$if !prealloc { return }
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut allocations := document.enter_native_storage()
	mut outer := acquire_inline_item_buffers(document)
	mut outer_items := []InlineLevelItem{}
	reserve_inline_items_in_storage(mut outer_items, 1, outer.arena)
	outer_items << InlineLevelItem{type_: .forced_break, width: CSSPixels.new(47)}
	before := document.native_storage().arena.usage().used
	for _ in 0 .. 64 {
		mut inner := acquire_inline_item_buffers(document)
		assert voidptr(inner.arena) != voidptr(outer.arena)
		mut items := []InlineLevelItem{}
		reserve_inline_items_in_storage(mut items, 1024, inner.arena)
		for index in 0 .. 1024 { items << InlineLevelItem{length_in_node:index} }
		assert inner.arena.contains(items.data)
		assert items[1023].length_in_node == 1023
		inner.finish()
		assert outer_items[0].width.to_double() == 47
	}
	assert document.native_storage().arena.usage().used - before < 64 * 1024
	outer.finish()
	assert inline_item_buffer_pool_.depth == 0
	allocations.finish()
	document.finalize()
	document.release_native_storage()
}

fn test_inline_fragments_survive_reused_item_vectors_and_document_teardown() {
	url := dom.URL{value:'https://inline-buffer.example/'}
	mut document := html.create_navigation_document(url, url.origin(), none)!
	document.set_font_rendering_policy(.chromium)
	document.enable_native_storage()
	mut allocations := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><style>
p{width:150px}span{display:inline-block;width:40px}b{float:left;width:30px}
</style><p>Retained wrapped words <span>nested words</span> after nested words
<b>float</b> and bidi אבג text<br>after break.</p>')
	allocations.finish()
	enable_native_paint_tree_storage(document)
	for width in [320, 280, 360, 320] {
		_ = layout_document_typed_in_viewport(document, width, 240)
		$if prealloc { assert inline_item_buffer_pool_.depth == 0 }
		display := document.record_viewport_display_list() or { panic('missing recording') }
		commands := display_list_commands(display)
		assert commands.any(it.text.contains('Retained'))
		assert commands.any(it.text.contains('nested'))
		assert commands.any(it.text.contains('after break'))
	}
	handle := document.layout_engine_handle()
	document.destroy_a_document_and_its_descendants()
	document.finalize()
	retire_native_document_layout(handle)
	document.release_native_storage()
}
