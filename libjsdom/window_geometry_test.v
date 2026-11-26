module libjsdom

import css
import dom
import html
import libjs

fn geometry_eval(mut vm libjs.VM, source string) !bool {
	mut script := libjs.Script.parse(source, vm.realm(), 'window-geometry.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 100000})!.as_bool()
}

fn test_geometry_reads_owning_window_and_cached_screen_without_snapshotting_values() {
	address := dom.URL{value: 'https://geometry.test/'}
	mut document := html.parse_navigation_document('<body></body>', address, address.origin(), none)!
	document.set_viewport_rect(dom.Rect{0, 0, 1024, 768})
	mut window := unsafe { &html.WindowModel(document.get_window()?) }
	window.set_host_configuration(html.WindowHostConfiguration{screen_width: 1440, screen_height: 900, available_screen_width: 1440, available_screen_height: 875, outer_width: 1050, outer_height: 880, window_x: 12, window_y: 24, device_pixel_ratio: 2})
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close(); document.finalize() }
	assert geometry_eval(mut vm, 'innerWidth===1024&&innerHeight===768&&outerWidth===1050&&outerHeight===880&&screenX===12&&screenLeft===12&&screenY===24&&screenTop===24&&devicePixelRatio===2')!
	assert geometry_eval(mut vm, 'var original=screen;screen===original&&screen instanceof Screen&&screen instanceof EventTarget&&screen.width===1440&&screen.height===900&&screen.availHeight===875&&screen.colorDepth===24&&screen.pixelDepth===24&&!screen.isExtended&&Object.prototype.toString.call(screen)==="[object Screen]"')!
	document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	mut screen := window.screen()
	screen.web_exposed_screen_area = css.CSSPixelRect.new(0, 0, 1920, 1080)
	assert geometry_eval(mut vm, 'innerWidth===800&&innerHeight===600&&original.width===1920&&screen.height===1080')!
	assert geometry_eval(mut vm, 'var getter=Object.getOwnPropertyDescriptor(window,"innerWidth").get;innerWidth=42;screen=17;innerWidth===42&&getter.call(window)===800&&screen===17&&original.width===1920')!
	assert geometry_eval(mut vm, 'var invalid=0;for(var run of [()=>new Screen(),()=>Screen(),()=>getter.call({}),()=>Object.getOwnPropertyDescriptor(Screen.prototype,"width").get.call({})])try{run()}catch(e){if(e instanceof TypeError)invalid++}invalid===4')!
}
