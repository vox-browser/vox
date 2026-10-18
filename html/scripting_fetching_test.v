@[has_globals]
module html

import dom
import fetch
import http

__global (
	scripting_fetching_completed_script &Script
	scripting_fetching_request_urls     []string
	scripting_fetching_last_destination fetch.Destination
	scripting_fetching_last_nonce       string
	scripting_fetching_last_top_level   TopLevelModule
	scripting_fetching_last_mode        fetch.Mode
	scripting_fetching_last_credentials fetch.CredentialsMode
	scripting_fetching_last_referrer_policy string
	scripting_fetching_last_priority    fetch.Priority
	scripting_fetching_last_parser_metadata fetch.ParserMetadata
	scripting_fetching_completion_request_count int
	scripting_fetching_completion_nonce string
	scripting_fetching_retry_count      int
	scripting_fetching_parsed           ParsedProgram
	scripting_fetching_parsed_source    string
	scripting_fetching_compiled         OffThreadCompiledProgram
	scripting_fetching_compiled_source  string
	scripting_fetching_function_asts    []string
	scripting_fetching_function_lengths []usize
	scripting_fetching_stale_shared     &SharedFunctionInstanceData
	scripting_fetching_stale_executable &ScriptExecutable
	scripting_fetching_track_cache      bool
	scripting_fetching_cache_events     []string
	scripting_fetching_cache_blobs      [][]u8
	scripting_fetching_cache_types      []ScriptProgramType
	scripting_fetching_cache_urls       []string
	scripting_fetching_cache_methods    []string
	scripting_fetching_cache_vary_keys  []u64
	scripting_fetching_cached_responses map[string][]u8
	scripting_fetching_materialized     [][]u8
	scripting_fetching_material_types   []ScriptProgramType
	scripting_fetching_compile_count    int
)

struct ScriptingFetchingFixture {
	realm    &ScriptingRealm
	settings &EnvironmentSettingsObject
}

fn scripting_fetching_fixture() !ScriptingFetchingFixture {
	url := dom.URL{ value: 'https://example.test/app/index.html' }
	document := &dom.Document{
		url: url
		origin_: url.origin()
		load_timing_info: dom.DocumentLoadTimingInfo{
			navigation_start_time: 1
		}
	}
	window := WindowModel.create_top_level(document, none, 'script-fetching')!
	mut realm := &ScriptingRealm{}
	object := WindowEnvironmentSettingsObject.setup(window, url, mut realm, none, url, url.origin())
	mut settings := unsafe { &EnvironmentSettingsObject(object.settings) }
	settings.set_script_fetch_hook(scripting_fetching_host)
	return ScriptingFetchingFixture{
		realm: realm
		settings: settings
	}
}

fn scripting_fetching_host(request &fetch.Request, is_top_level TopLevelModule) !&fetch.Response {
	url := request.current_url()
	scripting_fetching_request_urls << url.serialize()
	if destination := request.destination {
		scripting_fetching_last_destination = destination
	}
	scripting_fetching_last_nonce = request.cryptographic_nonce_metadata
	scripting_fetching_last_top_level = is_top_level
	scripting_fetching_last_mode = request.mode
	scripting_fetching_last_credentials = request.credentials_mode
	scripting_fetching_last_referrer_policy = request.referrer_policy
	scripting_fetching_last_priority = request.priority
	if parser_metadata := request.parser_metadata {
		scripting_fetching_last_parser_metadata = parser_metadata
	}
	mut response := fetch.Response.create()
	response.url_list = request.url_list.clone()
	mut content_type := 'text/javascript'
	body := if url.serialize().ends_with('/classic.js') {
		content_type = 'text/javascript; charset=windows-1252'
		[u8(0xe9)]
	} else if url.serialize().ends_with('/syntax.js') {
		'invalid'.bytes()
	} else if url.serialize().ends_with('/root.js') {
		"import './dep.js'\nexport const root = true".bytes()
	} else if url.serialize().ends_with('/dep.js') {
		'export const dependency = true'.bytes()
	} else if url.serialize().ends_with('/module.txt') {
		content_type = 'text/plain'
		'module text'.bytes()
	} else if url.serialize().ends_with('/module.css') {
		content_type = 'text/css'
		':root { color: green; }'.bytes()
	} else if url.serialize().ends_with('/module.json') {
		content_type = 'application/json'
		'{"answer":42}'.bytes()
	} else if url.serialize().ends_with('/retry.js') {
		scripting_fetching_retry_count++
		if scripting_fetching_retry_count == 1 {
			response.status = 500
		}
		'export const retried = true'.bytes()
	} else if url.serialize().ends_with('/warm-classic.js') {
		'const warm = true'.bytes()
	} else if url.serialize().ends_with('/corrupt-classic.js') {
		'const corrupt = true'.bytes()
	} else if url.serialize().ends_with('/stale-classic.js') {
		'const stale = true'.bytes()
	} else if url.serialize().ends_with('/warm-module.js') {
		'export const warm = true'.bytes()
	} else if url.serialize().ends_with('/rejected-filtered-module.js') {
		'export const rejected = true'.bytes()
	} else if url.serialize().ends_with('/bad.js') {
		content_type = 'text/plain'
		'not javascript'.bytes()
	} else {
		'worker source'.bytes()
	}
	response.set_body_bytes(body)
	response.header_list.append(http.Header{
		name: 'Content-Type'
		value: content_type
	})
	response.set_javascript_bytecode_cache_vary_key(u64(73))
	if cached := scripting_fetching_cached_responses[url.serialize()] {
		response.set_javascript_bytecode_cache(cached)
	}
	if url.serialize().ends_with('/warm-module.js')
		|| url.serialize().ends_with('/rejected-filtered-module.js') {
		mut filtered := fetch.Response.create_cors_filtered_response(response)
		if url.serialize().ends_with('/rejected-filtered-module.js') {
			filtered.status = 500
		}
		return filtered
	}
	return response
}

