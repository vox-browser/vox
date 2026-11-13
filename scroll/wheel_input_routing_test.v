module main

import browserjs
import dom
import gg
import html
import page
import time

const wheel_routing_test_markup = '<!doctype html><style>
html,body { margin:0 }
#wheel-scroller { width:240px; height:100px; overflow:auto }
video,audio { display:block; width:180px; height:60px }
#wheel-content { height:500px }
#wheel-remainder { height:600px }
#result { display:none }
</style><div id="wheel-scroller"><video id="video" controls></video><div id="wheel-content"></div></div>
<video id="viewport-video" controls></video><div id="wheel-remainder"></div><div id="result"></div>'

@[heap]
struct WheelRoutingTestObservation {
mut:
	events          []&dom.Event
	targets         []voidptr
	trusted         []bool
	inner_before    []f64
	viewport_before []f64
}

fn wheel_routing_test_document(address string) !(&page.Page, &dom.Document) {
	mut owner := page.Page.create(1)!
	owner.set_enable_autoscroll(false)
	document := parse_browser_navigation_document_for_page_with_response_time(wheel_routing_test_markup, dom.URL{
		value: address
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	return owner, document
}

fn wheel_routing_test_initialize(mut runtime browserjs.Runtime, document &dom.Document) ! {
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.routeVideo=document.getElementById("video");globalThis.routeViewportVideo=document.getElementById("viewport-video");globalThis.routeScroller=document.getElementById("wheel-scroller");0',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host(r'typeof WheelEvent==="function"&&Object.getPrototypeOf(WheelEvent.prototype)===MouseEvent.prototype')! == 'true'
	assert runtime.evaluate_host(r'(()=>{const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"onwheel");return !!d&&Function.prototype.toString.call(d.set).includes("[native code]")&&routeVideo.onwheel===null&&routeViewportVideo.onwheel===null})()')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	owner_handle := voidptr(&runtime)
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function('__wheelRoutingContext', fn [settings, owner_handle, actual_true] (_ voidptr, arguments []voidptr) !voidptr {
		owner := unsafe { &browserjs.Runtime(owner_handle) }
		assert arguments.len == 0
		assert settings.realm().script_execution_depth > 0
			&& settings.realm().callback_execution_depth > 0
		assert owner.libjs_vm().has_running_execution_context()
		assert voidptr(html.current_principal_settings_object()) == voidptr(settings)
		assert voidptr(html.incumbent_settings_object()) == voidptr(settings)
		return actual_true
	})!
}

fn wheel_routing_test_app(owner &page.Page, document &dom.Document, runtime &browserjs.Runtime) &BrowserApp {
	mut app := &BrowserApp{
		page_model:       owner
		document:         document
		js_runtime:       runtime
		layout_tree_only: false
		viewport_width:   320
		viewport_height:  200
	}
	app.relayout(320, 200 + app.chrome_height())
	assert app.content_height > 200
	assert document.paintable_box() != none && document.layout_node() != none
	return app
}

fn wheel_routing_test_observe(element &dom.Element, scroller &dom.Element, observation &WheelRoutingTestObservation) {
	callback := &dom.CallbackType{
		handle_event: fn [scroller, observation] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut result := unsafe { &WheelRoutingTestObservation(observation) }
			assert event.interface_ == .wheel_event
			result.events << event
			result.targets << voidptr(event.target() or {
				panic('routed wheel needs its actual target')
			})
			result.trusted << event.is_trusted()
			result.inner_before << scroller.el_scroll_offset().y()
			result.viewport_before << scroller.document().viewport_rect().y
			return dom.js_undefined()
		}
	}
	unsafe { &dom.EventTarget(element) }.add_event_listener_without_options('wheel',
		dom.IDLEventListener.create(callback))
}

fn wheel_routing_test_matches(mut runtime browserjs.Runtime, event &dom.Event, expression string) ! {
	wrapper := runtime.evaluate_host_value(expression)!
	assert voidptr(runtime.native_event(wrapper)!) == voidptr(event)
	assert runtime.javascript_event(event)! == wrapper
	wheel := unsafe { &dom.WheelEvent(event) }
	values := [wheel.screen_x(), wheel.screen_y(), wheel.client_x(),
		wheel.client_y(), wheel.page_x(), wheel.page_y(), wheel.offset_x(),
		wheel.offset_y(), wheel.delta_x(), wheel.delta_y(), wheel.delta_z(), f64(wheel.delta_mode()),
		f64(wheel.wheel_delta_x()), f64(wheel.wheel_delta_y()), f64(wheel.wheel_delta())].map(it.str()).join(',')
	assert runtime.evaluate_host('(()=>{const e=${expression};return [e.screenX,e.screenY,e.clientX,e.clientY,e.pageX,e.pageY,e.offsetX,e.offsetY,e.deltaX,e.deltaY,e.deltaZ,e.deltaMode,e.wheelDeltaX,e.wheelDeltaY,e.wheelDelta].every((value,index)=>value===[${values}][index])&&e.currentTarget===null&&e.eventPhase===Event.NONE&&window.event===undefined})()')! == 'true'
}

fn wheel_routing_test_balance(runtime &browserjs.Runtime, document &dom.Document, exceptions int) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == exceptions
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_callback_free_wheel_reuses_current_target_and_native_listeners_disable_reuse() {
	mut owner, mut document := wheel_routing_test_document('https://wheel-input-no-runtime.example.test/')!
	defer { document.finalize() }
	mut app := wheel_routing_test_app(owner, document, unsafe { nil })
	video := document.get_element_by_id('video')?
	scroller := document.get_element_by_id('wheel-scroller')?
	hit := app.hit_test_at_viewport_point(25.25, 20.125)?
	target := wheel_input_target(hit)?
	assert app.wheel_input_can_reuse_hit(target)
	assert wheel_input_target_layout_is_current(target)
	assert app.handle_wheel_at_viewport_point(page.PixelPoint{25.25, 20.125}, page.PixelPoint{},
		0, 0, 0, 0, 3.75, false) == .handled
	assert scroller.el_scroll_offset().y() == 3.75 && app.scroll_y == 0
	callback := &dom.CallbackType{
		handle_event: fn [scroller] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut changed := unsafe { &dom.Element(scroller) }
			changed.set_attribute_value('style', 'overflow:visible')
			return dom.js_undefined()
		}
	}
	unsafe { &dom.EventTarget(video) }.add_event_listener_without_options('wheel',
		dom.IDLEventListener.create(callback))
	assert !app.wheel_input_can_reuse_hit(target)
	// A native callback without a script runtime still forces fresh hit testing.
	assert app.handle_wheel_at_viewport_point(page.PixelPoint{25.25, 20.125}, page.PixelPoint{},
		0, 0, 0, 0, 3.75, false) == .handled
	assert app.scroll_y == 3.75
}

