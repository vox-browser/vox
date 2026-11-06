module css

import dom
import math
import svg

struct CSSAnimationEventObservation {
mut:
	names []string
}

fn test_abstract_element_equality_uses_dom_identity() {
	document := dom.Document.create(dom.url_about_blank())
	first := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	second := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	assert abstract_elements_equal(dom.AbstractElement.new(first, none), dom.AbstractElement.new(first, none))
	assert !abstract_elements_equal(dom.AbstractElement.new(first, none), dom.AbstractElement.new(second, none))
	assert !abstract_elements_equal(dom.AbstractElement.new(first, .before), dom.AbstractElement.new(first, .after))
}

fn test_single_line_input_clamps_line_height_even_with_fixed_height() {
	document := dom.Document.create(dom.url_about_blank())
	mut input := document.create_element_ns('http://www.w3.org/1999/xhtml', 'input') or {
		panic(err)
	}
	input.set_attribute_value('type', 'text')
	input.set_attribute_value('style', 'height:0;line-height:0;font-size:16px')
	computed := StyleComputer.new(document).compute_style(dom.AbstractElement.new(input, none))
	assert computed.line_height().to_double() > 0

	mut url_input := document.create_element_ns('http://www.w3.org/1999/xhtml', 'input') or {
		panic(err)
	}
	url_input.set_attribute_value('type', 'url')
	url_input.set_attribute_value('style', 'height:0;line-height:0;font-size:16px')
	url_computed := StyleComputer.new(document).compute_style(dom.AbstractElement.new(url_input,
		none))
	assert url_computed.line_height().to_double() == 0
}

fn test_property_computation_contexts_are_cached_per_style_pass() {
	document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(element.as_node()) or { panic('${err}') }
	abstract_element := dom.AbstractElement.new(element, none)
	computer := css_style_computer_for(document)
	computed := computer.compute_style(abstract_element)

	assert computer.computation_context_cache_is_empty()
	_ = computer.get_computation_context_for_property(.font_size, computed, abstract_element)
	assert computer.cached_font_computation_context != none
	_ = computer.get_computation_context_for_property(.line_height, computed, abstract_element)
	assert computer.cached_line_height_computation_context != none
	_ = computer.get_computation_context_for_property(.width, computed, abstract_element)
	assert computer.cached_generic_computation_context != none

	computer.clear_computation_context_caches()
	assert computer.computation_context_cache_is_empty()
}

// declaration_style_properties re-types a serialized CSSStyleProperties declaration into the typed
// StyleProperty list the cascade iterates over, mirroring Ladybird's CSSStyleProperties::properties().
fn test_declaration_style_properties() {
	mut declaration := CSSStyleProperties.create()
	declaration.properties << CSSStyleProperty{
		name: 'color'
		value: 'red'
		important: true
	}
	declaration.properties << CSSStyleProperty{
		name: 'width'
		value: '10px'
		important: false
	}
	declaration.properties << CSSStyleProperty{
		name: 'not-a-real-property'
		value: 'x'
		important: false
	}

	props := declaration_style_properties(declaration)
	// The unknown property is skipped.
	assert props.len == 2
	assert declaration.typed_importance_mask_ == 3

	color_id := property_id_from_string('color') or { panic('no color id') }
	width_id := property_id_from_string('width') or { panic('no width id') }
	assert props[0].property_id == color_id
	assert props[0].important == Important.yes
	assert props[1].property_id == width_id
	assert props[1].important == Important.no
	// Values are opaque dom.StyleValues carrying the serialized text.
	assert props[1].value.css_text == '10px'
	assert declaration_style_properties(declaration)[0].value == props[0].value

	blue := parse_css_value_logic(.color, 'blue') or { panic('blue') }
	declaration.set_a_css_declaration(.color, dom_style_value_from_value_logic(blue), .no)
	refreshed := declaration_style_properties(declaration)
	assert refreshed[0].value.css_text == 'blue'
	assert declaration.typed_importance_mask_ == 1
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
	s.cascade_declarations(mut cascaded, abstract_element, []ScopedMatchingRule{}, CascadeOrigin.author, Important.no, none, none, []PropertyID{})

	// The direct `color` declaration is cascaded.
	color_id := property_id_from_string('color') or { panic('no color id') }
	if _ := cascaded.property(color_id) {
	} else {
		panic('color was not cascaded')
	}
	// The `padding` shorthand is expanded to its longhands (padding-top = 10px).
	padding_top_id := property_id_from_string('padding-top') or { panic('no padding-top id') }
	padding_top := cascaded.property(padding_top_id) or {
		panic('padding-top not cascaded (shorthand not expanded)')
	}
	assert padding_top.css_text == '10px'
}

fn test_apply_arbitrary_property_list_to_cascade() {
	doc := dom.Document.create(dom.url_about_blank())
	mut element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	value := dom_style_value_from_value_logic(parse_css_value_logic(.color, 'tomato') or {
		panic('color did not parse')
	})
	properties := [StyleProperty{
		property_id: .color
		value: value
	}]
	mut cascaded := CascadedProperties.new()
	apply_property_list_to_cascade(mut cascaded, dom.AbstractElement.new(element, none), properties, .author, .no, none, unsafe { nil }, none, none, [])
	assert cascaded.property(.color)?.css_text == 'tomato'
	assert cascaded.property_source(.color) == unsafe { nil }
}

fn test_author_revert_also_removes_presentational_hint_origin() {
	doc := dom.Document.create(dom.url_about_blank())
	mut element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	abstract_element := dom.AbstractElement.new(element, none)
	mut cascaded := CascadedProperties.new()

	hint := StyleProperty{
		property_id: .color
		value: dom_style_value_from_value_logic(parse_css_value_logic(.color, 'red') or {
			panic('presentational hint did not parse')
		})
	}
	apply_property_list_to_cascade(mut cascaded, abstract_element, [hint], .author_presentational_hint, .no, none, unsafe { nil }, none, none, [])
	revert := StyleProperty{
		property_id: .color
		value: dom_style_value_from_value_logic(parse_css_value_logic(.color, 'revert') or {
			panic('revert did not parse')
		})
	}
	apply_property_list_to_cascade(mut cascaded, abstract_element, [revert], .author, .no, none, unsafe { nil }, none, none, [])

	assert cascaded.property(.color) == none
}

fn test_cascaded_properties_cache_retains_unresolved_shorthand_ids() {
	mut cascaded := CascadedProperties.new()
	unresolved := dom_style_value_from_value_logic(StyleValue(UnresolvedStyleValue.create(parse_component_values_for_value_logic('var(--spacing)'))))
	cascaded.set_property(.margin, unresolved, .no, .author, none, unsafe { nil }, none)

	retained := cascaded.property(.margin) or {
		panic('unresolved shorthand was not retained in the cascade')
	}
	assert retained == unresolved
	cascaded.revert_property(.margin, .no, .author)
	assert cascaded.property(.margin) == none
}

fn test_cascaded_properties_refresh_source_on_same_priority_replacement() {
	mut cascaded := CascadedProperties.new()
	first_value := &dom.StyleValue{
		css_text: 'red'
	}
	second_value := &dom.StyleValue{
		css_text: 'blue'
	}
	first_source := &dom.StyleValue{
		css_text: 'first source'
	}
	second_source := &dom.StyleValue{
		css_text: 'second source'
	}
	cascaded.set_property(.color, first_value, .no, .author, none, voidptr(first_source), none)
	cascaded.set_property(.color, second_value, .no, .author, none, voidptr(second_source), none)

	assert cascaded.property(.color)? == second_value
	assert cascaded.property_source(.color) == voidptr(second_source)
}

fn test_selection_resolves_var_in_shorthand_before_filtering_longhands() {
	mut doc := dom.Document.create(dom.url_about_blank())
	add_document_author_style_sheet(doc, 'div {
		--selection-bg: lightblue;
	}
	div::selection {
		background: var(--selection-bg);
	}')
	mut element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(element.as_node()) or { panic('${err}') }

	computer := StyleComputer.new(doc)
	mut element_abstract := dom.AbstractElement.new(element, none)
	computer.recompute_style(mut element_abstract)
	selection := computer.compute_pseudo_element_style_if_needed(dom.AbstractElement.new(element, .selection)) or { panic('::selection style was not generated') }
	background_color := selection.property(.background_color, .no) or {
		panic('::selection background-color missing')
	}
	assert background_color.css_text == 'rgb(173, 216, 230)'
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
	s.cascade_declarations(mut cascaded, abstract_element, []ScopedMatchingRule{}, CascadeOrigin.author, Important.no, none, none, []PropertyID{})

	mut computed := s.compute_properties(abstract_element, mut cascaded)
	assert computed.overflow_y() == .scroll
	// overflow-x: visible computes to auto because overflow-y is neither visible nor clip.
	assert computed.overflow_x() == .auto_
}

fn test_button_adjusts_computed_display_after_generic_box_transformation() {
	doc := dom.Document.create(dom.url_about_blank())
	s := StyleComputer.new(doc)

	mut inline_button := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'button') or {
		panic('${err}')
	}
	inline_button.set_attribute_value('style', 'display: inline')
	inline_computed := s.compute_style(dom.AbstractElement.new(inline_button, none))
	assert inline_computed.display_before_box_type_transformation() == Display.from_short(.inline_)
	assert inline_computed.display() == Display.from_short(.inline_block)

	mut block_button := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'button') or {
		panic('${err}')
	}
	block_button.set_attribute_value('style', 'display: block')
	block_computed := s.compute_style(dom.AbstractElement.new(block_button, none))
	assert block_computed.display_before_box_type_transformation() == Display.from_short(.block)
	assert block_computed.display() == Display.from_short(.flow_root)

	mut flex_button := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'button') or {
		panic('${err}')
	}
	flex_button.set_attribute_value('style', 'display: flex')
	flex_computed := s.compute_style(dom.AbstractElement.new(flex_button, none))
	assert flex_computed.display() == Display.from_short(.flex)
}

fn test_textarea_adjusts_computed_display_for_internal_shadow_tree() {
	doc := dom.Document.create(dom.url_about_blank())
	s := StyleComputer.new(doc)

	mut inline_textarea := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'textarea') or {
		panic('${err}')
	}
	inline_textarea.set_attribute_value('style', 'display: inline')
	inline_computed := s.compute_style(dom.AbstractElement.new(inline_textarea, none))
	assert inline_computed.display() == Display.from_short(.inline_block)

	mut contents_textarea := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'textarea') or {
		panic('${err}')
	}
	contents_textarea.set_attribute_value('style', 'display: contents')
	contents_computed := s.compute_style(dom.AbstractElement.new(contents_textarea, none))
	assert contents_computed.display() == Display.from_short(.none_)
}

