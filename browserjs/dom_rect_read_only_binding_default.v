module browserjs

$if !darwin && !linux {
	pub fn (mut runtime Runtime) install_dom_rect_read_only_binding() ! {
		return error('Native DOMRectReadOnly bindings require JavaScriptCore')
	}
}
