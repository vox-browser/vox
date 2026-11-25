module css

import dom
import os
import platform

fn test_browser_ua_startup_prepares_then_publishes_the_shared_default_sheet() {
	if !deferred_user_agent_startup { return }
	assert deferred_user_agent_default == unsafe { nil }
	begin_user_agent_stylesheet_startup()
	preparation := user_agent_startup_work
	assert preparation != unsafe { nil }
	assert deferred_user_agent_default == unsafe { nil }
	begin_user_agent_stylesheet_startup()
	assert voidptr(user_agent_startup_work) == voidptr(preparation)
	discard_user_agent_stylesheet_startup()
	assert user_agent_startup_work == unsafe { nil }
	assert deferred_user_agent_default == unsafe { nil }

	begin_user_agent_stylesheet_startup()
	sheet := user_agent_default_style_sheet('CSS/Default.css') or { panic('missing default sheet') }
	assert sheet.process_lifetime
	assert sheet.rules.length() > 0
	assert user_agent_startup_work == unsafe { nil }
	finish_user_agent_stylesheet_startup()
	assert voidptr(default_user_agent_stylesheet()) == voidptr(sheet)
	begin_user_agent_stylesheet_startup()
	assert user_agent_startup_work == unsafe { nil }
}

fn read_default_ua_sheet_in_worker_scratch() &CSSStyleSheet {
	scratch := platform.begin_thread_scratch('UA sheet caller scratch')
	defer { scratch.finish() }
	return default_user_agent_stylesheet()
}

fn test_default_ua_sheet_published_by_a_worker_outlives_its_caller() {
	if !deferred_user_agent_startup { return }
	previous := deferred_user_agent_default
	deferred_user_agent_default = unsafe { nil }
	defer { deferred_user_agent_default = previous }
	worker := spawn read_default_ua_sheet_in_worker_scratch()
	sheet := worker.wait()
	assert voidptr(default_user_agent_stylesheet()) == voidptr(sheet)
	rule := sheet.rules.item(0) or { panic('missing default rule') }
	assert rule.css_text() != ''
}

fn test_user_agent_lazy_rules_serialize_exactly_as_eager_rules() {
	previous := os.getenv_opt('VOX_EAGER_USER_AGENT_DECLARATIONS')
	defer {
		if value := previous { os.setenv('VOX_EAGER_USER_AGENT_DECLARATIONS', value, true) }
		else { os.unsetenv('VOX_EAGER_USER_AGENT_DECLARATIONS') }
	}
	for source in [user_agent_cascade_stylesheet_source, user_agent_mathml_stylesheet_source, user_agent_svg_stylesheet_source] {
		os.unsetenv('VOX_EAGER_USER_AGENT_DECLARATIONS')
		lazy := parse_shared_user_agent_stylesheet(source)
		os.setenv('VOX_EAGER_USER_AGENT_DECLARATIONS', '1', true)
		eager := parse_shared_user_agent_stylesheet(source)
		assert lazy.process_lifetime && eager.process_lifetime
		assert lazy.rules.length() == eager.rules.length()
		mut deferred := 0
		for index in 0 .. lazy.rules.length() {
			rule := lazy.rules.item(index) or { panic('lazy rule') }
			reference := eager.rules.item(index) or { panic('eager rule') }
			if declaration := rule.declaration {
				if declaration.deferred_declarations_ != none { deferred++ }
			}
			assert rule.css_text() == reference.css_text()
		}
		assert deferred > 0
	}
}

fn test_process_lifetime_ua_declarations_outlive_the_materializing_document_arena() {
	sheet := parse_shared_user_agent_stylesheet('div { display: block; color: rgb(11 22 33); width: 13px; }')
	rule := sheet.rules.item(0) or { panic('UA rule') }
	mut document := dom.Document.create(dom.url_about_blank())
	$if prealloc { document.enable_native_storage() }
	mut owner := document.enter_native_storage()
	scratch := platform.begin_thread_scratch('deferred UA properties')
	mut declaration := rule.style() or { panic('UA declaration') }
	assert declaration.get_property_value('width') == '13px'
	scratch.finish()
	owner.finish()
	document.release_native_storage()
	assert declaration.get_property_value('color') == 'rgb(11, 22, 33)'
	assert declaration.get_property_value('display') == 'block'
	declaration.set_property('width', '17px', '')!
	assert declaration.get_property_value('width') == '17px'
	assert declaration.get_property_value('color') == 'rgb(11, 22, 33)'
}

