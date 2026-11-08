module browserjs

$if !darwin && !linux && !windows {
	pub fn (mut runtime Runtime) install_window_event_handler_binding() ! {
		return error('Window JavaScriptCore event handler bindings are available on macOS only')
	}
}
