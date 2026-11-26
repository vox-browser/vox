module css

import dom

fn combined_matching_element(mut document dom.Document, mut parent dom.Element, tag string, id string, classes string) &dom.Element {
	mut element := document.create_element(tag) or { panic(err) }
	if id != '' { element.set_attribute_value('id', id) }
	if classes != '' { element.set_attribute_value('class', classes) }
	mut parent_node := parent.as_node()
	parent_node.append_child(element.as_node()) or { panic(err) }
	return element
}

fn combined_matching_layers(element &dom.Element, pseudo ?dom.PseudoElement, combined bool) []string {
	combined_author_matching_disabled_for_test = !combined
	defer { combined_author_matching_disabled_for_test = false }
	document := element.document()
	computer := css_style_computer_for(document)
	scope := css_style_scope_for_document(document)
	abstract := dom.AbstractElement.new(element, pseudo)
	mut attempted := PseudoClassBitmap{}
	mut matched_pseudo := false
	mode := if pseudo == none { ComputeStyleMode.normal } else { ComputeStyleMode.create_pseudo_element_style_if_needed }
	set := style_computer_build_matching_rule_set_impl(computer, abstract, mut attempted, &matched_pseudo, mode, scope)
	mut layers := []string{}
	for layer in set.author_rules {
		mut rules := []string{}
		for scoped in layer.rules {
			owner := scoped.rule.rule or { panic('rule') }
			rules << '${u64(voidptr(owner))}:${scoped.rule.specificity}'
		}
		layers << '${layer.qualified_layer_name}=[${rules.join(' ')}]'
	}
	layers << 'pseudo=${matched_pseudo}'
	return layers
}

// One collection over every author rule, split by layer cache, gives the
// per-layer lists that separate collections give.
fn test_combined_author_matching_splits_layers_like_separate_collections() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.html)
	mut html := document.create_element('html') or { panic(err) }
	mut document_node := document.as_node()
	document_node.append_child(html.as_node()) or { panic(err) }
	mut head := combined_matching_element(mut document, mut html, 'head', '', '')
	mut body := combined_matching_element(mut document, mut html, 'body', '', '')
	mut style := document.create_element('style') or { panic(err) }
	mut style_node := style.as_node()
	style_node.append_child(document.create_text_node('@layer base, theme;
		@layer theme { .x { color: red } div { margin: 1px } .y::before { content: "t" } }
		@layer base { .x { color: blue } #i.x { padding: 1px } [data-k] { opacity: .5 } }
		.x { color: green } div.x { border-top-width: 1px }
		@layer base.inner { div.x { border-left-width: 2px } .x, .y { outline-width: 1px } }
		@layer { .x { opacity: .4 } }
		@media (min-width: 1px) { @layer theme { .y { color: purple } } }
		.y::before { content: "u" } :is(.x, .z) { text-indent: 1px }').as_node()) or { panic(err) }
	mut head_node := head.as_node()
	head_node.append_child(style.as_node()) or { panic(err) }
	mut container := combined_matching_element(mut document, mut body, 'div', 'i', 'x')
	inner := combined_matching_element(mut document, mut container, 'span', '', 'x y')
	mut keyed := combined_matching_element(mut document, mut body, 'p', '', 'z')
	keyed.set_attribute_value('data-k', '1')
	keyed.set_attribute_value('style', 'color: black')
	plain := combined_matching_element(mut document, mut body, 'em', '', '')
	document.update_style()
	for element in [container, inner, keyed, plain] {
		combined := combined_matching_layers(element, none, true)
		assert combined == combined_matching_layers(element, none, false), element.local_name()
		pseudo := combined_matching_layers(element, .before, true)
		assert pseudo == combined_matching_layers(element, .before, false), element.local_name()
	}
	// The layers are present and populated in cascade order.
	layered := combined_matching_layers(container, none, true)
	assert layered.len >= 5
	assert layered.any(it.starts_with('base=[') && it != 'base=[]')
	assert layered.any(it.starts_with('base.inner=[') && it != 'base.inner=[]')
	assert layered.any(it.starts_with('theme=[') && it != 'theme=[]')
	assert layered[layered.len - 2].starts_with('=[') && layered[layered.len - 2] != '=[]'
}
