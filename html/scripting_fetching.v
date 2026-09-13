// Copyright (c) 2022-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HTML/Scripting/Fetching.{h,cpp}. Network I/O and JavaScript
// parsing remain typed host boundaries; request construction, decoding, module
// map state, graph traversal, and completion ordering are implemented here.
module html

import crypto.sha256
import dom
import encoding
import fetch
import http

pub enum TopLevelModule {
	no
	yes
}

pub struct ModuleRequestAttribute {
pub:
	key   string
	value string
}

pub struct ModuleRequest {
pub:
	specifier  string
	attributes []ModuleRequestAttribute
}

pub struct ScriptFetchOptions {
pub mut:
	cryptographic_nonce string
	integrity_metadata  string
	parser_metadata     fetch.ParserMetadata = .not_parser_inserted
	credentials_mode    fetch.CredentialsMode = .same_origin
	referrer_policy     string
	render_blocking     bool
	fetch_priority      fetch.Priority = .auto
}

pub type OnFetchScriptComplete = fn (?&Script)

// The C++ implementation delivers a response through a consume-body callback.
// V hosts return that response synchronously; the HTML algorithm immediately
// performs the same consume-body steps before returning to the caller.
pub type PerformTheFetchHook = fn (&fetch.Request, TopLevelModule) !&fetch.Response

struct ModuleScriptFetchResult {
	module_script ?&ModuleScript
}

struct BytecodeCacheContext {
	url             dom.URL
	method          string
	request_headers &http.HeaderList
}

pub enum ScriptProgramType {
	script
	module
}

pub struct ParsedProgram {
pub:
	program_type       ScriptProgramType
	line_number_offset usize
	error              ?string
}

pub type OffThreadParseComplete = fn (ParsedProgram, string)

@[heap]
pub struct SharedFunctionInstanceData {
pub mut:
	executable        ?&ScriptExecutable
	rust_function_ast ?string
}

@[heap]
pub struct ScriptExecutable {
pub mut:
	shared_function_data []&SharedFunctionInstanceData
}

pub struct CompiledProgram {
pub:
	program_type       ScriptProgramType
	line_number_offset usize
	executable         ?&ScriptExecutable
}

pub struct OffThreadCompiledProgram {
pub:
	parsed   ?ParsedProgram
	compiled ?CompiledProgram
}

pub type OffThreadCompileComplete = fn (OffThreadCompiledProgram, string)

// Runtime-neutral boundaries for LibJS top-level and lazy-function bytecode
// compilation. ScriptExecutable preserves the ownership graph needed to install
// completed lazy functions on the main event loop.
pub type ScriptCompileHook = fn (string, string, usize, ScriptProgramType) !&ScriptExecutable

pub type ScriptFunctionCompileHook = fn (string, usize) !&ScriptExecutable

pub type ScriptBytecodeCacheCompileHook = fn (string, string, ScriptProgramType, usize) ![]u8

pub type ScriptBytecodeCacheStoreHook = fn (dom.URL, string, &http.HeaderList, []u8) !

// V's runtime-neutral parser is a host hook. Invoke it outside the script
// execution context, then deliver completion and drain queued microtasks just
// as Ladybird's event-loop bounce does.
pub fn parse_off_thread(source_code string, program_type ScriptProgramType, line_number_offset usize, parser ScriptParseHook, on_parsed OffThreadParseComplete) {
	mut parse_error := ?string(none)
	parser(source_code, '', line_number_offset) or { parse_error = err.msg() }
	on_parsed(ParsedProgram{
		program_type: program_type
		line_number_offset: line_number_offset
		error: parse_error
	}, source_code)
	perform_a_microtask_checkpoint()
}

fn compile_source_off_thread(source_code string, program_type ScriptProgramType, line_number_offset usize, compiler ScriptCompileHook) OffThreadCompiledProgram {
	executable := compiler(source_code, '', line_number_offset, program_type) or {
		return OffThreadCompiledProgram{
			parsed: ParsedProgram{
				program_type: program_type
				line_number_offset: line_number_offset
				error: err.msg()
			}
		}
	}
	return OffThreadCompiledProgram{
		compiled: CompiledProgram{
			program_type: program_type
			line_number_offset: line_number_offset
			executable: executable
		}
	}
}

