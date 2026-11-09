module css

import dom
import platform

fn rule_cache_test_source(rules string) string {
	return '/*' + 'padding'.repeat(2400) + '*/' + rules
}

fn rule_cache_test_store(mut cache StylesheetRuleCache, source string) {
	mut parser := RuleSelectorParser.create(ParsingParams{}, source, 'utf-8')
	cache.store(source, parser.parse_a_stylesheet(none).rules)
}

fn test_rule_cache_matches_complete_source_bytes_and_evicts_with_bounded_storage() {
	mut cache := &StylesheetRuleCache{ max_entries: 2, max_source_bytes: 36_000, max_nodes: 96 }
	red := rule_cache_test_source('a{color:red}')
	tan := rule_cache_test_source('a{color:tan}')
	assert cache.eligible(red)
	rule_cache_test_store(mut cache, red)
	first := cache.lookup(red) or { panic('missing cache candidate') }
	defer { first.release() }
	again := cache.lookup(red) or { panic('missing cached rules') }
	assert again.rules.data == first.rules.data
	again.release()
	rule_cache_test_store(mut cache, tan)
	changed := cache.lookup(tan) or { panic('missing changed rules') }
	assert changed.rules.data != first.rules.data
	mut changed_parser := RuleSelectorParser{ raw_rules_transient: true, component_input_transient: true }
	changed_rules := changed_parser.convert_rules(changed.rules)
	assert changed_rules[0].style()?.get_property_value('color') == 'tan'
	changed.release()
	// Refresh red before a third source forces eviction of tan.
	refreshed := cache.lookup(red) or { panic('missing cached red') }
	refreshed.release()
	rule_cache_test_store(mut cache, rule_cache_test_source('b{color:blue}'))
	assert cache.entries.len == 2
	assert cache.entries.all(it.input != tan)
	retained_hit := cache.lookup(red) or { panic('red was unexpectedly evicted') }
	assert retained_hit.rules.data == first.rules.data
	retained_hit.release()
	rule_cache_test_store(mut cache, rule_cache_test_source('x{color:red}'.repeat(100)))
	assert cache.entries.all(it.input != rule_cache_test_source('x{color:red}'.repeat(100)))
	assert cache.entries.len <= cache.max_entries
	assert cache.source_bytes <= cache.max_source_bytes
	assert cache.nodes <= cache.max_nodes
	rule_cache_test_store(mut cache, '/*' + 'oversized'.repeat(5000) + '*/z{}')
	assert cache.source_bytes <= cache.max_source_bytes
	assert !cache.eligible('a{color:red}')
	assert cache.lookup('a{color:red}') == none
	// Dropping the cache's root must not retire a tree still borrowed by a parser.
	cache.release_unused()
	assert cache.entries.len == 0 && cache.source_bytes == 0 && cache.nodes == 0
	gc_collect()
	mut retained_parser := RuleSelectorParser{ raw_rules_transient: true, component_input_transient: true }
	retained := retained_parser.convert_rules(first.rules)
	assert retained[0].style()?.get_property_value('color') == 'red'
}

fn rule_cache_test_worker(mut cache StylesheetRuleCache, source string) bool {
	for _ in 0 .. 4 {
		rule_cache_test_store(mut cache, source)
		entry := cache.lookup(source) or { return false }
		mut parser := RuleSelectorParser{ raw_rules_transient: true, component_input_transient: true }
		rules := parser.convert_rules(entry.rules)
		entry.release()
		if rules.len != 1 { return false }
		style := rules[0].style() or { return false }
		if style.get_property_value('color') != 'red'
			|| style.get_property_value('--label') != '"β😀"' {
			return false
		}
	}
	return true
}

fn test_concurrent_rule_cache_publication_keeps_one_immutable_template() {
	$if prealloc {
		return
	}
	mut cache := &StylesheetRuleCache{}
	source := rule_cache_test_source('.probe{color:red;--label:"β😀"}')
	mut workers := []thread bool{}
	for _ in 0 .. 4 { workers << spawn rule_cache_test_worker(mut cache, source) }
	for worker in workers {
		assert worker.wait()
	}
	assert cache.entries.len == 1
	assert cache.entries[0].input == source
	cache.release_unused()
}

