module css

import dom
import platform

fn template_test_shadow(document &dom.Document) (&dom.ShadowRoot, &dom.Element) {
	mut host := document.create_element_ns(dom.namespace_html_uri, 'div') or { panic(err) }
	mut document_node := document.as_node()
	document_node.append_child(host.as_node()) or { panic(err) }
	shadow := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut target := document.create_element_ns(dom.namespace_html_uri, 'span') or { panic(err) }
	target.set_attribute_value('class', 'ua-template-probe')
	mut root := unsafe { &dom.Node(shadow) }
	root.append_child(target.as_node()) or { panic(err) }
	return shadow, target
}

fn template_test_cache(shadow &dom.ShadowRoot) &StyleCache {
	mut scope := css_style_scope_for_shadow_root(shadow)
	scope.build_rule_cache_if_needed()
	return scope.rule_cache or { panic('missing UA cache') }
}

fn template_test_retire(mut document dom.Document) {
	owner := document.native_storage()
	document.finalize()
	document.release_native_storage()
	$if prealloc {
		for _ in 0 .. 100 {
			if owner.arena.usage().capacity == 0 { break }
			platform.pump_native_events(0.01)
		}
		assert owner.arena.usage().capacity == 0
	}
}

fn test_ua_templates_share_only_immutable_indexes_and_survive_first_document_retirement() {
	mut first := dom.Document.create(dom.url_about_blank())
	mut second := dom.Document.create(dom.url_about_blank())
	first.set_font_rendering_policy(.chromium)
	second.set_font_rendering_policy(.chromium)
	first.enable_native_storage()
	second.enable_native_storage()
	mut first_work := first.enter_native_storage()
	first_shadow, _ := template_test_shadow(first)
	first_cache := template_test_cache(first_shadow)
	indexes := first_cache.user_agent_rule_cache
	first_work.finish()
	mut second_work := second.enter_native_storage()
	second_shadow, target := template_test_shadow(second)
	second_cache := template_test_cache(second_shadow)
	assert voidptr(first_cache) != voidptr(second_cache)
	assert voidptr(second_cache.user_agent_rule_cache) == voidptr(indexes)
	mut first_scope := css_style_scope_for_shadow_root(first_shadow)
	second_scope := css_style_scope_for_shadow_root(second_shadow)
	first_scope.needs_counter_style_cache_update = false
	assert second_scope.needs_counter_style_cache_update
	second_work.finish()
	template_test_retire(mut first)
	mut later := second.enter_native_storage()
	computed := StyleComputer.new(second).compute_style(dom.AbstractElement.new(target, none))
	assert (computed.property(.display, .no) or { panic('missing display') }).css_text == 'inline'
	assert voidptr(template_test_cache(second_shadow).user_agent_rule_cache) == voidptr(indexes)
	later.finish()
	template_test_retire(mut second)
}

fn test_ua_only_svg_document_roots_reuse_indexes_with_independent_wrappers_and_computed_style() {
	mut first := dom.Document.create(dom.url_about_blank())
	mut second := dom.Document.create(dom.url_about_blank())
	defer {
		first.finalize()
		second.finalize()
	}
	mut roots := []&dom.Element{}
	mut caches := []&StyleCache{}
	for document in [first, second] {
		mut element := document.create_element_ns(dom.namespace_svg_uri, 'svg')!
		mut node := document.as_node()
		node.append_child(element.as_node())!
		mut scope := css_style_scope_for_document(document)
		scope.build_rule_cache_if_needed()
		roots << element
		caches << scope.rule_cache or { panic('missing SVG UA cache') }
	}
	assert voidptr(caches[0]) != voidptr(caches[1])
	assert voidptr(caches[0].user_agent_rule_cache) == voidptr(caches[1].user_agent_rule_cache)
	for index, document in [first, second] {
		computer := StyleComputer.new(document)
		before := computer.compute_style(dom.AbstractElement.new(roots[index], none))
		mut scope := css_style_scope_for_document(document)
		scope.populate_new_rule_cache()
		after := computer.compute_style(dom.AbstractElement.new(roots[index], none))
		for property_index in 1 .. int(PropertyID.container) + 1 {
			id := unsafe { PropertyID(property_index) }
			if !computed_interpolation_is_longhand_property(id) { continue }
			if value := before.property(id, .no) {
				fresh := after.property(id, .no) or { panic('missing fresh ${id}') }
				assert value.css_text == fresh.css_text, '${id}: ${value.css_text} vs ${fresh.css_text}'
			} else {
				assert after.property(id, .no) == none
			}
		}
	}
}

fn test_ua_template_limit_keeps_later_stylesheet_mutations_fresh() {
	mut sheet := unsafe { &CSSStyleSheet(user_agent_default_stylesheet) }
	for index in 0 .. user_agent_style_cache_template_limit + 3 {
		position := u32(sheet.rules.length())
		sheet.insert_rule('.ua-template-probe {color:rgb(${index + 10} 22 33)}', position)!
		mut document := dom.Document.create(dom.url_about_blank())
		document.enable_native_storage()
		mut work := document.enter_native_storage()
		shadow, target := template_test_shadow(document)
		_ = template_test_cache(shadow)
		style := StyleComputer.new(document).compute_style(dom.AbstractElement.new(target, none))
		assert (style.property(.color, .no) or { panic('missing color') }).css_text == 'rgb(${index + 10}, 22, 33)'
		assert user_agent_style_cache_templates_.len <= user_agent_style_cache_template_limit
		work.finish()
		template_test_retire(mut document)
		sheet.delete_rule(position)!
	}
}

fn test_document_dynamic_sheet_exits_shared_ua_template_on_first_rule() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut target := document.create_element_ns(dom.namespace_svg_uri, 'svg')!
	mut node := document.as_node()
	node.append_child(target.as_node())!
	mut scope := css_style_scope_for_document(document)
	scope.build_rule_cache_if_needed()
	assert scope.adopted_user_agent_only_shadow_cache_ != unsafe { nil }
	before := scope.rule_cache or { panic('missing UA template') }
	mut sheet := dynamic_view_transition_style_sheet_for_document(document)
	sheet.insert_rule('svg { color: rgb(17 28 39) }', 0)!
	scope.build_rule_cache_if_needed()
	after := scope.rule_cache or { panic('missing authored cache') }
	assert voidptr(before) != voidptr(after)
	assert scope.adopted_user_agent_only_shadow_cache_ == unsafe { nil }
	style := StyleComputer.new(document).compute_style(dom.AbstractElement.new(target, none))
	assert (style.property(.color, .no) or { panic('missing color') }).css_text == 'rgb(17, 28, 39)'
}
