module browserjs

$if !darwin && !linux {
	pub fn (mut runtime Runtime) install_performance_binding() ! {
		return error('Native Performance bindings require JavaScriptCore')
	}
}
