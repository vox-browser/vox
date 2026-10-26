module browserjs

$if !darwin && !linux {
	pub fn (mut runtime Runtime) install_text_decoder_binding() ! {
		return error('Native TextDecoder binding requires JavaScriptCore')
	}
}
