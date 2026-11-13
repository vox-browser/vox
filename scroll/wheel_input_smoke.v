// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module main

import dom
import gg

// Precise platform wheels use three legacy wheelDelta units per CSS pixel.
const wheel_input_smoke_markup = '<!doctype html><style>
html,body { margin:0 }
body { height:4000px }
#wheel-smoke-scroller { width:240px; height:100px; overflow:auto }
video { display:block; width:180px; height:60px }
#wheel-smoke-content { height:500px }
#wheel-smoke-result { position:absolute; top:170px; left:0 }
</style><div id="wheel-smoke-scroller"><video id="wheel-smoke-video"></video><div id="wheel-smoke-content"></div></div>
<video id="wheel-smoke-viewport-video"></video><div id="wheel-smoke-result">waiting</div>
<script>
globalThis.wheelSmokeSaved=[];globalThis.wheelSmokeChecks=[];
globalThis.wheelSmokeVideo=document.getElementById("wheel-smoke-video");
globalThis.wheelSmokeViewportVideo=document.getElementById("wheel-smoke-viewport-video");
for(const player of [wheelSmokeVideo,wheelSmokeViewportVideo]){
 player.onwheel=function(event){
  wheelSmokeSaved.push(event);
  wheelSmokeChecks.push(this===player&&arguments.length===1&&event.target===player&&event.currentTarget===player&&event instanceof WheelEvent&&Object.getPrototypeOf(event)===WheelEvent.prototype&&event.isTrusted&&event.bubbles&&event.cancelable&&event.composed&&event.view===window&&event.type==="wheel"&&event.deltaX===0&&event.deltaY===42&&event.deltaZ===0&&event.deltaMode===WheelEvent.DOM_DELTA_PIXEL&&event.wheelDeltaY===-126&&event.button===0&&event.buttons===0&&window.event===event);
  const cancelled=wheelSmokeSaved.length===1;
  document.getElementById("wheel-smoke-result").textContent=cancelled?"cancelled":"accepted";
  return cancelled?false:0;
 };
}
</script>'

// The non-windowed signed-browser smoke invokes the real GG embedding entry.
// It does not post an operating-system event or use script dispatchEvent().
fn (mut app BrowserApp) run_wheel_input_smoke() ! {
	app.layout_tree_only = false
	app.platform_pointer_buttons = 0
	app.install_loaded_page(LoadedPage{
		url:          'about:wheel-input-smoke'
		markup:       wheel_input_smoke_markup
		status:       'Loaded wheel input smoke'
		content_type: 'text/html'
	}, false)
	if app.document == unsafe { nil } || app.js_runtime == unsafe { nil } {
		return error('wheel input smoke: parsed document or JavaScript owner missing')
	}
	if app.js_messages.len != 0 {
		return error('wheel input smoke: fixture script failed: ${app.js_messages.join('; ')}')
	}
	scroller := app.document.get_element_by_id('wheel-smoke-scroller') or {
		return error('wheel input smoke: overflow element missing')
	}
	result := app.document.get_element_by_id('wheel-smoke-result') or {
		return error('wheel input smoke: mutation result element missing')
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
		if app.js_runtime.evaluate_host('wheelSmokeSaved.length===${index + 1}&&wheelSmokeChecks.every(Boolean)&&wheelSmokeSaved.every(event=>event.currentTarget===null&&event.eventPhase===Event.NONE)&&window.event===undefined')! != 'true' {
			return error('wheel input smoke: native event ownership or payload failed at input ${
				index + 1}')
		}
		wrapper := app.js_runtime.evaluate_host_value('wheelSmokeSaved[${index}]')!
		event := app.js_runtime.native_event(wrapper)!
		if event.interface_ != .wheel_event || !event.is_trusted()
			|| app.js_runtime.javascript_event(event)! != wrapper {
			return error('wheel input smoke: retained wrapper lost its native WheelEvent at input ${
				index + 1}')
		}
		wheel := unsafe { &dom.WheelEvent(event) }
		if wheel.delta_x() != 0 || wheel.delta_y() != 42
			|| wheel.delta_mode() != dom.dom_delta_pixel || wheel.wheel_delta_y() != -126
			|| event.default_prevented() != (index == 0) {
			return error('wheel input smoke: GG delta conversion or cancellation failed at input ${
				index + 1}')
		}
		expected_text := if index == 0 { 'cancelled' } else { 'accepted' }
		if (result.as_node().text_content() or { '' }) != expected_text
			|| !app.document.layout_is_up_to_date()
			|| app.paint_commands.filter(it.kind == 'draw_text'
			&& it.text == expected_text).len == 0 {
			return error('wheel input smoke: callback mutation did not reach live DOM and paint at input ${
				index + 1}')
		}
		expected_inner := if index == 0 { f64(0) } else { f64(42) }
		expected_viewport := if index == 2 { f64(42) } else { f64(0) }
		if scroller.el_scroll_offset().y() != expected_inner || app.scroll_y != expected_viewport {
			return error('wheel input smoke: default scrolling order failed at input ${index + 1}: inner=${scroller.el_scroll_offset().y()}, viewport=${app.scroll_y}')
		}
	}
	if app.js_messages.len != 0 {
		return error('wheel input smoke: callback errors: ${app.js_messages.join('; ')}')
	}
}
