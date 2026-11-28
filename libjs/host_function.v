module libjs

// Embedders compiling an HTML event handler supply its actual ObjectEnvironment
// chain. Unlike Function(), it must not discard that chain or add a private
// named-expression binding. Parsing still enforces one complete FunctionBody.
pub fn create_host_function(mut vm VM, source string, filename string, environment Environment) !Value {
	text := '(' + source + '\n)'
	mut script := Script.parse(text, vm.realm(), filename, unsafe { nil }) or {
		return vm.throw_error(.syntax_error, err.msg())
	}
	program := script.parsed.program.kind.program_data or { return error('Missing handler program') }
	if program.scope.children.len != 1 { return vm.throw_error(.syntax_error, 'Invalid handler source') }
	expression := program.scope.children[0].kind.expression or { return vm.throw_error(.syntax_error, 'Invalid handler expression') }
	if expression.kind.tag != .function_expr { return vm.throw_error(.syntax_error, 'Invalid handler function') }
	data := script.parsed.function_table.get(expression.kind.function_id)
	if data.source_text_start != 1 || data.source_text_end != u32(utf16_string(text).len() - 2) {
		return vm.throw_error(.syntax_error, 'Invalid handler function boundary')
	}
	executable := script.compile(mut vm)!
	object := create_ecmascript_function_in_environment(mut vm, executable, data, false, none, true,
		environment, none, ScriptOrModule{})!
	return Value.from_object(object)
}
