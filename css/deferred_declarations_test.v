module css

import strings
import dom

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn deferred_sheet_for_test(source string) &CSSStyleSheet {
	mut parser := RuleSelectorParser.create(ParsingParams{}, source, 'utf-8')
	parser.defer_style_declarations = true
	return parser.parse_as_css_stylesheet('https://example.test/css/initial.css', none)
}

fn test_unused_declarations_stay_deferred_until_cssom_access() {
	sheet := deferred_sheet_for_test('.unused { color: red; } .used { width: 1/**/px; height: 2px; --word: "hello"; }')
	unused := sheet.css_rules().item(0) or { panic('missing unused rule') }
	used := sheet.css_rules().item(1) or { panic('missing used rule') }
	unused_raw := unused.declaration or { panic('missing deferred declaration') }
	assert unused_raw.deferred_declarations_ != none
	used_raw := used.declaration or { panic('missing used declaration') }
	assert used_raw.get_property_value('width') == ''
	assert used_raw.get_property_value('height') == '2px'
	assert used_raw.get_property_value('--word') == '"hello"'
	assert used_raw.length() == 2
	assert used_raw.deferred_declarations_ == none
	assert unused_raw.deferred_declarations_ != none
}

fn test_deferred_serialization_matches_eager_parsing_and_mutation_keeps_existing_declarations() {
	source := 'a { color: red; padding: 1px 2px; --x: var(--y, 3px); }'
	lazy := deferred_sheet_for_test(source)
	eager := parse_css_stylesheet_with_parser(source, 'https://example.test/css/initial.css')
	lazy_rule := lazy.css_rules().item(0) or { panic('missing lazy rule') }
	eager_rule := eager.css_rules().item(0) or { panic('missing eager rule') }
	assert lazy_rule.css_text() == eager_rule.css_text()
	mut declaration := lazy_rule.style() or { panic('missing style') }
	declaration.set_property('color', 'blue', 'important')!
	assert declaration.get_property_value('color') == 'blue'
	assert declaration.get_property_priority('color') == 'important'
	assert declaration.get_property_value('padding') == '1px 2px'
}

fn test_deferred_values_retain_last_nonempty_base_url_after_sheet_detachment() {
	sheet := deferred_sheet_for_test('a { background-image: url(icon.png); }')
	mut rule := sheet.css_rules().item(0) or { panic('missing rule') }
	other := parse_css_stylesheet_with_parser('', 'https://other.test/theme/replacement.css')
	rule.set_parent_style_sheet(other)
	rule.set_parent_style_sheet(none)
	declaration := rule.style() or { panic('missing style') }
	property := declaration.get_property(.background_image) or { panic('missing image') }
	assert property.value.base_url or { '' } == 'https://other.test/theme/replacement.css'
}

fn make_retained_deferred_sheet() &CSSStyleSheet {
	mut source := strings.new_builder(16_384)
	for i in 0 .. 128 {
		source.write_string('.item-${i} { --label: "value-${i}"; width: var(--size, calc(2px + 3%)); }')
	}
	return deferred_sheet_for_test(source.str())
}

fn test_deferred_token_graph_survives_parser_release_and_collection() {
	sheet := make_retained_deferred_sheet()
	$if gcboehm ? { C.GC_gcollect() }
	rule := sheet.css_rules().item(73) or { panic('missing retained rule') }
	declaration := rule.style() or { panic('missing retained declaration') }
	assert declaration.get_property_value('--label') == '"value-73"'
	assert declaration.get_property_value('width').contains('calc(2px + 3%)')
}

fn test_rule_matching_materializes_used_declarations_and_preserves_custom_property_cascade() {
	document := dom.Document.create(dom.url_about_blank())
	mut target := document.create_element('div')!
	target.set_attribute_value('class', 'target')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(target.as_node())!
	mut sheet := deferred_sheet_for_test('.unused { height: 17px; } .target { color: red; --size: 13px; width: var(--size); }')
	sheet.add_owning_document_or_shadow_root(document_node)
	holder := css_author_style_sheets_for(document)
	unsafe { holder.sheets << sheet }
	mut scope := css_style_scope_for_document(document)
	scope.invalidate_rule_cache()
	computer := StyleComputer.new(document)
	computed := computer.compute_style(dom.AbstractElement.new(target, none))
	assert (computed.property(.color, .no) or { panic('missing color') }).css_text == 'rgb(255, 0, 0)'
	assert (computed.property(.width, .no) or { panic('missing width') }).css_text == '13px'
	unused := sheet.css_rules().item(0) or { panic('missing unused rule') }
	raw := unused.declaration or { panic('missing unused declaration') }
	assert raw.deferred_declarations_ != none
}

fn test_dom_owned_large_stylesheets_defer_properties_but_small_and_public_parsers_stay_eager() {
	document := dom.Document.create(dom.url_about_blank())
	source := '.target { width: 17px; }'
	large_source := '/*${'padding '.repeat(2200)}*/${source}'
	small := parse_css_style_sheet_for_owner_node(document, source, 'https://example.test/small.css')
	large := parse_css_style_sheet_for_owner_node(document, large_source, 'https://example.test/large.css')
	eager := parse_css_stylesheet_with_parser(large_source, none)
	small_rule := small.css_rules().item(0) or { panic('missing small rule') }
	large_rule := large.css_rules().item(0) or { panic('missing large rule') }
	eager_rule := eager.css_rules().item(0) or { panic('missing eager rule') }
	assert (small_rule.declaration or { panic('missing small properties') }).deferred_declarations_ == none
	assert (large_rule.declaration or { panic('missing large properties') }).deferred_declarations_ != none
	assert (eager_rule.declaration or { panic('missing eager properties') }).deferred_declarations_ == none
	assert (large_rule.style() or { panic('missing materialized properties') }).get_property_value('width') == '17px'
}
