module browserjs

import dom
import html
import page

fn viewport_binding_fixture(width int, height int, ratio f64) !(&Runtime, &dom.Document) {
	owner := page.Page.create(1)!
	address := dom.URL{ value: 'https://viewport.example/' }
	mut document := html.create_navigation_document_for_page(address, address.origin(), none, unsafe { &dom.Page(owner) })!
	document.set_viewport_rect(dom.Rect{0, 0, f64(width), f64(height)})
	window_target := document.get_window() or { return error('Window is missing') }
	mut window := unsafe { &html.WindowModel(window_target) }
	window.set_host_configuration(html.WindowHostConfiguration{ device_pixel_ratio: ratio })
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) })!
	runtime.install_window_viewport_binding()!
	return runtime, document
}

fn test_window_viewport_attributes_read_live_native_geometry_and_density() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document := viewport_binding_fixture(1024, 768, 2)!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host('innerWidth===1024&&innerHeight===768&&devicePixelRatio===2')! == 'true'
	document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	window_target := document.get_window()?
	mut window := unsafe { &html.WindowModel(window_target) }
	window.set_host_configuration(html.WindowHostConfiguration{ device_pixel_ratio: 1.5 })
	assert runtime.evaluate_host('innerWidth===800&&innerHeight===600&&devicePixelRatio===1.5')! == 'true'
	assert runtime.evaluate_host(r'
 let invalid=0;
 for(const name of ["innerWidth","innerHeight","devicePixelRatio"]){
  const attribute=Object.getOwnPropertyDescriptor(globalThis,name);
  if(!attribute.enumerable||!attribute.configurable||attribute.get.name!=="get "+name||attribute.set.length!==1)throw new Error("attribute metadata");
  for(const callback of [()=>attribute.get.call({}),()=>attribute.set.call({},3)])try{callback()}catch(error){if(error instanceof TypeError)invalid++}
 }
 globalThis.savedViewportGetter=Object.getOwnPropertyDescriptor(globalThis,"innerWidth").get;
 innerWidth="replaced";
 invalid===6&&innerWidth==="replaced"&&savedViewportGetter.call(globalThis)===800;
 ')! == 'true'
	runtime.install_window_viewport_binding()!
	assert runtime.evaluate_host('innerWidth==="replaced"')! == 'true'
}

fn test_window_viewport_attributes_are_isolated_between_realms() {
	$if !darwin && !linux {
		return
	}
	mut first, mut first_document := viewport_binding_fixture(400, 300, 1)!
	mut second, mut second_document := viewport_binding_fixture(1200, 900, 2)!
	defer {
		first.close()
		second.close()
		first_document.finalize()
		second_document.finalize()
	}
	assert first.evaluate_host('innerWidth===400&&innerHeight===300&&devicePixelRatio===1')! == 'true'
	assert second.evaluate_host('innerWidth===1200&&innerHeight===900&&devicePixelRatio===2')! == 'true'
}