fn test_cached_rule_syntax_keeps_cssom_document_and_base_url_owners_independent() {
	mut first_document := dom.Document.create(dom.URL{ value: 'https://rule-cache-one.test/base/' })
	mut second_document := dom.Document.create(dom.URL{ value: 'https://rule-cache-two.test/base/' })
	defer {
		first_document.finalize()
		second_document.finalize()
	}
	source := rule_cache_test_source('@namespace s url("http://www.w3.org/2000/svg"); .probe{color:red!important;--size:calc(1px + var(--base));background:url(../image.png)}')
	mut first := parse_css_stylesheet_in_workspace(ParsingParams{ document: first_document },
		source, 'https://rule-cache-one.test/a.css', none, true)
	second := parse_css_stylesheet_in_workspace(ParsingParams{ document: second_document },
		source, 'https://rule-cache-two.test/b.css', none, true)
	assert first.rules.length() == 2 && second.rules.length() == 2
	assert voidptr(first.rules.rules[1]) != voidptr(second.rules.rules[1])
	assert voidptr(first.rules.rules[1].parent_style_sheet?) == voidptr(first)
	assert voidptr(second.rules.rules[1].parent_style_sheet?) == voidptr(second)
	assert voidptr(first.rules.rules[1].declaration?.deferred_declarations_?.params.document) == voidptr(first_document)
	assert voidptr(second.rules.rules[1].declaration?.deferred_declarations_?.params.document) == voidptr(second_document)
	mut declaration := first.rules.rules[1].style()?
	declaration.set_property('color', 'blue', '')!
	assert second.rules.rules[1].style()?.get_property_value('color') == 'red'
	assert second.rules.rules[1].style()?.get_property_priority('color') == 'important'
	assert declaration.get_property(.background_image)?.value.base_url? == 'https://rule-cache-one.test/a.css'
	assert second.rules.rules[1].style()?.get_property(.background_image)?.value.base_url? == 'https://rule-cache-two.test/b.css'
	first.delete_rule(1)!
	third := parse_css_stylesheet_in_workspace(ParsingParams{ document: first_document },
		source, 'https://rule-cache-one.test/c.css', none, true)
	assert third.rules.length() == 2
	assert third.rules.rules[1].style()?.get_property_value('color') == 'red'
	release_unused_stylesheet_syntax()
	gc_collect()
	assert second.rules.length() == 2
	assert second.rules.rules[1].style()?.get_property_value('--size').contains('var(--base)')
}

fn test_warm_sheet_owns_position_try_and_deferred_payloads_after_cache_retirement() {
	release_unused_stylesheet_syntax()
	source := rule_cache_test_source(r'@position-try --\{ {left:3px;top:anchor(bottom)} .probe{background:url("../image.png");--label:"β😀";width:var(--size,calc(2px + 3%))} @property --size{syntax:"<length>";inherits:true;initial-value:2px} @keyframes change{from{transform:translateX(1px)}to{transform:translateX(2px)}}')
	location := 'https://rule-cache.test/assets/style.css'
	mut expected_parser := RuleSelectorParser.create(ParsingParams{}, source, 'utf-8')
	expected := expected_parser.parse_as_css_stylesheet(location, none)
	mut producer := platform.new_retained_arena('rule cache source owner')
	mut source_scope := producer.enter()
	cold := parse_css_stylesheet_in_workspace(ParsingParams{}, source.clone(), location, none, true)
	assert cold.rules.length() == 4
	source_scope.finish()
	producer.release()
	// The cache owns the original syntax independently of the caller's arena.
	entry := stylesheet_rule_cache_.lookup(source) or { panic('source owner lost the cached syntax') }
	mut cache_storage := unsafe { &platform.RetainedArena(nil) }
	$if prealloc {
		cache_storage = entry.storage
		assert cache_storage.arena.usage().used > 0
	}
	entry.release()
	mut consumer := platform.new_retained_arena('rule cache sheet owner')
	defer { consumer.release() }
	mut sheet_scope := consumer.enter()
	sheet := parse_css_stylesheet_in_workspace(ParsingParams{}, source, location, none, true)
	assert sheet.rules.rules[1].declaration?.deferred_declarations_ != none
	$if prealloc {
		assert consumer.arena.contains(voidptr(sheet))
	}
	sheet_scope.finish()
	release_unused_stylesheet_syntax()
	$if prealloc {
		// A forgotten conversion lease would hide an escaped template pointer.
		assert cache_storage.arena.usage().used == 0
	}
	gc_collect()
	assert sheet.rules.rules[0].position_try_name() == r'--\{'
	assert sheet.rules.rules[0].style()?.get_property_value('left') == '3px'
	assert sheet.rules.rules[1].style()?.get_property_value('--label') == '"β😀"'
	assert sheet.rules.rules[1].style()?.get_property(.background_image)?.value.base_url? == location
	assert sheet.rules.length() == expected.rules.length()
	for index, rule in sheet.rules.rules {
		assert rule.css_text() == expected.rules.rules[index].css_text()
	}
}

