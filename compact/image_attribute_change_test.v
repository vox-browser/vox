module main

import browserjs
import dom
import html
import layout

fn image_attribute_change_fixture() !(&dom.Document, &browserjs.Runtime, &html.HTMLImageElementModel) {
	url := dom.URL{ value: 'https://image-attributes.test/' }
	mut document := html.parse_navigation_document('<!doctype html><style>html,body{margin:0}img{width:1px;height:1px}</style><img id="photo" srcset="">',
		url, url.origin(), none)!
	document.set_viewport_rect(dom.Rect{ width: 80, height: 60 })
	mut runtime := browserjs.Runtime.create()
	mut messages := []string{}
	// Bind the native image before installing the controlled fetch hook.
	run_document_javascript(document, url.serialize(), [r'
globalThis.photo=document.getElementById("photo");
globalThis.imageSourceAttribute=photo.getAttributeNode("srcset");
if(photo.currentSrc!=="")throw new Error("unexpected initial source");
'], runtime, mut messages)
	assert messages == []string{}, messages.join('\n')
	mut element := document.get_element_by_id('photo') or { return error('missing image') }
	mut model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
	model.set_fetch_hook(fn (resource dom.URL) !html.DecodedImageData {
		pixels := if resource.serialize().contains('green') {
			[u8(0), 255, 0, 255]
		} else {
			[u8(255), 0, 0, 255]
		}
		bitmap := &dom.Bitmap_{ width: 1, height: 1, pitch: 4, data: pixels }
		return html.BitmapDecodedImageData.create([
			html.BitmapDecodedImageFrame{ frame: dom.DecodedImageFrame_.create(bitmap) },
		], 0, false)
	})
	element.set_attribute_value('src', '/red-fallback.png')
	element.set_attribute_value('srcset', '/red.png 1x')
	model.update_the_image_data(false, false)
	assert model.current_src() == 'https://image-attributes.test/red.png'
	frame := model.current_image_frame() or { return error('missing initial image frame') }
	assert frame.bitmap().data[..4] == [u8(255), 0, 0, 255]
	return document, runtime, model
}

fn test_image_srcset_attr_and_element_writes_replace_same_size_pixels_and_invalidate_paint() {
	mut document, mut runtime, model := image_attribute_change_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	element := document.get_element_by_id('photo')?
	for index, write in [
		'imageSourceAttribute.value=value',
		'imageSourceAttribute.nodeValue=value',
		'imageSourceAttribute.textContent=value',
		'photo.setAttribute("srcset",value)',
		'photo.setAttributeNS(null,"srcset",value)',
	] {
		_ = layout.run_document_layout(document, 80, 60)?
		_ = document.record_display_list()?
		assert document.cached_display_list() != none
		candidate := '/green-${index}.png'
		value := '${candidate} 1x'
		_ = runtime.evaluate_host('(()=>{const value="${value}";${write};})()')!
		assert element.get_attribute_value('srcset') == value
		assert model.current_src() == 'https://image-attributes.test${candidate}'
		assert model.natural_width() == 1 && model.natural_height() == 1
		assert model.current_image_frame()?.bitmap().data[..4] == [u8(0), 255, 0, 255]
		assert document.cached_display_list() == none
	}
}

fn test_namespaced_srcset_writes_leave_the_html_image_selection_unchanged() {
	mut document, mut runtime, model := image_attribute_change_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	_ = runtime.evaluate_host('photo.setAttributeNS("urn:image-test","test:srcset","/green-foreign.png 1x")')!
	element := document.get_element_by_id('photo')?
	assert element.get_attribute_ns('urn:image-test', 'srcset')? == '/green-foreign.png 1x'
	assert element.get_attribute_value('srcset') == '/red.png 1x'
	assert model.current_src() == 'https://image-attributes.test/red.png'
	assert model.current_image_frame()?.bitmap().data[..4] == [u8(255), 0, 0, 255]
}
