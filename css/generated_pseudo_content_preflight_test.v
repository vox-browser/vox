module css

import dom

fn content_preflight_rule_set(source string) MatchingRuleSet {
	sheet := parse_css_stylesheet(ParsingParams{}, 'div::before{${source}}', none, none)
	rule := sheet.css_rules().rules[0]
	return MatchingRuleSet{
		author_rules: [LayerMatchingRules{
			rules: [ScopedMatchingRule{
				rule: &MatchingRule{ rule: rule }
			}]
		}]
	}
}

fn test_generated_content_preflight_keeps_all_content_sources_and_cssom_changes() {
	for source in ['color:red; margin:1px; border:2px solid; --text:"hello"',
		'font:16px serif; background:var(--missing, red); margin:var(--gap, 1px)'] {
		assert generated_pseudo_has_no_content_declaration(content_preflight_rule_set(source))
	}
	for source in ['content:"hello"', 'content:var(--text)', 'content:inherit', 'content:normal',
		'content:none!important', 'all:initial', 'all:var(--reset)'] {
		rules := content_preflight_rule_set(source)
		assert !generated_pseudo_has_no_content_declaration(rules)
		for origin in [CascadeOrigin.user_agent, .user] {
			scoped := rules.author_rules[0].rules
			other := if origin == .user_agent {
				MatchingRuleSet{ user_agent_rules: scoped }
			} else {
				MatchingRuleSet{ user_rules: scoped }
			}
			assert !generated_pseudo_has_no_content_declaration(other)
		}
	}
	rules := content_preflight_rule_set('color:red')
	mut declaration := rules.author_rules[0].rules[0].rule.rule?.style()?
	assert generated_pseudo_has_no_content_declaration(rules)
	declaration.set_property('content', '"added"', '')!
	assert !generated_pseudo_has_no_content_declaration(rules)
	declaration.remove_property('content')!
	assert generated_pseudo_has_no_content_declaration(rules)
}

fn test_generated_content_preflight_preserves_ordinary_pseudo_style_queries() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut element := document.create_element('div')!
	element.set_attribute_value('class', 'target')
	add_document_author_style_sheet(document, '.target::before{color:red;padding:7px;--text:"kept"}')
	computer := css_style_computer_for(document)
	scope := css_style_scope_for_document(document)
	pseudo := dom.AbstractElement.new(element, dom.PseudoElement.before)
	assert computer.compute_style_impl(pseudo, .create_pseudo_element_style_if_needed, none, scope) == none
	ordinary := computer.compute_style(pseudo)
	assert ordinary.property(.padding_top, .no)?.css_text == '7px'
	add_document_author_style_sheet(document, '.target::before{content:var(--text)}')
	created := computer.compute_style_impl(pseudo, .create_pseudo_element_style_if_needed, none, scope) or { panic('missing generated content') }
	assert created.property(.content, .no)?.css_text.contains('kept')
}
