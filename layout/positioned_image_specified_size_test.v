module layout

import dom
import html

fn specified_image_document(style string) &dom.Document {
	address := dom.URL{value:'https://specified-image.example.test/'}
	return html.parse_navigation_document('<!doctype html><style>html,body{margin:0}
		#parent{position:relative;width:160px;height:120px}#image{${style}}</style>
		<div id="parent"><img id="image" src="https://thumbs.example/first.png"></div>
		<div>following content</div>', address, address.origin(), none) or { panic(err) }
}

fn specified_image_data(width int, height int) html.DecodedImageData {
	return html.BitmapDecodedImageData.create([html.BitmapDecodedImageFrame{
		frame:dom.DecodedImageFrame_.create(&dom.Bitmap_{
			width:width
			height:height
			pitch:width*4
			data:[]u8{len:width*height*4,init:255}
			native_resource_replay_compatible:true
		})
	}],0,false)
}

fn specified_image_complete(document &dom.Document, width int, height int) &html.HTMLImageElementModel {
	element := document.get_element_by_id('image') or { panic('image') }
	mut model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
	model.set_fetch_hook(fn [width,height] (_ dom.URL) !html.DecodedImageData {
		return specified_image_data(width,height)
	})
	model.update_the_image_data(false,false)
	return model
}

fn specified_image_assert_full_rebuild(mut document dom.Document) {
	document.update_layout(.debugging)
	actual := (document.record_display_list() or { panic('display list') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('rebuilt display list') }).dump() == actual
}

fn test_positioned_image_first_completion_preserves_author_ratio_geometry() {
	for sizing in ['','box-sizing:border-box;border:2px solid;padding:4px;min-height:70px;max-height:100px;'] {
		mut document := specified_image_document('position:absolute;width:100%;height:auto;aspect-ratio:2/1;object-fit:cover;${sizing}')
		defer { document.finalize() }
		layout_document_typed_in_viewport(document,200,180)
		before := document_layout_result(document) or { panic('initial layout') }
		old := before.paint_tree.paint_commands().filter(it.kind=='draw_replaced_image')
		specified_image_complete(document,8,6)
		assert document.layout_is_up_to_date() == (!retain_positioned_image_load_layout && !disable_positioned_image_ratio_reuse)
		if document.layout_is_up_to_date() {
			current := document_layout_result(document) or { panic('current layout') }
			assert voidptr(before)==voidptr(current)
		}
		specified_image_assert_full_rebuild(mut document)
		if old.len>0 { assert old[0].replaced_image_bitmap==none }
	}
}

fn test_positioned_image_definite_percentage_axes_do_not_need_a_previous_natural_ratio() {
	mut document := specified_image_document('position:absolute;width:100%;height:100%;object-fit:contain')
	defer { document.finalize() }
	layout_document_typed_in_viewport(document,200,180)
	specified_image_complete(document,8,6)
	assert document.layout_is_up_to_date() == (!retain_positioned_image_load_layout && !disable_positioned_image_ratio_reuse)
	specified_image_assert_full_rebuild(mut document)
}

fn test_positioned_image_author_ratio_keeps_replacement_pixels_and_prior_commands_independent() {
	mut document := specified_image_document('position:absolute;width:100%;height:auto;aspect-ratio:2/1;object-fit:contain')
	defer { document.finalize() }
	specified_image_complete(document,8,6)
	layout_document_typed_in_viewport(document,200,180)
	before := document_layout_result(document) or { panic('layout') }
	old := before.paint_tree.paint_commands().filter(it.kind=='draw_replaced_image')
	assert old.len==1
	old_bitmap := old[0].replaced_image_bitmap or { panic('old bitmap') }
	assert old_bitmap.width==8 && old_bitmap.height==6
	mut element := document.get_element_by_id('image') or { panic('image') }
	element.set_attribute_value('src','https://thumbs.example/second.png')
	specified_image_complete(document,20,20)
	assert document.layout_is_up_to_date() == (!retain_positioned_image_load_layout && !disable_positioned_image_ratio_reuse)
	document.update_layout(.debugging)
	current := (document_layout_result(document) or { panic('current layout') }).paint_tree.paint_commands().filter(it.kind=='draw_replaced_image')
	assert current.len==1
	bitmap := current[0].replaced_image_bitmap or { panic('replacement bitmap') }
	assert bitmap.width==20 && bitmap.height==20
	assert voidptr(bitmap)!=voidptr(old_bitmap)
	assert old_bitmap.width==8 && old_bitmap.height==6
	assert old[0].image().image_url=='https://thumbs.example/first.png'
	specified_image_assert_full_rebuild(mut document)
}

fn test_positioned_image_specified_geometry_rejects_intrinsic_and_auto_ratio_dependencies() {
	for style in ['position:absolute;width:100%;height:auto;aspect-ratio:auto 2/1',
		'position:relative;width:100%;height:auto;aspect-ratio:2/1',
		'position:absolute;width:auto;height:auto;aspect-ratio:2/1',
		'position:absolute;width:100%;height:auto;aspect-ratio:2/1;max-width:max-content',
		'position:absolute;width:100%;height:auto;aspect-ratio:2/1;min-height:min-content',
		'position:absolute;width:100%;height:auto;aspect-ratio:2/1;writing-mode:vertical-rl'] {
		mut document := specified_image_document(style)
		defer { document.finalize() }
		layout_document_typed_in_viewport(document,200,180)
		specified_image_complete(document,8,6)
		assert !document.layout_is_up_to_date(),style
		specified_image_assert_full_rebuild(mut document)
	}
}

fn test_positioned_image_specified_geometry_preserves_pending_style_and_containing_size_changes() {
	for change in ['source','parent'] {
		mut document := specified_image_document('position:absolute;width:100%;height:auto;aspect-ratio:2/1}#image[src$="second.png"]{width:80px')
		defer { document.finalize() }
		specified_image_complete(document,8,6)
		layout_document_typed_in_viewport(document,200,180)
		if change=='source' {
			mut image := document.get_element_by_id('image') or { panic('image') }
			image.set_attribute_value('src','https://thumbs.example/second.png')
		} else {
			mut parent := document.get_element_by_id('parent') or { panic('parent') }
			parent.set_attribute_value('style','width:80px')
		}
		specified_image_complete(document,20,20)
		document.update_style()
		assert !document.layout_is_up_to_date()
		specified_image_assert_full_rebuild(mut document)
	}
}
