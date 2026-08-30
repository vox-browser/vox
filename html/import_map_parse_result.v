// Copyright (c) 2024, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/Scripting/ImportMapParseResult.{h,cpp}.
module html

import dom

@[heap]
pub struct ImportMapParseResult {
mut:
	import_map_       ?&ImportMap
	error_to_rethrow_ ?string
}

// https://html.spec.whatwg.org/multipage/webappapis.html#create-an-import-map-parse-result
pub fn ImportMapParseResult.create(input string, base_url dom.URL) &ImportMapParseResult {
	mut result := &ImportMapParseResult{}
	// Parse while catching the exception into the result record.
	parsed := parse_import_map_string(input, base_url) or {
		result.error_to_rethrow_ = err.msg()
		return result
	}
	result.import_map_ = &ImportMap{
		imports:   parsed.imports
		scopes:    parsed.scopes
		integrity: parsed.integrity
	}
	return result
}

pub fn (result &ImportMapParseResult) import_map() ?&ImportMap {
	return result.import_map_
}

pub fn (result &ImportMapParseResult) error_to_rethrow() ?string {
	return result.error_to_rethrow_
}

pub fn (mut result ImportMapParseResult) set_import_map(import_map ?&ImportMap) {
	result.import_map_ = import_map
}

pub fn (mut result ImportMapParseResult) set_error_to_rethrow(error_to_rethrow ?string) {
	result.error_to_rethrow_ = error_to_rethrow
}

// https://html.spec.whatwg.org/multipage/webappapis.html#register-an-import-map
// Reporting a WebIDL/JS exception is represented by returning it as a V error;
// callers at a realm boundary can report it through their host runtime.
pub fn (result &ImportMapParseResult) register_import_map(mut existing_import_map ImportMap, resolved_module_set []ResolvedModuleRecord, warn ImportMapWarningHandler) ! {
	if message := result.error_to_rethrow_ {
		return error(message)
	}
	new_import_map := result.import_map_ or { return error('import map parse result has no value') }
	merge_existing_and_new_import_maps(mut existing_import_map, new_import_map,
		resolved_module_set, warn)
}
