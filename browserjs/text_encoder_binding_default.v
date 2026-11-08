module browserjs

$if !darwin && !linux && !windows {
	pub fn (mut runtime Runtime) install_text_encoder_binding() ! {
		return error('Native TextEncoder binding requires JavaScriptCore')
	}
}
