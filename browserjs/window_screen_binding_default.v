module browserjs

$if !darwin && !linux {
	pub fn (mut runtime Runtime) install_window_screen_binding() ! {
		return error('Native Screen binding requires JavaScriptCore')
	}
}
