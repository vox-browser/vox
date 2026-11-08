module browserjs

$if !darwin && !linux && !windows {
	pub fn (mut runtime Runtime) install_text_decoder_binding() ! {
		return error('Native TextDecoder binding requires JavaScriptCore')
	}
}
