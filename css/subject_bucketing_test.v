module css

import dom

fn subject_bucketing_child(mut document dom.Document, mut parent dom.Element, namespace string, tag string, attributes map[string]string) &dom.Element {
	mut element := document.create_element_ns(namespace, tag) or { panic(err) }
	for name, value in attributes { element.set_attribute_value(name, value) }
	mut parent_node := parent.as_node()
	parent_node.append_child(element.as_node()) or { panic(err) }
	return element
}

fn subject_bucketing_matches(document &dom.Document, elements []&dom.Element) []string {
	computer := css_style_computer_for(document)
	mut scope := css_style_scope_for_document(document)
	scope.invalidate_rule_cache()
	scope.build_rule_cache_if_needed()
	mut out := []string{}
	for element in elements {
		for pseudo in [?dom.PseudoElement(none), ?dom.PseudoElement(.before)] {
			abstract := dom.AbstractElement.new(element, pseudo)
			mut attempted := PseudoClassBitmap{}
			mut matched_pseudo := false
			mode := if pseudo == none { ComputeStyleMode.normal } else { ComputeStyleMode.create_pseudo_element_style_if_needed }
			set := style_computer_build_matching_rule_set_impl(computer, abstract, mut attempted,
				&matched_pseudo, mode, scope)
			mut rules := []string{}
			for list in [set.user_agent_rules, set.user_rules] {
				for scoped in list { rules << '${u64(voidptr(scoped.rule.rule or { panic('rule') }))}' }
			}
			for layer in set.author_rules {
				for scoped in layer.rules { rules << '${layer.qualified_layer_name}:${u64(voidptr(scoped.rule.rule or { panic('rule') }))}' }
			}
			out << '${element.local_name()}${if pseudo == none { '' } else { '::before' }}=${rules.join(',')} hover=${attempted.get(.hover)} focus=${attempted.get(.focus_visible)}'
		}
	}
	return out
}

// Rules bucketed by the tag names their link and heading pseudo-classes
// require, and single-argument :is()/:where() compounds bucketed by a class,
// match exactly what universal candidates matched, with the same restyle bits.
fn test_link_heading_and_where_rules_bucket_by_their_required_names() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.html)
	html_ns := 'http://www.w3.org/1999/xhtml'
	mut html := document.create_element('html') or { panic(err) }
	mut document_node := document.as_node()
	document_node.append_child(html.as_node()) or { panic(err) }
	mut head := subject_bucketing_child(mut document, mut html, html_ns, 'head', {})
	mut body := subject_bucketing_child(mut document, mut html, html_ns, 'body', {})
	mut style := document.create_element('style') or { panic(err) }
	mut style_node := style.as_node()
	style_node.append_child(document.create_text_node(':link { color: red } :visited { color: blue }
		:link:active { color: green } :any-link:hover { outline: 1px solid } :local-link { margin: 1px }
		:heading { font-weight: 900 } :heading(2) { color: purple } :heading(3, 9) { color: teal }
		:heading(7) { color: black } :not(:link) { padding: 1px } :link::before { content: "x" }
		:where(.card[data-k]) { border-top-width: 1px } :is(.card:hover) { border-left-width: 2px }
		:where(div.card) { opacity: .5 } :where(p[title]) { opacity: .25 } :focus-visible { outline: 2px solid }
		:where([data-variant="link"]:only-child) { margin-top: 3px } div:where([data-k]) { margin-left: 4px }
		:is([data-mode="light"], [data-mode="auto"]) { color: white } :where([data-k]):where(div) { padding-top: 5px }
		:where(.card[data-k]):is([data-k]) { padding-left: 6px } :is([DATA-Mode]) { padding-right: 7px }
		@layer l { :heading(1) { color: orange } :link { text-decoration: none } }').as_node()) or { panic(err) }
	mut head_node := head.as_node()
	head_node.append_child(style.as_node()) or { panic(err) }
	mut elements := []&dom.Element{}
	elements << subject_bucketing_child(mut document, mut body, html_ns, 'a', {'href': '#x'})
	elements << subject_bucketing_child(mut document, mut body, html_ns, 'a', {})
	elements << subject_bucketing_child(mut document, mut body, html_ns, 'area', {'href': 'https://example.test/'})
	for level in 1 .. 7 { elements << subject_bucketing_child(mut document, mut body, html_ns, 'h${level}', {}) }
	elements << subject_bucketing_child(mut document, mut body, html_ns, 'div', {'class': 'card', 'data-k': '1'})
	elements << subject_bucketing_child(mut document, mut body, html_ns, 'div', {'class': 'card'})
	elements << subject_bucketing_child(mut document, mut body, html_ns, 'p', {'title': 't'})
	elements << subject_bucketing_child(mut document, mut body, html_ns, 'span', {})
	elements << subject_bucketing_child(mut document, mut body, html_ns, 'div', {'data-mode': 'light'})
	elements << subject_bucketing_child(mut document, mut body, html_ns, 'span', {'data-mode': 'auto'})
	elements << subject_bucketing_child(mut document, mut body, html_ns, 'p', {'data-mode': 'dark'})
	mut wrapper := subject_bucketing_child(mut document, mut body, html_ns, 'section', {})
	elements << subject_bucketing_child(mut document, mut wrapper, html_ns, 'button', {'data-variant': 'link'})
	elements << subject_bucketing_child(mut document, mut body, html_ns, 'b', {'data-variant': 'link'})
	elements << subject_bucketing_child(mut document, mut body, 'http://www.w3.org/2000/svg', 'a', {'href': '#y'})
	document.update_style()
	subject_bucketing_disabled_for_test = true
	universal := subject_bucketing_matches(document, elements)
	subject_bucketing_disabled_for_test = false
	bucketed := subject_bucketing_matches(document, elements)
	for index, line in universal {
		assert bucketed[index] == line
	}
	// The link and heading rules did match where they apply.
	assert bucketed[0].count(',') > bucketed[1].count(',')
	assert bucketed.any(it.starts_with('h2=') && it.count(',') >= 3)
	// The attribute rules too: the only child and the light and auto modes
	// gained rules the dark mode and the second link variant lack.
	button := bucketed.filter(it.starts_with('button='))[0]
	b := bucketed.filter(it.starts_with('b='))[0]
	assert button.count(',') > b.count(',')
	modes := bucketed.filter(it.starts_with('div=') || it.starts_with('span=') || it.starts_with('p='))
	assert modes.len > 3
}