fn scripting_fetching_abort_once_host(request &fetch.Request, is_top_level TopLevelModule) !&fetch.Response {
	scripting_fetching_retry_count++
	if scripting_fetching_retry_count == 1 {
		return error('implementation fetch hook aborted')
	}
	return scripting_fetching_host(request, is_top_level)
}

fn scripting_fetching_complete(script ?&Script) {
	scripting_fetching_completed_script = script or { unsafe { &Script(nil) } }
	if scripting_fetching_track_cache {
		scripting_fetching_cache_events << 'complete'
	}
}

fn modulepreload_fetching_complete(script ?&Script) {
	scripting_fetching_completed_script = script or { unsafe { &Script(nil) } }
	scripting_fetching_completion_request_count = scripting_fetching_request_urls.len
	scripting_fetching_completion_nonce = scripting_fetching_last_nonce
}

fn scripting_fetching_parser(source string, filename string, line usize) ! {
	_ = filename
	_ = line
	if source == 'invalid' {
		return error('syntax error')
	}
}

fn scripting_fetching_compiler(source string, filename string, line usize, program_type ScriptProgramType) !&ScriptExecutable {
	scripting_fetching_compile_count++
	scripting_fetching_parser(source, filename, line)!
	mut shared_function_data := []&SharedFunctionInstanceData{}
	if source == 'é' {
		shared_function_data << &SharedFunctionInstanceData{
			rust_function_ast: 'classic-function'
		}
	} else if source.contains('export const root') {
		shared_function_data << &SharedFunctionInstanceData{
			rust_function_ast: 'module-function'
		}
	}
	_ = program_type
	return &ScriptExecutable{
		shared_function_data: shared_function_data
	}
}

fn scripting_fetching_function_compiler(function_ast string, source_length usize) !&ScriptExecutable {
	scripting_fetching_function_asts << function_ast
	scripting_fetching_function_lengths << source_length
	if function_ast == 'failed' {
		return error('function compile failed')
	}
	if function_ast == 'stale' {
		mut stale_shared := scripting_fetching_stale_shared
		stale_shared.executable = scripting_fetching_stale_executable
	}
	return &ScriptExecutable{}
}

fn scripting_fetching_bytecode_cache_compiler(cache_parse &ParsedProgramForCache) ![]u8 {
	scripting_fetching_cache_events << 'compile-cache'
	scripting_fetching_cache_types << cache_parse.program_type
	return '${cache_parse.filename}:${cache_parse.line_number_offset}:${cache_parse.source_code}'.bytes()
}

fn scripting_fetching_bytecode_cache_materializer(bytecode []u8, _ string, _ string, _ usize, program_type ScriptProgramType) !&ScriptExecutable {
	scripting_fetching_materialized << bytecode.clone()
	scripting_fetching_material_types << program_type
	if bytecode == [u8(0xff)] {
		return error('cached bytecode is corrupt')
	}
	return &ScriptExecutable{}
}

