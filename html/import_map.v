// Copyright (c) 2024, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HTML/Scripting/ImportMap.cpp and the module-specifier resolution
// algorithms from HTML/Scripting/Fetching.cpp.
module html

import dom
import infra
import x.json2

pub type ImportMapWarningHandler = fn(string)

pub struct ModuleSpecifierResolution {
pub:
	specifier string
	url       ?dom.URL
}

pub struct ModuleSpecifierMap {
pub mut:
	entries []ModuleSpecifierResolution
}

pub struct ImportMapScope {
pub:
	prefix string
pub mut:
	imports ModuleSpecifierMap
}

pub struct ModuleIntegrityEntry {
pub:
	url       dom.URL
	integrity string
}

$if test {
	fn value_is_ordered_map(value json2.Any) bool {
		return value is map[string]json2.Any
	}
}

@[heap]
pub struct ImportMap {
pub mut:
	imports   ModuleSpecifierMap
	scopes    []ImportMapScope
	integrity []ModuleIntegrityEntry
}

pub fn (import_map &ImportMap) imports() ModuleSpecifierMap {
	return import_map.imports
}

pub fn (mut import_map ImportMap) set_imports(value ModuleSpecifierMap) {
	import_map.imports = value
}

pub fn (import_map &ImportMap) scopes() []ImportMapScope {
	return import_map.scopes.clone()
}

pub fn (mut import_map ImportMap) set_scopes(value []ImportMapScope) {
	import_map.scopes = value.clone()
}

pub fn (import_map &ImportMap) integrity() []ModuleIntegrityEntry {
	return import_map.integrity.clone()
}

pub fn (mut import_map ImportMap) set_integrity(value []ModuleIntegrityEntry) {
	import_map.integrity = value.clone()
}

pub struct ImportsMatchResult {
pub:
	matched bool
	url     ?dom.URL
}

pub struct ResolvedModuleRecord {
pub:
	serialized_base_url                           ?string
	specifier                                     string
	specifier_is_null_or_url_like_that_is_special bool
}

// Keep the input normalization alongside the resolved target: import maps may
// remap it to a different URL, but resolved-module bookkeeping uses the input.
pub struct ResolvedModuleSpecifier {
pub:
	url                  dom.URL
	normalized_specifier string
	url_like             ?dom.URL
}

fn ignore_import_map_warning(message string) {
	_ = message
}

fn sort_module_specifier_map(mut specifier_map ModuleSpecifierMap) {
	specifier_map.entries.sort_with_compare(fn (a &ModuleSpecifierResolution, b &ModuleSpecifierResolution) int {
		if infra.code_unit_less_than(a.specifier, b.specifier) {
			return 1
		}
		if infra.code_unit_less_than(b.specifier, a.specifier) {
			return -1
		}
		return 0
	})
}

fn sort_import_map_scopes(mut scopes []ImportMapScope) {
	scopes.sort_with_compare(fn (a &ImportMapScope, b &ImportMapScope) int {
		if infra.code_unit_less_than(a.prefix, b.prefix) {
			return 1
		}
		if infra.code_unit_less_than(b.prefix, a.prefix) {
			return -1
		}
		return 0
	})
}

fn (mut specifier_map ModuleSpecifierMap) set(specifier string, url ?dom.URL) {
	for index, entry in specifier_map.entries {
		if entry.specifier == specifier {
			specifier_map.entries[index] = ModuleSpecifierResolution{specifier, url}
			return
		}
	}
	specifier_map.entries << ModuleSpecifierResolution{specifier, url}
}

fn (specifier_map &ModuleSpecifierMap) contains(specifier string) bool {
	for entry in specifier_map.entries {
		if entry.specifier == specifier {
			return true
		}
	}
	return false
}

fn (integrity []ModuleIntegrityEntry) contains_url(url dom.URL) bool {
	for entry in integrity {
		if entry.url == url {
			return true
		}
	}
	return false
}

fn parse_absolute_url(input string) ?dom.URL {
	parsed := dom.dom_url_parse(input, dom.url_about_blank(), 'utf-8') or { return none }
	// A URL-like module specifier that is not path-relative must supply its own
	// scheme; the about:blank base must not turn a bare specifier into a URL.
	colon := input.index_u8(`:`)
	if colon <= 0 {
		return none
	}
	return parsed
}

