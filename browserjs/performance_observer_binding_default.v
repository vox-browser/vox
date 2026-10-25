module browserjs

$if !darwin && !linux {
	pub fn (mut runtime Runtime) install_performance_observer_binding() ! {
		return error('Native PerformanceObserver bindings require JavaScriptCore')
	}
}