fn test_br_adjusts_non_none_computed_display_to_inline() {
	doc := dom.Document.create(dom.url_about_blank())
	computer := StyleComputer.new(doc)

	for authored_display in ['table-cell', 'table-caption', 'flex', 'grid', 'block'] {
		mut element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'br') or {
			panic('${err}')
		}
		element.set_attribute_value('style', 'display: ${authored_display}')
		computed := computer.compute_style(dom.AbstractElement.new(element, none))
		assert computed.display() == Display.from_short(.inline_)
	}

	mut contents := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'br') or {
		panic('${err}')
	}
	contents.set_attribute_value('style', 'display: contents')
	assert computer.compute_style(dom.AbstractElement.new(contents, none)).display() == Display.from_short(.none_)

	mut hidden := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'br') or {
		panic('${err}')
	}
	hidden.set_attribute_value('style', 'display: none')
	assert computer.compute_style(dom.AbstractElement.new(hidden, none)).display() == Display.from_short(.none_)
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
	context := s.compute_logical_alias_mapping_context(abstract_element, ComputeStyleMode.normal, matching_rule_set)
	assert context.writing_mode == .vertical_rl
	assert context.direction == .rtl
}

// The dom<->css bridge round-trips a css object through its DOM placeholder handle, and an empty
// placeholder resolves to none.
fn test_dom_css_bridge_round_trip() {
	mut computed := ComputedProperties.new()
	placeholder := computed_properties_to_dom(computed)
	round_tripped := computed_properties_from_dom(placeholder) or {
		panic('computed handle missing')
	}
	assert voidptr(round_tripped) == voidptr(computed)

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
	mut parent := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	parent.set_attribute_value('style', 'color: red')
	mut child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
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
	mut orphan := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	orphan_ae := dom.AbstractElement.new(orphan, none)
	orphan_computed := s.compute_style(orphan_ae)

	parent_color := parent_computed.property(.color, .no) or {
		panic('parent has no computed color')
	}
	child_color := child_computed.property(.color, .no) or { panic('child did not inherit color') }
	orphan_color := orphan_computed.property(.color, .no) or {
		panic('orphan has no computed color')
	}
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
	el.set_attribute_value('style', 'overflow-x: hidden; overflow-y: hidden; visibility: hidden; color-scheme: only light dark')
	abstract_element := dom.AbstractElement.new(el, none)

	s := StyleComputer.new(doc)
	computed := s.compute_style(abstract_element)
	placeholder := computed_properties_to_dom(computed)

	// The DOM-side accessors read the mirrored fields (default would be .visible).
	assert placeholder.overflow_x() == .hidden
	assert placeholder.overflow_y() == .hidden
	assert placeholder.visibility() == .hidden
	assert placeholder.color_schemes() == ['light', 'dark']
	assert placeholder.color_scheme_only()
	// The handle still round-trips to the same css object.
	assert voidptr(computed_properties_from_dom(placeholder) or { panic('handle missing') }) == voidptr(computed)
}

// recompute_style computes and STORES an element's style on the element (bridged), so a top-down pass
// leaves each element styled and lets a child inherit from its already-stored parent -- the CSS half of
// DOM::Element::recompute_style, driving the whole pipeline onto the DOM tree.
fn test_recompute_style_stores_and_inherits() {
	doc := dom.Document.create(dom.url_about_blank())
	mut parent := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	parent.set_attribute_value('style', 'color: red')
	mut child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
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
	parent_computed := computed_properties_from_dom(stored_parent) or {
		panic('parent handle missing')
	}
	child_computed := computed_properties_from_dom(stored_child) or {
		panic('child handle missing')
	}

	// The child inherited the parent's computed color from the stored parent style.
	parent_color := parent_computed.property(.color, .no) or {
		panic('parent has no computed color')
	}
	child_color := child_computed.property(.color, .no) or { panic('child did not inherit color') }
	assert child_color.css_text == parent_color.css_text
	// The stored parent style also mirrors layout fields (default display is not none for a div's initial).
	assert stored_parent.display().is_none() == false
}

fn test_style_recomputation_counters_track_full_inherited_and_noop_work() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut parent := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	parent.set_attribute_value('style', 'color: red')
	child := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic(err)
	}
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node()) or { panic(err) }
	computer := StyleComputer.new(document)
	mut parent_abstract := dom.AbstractElement.new(parent, none)
	mut child_abstract := dom.AbstractElement.new(child, none)
	computer.recompute_style(mut parent_abstract)
	computer.recompute_style(mut child_abstract)
	document.reset_style_invalidation_counters()

	computer.recompute_style(mut parent_abstract)
	computer.recompute_inherited_style_with_invalidation(mut child_abstract)
	counters := document.style_invalidation_counters()
	assert counters.element_style_recomputations == 1
	assert counters.element_style_noop_recomputations == 1
	assert counters.element_inherited_style_recomputations == 1
	assert counters.element_inherited_style_noop_recomputations == 1
}

fn test_inheritance_dependent_specified_values_survive_the_cascade_pass() {
	document := dom.Document.create(dom.url_about_blank())
	mut parent := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	parent.set_attribute_value('style', 'font-size: 20px')
	mut child := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic(err)
	}
	child.set_attribute_value('style', 'font-size: 2em')
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node()) or { panic(err) }

	computer := StyleComputer.new(document)
	mut parent_abstract := dom.AbstractElement.new(parent, none)
	mut child_abstract := dom.AbstractElement.new(child, none)
	computer.recompute_style(mut parent_abstract)
	computer.recompute_style(mut child_abstract)
	child_computed := computed_properties_from_dom(child_abstract.computed_properties() or {
		panic('child style missing')
	}) or { panic('child computed properties missing') }
	assert child_computed.font_size().to_double() == 40
	assert child_computed.inheritance_dependent_specified_values()[.font_size].css_text == '2em'

	parent.set_attribute_value('style', 'font-size: 10px')
	computer.recompute_style(mut parent_abstract)
	computer.recompute_inherited_style_with_invalidation(mut child_abstract)
	updated_child := computed_properties_from_dom(child_abstract.computed_properties() or {
		panic('updated child style missing')
	}) or { panic('updated child computed properties missing') }
	assert updated_child.font_size().to_double() == 20
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
	root_computed := computed_properties_from_dom(root_ae.computed_properties() or {
		panic('root not styled')
	}) or { panic('root handle missing') }
	leaf_computed := computed_properties_from_dom(leaf_ae.computed_properties() or {
		panic('leaf not styled')
	}) or { panic('leaf handle missing') }
	root_color := root_computed.property(.color, .no) or { panic('root has no color') }
	leaf_color := leaf_computed.property(.color, .no) or { panic('leaf did not inherit color') }
	assert leaf_color.css_text == root_color.css_text
}

fn test_table_section_and_row_align_hints_are_inherited_by_cells() {
	doc := dom.Document.create(dom.url_about_blank())
	mut section := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'tbody') or {
		panic('${err}')
	}
	section.set_attribute_value('align', 'right')
	mut inherited_row := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'tr') or {
		panic('${err}')
	}
	mut inherited_cell := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'td') or {
		panic('${err}')
	}
	mut overriding_row := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'tr') or {
		panic('${err}')
	}
	overriding_row.set_attribute_value('align', 'middle')
	mut overriding_cell := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'td') or {
		panic('${err}')
	}
	mut section_node := section.as_node()
	mut inherited_row_node := inherited_row.as_node()
	mut overriding_row_node := overriding_row.as_node()
	inherited_row_node.append_child(inherited_cell.as_node()) or { panic('${err}') }
	overriding_row_node.append_child(overriding_cell.as_node()) or { panic('${err}') }
	section_node.append_child(inherited_row.as_node()) or { panic('${err}') }
	section_node.append_child(overriding_row.as_node()) or { panic('${err}') }

	mut style_computer := StyleComputer.new(doc)
	recompute_style_for_subtree(mut style_computer, section_node)
	inherited := computed_properties_from_dom(dom.AbstractElement.new(inherited_cell, none).computed_properties() or {
		panic('inherited cell not styled')
	}) or { panic('inherited cell handle missing') }
	overridden := computed_properties_from_dom(dom.AbstractElement.new(overriding_cell, none).computed_properties() or {
		panic('overriding cell not styled')
	}) or { panic('overriding cell handle missing') }
	assert inherited.text_align() == .libweb_right
	assert overridden.text_align() == .libweb_center
}

// DOM::Document.update_style() runs the CSS style pass over the whole tree through the installed hook:
// after a single update_style() call, every element is styled and inherited color reaches a descendant.
fn test_document_update_style_runs_css_pass_via_hook() {
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_browsing_context(&dom.BrowsingContext{})
	mut root := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic('${err}') }
	root.set_attribute_value('style', 'color: blue')
	mut child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	mut root_node := root.as_node()
	root_node.append_child(child.as_node()) or { panic('append child failed: ${err}') }
	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(root.as_node()) or { panic('append root failed: ${err}') }

	install_document_style_hook(doc)
	doc.needs_full_style_update = true
	doc.update_style()

	root_ae := dom.AbstractElement.new(root, none)
	child_ae := dom.AbstractElement.new(child, none)
	root_computed := computed_properties_from_dom(root_ae.computed_properties() or {
		panic('root not styled by update_style')
	}) or { panic('root handle missing') }
	child_computed := computed_properties_from_dom(child_ae.computed_properties() or {
		panic('child not styled by update_style')
	}) or { panic('child handle missing') }
	root_color := root_computed.property(.color, .no) or { panic('root has no color') }
	child_color := child_computed.property(.color, .no) or { panic('child did not inherit color') }
	assert child_color.css_text == root_color.css_text
}

// css_style_computer_for caches one persistent StyleComputer per document and installs the update hook,
// so plain doc.update_style() runs the CSS pass without a separate install_document_style_hook call.
fn test_css_style_computer_for_caches_and_autowires() {
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_browsing_context(&dom.BrowsingContext{})
	mut root := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic('${err}') }
	root.set_attribute_value('style', 'color: teal')
	mut child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
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

fn test_computed_lengths_retain_viewport_resolution_context_for_layout() {
	doc := dom.Document.create(dom.url_about_blank())
	mut mutable_doc := unsafe { &dom.Document(doc) }
	mutable_doc.set_viewport_rect(dom.Rect{0, 0, 500, 300})
	mut element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	element.set_attribute_value('style', 'width: 10vw; height: 20vh; margin-left: 2rem')
	mut computer := StyleComputer.new(doc)
	computed := computer.compute_style(dom.AbstractElement.new(element, none))
	assert computed.length_percentage_to_px(.width, 0) or { -1 } == 50
	assert computed.length_percentage_to_px(.height, 0) or { -1 } == 60
	assert computed.length_percentage_to_px(.margin_left, 0) or { -1 } == 32
}

fn test_media_feature_evaluation_uses_document_viewport() {
	doc := dom.Document.create(dom.url_about_blank())
	mut mutable_doc := unsafe { &dom.Document(doc) }
	query := parse_media_query_from_text('(min-width: 600px)') or { panic('query') }
	mutable_doc.set_viewport_rect(dom.Rect{0, 0, 500, 700})
	assert !query.evaluate(doc)
	portrait := parse_media_query_from_text('(orientation: portrait)') or { panic('query') }
	assert portrait.evaluate(doc)
	mutable_doc.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	assert query.evaluate(doc)
	assert !portrait.evaluate(doc)
}

