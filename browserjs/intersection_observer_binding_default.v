module browserjs

$if !darwin && !linux && !windows {
	pub fn (mut runtime Runtime) install_intersection_observer_binding(_ ?IntersectionObserverBeforeObserveHook) ! {
		return error('Native IntersectionObserver bindings require JavaScriptCore')
	}
}