// LibJS owns the real bytecode artifact in Ladybird. The V host compiler
// validates and compiles outside the script execution context, represented by
// CompiledProgram, before completion materializes the script on the main loop.
pub fn compile_off_thread(source_code string, program_type ScriptProgramType, line_number_offset usize, compiler ScriptCompileHook, on_compiled OffThreadCompileComplete) {
	result := compile_source_off_thread(source_code, program_type, line_number_offset, compiler)
	on_compiled(result, source_code)
	perform_a_microtask_checkpoint()
}

struct CompiledFunctionResult {
	executable ?&ScriptExecutable
}

fn scripting_source_length_in_code_units(source string) usize {
	return usize(scripting_source_utf16_bytes(source).len / 2)
}

fn scripting_source_utf16_bytes(source string) []u8 {
	mut bytes := []u8{cap: source.len * 2}
	for code_point in source.runes() {
		if code_point <= 0xffff {
			unit := u16(code_point)
			bytes << u8(unit & 0xff)
			bytes << u8(unit >> 8)
			continue
		}
		value := u32(code_point) - 0x10000
		high := u16(0xd800 + (value >> 10))
		low := u16(0xdc00 + (value & 0x3ff))
		bytes << u8(high & 0xff)
		bytes << u8(high >> 8)
		bytes << u8(low & 0xff)
		bytes << u8(low >> 8)
	}
	return bytes
}

const scripting_bytecode_cache_magic = 'VOX2BC01'

pub fn bytecode_cache_source_hash(source_code string) []u8 {
	return sha256.sum(scripting_source_utf16_bytes(source_code))
}

pub fn serialize_compiled_program_for_bytecode_cache(bytecode []u8, program_type ScriptProgramType, source_code string) []u8 {
	mut blob := scripting_bytecode_cache_magic.bytes()
	blob << if program_type == .script { u8(0) } else { u8(1) }
	blob << bytecode_cache_source_hash(source_code)
	blob << bytecode
	return blob
}

pub fn decode_bytecode_cache_blob(blob []u8, program_type ScriptProgramType, source_code string) ?[]u8 {
	header_length := scripting_bytecode_cache_magic.len + 1 + sha256.size
	if blob.len < header_length
		|| blob[..scripting_bytecode_cache_magic.len].bytestr() != scripting_bytecode_cache_magic {
		return none
	}
	expected_program_type := if program_type == .script { u8(0) } else { u8(1) }
	if blob[scripting_bytecode_cache_magic.len] != expected_program_type {
		return none
	}
	hash_start := scripting_bytecode_cache_magic.len + 1
	hash_end := hash_start + sha256.size
	if blob[hash_start..hash_end] != bytecode_cache_source_hash(source_code) {
		return none
	}
	return blob[header_length..].clone()
}

fn scripting_clone_header_list(source &http.HeaderList) &http.HeaderList {
	mut cloned := http.HeaderList.create()
	for header in source.headers() {
		cloned.append(header)
	}
	return cloned
}

fn bytecode_cache_context_for_request(request &fetch.Request, response_url dom.URL, settings &EnvironmentSettingsObject) ?BytecodeCacheContext {
	if !fetch.is_http_or_https_scheme(response_url.scheme()) {
		return none
	}
	if settings.script_bytecode_cache_store_hook() == none {
		return none
	}
	return BytecodeCacheContext{
		url: response_url
		method: request.method
		request_headers: scripting_clone_header_list(request.header_list)
	}
}

// Reparse and fully compile solely for cache generation. The execution path
// already owns its latency-trimmed artifact, so failure here never changes the
// script delivered to the caller.
fn schedule_bytecode_cache_generation(source_code string, filename string, program_type ScriptProgramType, line_number_offset usize, context BytecodeCacheContext, settings &EnvironmentSettingsObject) {
	compiler := settings.script_bytecode_cache_compile_hook() or { return }
	bytecode := compiler(source_code, filename, program_type, line_number_offset) or { return }
	if bytecode.len == 0 {
		return
	}
	blob := serialize_compiled_program_for_bytecode_cache(bytecode, program_type, source_code)
	if store := settings.script_bytecode_cache_store_hook() {
		store(context.url, context.method, context.request_headers, blob) or {}
	}
}