fn test_changed_css_at_the_same_url_rebuilds_rule_syntax() {
	location := 'https://rule-cache.test/assets/style.css'
	red := rule_cache_test_source('.probe{color:red}')
	tan := rule_cache_test_source('.probe{color:tan}')
	assert red.len == tan.len
	for source in [red, red, tan, tan, red] {
		sheet := parse_css_stylesheet_in_workspace(ParsingParams{}, source, location, none, true)
		expected := if source == red { 'red' } else { 'tan' }
		assert sheet.rules.rules[0].style()?.get_property_value('color') == expected
	}
}

fn test_cached_syntax_reconverts_namespaces_and_respects_nondefault_rule_context() {
	source := rule_cache_test_source('s|svg{color:red}')
	without_namespace := parse_css_stylesheet_in_workspace(ParsingParams{}, source, none, none, false)
	assert without_namespace.rules.length() == 0
	with_namespace := parse_css_stylesheet_in_workspace(ParsingParams{
		declared_namespaces: {
			's': true
		}
	}, source, none, none, false)
	assert with_namespace.rules.length() == 1
	without_again := parse_css_stylesheet_in_workspace(ParsingParams{}, source, none, none, false)
	assert without_again.rules.length() == 0
	ordinary_source := rule_cache_test_source('.probe{color:red}')
	normal := parse_css_stylesheet_in_workspace(ParsingParams{}, ordinary_source, none, none, false)
	assert normal.rules.length() == 1
	params := ParsingParams{ rule_context: [.font_face] }
	mut uncached_parser := RuleSelectorParser.create(params, ordinary_source, 'utf-8')
	expected := uncached_parser.parse_as_css_stylesheet(none, none)
	contextual := parse_css_stylesheet_in_workspace(params, ordinary_source, none, none, false)
	assert expected.rules.length() == 0
	assert contextual.rules.length() == expected.rules.length()
	assert parse_css_stylesheet_in_workspace(ParsingParams{}, ordinary_source, none, none, false).rules.length() == 1
}