fn scripting_fetching_bytecode_cache_store(url dom.URL, method string, _ &http.HeaderList, vary_key u64, blob []u8) ! {
	scripting_fetching_cache_events << 'store-cache'
	scripting_fetching_cache_urls << url.serialize()
	scripting_fetching_cache_methods << method
	scripting_fetching_cache_vary_keys << vary_key
	scripting_fetching_cache_blobs << blob.clone()
}

fn scripting_fetching_parsed_callback(parsed ParsedProgram, source string) {
	scripting_fetching_parsed = parsed
	scripting_fetching_parsed_source = source
}

fn scripting_fetching_compiled_callback(compiled OffThreadCompiledProgram, source string) {
	scripting_fetching_compiled = compiled
	scripting_fetching_compiled_source = source
}

fn test_script_fetch_options_module_requests_and_off_thread_parse() {
	options := default_script_fetch_options()
	assert options.cryptographic_nonce == ''
	assert options.integrity_metadata == ''
	assert options.parser_metadata == .not_parser_inserted
	assert options.credentials_mode == .same_origin
	assert options.fetch_priority == .auto

	assert module_type_from_module_request(ModuleRequest{}) == 'javascript-or-wasm'
	assert module_type_from_module_request(ModuleRequest{
		attributes: [ModuleRequestAttribute{ key: 'type', value: 'json' }]
	}) == 'json'
	assert module_type_from_module_request(ModuleRequest{
		attributes: [ModuleRequestAttribute{ key: 'type', value: 'javascript-or-wasm' }]
	}) == ''

	requests := parse_module_requests("import './side-effect.js'\nimport value from './value.js' with { type: 'json' }\nexport { x } from './export.js'\nimport('./dynamic.js')")
	assert requests.len == 3
	assert requests[0].specifier == './side-effect.js'
	assert requests[1].specifier == './value.js'
	assert requests[1].attributes == [
		ModuleRequestAttribute{ key: 'type', value: 'json' },
	]
	assert requests[2].specifier == './export.js'

	mut request := fetch.Request.create()
	custom_options := ScriptFetchOptions{
		cryptographic_nonce: 'nonce'
		integrity_metadata: 'sha256-value'
		parser_metadata: .parser_inserted
		credentials_mode: .include
		referrer_policy: 'origin'
		render_blocking: true
		fetch_priority: .high
	}
	set_up_classic_script_request(mut request, custom_options)
	assert request.cryptographic_nonce_metadata == 'nonce'
	assert request.integrity_metadata == 'sha256-value'
	assert request.parser_metadata? == .parser_inserted
	assert request.referrer_policy == 'origin'
	assert request.render_blocking
	assert request.priority == .high
	set_up_module_script_request(mut request, custom_options)
	assert request.credentials_mode == .include

	parse_off_thread('invalid', .module, 7, scripting_fetching_parser, scripting_fetching_parsed_callback)
	assert scripting_fetching_parsed.program_type == .module
	assert scripting_fetching_parsed.line_number_offset == 7
	assert scripting_fetching_parsed.error? == 'syntax error'
	assert scripting_fetching_parsed_source == 'invalid'

	compile_off_thread('valid', .script, 1, scripting_fetching_compiler, scripting_fetching_compiled_callback)
	assert scripting_fetching_compiled.compiled?.program_type == .script
	assert scripting_fetching_compiled.compiled?.line_number_offset == 1
	assert scripting_fetching_compiled.parsed == none
	assert scripting_fetching_compiled_source == 'valid'
	compile_off_thread('invalid', .module, 0, scripting_fetching_compiler, scripting_fetching_compiled_callback)
	assert scripting_fetching_compiled.compiled == none
	assert scripting_fetching_compiled.parsed?.error? == 'syntax error'
}

fn test_bytecode_cache_parse_snapshot_has_independent_function_ownership() {
	function_data := &SharedFunctionInstanceData{
		rust_function_ast: 'nested-function'
	}
	execution := &ScriptExecutable{
		shared_function_data: [function_data]
	}
	cache_parse := clone_parsed_program_for_cache('function outer() {}', 'cache.js',
		.script, 1, execution)
	assert cache_parse.source_code == 'function outer() {}'
	assert cache_parse.filename == 'cache.js'
	assert cache_parse.program_type == .script
	assert cache_parse.line_number_offset == 1
	assert cache_parse.executable.shared_function_data.len == 1
	assert voidptr(cache_parse.executable.shared_function_data[0]) != voidptr(function_data)
	assert cache_parse.executable.shared_function_data[0].rust_function_ast? == 'nested-function'

	mut cached_function := cache_parse.executable.shared_function_data[0]
	cached_function.executable = &ScriptExecutable{}
	assert function_data.executable == none
}

