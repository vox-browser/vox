module browserjs

$if !darwin && !linux {
	pub fn (mut runtime Runtime) install_text_encoder_binding() ! {
		return error('Native TextEncoder binding requires JavaScriptCore')
	}
}
