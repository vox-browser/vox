module browserjs

$if !darwin && !linux {
	pub fn (mut runtime Runtime) install_indexed_db_binding() ! {
		return error('IndexedDB bindings require JavaScriptCore')
	}
}