fn test_document_update_style_reevaluates_media_rules_before_cascade() {
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_browsing_context(&dom.BrowsingContext{})
	doc.set_viewport_rect(dom.Rect{0, 0, 500, 600})
	mut html := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut target := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html.as_node()) or { panic('${err}') }
	mut html_node := html.as_node()
	html_node.append_child(target.as_node()) or { panic('${err}') }
	add_document_author_style_sheet(doc, 'div { color: blue; } @media (min-width: 600px) { div { color: red; } }')
	css_style_computer_for(doc)
	doc.needs_full_style_update = true
	doc.update_style()
	assert computed_value_for(target, .color) or { '' } == 'rgb(0, 0, 255)'

	doc.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	doc.needs_full_style_update = true
	doc.update_style()
	assert computed_value_for(target, .color) or { '' } == 'rgb(255, 0, 0)'
}

fn test_document_media_rule_entry_point_crosses_css_module_boundary() {
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_browsing_context(&dom.BrowsingContext{})
	doc.set_viewport_rect(dom.Rect{0, 0, 500, 600})
	mut html := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut target := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html.as_node()) or { panic('${err}') }
	mut html_node := html.as_node()
	html_node.append_child(target.as_node()) or { panic('${err}') }
	add_document_author_style_sheet(doc, 'div { color: blue; } @media (min-width: 600px) { div { color: red; } }')
	css_style_computer_for(doc)
	doc.needs_full_style_update = true
	doc.update_style()
	assert computed_value_for(target, .color) or { '' } == 'rgb(0, 0, 255)'

	// Upstream Document::evaluate_media_queries_and_report_changes() calls
	// evaluate_media_rules() directly. This must invalidate style through the
	// CSS-owned StyleScope without requiring an unrelated full-style flag.
	doc.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	doc.evaluate_media_rules()
	assert doc.needs_full_style_update
	doc.update_style()
	assert computed_value_for(target, .color) or { '' } == 'rgb(255, 0, 0)'
}

fn test_shadow_media_rule_change_only_invalidates_its_style_scope_cache() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{})
	document.set_viewport_rect(dom.Rect{0, 0, 500, 600})
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut first_host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	mut second_host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node()) or { panic('${err}') }
	mut root_node := root.as_node()
	root_node.append_child(first_host.as_node()) or { panic('${err}') }
	root_node.append_child(second_host.as_node()) or { panic('${err}') }
	first_shadow := first_host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic('${err}') }
	second_shadow := second_host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic('${err}') }
	add_shadow_root_author_style_sheet(first_shadow, '@media (min-width: 600px) { span { color: red } }')
	add_shadow_root_author_style_sheet(second_shadow, 'span { color: blue }')
	_ := css_style_computer_for(document)
	document.evaluate_media_rules()
	mut document_scope := css_style_scope_for_document(document)
	mut first_scope := css_style_scope_for_shadow_root(first_shadow)
	mut second_scope := css_style_scope_for_shadow_root(second_shadow)
	document_scope.build_rule_cache_if_needed()
	first_scope.build_rule_cache_if_needed()
	second_scope.build_rule_cache_if_needed()
	assert document_scope.has_valid_rule_cache()
	assert first_scope.has_valid_rule_cache()
	assert second_scope.has_valid_rule_cache()

	document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	document.evaluate_media_rules()
	assert document_scope.has_valid_rule_cache()
	assert !first_scope.has_valid_rule_cache()
	assert second_scope.has_valid_rule_cache()
}

fn test_document_style_sheet_source_entry_point_uses_css_owned_sheets() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut style := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'style') or {
		panic('${err}')
	}
	mut style_node := style.as_node()
	style_node.append_child(doc.create_text_node('.card { color: red; }').as_node()) or {
		panic('${err}')
	}
	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(style.as_node()) or { panic('${err}') }
	css_style_computer_for(doc)

	assert doc.get_style_sheet_source(&dom.StyleSheetIdentifier{
		type_: .style_element
		dom_element_unique_id: style.as_node().unique_id()
	}) or { '' } == '.card { color: red; }'

	set_document_user_style_sheet(doc, 'body { color: green; }')
	assert doc.get_style_sheet_source(&dom.StyleSheetIdentifier{
		type_: .user_style
	}) or { '' } == 'body { color: green; }'

	ua_source := doc.get_style_sheet_source(&dom.StyleSheetIdentifier{
		type_: .user_agent
		url: 'CSS/Default.css'
	}) or { '' }
	assert ua_source.contains('display: block')
}

fn test_document_update_style_builds_property_rule_registration_cache() {
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_browsing_context(&dom.BrowsingContext{})
	mut html := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html.as_node()) or { panic('${err}') }
	add_document_author_style_sheet(doc, '@property --accent { syntax: "<color>"; inherits: false; initial-value: red; }')
	css_style_computer_for(doc)
	doc.needs_full_style_update = true
	doc.update_style()

	registration := doc.get_registered_custom_property('--accent') or {
		panic('missing @property registration')
	}
	assert registration.syntax == '<color>'
	assert !registration.inherits
	assert registration.initial_value or { '' } == 'red'
}

fn test_document_cache_entry_points_cross_the_dom_css_boundary() {
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_browsing_context(&dom.BrowsingContext{})
	add_document_author_style_sheet(doc, '@property --accent { syntax: "<color>"; inherits: false; initial-value: red; } @counter-style boxes { system: cyclic; symbols: "□"; suffix: " "; }')
	css_style_computer_for(doc)

	doc.build_registered_properties_cache()
	registration := doc.get_registered_custom_property('--accent') or {
		panic('missing @property registration')
	}
	assert registration.syntax == '<color>'
	assert registration.initial_value or { '' } == 'red'

	doc.build_counter_style_cache()
	styles := registered_counter_styles_for_document(doc)
	assert 'boxes' in styles
	assert 'ethiopic-numeric' in styles
}

fn test_comma_only_media_query_list_does_not_match() {
	mut media := MediaList.create_empty()
	media.set_media_text(',,')
	assert media.media.len == 3
	assert !media.matches()
	doc := dom.Document.create(dom.url_about_blank())
	assert !media.evaluate(doc)
}

