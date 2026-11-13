// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module main

import dom
import gg

// Precise platform wheels use three legacy wheelDelta units per CSS pixel.
const element_wheel_smoke_markup = '<!doctype html><style>
html,body { margin:0 }
body { height:4000px }
#element-wheel-smoke-scroller { width:240px; height:100px; overflow:auto }
#element-wheel-smoke-video,#element-wheel-smoke-viewport-video { display:block; width:180px; height:60px }
#element-wheel-smoke-content { height:500px }
#element-wheel-smoke-result { position:absolute; top:170px; left:0 }
</style><div id="element-wheel-smoke-scroller"><div id="element-wheel-smoke-video">inner target</div><div id="element-wheel-smoke-content"></div></div>
<div id="element-wheel-smoke-viewport-video">viewport target</div><div id="element-wheel-smoke-result">waiting</div>
<script>
globalThis.elementWheelSmokeSaved=[];globalThis.elementWheelSmokeChecks=[];
globalThis.elementWheelSmokeVideo=document.getElementById("element-wheel-smoke-video");
globalThis.elementWheelSmokeViewportVideo=document.getElementById("element-wheel-smoke-viewport-video");
for(const player of [elementWheelSmokeVideo,elementWheelSmokeViewportVideo]){
 player.addEventListener("wheel",function(event){
  elementWheelSmokeSaved.push(event);
  elementWheelSmokeChecks.push(this===player&&arguments.length===1&&event.target===player&&event.currentTarget===player&&event instanceof WheelEvent&&Object.getPrototypeOf(event)===WheelEvent.prototype&&event.isTrusted&&event.bubbles&&event.cancelable&&event.composed&&event.view===window&&event.type==="wheel"&&event.deltaX===0&&event.deltaY===42&&event.deltaZ===0&&event.deltaMode===WheelEvent.DOM_DELTA_PIXEL&&event.wheelDeltaY===-126&&event.button===0&&event.buttons===0&&window.event===event);
  const cancelled=elementWheelSmokeSaved.length===1;
  document.getElementById("element-wheel-smoke-result").textContent=cancelled?"cancelled":"accepted";
  if(cancelled)event.preventDefault();
  return false;
 },{passive:false});
}
</script>'

// The non-windowed signed-browser smoke invokes the real GG embedding entry.
// It does not post an operating-system event or use script dispatchEvent().
fn (mut app BrowserApp) run_element_wheel_smoke() ! {
	app.layout_tree_only = false
	app.platform_pointer_buttons = 0
	app.install_loaded_page(LoadedPage{
		url:          'about:element-wheel-smoke'
		markup:       element_wheel_smoke_markup
		status:       'Loaded element wheel smoke'
		content_type: 'text/html'
	}, false)
	if app.document == unsafe { nil } || app.js_runtime == unsafe { nil } {
		return error('element wheel smoke: parsed document or JavaScript owner missing')
	}
	if app.js_messages.len != 0 {
		return error('element wheel smoke: fixture script failed: ${app.js_messages.join('; ')}')
	}
	scroller := app.document.get_element_by_id('element-wheel-smoke-scroller') or {
		return error('element wheel smoke: overflow element missing')
	}
	result := app.document.get_element_by_id('element-wheel-smoke-result') or {
		return error('element wheel smoke: mutation result element missing')
	}
	for index in 0 .. 3 {
		client_y := if index == 2 { f32(124.25) } else { f32(12.25) }
		app.handle_event(&gg.Event{
			typ:           .mouse_scroll
			mouse_x:       24.5
			mouse_y:       client_y + app.page_top()
			scroll_y:      -1
			window_height: app.viewport_height + app.chrome_height()
		})
		if app.js_runtime.evaluate_host('elementWheelSmokeSaved.length===${index + 1}&&elementWheelSmokeChecks.every(Boolean)&&elementWheelSmokeSaved.every(event=>event.currentTarget===null&&event.eventPhase===Event.NONE)&&window.event===undefined')! != 'true' {
			return error('element wheel smoke: native event ownership or payload failed at input ${
				index + 1}')
		}
		wrapper := app.js_runtime.evaluate_host_value('elementWheelSmokeSaved[${index}]')!
		event := app.js_runtime.native_event(wrapper)!
		if event.interface_ != .wheel_event || !event.is_trusted()
			|| app.js_runtime.javascript_event(event)! != wrapper {
			return error('element wheel smoke: retained wrapper lost its native WheelEvent at input ${
				index + 1}')
		}
		wheel := unsafe { &dom.WheelEvent(event) }
		if wheel.delta_x() != 0 || wheel.delta_y() != 42
			|| wheel.delta_mode() != dom.dom_delta_pixel || wheel.wheel_delta_y() != -126
			|| event.default_prevented() != (index == 0) {
			return error('element wheel smoke: GG delta conversion or cancellation failed at input ${
				index + 1}')
		}
		expected_text := if index == 0 { 'cancelled' } else { 'accepted' }
		if (result.as_node().text_content() or { '' }) != expected_text
			|| !app.document.layout_is_up_to_date()
			|| app.paint_commands.filter(it.kind == 'draw_text'
			&& it.text == expected_text).len == 0 {
			return error('element wheel smoke: callback mutation did not reach live DOM and paint at input ${
				index + 1}')
		}
		expected_inner := if index == 0 { f64(0) } else { f64(42) }
		expected_viewport := if index == 2 { f64(42) } else { f64(0) }
		if scroller.el_scroll_offset().y() != expected_inner || app.scroll_y != expected_viewport {
			return error('element wheel smoke: default scrolling order failed at input ${index + 1}: inner=${scroller.el_scroll_offset().y()}, viewport=${app.scroll_y}')
		}
	}
	if app.js_messages.len != 0 {
		return error('element wheel smoke: callback errors: ${app.js_messages.join('; ')}')
	}
}
