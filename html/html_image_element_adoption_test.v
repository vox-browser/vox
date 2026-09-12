module html

import dom

fn test_image_adoption_retargets_lifecycle_and_load_delay() {
	mut old_document := dom.Document.create(dom.URL{ value: 'https://old.example/' })
	mut new_document := dom.Document.create(dom.URL{ value: 'https://new.example/' })
	image_element := old_document.create_element_ns(dom.namespace_html_uri, 'img')!
	image := unsafe { &dom.HTMLImageElement(image_element) }
	mut model := unsafe {
		&HTMLImageElementModel(html_image_element_model_for_dom_element(image))
	}

	model.begin_delaying_document_load_event()
	assert old_document.anything_is_delaying_the_load_event()
	new_document.adopt_node(image_element.as_node())
	assert voidptr(model.document_) == voidptr(new_document)
	assert model.base_url_.serialize() == 'https://new.example/'
	assert !old_document.anything_is_delaying_the_load_event()
	assert new_document.anything_is_delaying_the_load_event()

	model.last_seen_viewport_size_ = [f64(0), 0]!
	old_document.set_viewport_rect(dom.Rect{0, 0, 320, 240})
	old_document.inform_all_viewport_clients_about_the_current_viewport_rect()
	assert model.last_seen_viewport_size_ == [f64(0), 0]!
	new_document.set_viewport_rect(dom.Rect{0, 0, 640, 480})
	new_document.inform_all_viewport_clients_about_the_current_viewport_rect()
	assert model.last_seen_viewport_size_ == [f64(640), 480]!

	model.stop_delaying_document_load_event()
	assert !new_document.anything_is_delaying_the_load_event()
}

fn test_eager_image_fetch_delays_load_event_until_completion() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	mut image := HTMLImageElementModel.create(document, document.base_url())
	image.set_src('/image.png')
	image.set_fetch_hook(fn [document] (_ dom.URL) !DecodedImageData {
		assert document.anything_is_delaying_the_load_event()
		bitmap := &dom.ImmutableBitmap_{
			width: 1
			height: 1
			pitch: 4
			data: [u8(0), 0, 0, 255]
		}
		return BitmapDecodedImageData.create([
			BitmapDecodedImageFrame{ bitmap: bitmap },
		], 0, false)
	})

	image.update_the_image_data(false, false)
	assert image.complete()
	assert !document.anything_is_delaying_the_load_event()
}