fn test_warm_rule_syntax_preserves_nested_rules_descriptors_and_token_boundaries() {
	sources := [
		'@media (width > 1px){@supports (display:grid){a:hover{color:red!important}}} @scope (.root) to (.end){.child{height:3px}}',
		'@layer first, second; @layer first{.parent{color:red;& .child{color:blue}@media (width > 1px){padding:2px}}}',
		'@font-face{font-family:"Probe Font";src:url("probe.woff2");font-weight:400} @property --size{syntax:"<length>";inherits:true;initial-value:2px}',
		'@counter-style probe{system:cyclic;symbols:"a" "中";suffix:". "} @keyframes probe{from{transform:translateX(1px)}100%{transform:translateX(2px)}}',
		'@function --double(--x <length>:calc(2px + 3px)) returns <length>{@media (width > 1px){result:var(--x)}} @page :first{margin:1cm;@top-left{content:"page"}}',
		'@position-try --fallback{left:3px;top:anchor(bottom)}',
		'.probe{width:1/**/px;height:2px!important;--word:"hello\\20 world";--empty:;padding:var(--size,calc(2px + 3%))}',
	]
	for rules in sources {
		source := rule_cache_test_source(rules)
		mut uncached_parser := RuleSelectorParser.create(ParsingParams{}, source, 'utf-8')
		expected := uncached_parser.parse_as_css_stylesheet('https://rule-cache.test/style.css', none)
		assert expected.rules.length() > 0
		for deferred in [false, true] {
			parse_css_stylesheet_in_workspace(ParsingParams{}, source,
				'https://rule-cache.test/style.css', none, deferred)
			actual := parse_css_stylesheet_in_workspace(ParsingParams{}, source,
				'https://rule-cache.test/style.css', none, deferred)
			release_unused_stylesheet_syntax()
			assert actual.rules.length() == expected.rules.length()
			for index, rule in actual.rules.rules {
				assert rule.css_text() == expected.rules.rules[index].css_text()
			}
		}
	}
}

fn test_initially_unused_cached_rule_remains_available_after_a_class_change() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut target := document.create_element('div')!
	target.set_attribute_value('class', 'before')
	mut document_node := document.as_node()
	document_node.append_child(target.as_node())!
	source := rule_cache_test_source('.before{color:red}.later{color:blue;--size:23px;width:var(--size)}')
	parse_css_stylesheet_in_workspace(ParsingParams{}, source, none, none, true)
	mut sheet := parse_css_stylesheet_in_workspace(ParsingParams{ document: document }, source,
		'https://rule-cache.test/dynamic.css', none, true)
	sheet.add_owning_document_or_shadow_root(document_node)
	holder := css_author_style_sheets_for(document)
	unsafe { holder.sheets << sheet }
	mut scope := css_style_scope_for_document(document)
	scope.invalidate_rule_cache()
	computer := StyleComputer.new(document)
	before := computer.compute_style(dom.AbstractElement.new(target, none))
	assert before.property(.color, .no)?.css_text == 'rgb(255, 0, 0)'
	assert sheet.css_rules().length() == 2
	assert sheet.rules.rules[1].declaration?.deferred_declarations_ != none
	target.set_attribute_value('class', 'later')
	after := computer.compute_style(dom.AbstractElement.new(target, none))
	assert after.property(.color, .no)?.css_text == 'rgb(0, 0, 255)'
	assert after.property(.width, .no)?.css_text == '23px'
	assert sheet.rules.rules[1].declaration?.deferred_declarations_ == none
}

fn test_cached_media_rules_follow_each_documents_viewport_and_later_resizes() {
	mut narrow := dom.Document.create(dom.url_about_blank())
	mut wide := dom.Document.create(dom.url_about_blank())
	defer {
		narrow.finalize()
		wide.finalize()
	}
	narrow.set_viewport_rect(dom.Rect{0, 0, 300, 600})
	wide.set_viewport_rect(dom.Rect{0, 0, 900, 600})
	source := rule_cache_test_source('@media (min-width:600px){.probe{color:red}}')
	mut first := parse_css_stylesheet_in_workspace(ParsingParams{ document: narrow }, source, none, none, true)
	mut second := parse_css_stylesheet_in_workspace(ParsingParams{ document: wide }, source, none, none, true)
	first.evaluate_media_queries(narrow)
	second.evaluate_media_queries(wide)
	assert !first.rules.rules[0].media?.matches()
	assert second.rules.rules[0].media?.matches()
	narrow.set_viewport_rect(dom.Rect{0, 0, 900, 600})
	first.evaluate_media_queries(narrow)
	assert first.rules.rules[0].media?.matches()
	assert first.rules.rules[0].css_rules()?.length() == 1
}