// After top-level bytecode is handed back to the main event loop, compile all
// remaining lazy function payloads away from script execution. Completed
// bytecode is installed only while the shared function is still lazy. If the
// main thread compiled it first, discard the stale result and scan that newer
// executable so its nested lazy functions are still compiled.
pub fn compile_remaining_functions_off_thread(mut executable ScriptExecutable, source_code string, compiler ScriptFunctionCompileHook) {
	mut shared_data_roots := []&SharedFunctionInstanceData{}
	mut function_asts := []string{}
	for shared_data in executable.shared_function_data {
		if shared_data.executable != none {
			continue
		}
		function_ast := shared_data.rust_function_ast or { continue }
		shared_data_roots << shared_data
		function_asts << function_ast.clone()
	}
	if function_asts.len == 0 {
		return
	}

	source_length := scripting_source_length_in_code_units(source_code)
	mut compiled_functions := []CompiledFunctionResult{cap: function_asts.len}
	for function_ast in function_asts {
		compiled := compiler(function_ast, source_length) or {
			compiled_functions << CompiledFunctionResult{}
			continue
		}
		compiled_functions << CompiledFunctionResult{
			executable: compiled
		}
	}

	assert compiled_functions.len == shared_data_roots.len
	for i, result in compiled_functions {
		compiled := result.executable or { continue }
		mut shared_data := unsafe { &SharedFunctionInstanceData(shared_data_roots[i]) }
		if existing := shared_data.executable {
			mut mutable_existing := unsafe { &ScriptExecutable(existing) }
			compile_remaining_functions_off_thread(mut mutable_existing, source_code, compiler)
			continue
		}
		shared_data.executable = compiled
		shared_data.rust_function_ast = none
	}
}

fn compile_remaining_classic_script_functions_off_thread(script &ClassicScript, source_code string, compiler ScriptFunctionCompileHook) {
	compiled_program := script.compiled_program or { return }
	executable := compiled_program.executable or { return }
	mut mutable_executable := unsafe { &ScriptExecutable(executable) }
	compile_remaining_functions_off_thread(mut mutable_executable, source_code, compiler)
}

fn compile_remaining_module_functions_off_thread(script &JavaScriptModuleScript, source_code string, compiler ScriptFunctionCompileHook) {
	compiled_program := script.compiled_program or { return }
	executable := compiled_program.executable or { return }
	mut mutable_executable := unsafe { &ScriptExecutable(executable) }
	compile_remaining_functions_off_thread(mut mutable_executable, source_code, compiler)
}

pub fn create_on_fetch_script_complete(function OnFetchScriptComplete) OnFetchScriptComplete {
	return function
}

pub fn create_perform_the_fetch_hook(function PerformTheFetchHook) PerformTheFetchHook {
	return function
}

// https://html.spec.whatwg.org/multipage/webappapis.html#default-script-fetch-options
pub fn default_script_fetch_options() ScriptFetchOptions {
	return ScriptFetchOptions{
		cryptographic_nonce: ''
		integrity_metadata: ''
		parser_metadata: .not_parser_inserted
		credentials_mode: .same_origin
		referrer_policy: ''
		fetch_priority: .auto
	}
}

// https://html.spec.whatwg.org/multipage/webappapis.html#module-type-from-module-request
pub fn module_type_from_module_request(module_request ModuleRequest) string {
	mut module_type := 'javascript'
	for attribute in module_request.attributes {
		if attribute.key != 'type' {
			continue
		}
		module_type = if attribute.value == 'javascript' { '' } else { attribute.value }
	}
	return module_type
}

// https://html.spec.whatwg.org/multipage/webappapis.html#set-up-the-classic-script-request
pub fn set_up_classic_script_request(mut request fetch.Request, options ScriptFetchOptions) {
	request.cryptographic_nonce_metadata = options.cryptographic_nonce
	request.integrity_metadata = options.integrity_metadata
	request.parser_metadata = options.parser_metadata
	request.referrer_policy = options.referrer_policy
	request.render_blocking = options.render_blocking
	request.priority = options.fetch_priority
}

// https://html.spec.whatwg.org/multipage/webappapis.html#set-up-the-module-script-request
pub fn set_up_module_script_request(mut request fetch.Request, options ScriptFetchOptions) {
	set_up_classic_script_request(mut request, options)
	request.credentials_mode = options.credentials_mode
}

