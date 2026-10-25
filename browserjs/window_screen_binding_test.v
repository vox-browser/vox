module browserjs

import css
import dom
import html
import loader

fn screen_binding_fixture(url string) !(&Runtime, &dom.Document, &css.Screen) {
	if !loader.is_initialized() { loader.initialize() }
	document := html.parse_navigation_document('<!doctype html><body></body>', dom.URL{ value: url }, dom.URL{ value: url }.origin(), none)!
	window_target := document.get_window() or { return error('Screen fixture has no Window') }
	mut window := unsafe { &html.WindowModel(window_target) }
	window.set_host_configuration(html.WindowHostConfiguration{
		screen_width:            1440
		screen_height:           900
		available_screen_width:  1440
		available_screen_height: 875
	})
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) })!
	runtime.install_window_screen_binding()!
	return runtime, document, window.screen()
}

fn test_window_screen_uses_owning_screen_and_live_source_values() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document, mut screen := screen_binding_fixture('https://screen.test/')!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host('screen.width===1440&&screen.height===900&&screen.availWidth===1440&&screen.availHeight===875&&screen.colorDepth===24&&screen.pixelDepth===24&&!screen.isExtended')! == 'true'
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('screen')!)!) == voidptr(screen)
	screen.web_exposed_screen_area = css.CSSPixelRect.new(0, 0, 1920, 1080)
	screen.screen_count = 2
	screen.window_management_allowed = true
	assert runtime.evaluate_host('screen.width===1920&&screen.height===1080&&screen.isExtended')! == 'true'
	assert runtime.evaluate_host(r'
 const original=screen,orientation=screen.orientation;
 const attribute=Object.getOwnPropertyDescriptor(Screen.prototype,"colorDepth"),windowAttribute=Object.getOwnPropertyDescriptor(globalThis,"screen");
 let invalid=0;for(const f of [()=>new Screen(),()=>new ScreenOrientation(),()=>attribute.get.call({}),()=>windowAttribute.get.call({}),()=>windowAttribute.set.call({},1)]){try{f()}catch(error){if(error instanceof TypeError)invalid++}}
 const correct=invalid===5&&attribute.set===undefined&&attribute.enumerable&&attribute.configurable&&attribute.get.name==="get colorDepth"&&attribute.get.length===0&&screen instanceof Screen&&Object.prototype.toString.call(screen)==="[object Screen]"&&screen.orientation===orientation&&orientation instanceof ScreenOrientation&&orientation instanceof EventTarget&&orientation.type==="landscape-primary"&&orientation.angle===0;
 screen=17;correct&&screen===17&&windowAttribute.get.call(globalThis)===original;
 ')! == 'true'
	runtime.install_window_screen_binding()!
	assert runtime.evaluate_host('screen===17')! == 'true'
}

fn test_screen_handlers_and_orientation_use_actual_event_targets() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document, screen := screen_binding_fixture('https://screen.test/')!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 globalThis.changes=[];globalThis.changeHandler=function(event){changes.push(this===screen&&event.target===screen)};
 screen.onchange=changeHandler;
 screen.orientation.onchange=function(event){changes.push(this===screen.orientation&&event.target===screen.orientation)};
 screen.orientation.addEventListener("change",function(event){changes.push(event.currentTarget===screen.orientation)});
 screen.onchange===changeHandler&&screen.orientation.unlock()===undefined;
 ')! == 'true'
	assert unsafe { &dom.EventTarget(screen) }.dispatch_event(dom.Event.create('change', dom.EventInit{}))
	mut mutable_screen := unsafe { &css.Screen(screen) }
	assert unsafe { &dom.EventTarget(mutable_screen.orientation()) }.dispatch_event(dom.Event.create('change', dom.EventInit{}))
	assert runtime.evaluate_host('changes.length===3&&changes.every(Boolean)')! == 'true'
	assert runtime.evaluate_host(r'
 globalThis.lockErrors=[];
 for(const [object,arg] of [[screen.orientation,"portrait"],[screen.orientation,"invalid"],[{},"portrait"]])ScreenOrientation.prototype.lock.call(object,arg).catch(error=>lockErrors.push(error));
 true;
 ')! == 'true'
	assert runtime.evaluate_host('lockErrors.map(error=>error.name).join(",")==="NotSupportedError,TypeError,TypeError"&&lockErrors[0] instanceof DOMException&&lockErrors[0].code===9&&lockErrors[1] instanceof TypeError&&lockErrors[2] instanceof TypeError')! == 'true'
}

fn test_screen_secure_context_members_are_absent_on_http() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document, _ := screen_binding_fixture('http://screen.test/')!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host('!("isExtended" in screen)&&!("onchange" in screen)&&"onchange" in screen.orientation&&screen.colorDepth===24')! == 'true'
}
