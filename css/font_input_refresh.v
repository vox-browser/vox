module css

import dom
import os

const disable_font_refresh_cascade_reuse = os.getenv('VOX_DISABLE_FONT_REFRESH_CASCADE_REUSE') != ''
const font_refresh_cascade_diagnostics = os.getenv('VOX_FONT_REFRESH_CASCADE_DIAGNOSTICS') != ''
const disable_live_pending_font_refresh = os.getenv('VOX_DISABLE_LIVE_PENDING_FONT_REFRESH') != ''
const live_pending_font_refresh_diagnostics = os.getenv('VOX_LIVE_PENDING_FONT_REFRESH_DIAGNOSTICS') != ''

__global live_pending_font_refresh_reported bool

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
	return retained_style_needs_changed_font_inputs(style, family_name, unsafe { nil })
}

fn retained_style_needs_changed_font_inputs(style &dom.CSSComputedProperties_, family_name string,
	changed_face &FontFaceObject) bool {
	computed := computed_properties_from_dom(style) or { return false }
	// A different selected family can still depend on an ancestor/root face
	// through ex/ch/lh or their root-relative forms, including nested calc().
	if !computed.font_input_refresh_safe_ { return true }
	// The ancestor's computed font size can itself use face metrics. Include
	// nested em/rem consumers so their retained size-input checks run even
	// when they select another family and have no direct inheritance entry.
	// For a known face completion, root metrics and the inheritance fanout
	// below reach these consumers from the actual affected ancestor instead.
	if changed_face == unsafe { nil } && computed.font_input_depends_on_font_size_ { return true }
	// Completion changes an already registered face's availability, rather
	// than matching descriptors or family order. A retained cascade records
	// precisely which pending faces its selected weight/stretch can use.
	if changed_face != unsafe { nil } {
		// Metric queries can resolve the replacement cascade before this fanout
		// reaches the style. Its geometry still belongs to the refresh snapshot
		// until refresh_font_inputs applies the required layout invalidation.
		if computed.font_input_refresh_snapshot_ != unsafe { nil }
			&& computed.font_input_refresh_snapshot_.depends_on_pending_face(changed_face) {
			return true
		}
		if list := computed.cached_computed_font_list() {
			return list.depends_on_pending_face(changed_face)
		}
	}
	value := computed.property(.font_family, .yes) or { return false }
	typed := style_value_logic_from_dom(.font_family, value) or { return false }
	return font_family_value_names_family(typed, family_name)
}

// FontComputer.cpp:clear_computed_font_cache_for_families. Route font inputs
// through the shadow-including tree and include the owning element whenever a
// retained pseudo style uses the family. Ordinary selector inputs stay intact.
fn mark_font_family_inputs_changed(document &dom.Document, family_name string) {
	mark_changed_font_inputs(document, family_name, unsafe { nil })
}