// https://html.spec.whatwg.org/multipage/webappapis.html#resolving-a-url-like-module-specifier
pub fn resolve_url_like_module_specifier(specifier string, base_url dom.URL) ?dom.URL {
	if specifier.starts_with('/') || specifier.starts_with('./') || specifier.starts_with('../') {
		return dom.dom_url_parse(specifier, base_url, 'utf-8')
	}
	return parse_absolute_url(specifier)
}

// https://html.spec.whatwg.org/multipage/webappapis.html#normalizing-a-specifier-key
pub fn normalize_specifier_key_with_warnings(specifier_key string, base_url dom.URL, warn ImportMapWarningHandler) ?string {
	if specifier_key.len == 0 {
		warn('Specifier keys may not be empty')
		return none
	}
	if url := resolve_url_like_module_specifier(specifier_key, base_url) {
		return url.serialize()
	}
	return specifier_key
}

pub fn normalize_specifier_key(specifier_key string, base_url dom.URL) ?string {
	return normalize_specifier_key_with_warnings(specifier_key, base_url, ignore_import_map_warning)
}

// https://html.spec.whatwg.org/multipage/webappapis.html#sorting-and-normalizing-a-module-specifier-map
pub fn sort_and_normalise_module_specifier_map(original_map map[string]json2.Any, base_url dom.URL, warn ImportMapWarningHandler) ModuleSpecifierMap {
	mut normalized := ModuleSpecifierMap{}
	for specifier_key, value in original_map {
		normalized_specifier_key := normalize_specifier_key_with_warnings(specifier_key, base_url, warn) or {
			continue
		}
		if value !is string {
			warn('Addresses need to be strings')
			normalized.set(normalized_specifier_key, none)
			continue
		}
		address := value as string
		address_url := resolve_url_like_module_specifier(address, base_url) or {
			warn('Address was invalid')
			normalized.set(normalized_specifier_key, none)
			continue
		}
		if specifier_key.ends_with('/') && !address_url.serialize().ends_with('/') {
			warn('An invalid address was given for the specifier key (${specifier_key}); since specifierKey ends with a slash, the address needs to as well')
			normalized.set(normalized_specifier_key, none)
			continue
		}
		normalized.set(normalized_specifier_key, address_url)
	}
	sort_module_specifier_map(mut normalized)
	return normalized
}

// https://html.spec.whatwg.org/multipage/webappapis.html#sorting-and-normalizing-scopes
pub fn sort_and_normalise_scopes(original_map map[string]json2.Any, base_url dom.URL, warn ImportMapWarningHandler) ![]ImportMapScope {
	mut normalized := []ImportMapScope{}
	for scope_prefix, potential_specifier_map in original_map {
		if potential_specifier_map !is map[string]json2.Any {
			return error("The value of the scope with the prefix '${scope_prefix}' needs to be a JSON object.")
		}
		specifier_object := potential_specifier_map as map[string]json2.Any
		scope_prefix_url := dom.dom_url_parse(scope_prefix, base_url, 'utf-8') or {
			warn('The scope prefix URL (${scope_prefix}) was not parseable')
			continue
		}
		normalized << ImportMapScope{
			prefix: scope_prefix_url.serialize()
			imports: sort_and_normalise_module_specifier_map(specifier_object, base_url, warn)
		}
	}
	sort_import_map_scopes(mut normalized)
	return normalized
}

// https://html.spec.whatwg.org/multipage/webappapis.html#normalizing-a-module-integrity-map
pub fn normalize_module_integrity_map(original_map map[string]json2.Any, base_url dom.URL, warn ImportMapWarningHandler) []ModuleIntegrityEntry {
	mut normalized := []ModuleIntegrityEntry{}
	for key, value in original_map {
		resolved_url := resolve_url_like_module_specifier(key, base_url) or {
			warn('Failed to resolve key (${key})')
			continue
		}
		if value !is string {
			warn("Integrity metadata value for '${key}' needs to be a string")
			continue
		}
		integrity := value as string
		normalized << ModuleIntegrityEntry{resolved_url, integrity}
	}
	return normalized
}