fn test_browser_wheel_hit_routes_trusted_fractional_events_and_cancels_before_inner_and_viewport_scroll() {
	$if !darwin { return }
	mut owner, mut document :=
		wheel_routing_test_document('https://wheel-input-cancel.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	wheel_routing_test_initialize(mut runtime, document)!
	mut app := wheel_routing_test_app(owner, document, runtime)
	app.set_scroll_y(16, app.viewport_height + app.chrome_height())
	scroller := document.get_element_by_id('wheel-scroller')?
	video := document.get_element_by_id('video')?
	viewport_video := document.get_element_by_id('viewport-video')?
	observation := &WheelRoutingTestObservation{}
	for player in [video, viewport_video] {
		wheel_routing_test_observe(player, scroller, observation)
	}
	runtime.evaluate_host(r'
globalThis.routeSaved=[];globalThis.routeChecks=[];globalThis.routeCancel=true;
for(const player of [routeVideo,routeViewportVideo]){
 player.onwheel=function(e){routeSaved.push(e);routeChecks.push(this===player&&arguments.length===1&&e.target===player&&e.currentTarget===player&&e instanceof WheelEvent&&e instanceof MouseEvent&&e instanceof UIEvent&&e instanceof Event&&!(e instanceof PointerEvent)&&e.isTrusted&&e.bubbles&&e.cancelable&&e.composed&&e.view===window&&e.detail===0&&e.relatedTarget===null&&e.deltaMode===WheelEvent.DOM_DELTA_PIXEL&&window.event===e&&__wheelRoutingContext());document.getElementById("result").textContent=player.id+":"+routeSaved.length;return routeCancel?false:0};
 player.addEventListener("wheel",function(e){routeChecks.push(e.defaultPrevented===routeCancel&&e.currentTarget===player&&window.event===e)});
}0
')!
	for index, client in [page.PixelPoint{25.25, 20.125}, page.PixelPoint{25.25, 120.125}] {
		hit := app.hit_test_at_viewport_point(client.x, client.y) or {
			panic('missing real media control hit')
		}
		assert hit.node != unsafe { nil }
		shadow := hit.node.containing_shadow_root() or { panic('hit must exercise UA controls') }
		assert shadow.is_user_agent_internal()
		player := if index == 0 { video } else { viewport_video }
		assert voidptr(shadow.host()?) == voidptr(player)
		assert app.handle_wheel_at_viewport_point(client, page.PixelPoint{111.375, 222.625}, 2, 2,
			dom.modifier_ctrl | dom.modifier_alt | dom.modifier_super, 1.5, 3.75, false) == .cancelled
		assert app.scroll_y == 16 && scroller.el_scroll_offset().y() == 0
		assert document.get_element_by_id('result')?.text_content()? == '${player.get_attribute_value('id')}:${
			index + 1}'
		assert observation.events.len == index + 1 && observation.targets[index] == voidptr(player)
		assert observation.inner_before[index] == 0 && observation.viewport_before[index] == 16
		assert runtime.evaluate_host('routeSaved[${index}].screenX===111.375&&routeSaved[${index}].screenY===222.625&&routeSaved[${index}].clientX===${client.x}&&routeSaved[${index}].clientY===${client.y}&&routeSaved[${index}].pageY===${
			client.y + 16}&&routeSaved[${index}].deltaX===1.5&&routeSaved[${index}].deltaY===3.75&&routeSaved[${index}].wheelDeltaX===-4&&routeSaved[${index}].wheelDeltaY===-11&&routeSaved[${index}].button===2&&routeSaved[${index}].buttons===2&&routeSaved[${index}].ctrlKey&&routeSaved[${index}].altKey&&routeSaved[${index}].metaKey&&routeChecks.every(Boolean)')! == 'true'
		wheel_routing_test_matches(mut runtime, observation.events[index], 'routeSaved[${index}]')!
	}
	// Exercise the actual native shell entry, whose existing scale is 42 CSS pixels.
	app.handle_event(&gg.Event{
		typ:           .mouse_scroll
		mouse_x:       25.25
		mouse_y:       20.125 + app.page_top()
		scroll_x:      -0.0625
		scroll_y:      -0.125
		modifiers:     1
		window_height: 200 + app.chrome_height()
	})
	assert observation.events.len == 3 && app.scroll_y == 16 && scroller.el_scroll_offset().y() == 0
	assert runtime.evaluate_host('routeSaved.length===3&&routeSaved[2].deltaX===5.25&&routeSaved[2].deltaY===2.625&&routeSaved[2].shiftKey&&routeSaved[2].isTrusted&&routeSaved[2].defaultPrevented&&routeChecks.every(Boolean)')! == 'true'
	assert document.get_element_by_id('result')?.text_content()? == 'video:3'
	wheel_routing_test_matches(mut runtime, observation.events[2], 'routeSaved[2]')!
	runtime.evaluate_host('routeCancel=false;0')!
	assert app.handle_wheel_at_viewport_point(page.PixelPoint{25.25, 20.125}, page.PixelPoint{}, 0,
		0, 0, 0, 3.75, false) == .handled
	assert scroller.el_scroll_offset().y() == 3.75 && app.scroll_y == 16
	assert observation.inner_before[3] == 0 && observation.viewport_before[3] == 16
	assert app.handle_wheel_at_viewport_point(page.PixelPoint{25.25, 120.125}, page.PixelPoint{},
		0, 0, 0, 0, 3.75, false) == .handled
	assert app.scroll_y == 19.75 && scroller.el_scroll_offset().y() == 3.75
	assert observation.inner_before[4] == 3.75 && observation.viewport_before[4] == 16
	assert observation.trusted == [true, true, true, true, true]
	assert runtime.evaluate_host('routeSaved.length===5&&routeChecks.every(Boolean)')! == 'true'
	for index in 3 .. 5 {
		wheel_routing_test_matches(mut runtime, observation.events[index], 'routeSaved[${index}]')!
	}
	assert app.js_messages == []
	wheel_routing_test_balance(runtime, document, 0)
}

fn test_browser_wheel_default_action_uses_fresh_hit_after_native_handler_mutates_the_dom_and_overflow() {
	$if !darwin { return }
	mut owner, mut document :=
		wheel_routing_test_document('https://wheel-input-mutation.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	wheel_routing_test_initialize(mut runtime, document)!
	mut app := wheel_routing_test_app(owner, document, runtime)
	scroller := document.get_element_by_id('wheel-scroller')?
	video := document.get_element_by_id('video')?
	observation := &WheelRoutingTestObservation{}
	wheel_routing_test_observe(video, scroller, observation)
	runtime.evaluate_host(r'
globalThis.routeMutationSaved=[];globalThis.routeMutationChecks=[];
globalThis.routeReplacement=document.createElement("audio");routeReplacement.id="wheel-replacement";routeReplacement.setAttribute("controls","");
routeVideo.onwheel=function(e){routeMutationSaved.push(e);routeMutationChecks.push(e.isTrusted&&e.target===routeVideo&&this===routeVideo&&window.event===e&&__wheelRoutingContext());routeScroller.style.overflow="visible";routeVideo.remove();routeScroller.insertBefore(routeReplacement,routeScroller.firstChild);document.getElementById("result").textContent="fresh audio";void routeReplacement.paused;return 0};
routeReplacement.onwheel=function(e){routeMutationSaved.push(e);routeMutationChecks.push(e.isTrusted&&e.target===routeReplacement&&this===routeReplacement&&window.event===e&&__wheelRoutingContext());return false};0
')!
	created := runtime.native_event_target(runtime.evaluate_host_value('routeReplacement')!)!
	assert document.get_element_by_id('wheel-replacement') == none
	assert app.handle_wheel_at_viewport_point(page.PixelPoint{25.25, 20.125}, page.PixelPoint{101.25, 202.5},
		0, 0, 0, 0, 3.75, false) == .handled
	assert document.get_element_by_id('video') == none
	replacement := document.get_element_by_id('wheel-replacement')?
	assert voidptr(replacement) == voidptr(created)
	assert scroller.el_scroll_offset().y() == 0 && app.scroll_y == 3.75
	assert document.get_element_by_id('result')?.text_content()? == 'fresh audio'
	assert observation.events.len == 1 && observation.targets[0] == voidptr(video)
	assert observation.inner_before[0] == 0 && observation.viewport_before[0] == 0
	wheel_routing_test_matches(mut runtime, observation.events[0], 'routeMutationSaved[0]')!
	// The next native input must hit the attached native audio, not the old tree.
	wheel_routing_test_observe(replacement, scroller, observation)
	hit := app.hit_test_at_viewport_point(25.25, 20.125) or { panic('missing replacement hit') }
	assert hit.node != unsafe { nil }
	shadow := hit.node.containing_shadow_root() or {
		panic('replacement audio controls need a real UA hit')
	}
	assert shadow.is_user_agent_internal() && voidptr(shadow.host()?) == voidptr(replacement)
	assert app.handle_wheel_at_viewport_point(page.PixelPoint{25.25, 20.125}, page.PixelPoint{}, 0,
		0, 0, 0, 7.5, false) == .cancelled
	assert app.scroll_y == 3.75 && scroller.el_scroll_offset().y() == 0
	assert observation.events.len == 2 && observation.targets[1] == voidptr(replacement)
	assert runtime.evaluate_host('routeMutationSaved.length===2&&routeMutationSaved[0]!==routeMutationSaved[1]&&routeMutationChecks.every(Boolean)&&routeMutationSaved[1].defaultPrevented')! == 'true'
	wheel_routing_test_matches(mut runtime, observation.events[1], 'routeMutationSaved[1]')!
	assert app.js_messages == []
	wheel_routing_test_balance(runtime, document, 0)
}

fn test_browser_wheel_async_cancelability_page_script_gate_exception_and_runtime_close() {
	$if !darwin { return }
	mut owner, mut document :=
		wheel_routing_test_document('https://wheel-input-lifecycle.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	wheel_routing_test_initialize(mut runtime, document)!
	mut app := wheel_routing_test_app(owner, document, runtime)
	scroller := document.get_element_by_id('wheel-scroller')?
	video := document.get_element_by_id('video')?
	observation := &WheelRoutingTestObservation{}
	wheel_routing_test_observe(video, scroller, observation)
	runtime.evaluate_host(r'
globalThis.routeLifecycleSaved=[];globalThis.routeLifecycleOrder=[];globalThis.routeLifecycleChecks=[];globalThis.routeLifecycleMode="prevent";globalThis.routeThrown={message:"original wheel callback value"};
routeVideo.onwheel=function(e){routeLifecycleSaved.push(e);routeLifecycleOrder.push("handler");routeLifecycleChecks.push(e instanceof WheelEvent&&e.isTrusted&&e.target===routeVideo&&e.currentTarget===routeVideo&&this===routeVideo&&window.event===e&&__wheelRoutingContext());if(routeLifecycleMode==="throw")throw routeThrown;if(routeLifecycleMode==="false")return false;e.preventDefault();return 0};
routeVideo.addEventListener("wheel",function(e){routeLifecycleOrder.push("after");routeLifecycleChecks.push(e.currentTarget===routeVideo&&window.event===e);if(routeLifecycleMode==="throw")e.preventDefault()});0
')!
	for index, mode in ['prevent', 'false'] {
		runtime.evaluate_host('routeLifecycleMode="${mode}";0')!
		assert app.handle_wheel_at_viewport_point(page.PixelPoint{25.25, 20.125}, page.PixelPoint{},
			0, 0, 0, 1.5, 2.5, true) == .handled
		assert app.scroll_y == 0 && scroller.el_scroll_offset().y() == 0
		assert !observation.events[index].cancelable()
		assert observation.events[index].default_prevented() == (mode == 'false')
		assert runtime.evaluate_host('routeLifecycleSaved[${index}].cancelable===false&&routeLifecycleSaved[${index}].defaultPrevented===${mode == 'false'}&&routeLifecycleChecks.every(Boolean)')! == 'true'
		wheel_routing_test_matches(mut runtime, observation.events[index],
			'routeLifecycleSaved[${index}]')!
	}
	owner.set_is_scripting_enabled(false)
	assert app.handle_wheel_at_viewport_point(page.PixelPoint{25.25, 20.125}, page.PixelPoint{}, 0,
		0, 0, 0, 2.5, false) == .handled
	assert scroller.el_scroll_offset().y() == 2.5 && app.scroll_y == 0
	assert observation.events.len == 3 && !observation.events[2].default_prevented()
	assert runtime.evaluate_host('routeLifecycleSaved.length===2&&routeLifecycleOrder.join(",")==="handler,after,handler,after"&&window.event===undefined')! == 'true'
	wheel_routing_test_balance(runtime, document, 0)
	owner.set_is_scripting_enabled(true)
	runtime.evaluate_host('routeLifecycleMode="throw";0')!
	assert app.handle_wheel_at_viewport_point(page.PixelPoint{25.25, 20.125}, page.PixelPoint{}, 0,
		0, 0, 0, 7.5, false) == .cancelled
	assert scroller.el_scroll_offset().y() == 2.5 && app.scroll_y == 0
	assert observation.events.len == 4 && observation.events[3].default_prevented()
	assert runtime.evaluate_host('routeLifecycleSaved.length===3&&routeLifecycleOrder.join(",")==="handler,after,handler,after,handler,after"&&routeLifecycleChecks.every(Boolean)&&window.event===undefined')! == 'true'
	wheel_routing_test_matches(mut runtime, observation.events[3], 'routeLifecycleSaved[2]')!
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 1
	assert runtime.actual_webidl_value(settings.realm().reported_exceptions[0].value.as_webidl_value()!)! == runtime.evaluate_host_value('routeThrown')!
	wheel_routing_test_balance(runtime, document, 1)
	assert app.js_messages == []
	runtime.close()
	assert app.handle_wheel_at_viewport_point(page.PixelPoint{25.25, 20.125}, page.PixelPoint{}, 0,
		0, 0, 0, 2.5, false) == .handled
	assert scroller.el_scroll_offset().y() == 5 && app.scroll_y == 0
	assert observation.events.len == 5 && observation.trusted == [true, true, true, true, true]
	assert !observation.events[4].default_prevented()
		&& observation.events[4].current_target() == none
	assert app.js_messages == []
	wheel_routing_test_balance(runtime, document, 1)
}

fn test_quiet_script_runtime_reuses_wheel_hit_but_document_and_window_listeners_do_not() {
	$if !darwin { return }
	mut owner, mut document := wheel_routing_test_document('https://wheel-input-quiet.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	wheel_routing_test_initialize(mut runtime, document)!
	mut app := wheel_routing_test_app(owner, document, runtime)
	app.poll_javascript_tasks()
	assert !runtime.has_pending_document_state()
	hit := app.hit_test_at_viewport_point(25.25, 20.125)?
	target := wheel_input_target(hit)?
	assert app.wheel_input_can_reuse_hit(target)
	scroller := document.get_element_by_id('wheel-scroller')?
	assert app.handle_wheel_at_viewport_point(page.PixelPoint{25.25, 20.125}, page.PixelPoint{},
		0, 0, 0, 0, 3.75, false) == .handled
	assert scroller.el_scroll_offset().y() == 3.75 && app.scroll_y == 0
	for scope in ['document', 'window'] {
		runtime.evaluate_host('globalThis.routeQuietCancel=e=>e.preventDefault();${scope}.addEventListener("wheel",routeQuietCancel,{passive:false});0')!
		app.poll_javascript_tasks()
		assert !runtime.has_pending_document_state()
		assert !app.wheel_input_can_reuse_hit(target)
		assert app.handle_wheel_at_viewport_point(page.PixelPoint{25.25, 20.125}, page.PixelPoint{},
			0, 0, 0, 0, 3.75, false) == .cancelled
		assert scroller.el_scroll_offset().y() == 3.75 && app.scroll_y == 0
		runtime.evaluate_host('${scope}.removeEventListener("wheel",routeQuietCancel);0')!
		app.poll_javascript_tasks()
		assert app.wheel_input_can_reuse_hit(target)
	}
}

fn test_pending_script_mutation_rejects_wheel_hit_reuse_and_updates_default_scroll_target() {
	$if !darwin { return }
	mut owner, mut document := wheel_routing_test_document('https://wheel-input-pending.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	wheel_routing_test_initialize(mut runtime, document)!
	mut app := wheel_routing_test_app(owner, document, runtime)
	app.poll_javascript_tasks()
	hit := app.hit_test_at_viewport_point(25.25, 20.125)?
	target := wheel_input_target(hit)?
	runtime.evaluate_host('routeScroller.style.overflow="visible";0')!
	runtime.mark_document_state_dirty()
	assert !app.wheel_input_can_reuse_hit(target)
	assert app.handle_wheel_at_viewport_point(page.PixelPoint{25.25, 20.125}, page.PixelPoint{},
		0, 0, 0, 0, 3.75, false) == .handled
	assert document.get_element_by_id('wheel-scroller')?.el_scroll_offset().y() == 0
	assert app.scroll_y == 3.75
	assert !runtime.has_pending_document_state()
}

fn test_frame_replayed_wheel_adopts_script_geometry_without_duplicate_shell_layout() {
	$if !darwin { return }
	for cancelled in [false, true] {
		mut owner, mut document := wheel_routing_test_document('https://wheel-frame-task.example.test/')!
		mut runtime := browserjs.Runtime.create()
		defer { runtime.close(); document.finalize() }
		wheel_routing_test_initialize(mut runtime, document)!
		mut app := wheel_routing_test_app(owner, document, runtime)
		app.poll_javascript_tasks()
		runtime.evaluate_host('routeScroller.style.overflow="visible";routeVideo.onwheel=e=>{${if cancelled { 'e.preventDefault();' } else { '' }}globalThis.frameWheelWidth=routeScroller.getBoundingClientRect().width};0')!
		runtime.mark_document_state_dirty()
		generation := document.layout_pass_generation
		paint_generation := app.paint_generation
		app.frame_aligned_wheel = DeferredPageInput{
			document: voidptr(document)
			generation: app.navigation_generation
			event: gg.Event{
				typ: .mouse_scroll
				mouse_x: 25.25
				mouse_y: f32(20.125 + app.page_top())
				scroll_y: -1
				window_height: app.viewport_height + app.chrome_height()
			}
		}
		app.prepare_frame_page_input()
		assert app.frame_preparation_depth == 1
		assert app.frame_aligned_wheel == none && app.deferred_page_input.len == 0
		assert runtime.evaluate_host('frameWheelWidth')! == '240'
		assert document.get_element_by_id('wheel-scroller')?.el_scroll_offset().y() == 0
		assert app.scroll_y == if cancelled { f64(0) } else { f64(42) }
		if !disable_frame_task_layout_coalescing {
			assert document.layout_pass_generation == generation + 1
			assert app.paint_generation == paint_generation
		}
		app.finish_frame_preparation()
		assert document.layout_is_up_to_date()
		assert !app.javascript_tasks_have_unadopted_paint()
		assert app.frame_preparation_depth == 0
		assert app.paint_generation > paint_generation
		assert app.js_messages == []
	}
}
