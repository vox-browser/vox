module browserjs

$if !darwin && !linux {
	pub fn (mut runtime Runtime) install_microtask_binding() ! {
		return error('Native microtask binding requires JavaScriptCore')
	}
	pub fn (mut runtime Runtime) enqueue_javascript_microtask(_ voidptr) ! {
		return error('Native microtask binding requires JavaScriptCore')
	}
}
