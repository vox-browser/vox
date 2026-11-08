module browserjs

$if !darwin && !linux && !windows {
	pub fn (mut runtime Runtime) install_window_viewport_binding() ! {
		return error('Window viewport JavaScriptCore bindings are unavailable on this platform')
	}
}
