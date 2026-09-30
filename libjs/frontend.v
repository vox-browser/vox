module libjs

pub enum SourceType {
	script
	module
}

pub struct SyntaxDiagnostic {
pub:
	message string
	line    u32
	column  u32
}

@[heap]
pub struct ParsedSource {
	program        Statement
	function_table FunctionTable
pub:
	source_text         string
	diagnostics         []SyntaxDiagnostic
	is_strict_mode      bool
	has_top_level_await bool
	// An embedding VM may accept deeper input than this frontend's stack budget.
	reached_recursion_limit bool
}

// The translated frontend is usable independently of the browser's VM host.
// Syntax diagnostics include both parsing and lexical-scope early errors.
pub fn parse_source(source string, source_type SourceType) &ParsedSource {
	program_type := if source_type == .module { ProgramType.module } else { ProgramType.script }
	mut parser := Parser.new(utf16(source), program_type)
	program := parser.parse_program(false)
	if !parser.has_errors() {
		parser.scope_collector.analyze(false)
	}
	mut diagnostics := []SyntaxDiagnostic{}
	for diagnostic in parser.errors {
		diagnostics << SyntaxDiagnostic{diagnostic.message, diagnostic.line, diagnostic.column}
	}
	for diagnostic in parser.scope_collector.drain_errors() {
		diagnostics << SyntaxDiagnostic{diagnostic.message, diagnostic.line, diagnostic.column}
	}
	data := program.kind.program_data or { panic('parser returned a non-program root') }
	return &ParsedSource{
		source_text:             source
		program:                 program
		function_table:          parser.function_table
		diagnostics:             diagnostics
		is_strict_mode:          data.is_strict_mode
		has_top_level_await:     data.has_top_level_await
		reached_recursion_limit: parser.recursion_limit_reached
	}
}

pub fn (source &ParsedSource) has_errors() bool {
	return source.diagnostics.len != 0
}

pub fn (source &ParsedSource) dump_ast() !string {
	if source.has_errors() {
		return error('Cannot dump a JavaScript program with syntax errors')
	}
	return dump_program_to_string(&source.program, &source.function_table)
}
