module css

import dom

$if gcboehm ? {
	fn C.GC_get_total_bytes() uint
}

fn test_pseudo_class_cache_list_preserves_order_independence_and_no_allocation() {
	expected := [PseudoClass.hover, .active, .focus, .focus_within, .focus_visible, .has, .target]!
	assert style_scope_pseudo_classes_with_rule_cache() == expected
	mut edited := style_scope_pseudo_classes_with_rule_cache()
	edited[0] = .root
	assert edited[0] == .root
	assert style_scope_pseudo_classes_with_rule_cache() == expected
	mut before := uint(0)
	$if gcboehm ? { before = C.GC_get_total_bytes() }
	mut visits := 0
	for _ in 0 .. 1024 {
		for pseudo_class in style_scope_pseudo_classes_with_rule_cache() {
			if pseudo_class == .hover || pseudo_class == .target { visits++ }
		}
	}
	mut allocated := uint(0)
	$if gcboehm ? { allocated = C.GC_get_total_bytes() - before }
	assert visits == 2048
	assert allocated == 0
}

fn test_rule_cache_populates_every_supported_dynamic_pseudo_class() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	add_document_author_style_sheet(document,
		'.probe:hover{color:red}.probe:active{color:red}.probe:focus{color:red}.probe:focus-within{color:red}.probe:focus-visible{color:red}.probe:has(.child){color:red}.probe:target{color:red}')
	scope := css_style_scope_for_document(document)
	for pseudo_class in style_scope_pseudo_classes_with_rule_cache() {
		cache := scope.get_pseudo_class_rule_cache(pseudo_class) or { panic('missing cache') }
		assert 'probe' in cache.rules_by_class
		rules := cache.rules_by_class['probe'] or { panic('missing rules') }
		assert rules.len == 1
		assert rules[0].selector.contains_pseudo_class(pseudo_class)
		assert rules[0].cascade_origin == .author
	}
	gc_collect()
	assert scope.pseudo_class_rule_cache.len == 7
	for pseudo_class in style_scope_pseudo_classes_with_rule_cache() {
		cache := scope.get_pseudo_class_rule_cache(pseudo_class) or { panic('lost cache') }
		assert (cache.rules_by_class['probe'] or { panic('lost rules') })[0].selector.contains_pseudo_class(pseudo_class)
	}
}
