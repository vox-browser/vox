module css

import dom

fn cascade_reuse_child(mut document dom.Document, mut parent dom.Element, tag string, attributes map[string]string) &dom.Element {
	mut element := document.create_element(tag) or { panic(err) }
	for name, value in attributes { element.set_attribute_value(name, value) }
	mut parent_node := parent.as_node()
	parent_node.append_child(element.as_node()) or { panic(err) }
	return element
}

// The complete cascaded structure: every chain in active order and the
// presence bits, with value, source and layer identities.
fn cascade_reuse_dump(cascaded &CascadedProperties, by_text bool) []string {
	mut out := []string{}
	for id in cascaded.entry_heads_.active {
		mut index := cascaded.entry_heads_.get(id)
		mut chain := []string{}
		for index >= 0 {
			node := cascaded.entry_node(index)
			entry := node.entry
			root := if r := entry.source_shadow_root { u64(voidptr(r)) } else { u64(0) }
			value := if by_text { entry.property.value.css_text } else { '${u64(voidptr(entry.property.value))}' }
			chain << '${value}:${entry.property.important}:${entry.origin}:${entry.layer_name or { '-' }}:${u64(entry.source)}:${root}'
			index = node.previous
		}
		out << '${id}=${chain.join(' ')}'
	}
	for index, bit in cascaded.contained_properties_cache_ {
		if bit != 0 { out << 'present ${index}' }
	}
	return out
}

fn cascade_reuse_cascade(computer &StyleComputer, element &dom.Element, scope &StyleScope, reuse bool, by_text bool) []string {
	abstract := dom.AbstractElement.new(element, none)
	mut attempted := PseudoClassBitmap{}
	mut matched_pseudo := false
	set := style_computer_build_matching_rule_set_impl(computer, abstract, mut attempted, &matched_pseudo, .normal, scope)
	mut lease := computer.acquire_cascade_scratch()
	defer { lease.finish() }
	mut cascaded := lease.properties
	if reuse {
		computer.compute_cascaded_values_reusing(mut cascaded, abstract, false, .normal, set, LogicalAliasMappingContext{})
	} else {
		computer.compute_cascaded_values_into(mut cascaded, abstract, false, .normal, set, LogicalAliasMappingContext{}, []PropertyID{})
	}
	return cascade_reuse_dump(cascaded, by_text)
}

// Within a style batch a second element with the same rules, hints and
// custom property environment replays exactly the structure an ordinary
// cascade builds, and records its var() use. Inline styles cascade anew.
fn test_cascade_reuse_replays_the_ordinary_cascade_structure() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.html)
	mut html := document.create_element('html') or { panic(err) }
	mut document_node := document.as_node()
	document_node.append_child(html.as_node()) or { panic(err) }
	mut head := cascade_reuse_child(mut document, mut html, 'head', {})
	mut body := cascade_reuse_child(mut document, mut html, 'body', {'style': '--tone: green'})
	mut style := cascade_reuse_child(mut document, mut head, 'style', {})
	mut style_node := style.as_node()
	style_node.append_child(document.create_text_node('.a { color: var(--tone, red) !important; margin: 1px 2px }
		@layer base { .a { padding: 3px; color: blue; margin-top: revert-layer } }
		.a { border-top: 1px solid var(--tone) } .a.b { margin-left: 4px }').as_node()) or { panic(err) }
	first := cascade_reuse_child(mut document, mut body, 'div', {'class': 'a'})
	second := cascade_reuse_child(mut document, mut body, 'div', {'class': 'a'})
	other := cascade_reuse_child(mut document, mut body, 'div', {'class': 'a b'})
	inline := cascade_reuse_child(mut document, mut body, 'div', {'class': 'a', 'style': 'padding: 9px'})
	document.update_style()
	computer := css_style_computer_for(document)
	scope := css_style_scope_for_document(document)
	mut fresh := map[string][]string{}
	for name, element in {'first': first, 'second': second, 'other': other, 'inline': inline} {
		fresh[name] = cascade_reuse_cascade(computer, element, scope, false, true)
	}
	computer.begin_computed_property_page_batch()
	first_identities := cascade_reuse_cascade(computer, first, scope, true, false)
	mut second_element := unsafe { &dom.Element(second) }
	second_element.reset_style_dependency_flags()
	second_identities := cascade_reuse_cascade(computer, second, scope, true, false)
	reused_first := cascade_reuse_cascade(computer, first, scope, true, true)
	reused_second := cascade_reuse_cascade(computer, second, scope, true, true)
	reused_other := cascade_reuse_cascade(computer, other, scope, true, true)
	reused_inline := cascade_reuse_cascade(computer, inline, scope, true, true)
	cache := computer.cascade_reuse_
	assert cache != unsafe { nil }
	// first and other are stored; second replays first's entry; inline bypasses.
	assert cache.entries.len == 2
	computer.end_computed_property_page_batch()
	// The replay is the first element's cascade, value for value.
	assert second_identities == first_identities
	assert reused_first == fresh['first']
	assert reused_second == fresh['second']
	assert reused_other == fresh['other']
	assert reused_inline == fresh['inline']
	assert reused_second.len > 6
	assert second.style_uses_var_css_function()
}

// Substitutions reading more than the custom property environment stop the
// cascade being recorded.
fn test_cascade_reuse_records_only_environment_substitutions() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := document.create_element('div') or { panic(err) }
	computer := css_style_computer_for(document)
	computer.begin_computed_property_page_batch()
	defer { computer.end_computed_property_page_batch() }
	mut owner := unsafe { &StyleComputer(computer) }
	owner.cascade_reuse_ = &CascadeReuseCache{recording: true}
	abstract := dom.AbstractElement.new(element, none)
	note_cascade_substitution(abstract, UnresolvedStyleValue{substitution_functions_presence: SubstitutionFunctionsPresence{var: true}})
	assert !owner.cascade_reuse_.blocked && owner.cascade_reuse_.uses_var
	note_cascade_substitution(abstract, UnresolvedStyleValue{substitution_functions_presence: SubstitutionFunctionsPresence{attr: true}})
	assert owner.cascade_reuse_.blocked
}