fn test_remaining_lazy_functions_compile_and_discard_stale_results() {
	direct := &SharedFunctionInstanceData{
		rust_function_ast: 'direct'
	}
	failed := &SharedFunctionInstanceData{
		rust_function_ast: 'failed'
	}
	nested := &SharedFunctionInstanceData{
		rust_function_ast: 'nested'
	}
	stale := &SharedFunctionInstanceData{
		rust_function_ast: 'stale'
	}
	stale_executable := &ScriptExecutable{
		shared_function_data: [nested]
	}
	scripting_fetching_stale_shared = stale
	scripting_fetching_stale_executable = stale_executable
	scripting_fetching_function_asts = []
	scripting_fetching_function_lengths = []
	mut executable := ScriptExecutable{
		shared_function_data: [direct, failed, stale]
	}
	compile_remaining_functions_off_thread(mut executable, 'A😀B', scripting_fetching_function_compiler)

	assert scripting_fetching_function_asts == ['direct', 'failed', 'stale', 'nested']
	assert scripting_fetching_function_lengths == [usize(4), 4, 4, 4]
	assert direct.executable != none
	assert direct.rust_function_ast == none
	assert failed.executable == none
	assert failed.rust_function_ast? == 'failed'
	assert stale.executable? == stale_executable
	assert stale.rust_function_ast? == 'stale'
	assert nested.executable != none
	assert nested.rust_function_ast == none
}

fn test_bytecode_cache_blob_is_bound_to_source_and_program_type() {
	bytecode := [u8(0xde), 0xad, 0xbe, 0xef]
	source := 'const emoji = "😀";'
	blob := serialize_compiled_program_for_bytecode_cache(bytecode, .script, source)
	assert decode_bytecode_cache_blob(blob, .script, source)? == bytecode
	assert decode_bytecode_cache_blob(blob, .script, 'const emoji = "😃";') == none
	assert decode_bytecode_cache_blob(blob, .module, source) == none
	assert decode_bytecode_cache_blob([u8(1), 2, 3], .script, source) == none
}

fn test_cached_bytecode_materialization_and_source_compile_fallbacks() {
	fixture := scripting_fetching_fixture()!
	mut settings := fixture.settings
	settings.set_script_compile_hook(scripting_fetching_compiler)
	settings.set_script_bytecode_cache_materialize_hook(scripting_fetching_bytecode_cache_materializer)
	scripting_fetching_cached_responses = map[string][]u8{}
	scripting_fetching_materialized = []
	scripting_fetching_material_types = []
	scripting_fetching_compile_count = 0
	element := HTMLScriptElementModel.create(dom.URL{ value: 'https://example.test/app/' })
	warm_url := dom.URL{ value: 'https://example.test/app/warm-classic.js' }
	scripting_fetching_cached_responses[warm_url.serialize()] = serialize_compiled_program_for_bytecode_cache([
		u8(0x2a),
	], .script, 'const warm = true')
	fetch_classic_script(element, warm_url, fixture.settings, default_script_fetch_options(), .anonymous, 'utf-8', scripting_fetching_complete)
	warm := unsafe { &ClassicScript(scripting_fetching_completed_script) }
	assert warm.compiled_program?.program_type == .script
	assert scripting_fetching_materialized == [[u8(0x2a)]]
	assert scripting_fetching_material_types == [.script]
	assert scripting_fetching_compile_count == 0

	corrupt_url := dom.URL{ value: 'https://example.test/app/corrupt-classic.js' }
	scripting_fetching_cached_responses[corrupt_url.serialize()] = serialize_compiled_program_for_bytecode_cache([
		u8(0xff),
	], .script, 'const corrupt = true')
	scripting_fetching_materialized = []
	scripting_fetching_compile_count = 0
	fetch_classic_script(element, corrupt_url, fixture.settings, default_script_fetch_options(), .anonymous, 'utf-8', scripting_fetching_complete)
	corrupt_fallback := unsafe { &ClassicScript(scripting_fetching_completed_script) }
	assert corrupt_fallback.parse_error == none
	assert corrupt_fallback.compiled_program?.program_type == .script
	assert scripting_fetching_materialized == [[u8(0xff)]]
	assert scripting_fetching_compile_count == 1

	stale_url := dom.URL{ value: 'https://example.test/app/stale-classic.js' }
	scripting_fetching_cached_responses[stale_url.serialize()] = serialize_compiled_program_for_bytecode_cache([
		u8(0x33),
	], .script, 'different source')
	scripting_fetching_materialized = []
	scripting_fetching_compile_count = 0
	fetch_classic_script(element, stale_url, fixture.settings, default_script_fetch_options(), .anonymous, 'utf-8', scripting_fetching_complete)
	stale_fallback := unsafe { &ClassicScript(scripting_fetching_completed_script) }
	assert stale_fallback.compiled_program?.program_type == .script
	assert scripting_fetching_materialized.len == 0
	assert scripting_fetching_compile_count == 1
	scripting_fetching_cached_responses = map[string][]u8{}
}

