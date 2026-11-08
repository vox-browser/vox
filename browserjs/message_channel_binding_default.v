module browserjs

$if !darwin && !linux && !windows {
	pub fn (mut runtime Runtime) install_message_channel_binding() ! {
		return error('MessageChannel binding requires JavaScriptCore')
	}
}
