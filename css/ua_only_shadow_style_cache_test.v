module css

import dom

fn ua_cache_shadow(document &dom.Document, tag string) (&dom.Element, &dom.ShadowRoot, &dom.Element) {
	mut host := document.create_element_ns(dom.namespace_html_uri, 'div') or { panic(err) }
	if parent := document.document_element() {
		mut parent_node := parent.as_node()
		parent_node.append_child(host.as_node()) or { panic(err) }
	} else {
		mut doc_node := unsafe { &dom.Node(document) }
		doc_node.append_child(host.as_node()) or { panic(err) }
	}
	shadow := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut target := document.create_element_ns(dom.namespace_html_uri, tag) or { panic(err) }
	target.set_attribute_value('class', 'ua-cache-probe')
	mut shadow_node := unsafe { &dom.Node(shadow) }
	shadow_node.append_child(target.as_node()) or { panic(err) }
	return host, shadow, target
}

fn ua_cache_for(shadow &dom.ShadowRoot) &StyleCache {
	scope := css_style_scope_for_shadow_root(shadow)
	scope.build_rule_cache_if_needed()
	return scope.rule_cache or { panic('missing cache') }
}

fn ua_cache_fresh_color(document &dom.Document, target &dom.Element) string {
	computed := StyleComputer.new(document).compute_style(dom.AbstractElement.new(target, none))
	return (computed.property(.color, .no) or { panic('color') }).css_text
}

fn test_ua_only_empty_shadow_caches_share_same_document_inputs_and_keep_scope_state_separate() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	_, one, target_one := ua_cache_shadow(document, 'slot')
	_, two, target_two := ua_cache_shadow(document, 'slot')
	first := ua_cache_for(one)
	second := ua_cache_for(two)
	assert voidptr(first) == voidptr(second)
	mut scope_one := css_style_scope_for_shadow_root(one)
	scope_two := css_style_scope_for_shadow_root(two)
	assert voidptr(scope_one) != voidptr(scope_two)
	assert voidptr(scope_one.style_invalidation_data or { panic('data') }) == voidptr(scope_two.style_invalidation_data or { panic('data') })
	scope_one.needs_counter_style_cache_update = false
	assert scope_two.needs_counter_style_cache_update
	scope_one.pending_nodes_for_style_invalidation_due_to_presence_of_has << target_one.as_node()
	assert scope_two.pending_nodes_for_style_invalidation_due_to_presence_of_has.len == 0
	computer := StyleComputer.new(document)
	computed_one := computer.compute_style(dom.AbstractElement.new(target_one, none))
	computed_two := computer.compute_style(dom.AbstractElement.new(target_two, none))
	assert computed_one.display() == computed_two.display()
	assert computed_one.display().is_contents()
	mut attempted := PseudoClassBitmap{}
	rules_one := style_computer_collect_matching_rules_in_scope(computer, dom.AbstractElement.new(target_one, none), .user_agent, mut attempted, none, scope_one)
	rules_two := style_computer_collect_matching_rules_in_scope(computer, dom.AbstractElement.new(target_two, none), .user_agent, mut attempted, none, scope_two)
	assert rules_one.len > 0 && rules_two.len > 0
	assert rules_one.all(voidptr(it.shadow_root or { panic('root') }) == voidptr(one))
	assert rules_two.all(voidptr(it.shadow_root or { panic('root') }) == voidptr(two))
	gc_collect()
	assert voidptr(ua_cache_for(one)) == voidptr(first)
	assert voidptr(ua_cache_for(two)) == voidptr(first)
}

