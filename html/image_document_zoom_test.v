// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause

module html

import css
import dom
import page

// Ladybird 0a4c6a58ea6fa80924e0b1c08f8080b9707ee03c.
fn test_standalone_image_tracks_page_zoom_at_fixed_viewport_size_and_stops_after_adoption() {
	mut document := dom.Document.create(dom.URL{value: 'https://image.test/picture.png'})
	defer { document.finalize() }
	document.set_document_type(.html)
	model_page := page.Page.create(2)!
	document.set_page(&model_page.Page)
	document.populate_with_html_head_and_body()!
	mut element := document.create_element('img')!
	mut image := unsafe { &dom.HTMLImageElement(element) }
	image.is_image_document_image_ = true
	mut model := html_image_element_model_for_dom_element(image)
	style := css.inline_style(element)
	assert style.get_property_value('max-width') == '100vw'
	assert style.get_property_value('max-height') == '100vh'
	viewport := dom.Rect{width: 400, height: 300}
	model.did_set_viewport_rect(viewport)
	mut client := model_page.client()
	client.zoom_level_ = 2
	model.did_set_viewport_rect(viewport)
	assert style.get_property_value('max-width') == '200vw'
	assert style.get_property_value('max-height') == '200vh'
	client.zoom_level_ = 0.5
	model.did_set_viewport_rect(viewport)
	assert style.get_property_value('max-width') == '50vw'
	mut new_document := dom.Document.create(dom.URL{value: 'https://image.test/other'})
	defer { new_document.finalize() }
	new_document.adopt_node(element.as_node())
	assert model.image_document_zoom_level_ == none
	assert !image.is_image_document_image_
	model.did_set_viewport_rect(dom.Rect{width: 800, height: 600})
	assert style.get_property_value('max-width') == '50vw'
}
