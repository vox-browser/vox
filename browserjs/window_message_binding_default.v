module browserjs

$if !darwin && !linux && !windows {
	pub fn (mut runtime Runtime) install_window_message_binding() ! {
		return error('Window messaging requires JavaScriptCore')
	}
}
