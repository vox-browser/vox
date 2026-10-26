module browserjs

$if !darwin && !linux {
	pub fn (mut runtime Runtime) install_microtask_binding() ! {
		return error('Native microtask binding requires JavaScriptCore')
	}
}