fn test_worker_user_agent_syntax_retires_before_the_published_sheet_is_used() {
	$if macos && prealloc && !vox_css_diagnostics ? {
		if bulk_css_input_probe_diagnostics { return }
		release_unused_stylesheet_syntax()
		actual := load_user_agent_stylesheets_with_worker()
		if user_agent_selector_worker_available() {
			storage := actual.default_sheet.user_agent_selector_storage_
			assert storage != unsafe { nil }
			first := actual.default_sheet.rules.item(0) or { panic('missing default rule') }
			selector := first.selectors.selectors[0]
			assert storage.arena.contains(voidptr(selector.data_))
			assert selector.text() == 'html'
			assert selector.has_invalidation_projection() == prepare_user_agent_selector_invalidation
			if selector.has_invalidation_projection() {
				groups := selector_groups_for_invalidation(selector)
				assert storage.arena.contains(groups.data)
				assert groups[0].simple_selectors[0].name == 'html'
			}
		}
		if !disable_stylesheet_rule_cache && stylesheet_rule_cache_.eligible(user_agent_cascade_stylesheet_source) {
			entry := stylesheet_rule_cache_.lookup(user_agent_cascade_stylesheet_source) or {
				panic('missing startup syntax cache entry')
			}
			assert entry.id == actual.default_sheet.source_syntax_id_
			assert entry.storage.arena.contains(entry.rules.data)
			// Convert a fresh sheet from the entry after the worker's raw
			// parser arena and thread have both been retired.
			warm := parse_shared_user_agent_stylesheet(user_agent_cascade_stylesheet_source)
			assert warm.source_syntax_id_ == entry.id
			assert warm.rules.length() == actual.default_sheet.rules.length()
			entry.release()
			release_unused_stylesheet_syntax()
			for index, rule in warm.rules.rules {
				assert rule.css_text() == actual.default_sheet.rules.rules[index].css_text()
			}
		}
		serial := parse_shared_user_agent_stylesheet(user_agent_cascade_stylesheet_source)
		// The worker has already released its input. Serializing every rule
		// also forces lazy values to read their retained source spelling.
		assert actual.default_sheet.process_lifetime
		assert actual.default_sheet.rules.length() == serial.rules.length()
		for index in 0 .. serial.rules.length() {
			rule := actual.default_sheet.rules.item(index) or { panic('worker rule') }
			reference := serial.rules.item(index) or { panic('serial rule') }
			assert rule.css_text() == reference.css_text()
		}
	}
}

fn test_prepared_user_agent_selectors_allow_namespace_and_nested_fallback() {
	$if macos && prealloc && !vox_css_diagnostics ? {
		if !user_agent_selector_worker_available() { return }
		source := '@namespace x url("urn:x"); x|a { color: red } .parent { & > b { color: blue } } .bad, > .invalid { color: green }'
		scratch := platform.begin_thread_scratch('raw selector test')
		mut parser := RuleSelectorParser{
			token_stream: ParserTokenStream.from_transient_source(source, 'utf-8')
			is_ua_style_sheet: .yes
		}
		raw := parser.parse_a_stylesheet(none)
		prepared, worker_storage := prepare_user_agent_selector_lists(raw.rules)
		mut detached := worker_storage
		assert prepared.lists.len == 1
		scratch.leave()
		actual := convert_transient_stylesheet_rules(ParsingParams{is_ua_style_sheet: .yes},
			raw.rules, none, none, deferred: true, prepared_selectors: prepared)
		mut storage := detached.adopt('user agent stylesheet selectors')
		storage.release()
		scratch.finish()
		expected := parse_shared_user_agent_stylesheet(source)
		assert actual.rules.length() == 3
		assert actual.rules.length() == expected.rules.length()
		for index, rule in actual.rules.rules {
			assert rule.css_text() == expected.rules.rules[index].css_text()
		}
	}
}
