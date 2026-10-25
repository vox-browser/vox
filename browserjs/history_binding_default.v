module browserjs

$if !darwin && !linux {
	pub fn (mut runtime Runtime) install_history_binding() ! {
		return error('History JavaScriptCore bindings are unavailable on this platform')
	}
}
