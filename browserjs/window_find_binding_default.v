module browserjs

$if !darwin && !linux && !windows {
	pub fn (mut runtime Runtime) install_window_find_binding(_ ?WindowFindBeforeSearchHook) ! {
		return error('Window.find JavaScriptCore bindings are available on macOS only')
	}
}