// https://html.spec.whatwg.org/multipage/webappapis.html#get-the-descendant-script-fetch-options
pub fn get_descendant_script_fetch_options(original_options ScriptFetchOptions, url dom.URL, settings_object &EnvironmentSettingsObject) ScriptFetchOptions {
	mut new_options := original_options
	new_options.integrity_metadata = resolve_a_module_integrity_metadata(url, settings_object)
	new_options.fetch_priority = .auto
	return new_options
}

// https://html.spec.whatwg.org/multipage/webappapis.html#resolving-a-module-integrity-metadata
pub fn resolve_a_module_integrity_metadata(url dom.URL, settings_object &EnvironmentSettingsObject) string {
	if settings_object.universal_global_scope_ == unsafe { nil } {
		return ''
	}
	for entry in settings_object.universal_global_scope_.import_map().integrity() {
		if entry.url == url {
			return entry.integrity
		}
	}
	return ''
}

fn script_response_body(response &fetch.Response) ?[]u8 {
	unsafe_response := response.unsafe_response()
	if !fetch.is_ok_status(unsafe_response.status) {
		return none
	}
	return unsafe_response.fetch_response_body_bytes()
}

fn response_for_script_request(request &fetch.Request, is_top_level TopLevelModule, settings_object &EnvironmentSettingsObject, perform_fetch ?PerformTheFetchHook) !&fetch.Response {
	if hook := perform_fetch {
		return hook(request, is_top_level)!
	}
	if hook := settings_object.script_fetch_hook() {
		return hook(request, is_top_level)!
	}
	if request.current_url().scheme() == 'data' {
		data := fetch.process_data_url(request.current_url())!
		mut response := fetch.Response.create()
		response.url_list = request.url_list.clone()
		response.set_body_bytes(data.body)
		response.header_list.append(http.Header{
			name: 'Content-Type'
			value: data.mime_type.serialized()
		})
		return response
	}
	return error('NetworkError: no script fetch host is installed')
}

fn decode_script_body(bytes []u8, encoding_label string) !string {
	decoder := encoding.TextDecoder.construct(encoding_label, encoding.TextDecoderOptions{})!
	return decoder.decode(bytes, encoding.TextDecodeOptions{})!
}

fn script_pointer(script &ClassicScript) &Script {
	return &script.Script
}

fn module_script_pointer(script &JavaScriptModuleScript) &Script {
	return &script.ModuleScript.Script
}

// https://html.spec.whatwg.org/multipage/webappapis.html#fetch-a-classic-script
pub fn fetch_classic_script(element &HTMLScriptElementModel, url dom.URL, settings_object &EnvironmentSettingsObject, options ScriptFetchOptions, cors_setting CORSSettingAttribute, character_encoding string, on_complete OnFetchScriptComplete) {
	_ = element
	mut request := fetch.Request.create()
	request.set_url(url)
	request.destination = .script
	request.mode = if cors_setting == .no_cors { .no_cors } else { .cors }
	request.credentials_mode = if cors_setting == .use_credentials {
		.include
	} else {
		.same_origin
	}
	request.use_url_credentials = true
	request.set_client(settings_object)
	request.initiator_type = .script
	set_up_classic_script_request(mut request, options)
	response := response_for_script_request(request, .yes, settings_object, none) or {
		on_complete(none)
		return
	}
	unsafe_response := response.unsafe_response()
	body := script_response_body(unsafe_response) or {
		on_complete(none)
		return
	}
	mime_type := fetch.extract_mime_type(unsafe_response.header_list)
	encoding_label := fetch.legacy_extract_an_encoding(mime_type, character_encoding)
	source_text := decode_script_body(body, encoding_label) or {
		on_complete(none)
		return
	}
	response_url := unsafe_response.url() or { url }
	bytecode_cache_context := bytecode_cache_context_for_request(request, response_url, settings_object)
	mut script := ClassicScript.create(response_url.serialize(), source_text, settings_object.realm(), response_url, 1, if unsafe_response.is_cors_cross_origin() {
		.yes
	} else {
		.no
	})
	mut compiled_off_thread := false
	if compiler := settings_object.script_compile_hook() {
		muted_errors := if unsafe_response.is_cors_cross_origin() {
			MutedErrors.yes
		} else {
			MutedErrors.no
		}
		result := compile_source_off_thread(source_text, .script, 1, compiler)
		if compiled := result.compiled {
			script = ClassicScript.create_from_pre_compiled(response_url.serialize(), source_text, settings_object.realm(), response_url, compiled, muted_errors)
			compiled_off_thread = true
		} else if parsed := result.parsed {
			script = ClassicScript.create_from_parsed_program(response_url.serialize(), source_text, settings_object.realm(), response_url, parsed, muted_errors)
		}
		if function_compiler := settings_object.script_function_compile_hook() {
			compile_remaining_classic_script_functions_off_thread(script, source_text, function_compiler)
		}
	}
	on_complete(script_pointer(script))
	if compiled_off_thread {
		if context := bytecode_cache_context {
			schedule_bytecode_cache_generation(source_text, response_url.serialize(), .script, 1, context, settings_object)
		}
	}
}