fn mark_changed_font_inputs(document &dom.Document, family_name string, changed_face &FontFaceObject) {
	mut root_metrics_may_change := false
	if root := document.document_element() {
		if style := root.el_computed_properties() {
			root_metrics_may_change = retained_style_needs_changed_font_inputs(style, family_name, changed_face)
		}
	}
	document.visit_shadow_including_descendants(fn [family_name, changed_face, root_metrics_may_change] (node &dom.Node) dom.TraversalDecision {
		element := node.as_element() or { return .@continue }
		mut affected := false
		if style := element.el_computed_properties() {
			// Refresh root scalar contexts even when a different family is
			// selected, so deferred used-value resolution sees the new metrics.
			affected = root_metrics_may_change || retained_style_needs_changed_font_inputs(style, family_name, changed_face)
		}
		for index in 0 .. int(dom.PseudoElement.known_pseudo_element_count) {
			if affected { break }
			if style := element.computed_properties_for_pseudo(index) {
				affected = root_metrics_may_change || retained_style_needs_changed_font_inputs(style, family_name, changed_face)
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
	bridge := abstract_element.computed_properties() or { return diagnostic_font_guard_reject(0) }
	computed := computed_properties_from_dom(bridge) or { return diagnostic_font_guard_reject(1) }
	if !computed.font_input_refresh_safe_ || computed.has_animated_properties()
		|| computed.has_animated_custom_properties() {
		return diagnostic_font_guard_reject(2)
	}
	// A font-metric-relative font size on an ancestor can change after loading
	// its face. Keep em/rem results only while both size inputs stay identical.
	if computed.root_font_size_px_ != s.root_element_font_metrics.font_size.to_double() {
		return diagnostic_font_guard_reject(3)
	}
	parent := if retain_font_refresh_parent_lookups { ?&ComputedProperties(none) }
		else { parent_computed_properties(abstract_element) }
	if style_value_option_changed(computed.font_input_parent_font_size_,
		font_refresh_parent_value(.font_size, abstract_element, parent)) {
		return diagnostic_font_guard_reject(3)
	}
	if abstract_element.pseudo_element() == none {
		if root := abstract_element.document().document_element() {
			if voidptr(root) == voidptr(abstract_element.element()) {
				if value := computed.raw_cascaded_font_size() {
					// The root's initial font context also governs nested calc()
					// font-size leaves, which have no direct inheritance entry.
					// Absolute-size keywords use the document's size table and do
					// not acquire a new size when an author face finishes loading.
					typed := style_value_logic_from_dom(.font_size, value) or { return diagnostic_font_guard_reject(4) }
					if computed_interpolation_keyword_to_absolute_size(typed.to_keyword()) == none {
						length := computed_interpolation_length_from_dom_style_value(value) or { return diagnostic_font_guard_reject(4) }
						if !length.is_absolute() { return diagnostic_font_guard_reject(5) }
					}
				}
			}
		}
	}
	if computed.inheritance_specified_storage_ != unsafe { nil } {
		for _, value in computed.inheritance_specified_storage_.values {
			length := computed_interpolation_length_from_dom_style_value(value) or { return diagnostic_font_guard_reject(6) }
			if length.unit() !in [.em, .rem] { return diagnostic_font_guard_reject(7) }
		}
	}
	if s.css_animation_storage_ != unsafe { nil } {
		for entry in s.css_animation_storage_.entries {
			if abstract_elements_equal(entry.abstract_element, abstract_element) { return diagnostic_font_guard_reject(8) }
		}
	}
	if s.css_transition_storage_ != unsafe { nil }
		&& abstract_element_storage_key(abstract_element) in s.css_transition_storage_.associated_transitions {
		return diagnostic_font_guard_reject(9)
	}
	// Reusing the object is safe only when its inherited property values also
	// remain unchanged. A changed inherited value can start a transition and
	// therefore retains the normal cascade/transition publication path.
	for id in computed.inherited_property_iterator() {
		if style_value_option_changed(computed.property(id, .no),
				font_refresh_parent_value(id, abstract_element, parent)) {
			return diagnostic_font_guard_reject(10)
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
	// The refresh guard has already proved that the computed font inputs are
	// unchanged. Let the FontComputer expire a selected face's cascade; a root
	// metric refresh can also visit styles whose original cascade is still live.
	if disable_font_refresh_cascade_reuse { computed.clear_computed_font_list_cache() }
	new_font_list := computed.computed_font_list(s.font_computer())
	if font_refresh_cascade_diagnostics {
		if previous := old_font_list {
			if voidptr(previous) == voidptr(new_font_list) {
				eprintln('Vox font refresh: retained original live cascade')
			}
		}
	}
	computed.cached_first_available_computed_font_ = computed.first_available_computed_font(s.font_computer())
	computed.computed_values_line_height_ = computed.line_height()
	if abstract_element.pseudo_element() == none && abstract_element.element().is_document_element() {
		mut mutable_s := unsafe { &StyleComputer(s) }
		mutable_s.root_element_font_metrics = s.calculate_root_element_font_metrics(computed)
		mutable_s.root_element_font_metrics_depend_on_viewport_metrics = computed.font_metrics_depend_on_viewport_metrics()
	}
	computed.root_font_size_px_ = s.root_element_font_metrics.font_size.to_double()
	computed.root_line_height_px_ = s.root_element_font_metrics.line_height.to_double()
	computed.root_font_metrics_depend_on_viewport_metrics_ = s.root_element_font_metrics_depend_on_viewport_metrics
	mut invalidation := RequiredInvalidationAfterStyleChange{}
	same_font := if previous := old_font_list {
		original := if computed.font_input_refresh_snapshot_ != unsafe { nil } {
			computed.font_input_refresh_snapshot_
		} else { previous }
		// Pending lists cannot be compared by value: their selected faces can
		// change fallback visibility as well as metrics. Identity is sufficient
		// only while the font computer still owns this exact live snapshot.
		retained_pending := !disable_live_pending_font_refresh
			&& original.pending_faces.len > 0
			&& voidptr(original) == voidptr(new_font_list)
			&& s.font_computer().cached_cascade_is_current(original)
		if retained_pending && live_pending_font_refresh_diagnostics
			&& !live_pending_font_refresh_reported {
			live_pending_font_refresh_reported = true
			eprintln('Vox font refresh: original live pending cascade keeps geometry')
		}
		retained_pending || original.equals(new_font_list)
	} else { false }
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
	computed.font_input_refresh_snapshot_ = new_font_list
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