fn test_concrete_html_element_presentational_hint_entry_points() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/root/' })

	mut hr_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'hr') or {
		panic(err)
	}
	hr_element.set_attribute_value('color', 'red')
	hr_element.set_attribute_value('size', '10')
	hr_element.set_attribute_value('align', 'center')
	hr_element.set_attribute_value('width', '50%')
	hr := unsafe { &dom.HTMLHRElement(hr_element) }
	assert html_hr_element_is_presentational_hint(hr, 'noshade')
	mut hr_properties := CascadedProperties.new()
	html_hr_element_apply_presentational_hints(hr, mut hr_properties)
	assert hr_properties.property(.border_top_style)?.css_text == 'solid'
	assert hr_properties.property(.border_left_width)?.css_text == '5px'
	assert hr_properties.property(.margin_left)?.css_text == 'auto'
	assert hr_properties.property(.width)?.css_text == '50%'

	mut marquee_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'marquee') or {
		panic(err)
	}
	marquee_element.set_attribute_value('bgcolor', '#123456')
	marquee_element.set_attribute_value('hspace', '4')
	marquee := unsafe { &dom.HTMLMarqueeElement(marquee_element) }
	assert html_marquee_element_is_presentational_hint(marquee, 'hspace')
	mut marquee_properties := CascadedProperties.new()
	html_marquee_element_apply_presentational_hints(marquee, mut marquee_properties)
	assert marquee_properties.property(.margin_left)?.css_text == '4px'
	assert marquee_properties.property(.margin_right)?.css_text == '4px'

	mut pre_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'pre') or {
		panic(err)
	}
	pre_element.set_attribute_value('wrap', '')
	pre := unsafe { &dom.HTMLPreElement(pre_element) }
	mut pre_properties := CascadedProperties.new()
	html_pre_element_apply_presentational_hints(pre, mut pre_properties)
	assert pre_properties.property(.text_wrap_mode)?.css_text == 'wrap'

	mut caption_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'caption') or {
		panic(err)
	}
	caption_element.set_attribute_value('align', 'bottom')
	caption := unsafe { &dom.HTMLTableCaptionElement(caption_element) }
	mut caption_properties := CascadedProperties.new()
	html_table_caption_element_apply_presentational_hints(caption, mut caption_properties)
	assert caption_properties.property(.caption_side)?.css_text == 'bottom'

	mut list_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'ul') or {
		panic(err)
	}
	list_element.set_attribute_value('type', 'circle')
	list := unsafe { &dom.HTMLUListElement(list_element) }
	mut list_properties := CascadedProperties.new()
	html_ulist_element_apply_presentational_hints(list, mut list_properties)
	assert list_properties.property(.list_style_type)?.css_text == 'circle'

	mut row_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'tr') or {
		panic(err)
	}
	row_element.set_attribute_value('background', 'tile.png')
	row_element.set_attribute_value('height', '12')
	row_element.set_attribute_value('align', 'middle')
	row := unsafe { &dom.HTMLTableRowElement(row_element) }
	assert html_table_row_element_is_presentational_hint(row, 'align')
	mut row_properties := CascadedProperties.new()
	html_table_row_element_apply_presentational_hints(row, mut row_properties)
	assert row_properties.property(.background_image)?.css_text.contains('tile.png')
	assert row_properties.property(.height)?.css_text == '12px'
	assert row_properties.property(.text_align)?.css_text == '-libweb-center'

	mut section_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'tbody') or {
		panic(err)
	}
	section_element.set_attribute_value('align', 'justify')
	section := unsafe { &dom.HTMLTableSectionElement(section_element) }
	assert html_table_section_element_is_presentational_hint(section, 'align')
	mut section_properties := CascadedProperties.new()
	html_table_section_element_apply_presentational_hints(section, mut section_properties)
	assert section_properties.property(.text_align)?.css_text == 'justify'

	mut cell_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'td') or {
		panic(err)
	}
	cell := unsafe { &dom.HTMLTableCellElement(cell_element) }
	cell_element.set_attribute_value('align', 'justify')
	mut cell_properties := CascadedProperties.new()
	html_table_cell_element_apply_presentational_hints(cell, mut cell_properties)
	assert cell_properties.property(.text_align)?.css_text == 'justify'
	cell_element.set_attribute_value('align', 'start')
	mut invalid_cell_properties := CascadedProperties.new()
	html_table_cell_element_apply_presentational_hints(cell, mut invalid_cell_properties)
	assert invalid_cell_properties.property(.text_align) == none

	assert html_div_element_is_presentational_hint(unsafe { &dom.HTMLDivElement(hr_element) }, 'align')
	assert html_paragraph_element_is_presentational_hint(unsafe {
		&dom.HTMLParagraphElement(hr_element)
	}, 'align')
	assert html_table_col_element_is_presentational_hint(unsafe {
		&dom.HTMLTableColElement(hr_element)
	}, 'width')
	assert html_table_section_element_is_presentational_hint(unsafe {
		&dom.HTMLTableSectionElement(hr_element)
	}, 'align')
	assert html_heading_element_is_presentational_hint(unsafe {
		&dom.HTMLHeadingElement(hr_element)
	}, 'align')
	assert html_table_cell_element_is_presentational_hint(unsafe {
		&dom.HTMLTableCellElement(hr_element)
	}, 'nowrap')

	mut body_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'body') or {
		panic(err)
	}
	body_element.set_attribute_value('bgcolor', '#123456')
	body_element.set_attribute_value('text', 'red')
	body_element.set_attribute_value('background', 'tile.png')
	body_element.set_attribute_value('marginheight', '8junk')
	body_element.set_attribute_value('leftmargin', '9')
	body := unsafe { &dom.HTMLBodyElement(body_element) }
	assert html_body_element_is_presentational_hint(body, 'marginheight')
	mut body_properties := CascadedProperties.new()
	html_body_element_apply_presentational_hints(body, mut body_properties)
	assert body_properties.property(.background_image)?.css_text.contains('tile.png')
	assert body_properties.property(.margin_top)?.css_text == '8px'
	assert body_properties.property(.margin_bottom)?.css_text == '8px'
	assert body_properties.property(.margin_left)?.css_text == '9px'

	mut li_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'li') or {
		panic(err)
	}
	li_element.set_attribute_value('type', 'I')
	li := unsafe { &dom.HTMLLIElement(li_element) }
	mut li_properties := CascadedProperties.new()
	html_li_element_apply_presentational_hints(li, mut li_properties)
	assert html_li_element_is_presentational_hint(li, 'type')
	assert li_properties.property(.list_style_type)?.css_text == 'upper-roman'

	mut ol_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'ol') or {
		panic(err)
	}
	ol_element.set_attribute_value('type', 'A')
	ol := unsafe { &dom.HTMLOListElement(ol_element) }
	mut ol_properties := CascadedProperties.new()
	htmlol_list_element_apply_presentational_hints(ol, mut ol_properties)
	assert htmlol_list_element_is_presentational_hint(ol, 'type')
	assert ol_properties.property(.list_style_type)?.css_text == 'upper-alpha'

	mut br_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'br') or {
		panic(err)
	}
	br_element.set_attribute_value('clear', 'all')
	br := unsafe { &dom.HTMLBRElement(br_element) }
	mut br_properties := CascadedProperties.new()
	htmlbr_element_apply_presentational_hints(br, mut br_properties)
	assert htmlbr_element_is_presentational_hint(br, 'clear')
	assert br_properties.property(.clear)?.css_text == 'both'

	mut embed_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'embed') or {
		panic(err)
	}
	embed_element.set_attribute_value('align', 'middle')
	embed_element.set_attribute_value('hspace', '6')
	embed_element.set_attribute_value('vspace', '7')
	embed := unsafe { &dom.HTMLEmbedElement(embed_element) }
	assert html_embed_element_is_presentational_hint(embed, 'align')
	mut embed_properties := CascadedProperties.new()
	html_embed_element_apply_presentational_hints(embed, mut embed_properties)
	assert embed_properties.property(.text_align)?.css_text == 'middle'
	assert embed_properties.property(.margin_left)?.css_text == '6px'
	assert embed_properties.property(.margin_right)?.css_text == '6px'
	assert embed_properties.property(.margin_top)?.css_text == '7px'
	assert embed_properties.property(.margin_bottom)?.css_text == '7px'

	mut iframe_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'iframe') or {
		panic(err)
	}
	iframe_element.set_attribute_value('frameborder', 'not-an-integer')
	iframe := unsafe { &dom.HTMLIFrameElement(iframe_element) }
	assert html_iframe_element_is_presentational_hint(iframe, 'frameborder')
	mut iframe_properties := CascadedProperties.new()
	html_iframe_element_apply_presentational_hints(iframe, mut iframe_properties)
	assert iframe_properties.property(.border_top_width)?.css_text == '0px'
	assert iframe_properties.property(.border_right_width)?.css_text == '0px'
	assert iframe_properties.property(.border_bottom_width)?.css_text == '0px'
	assert iframe_properties.property(.border_left_width)?.css_text == '0px'

	mut canvas_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'canvas') or {
		panic(err)
	}
	canvas_element.set_attribute_value('width', '320')
	canvas_element.set_attribute_value('height', '200')
	canvas := unsafe { &dom.HTMLCanvasElement(canvas_element) }
	assert html_canvas_element_is_presentational_hint(canvas, 'width')
	mut canvas_properties := CascadedProperties.new()
	html_canvas_element_apply_presentational_hints(canvas, mut canvas_properties)
	assert canvas_properties.property(.aspect_ratio)?.css_text == 'auto 320 / 200'

	mut font_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'font') or {
		panic(err)
	}
	font_element.set_attribute_value('color', 'red')
	font_element.set_attribute_value('face', 'serif')
	font_element.set_attribute_value('size', '+2')
	font := unsafe { &dom.HTMLFontElement(font_element) }
	assert html_font_element_is_presentational_hint(font, 'face')
	mut font_properties := CascadedProperties.new()
	html_font_element_apply_presentational_hints(font, mut font_properties)
	assert font_properties.property(.color)?.css_text == 'red'
	assert font_properties.property(.font_family)?.css_text == 'serif'
	assert font_properties.property(.font_size)?.css_text == 'x-large'

	mut table_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'table') or {
		panic(err)
	}
	table_element.set_attribute_value('align', 'center')
	table_element.set_attribute_value('border', '2')
	table_element.set_attribute_value('cellspacing', '3')
	table := unsafe { &dom.HTMLTableElement(table_element) }
	assert html_table_element_is_presentational_hint(table, 'cellpadding')
	mut table_properties := CascadedProperties.new()
	html_table_element_apply_presentational_hints(table, mut table_properties)
	assert table_properties.property(.margin_left)?.css_text == 'auto'
	assert table_properties.property(.border_left_width)?.css_text == '2px'
	assert table_properties.property(.border_spacing)?.css_text == '3px'
}

fn test_element_presentational_hints_apply_document_link_colors() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_normal_link_color(dom.Color{ r: 0x12, g: 0x34, b: 0x56, a: 0xff })
	document.set_active_link_color(dom.Color{ r: 0xab, g: 0xcd, b: 0xef, a: 0xff })
	document.set_visited_link_color(dom.Color{ r: 0x11, g: 0x22, b: 0x33, a: 0xff })

	mut anchor := document.create_element_ns('http://www.w3.org/1999/xhtml', 'a') or {
		panic('${err}')
	}
	anchor.set_attribute_value('href', 'https://example.com/')
	assert anchor.matches_link_pseudo_class()
	assert !anchor.matches_visited_pseudo_class()

	mut link_properties := CascadedProperties.new()
	apply_html_presentational_hints_to_cascade(mut link_properties, anchor)
	assert link_properties.property(.color)?.css_text == 'rgb(18, 52, 86)'

	anchor.set_being_activated(true)
	mut active_properties := CascadedProperties.new()
	apply_html_presentational_hints_to_cascade(mut active_properties, anchor)
	assert active_properties.property(.color)?.css_text == 'rgb(171, 205, 239)'

	mut div := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	div.set_being_activated(true)
	mut non_link_properties := CascadedProperties.new()
	apply_html_presentational_hints_to_cascade(mut non_link_properties, div)
	assert non_link_properties.property(.color) == none

	mut filtered_hints := []StyleProperty{}
	mut filtered_properties := ComputedInterpolationPropertyIDs{}
	filtered_properties << PropertyID.width
	collect_element_presentational_hints(mut filtered_hints, anchor, filtered_properties)
	assert filtered_hints.len == 0
}

fn test_embed_frame_iframe_and_canvas_adjust_display_contents_to_none() {
	document := dom.Document.create(dom.url_about_blank())
	computer := StyleComputer.new(document)
	for local_name in ['embed', 'iframe', 'canvas', 'frame', 'frameset', 'br'] {
		mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', local_name) or {
			panic(err)
		}
		element.set_attribute_value('style', 'display: contents')
		computed := computer.compute_style(dom.AbstractElement.new(element, none))
		assert computed.display() == Display.from_short(.none_)
	}
}

fn svg_display_contents_test_element(document &dom.Document, local_name string) &dom.Element {
	mut element := document.create_element_ns('http://www.w3.org/2000/svg', local_name) or {
		panic(err)
	}
	element.set_attribute_value('style', 'display: contents; position: relative')
	return element
}

fn test_svg_and_mathml_adjust_display_contents_for_unboxing_rules() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut outer := svg_display_contents_test_element(document, 'svg')
	mut inner := svg_display_contents_test_element(document, 'svg')
	mut anchor := svg_display_contents_test_element(document, 'a')
	mut group := svg_display_contents_test_element(document, 'g')
	mut switch_element := svg_display_contents_test_element(document, 'switch')
	mut text_element := svg_display_contents_test_element(document, 'text')
	mut tspan := svg_display_contents_test_element(document, 'tspan')
	mut text_path := svg_display_contents_test_element(document, 'textPath')
	mut use_element := svg_display_contents_test_element(document, 'use')
	mut defs := svg_display_contents_test_element(document, 'defs')
	mut symbol := svg_display_contents_test_element(document, 'symbol')
	mut foreign_object := svg_display_contents_test_element(document, 'foreignObject')
	mut rect := svg_display_contents_test_element(document, 'rect')
	mut foreign_svg := svg_display_contents_test_element(document, 'svg')

	mut outer_node := outer.as_node()
	outer_node.append_child(inner.as_node()) or { panic(err) }
	mut inner_node := inner.as_node()
	inner_node.append_child(anchor.as_node()) or { panic(err) }
	mut anchor_node := anchor.as_node()
	anchor_node.append_child(group.as_node()) or { panic(err) }
	mut group_node := group.as_node()
	group_node.append_child(switch_element.as_node()) or { panic(err) }
	inner_node.append_child(text_element.as_node()) or { panic(err) }
	mut text_node := text_element.as_node()
	text_node.append_child(tspan.as_node()) or { panic(err) }
	text_node.append_child(text_path.as_node()) or { panic(err) }
	inner_node.append_child(use_element.as_node()) or { panic(err) }
	inner_node.append_child(defs.as_node()) or { panic(err) }
	mut defs_node := defs.as_node()
	defs_node.append_child(symbol.as_node()) or { panic(err) }
	inner_node.append_child(foreign_object.as_node()) or { panic(err) }
	inner_node.append_child(rect.as_node()) or { panic(err) }
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(outer.as_node()) or { panic(err) }

	computer := StyleComputer.new(document)
	assert computer.compute_style(dom.AbstractElement.new(outer, none)).display() == Display.from_short(.none_)
	assert computer.compute_style(dom.AbstractElement.new(inner, none)).display().is_contents()
	assert computer.compute_style(dom.AbstractElement.new(anchor, none)).display().is_contents()
	assert computer.compute_style(dom.AbstractElement.new(group, none)).display().is_contents()
	assert computer.compute_style(dom.AbstractElement.new(switch_element, none)).display().is_contents()
	assert computer.compute_style(dom.AbstractElement.new(text_element, none)).display() == Display.from_short(.none_)
	assert computer.compute_style(dom.AbstractElement.new(tspan, none)).display().is_contents()
	assert computer.compute_style(dom.AbstractElement.new(text_path, none)).display().is_contents()
	assert computer.compute_style(dom.AbstractElement.new(use_element, none)).display().is_contents()
	assert computer.compute_style(dom.AbstractElement.new(defs, none)).display() == Display.from_short(.none_)
	assert computer.compute_style(dom.AbstractElement.new(symbol, none)).display() == Display.from_short(.none_)
	assert computer.compute_style(dom.AbstractElement.new(foreign_object, none)).display() == Display.from_short(.none_)
	assert computer.compute_style(dom.AbstractElement.new(rect, none)).display() == Display.from_short(.none_)
	assert computer.compute_style(dom.AbstractElement.new(group, none)).position() == .static_
	assert computer.compute_style(dom.AbstractElement.new(inner, none)).position() == .static_

	// A nested SVG inside foreignObject establishes CSS box layout again, so it
	// is outermost for SVG purposes even though another SVG is an ancestor.
	mut foreign_object_node := foreign_object.as_node()
	foreign_object_node.append_child(foreign_svg.as_node()) or { panic(err) }
	foreign_style := computer.compute_style(dom.AbstractElement.new(foreign_svg, none))
	assert foreign_style.display() == Display.from_short(.none_)
	assert foreign_style.position() == .relative

	mut mathml_row := document.create_element_ns('http://www.w3.org/1998/Math/MathML', 'mrow') or {
		panic(err)
	}
	mathml_row.set_attribute_value('style', 'display: contents')
	math_style := computer.compute_style(dom.AbstractElement.new(mathml_row, none))
	assert math_style.display() == Display.from_short(.none_)
}

