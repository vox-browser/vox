module html

import dom

fn alt_invalidation_fixture() (&dom.Document, &HTMLImageElementModel, &dom.Element, &dom.Element) {
	mut document := parse_document_with_url('<!doctype html><body><img id="image" alt="Fallback"><section id="stable">Unrelated content</section>', dom.URL{ value: 'https://image-alt.test/' })
	image := document.get_element_by_id('image') or { panic('missing image') }
	stable := document.get_element_by_id('stable') or { panic('missing stable element') }
	model := html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(image) })
	return document, model, image, stable
}

fn reset_alt_invalidation_flags(mut document dom.Document, image &dom.Element, stable &dom.Element) {
	document.set_needs_full_layout_tree_update(false)
	mut image_node := image.as_node()
	image_node.set_needs_layout_tree_update(false, .html_image_element_update_the_image_data)
	mut stable_node := stable.as_node()
	stable_node.set_needs_layout_tree_update(false, .html_image_element_update_the_image_data)
}

fn test_creating_alt_text_invalidates_the_image_without_a_full_document_tree_rebuild() {
	mut document, mut model, image, stable := alt_invalidation_fixture()
	defer { document.finalize() }
	model.remove_alt_text_shadow_tree()
	reset_alt_invalidation_flags(mut document, image, stable)
	model.update_alt_text_shadow_tree()
	assert image.shadow_root() != none
	assert model.alt_text_node_?.data() == 'Fallback'
	assert image.as_node().needs_layout_tree_update_()
	assert !stable.as_node().needs_layout_tree_update_()
	assert !document.needs_full_layout_tree_update()
}

fn test_removing_alt_text_invalidates_the_image_without_a_full_document_tree_rebuild() {
	mut document, mut model, image, stable := alt_invalidation_fixture()
	defer { document.finalize() }
	assert image.shadow_root() != none
	reset_alt_invalidation_flags(mut document, image, stable)
	model.remove_alt_text_shadow_tree()
	assert image.shadow_root() == none
	assert model.alt_text_node_ == none
	assert image.as_node().needs_layout_tree_update_()
	assert !stable.as_node().needs_layout_tree_update_()
	assert !document.needs_full_layout_tree_update()
}

fn test_editing_alt_text_invalidates_the_image_without_a_full_document_tree_rebuild() {
	mut document, mut model, image, stable := alt_invalidation_fixture()
	defer { document.finalize() }
	reset_alt_invalidation_flags(mut document, image, stable)
	model.set_alt('Changed fallback')
	model.update_alt_text_shadow_tree()
	assert model.alt_text_node_?.data() == 'Changed fallback'
	assert image.as_node().needs_layout_tree_update_()
	assert !stable.as_node().needs_layout_tree_update_()
	assert !document.needs_full_layout_tree_update()
}
