module browserjs

// Initialize a host closure with JSON data without compiling an escaped copy
// of that data as JavaScript source. The engine parser preserves JSON property
// names, including __proto__, and cannot invoke a replaced global JSON.parse.
pub fn (mut runtime Runtime) initialize_host_from_json(factory_source string, json_text string) ! {
	$if darwin || linux || windows {
		runtime.initialize_javascript_core_host_from_json(factory_source, json_text)!
	} $else {
		return error('Native JSON host initialization requires JavaScriptCore')
	}
}
