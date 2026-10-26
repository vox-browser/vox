module browserjs

$if !darwin && !linux {
	pub fn (mut runtime Runtime) install_resize_observer_binding(_ ?ResizeObserverBeforeObserveHook) ! {
		return error('ResizeObserver requires JavaScriptCore')
	}
}
