module html

import dom

fn source_picture_test_document() &dom.Document {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	mut navigable := &dom.Navigable{
		active_document_: document
		is_top_level_traversable_: true
	}
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)
	return document
}

fn source_picture_test_element(document &dom.Document, name string) &dom.Element {
	return document.create_element_ns('http://www.w3.org/1999/xhtml', name) or { panic(err) }
}

fn test_source_insertion_updates_each_picture_image() {
	document := source_picture_test_document()
	mut picture := source_picture_test_element(document, 'picture')
	source_element := source_picture_test_element(document, 'source')
	first_image_element := source_picture_test_element(document, 'img')
	second_image_element := source_picture_test_element(document, 'img')
	mut picture_node := picture.as_node()
	picture_node.append_child(source_element.as_node())!
	picture_node.append_child(first_image_element.as_node())!
	picture_node.append_child(second_image_element.as_node())!

	first_image := html_image_element_model_for_dom_element(unsafe {
		&dom.HTMLImageElement(first_image_element)
	})
	second_image := html_image_element_model_for_dom_element(unsafe {
		&dom.HTMLImageElement(second_image_element)
	})
	assert first_image.update_count_ == 0
	assert second_image.update_count_ == 0

	html_source_element_inserted(unsafe { &dom.HTMLSourceElement(source_element) })
	assert first_image.update_count_ == 1
	assert second_image.update_count_ == 1
}

fn test_source_attribute_change_updates_only_following_picture_images() {
	document := source_picture_test_document()
	mut picture := source_picture_test_element(document, 'picture')
	preceding_image_element := source_picture_test_element(document, 'img')
	source_element := source_picture_test_element(document, 'source')
	following_image_element := source_picture_test_element(document, 'img')
	mut picture_node := picture.as_node()
	picture_node.append_child(preceding_image_element.as_node())!
	picture_node.append_child(source_element.as_node())!
	picture_node.append_child(following_image_element.as_node())!

	preceding_image := html_image_element_model_for_dom_element(unsafe {
		&dom.HTMLImageElement(preceding_image_element)
	})
	following_image := html_image_element_model_for_dom_element(unsafe {
		&dom.HTMLImageElement(following_image_element)
	})
	source := unsafe { &dom.HTMLSourceElement(source_element) }
	html_source_element_attribute_changed(source, 'srcset', none, '/candidate.png 1x', none)
	assert preceding_image.update_count_ == 0
	assert following_image.update_count_ == 1

	html_source_element_attribute_changed(source, 'id', none, 'unrelated', none)
	assert preceding_image.update_count_ == 0
	assert following_image.update_count_ == 1
}

fn test_source_move_and_removal_update_old_and_new_picture_images() {
	document := source_picture_test_document()
	mut old_picture := source_picture_test_element(document, 'picture')
	mut new_picture := source_picture_test_element(document, 'picture')
	source_element := source_picture_test_element(document, 'source')
	old_image_element := source_picture_test_element(document, 'img')
	new_image_element := source_picture_test_element(document, 'img')
	mut old_picture_node := old_picture.as_node()
	old_picture_node.append_child(source_element.as_node())!
	old_picture_node.append_child(old_image_element.as_node())!
	mut new_picture_node := new_picture.as_node()
	new_picture_node.append_child(new_image_element.as_node())!

	old_image := html_image_element_model_for_dom_element(unsafe {
		&dom.HTMLImageElement(old_image_element)
	})
	new_image := html_image_element_model_for_dom_element(unsafe {
		&dom.HTMLImageElement(new_image_element)
	})
	source := unsafe { &dom.HTMLSourceElement(source_element) }
	new_picture_node.append_child(source_element.as_node())!
	html_source_element_moved_from(source, old_picture_node)
	assert old_image.update_count_ == 1
	assert new_image.update_count_ == 1

	mut source_node := source_element.as_node()
	source_node.remove(false)
	html_source_element_removed_from(source, new_picture_node, new_picture_node)
	assert old_image.update_count_ == 1
	assert new_image.update_count_ == 2
}