fn test_ua_only_shadow_cache_falls_back_for_authored_user_and_quirks_then_rejoins() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	_, one, target := ua_cache_shadow(document, 'span')
	_, two, _ := ua_cache_shadow(document, 'span')
	shared_cache := ua_cache_for(one)
	assert voidptr(ua_cache_for(two)) == voidptr(shared_cache)
	mut scope := css_style_scope_for_shadow_root(one)
	mut sheet := css_style_sheet_construct(none, document)!
	sheet.replace_sync('.ua-cache-probe {color:rgb(11 22 33)}')!
	mut list := create_adopted_style_sheets_list(unsafe { &dom.Node(one) })
	list.append(sheet)!
	assert voidptr(ua_cache_for(one)) != voidptr(shared_cache)
	assert ua_cache_fresh_color(document, target) == 'rgb(11, 22, 33)'
	sheet.set_disabled(true)
	assert voidptr(ua_cache_for(one)) == voidptr(ua_cache_for(two))
	sheet.set_disabled(false)
	assert ua_cache_fresh_color(document, target) == 'rgb(11, 22, 33)'
	list.clear()
	assert voidptr(ua_cache_for(one)) == voidptr(ua_cache_for(two))
	scope.user_style_source = '.ua-cache-probe {color:rgb(44 55 66)}'
	scope.invalidate_rule_cache()
	assert voidptr(ua_cache_for(one)) != voidptr(ua_cache_for(two))
	assert ua_cache_fresh_color(document, target) == 'rgb(44, 55, 66)'
	scope.user_style_source = none
	scope.invalidate_rule_cache()
	assert voidptr(ua_cache_for(one)) == voidptr(ua_cache_for(two))
	document.set_quirks_mode(.yes)
	scope.invalidate_rule_cache()
	assert scope.adopted_user_agent_only_shadow_cache_ == unsafe { nil }
	assert voidptr(ua_cache_for(one)) != voidptr(ua_cache_for(two))
}

fn test_ua_only_shadow_cache_is_document_owned_and_changes_after_adoption() {
	mut first_doc := dom.Document.create(dom.url_about_blank())
	mut second_doc := dom.Document.create(dom.url_about_blank())
	defer {
		first_doc.finalize()
		second_doc.finalize()
	}
	host, shadow, _ := ua_cache_shadow(first_doc, 'span')
	_, other, _ := ua_cache_shadow(second_doc, 'span')
	first := ua_cache_for(shadow)
	second := ua_cache_for(other)
	assert voidptr(first) != voidptr(second)
	second_doc.adopt_node(host.as_node())
	current := ua_cache_for(shadow)
	assert voidptr(current) == voidptr(ua_cache_for(other))
	assert voidptr(current) != voidptr(first)
}

fn test_ua_only_shadow_cache_tracks_environment_and_ua_rule_mutation_against_fresh_cache() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	_, one, target := ua_cache_shadow(document, 'span')
	_, two, _ := ua_cache_shadow(document, 'span')
	before := ua_cache_for(one)
	document.set_viewport_rect(dom.Rect{0, 0, 400, 600})
	resized := ua_cache_for(one)
	assert voidptr(resized) != voidptr(before)
	assert voidptr(ua_cache_for(two)) == voidptr(resized)
	document.bump_style_environment_version()
	changed := ua_cache_for(one)
	assert voidptr(changed) != voidptr(resized)
	assert voidptr(ua_cache_for(two)) == voidptr(changed)
	mut sheet := unsafe { &CSSStyleSheet(user_agent_default_stylesheet) }
	index := u32(sheet.rules.length())
	sheet.insert_rule('.ua-cache-probe {color:rgb(71 72 73)}', index)!
	defer { sheet.delete_rule(index) or { panic(err) } }
	mutated := ua_cache_for(one)
	assert voidptr(mutated) != voidptr(changed)
	assert voidptr(ua_cache_for(two)) == voidptr(mutated)
	actual := ua_cache_fresh_color(document, target)
	mut scope := css_style_scope_for_shadow_root(one)
	scope.populate_new_rule_cache()
	assert ua_cache_fresh_color(document, target) == actual
	assert actual == 'rgb(71, 72, 73)'
}

fn ua_cache_assert_fresh_properties(document &dom.Document, root &dom.ShadowRoot, target &dom.Element) {
	shared_cache := ua_cache_for(root)
	computer := StyleComputer.new(document)
	before := computer.compute_style(dom.AbstractElement.new(target, none))
	mut scope := css_style_scope_for_shadow_root(root)
	fresh := scope.populate_new_rule_cache()
	assert voidptr(fresh) != voidptr(shared_cache)
	after := computer.compute_style(dom.AbstractElement.new(target, none))
	for index in 1 .. int(PropertyID.container) + 1 {
		id := unsafe { PropertyID(index) }
		if !computed_interpolation_is_longhand_property(id) { continue }
		before_value := before.property(id, .no)
		after_value := after.property(id, .no)
		if first := before_value {
			last := after_value or { panic('missing fresh ${id}') }
			assert first.css_text == last.css_text, '${id}: ${first.css_text} vs ${last.css_text}'
		} else {
			assert after_value == none
		}
	}
}