fn test_module_uses_internal_response_bytecode_without_unfiltering_response_checks() {
	fixture := scripting_fetching_fixture()!
	mut settings := fixture.settings
	settings.set_script_compile_hook(scripting_fetching_compiler)
	settings.set_script_bytecode_cache_materialize_hook(scripting_fetching_bytecode_cache_materializer)
	warm_url := dom.URL{ value: 'https://example.test/app/warm-module.js' }
	scripting_fetching_cached_responses = {
		warm_url.serialize(): serialize_compiled_program_for_bytecode_cache([u8(0x44)], .module, 'export const warm = true')
	}
	scripting_fetching_materialized = []
	scripting_fetching_material_types = []
	scripting_fetching_compile_count = 0
	scripting_fetching_completed_script = unsafe { &Script(nil) }
	fetch_external_module_script_graph(fixture.realm, warm_url, fixture.settings, default_script_fetch_options(), scripting_fetching_complete)
	assert scripting_fetching_completed_script != unsafe { nil }
	warm := unsafe { &JavaScriptModuleScript(scripting_fetching_completed_script) }
	assert warm.is_linked()
	assert warm.compiled_program?.program_type == .module
	assert scripting_fetching_materialized == [[u8(0x44)]]
	assert scripting_fetching_material_types == [.module]
	assert scripting_fetching_compile_count == 0

	rejected_url := dom.URL{ value: 'https://example.test/app/rejected-filtered-module.js' }
	scripting_fetching_cached_responses[rejected_url.serialize()] = serialize_compiled_program_for_bytecode_cache([
		u8(0x55),
	], .module, 'export const rejected = true')
	scripting_fetching_materialized = []
	scripting_fetching_completed_script = unsafe { &Script(nil) }
	fetch_external_module_script_graph(fixture.realm, rejected_url, fixture.settings, default_script_fetch_options(), scripting_fetching_complete)
	assert scripting_fetching_completed_script == unsafe { nil }
	assert scripting_fetching_materialized.len == 0
	scripting_fetching_cached_responses = map[string][]u8{}
}

fn test_descendant_options_resolve_import_map_integrity() {
	fixture := scripting_fetching_fixture()!
	module_url := dom.URL{ value: 'https://example.test/app/dep.js' }
	mut scope := unsafe { &UniversalGlobalScopeMixin(fixture.settings.universal_global_scope()) }
	import_map := &ImportMap{
		integrity: [ModuleIntegrityEntry{
			url: module_url
			integrity: 'sha384-module'
		}]
	}
	scope.set_import_map(import_map)
	original := ScriptFetchOptions{
		integrity_metadata: 'parent'
		fetch_priority: .high
	}
	descendant := get_descendant_script_fetch_options(original, module_url, fixture.settings)
	assert descendant.integrity_metadata == 'sha384-module'
	assert descendant.fetch_priority == .auto
	assert resolve_a_module_integrity_metadata(dom.URL{ value: 'https://example.test/other.js' }, fixture.settings) == ''
}