fn test_dimension_attributes_follow_style_computer_source_rules() {
	document := dom.Document.create(dom.url_about_blank())
	mut canvas := document.create_element_ns('http://www.w3.org/1999/xhtml', 'canvas') or {
		panic('${err}')
	}
	canvas.set_attribute_value('width', '320')
	canvas.set_attribute_value('height', '200')
	canvas_computed := StyleComputer.new(document).compute_style(dom.AbstractElement.new(canvas, none))
	assert (canvas_computed.property(.width, .no) or { panic('canvas width missing') }).css_text == 'auto'
	assert (canvas_computed.property(.height, .no) or { panic('canvas height missing') }).css_text == 'auto'
	assert (canvas_computed.property(.aspect_ratio, .no) or {
		panic('canvas aspect ratio missing')
	}).css_text == 'auto 320 / 200'

	mut image_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'img') or {
		panic('${err}')
	}
	image_element.set_attribute_value('width', '100')
	mut selected_source := document.create_element_ns('http://www.w3.org/1999/xhtml', 'source') or {
		panic('${err}')
	}
	selected_source.set_attribute_value('width', '240')
	selected_source.set_attribute_value('height', '120')
	mut image := unsafe { &dom.HTMLImageElement(image_element) }
	image.dimension_attribute_source_ = selected_source
	image_computed := StyleComputer.new(document).compute_style(dom.AbstractElement.new(image_element, none))
	assert (image_computed.property(.width, .no) or { panic('image width missing') }).css_text == '240px'
	assert (image_computed.property(.height, .no) or { panic('image height missing') }).css_text == '120px'
}

fn test_media_element_adjusts_inline_and_contents_display() {
	document := dom.Document.create(dom.url_about_blank())
	computer := StyleComputer.new(document)
	mut video := document.create_element_ns('http://www.w3.org/1999/xhtml', 'video') or {
		panic(err)
	}
	video.set_attribute_value('style', 'display: inline')
	computed_inline := computer.compute_style(dom.AbstractElement.new(video, none))
	assert computed_inline.display() == Display.from_short(.inline_block)
	video.set_attribute_value('style', 'display: contents')
	computed_contents := computer.compute_style(dom.AbstractElement.new(video, none))
	assert computed_contents.display() == Display.from_short(.none_)
}

fn test_invalid_media_group_does_not_override_matching_style_rule() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html_element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut invalid := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	invalid.set_attribute_value('class', 'invalid')
	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_element.as_node()) or { panic('${err}') }
	mut html_node := html_element.as_node()
	html_node.append_child(invalid.as_node()) or { panic('${err}') }
	add_document_author_style_sheet(doc, 'div { display: none } @media ,, { div.invalid { display: block } }')
	mut computer := css_style_computer_for(doc)
	recompute_style_for_subtree(mut computer, html_element.as_node())
	computed := computed_properties_for_element(invalid) or { panic('missing computed style') }
	assert computed.display().is_none()
}

fn test_attribute_mutation_uses_css_invalidation_plan_for_descendant() {
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_browsing_context(&dom.BrowsingContext{})
	mut html := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic('${err}') }
	mut parent := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	mut target := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	target.set_attribute_value('class', 'target')

	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html.as_node()) or { panic('append html failed: ${err}') }
	mut html_node := html.as_node()
	html_node.append_child(parent.as_node()) or { panic('append parent failed: ${err}') }
	mut parent_node := parent.as_node()
	parent_node.append_child(target.as_node()) or { panic('append target failed: ${err}') }

	add_document_author_style_sheet(doc, '.target { color: blue; } .theme .target { color: red; }')
	css_style_computer_for(doc)
	doc.needs_full_style_update = true
	doc.update_style()
	assert computed_value_for(target, .color) or { '' } == 'rgb(0, 0, 255)'

	parent.set_attribute_value('class', 'theme')
	assert doc.element_needs_style_update(target)
	doc.update_style()
	assert computed_value_for(target, .color) or { '' } == 'rgb(255, 0, 0)'
}

fn test_removed_attribute_still_matches_pending_descendant_invalidation() {
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_browsing_context(&dom.BrowsingContext{})
	mut html := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic('${err}') }
	mut parent := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	mut target := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	parent.set_attribute_value('data-theme', '')
	target.set_attribute_value('class', 'target')

	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html.as_node()) or { panic('append html failed: ${err}') }
	mut html_node := html.as_node()
	html_node.append_child(parent.as_node()) or { panic('append parent failed: ${err}') }
	mut parent_node := parent.as_node()
	parent_node.append_child(target.as_node()) or { panic('append target failed: ${err}') }

	add_document_author_style_sheet(doc, '.target { color: blue; } [data-theme] .target { color: red; }')
	css_style_computer_for(doc)
	doc.needs_full_style_update = true
	doc.update_style()
	assert computed_value_for(target, .color) or { '' } == 'rgb(255, 0, 0)'

	parent.remove_attribute('data-theme')
	assert doc.element_needs_style_update(target)
	doc.update_style()
	assert computed_value_for(target, .color) or { '' } == 'rgb(0, 0, 255)'
	assert parent.removed_attribute_names_for_style_invalidation().len == 0
}

fn test_same_parent_move_only_invalidates_moved_root_for_subject_structural_selector() {
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_browsing_context(&dom.BrowsingContext{})
	mut parent := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'main') or { panic('${err}') }
	mut moved := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'section') or {
		panic('${err}')
	}
	mut descendant := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	mut sibling := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'section') or {
		panic('${err}')
	}
	moved.set_attribute_value('class', 'moved')
	mut document_node := unsafe { &dom.Node(doc) }
	document_node.append_child(parent.as_node()) or { panic(err) }
	mut parent_node := parent.as_node()
	parent_node.append_child(moved.as_node()) or { panic(err) }
	mut moved_node := moved.as_node()
	moved_node.append_child(descendant.as_node()) or { panic(err) }
	parent_node.append_child(sibling.as_node()) or { panic(err) }

	add_document_author_style_sheet(doc, '.moved:first-child { color: red }')
	css_style_computer_for(doc)
	doc.needs_full_style_update = true
	doc.update_style()
	assert moved.affected_by_first_child_pseudo_class
	assert !moved.affected_by_structural_pseudo_class_in_non_subject_position
	moved_node.set_needs_style_update_internal(false)
	moved_node.set_entire_subtree_needs_style_update(false)
	mut descendant_node := descendant.as_node()
	descendant_node.set_needs_style_update_internal(false)
	descendant_node.set_entire_subtree_needs_style_update(false)

	moved_node.move_node(mut parent_node, none) or { panic(err) }
	assert moved_node.needs_style_update()
	assert !moved_node.entire_subtree_needs_style_update()
	assert !descendant_node.needs_style_update()
	assert !descendant_node.entire_subtree_needs_style_update()
}

fn test_same_parent_move_invalidates_subtree_for_non_subject_structural_selector() {
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_browsing_context(&dom.BrowsingContext{})
	mut parent := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'main') or { panic('${err}') }
	mut moved := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'section') or {
		panic('${err}')
	}
	mut descendant := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	mut sibling := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'section') or {
		panic('${err}')
	}
	moved.set_attribute_value('class', 'moved')
	descendant.set_attribute_value('class', 'target')
	mut document_node := unsafe { &dom.Node(doc) }
	document_node.append_child(parent.as_node()) or { panic(err) }
	mut parent_node := parent.as_node()
	parent_node.append_child(moved.as_node()) or { panic(err) }
	mut moved_node := moved.as_node()
	moved_node.append_child(descendant.as_node()) or { panic(err) }
	parent_node.append_child(sibling.as_node()) or { panic(err) }

	add_document_author_style_sheet(doc, '.moved:first-child .target { color: red } .lead + .moved .target { color: blue }')
	css_style_computer_for(doc)
	doc.needs_full_style_update = true
	doc.update_style()
	assert moved.affected_by_structural_pseudo_class_in_non_subject_position
	assert moved.affected_by_sibling_combinator_in_non_subject_position
	moved_node.set_needs_style_update_internal(false)
	moved_node.set_entire_subtree_needs_style_update(false)

	moved_node.move_node(mut parent_node, none) or { panic(err) }
	assert moved_node.entire_subtree_needs_style_update()
}

fn test_cross_parent_move_refreshes_inherited_language_and_direction() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{})
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic(err)
	}
	mut old_parent := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	old_parent.set_attribute_value('lang', 'en')
	old_parent.set_attribute_value('dir', 'ltr')
	mut new_parent := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	new_parent.set_attribute_value('lang', 'fr')
	new_parent.set_attribute_value('dir', 'rtl')
	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic(err)
	}
	target.set_attribute_value('class', 'target')
	mut descendant := document.create_element_ns('http://www.w3.org/1999/xhtml', 'b') or {
		panic(err)
	}

	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(old_parent.as_node()) or { panic(err) }
	root_node.append_child(new_parent.as_node()) or { panic(err) }
	mut old_parent_node := old_parent.as_node()
	old_parent_node.append_child(target.as_node()) or { panic(err) }
	mut target_node := target.as_node()
	target_node.append_child(descendant.as_node()) or { panic(err) }

	add_document_author_style_sheet(document, '.target { color: black; background-color: transparent }
		.target:lang(fr) { color: rgb(1, 1, 1) }
		.target:dir(rtl) { background-color: rgb(2, 2, 2) }')
	css_style_computer_for(document)
	document.needs_full_style_update = true
	document.update_style()
	// Populate both inherited-language caches before moving the subtree.
	assert target.lang() or { '' } == 'en'
	assert descendant.lang() or { '' } == 'en'
	assert target.directionality() == .ltr

	mut new_parent_node := new_parent.as_node()
	target_node.move_node(mut new_parent_node, none) or { panic(err) }
	document.update_style()

	assert target.lang() or { '' } == 'fr'
	assert descendant.lang() or { '' } == 'fr'
	assert target.directionality() == .rtl
	assert target.matches(':lang(fr)') or { false }
	assert target.matches(':dir(rtl)') or { false }
	assert computed_value_for(target, .color) or { '' } == 'rgb(1, 1, 1)'
	assert computed_value_for(target, .background_color) or { '' } == 'rgb(2, 2, 2)'
	assert computed_value_for(descendant, .color) or { '' } == 'rgb(1, 1, 1)'
}

