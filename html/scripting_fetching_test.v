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
	scripting_fetching_parsed           ParsedProgram
	scripting_fetching_parsed_source    string
	scripting_fetching_compiled         OffThreadCompiledProgram
	scripting_fetching_compiled_source  string
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
	return response
}

fn scripting_fetching_complete(script ?&Script) {
	scripting_fetching_completed_script = script or { unsafe { &Script(nil) } }
}

fn scripting_fetching_parser(source string, filename string, line usize) ! {
	_ = filename
	_ = line
	if source == 'invalid' {
		return error('syntax error')
	}
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

	assert module_type_from_module_request(ModuleRequest{}) == 'javascript'
	assert module_type_from_module_request(ModuleRequest{
		attributes: [ModuleRequestAttribute{ key: 'type', value: 'json' }]
	}) == 'json'
	assert module_type_from_module_request(ModuleRequest{
		attributes: [ModuleRequestAttribute{ key: 'type', value: 'javascript' }]
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

	compile_off_thread('valid', .script, 1, scripting_fetching_parser, scripting_fetching_compiled_callback)
	assert scripting_fetching_compiled.compiled?.program_type == .script
	assert scripting_fetching_compiled.compiled?.line_number_offset == 1
	assert scripting_fetching_compiled.parsed == none
	assert scripting_fetching_compiled_source == 'valid'
	compile_off_thread('invalid', .module, 0, scripting_fetching_parser, scripting_fetching_compiled_callback)
	assert scripting_fetching_compiled.compiled == none
	assert scripting_fetching_compiled.parsed?.error? == 'syntax error'
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
	settings.set_script_compile_hook(scripting_fetching_parser)
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
	assert scripting_fetching_last_destination == .script
	assert scripting_fetching_last_nonce == 'classic-nonce'

	scripting_fetching_completed_script = unsafe { &Script(nil) }
	fetch_classic_script(element, dom.URL{ value: 'https://example.test/app/syntax.js' }, fixture.settings, options, .anonymous, 'utf-8', scripting_fetching_complete)
	broken := unsafe { &ClassicScript(scripting_fetching_completed_script) }
	assert broken.compiled_program == none
	assert broken.parse_error? == 'syntax error'
	assert broken.error_to_rethrow? == 'syntax error'

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
	settings.set_script_compile_hook(scripting_fetching_parser)
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
	assert root.requested_modules().len == 1
	assert scripting_fetching_request_urls == [
		'https://example.test/app/root.js',
		'https://example.test/app/dep.js',
	]
	module_map := fixture.settings.module_map()
	assert module_map.get(dom.URL{ value: 'https://example.test/app/root.js' }, 'javascript')?.type_ == .module_script
	assert module_map.get(dom.URL{ value: 'https://example.test/app/dep.js' }, 'javascript')?.type_ == .module_script

	// A second graph load reuses the module-map entries and performs no fetch.
	fetch_external_module_script_graph(fixture.realm, dom.URL{
		value: 'https://example.test/app/root.js'
	}, fixture.settings, default_script_fetch_options(), scripting_fetching_complete)
	assert scripting_fetching_request_urls.len == 2
	assert fetch_destination_from_module_type(.script, 'json') == .json
	assert fetch_destination_from_module_type(.worker, 'css') == .style
	assert fetch_destination_from_module_type(.worker, 'javascript') == .worker
}
