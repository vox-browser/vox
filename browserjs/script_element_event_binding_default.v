module browserjs

import dom as _

$if !darwin && !linux {
	pub fn (mut runtime Runtime) install_script_element_event_binding() ! {
		return error('Script element JavaScriptCore bindings are unavailable on this platform')
	}

	pub fn (runtime &Runtime) dispatch_external_script_load(element &dom.Element) ! {
		return error('Script element JavaScriptCore bindings are unavailable on this platform')
	}

	pub fn (runtime &Runtime) dispatch_external_script_event(element &dom.Element, name string) ! {
		return error('Script element JavaScriptCore bindings are unavailable on this platform')
	}
}