fn test_classic_and_worker_script_fetching_decode_and_validate_responses() {
	fixture := scripting_fetching_fixture()!
	mut settings := fixture.settings
	settings.set_script_compile_hook(scripting_fetching_compiler)
	settings.set_script_function_compile_hook(scripting_fetching_function_compiler)
	settings.set_script_bytecode_cache_compile_hook(scripting_fetching_bytecode_cache_compiler)
	settings.set_script_bytecode_cache_store_hook(scripting_fetching_bytecode_cache_store)
	scripting_fetching_function_asts = []
	scripting_fetching_function_lengths = []
	scripting_fetching_track_cache = true
	scripting_fetching_cache_events = []
	scripting_fetching_cache_blobs = []
	scripting_fetching_cache_types = []
	scripting_fetching_cache_urls = []
	scripting_fetching_cache_methods = []
	scripting_fetching_cache_vary_keys = []
	scripting_fetching_cached_responses = map[string][]u8{}
	scripting_fetching_completed_script = unsafe { &Script(nil) }
	scripting_fetching_request_urls = []
	options := ScriptFetchOptions{
		cryptographic_nonce: 'classic-nonce'
	}
	element := HTMLScriptElementModel.create(dom.URL{ value: 'https://example.test/app/' })
	fetch_classic_script(element, dom.URL{ value: 'https://example.test/app/classic.js' }, fixture.settings, options, .anonymous, 'utf-8', scripting_fetching_complete)
	assert scripting_fetching_completed_script != unsafe { nil }
	classic := unsafe { &ClassicScript(scripting_fetching_completed_script) }
	assert classic.source == 'é'
	assert classic.compiled_program?.program_type == .script
	assert scripting_fetching_function_asts == ['classic-function']
	assert scripting_fetching_function_lengths == [usize(1)]
	assert scripting_fetching_cache_events == ['complete', 'compile-cache', 'store-cache']
	assert scripting_fetching_cache_types == [.script]
	assert scripting_fetching_cache_urls == ['https://example.test/app/classic.js']
	assert scripting_fetching_cache_methods == ['GET']
	assert scripting_fetching_cache_vary_keys == [u64(73)]
	assert decode_bytecode_cache_blob(scripting_fetching_cache_blobs[0], .script, 'é')? == 'https://example.test/app/classic.js:1:é'.bytes()
	assert scripting_fetching_last_destination == .script
	assert scripting_fetching_last_nonce == 'classic-nonce'

	scripting_fetching_completed_script = unsafe { &Script(nil) }
	fetch_classic_script(element, dom.URL{ value: 'https://example.test/app/syntax.js' }, fixture.settings, options, .anonymous, 'utf-8', scripting_fetching_complete)
	broken := unsafe { &ClassicScript(scripting_fetching_completed_script) }
	assert broken.compiled_program == none
	assert broken.parse_error? == 'syntax error'
	assert broken.error_to_rethrow? == 'syntax error'
	assert scripting_fetching_cache_events == ['complete', 'compile-cache', 'store-cache', 'complete']
	scripting_fetching_track_cache = false

	scripting_fetching_completed_script = unsafe { &Script(nil) }
	fetch_classic_worker_script(dom.URL{ value: 'https://example.test/app/worker.js' }, fixture.settings, .worker, fixture.settings, none, scripting_fetching_complete)!
	assert scripting_fetching_completed_script != unsafe { nil }
	worker := unsafe { &ClassicScript(scripting_fetching_completed_script) }
	assert worker.source == 'worker source'
	assert scripting_fetching_last_top_level == .yes
	assert scripting_fetching_last_mode == .same_origin

	imported := fetch_a_classic_worker_imported_script(dom.URL{
		value: 'https://example.test/app/worker.js'
	}, fixture.settings, none)!
	assert imported.source == 'worker source'
	if _ := fetch_a_classic_worker_imported_script(dom.URL{
		value: 'https://example.test/app/bad.js'
	}, fixture.settings, none) {
		assert false
	} else {
		assert err.msg().contains('non-JavaScript MIME type')
	}
}

