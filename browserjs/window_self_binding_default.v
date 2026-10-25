module browserjs

$if !darwin && !linux {
	pub fn (mut runtime Runtime) install_window_self_binding() ! {
		return error('Window.self JavaScriptCore bindings are unavailable on this platform')
	}
}
