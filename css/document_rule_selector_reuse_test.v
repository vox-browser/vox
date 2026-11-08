module css

import dom
import platform

fn test_document_selector_memo_survives_parser_scratch_and_keeps_rules_independent() {
	$if !prealloc {
		return
	}
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer {
		owner.finish()
		document.finalize()
		document.release_native_storage()
	}
	work := platform.begin_thread_scratch('document selector source')
	mut parser := RuleSelectorParser{ document: document }
	parsed := parser.parse_memoized_rule_selector('.card:is(.a,.b):has(> .flag)'.clone(), .standalone) or { panic('selector') }
	work.finish()
	churn := platform.begin_thread_scratch('overwrite document selector source')
	_ = 'overwrite '.repeat(16384)
	churn.finish()
	first := parse_css_stylesheet(ParsingParams{ document: document },
		'.card:is(.a,.b):has(> .flag){color:red}', none, none)
	second := parse_css_stylesheet(ParsingParams{ document: document },
		'.card:is(.a,.b):has(> .flag){width:20px}', none, none)
	mut first_rule := first.css_rules().rules[0]
	second_rule := second.css_rules().rules[0]
	first_selector := first_rule.selectors.selectors[0]
	second_selector := second_rule.selectors.selectors[0]
	assert voidptr(parsed.data_) == voidptr(first_selector.data_)
	assert voidptr(first_selector.data_) == voidptr(second_selector.data_)
	assert document.native_storage().arena.contains(voidptr(first_selector.data_))
	original := second_rule.selector_text()
	first_rule.set_selector_text('.replacement')
	assert second_rule.selector_text() == original
	mut declaration := first_rule.style() or { panic('missing declaration') }
	declaration.set_property('color', 'blue', '')!
	assert second_rule.style()?.get_property_value('color') == ''
	assert second_rule.style()?.get_property_value('width') == '20px'
}

fn test_document_selector_memo_separates_documents_namespaces_and_validation_policy() {
	$if !prealloc {
		return
	}
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	mut parser := RuleSelectorParser{ document: document }
	standalone := parser.parse_memoized_rule_selector('.card', .standalone) or { panic('selector') }
	relative := parser.parse_memoized_rule_selector('.card', .relative) or { panic('selector') }
	assert voidptr(standalone.data_) != voidptr(relative.data_)
	assert parser.parse_memoized_rule_selector('> .card', .standalone) == none
	assert parser.parse_memoized_rule_selector('> .card', .relative) != none
	assert parser.parse_memoized_rule_selector('s|path', .standalone) == none
	parser.declared_namespaces['s'] = true
	assert parser.parse_memoized_rule_selector('s|path', .standalone) != none
	parser.declared_namespaces.clear()
	assert parser.parse_memoized_rule_selector('s|path', .standalone) == none
	_ = parser.parse_memoized_rule_selector('input::-moz-placeholder', .standalone) or { panic('libweb alias') }
	document.set_font_rendering_policy(.chromium)
	assert parser.parse_memoized_rule_selector('input::-moz-placeholder', .standalone) == none
	owner.finish()
	mut other := dom.Document.create(dom.url_about_blank())
	other.enable_native_storage()
	mut other_owner := other.enter_native_storage()
	mut other_parser := RuleSelectorParser{ document: other }
	other_selector := other_parser.parse_memoized_rule_selector('.card', .standalone) or { panic('selector') }
	assert voidptr(standalone.data_) != voidptr(other_selector.data_)
	other_owner.finish()
	other.finalize()
	other.release_native_storage()
	document.release_native_storage()
	assert document.rule_selector_memo_handle_ == unsafe { nil }
	// Re-enabling native storage cannot expose the retired memo.
	document.enable_native_storage()
	mut replacement_owner := document.enter_native_storage()
	mut replacement := RuleSelectorParser{ document: document }
	selector := replacement.parse_memoized_rule_selector('.card', .standalone) or { panic('selector') }
	assert selector.serialize() == '.card'
	assert document.native_storage().arena.contains(voidptr(selector.data_))
	replacement_owner.finish()
	document.finalize()
	document.release_native_storage()
}
