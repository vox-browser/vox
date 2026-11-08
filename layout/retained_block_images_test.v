module layout

import dom
import html
import platform

fn retained_image_handle(document &dom.Document, id string) &Node {
 element := document.get_element_by_id(id) or { panic('missing '+id) }
 return unsafe { &Node(element.as_node().unsafe_layout_node() or { panic('missing layout') }.real_layout_handle()) }
}

fn retained_image_assert_full_layout(mut document dom.Document) {
 before := (document.record_display_list() or { panic('missing paint') }).dump()
 document.set_needs_full_layout_tree_update(true)
 document.update_layout(.debugging)
 assert (document.record_display_list() or { panic('missing rebuilt paint') }).dump() == before
}


fn retained_image_pixels(width int, height int, value u8) html.DecodedImageData {
	return html.BitmapDecodedImageData.create([html.BitmapDecodedImageFrame{
		frame: dom.DecodedImageFrame_.create(&dom.Bitmap_{
			width: width
			height: height
			pitch: width * 4
			data: []u8{len:width * height * 4,init:value}
			native_resource_replay_compatible: true
		})
	}], 0, false)
}

fn retained_image_fixture() (&dom.Document, &html.HTMLImageElementModel) {
	address := dom.URL{value:'https://retained-images.example/'}
	mut document := html.parse_navigation_document('<!doctype html><div id="changed"></div><section id="stable" style="overflow:hidden;width:180px"><img id="photo" src="a.png" style="display:block;width:100%"><p>Several unchanged words below the image.</p></section>', address, address.origin(), none) or { panic(err) }
	element := document.get_element_by_id('photo') or { panic('missing photo') }
	mut image := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
	image.set_fetch_hook(fn (_ dom.URL) !html.DecodedImageData { return retained_image_pixels(8,6,255) })
	image.update_the_image_data(false, false)
	assert image.complete()
	_ = layout_document_typed_in_viewport(document, 400, 400)
	return document, image
}

fn test_decoded_image_block_layout_survives_an_external_change_and_retains_old_paint() {
	mut document, _ := retained_image_fixture()
	defer { document.finalize() }
	root := retained_image_handle(document, 'stable')
	before := document_layout_result(document) or { panic('missing layout') }
	cache := before.state.block_layouts_[u64(voidptr(root))] or { panic('missing image block cache') }
	old := document.record_display_list() or { panic('missing paint') }
	old_scene := retain_display_list_scene(old)
	defer { release_display_list_scene(old_scene) }
	old_dump := old.dump()
	old_y := document.get_element_by_id('photo')?.get_bounding_client_rect().y
	mut changed := document.get_element_by_id('changed')?
	changed.set_attribute_value('style', 'height:50px')
	document.update_layout(.debugging)
	after := document_layout_result(document) or { panic('missing new layout') }
	assert voidptr(after.state.block_layouts_[u64(voidptr(root))] or { panic('missing retained block') }) == voidptr(cache)
	assert document.get_element_by_id('photo')?.get_bounding_client_rect().y == old_y + 50
	assert old.dump() == old_dump
	retained_image_assert_full_layout(mut document)
}

fn test_retained_image_geometry_expires_after_source_and_intrinsic_size_changes() {
	mut document, mut image := retained_image_fixture()
	defer { document.finalize() }
	root := retained_image_handle(document, 'stable')
	before := document_layout_result(document) or { panic('missing layout') }
	cache := before.state.block_layouts_[u64(voidptr(root))] or { panic('missing image block cache') }
	old_height := document.get_element_by_id('photo')?.get_bounding_client_rect().height
	image.set_fetch_hook(fn (_ dom.URL) !html.DecodedImageData { return retained_image_pixels(8,12,128) })
	mut element := document.get_element_by_id('photo')?
	element.set_attribute_value('src', 'taller.png')
	image.update_the_image_data(false, false)
	assert !retained_inline_inputs_are_current(cache.inputs)
	document.update_layout(.debugging)
	assert element.get_bounding_client_rect().height == old_height * 2
	retained_image_assert_full_layout(mut document)
}

fn test_same_size_image_replacement_paints_current_pixels_without_mutating_old_commands() {
	mut document, mut image := retained_image_fixture()
	defer { document.finalize() }
	old := document.record_display_list() or { panic('missing paint') }
	old_scene := retain_display_list_scene(old)
	defer { release_display_list_scene(old_scene) }
	old_commands := display_list_commands(old).filter(it.kind == 'draw_replaced_image')
	assert old_commands.len == 1
	old_bitmap := old_commands[0].replaced_image_bitmap or { panic('missing pixels') }
	image.set_fetch_hook(fn (_ dom.URL) !html.DecodedImageData { return retained_image_pixels(8,6,128) })
	mut element := document.get_element_by_id('photo')?
	element.set_attribute_value('src', 'new-pixels.png')
	image.update_the_image_data(false, false)
	document.update_layout(.debugging)
	commands := display_list_commands(document.record_display_list() or { panic('missing replacement paint') }).filter(it.kind == 'draw_replaced_image')
	assert commands.len == 1
	bitmap := commands[0].replaced_image_bitmap or { panic('missing new pixels') }
	assert bitmap.data[0] == 128 && old_bitmap.data[0] == 255
	retained_image_assert_full_layout(mut document)
}

fn test_unavailable_images_and_other_replaced_elements_reject_block_retention() {
	for contents in ['<img src="missing.png">','<canvas width="20" height="20"></canvas>',
		'<video width="20" height="20"></video>','<input value="text">'] {
		mut document := html.parse_document('<!doctype html><section id="stable" style="overflow:hidden;width:180px">${contents}<p>Following text.</p></section>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 400)
		root := retained_image_handle(document, 'stable')
		assert u64(voidptr(root)) !in (document_layout_result(document) or { panic('missing layout') }).state.block_layouts_
	}
}

fn test_retained_image_snapshot_owns_its_record_and_source_outside_geometry_scratch() {
	$if prealloc {
		mut document, image := retained_image_fixture()
		defer { document.finalize() }
		document.enable_native_storage()
		mut storage := document.enter_native_storage()
		defer { storage.finish() }
		owner := platform.current_retained_arena()
		node := retained_image_handle(document, 'photo')
		expected := image.current_src().clone()
		mut geometry := begin_document_geometry_scratch(document)
		snapshot := retained_block_image_snapshot(node)?
		assert owner.arena.contains(voidptr(snapshot))
		assert owner.arena.contains(snapshot.source.str)
		geometry.finish()
		assert snapshot.source == expected
	}
}
