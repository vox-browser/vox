module css

import dom

// declaration_style_properties re-types a serialized CSSStyleProperties declaration into the typed
// StyleProperty list the cascade iterates over, mirroring Ladybird's CSSStyleProperties::properties().
fn test_declaration_style_properties() {
	mut declaration := CSSStyleProperties.create()
	declaration.properties << CSSStyleProperty{
		name:      'color'
		value:     'red'
		important: true
	}
	declaration.properties << CSSStyleProperty{
		name:      'width'
		value:     '10px'
		important: false
	}
	declaration.properties << CSSStyleProperty{
		name:      'not-a-real-property'
		value:     'x'
		important: false
	}

	props := declaration_style_properties(declaration)
	// The unknown property is skipped.
	assert props.len == 2

	color_id := property_id_from_string('color') or { panic('no color id') }
	width_id := property_id_from_string('width') or { panic('no width id') }
	assert props[0].property_id == color_id
	assert props[0].important == Important.yes
	assert props[1].property_id == width_id
	assert props[1].important == Important.no
	// Values are opaque dom.StyleValues carrying the serialized text.
	assert props[1].value.css_text == '10px'
}

// cascade_declarations over an element's inline style: direct properties are set and shorthands are
// expanded into the CascadedProperties (empty matching rules -> only the inline author style applies).
fn test_cascade_declarations_inline_style() {
	doc := dom.Document.create(dom.url_about_blank())
	mut el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	el.set_attribute_value('style', 'color: red; padding: 10px')
	abstract_element := dom.AbstractElement.new(el, none)

	s := StyleComputer.new(doc)
	mut cascaded := CascadedProperties.new()
	s.cascade_declarations(mut cascaded, abstract_element, []MatchingRule{}, CascadeOrigin.author,
		Important.no, none, none, []PropertyID{})

	// The direct `color` declaration is cascaded.
	color_id := property_id_from_string('color') or { panic('no color id') }
	if _ := cascaded.property(color_id) {
	} else {
		panic('color was not cascaded')
	}
	// The `padding` shorthand is expanded to its longhands (padding-top = 10px).
	padding_top_id := property_id_from_string('padding-top') or { panic('no padding-top id') }
	padding_top := cascaded.property(padding_top_id) or { panic('padding-top not cascaded (shorthand not expanded)') }
	assert padding_top.css_text == '10px'
}

// compute_properties turns cascaded values into computed values and runs the tail adjustments; here the
// effective-overflow rule applies: overflow-y: scroll forces overflow-x: visible to compute to auto.
fn test_compute_properties_resolves_effective_overflow() {
	doc := dom.Document.create(dom.url_about_blank())
	mut el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	el.set_attribute_value('style', 'overflow-x: visible; overflow-y: scroll')
	abstract_element := dom.AbstractElement.new(el, none)

	s := StyleComputer.new(doc)
	mut cascaded := CascadedProperties.new()
	s.cascade_declarations(mut cascaded, abstract_element, []MatchingRule{}, CascadeOrigin.author,
		Important.no, none, none, []PropertyID{})

	mut computed := s.compute_properties(abstract_element, mut cascaded)
	assert computed.overflow_y() == .scroll
	// overflow-x: visible computes to auto because overflow-y is neither visible nor clip.
	assert computed.overflow_x() == .auto_
}

// compute_logical_alias_mapping_context cascades only writing-mode + direction and maps them to the
// flow-relative context used for resolving logical property aliases.
fn test_compute_logical_alias_mapping_context() {
	doc := dom.Document.create(dom.url_about_blank())
	mut el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	el.set_attribute_value('style', 'writing-mode: vertical-rl; direction: rtl')
	abstract_element := dom.AbstractElement.new(el, none)

	s := StyleComputer.new(doc)
	// One (empty) author layer so the author-origin cascade runs and reads the element's inline style
	// (the real build_matching_rule_set always yields at least the un-named author layer).
	matching_rule_set := MatchingRuleSet{
		author_rules: [LayerMatchingRules{}]
	}
	context := s.compute_logical_alias_mapping_context(abstract_element, ComputeStyleMode.normal,
		matching_rule_set)
	assert context.writing_mode == .vertical_rl
	assert context.direction == .rtl
}

// The dom<->css bridge round-trips a css object through its DOM placeholder handle, and an empty
// placeholder resolves to none.
fn test_dom_css_bridge_round_trip() {
	mut computed := ComputedProperties.new()
	placeholder := computed_properties_to_dom(computed)
	round_tripped := computed_properties_from_dom(placeholder) or { panic('computed handle missing') }
	assert voidptr(round_tripped) == voidptr(computed)

	mut cascaded := CascadedProperties.new()
	c_placeholder := cascaded_properties_to_dom(cascaded)
	c_round := cascaded_properties_from_dom(c_placeholder) or { panic('cascaded handle missing') }
	assert voidptr(c_round) == voidptr(cascaded)

	empty := &dom.CSSComputedProperties_{}
	if _ := computed_properties_from_dom(empty) {
		panic('empty placeholder should not resolve to a css object')
	}
}

