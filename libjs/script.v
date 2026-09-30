module libjs

// Translated from the Script Record in LibJS/Script.{h,cpp}. Parsing runs through
// the translated frontend; bytecode generation, cached executables, and
// GlobalDeclarationInstantiation remain part of the pending interpreter work.

pub struct ScriptParseError {
	Error
pub:
	diagnostics []SyntaxDiagnostic
}

pub fn (err ScriptParseError) msg() string {
	if err.diagnostics.len == 0 {
		return 'Script parse error'
	}
	first := err.diagnostics[0]
	return 'SyntaxError: ${first.line}:${first.column}: ${first.message}'
}

// 16.1.4 Script Records, https://tc39.es/ecma262/#sec-script-records
@[heap]
pub struct Script {
pub mut:
	realm          &Realm                // [[Realm]]
	filename       string
	loaded_modules []LoadedModuleRequest // [[LoadedModules]]
	host_defined   voidptr               // [[HostDefined]]
	parsed         &ParsedSource         // [[ECMAScriptCode]]
	is_strict_mode bool
}

// 16.1.5 ParseScript ( sourceText, realm, hostDefined ), https://tc39.es/ecma262/#sec-parse-script
pub fn Script.parse(source_text string, realm &Realm, filename string, host_defined voidptr) !&Script {
	// 1. Let script be ParseText(sourceText, Script).
	parsed := parse_source(source_text, .script)
	// 2. If script is a List of errors, return script.
	if parsed.has_errors() {
		return ScriptParseError{
			diagnostics: parsed.diagnostics
		}
	}
	// 3. Return Script Record { [[Realm]]: realm, [[ECMAScriptCode]]: script, [[LoadedModules]]: « », [[HostDefined]]: hostDefined }.
	return &Script{
		realm:          realm
		filename:       filename
		host_defined:   host_defined
		parsed:         parsed
		is_strict_mode: parsed.is_strict_mode
	}
}