fn test_external_module_graph_fetches_descendants_caches_and_links() {
	fixture := scripting_fetching_fixture()!
	mut settings := fixture.settings
	settings.set_script_compile_hook(scripting_fetching_compiler)
	settings.set_script_function_compile_hook(scripting_fetching_function_compiler)
	settings.set_script_bytecode_cache_compile_hook(scripting_fetching_bytecode_cache_compiler)
	settings.set_script_bytecode_cache_store_hook(scripting_fetching_bytecode_cache_store)
	scripting_fetching_function_asts = []
	scripting_fetching_function_lengths = []
	scripting_fetching_track_cache = false
	scripting_fetching_cache_events = []
	scripting_fetching_cache_blobs = []
	scripting_fetching_cache_types = []
	scripting_fetching_cache_urls = []
	scripting_fetching_cache_methods = []
	scripting_fetching_cache_vary_keys = []
	scripting_fetching_cached_responses = map[string][]u8{}
	scripting_fetching_completed_script = unsafe { &Script(nil) }
	scripting_fetching_request_urls = []
	fetch_external_module_script_graph(fixture.realm, dom.URL{
		value: 'https://example.test/app/root.js'
	}, fixture.settings, default_script_fetch_options(), scripting_fetching_complete)
	assert scripting_fetching_completed_script != unsafe { nil }
	root := unsafe { &JavaScriptModuleScript(scripting_fetching_completed_script) }
	assert root.is_linked()
	assert root.compiled_program?.program_type == .module
	assert root.compiled_program?.line_number_offset == 0
	assert 'module-function' in scripting_fetching_function_asts
	assert scripting_fetching_cache_blobs.len == 2
	assert scripting_fetching_cache_types == [.module, .module]
	assert scripting_fetching_cache_urls == [
		'https://example.test/app/root.js',
		'https://example.test/app/dep.js',
	]
	assert decode_bytecode_cache_blob(scripting_fetching_cache_blobs[0], .module, "import './dep.js'\nexport const root = true")? == "https://example.test/app/root.js:0:import './dep.js'\nexport const root = true".bytes()
	assert root.requested_modules().len == 1
	assert scripting_fetching_request_urls == [
		'https://example.test/app/root.js',
		'https://example.test/app/dep.js',
	]
	module_map := fixture.settings.module_map()
	assert module_map.get(dom.URL{ value: 'https://example.test/app/root.js' }, 'javascript-or-wasm')?.type_ == .module_script
	assert module_map.get(dom.URL{ value: 'https://example.test/app/dep.js' }, 'javascript-or-wasm')?.type_ == .module_script

	// A second graph load reuses the module-map entries and performs no fetch.
	fetch_external_module_script_graph(fixture.realm, dom.URL{
		value: 'https://example.test/app/root.js'
	}, fixture.settings, default_script_fetch_options(), scripting_fetching_complete)
	assert scripting_fetching_request_urls.len == 2
	assert fetch_destination_from_module_type(.script, 'json') == .json
	assert fetch_destination_from_module_type(.worker, 'css') == .style
	assert fetch_destination_from_module_type(.worker, 'text') == .text
	assert fetch_destination_from_module_type(.worker, 'javascript-or-wasm') == .worker
}

fn test_modulepreload_fetches_graph_reuses_modules_and_retries_failures() {
	fixture := scripting_fetching_fixture()!
	scripting_fetching_request_urls = []
	scripting_fetching_completed_script = unsafe { &Script(nil) }
	scripting_fetching_completion_request_count = 0
	scripting_fetching_completion_nonce = ''
	options := ScriptFetchOptions{
		cryptographic_nonce: 'module-nonce'
		integrity_metadata: 'sha256-module'
		credentials_mode: .include
		referrer_policy: 'origin'
		fetch_priority: .high
	}
	root_url := dom.URL{ value: 'https://example.test/app/root.js' }
	assert fetch_modulepreload_module_script_graph(fixture.realm, root_url, .script,
		fixture.settings, options, modulepreload_fetching_complete)
	assert scripting_fetching_completed_script != unsafe { nil }
	assert scripting_fetching_completion_request_count == 1
	assert scripting_fetching_completion_nonce == 'module-nonce'
	assert scripting_fetching_request_urls == [
		'https://example.test/app/root.js',
		'https://example.test/app/dep.js',
	]
	root := unsafe { &JavaScriptModuleScript(scripting_fetching_completed_script) }
	assert root.is_linked()

	// Static graph loading reuses both entries populated by modulepreload.
	fetch_external_module_script_graph(fixture.realm, root_url, fixture.settings,
		default_script_fetch_options(), scripting_fetching_complete)
	assert scripting_fetching_request_urls.len == 2

	retry_url := dom.URL{ value: 'https://example.test/app/retry.js' }
	scripting_fetching_retry_count = 0
	assert !fetch_modulepreload_module_script_graph(fixture.realm, retry_url, .script,
		fixture.settings, default_script_fetch_options(), modulepreload_fetching_complete)
	assert fixture.settings.module_map().get(retry_url, 'javascript-or-wasm') == none
	assert fetch_modulepreload_module_script_graph(fixture.realm, retry_url, .script,
		fixture.settings, default_script_fetch_options(), modulepreload_fetching_complete)
	assert scripting_fetching_retry_count == 2
}

