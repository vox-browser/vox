module css

import dom

fn duplicate_document() (&dom.Document, &dom.Element) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.html)
	mut html := document.create_element('html') or { panic(err) }
	mut head := document.create_element('head') or { panic(err) }
	mut body := document.create_element('body') or { panic(err) }
	mut document_node := document.as_node()
	document_node.append_child(html.as_node()) or { panic(err) }
	mut html_node := html.as_node()
	html_node.append_child(head.as_node()) or { panic(err) }
	html_node.append_child(body.as_node()) or { panic(err) }
	return document, head
}

fn duplicate_style(document &dom.Document, text string) &dom.Element {
	mut owner := document.create_element('style') or { panic(err) }
	mut owner_node := owner.as_node()
	owner_node.append_child(document.create_text_node(text).as_node()) or { panic(err) }
	return owner
}

fn duplicate_add_sheet(document &dom.Document, head &dom.Element, text string) &dom.Element {
	owner := duplicate_style(document, text)
	mut head_node := head.as_node()
	head_node.append_child(owner.as_node()) or { panic(err) }
	return owner
}

// Sources of at least 16 KB take the stylesheet rule cache, whose entry ids
// identify identical copies.
fn duplicate_sheet_source(rules string) string {
	return '/*' + 'padding'.repeat(2400) + '*/' + rules
}

fn duplicate_class_rules(scope &StyleScope, class_name string) []&MatchingRule {
	caches := scope.author_rule_cache or { return []&MatchingRule{} }
	return caches.main.rules_by_class[class_name] or { []&MatchingRule{} }
}

fn duplicate_rule_value(rule &MatchingRule) string {
	owner := rule.rule or { return '' }
	declaration := owner.style() or { return '' }
	return declaration.get_property_value('color')
}

fn duplicate_winner(rules []&MatchingRule) string {
	mut winner := rules[0]
	for rule in rules {
		if rule.specificity > winner.specificity
			|| (rule.specificity == winner.specificity && rule.style_sheet_index > winner.style_sheet_index) {
			winner = rule
		}
	}
	return duplicate_rule_value(winner)
}

fn test_identical_sheets_index_one_copy_at_the_latest_position() {
	mut document, head := duplicate_document()
	defer { document.finalize() }
	shared := duplicate_sheet_source('.a{color:red} .only{color:green}')
	duplicate_add_sheet(document, head, shared)
	duplicate_add_sheet(document, head, '.a{color:blue}')
	duplicate_add_sheet(document, head, shared)
	mut scope := css_style_scope_for_document(document)
	scope.build_rule_cache_if_needed()
	sheets := scope.stylesheets_for_cascade_origin(.author)
	assert sheets[0].source_syntax_id_ != 0 && sheets[0].source_syntax_id_ == sheets[2].source_syntax_id_
	only := duplicate_class_rules(scope, 'only')
	assert only.len == 1
	indexed := only[0].sheet or { panic('missing sheet') }
	assert voidptr(indexed) == voidptr(sheets[2])
	rules := duplicate_class_rules(scope, 'a')
	assert rules.len == 2
	// The latest copy follows the sheet between the copies and wins.
	assert duplicate_winner(rules) == 'red'
}

fn test_an_appended_identical_sheet_moves_the_indexed_copy_after_later_sheets() {
	mut document, head := duplicate_document()
	defer { document.finalize() }
	shared := duplicate_sheet_source('.a{color:red} .only{color:green}')
	duplicate_add_sheet(document, head, shared)
	duplicate_add_sheet(document, head, '.a{color:blue}')
	mut scope := css_style_scope_for_document(document)
	scope.build_rule_cache_if_needed()
	assert duplicate_winner(duplicate_class_rules(scope, 'a')) == 'blue'
	before := rule_cache_extension_count()
	duplicate_add_sheet(document, head, shared)
	scope.build_rule_cache_if_needed()
	assert rule_cache_extension_count() == before + 1
	assert duplicate_class_rules(scope, 'only').len == 1
	rules := duplicate_class_rules(scope, 'a')
	assert rules.len == 2
	assert duplicate_winner(rules) == 'red'
}

fn test_mutated_and_copy_dependent_sheets_index_every_copy() {
	mut document, head := duplicate_document()
	defer { document.finalize() }
	shared := duplicate_sheet_source('.only{color:green}')
	duplicate_add_sheet(document, head, shared)
	duplicate_add_sheet(document, head, shared)
	mut scope := css_style_scope_for_document(document)
	scope.build_rule_cache_if_needed()
	assert duplicate_class_rules(scope, 'only').len == 1
	mut sheets := scope.stylesheets_for_cascade_origin(.author)
	mut mutated := sheets[0]
	mutated.insert_rule('.other{color:red}', 0) or { panic(err) }
	scope.build_rule_cache_if_needed()
	assert duplicate_class_rules(scope, 'only').len == 2

	layered := duplicate_sheet_source('@layer {.anonymous{color:red}} @layer named {.named{color:red}}')
	duplicate_add_sheet(document, head, layered)
	duplicate_add_sheet(document, head, layered)
	scope.build_rule_cache_if_needed()
	caches := scope.author_rule_cache or { panic('missing author caches') }
	mut anonymous := 0
	for _, cache in caches.by_layer {
		anonymous += (cache.rules_by_class['anonymous'] or { []&MatchingRule{} }).len
	}
	assert anonymous == 2
}

fn test_imported_and_constructed_sheets_have_no_duplicate_identity() {
	mut constructed := CSSStyleSheet.create(CSSRuleList.create([]&CSSRule{}), MediaList.create_empty(), none)
	constructed.source_syntax_id_ = 7
	assert constructed.duplicate_identity() != none
	constructed.constructed = true
	assert constructed.duplicate_identity() == none
	mut imported := CSSStyleSheet.create(CSSRuleList.create([]&CSSRule{}), MediaList.create_empty(), none)
	imported.source_syntax_id_ = 7
	imported.content_mutated_ = true
	assert imported.duplicate_identity() == none
}

fn test_a_declaration_changed_through_cssom_indexes_every_copy() {
	mut document, head := duplicate_document()
	defer { document.finalize() }
	shared := duplicate_sheet_source('.declared{color:green}')
	duplicate_add_sheet(document, head, shared)
	duplicate_add_sheet(document, head, shared)
	mut scope := css_style_scope_for_document(document)
	scope.build_rule_cache_if_needed()
	assert duplicate_class_rules(scope, 'declared').len == 1
	sheets := scope.stylesheets_for_cascade_origin(.author)
	mut rule := sheets[0].rules.rules[0]
	mut declaration := rule.style() or { panic('missing declaration') }
	declaration.set_property('color', 'blue', '') or { panic(err) }
	assert sheets[0].content_mutated_
	scope.invalidate_rule_cache()
	scope.build_rule_cache_if_needed()
	rules := duplicate_class_rules(scope, 'declared')
	assert rules.len == 2
	assert duplicate_winner(rules) == 'green'
}
