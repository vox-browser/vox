module layout

import dom
import html
import math
import page

struct NativePointerGeometry {
mut:
	client_x   f64
	page_x     f64
	offset_x   f64
	offset_y   f64
	movement_x f64
	screen_x   f64
}

fn test_platform_pointer_offsets_use_the_committed_inverse_css_transform() {
	document := html.parse_document('<!doctype html><style>html,body{margin:0}#target{position:absolute;left:20px;top:10px;width:30px;height:30px;transform:scale(2);transform-origin:0 0}</style><div id="target"></div>')
	_ = layout_document_typed_in_viewport(document, 200, 100)
	target := document.get_element_by_id('target') or { panic('missing target') }
	state := &NativePointerGeometry{}
	callback := &dom.CallbackType{
		handle_event: fn [state] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mouse := unsafe { &dom.MouseEvent(event) }
			mut observed := unsafe { &NativePointerGeometry(state) }
			observed.client_x = mouse.client_x()
			observed.page_x = mouse.page_x()
			observed.offset_x = mouse.offset_x()
			observed.offset_y = mouse.offset_y()
			observed.screen_x = mouse.screen_x()
			observed.movement_x = mouse.movement_x()
			return dom.js_undefined()
		}
	}
	mut event_target := unsafe { &dom.EventTarget(target.as_node()) }
	event_target.add_event_listener_without_options('mousemove', dom.IDLEventListener.create(callback))
	mut handler := page.EventHandler{}
	input_target := page.InputTarget.from_node(target.as_node())
	assert handler.handle_platform_pointer_event('pointermove', input_target, page.PixelPoint{30, 20}, page.PixelPoint{130, 220}, 0, 0, 0, 0) == .handled
	assert math.abs(state.offset_x - 5) < 0.02
	assert math.abs(state.offset_y - 5) < 0.02
	assert state.client_x == 30
	assert state.page_x == 30
	assert state.screen_x == 130
	assert state.movement_x == 0
	assert handler.handle_platform_pointer_event('pointermove', input_target, page.PixelPoint{34, 20}, page.PixelPoint{134, 220}, 0, 0, 0, 0) == .handled
	assert state.movement_x == 4
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_viewport_rect(dom.Rect{8, 0, 200, 100})
	assert handler.handle_platform_pointer_event('pointermove', input_target, page.PixelPoint{26, 20}, page.PixelPoint{126, 220}, 0, 0, 0, 0) == .handled
	assert state.client_x == 26
	assert state.page_x == 34
	assert math.abs(state.offset_x - 7) < 0.02
}
