module html

import dom
import page

fn classic_script_owner_fixture(value string) !(&page.Page, &dom.Document, &ScriptingRealm) {
	owner := page.Page.create(1)!
	url := dom.URL{value: value}
	document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	settings := unsafe { &EnvironmentSettingsObject(document.relevant_settings_object()) }
	return owner, document, settings.realm()
}

fn classic_owner_parse(source string, _ string, _ uint) ! {
	if source == 'invalid' { return error('original parse failure') }
}

fn classic_owner_evaluate(source string, _ &ScriptingRealm) !dom.JSValue {
	return dom.js_string(source)
}

fn test_source_classic_create_replaces_disabled_source_before_parsing_in_actual_owner() {
	mut owner, _, realm := classic_script_owner_fixture('https://classic.example/')!
	owner.set_is_scripting_enabled(false)
	mut script := ClassicScript.create_with_parser('disabled.js', 'invalid', realm, dom.url_about_blank(), 1, .no, classic_owner_parse)
	assert script.source == ''
	assert script.parse_error == none && script.error_to_rethrow == none
	script.set_evaluator(classic_owner_evaluate)
	before := realm.microtask_checkpoint_count
	result := script.run(.yes)!
	assert result.kind == .undefined
	assert realm.microtask_checkpoint_count == before
	owner.set_is_scripting_enabled(true)
	assert script.run(.yes)!.string_data == ''
}

fn test_source_classic_create_uses_exact_webui_exemption_and_sandbox() {
	mut owner, mut document, realm := classic_script_owner_fixture('about:settings')!
	owner.set_is_scripting_enabled(false)
	allowed := ClassicScript.create_with_parser('settings.js', 'invalid', realm, document.url, 1, .no, classic_owner_parse)
	assert allowed.source == 'invalid' && allowed.parse_error? == 'original parse failure'
	document.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_scripts))
	disabled := ClassicScript.create('sandbox.js', 'kept', realm, document.url, 1, .no)
	assert disabled.source == ''
	document.set_active_sandboxing_flag_bits(0)
	document.set_url(dom.URL{value: 'about:settings#'})
	assert ClassicScript.create('fragment.js', 'kept', realm, document.url, 1, .no).source == ''
}

fn test_source_classic_preparsed_and_compiled_constructors_retain_original_source_while_disabled() {
	mut owner, _, realm := classic_script_owner_fixture('https://classic.example/')!
	owner.set_is_scripting_enabled(false)
	preparsed := ClassicScript.create_from_pre_parsed('parsed.js', 'invalid', realm, dom.url_about_blank(), classic_owner_parse, .no)
	assert preparsed.source == 'invalid' && preparsed.error_to_rethrow? == 'original parse failure'
	parsed := ClassicScript.create_from_parsed_program('program.js', 'original', realm, dom.url_about_blank(), ParsedProgram{}, .no)
	assert parsed.source == 'original'
	mut compiled := ClassicScript.create_from_pre_compiled('compiled.js', 'original compiled source', realm, dom.URL{value: 'https://other.example/script'}, CompiledProgram{ program_type: .script }, .yes)
	assert compiled.source == 'original compiled source'
	assert compiled.base_url? == dom.url_about_blank()
	compiled.set_evaluator(classic_owner_evaluate)
	assert compiled.run(.yes)!.kind == .undefined
	owner.set_is_scripting_enabled(true)
	assert compiled.run(.yes)!.string_data == 'original compiled source'
	owner.set_is_scripting_enabled(false)
	cached := ClassicScript.create_from_bytecode_cache('cache.js', 'original cache source', realm, dom.url_about_blank(), [], fn (_ []u8, _ string, _ string, _ uint, _ ScriptProgramType) !&ScriptExecutable {
		return error('cache failure')
	}, .no)
	assert cached.source == 'original cache source' && cached.error_to_rethrow? == 'cache failure'
}

fn test_source_classic_run_checks_activity_and_scripting_before_rethrow_or_context_entry() {
	mut owner, document, mut realm := classic_script_owner_fixture('https://classic.example/')!
	mut script := ClassicScript.create_with_parser('invalid.js', 'invalid', realm, dom.url_about_blank(), 1, .no, classic_owner_parse)
	before := realm.microtask_checkpoint_count
	owner.set_is_scripting_enabled(false)
	assert script.run(.yes)!.kind == .undefined
	assert realm.microtask_checkpoint_count == before && realm.script_execution_depth == 0
	assert realm.reported_exceptions.len == 0 && realm.active_classic_script_ == none
	owner.set_is_scripting_enabled(true)
	mut navigable := document.navigable()?
	navigable.is_top_level_traversable_ = false
	assert script.run(.yes)!.kind == .undefined
	assert realm.microtask_checkpoint_count == before && realm.script_execution_depth == 0
	navigable.is_top_level_traversable_ = true
	if _ := script.run(.yes) {
		assert false
	} else {
		assert err.msg() == 'original parse failure'
	}
	assert realm.microtask_checkpoint_count == before + 1
}

fn test_source_classic_owned_constructor_and_run_ignore_standalone_realm_flags() {
	_, _, mut realm := classic_script_owner_fixture('https://classic.example/')!
	realm.can_run = false
	realm.scripting_enabled = false
	mut script := ClassicScript.create('owner.js', 'actual owner', realm, dom.url_about_blank(), 1, .no)
	script.set_evaluator(classic_owner_evaluate)
	assert script.source == 'actual owner'
	assert script.run(.yes)!.string_data == 'actual owner'
}
