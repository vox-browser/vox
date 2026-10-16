module browserjs

$if !darwin && !linux {
	pub fn (mut runtime Runtime) install_window_current_event_binding() ! {
		return error('Window.event JavaScriptCore bindings are available on macOS only')
	}
}
