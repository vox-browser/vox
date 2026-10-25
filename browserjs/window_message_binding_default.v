module browserjs

$if !darwin && !linux {
	pub fn (mut runtime Runtime) install_window_message_binding() ! {
		return error('Window messaging requires JavaScriptCore')
	}
}