fn test_sibling_structural_invalidation_only_marks_subject_root() {
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_browsing_context(&dom.BrowsingContext{})
	mut parent := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'main') or { panic(err) }
	mut item := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'section') or { panic(err) }
	mut descendant := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic(err)
	}
	item.set_attribute_value('class', 'item')
	mut document_node := unsafe { &dom.Node(doc) }
	document_node.append_child(parent.as_node()) or { panic(err) }
	mut parent_node := parent.as_node()
	parent_node.append_child(item.as_node()) or { panic(err) }
	mut item_node := item.as_node()
	item_node.append_child(descendant.as_node()) or { panic(err) }

	add_document_author_style_sheet(doc, '.item:first-child { color: red }')
	css_style_computer_for(doc)
	doc.needs_full_style_update = true
	doc.update_style()
	assert item.affected_by_first_child_pseudo_class
	assert !item.affected_by_structural_pseudo_class_in_non_subject_position
	item_node.set_needs_style_update_internal(false)
	item_node.set_entire_subtree_needs_style_update(false)
	mut descendant_node := descendant.as_node()
	descendant_node.set_needs_style_update_internal(false)
	descendant_node.set_entire_subtree_needs_style_update(false)

	lead := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	parent_node.insert_before(lead.as_node(), item.as_node(), false)
	assert item_node.needs_style_update()
	assert !item_node.entire_subtree_needs_style_update()
	assert !descendant_node.needs_style_update()
	assert !descendant_node.entire_subtree_needs_style_update()
}

fn test_sibling_structural_invalidation_marks_subtree_for_non_subject_selector() {
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_browsing_context(&dom.BrowsingContext{})
	mut parent := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'main') or { panic(err) }
	mut item := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'section') or { panic(err) }
	mut descendant := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic(err)
	}
	item.set_attribute_value('class', 'item')
	descendant.set_attribute_value('class', 'target')
	mut document_node := unsafe { &dom.Node(doc) }
	document_node.append_child(parent.as_node()) or { panic(err) }
	mut parent_node := parent.as_node()
	parent_node.append_child(item.as_node()) or { panic(err) }
	mut item_node := item.as_node()
	item_node.append_child(descendant.as_node()) or { panic(err) }

	add_document_author_style_sheet(doc, '.item:first-child .target { color: red }')
	css_style_computer_for(doc)
	doc.needs_full_style_update = true
	doc.update_style()
	assert item.affected_by_structural_pseudo_class_in_non_subject_position
	item_node.set_entire_subtree_needs_style_update(false)

	lead := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	parent_node.insert_before(lead.as_node(), item.as_node(), false)
	assert item_node.entire_subtree_needs_style_update()
}

fn test_computed_style_records_attempted_pseudo_class_matches() {
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_browsing_context(&dom.BrowsingContext{})
	mut root := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic('${err}') }
	mut item := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	item.set_attribute_value('class', 'item')
	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(root.as_node()) or { panic('append root failed: ${err}') }
	mut root_node := root.as_node()
	root_node.append_child(item.as_node()) or { panic('append item failed: ${err}') }
	add_document_author_style_sheet(doc, '.item:hover { color: red; }')
	css_style_computer_for(doc)
	doc.needs_full_style_update = true
	doc.update_style()
	assert item.affected_by_pseudo_class(.hover)
}

fn test_pseudo_class_bitmap_handles_both_words_and_merge() {
	mut first := PseudoClassBitmap{}
	first.set(.hover, true)
	first.set(.heading, true)
	assert first.get(.hover)
	assert first.get(.heading)
	assert !first.get(.focus)

	mut second := PseudoClassBitmap{}
	second.set(.focus, true)
	first.merge(second)
	assert first.get(.focus)
	first.set(.hover, false)
	assert !first.get(.hover)
}

fn test_typed_view_transition_name_reaches_dom_element_algorithm() {
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_browsing_context(&dom.BrowsingContext{})
	mut root := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic('${err}') }
	mut item := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(root.as_node()) or { panic('append root failed: ${err}') }
	mut root_node := root.as_node()
	root_node.append_child(item.as_node()) or { panic('append item failed: ${err}') }
	add_document_author_style_sheet(doc, 'div { view-transition-name: card; }')
	css_style_computer_for(doc)
	doc.needs_full_style_update = true
	doc.update_style()
	assert item.document_scoped_view_transition_name() or { '' } == 'card'
}

fn test_dynamic_pseudo_class_changes_use_rule_cache_selector_deltas() {
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_browsing_context(&dom.BrowsingContext{})
	mut root := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic('${err}') }
	mut hovered := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'section') or {
		panic('${err}')
	}
	hovered.set_attribute_value('class', 'hovered')
	mut descendant := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	descendant.set_attribute_value('class', 'descendant')
	mut unrelated := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'aside') or {
		panic('${err}')
	}
	unrelated.set_attribute_value('class', 'unrelated')
	mut focus_parent := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	focus_parent.set_attribute_value('class', 'focus-parent')
	mut focus_child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'input') or {
		panic('${err}')
	}
	focus_child.set_attribute_value('class', 'focus-child')
	mut target := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	target.set_attribute_value('class', 'target')

	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(root.as_node()) or { panic('append root failed: ${err}') }
	mut root_node := root.as_node()
	root_node.append_child(hovered.as_node()) or { panic('append hovered failed: ${err}') }
	mut hovered_node := hovered.as_node()
	hovered_node.append_child(descendant.as_node()) or {
		panic('append descendant failed: ${err}')
	}
	root_node.append_child(unrelated.as_node()) or { panic('append unrelated failed: ${err}') }
	root_node.append_child(focus_parent.as_node()) or {
		panic('append focus parent failed: ${err}')
	}
	mut focus_parent_node := focus_parent.as_node()
	focus_parent_node.append_child(focus_child.as_node()) or {
		panic('append focus child failed: ${err}')
	}
	root_node.append_child(target.as_node()) or { panic('append target failed: ${err}') }

	add_document_author_style_sheet(doc, '
		.hovered:hover { color: red; }
		.hovered:hover .descendant { color: blue; }
		.focus-parent:focus-within { background-color: green; }
		.focus-child:focus-visible { color: purple; }
		.target:target { color: orange; }
	')
	css_style_computer_for(doc)
	doc.needs_full_style_update = true
	doc.update_style()

	assert !hovered.needs_style_update()
	assert !descendant.needs_style_update()
	assert !unrelated.needs_style_update()
	doc.set_hovered_node(hovered.as_node())
	assert hovered.needs_style_update()
	assert descendant.needs_style_update()
	assert !unrelated.needs_style_update()
	doc.update_style()
	assert computed_value_for(hovered, .color) or { '' } == 'rgb(255, 0, 0)'
	assert computed_value_for(descendant, .color) or { '' } == 'rgb(0, 0, 255)'

	doc.set_focused_area(focus_child.as_node())
	assert focus_parent.needs_style_update()
	assert focus_child.needs_style_update()
	assert !unrelated.needs_style_update()
	doc.update_style()
	assert computed_value_for(focus_parent, .background_color) or { '' } == 'rgb(0, 128, 0)'
	assert computed_value_for(focus_child, .color) or { '' } == 'rgb(128, 0, 128)'

	doc.set_target_element(target)
	assert target.needs_style_update()
	assert !unrelated.needs_style_update()
	doc.update_style()
	assert computed_value_for(target, .color) or { '' } == 'rgb(255, 165, 0)'
}

fn test_meta_theme_color_uses_css_color_and_media_parsers() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic('${err}') }
	mut invalid := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'meta') or {
		panic('${err}')
	}
	invalid.set_attribute_value('name', 'theme-color')
	invalid.set_attribute_value('content', 'not-a-color')
	mut media_mismatch := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'meta') or {
		panic('${err}')
	}
	media_mismatch.set_attribute_value('name', 'theme-color')
	media_mismatch.set_attribute_value('content', 'red')
	media_mismatch.set_attribute_value('media', '(max-width: 1px)')
	mut valid := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'meta') or {
		panic('${err}')
	}
	valid.set_attribute_value('name', 'THEME-COLOR')
	valid.set_attribute_value('content', ' #0f0 ')

	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html.as_node()) or { panic('append html failed: ${err}') }
	mut html_node := html.as_node()
	html_node.append_child(invalid.as_node()) or { panic('append invalid failed: ${err}') }
	html_node.append_child(media_mismatch.as_node()) or { panic('append media failed: ${err}') }
	html_node.append_child(valid.as_node()) or { panic('append valid failed: ${err}') }
	css_style_computer_for(doc)
	doc.obtain_theme_color()
	assert doc.theme_color() or { '' } == 'rgb(0, 255, 0)'
}

fn test_meta_theme_color_resolves_current_color_against_the_root_element() {
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_browsing_context(&dom.BrowsingContext{})
	mut html := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic('${err}') }
	html.set_attribute_value('style', 'color: rgb(1, 2, 3)')
	mut meta := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'meta') or { panic('${err}') }
	meta.set_attribute_value('name', 'theme-color')
	meta.set_attribute_value('content', 'currentcolor')
	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html.as_node()) or { panic('append html failed: ${err}') }
	mut html_node := html.as_node()
	html_node.append_child(meta.as_node()) or { panic('append meta failed: ${err}') }
	css_style_computer_for(doc)
	color := property_id_from_string('color') or { panic('color id') }
	_ := computed_value_for(html, color) or { panic('no computed color for html') }
	html_node.set_layout_node(&dom.LayoutNode{
		dom_node_: html.as_node()
	})

	doc.obtain_theme_color()
	assert doc.theme_color() or { '' } == 'rgb(1, 2, 3)'
}

