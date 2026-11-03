module browserjs

$if !darwin && !linux {
	pub fn (mut runtime Runtime) install_scroll_promise_binding(_ ScrollPromiseResolver) ! {
		return error('Scroll Promise bindings require JavaScriptCore')
	}
}
