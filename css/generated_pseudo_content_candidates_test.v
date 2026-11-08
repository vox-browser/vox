module css

import dom

fn content_candidates_test_declaration(source string) &CSSStyleProperties {
	sheet := parse_css_stylesheet(ParsingParams{}, 'div::before{${source}}', none, none)
	return sheet.css_rules().rules[0].declaration or { panic('declaration') }
}

fn test_content_candidate_names_do_not_force_lazy_parsing() {
	for source in ['color:red;--content:"custom"', 'padding:var(--gap);border:1px solid'] {
		declaration := content_candidates_test_declaration(source)
		was_deferred := declaration.deferred_declarations_ != none
		assert !declaration_may_set_content_without_parsing(declaration)
		assert (declaration.deferred_declarations_ != none) == was_deferred
	}
	for source in ['CoNtEnT:"text"', 'content:var(--text)', 'content:inherit', 'content:normal',
		'content:none!important', 'all:initial'] {
		declaration := content_candidates_test_declaration(source)
		was_deferred := declaration.deferred_declarations_ != none
		assert declaration_may_set_content_without_parsing(declaration), source
		assert (declaration.deferred_declarations_ != none) == was_deferred
	}
	raw := &CSSStyleProperties{ properties: [CSSStyleProperty{ name: 'content', value: 'invalid-value' }] }
	assert declaration_may_set_content_without_parsing(raw)
	mut declaration := content_candidates_test_declaration('color:red')
	_ = declaration_style_properties(declaration)
	assert !declaration_may_set_content_without_parsing(declaration)
	declaration.set_property('content', '"added"', '')!
	assert declaration_may_set_content_without_parsing(declaration)
	declaration.remove_property('content')!
	assert !declaration_may_set_content_without_parsing(declaration)
}

fn test_content_candidate_preflight_preserves_dynamic_content_and_pseudo_queries() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.html)
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
	mut root := document.create_element('html')!
	mut element := document.create_element('div')!
	element.set_attribute_value('class', 'target')
	mut document_node := document.as_node()
	document_node.append_child(root.as_node())!
	mut root_node := root.as_node()
	root_node.append_child(element.as_node())!
	add_document_author_style_sheet(document,
		'.target::before{color:red;padding:7px}' +
			'.target:hover::before{content:"hovered"}')
	computer := css_style_computer_for(document)
	scope := css_style_scope_for_document(document)
	scope.build_rule_cache_if_needed()
	pseudo := dom.AbstractElement.new(element, dom.PseudoElement.before)
	assert !scope.generated_pseudo_has_no_content_candidates(pseudo, computer)
	assert computer.compute_style_impl(pseudo, .create_pseudo_element_style_if_needed, none, scope) == none
	queried := computer.compute_style(pseudo)
	assert queried.has_attempted_match_against_pseudo_class(.hover)
	document.set_hovered_node(element.as_node())
	created := computer.compute_style_impl(pseudo, .create_pseudo_element_style_if_needed, none, scope) or { panic('hover content') }
	assert created.property(.content, .no)?.css_text.contains('hovered')
	ordinary := computer.compute_style(pseudo)
	assert ordinary.property(.padding_top, .no)?.css_text == '7px'
}

fn test_content_candidate_preflight_clears_previously_published_styles() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.html)
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
	mut element := document.create_element('div')!
	element.set_attribute_value('class', 'generated')
	add_document_author_style_sheet(document,
		'.generated::before{content:"old"}.plain::before{color:red;padding:7px}')
	computer := css_style_computer_for(document)
	mut target := dom.AbstractElement.new(element, none)
	mut changed := false
	_, _ = computer.recompute_style_with_invalidation(mut target, &changed)
	pseudo := dom.AbstractElement.new(element, dom.PseudoElement.before)
	assert pseudo.computed_properties() != none
	element.set_attribute_value('class', 'plain')
	scope := css_style_scope_for_document(document)
	assert scope.generated_pseudo_has_no_content_candidates(pseudo, computer)
	_, _ = computer.recompute_style_with_invalidation(mut target, &changed)
	assert pseudo.computed_properties() == none
	ordinary := computer.compute_style(pseudo)
	assert ordinary.property(.padding_top, .no)?.css_text == '7px'
}

fn test_content_candidate_preflight_keeps_layer_and_origin_sources() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.html)
	defer { document.finalize() }
	mut element := document.create_element('div')!
	element.set_attribute_value('class', 'target')
	add_document_author_style_sheet(document, '@layer generated{.target::after{content:"layer"}}')
	computer := css_style_computer_for(document)
	scope := css_style_scope_for_document(document)
	scope.build_rule_cache_if_needed()
	pseudo := dom.AbstractElement.new(element, dom.PseudoElement.after)
	assert !scope.generated_pseudo_has_no_content_candidates(pseudo, computer)
	for origin in [CascadeOrigin.user, .user_agent] {
		mut isolated := RuleCache.new()
		sheet := parse_css_stylesheet(ParsingParams{}, '.target::after{all:initial}', none, none)
		rule := &MatchingRule{
			rule:           sheet.css_rules().rules[0]
			selector:       sheet.css_rules().rules[0].selectors.selectors[0]
			pseudo_element: PseudoElement.after
		}
		isolated.add_rule(rule, PseudoElement.after, false)
		for layered in [false, true] {
			mut caches := RuleCaches.new()
			if layered {
				caches.by_layer['test'] = isolated
			} else {
				caches.main = isolated
			}
			mut isolated_scope := StyleScope{}
			if origin == .user {
				isolated_scope.user_rule_cache = caches
			} else {
				isolated_scope.user_agent_rule_cache = caches
			}
			assert !isolated_scope.generated_pseudo_has_no_content_candidates(pseudo, computer)
		}
	}
}

fn test_content_candidate_preflight_retains_shadow_and_host_matching() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.html)
	defer { document.finalize() }
	mut host := document.create_element('div')!
	shadow := host.attach_shadow(dom.ShadowRootInit{ mode: .open })!
	mut child := document.create_element('span')!
	mut shadow_node := shadow.as_node()
	shadow_node.append_child(child.as_node())!
	computer := css_style_computer_for(document)
	assert !css_style_scope_for_document(document).generated_pseudo_has_no_content_candidates(dom.AbstractElement.new(host, dom.PseudoElement.before), computer)
	assert !css_style_scope_for_shadow_root(shadow).generated_pseudo_has_no_content_candidates(dom.AbstractElement.new(child, dom.PseudoElement.after), computer)
}
