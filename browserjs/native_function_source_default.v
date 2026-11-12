module browserjs

$if !darwin && !linux && !windows {
	pub fn (mut runtime Runtime) install_platform_function_source(_ string) ! {
		return error('Platform function source requires JavaScriptCore')
	}
}