// https://html.spec.whatwg.org/multipage/webappapis.html#fetch-a-classic-worker-script
pub fn fetch_classic_worker_script(url dom.URL, fetch_client &EnvironmentSettingsObject, destination fetch.Destination, settings_object &EnvironmentSettingsObject, perform_fetch ?PerformTheFetchHook, on_complete OnFetchScriptComplete) ! {
	mut request := fetch.Request.create()
	request.set_url(url)
	request.set_client(fetch_client)
	request.destination = destination
	request.initiator_type = .other
	request.mode = .same_origin
	request.credentials_mode = .same_origin
	request.parser_metadata = .not_parser_inserted
	request.use_url_credentials = true
	response := response_for_script_request(request, .yes, settings_object, perform_fetch)!
	unsafe_response := response.unsafe_response()
	body := script_response_body(unsafe_response) or {
		on_complete(none)
		return
	}
	if response_url := unsafe_response.url() {
		if fetch.is_http_or_https_scheme(response_url.scheme()) {
			mime_type := fetch.extract_mime_type(unsafe_response.header_list) or {
				on_complete(none)
				return
			}
			if !mime_type.is_javascript() {
				on_complete(none)
				return
			}
		}
	}
	source_text := decode_script_body(body, 'utf-8')!
	response_url := unsafe_response.url() or { url }
	script := ClassicScript.create(response_url.serialize(), source_text, settings_object.realm(), response_url, 1, .no)
	on_complete(script_pointer(script))
}

// https://html.spec.whatwg.org/multipage/webappapis.html#fetch-a-classic-worker-imported-script
pub fn fetch_a_classic_worker_imported_script(url dom.URL, settings_object &EnvironmentSettingsObject, perform_fetch ?PerformTheFetchHook) !&ClassicScript {
	mut request := fetch.Request.create()
	request.set_url(url)
	request.set_client(settings_object)
	request.destination = .script
	request.initiator_type = .other
	request.parser_metadata = .not_parser_inserted
	request.use_url_credentials = true
	response := response_for_script_request(request, .yes, settings_object, perform_fetch)!
	unsafe_response := response.unsafe_response()
	body := script_response_body(unsafe_response) or { return error('NetworkError: worker script fetch failed') }
	mime_type := fetch.extract_mime_type(unsafe_response.header_list) or {
		return error('NetworkError: worker script has no JavaScript MIME type')
	}
	if !mime_type.is_javascript() {
		return error('NetworkError: worker script has a non-JavaScript MIME type')
	}
	source_text := decode_script_body(body, 'utf-8')!
	response_url := unsafe_response.url() or { url }
	return ClassicScript.create(response_url.serialize(), source_text, settings_object.realm(), response_url, 1, if unsafe_response.is_cors_cross_origin() {
		.yes
	} else {
		.no
	})
}

// https://html.spec.whatwg.org/multipage/webappapis.html#fetch-destination-from-module-type
pub fn fetch_destination_from_module_type(default_destination fetch.Destination, module_type string) fetch.Destination {
	return match module_type {
		'json' { .json }
		'css' { .style }
		else { default_destination }
	}
}

