module css

import dom

fn font_family_value_names_family(value StyleValue, family_name string) bool {
	return match value {
		StringStyleValue { equals_ignoring_ascii_case(value.string_value(), family_name) }
		CustomIdentStyleValue { equals_ignoring_ascii_case(value.custom_ident(), family_name) }
		StyleValueList {
			mut found := false
			for item in value.values() {
				if font_family_value_names_family(item, family_name) {
					found = true
					break
				}
			}
			found
		}
		else { false }
	}
}

fn retained_style_needs_font_inputs(style &dom.CSSComputedProperties_, family_name string) bool {
	computed := computed_properties_from_dom(style) or { return false }
	// A different selected family can still depend on an ancestor/root face
	// through ex/ch/lh or their root-relative forms, including nested calc().
	if !computed.font_input_refresh_safe_ { return true }
	// The ancestor's computed font size can itself use face metrics. Include
	// nested em/rem consumers so their retained size-input checks run even
	// when they select another family and have no direct inheritance entry.
	if computed.font_input_depends_on_font_size_ { return true }
	value := computed.property(.font_family, .yes) or { return false }
	typed := style_value_logic_from_dom(.font_family, value) or { return false }
	return font_family_value_names_family(typed, family_name)
}

// FontComputer.cpp:clear_computed_font_cache_for_families. Route font inputs
// through the shadow-including tree and include the owning element whenever a
// retained pseudo style uses the family. Ordinary selector inputs stay intact.
fn mark_font_family_inputs_changed(document &dom.Document, family_name string) {
	mut root_metrics_may_change := false
	if root := document.document_element() {
		if style := root.el_computed_properties() {
			root_metrics_may_change = retained_style_needs_font_inputs(style, family_name)
		}
	}
	document.visit_shadow_including_descendants(fn [family_name, root_metrics_may_change] (node &dom.Node) dom.TraversalDecision {
		element := node.as_element() or { return .@continue }
		mut affected := false
		if style := element.el_computed_properties() {
			// Refresh root scalar contexts even when a different family is
			// selected, so deferred used-value resolution sees the new metrics.
			affected = root_metrics_may_change || retained_style_needs_font_inputs(style, family_name)
		}
		for index in 0 .. int(dom.PseudoElement.known_pseudo_element_count) {
			if affected { break }
			if style := element.computed_properties_for_pseudo(index) {
				affected = root_metrics_may_change || retained_style_needs_font_inputs(style, family_name)
			}
		}
		if affected {
			mut mutable_element := unsafe { &dom.Element(element) }
			mutable_element.set_pending_font_input_update(true)
		}
		return .@continue
	})
	if root_metrics_may_change { return }
	// A changed ancestor size also reaches ordinary inherited values and
	// inherited pseudo styles with no explicit length dependency. Mark after
	// the first pass so flat-tree inheritance works across slot/tree order.
	document.for_each_shadow_including_descendant(fn (node &dom.Node) dom.TraversalDecision {
		element := node.as_element() or { return .@continue }
		if element.has_pending_font_input_update() || element.el_computed_properties() == none {
			return .@continue
		}
		mut ancestor := element.element_to_inherit_style_from(none)
		for ancestor != none {
			current := ancestor or { break }
			if current.has_pending_font_input_update() {
				mut mutable_element := unsafe { &dom.Element(element) }
				mutable_element.set_pending_font_input_update(true)
				break
			}
			ancestor = current.element_to_inherit_style_from(none)
		}
		return .@continue
	})
}

fn (s &StyleComputer) can_refresh_font_inputs(abstract_element dom.AbstractElement) bool {
	bridge := abstract_element.computed_properties() or { return false }
	computed := computed_properties_from_dom(bridge) or { return false }
	if !computed.font_input_refresh_safe_ || computed.has_animated_properties()
		|| computed.has_animated_custom_properties() {
		return false
	}
	// A font-metric-relative font size on an ancestor can change after loading
	// its face. Keep em/rem results only while both size inputs stay identical.
	if computed.root_font_size_px_ != s.root_element_font_metrics.font_size.to_double()
		|| style_value_option_changed(computed.font_input_parent_font_size_,
			StyleComputer.get_non_animated_inherit_value(.font_size, abstract_element)) {
		return false
	}
	if abstract_element.pseudo_element() == none {
		if root := abstract_element.document().document_element() {
			if voidptr(root) == voidptr(abstract_element.element()) {
				if value := computed.raw_cascaded_font_size() {
					// The root's initial font context also governs nested calc()
					// font-size leaves, which have no direct inheritance entry.
					length := computed_interpolation_length_from_dom_style_value(value) or { return false }
					if !length.is_absolute() { return false }
				}
			}
		}
	}
	if computed.inheritance_specified_storage_ != unsafe { nil } {
		for _, value in computed.inheritance_specified_storage_.values {
			length := computed_interpolation_length_from_dom_style_value(value) or { return false }
			if length.unit() !in [.em, .rem] { return false }
		}
	}
	if s.css_animation_storage_ != unsafe { nil } {
		for entry in s.css_animation_storage_.entries {
			if abstract_elements_equal(entry.abstract_element, abstract_element) { return false }
		}
	}
	if s.css_transition_storage_ != unsafe { nil }
		&& abstract_element_storage_key(abstract_element) in s.css_transition_storage_.associated_transitions {
		return false
	}
	// Reusing the object is safe only when its inherited property values also
	// remain unchanged. A changed inherited value can start a transition and
	// therefore retains the normal cascade/transition publication path.
	for id in computed_interpolation_longhand_property_ids() {
		if computed.is_property_inherited(id)
			&& style_value_option_changed(computed.property(id, .no),
				StyleComputer.get_non_animated_inherit_value(id, abstract_element)) {
			return false
		}
	}
	return true
}

