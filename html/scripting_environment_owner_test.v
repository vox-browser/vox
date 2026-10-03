module html

import dom
import page

fn scripting_owner_fixture(value string) !(&page.Page, &dom.Document, &EnvironmentSettingsObject) {
	mut owner := page.Page.create(1)!
	url := dom.URL{value}
	mut document := create_navigation_document(url, url.origin(), none)!
	document.set_page(unsafe { &dom.Page(owner) })
	settings := unsafe { &EnvironmentSettingsObject(document.relevant_settings_object()) }
	return owner, document, settings
}

fn test_source_node_gate_reads_actual_page_preference_and_sandbox_for_own_settings() {
	mut owner, mut document, settings := scripting_owner_fixture('https://scripting.example/')!
	node := document.create_element('button')!.as_node()
	assert document.page().has_scripting_enabled_owner()
	assert node.relevant_scripting_environment_ != none
	assert node.relevant_scripting_document_ == unsafe { nil }
	assert node.is_scripting_enabled() && is_scripting_enabled_for_settings(settings)
	owner.set_is_scripting_enabled(false)
	assert node.is_scripting_disabled() && is_scripting_disabled_for_settings(settings)
	assert can_run_script_for_settings(settings) == .do_not_run
	owner.set_is_scripting_enabled(true)
	document.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_scripts))
	assert node.is_scripting_disabled() && is_scripting_disabled_for_settings(settings)
	document.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_forms))
	assert node.is_scripting_enabled()
}

fn test_source_webui_exempts_user_preference_but_never_sandbox_or_nonexact_urls() {
	mut owner, mut document, settings := scripting_owner_fixture('about:settings')!
	owner.set_is_scripting_enabled(false)
	assert is_scripting_enabled_for_settings(settings)
	document.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_scripts))
	assert is_scripting_disabled_for_settings(settings)
	document.set_active_sandboxing_flag_bits(0)
	for value in ['about:settings#', 'about:settings?', 'about:blank', 'about:Settings'] {
		document.set_url(dom.URL{value})
		assert is_scripting_disabled_for_settings(settings)
	}
}

fn test_source_scripting_enabled_does_not_include_fully_active_or_standalone_realm_run_flags() {
	_, document, settings := scripting_owner_fixture('https://scripting.example/')!
	window := unsafe { &WindowModel(document.get_window() or { panic('Window') }) }
	mut navigable := document.navigable() or { panic('navigable') }
	navigable.is_top_level_traversable_ = false
	assert is_scripting_enabled_for_settings(settings)
	assert document.create_element('button')!.as_node().is_scripting_enabled()
	assert can_run_script_for_settings(settings) == .do_not_run
	navigable.is_top_level_traversable_ = true
	mut realm := unsafe { &ScriptingRealm(settings.realm()) }
	realm.scripting_enabled = false
	realm.can_run = false
	assert is_scripting_enabled_for_settings(settings)
	assert can_run_script_for_settings(settings) == .run
}

fn test_source_adopted_nodes_use_new_document_context_and_original_settings_identity() {
	mut source_owner, mut source, source_settings := scripting_owner_fixture('https://first.example/')!
	mut target_owner, mut target, target_settings := scripting_owner_fixture('https://second.example/')!
	root := source.create_element('div')!
	child := source.create_element('button')!
	mut root_node := root.as_node()
	root_node.append_child(child.as_node())!
	root_node.append_child(source.create_text_node('owned text').as_node())!
	source_environment := root.as_node().relevant_scripting_environment_ or { panic('settings') }
	assert source_environment.settings == voidptr(source_settings)
	target_owner.set_is_scripting_enabled(false)
	target.adopt_node(root.as_node())
	assert voidptr(root.document()) == voidptr(target)
	assert root.as_node().is_scripting_enabled() && child.as_node().is_scripting_enabled()
	assert root.as_node().children[1].is_scripting_enabled()
	assert (root.as_node().relevant_scripting_environment_ or { panic('settings') }).settings == voidptr(source_settings)
	assert root.as_node().relevant_scripting_document_ == unsafe { nil }
	copy := root.as_node().clone_single_node(target)!
	assert (copy.relevant_scripting_environment_ or { panic('clone settings') }).settings == voidptr(target_settings)
	assert copy.is_scripting_disabled()
	source_owner.set_is_scripting_enabled(false)
	target_owner.set_is_scripting_enabled(true)
	assert root.as_node().is_scripting_disabled()
	source_owner.set_is_scripting_enabled(true)
	mut detached := dom.Document.create(dom.url_about_blank())
	detached.adopt_node(root.as_node())
	assert root.as_node().is_scripting_disabled()
}

fn test_source_document_constructor_binds_actual_setting_identity_eagerly() {
	_, document, settings := scripting_owner_fixture('https://scripting.example/')!
	node := document.as_node()
	assert (node.relevant_scripting_environment_ or { panic('eager Document realm') }).settings == voidptr(settings)
	assert node.relevant_scripting_document_ == unsafe { nil }
}

fn test_source_owned_parser_noscript_mode_reads_page_preference_and_sandbox() {
	mut owner, document, _ := scripting_owner_fixture('https://scripting.example/')!
	owner.set_is_scripting_enabled(false)
	parse_html_from_a_string(document, '<!doctype html><body><noscript><b id="fallback">text</b></noscript>')
	assert document.get_element_by_id('fallback') != none
	mut enabled_owner, enabled_document, _ := scripting_owner_fixture('https://scripting.example/')!
	enabled_owner.set_is_scripting_enabled(true)
	parse_html_from_a_string(enabled_document, '<!doctype html><body><noscript><b id="fallback">text</b></noscript>')
	assert enabled_document.get_element_by_id('fallback') == none
}

fn test_source_worker_scripting_enabled_keeps_pinned_nonwindow_behavior() {
	_, document, settings := scripting_owner_fixture('https://scripting.example/')!
	outside := settings.serialize()
	mut realm := &ScriptingRealm{ scripting_enabled: false, can_run: false }
	scope := WorkerGlobalScope.create(dom.URL{'https://scripting.example/worker.js'}, .classic, '', realm)
	worker := WorkerEnvironmentSettingsObject.setup(scope, mut realm, outside, 1)
	assert is_scripting_enabled_for_settings(worker.settings)
	assert !is_scripting_disabled_for_settings(worker.settings)
	assert can_run_script_for_settings(worker.settings) == .run
	assert document.url.serialize() == 'https://scripting.example/'
}