fn test_ua_only_shadow_cache_default_svg_and_mathml_cascade_match_fresh_scope() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	_, html_root, html_target := ua_cache_shadow(document, 'input')
	_, svg_root, _ := ua_cache_shadow(document, 'span')
	_, math_root, _ := ua_cache_shadow(document, 'span')
	mut svg := document.create_element_ns('http://www.w3.org/2000/svg', 'svg')!
	mut svg_node := unsafe { &dom.Node(svg_root) }
	svg_node.append_child(svg.as_node())!
	mut math := document.create_element_ns('http://www.w3.org/1998/Math/MathML', 'math')!
	mut math_node := unsafe { &dom.Node(math_root) }
	math_node.append_child(math.as_node())!
	shared_cache := ua_cache_for(html_root)
	assert voidptr(ua_cache_for(svg_root)) == voidptr(shared_cache)
	assert voidptr(ua_cache_for(math_root)) == voidptr(shared_cache)
	ua_cache_assert_fresh_properties(document, html_root, html_target)
	ua_cache_assert_fresh_properties(document, svg_root, svg)
	ua_cache_assert_fresh_properties(document, math_root, math)
}

fn test_ua_only_shadow_cache_keeps_inherited_counter_scopes_separate() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	add_document_author_style_sheet(document, '@counter-style ua-marker {system:cyclic; symbols:"DOCUMENT";suffix:""}')
	_, outer, _ := ua_cache_shadow(document, 'span')
	add_shadow_root_author_style_sheet(outer, '@counter-style ua-marker {system:cyclic; symbols:"SHADOW";suffix:""}')
	inner_host, inner, _ := ua_cache_shadow(document, 'span')
	mut outer_node := unsafe { &dom.Node(outer) }
	outer_node.append_child(inner_host.as_node())!
	_, unrelated, _ := ua_cache_shadow(document, 'span')
	assert voidptr(ua_cache_for(inner)) == voidptr(ua_cache_for(unrelated))
	inner_styles := registered_counter_styles_for_scope(css_style_scope_for_shadow_root(inner))
	unrelated_styles := registered_counter_styles_for_scope(css_style_scope_for_shadow_root(unrelated))
	assert generate_a_counter_representation(inner_styles['ua-marker'], inner_styles, 1) == 'SHADOW'
	assert generate_a_counter_representation(unrelated_styles['ua-marker'], unrelated_styles, 1) == 'DOCUMENT'
}