fn test_module_fetch_hook_abort_removes_in_progress_entry_for_retry() {
	fixture := scripting_fetching_fixture()!
	url := dom.URL{ value: 'https://example.test/app/aborted-module.js' }
	scripting_fetching_retry_count = 0
	scripting_fetching_completed_script = unsafe { &Script(nil) }
	fetch_worklet_module_worker_script_graph(url, fixture.settings, .worker, fixture.settings,
		scripting_fetching_abort_once_host, scripting_fetching_complete)!
	assert scripting_fetching_completed_script == unsafe { nil }
	assert fixture.settings.module_map().get(url, 'javascript-or-wasm') == none

	fetch_worklet_module_worker_script_graph(url, fixture.settings, .worker, fixture.settings,
		scripting_fetching_abort_once_host, scripting_fetching_complete)!
	assert scripting_fetching_completed_script != unsafe { nil }
	assert fixture.settings.module_map().get(url, 'javascript-or-wasm')?.type_ == .module_script
	assert scripting_fetching_retry_count == 2
}

fn test_modulepreload_populates_typed_module_map_entries() {
	fixture := scripting_fetching_fixture()!
	scripting_fetching_request_urls = []
	text_url := dom.URL{ value: 'https://example.test/app/module.txt' }
	assert fetch_modulepreload_module_script_graph(fixture.realm, text_url, .text,
		fixture.settings, default_script_fetch_options(), scripting_fetching_complete)
	text_entry := fixture.settings.module_map().get(text_url, 'text')?.module_script?
	assert text_entry.kind == .text
	assert text_entry.synthetic_source == 'module text'
	assert text_entry.synthetic_export_names() == ['default']
	assert text_entry.synthetic_default_export()?.string_data == 'module text'
	assert scripting_fetching_last_destination == .text

	style_url := dom.URL{ value: 'https://example.test/app/module.css' }
	assert fetch_modulepreload_module_script_graph(fixture.realm, style_url, .style,
		fixture.settings, default_script_fetch_options(), scripting_fetching_complete)
	style_entry := fixture.settings.module_map().get(style_url, 'css')?.module_script?
	assert style_entry.kind == .css
	assert style_entry.synthetic_source == ':root { color: green; }'
	assert scripting_fetching_last_destination == .style

	json_url := dom.URL{ value: 'https://example.test/app/module.json' }
	assert fetch_modulepreload_module_script_graph(fixture.realm, json_url, .json,
		fixture.settings, default_script_fetch_options(), scripting_fetching_complete)
	json_entry := fixture.settings.module_map().get(json_url, 'json')?.module_script?
	assert json_entry.kind == .json
	assert json_entry.synthetic_source == '{"answer":42}'
	assert scripting_fetching_last_destination == .json
}

fn test_link_modulepreload_dispatches_events_and_preserves_fetch_options() {
	fixture := scripting_fetching_fixture()!
	document := fixture.settings.responsible_document() or { panic('missing document') }
	scripting_fetching_request_urls = []
	mut element := document.create_element_ns(dom.namespace_html_uri, 'link')!
	link_element := unsafe { &dom.HTMLLinkElement(element) }
	mut model := unsafe { &HTMLLinkElementModel(html_link_element_model_for_dom_element(link_element)) }
	model.set_rel('preload modulepreload')
	model.set_href('/app/module.txt')
	model.set_as('text')
	model.set_crossorigin('use-credentials')
	model.integrity_ = 'sha256-link'
	model.referrer_policy_ = 'origin'
	model.fetch_priority_ = 'high'
	mut html_element := unsafe { &dom.HTMLElement(element) }
	html_element.set_cryptographic_nonce('link-nonce')
	model.fetch_and_process_linked_resource()
	assert model.event_count('load') == 1
	assert model.event_count('error') == 0
	assert scripting_fetching_request_urls == ['https://example.test/app/module.txt']
	assert scripting_fetching_last_destination == .text
	assert scripting_fetching_last_credentials == .include
	assert scripting_fetching_last_nonce == 'link-nonce'
	assert scripting_fetching_last_referrer_policy == 'origin'
	assert scripting_fetching_last_priority == .high
	assert scripting_fetching_last_parser_metadata == .not_parser_inserted

	mut suppressed := HTMLLinkElementModel.create(document.base_url())
	suppressed.set_rel('modulepreload')
	suppressed.set_href('/app/suppressed.js')
	suppressed.set_media('not all')
	suppressed.fetch_and_process_linked_resource()
	assert suppressed.event_count('load') == 0
	assert suppressed.event_count('error') == 0
	assert scripting_fetching_request_urls.len == 1

	mut invalid := HTMLLinkElementModel.create(document.base_url())
	invalid.set_rel('modulepreload')
	invalid.set_href('/app/image.png')
	invalid.set_as('image')
	invalid.fetch_and_process_linked_resource()
	assert invalid.event_count('error') == 1
	assert scripting_fetching_request_urls.len == 1
}