// https://html.spec.whatwg.org/multipage/webappapis.html#parse-an-import-map-string
pub fn parse_import_map_string_with_warnings(input string, base_url dom.URL, warn ImportMapWarningHandler) !ImportMap {
	parsed := infra.parse_json_string_to_javascript_value(input)!
	if parsed !is map[string]json2.Any {
		return error('The top-level value of an importmap needs to be a JSON object.')
	}
	parsed_object := parsed as map[string]json2.Any
	mut import_map := ImportMap{}
	if imports := parsed_object['imports'] {
		if imports !is map[string]json2.Any {
			return error("The 'imports' top-level value of an importmap needs to be a JSON object.")
		}
		imports_object := imports as map[string]json2.Any
		import_map.imports = sort_and_normalise_module_specifier_map(imports_object, base_url, warn)
	}
	if scopes := parsed_object['scopes'] {
		if scopes !is map[string]json2.Any {
			return error("The 'scopes' top-level value of an importmap needs to be a JSON object.")
		}
		scopes_object := scopes as map[string]json2.Any
		import_map.scopes = sort_and_normalise_scopes(scopes_object, base_url, warn)!
	}
	if integrity := parsed_object['integrity'] {
		if integrity !is map[string]json2.Any {
			return error("The 'integrity' top-level value of an importmap needs to be a JSON object.")
		}
		integrity_object := integrity as map[string]json2.Any
		import_map.integrity = normalize_module_integrity_map(integrity_object, base_url, warn)
	}
	for key, _ in parsed_object {
		if key !in ['imports', 'scopes', 'integrity'] {
			warn('An invalid top-level key (${key}) was present in the import map')
		}
	}
	return import_map
}

pub fn parse_import_map_string(input string, base_url dom.URL) !ImportMap {
	return parse_import_map_string_with_warnings(input, base_url, ignore_import_map_warning)
}

fn url_is_special(url dom.URL) bool {
	return url.scheme() in ['ftp', 'file', 'http', 'https', 'ws', 'wss']
}

// https://html.spec.whatwg.org/multipage/webappapis.html#resolving-an-imports-match
pub fn resolve_imports_match(normalized_specifier string, as_url ?dom.URL, specifier_map &ModuleSpecifierMap) !ImportsMatchResult {
	for entry in specifier_map.entries {
		if entry.specifier == normalized_specifier {
			resolution_result := entry.url or {
				return error("Import resolution of '${entry.specifier}' was blocked by a null entry.")
			}

			return ImportsMatchResult{true, resolution_result}
		}
		if entry.specifier.ends_with('/') && normalized_specifier.starts_with(entry.specifier) && (as_url == none || url_is_special(as_url or {
			dom.URL{}})) {
			resolution_result := entry.url or {
				return error("Import resolution of '${entry.specifier}' was blocked by a null entry.")
			}

			after_prefix := normalized_specifier[entry.specifier.len..]
			url := dom.dom_url_parse(after_prefix, resolution_result, 'utf-8') or {
				return error("Could not resolve '${normalized_specifier}' as the after prefix portion could not be URL-parsed.")
			}
			if !url.serialize().starts_with(resolution_result.serialize()) {
				return error("Could not resolve '${normalized_specifier}' as it backtracks above its prefix specifierKey.")
			}
			return ImportsMatchResult{true, url}
		}
	}
	return ImportsMatchResult{}
}

// Core of https://html.spec.whatwg.org/multipage/webappapis.html#resolve-a-module-specifier.
// Realm bookkeeping is represented separately by ResolvedModuleRecord.
pub fn resolve_module_specifier(import_map &ImportMap, base_url dom.URL, specifier string) !dom.URL {
	return resolve_module_specifier_with_metadata(import_map, base_url, specifier)!.url
}