// compute_style runs the whole cascade->compute pipeline end-to-end via the bridge (style scope,
// matching rules, cascade, compute_properties) and yields a computed style reflecting the inline style.
fn test_compute_style_end_to_end() {
	doc := dom.Document.create(dom.url_about_blank())
	mut el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	el.set_attribute_value('style', 'overflow-x: hidden; overflow-y: hidden')
	abstract_element := dom.AbstractElement.new(el, none)

	s := StyleComputer.new(doc)
	computed := s.compute_style(abstract_element)
	assert computed.overflow_x() == .hidden
	assert computed.overflow_y() == .hidden
}

// A child inherits an inherited property (color) from its parent's stored computed style, retrieved
// across the dom<->css bridge.
fn test_compute_style_inherits_from_parent_via_bridge() {
	doc := dom.Document.create(dom.url_about_blank())
	mut parent := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	parent.set_attribute_value('style', 'color: red')
	mut child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or { panic('${err}') }
	mut parent_node := parent.as_node()
	child_node := child.as_node()
	parent_node.append_child(child_node) or { panic('append failed: ${err}') }

	s := StyleComputer.new(doc)

	// Compute the parent's style and store it (bridged) so the child can inherit through it.
	mut parent_ae := dom.AbstractElement.new(parent, none)
	parent_computed := s.compute_style(parent_ae)
	parent_ae.set_computed_properties(computed_properties_to_dom(parent_computed))

	// The child declares no color, so it inherits the parent's computed color.
	child_ae := dom.AbstractElement.new(child, none)
	child_computed := s.compute_style(child_ae)

	// Baseline: a parentless element with no color falls back to the initial color.
	mut orphan := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or { panic('${err}') }
	orphan_ae := dom.AbstractElement.new(orphan, none)
	orphan_computed := s.compute_style(orphan_ae)

	parent_color := parent_computed.property(.color, .no) or { panic('parent has no computed color') }
	child_color := child_computed.property(.color, .no) or { panic('child did not inherit color') }
	orphan_color := orphan_computed.property(.color, .no) or { panic('orphan has no computed color') }
	// The child inherited the parent's color...
	assert child_color.css_text == parent_color.css_text
	// ...which is a real inherited value, not the initial color the orphan falls back to.
	assert child_color.css_text != orphan_color.css_text
}

// computed_properties_to_dom mirrors the css computed values into the DOM placeholder's concrete fields,
// so DOM/layout code reading them directly (without importing css) sees the real computed style.
fn test_computed_properties_to_dom_mirrors_fields() {
	doc := dom.Document.create(dom.url_about_blank())
	mut el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	el.set_attribute_value('style', 'overflow-x: hidden; overflow-y: hidden; visibility: hidden')
	abstract_element := dom.AbstractElement.new(el, none)

	s := StyleComputer.new(doc)
	computed := s.compute_style(abstract_element)
	placeholder := computed_properties_to_dom(computed)

	// The DOM-side accessors read the mirrored fields (default would be .visible).
	assert placeholder.overflow_x() == .hidden
	assert placeholder.overflow_y() == .hidden
	assert placeholder.visibility() == .hidden
	// The handle still round-trips to the same css object.
	assert voidptr(computed_properties_from_dom(placeholder) or { panic('handle missing') }) == voidptr(computed)
}

// recompute_style computes and STORES an element's style on the element (bridged), so a top-down pass
// leaves each element styled and lets a child inherit from its already-stored parent -- the CSS half of
// DOM::Element::recompute_style, driving the whole pipeline onto the DOM tree.
fn test_recompute_style_stores_and_inherits() {
	doc := dom.Document.create(dom.url_about_blank())
	mut parent := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	parent.set_attribute_value('style', 'color: red')
	mut child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or { panic('${err}') }
	mut parent_node := parent.as_node()
	child_node := child.as_node()
	parent_node.append_child(child_node) or { panic('append failed: ${err}') }

	s := StyleComputer.new(doc)

	// Top-down: parent first (so its computed style is stored before the child inherits).
	mut parent_ae := dom.AbstractElement.new(parent, none)
	s.recompute_style(mut parent_ae)
	mut child_ae := dom.AbstractElement.new(child, none)
	s.recompute_style(mut child_ae)

	// Both elements now carry a stored (bridged) computed style.
	stored_parent := parent_ae.computed_properties() or { panic('parent style not stored') }
	stored_child := child_ae.computed_properties() or { panic('child style not stored') }
	parent_computed := computed_properties_from_dom(stored_parent) or { panic('parent handle missing') }
	child_computed := computed_properties_from_dom(stored_child) or { panic('child handle missing') }

	// The child inherited the parent's computed color from the stored parent style.
	parent_color := parent_computed.property(.color, .no) or { panic('parent has no computed color') }
	child_color := child_computed.property(.color, .no) or { panic('child did not inherit color') }
	assert child_color.css_text == parent_color.css_text
	// The stored parent style also mirrors layout fields (default display is not none for a div's initial).
	assert stored_parent.display().is_none() == false
}