fn fetch_single_module_script_result(url dom.URL, fetch_client &EnvironmentSettingsObject, destination fetch.Destination, options ScriptFetchOptions, module_map_realm &ScriptingRealm, referrer fetch.Referrer, module_request ?ModuleRequest, is_top_level TopLevelModule, perform_fetch ?PerformTheFetchHook) !ModuleScriptFetchResult {
	module_type := if request := module_request {
		module_type_from_module_request(request)
	} else {
		'javascript'
	}
	if !module_type_allowed(module_type) {
		return ModuleScriptFetchResult{}
	}
	mut module_map := unsafe { &ModuleMap(module_map_of_realm(module_map_realm)) }
	if entry := module_map.get(url, module_type) {
		if entry.type_ == .fetching {
			return error('InvalidStateError: module is already being fetched')
		}
		return ModuleScriptFetchResult{
			module_script: entry.module_script
		}
	}
	module_map.set(url, module_type, ModuleMapEntry{ type_: .fetching })!

	mut request := fetch.Request.create()
	request.set_url(url)
	request.mode = .cors
	request.referrer = referrer
	request.set_client(fetch_client)
	request.destination = fetch_destination_from_module_type(destination, module_type)
	if destination in [.worker, .shared_worker, .service_worker] && is_top_level == .yes {
		request.mode = .same_origin
	}
	request.initiator_type = .script
	set_up_module_script_request(mut request, options)
	response := response_for_script_request(request, is_top_level, fetch_client, perform_fetch) or {
		module_map.set(url, module_type, ModuleMapEntry{ type_: .failed })!
		return ModuleScriptFetchResult{}
	}
	unsafe_response := response.unsafe_response()
	body := script_response_body(unsafe_response) or {
		module_map.set(url, module_type, ModuleMapEntry{ type_: .failed })!
		return ModuleScriptFetchResult{}
	}
	source_text := decode_script_body(body, 'utf-8') or {
		module_map.set(url, module_type, ModuleMapEntry{ type_: .failed })!
		return ModuleScriptFetchResult{}
	}
	mime_type := fetch.extract_mime_type(unsafe_response.header_list)
	mut module_script := ?&ModuleScript(none)
	mut cache_context := ?BytecodeCacheContext(none)
	mut should_generate_bytecode_cache := false
	if mime := mime_type {
		if mime.is_javascript() && module_type == 'javascript' {
			response_url := unsafe_response.url() or { url }
			cache_context = bytecode_cache_context_for_request(request, response_url, fetch_client)
			mut javascript_module := JavaScriptModuleScript.create(url.serialize(), source_text, module_map_realm, response_url)
			mut compiled_off_thread := false
			if compiler := fetch_client.script_compile_hook() {
				result := compile_source_off_thread(source_text, .module, 0, compiler)
				if compiled := result.compiled {
					javascript_module = JavaScriptModuleScript.create_from_pre_compiled(url.serialize(), source_text, module_map_realm, response_url, compiled)
					compiled_off_thread = true
				} else if parsed := result.parsed {
					javascript_module = JavaScriptModuleScript.create_from_parsed_program(url.serialize(), source_text, module_map_realm, response_url, parsed)
				}
				if function_compiler := fetch_client.script_function_compile_hook() {
					compile_remaining_module_functions_off_thread(javascript_module, source_text, function_compiler)
				}
			}
			module_script = &javascript_module.ModuleScript
			should_generate_bytecode_cache = compiled_off_thread
		}
	}
	if script := module_script {
		module_map.set(url, module_type, ModuleMapEntry{
			type_: .module_script
			module_script: script
		})!
		if should_generate_bytecode_cache {
			if context := cache_context {
				schedule_bytecode_cache_generation(source_text, url.serialize(), .module, 0, context, fetch_client)
			}
		}
		return ModuleScriptFetchResult{
			module_script: script
		}
	}
	module_map.set(url, module_type, ModuleMapEntry{ type_: .failed })!
	return ModuleScriptFetchResult{}
}