// computed_value_for is the real-StyleComputer cascade query (drop-in for the minimal cascaded_value_for):
// a full style pass over the document resolves inline styles + inheritance, read back per element.
fn test_computed_value_for_inline_and_inheritance() {
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_browsing_context(&dom.BrowsingContext{})
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
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

fn test_background_lists_are_coordinated_at_computed_value_time() {
	doc := dom.Document.create(dom.url_about_blank())
	mut target := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	target.set_attribute_value('style', 'font-size: 20px; background-image: none, none; background-repeat: no-repeat; background-position-x: 2em')

	computer := StyleComputer.new(doc)
	computed := computer.compute_style(dom.AbstractElement.new(target, none))
	background_repeat := computed.property(.background_repeat, .no) or {
		panic('no computed background-repeat')
	}
	background_position_x := computed.property(.background_position_x, .no) or {
		panic('no computed background-position-x')
	}

	assert background_repeat.css_text == 'no-repeat, no-repeat'
	assert background_position_x.css_text == '40px, 40px'
}

// With the UA stylesheet wired in, the real StyleComputer applies user-agent display defaults
// (head { display: none }, li { display: list-item }, div { display: block }), not just inline/inheritance.
fn test_ua_default_stylesheet_applies_display() {
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_browsing_context(&dom.BrowsingContext{})
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut head := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'head') or { panic('${err}') }
	mut body := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'body') or { panic('${err}') }
	mut div := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	mut li := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'li') or { panic('${err}') }
	mut span := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or { panic('${err}') }

	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('append html failed: ${err}') }
	mut html_node := html_el.as_node()
	html_node.append_child(head.as_node()) or { panic('append head failed: ${err}') }
	html_node.append_child(body.as_node()) or { panic('append body failed: ${err}') }
	mut body_node := body.as_node()
	body_node.append_child(div.as_node()) or { panic('append div failed: ${err}') }
	body_node.append_child(li.as_node()) or { panic('append li failed: ${err}') }
	body_node.append_child(span.as_node()) or { panic('append span failed: ${err}') }

	display := property_id_from_string('display') or { panic('display id') }
	assert computed_value_for(head, display) or { panic('no head display') } == 'none'
	assert computed_value_for(li, display) or { panic('no li display') } == 'list-item'
	assert computed_value_for(div, display) or { panic('no div display') } == 'block'
	// span has no UA rule; inline is the initial value.
	assert computed_value_for(span, display) or { panic('no span display') } == 'inline'
}

fn test_root_pseudo_class_matches_non_html_document_element() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.xml)
	document.set_browsing_context(&dom.BrowsingContext{})
	mut svg_root := document.create_element_ns('http://www.w3.org/2000/svg', 'svg') or {
		panic('${err}')
	}
	mut nested_html := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(svg_root.as_node()) or { panic('${err}') }
	mut svg_node := svg_root.as_node()
	svg_node.append_child(nested_html.as_node()) or { panic('${err}') }

	assert element_matches_selector(svg_root, ':root')
	assert !element_matches_selector(nested_html, ':root')
	assert computed_value_for(svg_root, .view_transition_name) or { '' } == 'root'
}

fn test_ua_default_stylesheet_keeps_select_labels_on_one_line() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{})
	mut select_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'select') or {
		panic('${err}')
	}
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(select_element.as_node()) or { panic('${err}') }

	assert computed_value_for(select_element, .white_space_collapse) or {
		panic('no select white-space-collapse')
	} == 'preserve'
	assert computed_value_for(select_element, .text_wrap_mode) or {
		panic('no select text-wrap-mode')
	} == 'nowrap'
}

fn test_table_heading_alignment_uses_immediate_parents_computed_value() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{})
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic(err)
	}
	mut body := document.create_element_ns('http://www.w3.org/1999/xhtml', 'body') or {
		panic(err)
	}
	mut start_table := document.create_element_ns('http://www.w3.org/1999/xhtml', 'table') or {
		panic(err)
	}
	start_table.set_attribute_value('style', 'text-align: start')
	mut start_row := document.create_element_ns('http://www.w3.org/1999/xhtml', 'tr') or {
		panic(err)
	}
	start_heading := document.create_element_ns('http://www.w3.org/1999/xhtml', 'th') or {
		panic(err)
	}
	mut end_table := document.create_element_ns('http://www.w3.org/1999/xhtml', 'table') or {
		panic(err)
	}
	end_table.set_attribute_value('style', 'text-align: end')
	mut end_row := document.create_element_ns('http://www.w3.org/1999/xhtml', 'tr') or {
		panic(err)
	}
	end_heading := document.create_element_ns('http://www.w3.org/1999/xhtml', 'th') or {
		panic(err)
	}

	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(body.as_node()) or { panic(err) }
	mut body_node := body.as_node()
	body_node.append_child(start_table.as_node()) or { panic(err) }
	body_node.append_child(end_table.as_node()) or { panic(err) }
	mut start_table_node := start_table.as_node()
	start_table_node.append_child(start_row.as_node()) or { panic(err) }
	mut start_row_node := start_row.as_node()
	start_row_node.append_child(start_heading.as_node()) or { panic(err) }
	mut end_table_node := end_table.as_node()
	end_table_node.append_child(end_row.as_node()) or { panic(err) }
	mut end_row_node := end_row.as_node()
	end_row_node.append_child(end_heading.as_node()) or { panic(err) }

	assert computed_value_for(start_heading, .text_align) or { '' } == 'center'
	assert computed_value_for(end_heading, .text_align) or { '' } == 'end'
}

// The real StyleComputer matches an author stylesheet attached to the document (author cascade origin):
// a `.card { color: navy }` rule applies to a matching element and inherits to its child, distinct from
// an unmatched element's initial color.
fn test_real_pipeline_matches_author_stylesheet() {
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_browsing_context(&dom.BrowsingContext{})
	add_document_author_style_sheet(doc, '.card { color: navy }')

	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut card := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	card.set_attribute_value('class', 'card')
	mut child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'p') or { panic('${err}') }

	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('append html failed: ${err}') }
	mut html_node := html_el.as_node()
	html_node.append_child(card.as_node()) or { panic('append card failed: ${err}') }
	mut card_node := card.as_node()
	card_node.append_child(child.as_node()) or { panic('append child failed: ${err}') }

	color := property_id_from_string('color') or { panic('color id') }
	html_color := computed_value_for(html_el, color) or { panic('no html color') }
	card_color := computed_value_for(card, color) or { panic('no card color') }
	child_color := computed_value_for(child, color) or { panic('no child color') }

	// .card matched the author rule (navy), distinct from html's initial color; child inherits card's navy.
	assert card_color != html_color
	assert child_color == card_color
}

// The dom-side CSSDisplay_ predicates (is_contents/is_inline_outside/is_flow_inside) are now mirrored
// from the real CSS::Display via the bridge, instead of always returning false.
fn test_display_predicates_mirrored_to_dom() {
	doc := dom.Document.create(dom.url_about_blank())
	mut contents_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	contents_el.set_attribute_value('style', 'display: contents')
	s := StyleComputer.new(doc)
	contents_computed := s.compute_style(dom.AbstractElement.new(contents_el, none))
	contents_display := computed_properties_to_dom(contents_computed).display()
	assert contents_display.is_contents()

	mut inline_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	inline_el.set_attribute_value('style', 'display: inline')
	inline_computed := s.compute_style(dom.AbstractElement.new(inline_el, none))
	inline_display := computed_properties_to_dom(inline_computed).display()
	assert inline_display.is_inline_outside()
	assert inline_display.is_flow_inside()
	assert !inline_display.is_contents()
}

fn test_svg_presentation_attributes_participate_at_the_correct_cascade_position() {
	doc := dom.Document.create(dom.url_about_blank())
	mut from_attribute := doc.create_element_ns('http://www.w3.org/2000/svg', 'rect') or {
		panic('${err}')
	}
	from_attribute.set_attribute_value('fill', 'red')
	computer := StyleComputer.new(doc)
	attribute_style := computer.compute_style(dom.AbstractElement.new(from_attribute, none))
	attribute_fill := attribute_style.property(.fill, .yes) or { panic('no computed fill') }
	attribute_color := parse_color_string(attribute_fill.css_text) or {
		panic('fill is not a color')
	}
	assert attribute_color.serialize() == 'rgb(255 0 0)'
	from_attribute.set_attribute_value('stroke-width', '2')
	from_attribute.set_attribute_value('x', '12')
	from_attribute.set_attribute_value('width', '25')
	attribute_style_with_stroke := computer.compute_style(dom.AbstractElement.new(from_attribute, none))
	assert attribute_style_with_stroke.length_percentage_to_px(.stroke_width, 100) or { -1 } == 2
	assert attribute_style_with_stroke.length_percentage_to_px(.x, 100) or { -1 } == 12
	assert attribute_style_with_stroke.length_percentage_to_px(.width, 100) or { -1 } == 25
	from_attribute.set_attribute_value('vector-effect', 'non-scaling-stroke')
	attribute_style_with_vector_effect := computer.compute_style(dom.AbstractElement.new(from_attribute, none))
	assert attribute_style_with_vector_effect.vector_effect() == .non_scaling_stroke

	mut overridden := doc.create_element_ns('http://www.w3.org/2000/svg', 'rect') or {
		panic('${err}')
	}
	overridden.set_attribute_value('fill', 'red')
	overridden.set_attribute_value('vector-effect', 'non-scaling-stroke')
	overridden.set_attribute_value('style', 'fill: blue; vector-effect: none')
	overridden_style := computer.compute_style(dom.AbstractElement.new(overridden, none))
	overridden_fill := overridden_style.property(.fill, .yes) or { panic('no overridden fill') }
	overridden_color := parse_color_string(overridden_fill.css_text) or {
		panic('overridden fill is not a color')
	}
	assert overridden_color.serialize() == 'rgb(0 0 255)'
	assert overridden_style.vector_effect() == .none_
}

fn test_svg_presentation_attribute_names_are_case_sensitive_and_unnamespaced() {
	doc := dom.Document.create(dom.url_about_blank())
	computer := StyleComputer.new(doc)
	mut rect := doc.create_element_ns('http://www.w3.org/2000/svg', 'rect') or {
		panic('${err}')
	}
	rect.set_attribute_value('fill', 'red')
	rect.set_attribute_value('FILL', 'blue')
	rect.set_attribute_value_ns('fill', 'green', 'x', 'urn:test')

	computed := computer.compute_style(dom.AbstractElement.new(rect, none))
	fill := computed.property(.fill, .yes) or { panic('no computed fill') }
	color := parse_color_string(fill.css_text) or { panic('fill is not a color') }
	assert color.serialize() == 'rgb(255 0 0)'

	mut upper_only := doc.create_element_ns('http://www.w3.org/2000/svg', 'rect') or {
		panic('${err}')
	}
	upper_only.set_attribute_value('FILL', 'blue')
	upper_computed := computer.compute_style(dom.AbstractElement.new(upper_only, none))
	upper_fill := upper_computed.property(.fill, .yes) or { panic('no initial fill') }
	upper_color := parse_color_string(upper_fill.css_text) or { panic('initial fill is not a color') }
	assert upper_color.serialize() == 'rgb(0 0 0)'
}

fn test_svg_transform_presentation_attributes_use_the_svg_transform_grammar() {
	doc := dom.Document.create(dom.url_about_blank())
	computer := StyleComputer.new(doc)
	mut rect := doc.create_element_ns('http://www.w3.org/2000/svg', 'rect') or {
		panic('${err}')
	}
	rect.set_attribute_value('transform', 'translate(10 20) rotate(90 5 5)')
	computed := computer.compute_style(dom.AbstractElement.new(rect, none))
	matrix := resolve_computed_transform_2d_matrix(computed, 100, 100) or {
		panic('SVG transform presentation attribute did not compute')
	}
	assert math.abs(matrix[0]) < 0.00001
	assert math.abs(matrix[1] - 1) < 0.00001
	assert math.abs(matrix[2] + 1) < 0.00001
	assert math.abs(matrix[3]) < 0.00001
	assert math.abs(matrix[4] - 20) < 0.00001
	assert math.abs(matrix[5] - 20) < 0.00001

	mut gradient := doc.create_element_ns('http://www.w3.org/2000/svg', 'linearGradient') or {
		panic('${err}')
	}
	gradient.set_attribute_value('transform', 'translate(99 99)')
	gradient.set_attribute_value('gradientTransform', 'translate(3 4)')
	gradient_computed := computer.compute_style(dom.AbstractElement.new(gradient, none))
	gradient_matrix := resolve_computed_transform_2d_matrix(gradient_computed, 100, 100) or {
		panic('gradientTransform presentation attribute did not compute')
	}
	assert gradient_matrix[4] == 3
	assert gradient_matrix[5] == 4
}

