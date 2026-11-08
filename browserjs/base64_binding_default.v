module browserjs

$if !darwin && !linux && !windows {
	pub fn (mut runtime Runtime) install_base64_binding() ! {
		return error('Native base64 binding requires JavaScriptCore')
	}
}
