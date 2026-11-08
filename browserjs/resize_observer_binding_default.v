module browserjs

$if !darwin && !linux && !windows {
	pub fn (mut runtime Runtime) install_resize_observer_binding(_ ?ResizeObserverBeforeObserveHook) ! {
		return error('ResizeObserver requires JavaScriptCore')
	}
}
