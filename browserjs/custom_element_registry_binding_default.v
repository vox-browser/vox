module browserjs

$if !darwin && !linux && !windows {
	pub fn (mut runtime Runtime) install_custom_element_registry_binding() ! {
		return error('CustomElementRegistry JavaScriptCore bindings are unavailable on this platform')
	}
}
