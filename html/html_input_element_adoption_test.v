module html

import dom

struct InputImageAdoptionContext {
	old_document &dom.Document
	new_document &dom.Document
	element      &dom.Element
}

fn input_image_adoption_fetch(context &InputImageAdoptionContext, _ dom.URL) !DecodedImageData {
	assert context.old_document.anything_is_delaying_the_load_event()
	assert !context.new_document.anything_is_delaying_the_load_event()
	mut new_document := unsafe { &dom.Document(context.new_document) }
	new_document.adopt_node(context.element.as_node())
	assert !context.old_document.anything_is_delaying_the_load_event()
	assert context.new_document.anything_is_delaying_the_load_event()
	bitmap := &dom.Bitmap_{
		width: 1
		height: 1
		pitch: 4
		data: [u8(0), 0, 0, 255]
	}
	return BitmapDecodedImageData.create([
		BitmapDecodedImageFrame{ frame: dom.DecodedImageFrame_.create(bitmap) },
	], 0, false)
}

fn test_image_input_adoption_transfers_in_flight_load_event_delay() {
	mut old_document := dom.Document.create(dom.URL{ value: 'https://old.example/' })
	mut new_document := dom.Document.create(dom.URL{ value: 'https://new.example/' })
	mut input_element := old_document.create_element_ns(dom.namespace_html_uri, 'input')!
	input_element.set_attribute_value('type', 'image')
	input := unsafe { &dom.HTMLInputElement(input_element) }
	mut model := HTMLInputElementModel.create(input)
	context := &InputImageAdoptionContext{
		old_document: old_document
		new_document: new_document
		element: input_element
	}
	model.set_image_fetch_hook(fn [context] (url dom.URL) !DecodedImageData {
		return input_image_adoption_fetch(context, url)
	})

	model.handle_src_attribute('/submit.png')!
	assert voidptr(input_element.document()) == voidptr(new_document)
	assert model.event_count('load') == 1
	assert !old_document.anything_is_delaying_the_load_event()
	assert !new_document.anything_is_delaying_the_load_event()
}