// https://html.spec.whatwg.org/multipage/webappapis.html#fetch-a-single-module-script
pub fn fetch_single_module_script(realm &ScriptingRealm, url dom.URL, fetch_client &EnvironmentSettingsObject, destination fetch.Destination, options ScriptFetchOptions, module_map_realm &ScriptingRealm, referrer fetch.Referrer, module_request ?ModuleRequest, is_top_level TopLevelModule, perform_fetch ?PerformTheFetchHook, on_complete OnFetchScriptComplete) {
	_ = realm
	result := fetch_single_module_script_result(url, fetch_client, destination, options, module_map_realm, referrer, module_request, is_top_level, perform_fetch) or {
		on_complete(none)
		return
	}
	if script := result.module_script {
		on_complete(&script.Script)
	} else {
		on_complete(none)
	}
}

// https://html.spec.whatwg.org/multipage/webappapis.html#fetch-a-single-imported-module-script
pub fn fetch_single_imported_module_script(realm &ScriptingRealm, url dom.URL, fetch_client &EnvironmentSettingsObject, destination fetch.Destination, options ScriptFetchOptions, module_map_realm &ScriptingRealm, referrer fetch.Referrer, module_request ModuleRequest, perform_fetch ?PerformTheFetchHook, on_complete OnFetchScriptComplete) {
	for attribute in module_request.attributes {
		assert attribute.key == 'type'
	}
	if !module_type_allowed(module_type_from_module_request(module_request)) {
		on_complete(none)
		return
	}
	fetch_single_module_script(realm, url, fetch_client, destination, options, module_map_realm, referrer, module_request, .no, perform_fetch, on_complete)
}

fn fetch_descendant_module_graph(mut module_script JavaScriptModuleScript, fetch_client &EnvironmentSettingsObject, destination fetch.Destination, perform_fetch ?PerformTheFetchHook, mut visited map[string]bool) !bool {
	record := module_script.record() or {
		module_script.set_error_to_rethrow(module_script.parse_error())
		return true
	}
	_ = record
	base_url := module_script.base_url() or { return error('TypeError: module script has no base URL') }
	key := base_url.serialize()
	if visited[key] {
		return true
	}
	visited[key] = true
	import_map := if fetch_client.universal_global_scope_ == unsafe { nil } {
		&ImportMap{}
	} else {
		fetch_client.universal_global_scope_.import_map()
	}
	for module_request in module_script.requested_modules() {
		resolved_url := resolve_module_specifier(import_map, base_url, module_request.specifier) or {
			module_script.set_error_to_rethrow(err.msg())
			return true
		}
		options := get_descendant_script_fetch_options(default_script_fetch_options(), resolved_url, fetch_client)
		result := fetch_single_module_script_result(resolved_url, fetch_client, destination, options, module_script.realm(), fetch.Referrer{ url: base_url }, module_request, .no, perform_fetch)!
		imported := result.module_script or { return false }
		mut javascript_import := unsafe { &JavaScriptModuleScript(imported) }
		if !fetch_descendant_module_graph(mut javascript_import, fetch_client, destination, perform_fetch, mut visited)! {
			return false
		}
	}
	module_script.linked = true
	return true
}

// https://html.spec.whatwg.org/multipage/webappapis.html#fetch-the-descendants-of-and-link-a-module-script
pub fn fetch_descendants_of_and_link_a_module_script(realm &ScriptingRealm, module_script &JavaScriptModuleScript, fetch_client &EnvironmentSettingsObject, destination fetch.Destination, perform_fetch ?PerformTheFetchHook, on_complete OnFetchScriptComplete) {
	_ = realm
	mut mutable_script := unsafe { &JavaScriptModuleScript(module_script) }
	mut visited := map[string]bool{}
	linked := fetch_descendant_module_graph(mut mutable_script, fetch_client, destination, perform_fetch, mut visited) or {
		on_complete(none)
		return
	}
	if !linked {
		on_complete(none)
		return
	}
	on_complete(module_script_pointer(module_script))
}

// https://html.spec.whatwg.org/multipage/webappapis.html#fetch-a-module-script-tree
pub fn fetch_external_module_script_graph(realm &ScriptingRealm, url dom.URL, settings_object &EnvironmentSettingsObject, options ScriptFetchOptions, on_complete OnFetchScriptComplete) {
	result := fetch_single_module_script_result(url, settings_object, .script, options, realm, fetch.Referrer{}, none, .yes, none) or {
		on_complete(none)
		return
	}
	fetched_module := result.module_script or {
		on_complete(none)
		return
	}
	fetch_descendants_of_and_link_a_module_script(realm, unsafe { &JavaScriptModuleScript(fetched_module) }, settings_object, .script, none, on_complete)
}