// recompute_style_for_subtree styles a whole tree top-down in one pass, so an inherited property flows
// down multiple levels (grandparent -> parent -> grandchild) via each element's stored computed style.
fn test_recompute_style_for_subtree_inherits_down_levels() {
	doc := dom.Document.create(dom.url_about_blank())
	mut root := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	root.set_attribute_value('style', 'color: green')
	mut mid := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	mut leaf := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or { panic('${err}') }
	mut root_node := root.as_node()
	mut mid_node := mid.as_node()
	root_node.append_child(mid.as_node()) or { panic('append mid failed: ${err}') }
	mid_node.append_child(leaf.as_node()) or { panic('append leaf failed: ${err}') }

	mut s := StyleComputer.new(doc)
	recompute_style_for_subtree(mut s, root_node)

	// Every element got a stored computed style, and green flowed all the way to the leaf.
	root_ae := dom.AbstractElement.new(root, none)
	leaf_ae := dom.AbstractElement.new(leaf, none)
	root_computed := computed_properties_from_dom(root_ae.computed_properties() or { panic('root not styled') }) or {
		panic('root handle missing')
	}
	leaf_computed := computed_properties_from_dom(leaf_ae.computed_properties() or { panic('leaf not styled') }) or {
		panic('leaf handle missing')
	}
	root_color := root_computed.property(.color, .no) or { panic('root has no color') }
	leaf_color := leaf_computed.property(.color, .no) or { panic('leaf did not inherit color') }
	assert leaf_color.css_text == root_color.css_text
}

// DOM::Document.update_style() runs the CSS style pass over the whole tree through the installed hook:
// after a single update_style() call, every element is styled and inherited color reaches a descendant.
fn test_document_update_style_runs_css_pass_via_hook() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut root := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic('${err}') }
	root.set_attribute_value('style', 'color: blue')
	mut child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or { panic('${err}') }
	mut root_node := root.as_node()
	root_node.append_child(child.as_node()) or { panic('append child failed: ${err}') }
	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(root.as_node()) or { panic('append root failed: ${err}') }

	install_document_style_hook(doc)
	doc.needs_full_style_update = true
	doc.update_style()

	root_ae := dom.AbstractElement.new(root, none)
	child_ae := dom.AbstractElement.new(child, none)
	root_computed := computed_properties_from_dom(root_ae.computed_properties() or { panic('root not styled by update_style') }) or {
		panic('root handle missing')
	}
	child_computed := computed_properties_from_dom(child_ae.computed_properties() or { panic('child not styled by update_style') }) or {
		panic('child handle missing')
	}
	root_color := root_computed.property(.color, .no) or { panic('root has no color') }
	child_color := child_computed.property(.color, .no) or { panic('child did not inherit color') }
	assert child_color.css_text == root_color.css_text
}

// css_style_computer_for caches one persistent StyleComputer per document and installs the update hook,
// so plain doc.update_style() runs the CSS pass without a separate install_document_style_hook call.
fn test_css_style_computer_for_caches_and_autowires() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut root := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic('${err}') }
	root.set_attribute_value('style', 'color: teal')
	mut child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or { panic('${err}') }
	mut root_node := root.as_node()
	root_node.append_child(child.as_node()) or { panic('append child failed: ${err}') }
	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(root.as_node()) or { panic('append root failed: ${err}') }

	// Same persistent StyleComputer on repeat calls.
	first := css_style_computer_for(doc)
	second := css_style_computer_for(doc)
	assert voidptr(first) == voidptr(second)

	// The hook was installed as a side effect, so update_style works without an explicit install call.
	doc.needs_full_style_update = true
	doc.update_style()
	child_ae := dom.AbstractElement.new(child, none)
	child_computed := computed_properties_from_dom(child_ae.computed_properties() or {
		panic('child not styled by auto-wired update_style')
	}) or { panic('child handle missing') }
	if _ := child_computed.property(.color, .no) {
	} else {
		panic('child has no computed color after auto-wired update_style')
	}
}

// computed_value_for is the real-StyleComputer cascade query (drop-in for the minimal cascaded_value_for):
// a full style pass over the document resolves inline styles + inheritance, read back per element.
fn test_computed_value_for_inline_and_inheritance() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic('${err}') }
	mut body := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'body') or { panic('${err}') }
	body.set_attribute_value('style', 'color: navy')
	mut para := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'p') or { panic('${err}') }
	mut span := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or { panic('${err}') }
	span.set_attribute_value('style', 'color: red')

	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('append html failed: ${err}') }
	mut html_node := html_el.as_node()
	html_node.append_child(body.as_node()) or { panic('append body failed: ${err}') }
	mut body_node := body.as_node()
	body_node.append_child(para.as_node()) or { panic('append p failed: ${err}') }
	body_node.append_child(span.as_node()) or { panic('append span failed: ${err}') }

	color := property_id_from_string('color') or { panic('color id') }
	body_color := computed_value_for(body, color) or { panic('no computed color for body') }
	para_color := computed_value_for(para, color) or { panic('no computed color for p') }
	span_color := computed_value_for(span, color) or { panic('no computed color for span') }

	// p (no color) inherits body's navy; span overrides it inline.
	assert para_color == body_color
	assert span_color != body_color
}