fn test_ua_only_shadow_cache_tracks_nested_media_supports_and_layer_mutation() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	_, one, target := ua_cache_shadow(document, 'span')
	_, two, _ := ua_cache_shadow(document, 'span')
	mut sheet := unsafe { &CSSStyleSheet(user_agent_default_stylesheet) }
	index := u32(sheet.rules.length())
	sheet.insert_rule('@media (min-width: 700px) { @supports (display: block) { .ua-cache-probe { color: rgb(101 102 103) } @layer ua-test-layer { .ua-layer-target {color:blue} } } }', index)!
	defer { sheet.delete_rule(index) or { panic(err) } }
	sheet.evaluate_media_queries(document)
	wide := ua_cache_for(one)
	assert voidptr(ua_cache_for(two)) == voidptr(wide)
	assert ua_cache_fresh_color(document, target) == 'rgb(101, 102, 103)'
	mut media_rule := sheet.rules.item(index) or { panic('media') }
	media_children := media_rule.rules or { panic('children') }
	mut support_rule := media_children.item(0) or { panic('supports') }
	mut supports := support_rule.supports or { panic('condition') }
	// The resolved supports result is an input even without a CSSOM revision.
	supports.matches = false
	unsupported := ua_cache_for(one)
	assert voidptr(unsupported) != voidptr(wide)
	assert voidptr(ua_cache_for(two)) == voidptr(unsupported)
	assert ua_cache_fresh_color(document, target) != 'rgb(101, 102, 103)'
	supports.matches = true
	supported := ua_cache_for(one)
	assert voidptr(supported) != voidptr(unsupported)
	assert ua_cache_fresh_color(document, target) == 'rgb(101, 102, 103)'
	// Nested insertion propagates its parent sheet revision.
	support_rule.insert_rule('.ua-cache-probe { color:rgb(111 112 113) }', 1)!
	inserted := ua_cache_for(one)
	assert inserted.user_agent_rule_cache.by_layer.len > 0
	assert voidptr(inserted) != voidptr(supported)
	assert voidptr(ua_cache_for(two)) == voidptr(inserted)
	after_insertion := ua_cache_fresh_color(document, target)
	ua_cache_assert_fresh_properties(document, one, target)
	document.set_viewport_rect(dom.Rect{0, 0, 400, 600})
	sheet.evaluate_media_queries(document)
	narrow := ua_cache_for(one)
	assert voidptr(narrow) != voidptr(inserted)
	assert ua_cache_fresh_color(document, target) != after_insertion
	mut media := media_rule.media or { panic('media list') }
	media.set_media_text('(min-width: 300px)')
	sheet.evaluate_media_queries(document)
	changed_media := ua_cache_for(one)
	assert voidptr(changed_media) != voidptr(narrow)
	assert voidptr(ua_cache_for(two)) == voidptr(changed_media)
	assert ua_cache_fresh_color(document, target) == after_insertion
	ua_cache_assert_fresh_properties(document, one, target)
}

fn test_ua_only_shadow_cache_tracks_import_loading_replacement_and_nested_revision() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	_, one, target := ua_cache_shadow(document, 'span')
	_, two, _ := ua_cache_shadow(document, 'span')
	mut sheet := unsafe { &CSSStyleSheet(user_agent_default_stylesheet) }
	sheet.insert_rule('@import url(ua-cache-probe.css);', 0)!
	defer { sheet.delete_rule(0) or { panic(err) } }
	mut import_rule := sheet.rules.item(0) or { panic('import') }
	unloaded := ua_cache_for(one)
	mut imported := parse_css_stylesheet_with_parser('.ua-cache-probe {color:rgb(121 122 123)}', none)
	import_rule.set_style_sheet(imported)
	loaded := ua_cache_for(one)
	assert voidptr(loaded) != voidptr(unloaded)
	assert voidptr(ua_cache_for(two)) == voidptr(loaded)
	assert ua_cache_fresh_color(document, target) == 'rgb(121, 122, 123)'
	imported.insert_rule('.ua-cache-probe {color:rgb(131 132 133)}', 1)!
	nested_mutated := ua_cache_for(one)
	assert voidptr(nested_mutated) != voidptr(loaded)
	assert ua_cache_fresh_color(document, target) == 'rgb(131, 132, 133)'
	replacement := parse_css_stylesheet_with_parser('.ua-cache-probe {color:rgb(141 142 143)}', none)
	import_rule.set_style_sheet(replacement)
	replaced := ua_cache_for(one)
	assert voidptr(replaced) != voidptr(nested_mutated)
	assert voidptr(ua_cache_for(two)) == voidptr(replaced)
	assert ua_cache_fresh_color(document, target) == 'rgb(141, 142, 143)'
	ua_cache_assert_fresh_properties(document, one, target)
}

fn test_ua_only_shadow_caches_are_shared_under_the_chromium_rendering_policy() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_, one, target := ua_cache_shadow(document, 'input')
	_, two, _ := ua_cache_shadow(document, 'input')
	scope := css_style_scope_for_shadow_root(one)
	sheets := scope.stylesheets_for_cascade_origin(.user_agent)
	assert sheets.len == 4
	assert voidptr(sheets[3]) == voidptr(chromium_control_font_style_sheet())
	shared_cache := ua_cache_for(one)
	assert voidptr(ua_cache_for(two)) == voidptr(shared_cache)
	computed := StyleComputer.new(document).compute_style(dom.AbstractElement.new(target, none))
	assert (computed.property(.font_family, .no) or { panic('font-family') }).css_text == 'Arial'
}
