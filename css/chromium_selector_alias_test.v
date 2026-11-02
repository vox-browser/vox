module css

import dom

fn test_chromium_rejects_the_whole_standard_selector_list_with_mozilla_pseudos() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	for policy in [dom.FontRenderingPolicy.libweb, .chromium, .libweb] {
		document.set_font_rendering_policy(policy)
		for alias in ['-moz-placeholder', '-moz-meter-bar', '-moz-progress-bar',
			'-moz-range-progress', '-moz-range-thumb', '-moz-range-track'] {
			sheet := parse_css_stylesheet(ParsingParams{document: document},
				'.search, input::${alias} {color:darkgray} .kept {color:blue}', none, none)
			assert sheet.css_rules().rules.len == if policy == .chromium { 1 } else { 2 }
			assert sheet.css_rules().rules.last().selector_text() == '.kept'
		}
	}
}

fn test_chromium_selector_alias_validation_keeps_forgiving_branches_and_authored_text() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	params := ParsingParams{document: document}
	for selector in ['input::placeholder', 'input::-webkit-input-placeholder',
		'[title="::-moz-placeholder"]', r'.\:\:-moz-placeholder'] {
		assert parse_css_rule(params, '${selector}{color:red}') != none
	}
	for selector in [r'input::-m\6fz-placeholder', ':not(input::-moz-placeholder)',
		':has(> input::-moz-range-thumb)', ':nth-child(2n of input::-moz-placeholder)'] {
		assert parse_css_rule(params, '${selector}{color:red}') == none
	}
	for function in ['is', 'where'] {
		rule := parse_css_rule(params,
			':${function}(.kept, input::-moz-placeholder){color:red}') or { panic('missing forgiving rule') }
		assert rule.selector_text() == ':${function}(.kept)'
	}
}

fn test_selector_alias_memo_does_not_reuse_another_browser_policy() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut parser := RuleSelectorParser{document: document}
	for policy in [dom.FontRenderingPolicy.libweb, .chromium, .libweb] {
		document.set_font_rendering_policy(policy)
		assert (parser.parse_memoized_rule_selector('input::-moz-placeholder', .standalone) != none) == (policy != .chromium)
		// Namespaced selectors bypass the memo, but use the same policy.
		parser.declared_namespaces['html'] = true
		assert (parser.parse_memoized_rule_selector('html|input::-moz-placeholder', .standalone) != none) == (policy != .chromium)
		parser.declared_namespaces.clear()
		assert parser.parse_memoized_rule_selector('input::-webkit-input-placeholder', .standalone) != none
	}
}

fn test_supports_selector_and_forgiving_parser_use_the_same_alias_policy() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		document.set_font_rendering_policy(policy)
		params := ParsingParams{document: document}
		condition := parse_css_supports(params, 'selector(input::-moz-placeholder)') or { panic('missing condition') }
		assert condition.matches_condition() == (policy != .chromium)
		assert parse_css_supports(params, 'selector(input::-webkit-input-placeholder)')?.matches_condition()
		mut parser := RuleSelectorParser.create(params, '.kept,input::-moz-placeholder', 'utf-8')
		selectors := parser.parse_as_selector(.forgiving) or { panic('missing selector list') }
		assert selectors.selectors.len == 2
		assert selectors.selectors[0].serialize() == '.kept'
		assert (selectors.selectors[1].compound_selectors()[0].simple_selectors[0].type_ == .invalid) == (policy == .chromium)
	}
}