// Resolve once for callers that also publish a ResolvedModuleRecord. The bare
// specifier is copied into the result's owner just like a serialized URL.
pub fn resolve_module_specifier_with_metadata(import_map &ImportMap, base_url dom.URL, specifier string) !ResolvedModuleSpecifier {
	serialized_base_url := base_url.serialize()
	as_url := resolve_url_like_module_specifier(specifier, base_url)
	normalized_specifier := if url := as_url { url.serialize() } else { specifier.clone() }
	for scope in import_map.scopes {
		if scope.prefix == serialized_base_url || (scope.prefix.ends_with('/') && serialized_base_url.starts_with(scope.prefix)) {
			matched := resolve_imports_match(normalized_specifier, as_url, &scope.imports)!
			if matched.matched {
				return ResolvedModuleSpecifier{
					url: matched.url or { return error('Import map produced a null URL') }
					normalized_specifier: normalized_specifier
					url_like: as_url
				}
			}
		}
	}
	matched := resolve_imports_match(normalized_specifier, as_url, &import_map.imports)!
	if matched.matched {
		return ResolvedModuleSpecifier{
			url: matched.url or { return error('Import map produced a null URL') }
			normalized_specifier: normalized_specifier
			url_like: as_url
		}
	}
	if url := as_url {
		return ResolvedModuleSpecifier{url: url, normalized_specifier: normalized_specifier, url_like: as_url}
	}
	return error("Failed to resolve non relative module specifier '${specifier}' from an import map.")
}

fn merge_module_specifier_maps(new_map &ModuleSpecifierMap, old_map &ModuleSpecifierMap, warn ImportMapWarningHandler) ModuleSpecifierMap {
	mut merged := ModuleSpecifierMap{
		entries: old_map.entries.clone()
	}
	for entry in new_map.entries {
		if old_map.contains(entry.specifier) {
			warn("An import map rule for specifier '${entry.specifier}' was ignored as one was already present in the existing import map")
			continue
		}
		merged.set(entry.specifier, entry.url)
	}
	sort_module_specifier_map(mut merged)
	return merged
}

fn record_matches_scope(record ResolvedModuleRecord, scope_prefix string) bool {
	serialized_base_url := record.serialized_base_url or { return false }
	return scope_prefix == serialized_base_url || (scope_prefix.ends_with('/') && serialized_base_url.starts_with(scope_prefix))
}

// https://html.spec.whatwg.org/multipage/webappapis.html#merge-existing-and-new-import-maps
pub fn merge_existing_and_new_import_maps(mut old_import_map ImportMap, new_import_map &ImportMap, resolved_module_set []ResolvedModuleRecord, warn ImportMapWarningHandler) {
	for new_scope in new_import_map.scopes {
		mut scope_imports := ModuleSpecifierMap{
			entries: new_scope.imports.entries.clone()
		}
		for record in resolved_module_set {
			if !record_matches_scope(record, new_scope.prefix) {
				continue
			}
			for index := scope_imports.entries.len - 1; index >= 0; index-- {
				specifier_key := scope_imports.entries[index].specifier
				if specifier_key == record.specifier || (specifier_key.ends_with('/') && record.specifier.starts_with(specifier_key) && record.specifier_is_null_or_url_like_that_is_special) {
					warn("An import map rule for specifier '${specifier_key}' was ignored as one was already present in the existing import map")
					scope_imports.entries.delete(index)
				}
			}
		}
		mut found_scope := false
		for index, old_scope in old_import_map.scopes {
			if old_scope.prefix == new_scope.prefix {
				old_import_map.scopes[index].imports = merge_module_specifier_maps(&scope_imports, &old_scope.imports, warn)
				found_scope = true
				break
			}
		}
		if !found_scope {
			old_import_map.scopes << ImportMapScope{new_scope.prefix, scope_imports}
		}
	}
	sort_import_map_scopes(mut old_import_map.scopes)
	for entry in new_import_map.integrity {
		if old_import_map.integrity.contains_url(entry.url) {
			warn("An import map integrity rule for url '${entry.url.serialize()}' was ignored as one was already present in the existing import map")
			continue
		}
		old_import_map.integrity << entry
	}
	mut new_imports := ModuleSpecifierMap{
		entries: new_import_map.imports.entries.clone()
	}
	for record in resolved_module_set {
		for index := new_imports.entries.len - 1; index >= 0; index-- {
			if new_imports.entries[index].specifier.starts_with(record.specifier) {
				warn("An import map rule for specifier '${new_imports.entries[index].specifier}' was ignored as one was already present in the existing import map")
				new_imports.entries.delete(index)
			}
		}
	}
	old_import_map.imports = merge_module_specifier_maps(&new_imports, &old_import_map.imports, warn)
}