fn test_svg_presentational_hint_with_undefined_var_uses_initial_value() {
	doc := dom.Document.create(dom.url_about_blank())
	mut stop := doc.create_element_ns('http://www.w3.org/2000/svg', 'stop') or {
		panic('${err}')
	}
	stop.set_attribute_value('stop-color', 'var(--undefined)')

	computer := StyleComputer.new(doc)
	computed := computer.compute_style(dom.AbstractElement.new(stop, none))
	values := resolve_computed_values_for_document(computed, doc)

	assert values.stop_color() == InitialValues.stop_color()
}

fn test_svg_style_element_disabled_controls_its_sheet() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut svg_root := document.create_element_ns('http://www.w3.org/2000/svg', 'svg') or {
		panic('${err}')
	}
	mut style_element := document.create_element_ns('http://www.w3.org/2000/svg', 'style') or {
		panic('${err}')
	}
	mut target := document.create_element_ns('http://www.w3.org/2000/svg', 'rect') or {
		panic('${err}')
	}
	mut style_node := style_element.as_node()
	style_node.append_child(document.create_text_node('rect { fill: green; }').as_node()) or {
		panic('${err}')
	}
	mut root_node := svg_root.as_node()
	root_node.append_child(style_element.as_node()) or { panic('${err}') }
	root_node.append_child(target.as_node()) or { panic('${err}') }
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(svg_root.as_node()) or { panic('${err}') }
	style := unsafe { &dom.SVGStyleElement(style_element) }

	computer := css_style_computer_for(document)
	sync_document_style_elements(document)
	initial_style := computer.compute_style(dom.AbstractElement.new(target, none))
	initial_fill := initial_style.property(.fill, .yes) or { panic('missing initial fill') }
	assert parse_color_string(initial_fill.css_text)?.serialize() == 'rgb(0 128 0)'
	assert !svg.svg_style_element_disabled(style)
	svg.set_svg_style_element_disabled(style, true)
	assert svg.svg_style_element_disabled(style)
	sync_document_style_elements(document)
	disabled_style := computer.compute_style(dom.AbstractElement.new(target, none))
	disabled_fill := disabled_style.property(.fill, .yes) or { panic('missing disabled fill') }
	assert parse_color_string(disabled_fill.css_text)?.serialize() == 'rgb(0 0 0)'
	svg.set_svg_style_element_disabled(style, false)
	sync_document_style_elements(document)
	enabled_style := computer.compute_style(dom.AbstractElement.new(target, none))
	enabled_fill := enabled_style.property(.fill, .yes) or { panic('missing enabled fill') }
	assert parse_color_string(enabled_fill.css_text)?.serialize() == 'rgb(0 128 0)'
}

fn test_dir_pseudo_class_ua_direction_and_inheritance() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html_element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	html_element.set_attribute_value('dir', 'rtl')
	mut child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_element.as_node()) or { panic('${err}') }
	mut html_node := html_element.as_node()
	html_node.append_child(child.as_node()) or { panic('${err}') }
	mut computer := css_style_computer_for(doc)
	assert html_element.directionality() == .rtl
	assert html_element.matches('[dir]:dir(rtl)') or { false }
	recompute_style_for_subtree(mut computer, html_element.as_node())
	html_computed := computed_properties_for_element(html_element) or { panic('html style') }
	child_computed := computed_properties_for_element(child) or { panic('child style') }
	assert html_computed.direction() == .rtl
	assert child_computed.direction() == .rtl
}

fn css_animation_test_active_document() &dom.Document {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{
		active_document_: document
	})
	document.set_navigable(&dom.Navigable{ active_document_: document })
	return document
}

fn test_document_rendering_update_advances_the_css_default_document_timeline() {
	mut document := css_animation_test_active_document()
	mut computer := css_style_computer_for(document)

	document.update_animations_and_send_events(125.0)
	assert computer.animation_time_ms_ == 125.0
	assert computer.document_timeline_.current_time_ms() or { -1.0 } == 125.0

	// DocumentTimeline becomes monotonically increasing once active.
	document.update_animations_and_send_events(100.0)
	assert computer.animation_time_ms_ == 125.0
	assert computer.document_timeline_.current_time_ms() or { -1.0 } == 125.0

	// Detaching the actual navigable makes the timeline inactive even though
	// the compatibility BrowsingContext still points to this document.
	document.set_navigable(none)
	document.update_animations_and_send_events(150.0)
	assert computer.document_timeline_.current_time_ms() == none
}

fn test_document_rendering_update_dispatches_css_animation_phase_events() {
	mut document := css_animation_test_active_document()
	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(target.as_node()) or { panic(err) }
	observation := &CSSAnimationEventObservation{}
	callback := &dom.CallbackType{
		handle_event: fn [observation] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut mutable_observation := unsafe { &CSSAnimationEventObservation(observation) }
			mutable_observation.names << event.type_name()
			return dom.js_undefined()
		}
	}
	mut event_target := unsafe { &dom.EventTarget(target.as_node()) }
	event_target.set_event_handler_attribute('animationstart', callback)
	event_target.set_event_handler_attribute('animationend', callback)

	mut computer := css_style_computer_for(document)
	abstract_target := dom.AbstractElement.new(target, none)
	mut effect := KeyframeEffect.create()
	effect.set_target(abstract_target)
	effect.set_specified_iteration_duration(100.0)
	effect.set_fill_mode(.forwards)
	mut animation := CSSAnimation.create()
	animation.set_animation_name('fade')
	animation.set_owning_element(abstract_target)
	animation.set_effect(effect)
	animation.set_timeline(computer.document_timeline_)
	animation.play() or { panic(err) }
	computer.css_animation_storage_.set(abstract_target, 'fade', animation)

	document.update_animations_and_send_events(0.0)
	document.update_animations_and_send_events(150.0)
	assert observation.names == ['animationstart', 'animationend']
}

fn test_display_change_cancels_and_restarts_css_defined_animations() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	target.set_attribute_value('style', 'display: block; animation-name: fade; animation-duration: 1s; animation-play-state: running')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(target.as_node()) or { panic(err) }

	mut computer := css_style_computer_for(document)
	mut abstract_target := dom.AbstractElement.new(target, none)
	computer.recompute_style(mut abstract_target)
	mut animation := computer.css_animation_storage_.animation(abstract_target, 'fade') or {
		panic('missing CSS animation')
	}
	assert animation.play_state() == .running

	target.set_attribute_value('style', 'display: none; animation-name: fade; animation-duration: 1s; animation-play-state: running')
	computer.recompute_style(mut abstract_target)
	assert animation.play_state() == .idle

	target.set_attribute_value('style', 'display: block; animation-name: fade; animation-duration: 1s; animation-play-state: running')
	computer.recompute_style(mut abstract_target)
	assert animation.play_state() == .running

	// An animated display:none must not cancel the animation while the
	// underlying display remains non-none.
	mut computed := computed_properties_from_dom(abstract_target.computed_properties() or {
		panic('missing computed style')
	}) or { panic('missing CSS style') }
	none_display := dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.none_))))
	block_display := dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.block))))
	computed.set_animated_property(.display, none_display, .no, .no)
	abstract_target.set_computed_properties(computed_properties_to_dom(computed))
	target.play_or_cancel_animations_after_display_property_change()
	assert animation.play_state() == .running

	// Conversely, an animated non-none value cannot keep the animation alive
	// when the underlying display is none.
	computed.set_property(.display, none_display, .no, .no)
	computed.set_animated_property(.display, block_display, .no, .no)
	abstract_target.set_computed_properties(computed_properties_to_dom(computed))
	target.play_or_cancel_animations_after_display_property_change()
	assert animation.play_state() == .idle
}

fn test_animation_refresh_can_override_base_display_none() {
	mut document := css_animation_test_active_document()
	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	target.set_attribute_value('style', 'display: none')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(target.as_node())!
	mut computer := css_style_computer_for(document)
	document.needs_full_style_update = true
	document.update_style()
	abstract_target := dom.AbstractElement.new(target, none)
	assert is_in_display_none_subtree_ignoring_animations(abstract_target)

	block_value := parse_css_value(ParsingParams{}, 'block', .display) or {
		panic('failed to parse display keyframe')
	}
	mut keyframes := &KeyFrameSet{
		keyframes_by_key: {
			0:      ResolvedKeyFrame{
				properties: {
					PropertyID.display: block_value
				}
			}
			100000: ResolvedKeyFrame{
				properties: {
					PropertyID.display: block_value
				}
			}
		}
	}
	mut effect := KeyframeEffect.create()
	effect.set_target(abstract_target)
	effect.set_specified_iteration_duration(100)
	effect.set_fill_mode(.both)
	effect.set_key_frame_set(keyframes)
	assert keyframe_effect_animates_property(effect, .display)

	mut animation := CSSAnimation.create()
	animation.set_animation_name('show')
	animation.set_owning_element(abstract_target)
	animation.set_effect(effect)
	animation.set_timeline(computer.document_timeline_)
	animation.play()!
	computer.css_animation_storage_.set(abstract_target, 'show', animation)
	computer.set_animation_time_ms(50)
	document.update_animated_style_if_needed()

	dom_computed := abstract_target.computed_properties() or { panic('missing computed style') }
	computed := computed_properties_from_dom(dom_computed) or { panic('missing CSS style') }
	assert (computed.property(.display, .no) or { panic('missing base display') }).css_text == 'none'
	assert (computed.property(.display, .yes) or { panic('missing animated display') }).css_text == 'block'
	assert is_in_display_none_subtree_ignoring_animations(abstract_target)
}

fn test_document_rendering_update_dispatches_css_transition_phase_events() {
	mut document := css_animation_test_active_document()
	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(target.as_node()) or { panic(err) }
	observation := &CSSAnimationEventObservation{}
	callback := &dom.CallbackType{
		handle_event: fn [observation] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut mutable_observation := unsafe { &CSSAnimationEventObservation(observation) }
			mutable_observation.names << event.type_name()
			return dom.js_undefined()
		}
	}
	mut event_target := unsafe { &dom.EventTarget(target.as_node()) }
	for event_name in ['transitionrun', 'transitionstart', 'transitionend'] {
		event_target.set_event_handler_attribute(event_name, callback)
	}

	_ = css_style_computer_for(document)
	abstract_target := dom.AbstractElement.new(target, none)
	start_value := &dom.StyleValue{ css_text: '0' }
	end_value := &dom.StyleValue{ css_text: '1' }
	_ = CSSTransition.start_a_transition(abstract_target, .opacity, 1, 0.0, 0.0, 100.0, start_value, end_value, start_value, 1.0)
	document.update_animations_and_send_events(0.0)
	document.update_animations_and_send_events(150.0)
	assert observation.names == ['transitionrun', 'transitionstart', 'transitionend']
}
