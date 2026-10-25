module browserjs

$if !darwin && !linux {
	pub fn (mut runtime Runtime) install_window_media_query_binding() ! {
		return error('Window.matchMedia JavaScriptCore bindings are unavailable on this platform')
	}
}