fn (s &StyleComputer) refresh_font_inputs(abstract_element dom.AbstractElement) RequiredInvalidationAfterStyleChange {
	bridge := abstract_element.computed_properties() or { return RequiredInvalidationAfterStyleChange{} }
	owner := computed_properties_from_dom(bridge) or { return RequiredInvalidationAfterStyleChange{} }
	mut computed := unsafe { &ComputedProperties(owner) }
	old_font_list := computed.cached_computed_font_list()
	old_root_font_size := computed.root_font_size_px_
	old_root_line_height := computed.root_line_height_px_
	old_line_height := if computed.computed_values_resolved_ {
		computed.computed_values_line_height_
	} else {
		computed.line_height()
	}
	computed.clear_computed_font_list_cache()
	computed.cached_length_metrics_ = unsafe { nil }
	new_font_list := computed.computed_font_list(s.font_computer())
	computed.cached_first_available_computed_font_ = computed.first_available_computed_font(s.font_computer())
	computed.computed_values_line_height_ = computed.line_height()
	if abstract_element.pseudo_element() == none && abstract_element.element().is_html_element()
		&& abstract_element.element().local_name().to_lower() == 'html' {
		if root := abstract_element.document().document_element() {
			if voidptr(root) == voidptr(abstract_element.element()) {
				mut mutable_s := unsafe { &StyleComputer(s) }
				mutable_s.root_element_font_metrics = s.calculate_root_element_font_metrics(computed)
				mutable_s.root_element_font_metrics_depend_on_viewport_metrics = computed.font_metrics_depend_on_viewport_metrics()
			}
		}
	}
	computed.root_font_size_px_ = s.root_element_font_metrics.font_size.to_double()
	computed.root_line_height_px_ = s.root_element_font_metrics.line_height.to_double()
	computed.root_font_metrics_depend_on_viewport_metrics_ = s.root_element_font_metrics_depend_on_viewport_metrics
	mut invalidation := RequiredInvalidationAfterStyleChange{}
	same_font := if previous := old_font_list { previous.equals(new_font_list) } else { false }
	if !same_font || old_line_height != computed.line_height()
		|| old_root_font_size != computed.root_font_size_px_
		|| old_root_line_height != computed.root_line_height_px_ {
		invalidation.ensure_at_least(.relayout)
		// Raw computed properties did not change, so the DOM mirror remains
		// valid. Apply its retained owner to refresh font metrics and anonymous
		// layout wrappers without allocating a replacement CSS property table.
		if layout_node := abstract_element.unsafe_layout_node() {
			layout_node.apply_style(bridge)
		}
	}
	return invalidation
}

fn (s &StyleComputer) try_refresh_font_inputs(element &dom.Element) ?RequiredInvalidationAfterStyleChange {
	subject := dom.AbstractElement.new(element, none)
	if !s.can_refresh_font_inputs(subject) { return none }
	for index in 0 .. int(dom.PseudoElement.known_pseudo_element_count) {
		if _ := element.computed_properties_for_pseudo(index) {
			pseudo := unsafe { dom.PseudoElement(index) }
			if !s.can_refresh_font_inputs(dom.AbstractElement.new(element, pseudo)) { return none }
		}
	}
	mut document := unsafe { &dom.Document(element.document()) }
	document.record_element_inherited_style_recomputation()
	mut invalidation := s.refresh_font_inputs(subject)
	for index in 0 .. int(dom.PseudoElement.known_pseudo_element_count) {
		if _ := element.computed_properties_for_pseudo(index) {
			pseudo := unsafe { dom.PseudoElement(index) }
			invalidation = required_invalidation_after_style_change_or(invalidation,
				s.refresh_font_inputs(dom.AbstractElement.new(element, pseudo)))
		}
	}
	if invalidation.is_none() { document.record_element_inherited_style_noop_recomputation() }
	s.clear_computation_context_caches()
	return invalidation
}
