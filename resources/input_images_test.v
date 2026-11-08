module main

import browserjs
import dom
import encoding.base64
import html
import layout

fn input_image_test_svg(width int, height int) string {
	return 'data:image/svg+xml;base64,' + base64.encode('<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}"><rect width="10" height="10" fill="green"/></svg>'.bytes())
}

fn test_native_image_input_uses_decoded_svg_size_and_full_hit_region() {
	source := input_image_test_svg(200, 200)
	mut document := html.parse_document('<!doctype html><form><input id="image" type="image" src="${source}"></form>')
	defer { document.finalize() }
	document.set_viewport_rect(dom.Rect{ width: 800, height: 600 })
	install_static_browser_image_fetch_hooks(document, {})
	element := document.get_element_by_id('image')?
	model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
	assert model.is_image_available()
	assert model.width() == 200 && model.height() == 200
	mut app := BrowserApp{ document: document }
	app.relayout(800, 712)
	rect := element.get_bounding_client_rect()
	assert rect.x == 8 && rect.y == 8
	assert rect.width == 200 && rect.height == 200
	assert app.paint_commands.any(it.kind == 'paint_nested_display_list')
	for offset in [5, 100, 199] {
		hit := document.element_from_point(rect.x + offset, rect.y + offset)?
		assert voidptr(hit) == voidptr(element)
	}
	loads := model.event_count('load')
	install_static_browser_image_fetch_hooks(document, {})
	assert model.event_count('load') == loads
	// Relayout keeps the decoded provider even without an encoded cache entry.
	mut image_box := unsafe { &layout.ImageBox(element.as_node().unsafe_layout_node()?.real_layout_handle()) }
	image_box.reset_for_relayout()
	assert image_box.svg_image_document() != none
	assert image_box.natural_size().width?.to_double() / document.layout_coordinate_scale() == 200
	mut styled := unsafe { &dom.Element(element) }
	apply_javascript_element_attribute(mut styled, 'style', 'width:60px;height:40px;border:3px solid;padding:5px')
	assert model.width() == 60 && model.height() == 40
	apply_javascript_element_attribute(mut styled, 'style', 'display:none')
	assert model.width() == 200 && model.height() == 200
	apply_javascript_element_attribute(mut styled, 'width', '12')
	apply_javascript_element_attribute(mut styled, 'height', '13')
	assert model.width() == 12 && model.height() == 13
}

fn test_script_created_image_inputs_load_and_relayout_after_source_and_type_changes() {
	mut document := html.parse_document('<!doctype html><input id="existing" type="text"><body></body>')
	document.set_viewport_rect(dom.Rect{ width: 800, height: 600 })
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	wide := input_image_test_svg(120, 80)
	tall := input_image_test_svg(40, 90)
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		'const wide="${wide}",tall="${tall}";' + r'
function check(input,w,h){const r=input.getBoundingClientRect();if(r.width!==w||r.height!==h||input.width!==w||input.height!==h)throw new Error("image dimensions "+JSON.stringify([r.width,r.height,input.width,input.height]));}
existing.src=wide;existing.type="image";check(existing,120,80);
const made=document.createElement("input");made.type="image";made.src=tall;document.body.appendChild(made);check(made,40,90);
made.src=wide;check(made,120,80);made.src=tall;check(made,40,90);
console.log("image input resources passed");',
	], runtime, mut messages)
	assert messages == ['image input resources passed']
}

fn test_native_image_input_uses_decoded_raster_pixels_and_size() {
	mut document := html.parse_document('<!doctype html><input id="image" type="image" src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=">')
	defer { document.finalize() }
	install_static_browser_image_fetch_hooks(document, {})
	model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(document.get_element_by_id('image')?) })
	assert model.is_image_available()
	assert model.intrinsic_width()? == 1 && model.intrinsic_height()? == 1
	mut app := BrowserApp{ document: document }
	app.relayout(800, 712)
	rect := document.get_element_by_id('image')?.get_bounding_client_rect()
	assert rect.width == 1 && rect.height == 1
	assert app.paint_commands.any(it.replaced_image_bitmap != none)
}