// https://html.spec.whatwg.org/multipage/webappapis.html#fetch-an-inline-module-script-graph
pub fn fetch_inline_module_script_graph(realm &ScriptingRealm, filename string, source_text string, base_url dom.URL, settings_object &EnvironmentSettingsObject, on_complete OnFetchScriptComplete) {
	script := JavaScriptModuleScript.create(filename, source_text, settings_object.realm(), base_url)
	fetch_descendants_of_and_link_a_module_script(realm, script, settings_object, .script, none, on_complete)
}

// https://html.spec.whatwg.org/multipage/webappapis.html#fetch-a-module-worker-script-tree
pub fn fetch_module_worker_script_graph(url dom.URL, fetch_client &EnvironmentSettingsObject, destination fetch.Destination, settings_object &EnvironmentSettingsObject, perform_fetch ?PerformTheFetchHook, on_complete OnFetchScriptComplete) ! {
	fetch_worklet_module_worker_script_graph(url, fetch_client, destination, settings_object, perform_fetch, on_complete)!
}

// https://html.spec.whatwg.org/multipage/webappapis.html#fetch-a-worklet/module-worker-script-graph
pub fn fetch_worklet_module_worker_script_graph(url dom.URL, fetch_client &EnvironmentSettingsObject, destination fetch.Destination, settings_object &EnvironmentSettingsObject, perform_fetch ?PerformTheFetchHook, on_complete OnFetchScriptComplete) ! {
	options := default_script_fetch_options()
	result := fetch_single_module_script_result(url, fetch_client, destination, options, settings_object.realm(), fetch.Referrer{}, none, .yes, perform_fetch)!
	fetched_module := result.module_script or {
		on_complete(none)
		return
	}
	fetch_descendants_of_and_link_a_module_script(settings_object.realm(), unsafe {
		&JavaScriptModuleScript(fetched_module)
	}, fetch_client, destination, perform_fetch, on_complete)
}

struct QuotedModuleSpecifier {
	value string
	end   int
}

fn quoted_module_specifier(source string, start int) ?QuotedModuleSpecifier {
	if start < 0 || start >= source.len || source[start] !in [`'`, `"`] {
		return none
	}
	quote := source[start]
	mut escaped := false
	for index := start + 1; index < source.len; index++ {
		character := source[index]
		if escaped {
			escaped = false
			continue
		}
		if character == `\\` {
			escaped = true
			continue
		}
		if character == quote {
			return QuotedModuleSpecifier{
				value: source[start + 1..index]
				end: index + 1
			}
		}
	}
	return none
}

fn module_type_attribute(source string, start int) []ModuleRequestAttribute {
	remainder := source[start..]
	type_index := remainder.index('type') or { return [] }
	colon_index := remainder.index_after(':', type_index + 4) or { return [] }
	mut value_start := colon_index + 1
	for value_start < remainder.len && remainder[value_start].is_space() {
		value_start++
	}
	value := quoted_module_specifier(remainder, value_start) or { return [] }
	return [ModuleRequestAttribute{ key: 'type', value: value.value }]
}

// Runtime-neutral extraction of the static module requests needed to drive
// graph fetching. Full syntax validation stays at the parser host boundary.
pub fn parse_module_requests(source string) []ModuleRequest {
	mut requests := []ModuleRequest{}
	for raw_line in source.split_into_lines() {
		line := raw_line.trim_space()
		if !(line.starts_with('import') || line.starts_with('export')) || line.starts_with('import(') {
			continue
		}
		mut quote_index := -1
		if line.starts_with('import') {
			mut index := 'import'.len
			for index < line.len && line[index].is_space() {
				index++
			}
			if index < line.len && line[index] in [`'`, `"`] {
				quote_index = index
			}
		}
		if quote_index < 0 {
			from_index := line.index(' from ') or { continue }
			mut index := from_index + ' from '.len
			for index < line.len && line[index].is_space() {
				index++
			}
			quote_index = index
		}
		specifier := quoted_module_specifier(line, quote_index) or { continue }
		requests << ModuleRequest{
			specifier: specifier.value
			attributes: module_type_attribute(line, specifier.end)
		}
	}
	return requests
}
