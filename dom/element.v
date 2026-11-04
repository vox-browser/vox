// Copyright (c) 2018-2024, Andreas Kling <andreas@ladybird.org>
// Copyright (c) 2022-2023, Sam Atkins <atkinssj@serenityos.org>
// Copyright (c) 2025, Simon Farre <simon.farre.cx@gmail.com>
//
// SPDX-License-Identifier: BSD-2-Clause
//
// Translated from Libraries/LibWeb/DOM/Element.cpp
module dom

import rand
import math
import strings
import webidl
import platform

// --- Types needed by Element that are NOT already in document.v ---
pub struct QualifiedName {
pub mut:
	local_name            string
	prefix_               ?string
	namespace_            ?string
	lowercased_local_name string
}

pub fn (q &QualifiedName) as_string() string {
	if p := q.prefix_ {
		return '${p}:${q.local_name}'
	}
	return q.local_name
}

pub struct NamedNodeMap {
pub mut:
	attrs   []&Attr_
	element &Element = unsafe { nil }
}

pub fn (n &NamedNodeMap) length() int {
	return n.attrs.len
}

pub fn (n &NamedNodeMap) item(index int) ?&Attr_ {
	if index < 0 || index >= n.attrs.len {
		return none
	}
	return n.attrs[index]
}

pub fn (n &NamedNodeMap) is_empty() bool {
	return n.attrs.len == 0
}

fn (n &NamedNodeMap) should_lowercase_attribute_names() bool {
	return n.element != unsafe { nil } && n.element.is_html_element() && n.element.document().is_html_document()
}

fn (n &NamedNodeMap) effective_attribute_name(qualified_name string) string {
	if n.should_lowercase_attribute_names() {
		return to_ascii_lowercase(qualified_name)
	}
	return qualified_name
}

fn normalize_attribute_namespace(namespace_ ?string) ?string {
	if namespace_ or { '' } == '' {
		return none
	}
	return namespace_
}

fn (n &NamedNodeMap) attribute_index_by_name(qualified_name string) ?int {
	effective_qualified_name := n.effective_attribute_name(qualified_name)
	for index, attribute in n.attrs {
		if attribute.name_ == effective_qualified_name {
			return index
		}
	}
	return none
}

fn (n &NamedNodeMap) attribute_index_by_namespace(namespace_ ?string, local_name string) ?int {
	normalized_namespace := normalize_attribute_namespace(namespace_)
	for index, attribute in n.attrs {
		if option_string_equal(attribute.namespace_uri_, normalized_namespace) && attribute.local_name_ == local_name {
			return index
		}
	}
	return none
}

pub fn (n &NamedNodeMap) get_attribute(name string) ?&Attr_ {
	index := n.attribute_index_by_name(name) or { return none }
	return n.attrs[index]
}

pub fn (n &NamedNodeMap) get_attribute_ns(namespace_ ?string, local_name string) ?&Attr_ {
	index := n.attribute_index_by_namespace(namespace_, local_name) or { return none }
	return n.attrs[index]
}

pub fn (mut n NamedNodeMap) append_attribute(attr &Attr_) {
	n.attrs << attr
	if n.element != unsafe { nil } {
		mut mutable_attr := unsafe { &Attr_(attr) }
		mutable_attr.owner_element_ = n.element
		mutable_attr.handle_attribute_changes(n.element, none, attr.value_)
	}
}

pub fn (mut n NamedNodeMap) remove_attribute(name string) {
	index := n.attribute_index_by_name(name) or { return }
	n.remove_attribute_at_index(index)
}

pub fn (mut n NamedNodeMap) remove_attribute_node(attr &Attr_) {
	for index, existing in n.attrs {
		if existing == attr {
			n.remove_attribute_at_index(index)
			return
		}
	}
}

// Attr_ is the lightweight Element-owned attribute record; Attr is the node-backed DOM object.
@[heap]
pub struct Attr_ {
pub mut:
	name_          string
	value_         string
	local_name_    string
	prefix__       ?string
	namespace_uri_ ?string
	owner_element_ ?&Element
}

pub fn (a &Attr_) name() string {
	return a.name_
}

pub fn (a &Attr_) value() string {
	return a.value_
}

pub fn (a &Attr_) local_name() string {
	return a.local_name_
}

pub fn (a &Attr_) prefix() ?string {
	return a.prefix__
}

pub fn (a &Attr_) namespace_uri() ?string {
	return a.namespace_uri_
}

pub fn (a &Attr_) owner_element() ?&Element {
	return a.owner_element_
}

pub fn (mut a Attr_) set_owner_element(element ?&Element) {
	a.owner_element_ = element
}

pub fn (a &Attr_) handle_attribute_changes(element &Element, old_value ?string, new_value ?string) {
	if element.document() != unsafe { nil } {
		mut owner := unsafe { &Document(element.document()) }
		owner.bump_attribute_version()
	}
	if new_value != none && element.document() != unsafe { nil } {
		mut owner := unsafe { &Document(element.document()) }
		owner.note_element_attribute_name(element.local_name(), a.local_name_)
	}
	if element.document() != unsafe { nil } {
		element.document().notify_editing_history_dom_mutation()
	}
	mut element_node := unsafe { &Node(element) }
	element_node.queue_mutation_record(.attributes, a.local_name_, a.namespace_uri_, old_value, []&Node{}, []&Node{}, unsafe { nil }, unsafe { nil })

	mut mutable_element := unsafe { &Element(element) }
	if element.is_custom() {
		mutable_element.enqueue_a_custom_element_callback_reaction('attributeChangedCallback', [
			a.local_name_,
			old_value or { '' },
			new_value or { '' },
			a.namespace_uri_ or { '' },
		])
	}
	mutable_element.run_attribute_change_steps(a.local_name_, old_value, new_value, a.namespace_uri_)
}

pub struct ShadowRootInit {
pub mut:
	mode                    ShadowRootMode
	delegates_focus         bool
	slot_assignment         SlotAssignmentMode = .named
	clonable                bool
	serializable            bool
	custom_element_registry ?voidptr
}

pub enum ShadowRootMode {
	open
	closed
}

pub enum SlotAssignmentMode {
	named
	manual
}

pub struct GetHTMLOptions {
pub mut:
	serializable_shadow_roots bool
}

pub enum TokenizedFeatureNoOpener {
	no
	yes
}

pub type TaskID = int

pub enum TaskSource {
	dom_manipulation
	user_interaction
	networking
}

pub struct PointerLockOptions {}

// https://w3c.github.io/csswg-drafts/cssom-view-1/#dictdef-scrollintoviewoptions
pub struct ScrollIntoViewOptions {
pub mut:
	block    ScrollLogicalPosition = .start
	inline_  ScrollLogicalPosition = .nearest
	behavior ScrollBehavior = .auto_
	container ScrollIntoViewContainer = .all
}

pub enum ScrollIntoViewContainer {
	all
	nearest
}

pub type ScrollIntoViewArgument = bool | ScrollIntoViewOptions

pub enum ScrollLogicalPosition {
	start
	center
	end_
	nearest
}

pub struct ScrollToOptions_ {
pub:
	left ?f64
	top ?f64
	behavior ScrollBehavior = .auto_
}

pub enum ScrollBehavior {
	auto_
	smooth
	instant
}

// https://drafts.csswg.org/cssom-view-1/#dictdef-checkvisibilityoptions
pub struct CheckVisibilityOptions {
pub mut:
	check_opacity           bool
	check_visibility_css    bool
	content_visibility_auto bool
	opacity_property        bool
	visibility_property     bool
}

// https://html.spec.whatwg.org/multipage/custom-elements.html#upgrade-reaction
pub struct CustomElementUpgradeReaction {
pub mut:
	custom_element_definition &CustomElementDefinition = unsafe { nil }
}

// https://html.spec.whatwg.org/multipage/custom-elements.html#callback-reaction
pub struct CustomElementCallbackReaction {
pub mut:
	callback  voidptr
	arguments []string
}

// https://dom.spec.whatwg.org/#concept-element-custom-element-state
pub enum CustomElementState {
	undefined_
	failed
	uncustomized
	precustomized
	custom
}

// https://drafts.csswg.org/css-contain/#proximity-to-the-viewport
pub enum ProximityToTheViewport {
	close_to_the_viewport
	far_away_from_the_viewport
	not_determined
}

pub type CustomElementExceptionReporter = fn (string)

@[heap]
pub struct CustomElementDefinition {
pub mut:
	disable_shadow_      bool
	disable_internals_   bool
	form_associated_     bool
	construction_stack   []&Element
	name_                string
	local_name_          string
	observed_attributes  []string
	constructor_id_      u64
	lifecycle_callbacks_ []string
	exception_reporter_  ?CustomElementExceptionReporter
}

pub fn CustomElementDefinition.create(name string, local_name string, observed_attributes []string, form_associated bool, disable_internals bool, disable_shadow bool) &CustomElementDefinition {
	return &CustomElementDefinition{
		name_: name
		local_name_: local_name
		observed_attributes: observed_attributes.clone()
		form_associated_: form_associated
		disable_internals_: disable_internals
		disable_shadow_: disable_shadow
	}
}

pub fn (d &CustomElementDefinition) disable_shadow() bool {
	return d.disable_shadow_
}

pub fn (d &CustomElementDefinition) disable_internals() bool {
	return d.disable_internals_
}

pub fn (d &CustomElementDefinition) name() string {
	return d.name_
}

pub fn (d &CustomElementDefinition) local_name() string {
	if d.local_name_.len == 0 {
		return d.name_
	}
	return d.local_name_
}

pub fn (d &CustomElementDefinition) form_associated() bool {
	return d.form_associated_
}

pub fn (d &CustomElementDefinition) constructor() u64 {
	return d.constructor_id_
}

pub fn (d &CustomElementDefinition) observed_attributes() []string {
	return d.observed_attributes.clone()
}

pub fn (d &CustomElementDefinition) lifecycle_callbacks() []string {
	return d.lifecycle_callbacks_.clone()
}

pub fn (d &CustomElementDefinition) report_constructor_exception(message string) {
	reporter := d.exception_reporter_ or { return }
	reporter(message)
}

pub fn (d &CustomElementDefinition) construction_stack() []&Element {
	return d.construction_stack.clone()
}

@[heap]
pub struct CustomStateSet {
mut:
	element_            ?&Element
	entries_            map[string]bool
	modification_count_ u64
}

pub fn CustomStateSet.create(element &Element) &CustomStateSet {
	return &CustomStateSet{
		element_: element
		entries_: map[string]bool{}
	}
}

pub fn (states &CustomStateSet) has_state(state string) bool {
	return states.entries_[state]
}

pub fn (states &CustomStateSet) size() int {
	return states.entries_.len
}

pub fn (states &CustomStateSet) set_size() int {
	return states.size()
}

pub fn (states &CustomStateSet) values() []string {
	mut values := states.entries_.keys()
	values.sort()
	return values
}

pub fn (states &CustomStateSet) states() []string {
	return states.values()
}

pub fn (states &CustomStateSet) element() ?&Element {
	return states.element_
}

pub fn (states &CustomStateSet) set_entries() map[string]bool {
	return states.entries_.clone()
}

pub fn (states &CustomStateSet) modification_count() u64 {
	return states.modification_count_
}

fn (mut states CustomStateSet) did_modify() {
	states.modification_count_++
	if element := states.element_ {
		mut node := unsafe { &Node(element) }
		node.invalidate_style(.custom_state_set_change)
	}
}

pub fn (mut states CustomStateSet) on_set_modified_from_js() {
	states.did_modify()
}

pub fn (mut states CustomStateSet) add(state string) ! {
	if states.entries_[state] {
		return
	}
	states.entries_[state] = true
	states.did_modify()
}

pub fn (mut states CustomStateSet) add_state(state string) {
	states.add(state) or { return }
}

pub fn (mut states CustomStateSet) delete(state string) bool {
	if !states.entries_[state] {
		return false
	}
	states.entries_.delete(state)
	states.did_modify()
	return true
}

pub fn (mut states CustomStateSet) remove_state(state string) bool {
	return states.delete(state)
}

pub fn (mut states CustomStateSet) clear() {
	if states.entries_.len == 0 {
		return
	}
	states.entries_.clear()
	states.did_modify()
}

pub fn (mut states CustomStateSet) clear_states() {
	states.clear()
}

@[heap]
pub struct CSSStyleProperties_ {
pub mut:
	is_updating_       bool
	associated_element ?&Element
	// DOM owns the element while CSS owns the typed CSSStyleProperties. Keep the
	// same live declaration object across cascades and attribute mutations without
	// introducing a dom -> css import cycle.
	css_handle                voidptr = unsafe { nil }
	set_declarations_callback fn (voidptr, string) = unsafe { nil }
	prefetch_resources_target voidptr = unsafe { nil }
	prefetch_resources        fn (voidptr, &Document) = unsafe { nil }
}

pub fn (c &CSSStyleProperties_) is_updating() bool {
	return c.is_updating_
}

pub fn (mut c CSSStyleProperties_) set_declarations_from_text(text string) {
	if c.css_handle != unsafe { nil } && c.set_declarations_callback != unsafe { nil } {
		c.set_declarations_callback(c.css_handle, text)
	}
}

fn create_element_inline_style(element &Element) &CSSStyleProperties_ {
	return &CSSStyleProperties_{
		associated_element: element
	}
}

@[heap]
pub struct CSSComputedProperties_ {
pub mut:
	display_                        CSSDisplay_ = CSSDisplay_{}
	non_animated_display_is_none_   bool
	overflow_x_                     CSSOverflow_ = .visible
	overflow_y_                     CSSOverflow_ = .visible
	content_visibility_             CSSContentVisibility_ = .visible
	opacity_                        f32 = 1.0
	visibility_                     CSSVisibility_ = .visible
	font_weight_                    f64 = 400
	scroll_behavior_                ScrollBehavior = .auto_
	scroll_snap_strictness_none_ bool = true
	client_border_top_width_        f64
	client_border_left_width_       f64
	math_depth_                     int
	math_style_                     CSSMathStyle_ = .normal
	color_scheme_only_              bool
	has_casing_text_transform_      bool
	attempted_pseudo_class_matches_ u8
	// dom<->css bridge: opaque handle to the real css.ComputedProperties this placeholder mirrors.
	// The CSS module (which owns the type) sets/reads it via unsafe cast; dom cannot name the type
	// because it cannot import css. See css/dom_css_bridge.v.
	css_handle voidptr = unsafe { nil }
mut:
	rare_properties_ &CSSComputedPropertiesRareData = unsafe { nil }
}

pub fn (c &CSSComputedProperties_) display() CSSDisplay_ {
	return c.display_
}

pub fn (c &CSSComputedProperties_) display_is_none_ignoring_animations() bool {
	// DOM-only callers can construct a placeholder without the opaque CSS
	// handle. For those values, the mirrored display is necessarily the base
	// display as well.
	if c.css_handle == unsafe { nil } {
		return c.display_.is_none()
	}
	return c.non_animated_display_is_none_
}

pub fn (c &CSSComputedProperties_) overflow_x() CSSOverflow_ {
	return c.overflow_x_
}

pub fn (c &CSSComputedProperties_) overflow_y() CSSOverflow_ {
	return c.overflow_y_
}

pub fn (c &CSSComputedProperties_) has_casing_text_transform() bool {
	return c.has_casing_text_transform_
}

pub fn (c &CSSComputedProperties_) content_visibility() CSSContentVisibility_ {
	return c.content_visibility_
}

pub fn (c &CSSComputedProperties_) opacity() f32 {
	return c.opacity_
}

pub fn (c &CSSComputedProperties_) visibility() CSSVisibility_ {
	return c.visibility_
}

pub fn (c &CSSComputedProperties_) font_weight() f64 {
	return c.font_weight_
}

pub fn (c &CSSComputedProperties_) math_depth() int {
	return c.math_depth_
}

pub fn (c &CSSComputedProperties_) math_style() CSSMathStyle_ {
	return c.math_style_
}

pub fn (c &CSSComputedProperties_) view_transition_name() ?string {
	return c.rare_properties().view_transition_name
}

pub fn (c &CSSComputedProperties_) anchor_names() []string {
	return c.rare_properties().anchor_names.clone()
}

pub fn (c &CSSComputedProperties_) color_schemes() []string {
	return c.rare_properties().color_schemes.clone()
}

pub fn (c &CSSComputedProperties_) color_scheme_only() bool {
	return c.color_scheme_only_
}

pub fn (c &CSSComputedProperties_) has_attempted_match_against_pseudo_class(pseudo_class PseudoClass) bool {
	return c.attempted_pseudo_class_matches_ & (u8(1) << int(pseudo_class)) != 0
}

pub struct CSSDisplay_ {
pub mut:
	is_none_               bool
	is_list_item_          bool
	is_contents_           bool
	is_inline_outside_     bool
	is_flow_inside_        bool
	is_flow_root_inside_   bool
	is_flex_inside_        bool
	is_grid_inside_        bool
	is_table_inside_       bool
	is_math_inside_        bool
	is_ruby_inside_        bool
	is_block_outside_      bool
	is_table_caption_      bool
	is_table_cell_         bool
	is_table_row_          bool
	is_table_row_group_    bool
	is_table_header_group_ bool
	is_table_footer_group_ bool
	is_table_column_       bool
	is_table_column_group_ bool
}

pub fn (d CSSDisplay_) is_none() bool {
	return d.is_none_
}

pub fn (d CSSDisplay_) is_list_item() bool {
	return d.is_list_item_
}

pub fn (d CSSDisplay_) is_block_outside() bool {
	return d.is_block_outside_
}

pub fn (d CSSDisplay_) is_table_caption() bool {
	return d.is_table_caption_
}

pub fn (d CSSDisplay_) is_table_cell() bool {
	return d.is_table_cell_
}

pub fn (d CSSDisplay_) is_table_row() bool {
	return d.is_table_row_
}

pub fn (d CSSDisplay_) is_flow_root_inside() bool {
	return d.is_flow_root_inside_
}

pub fn (d CSSDisplay_) is_flex_inside() bool {
	return d.is_flex_inside_
}

pub fn (d CSSDisplay_) is_grid_inside() bool {
	return d.is_grid_inside_
}

pub fn (d CSSDisplay_) is_table_inside() bool {
	return d.is_table_inside_
}

pub fn (d CSSDisplay_) is_math_inside() bool {
	return d.is_math_inside_
}

pub fn (d CSSDisplay_) is_ruby_inside() bool {
	return d.is_ruby_inside_
}

pub fn (d CSSDisplay_) is_table_row_group() bool {
	return d.is_table_row_group_
}

pub fn (d CSSDisplay_) is_table_header_group() bool {
	return d.is_table_header_group_
}

pub fn (d CSSDisplay_) is_table_footer_group() bool {
	return d.is_table_footer_group_
}

pub fn (d CSSDisplay_) is_table_column() bool {
	return d.is_table_column_
}

pub fn (d CSSDisplay_) is_table_column_group() bool {
	return d.is_table_column_group_
}

pub enum CSSOverflow_ {
	visible
	hidden
	scroll
	auto_
	clip
}

pub enum CSSContentVisibility_ {
	visible
	hidden
	auto_
}

pub enum CSSVisibility_ {
	visible
	hidden
	collapse
}

pub enum CSSMathStyle_ {
	normal
	compact
}

pub struct CSSCustomProperty_ {
pub:
	important bool
	value     &CSSStyleValue_
}

@[heap]
pub struct CSSCustomPropertyData_ {
pub mut:
	own_values                           map[string]CSSCustomProperty_
	parent                               ?&CSSCustomPropertyData_
	ancestor_count                       u8
	is_animation_overlay_                bool
	cached_inheritable_document_identity voidptr = unsafe { nil }
	cached_inheritable_generation        u64 = max_u64
	cached_inheritable_data              ?&CSSCustomPropertyData_
	cached_inheritable_is_self           bool
}

pub fn (data &CSSCustomPropertyData_) is_animation_overlay() bool {
	return data.is_animation_overlay_
}

pub fn (data &CSSCustomPropertyData_) get(name string) ?&CSSStyleValue_ {
	return (data.get_property(name) or { return none }).value
}

pub fn (data &CSSCustomPropertyData_) get_property(name string) ?CSSCustomProperty_ {
	if property := data.own_values[name] {
		return property
	}
	if parent := data.parent {
		return parent.get_property(name)
	}
	return none
}

pub fn (data &CSSCustomPropertyData_) all_values() map[string]CSSCustomProperty_ {
	mut values := map[string]CSSCustomProperty_{}
	mut node := ?&CSSCustomPropertyData_(data)
	for {
		current := node or { break }
		for name, property in current.own_values {
			if name !in values {
				values[name] = property
			}
		}
		node = current.parent
	}
	return values
}

pub fn (data &CSSCustomPropertyData_) is_empty() bool {
	if data.own_values.len != 0 {
		return false
	}
	if parent := data.parent {
		return parent.is_empty()
	}
	return true
}

fn optional_custom_property_data_identical(left ?&CSSCustomPropertyData_, right ?&CSSCustomPropertyData_) bool {
	if left_data := left {
		right_data := right or { return false }
		return voidptr(left_data) == voidptr(right_data)
	}
	return right == none
}

pub fn (data &CSSCustomPropertyData_) inheritable(document &Document) ?&CSSCustomPropertyData_ {
	document_identity := voidptr(document)
	generation := document.custom_property_registration_generation()
	if data.cached_inheritable_document_identity == document_identity
		&& data.cached_inheritable_generation == generation {
		if data.cached_inheritable_is_self {
			return data
		}
		return data.cached_inheritable_data
	}

	mut inheritable_parent := ?&CSSCustomPropertyData_(none)
	if parent := data.parent {
		inheritable_parent = parent.inheritable(document)
	}
	mut inheritable_own_values := map[string]CSSCustomProperty_{}
	mut filtered_any_own_values := false
	for name, property in data.own_values {
		if registration := document.get_registered_custom_property(name) {
			if !registration.inherits {
				filtered_any_own_values = true
				continue
			}
		}
		inheritable_own_values[name] = property
	}

	mut mutable_data := unsafe { &CSSCustomPropertyData_(data) }
	mutable_data.cached_inheritable_document_identity = document_identity
	mutable_data.cached_inheritable_generation = generation
	if !filtered_any_own_values
		&& optional_custom_property_data_identical(inheritable_parent, data.parent) {
		mutable_data.cached_inheritable_data = none
		mutable_data.cached_inheritable_is_self = true
		return data
	}

	mutable_data.cached_inheritable_is_self = false
	if inheritable_own_values.len == 0 && inheritable_parent == none {
		mutable_data.cached_inheritable_data = none
		return none
	}
	result := CSSCustomPropertyData_.create(inheritable_own_values, inheritable_parent)
	mutable_data.cached_inheritable_data = result
	return result
}

// CustomPropertyData::create (LibWeb/CSS/CustomPropertyData.cpp). Keep shallow
// chains by flattening after 32 ancestors and absorbing parents with at most
// eight own declarations, exactly like upstream.
pub fn CSSCustomPropertyData_.create(input_own_values map[string]CSSCustomProperty_, parent ?&CSSCustomPropertyData_) &CSSCustomPropertyData_ {
	mut own_values := input_own_values.clone()
	parent_data := parent or {
		return &CSSCustomPropertyData_{
			own_values: own_values
		}
	}

	if parent_data.ancestor_count >= 31 {
		for name, property in parent_data.all_values() {
			if name !in own_values {
				own_values[name] = property
			}
		}
		return &CSSCustomPropertyData_{
			own_values: own_values
		}
	}

	if parent_data.own_values.len <= 8 {
		for name, property in parent_data.own_values {
			if name !in own_values {
				own_values[name] = property
			}
		}
		grandparent := parent_data.parent
		ancestor_count := if grandparent_data := grandparent {
			grandparent_data.ancestor_count + 1
		} else {
			u8(0)
		}
		return &CSSCustomPropertyData_{
			own_values: own_values
			parent: grandparent
			ancestor_count: ancestor_count
		}
	}

	return &CSSCustomPropertyData_{
		own_values: own_values
		parent: parent_data
		ancestor_count: parent_data.ancestor_count + 1
	}
}

// Animation values form a distinct layer above the element's ordinary custom
// property environment. Do not apply create()'s parent absorption here: style
// recomputation must be able to replace the base while retaining the sampled
// animation values, and change reporting must compare both layers separately.
pub fn CSSCustomPropertyData_.create_animation_overlay(animated_values map[string]CSSCustomProperty_, base ?&CSSCustomPropertyData_) &CSSCustomPropertyData_ {
	ancestor_count := if base_data := base {
		base_data.ancestor_count + 1
	} else {
		u8(0)
	}
	return &CSSCustomPropertyData_{
		own_values: animated_values.clone()
		parent: base
		ancestor_count: ancestor_count
		is_animation_overlay_: true
	}
}

@[heap]
pub struct CSSCountersSet_ {

	// dom<->css bridge: opaque handle to the real css.CountersSet. Keeping the
	// concrete type on the CSS side avoids a dom -> css import cycle.
pub mut:
	css_handle voidptr = unsafe { nil }
}

pub fn CSSCountersSet_.with_css_handle(handle voidptr) &CSSCountersSet_ {
	return &CSSCountersSet_{
		css_handle: handle
	}
}

pub fn (mut c CSSCountersSet_) visit_edges(visitor &CellVisitor) {
	_ = visitor
}

pub struct RequiredInvalidationAfterStyleChange {
pub mut:
	relayout                            bool
	rebuild_layout_tree                 bool
	repaint                             bool
	rebuild_stacking_context_tree       bool
	rebuild_accumulated_visual_contexts bool
	recompute_descendant_styles         bool
	invalidates_hit_test_display_list   bool
}

pub fn (r RequiredInvalidationAfterStyleChange) is_none() bool {
	return !r.relayout && !r.rebuild_layout_tree && !r.repaint
		&& !r.rebuild_stacking_context_tree && !r.rebuild_accumulated_visual_contexts
		&& !r.recompute_descendant_styles && !r.invalidates_hit_test_display_list
}


@[heap]
pub struct PseudoElement_ {
pub mut:
	layout_node_     ?&LayoutNodeWithStyle_
	computed_props   ?&CSSComputedProperties_
	custom_prop_data ?&CSSCustomPropertyData_
	counters_set_    ?&CSSCountersSet_
	scroll_offset_   CSSPixelPoint_
}

pub fn (p &PseudoElement_) layout_node() ?&LayoutNodeWithStyle_ {
	return p.layout_node_
}

pub fn (mut p PseudoElement_) set_layout_node(node ?&LayoutNodeWithStyle_) {
	p.layout_node_ = node
}

pub fn (p &PseudoElement_) computed_properties() ?&CSSComputedProperties_ {
	return p.computed_props
}

pub fn (mut p PseudoElement_) set_computed_properties(props ?&CSSComputedProperties_) {
	p.computed_props = props
}

pub fn (p &PseudoElement_) custom_property_data() ?&CSSCustomPropertyData_ {
	return p.custom_prop_data
}

pub fn (mut p PseudoElement_) set_custom_property_data(data ?&CSSCustomPropertyData_) {
	p.custom_prop_data = data
}

pub enum LayoutNodeKind {
	box
	list_item_box
	block_container
	inline_node
}

@[heap]
pub struct LayoutNodeWithStyle_ {
pub mut:
	layout_node_        ?&LayoutNode
	applied_properties_ ?&CSSComputedProperties_
	kind_               LayoutNodeKind = .inline_node
}

pub fn (n &LayoutNodeWithStyle_) apply_style(props &CSSComputedProperties_) {
	unsafe {
		n.applied_properties_ = props
	}
	if layout_node := n.layout_node_ {
		layout_node.apply_style(props.css_handle)
	}
}

pub fn (n &LayoutNodeWithStyle_) apply_inherited_color_style(props &CSSComputedProperties_) bool {
	unsafe { n.applied_properties_ = props }
	if layout_node := n.layout_node_ {
		return layout_node.apply_inherited_color_style(props.css_handle)
	}
	return false
}

pub fn (n &LayoutNodeWithStyle_) apply_animated_style(props &CSSComputedProperties_,
	only_compositor_changes bool) bool {
	unsafe { n.applied_properties_ = props }
	if layout_node := n.layout_node_ {
		return layout_node.apply_animated_style(props.css_handle, only_compositor_changes)
	}
	return false
}

pub fn (n &LayoutNodeWithStyle_) layout_node_kind() LayoutNodeKind {
	return n.kind_
}

pub fn (n &LayoutNodeWithStyle_) is_scroll_container() bool {
	dom_node := n.dom_node() or { return false }
	element := dom_node.as_element() or { return false }
	computed := element.el_computed_properties() or { return false }
	return computed.overflow_x() in [.hidden, .scroll, .auto_] || computed.overflow_y() in [
		.hidden,
		.scroll,
		.auto_,
	]
}

pub fn (n &LayoutNodeWithStyle_) previous_in_pre_order() ?&LayoutNodeWithStyle_ {
	layout_node := n.layout_node_ or { return none }
	if previous := n.previous_sibling() {
		mut current := previous.layout_node_ or { return previous }
		for current.children_.len > 0 {
			current = current.children_[current.children_.len - 1]
		}
		return layout_node_with_style(current)
	}
	parent := layout_node.parent_ or { return none }
	return layout_node_with_style(parent)
}

pub fn (n &LayoutNodeWithStyle_) previous_sibling() ?&LayoutNodeWithStyle_ {
	layout_node := n.layout_node_ or { return none }
	parent := layout_node.parent_ or { return none }
	for index, sibling in parent.children_ {
		if voidptr(sibling) == voidptr(layout_node) {
			if index == 0 {
				return none
			}
			return layout_node_with_style(parent.children_[index - 1])
		}
	}
	return none
}

pub fn (n &LayoutNodeWithStyle_) dom_node() ?&Node {
	layout_node := n.layout_node_ or { return none }
	return layout_node.dom_node_
}

pub fn (n &LayoutNodeWithStyle_) is_generated_for_pseudo_element() bool {
	layout_node := n.layout_node_ or { return false }
	return layout_node.generated_for_pseudo_element() != none
}

pub fn (n &LayoutNodeWithStyle_) pseudo_element_generator() ?&Element {
	layout_node := n.layout_node_ or { return none }
	return layout_node.pseudo_element_generator()
}

pub fn (n &LayoutNodeWithStyle_) generated_for_pseudo_element() ?PseudoElement {
	layout_node := n.layout_node_ or { return none }
	return layout_node.generated_for_pseudo_element()
}

pub fn (n &LayoutNodeWithStyle_) is_before(other &LayoutNodeWithStyle_) bool {
	this_node := n.layout_node_ or { return false }
	other_node := other.layout_node_ or { return false }
	if voidptr(this_node) == voidptr(other_node) {
		return false
	}
	this_path := layout_node_ancestor_path(this_node)
	other_path := layout_node_ancestor_path(other_node)
	mut common_length := 0
	for common_length < this_path.len && common_length < other_path.len && voidptr(this_path[common_length]) == voidptr(other_path[common_length]) {
		common_length++
	}
	if common_length == this_path.len {
		return true
	}
	if common_length == other_path.len || common_length == 0 {
		return false
	}
	parent := this_path[common_length - 1]
	for child in parent.children_ {
		if voidptr(child) == voidptr(this_path[common_length]) {
			return true
		}
		if voidptr(child) == voidptr(other_path[common_length]) {
			return false
		}
	}
	return false
}

fn layout_node_with_style(node &LayoutNode) &LayoutNodeWithStyle_ {
	return &LayoutNodeWithStyle_{
		layout_node_: node
	}
}

fn layout_style_wrapper_for_attachment(element &Element, node &LayoutNode) &LayoutNodeWithStyle_ {
	if previous := element.layout_node_with_style_ {
		if previous_node := previous.layout_node_ {
			if voidptr(previous_node) == voidptr(node) {
				// The DOM/layout boundary is live. Keep its wrapper when the same
				// boundary receives geometry again, while resetting attachment data.
				unsafe { *previous = LayoutNodeWithStyle_{layout_node_: node} }
				return previous
			}
		}
	}
	return layout_node_with_style(node)
}

fn layout_node_ancestor_path(node &LayoutNode) []&LayoutNode {
	mut result := []&LayoutNode{}
	mut current := ?&LayoutNode(node)
	for current != none {
		item := current or { break }
		result.prepend(item)
		current = item.parent_
	}
	return result
}

@[heap]
pub struct Bitmap_ {
pub mut:
	width      int = 1
	height     int = 1
	pitch      int
	format     u8
	alpha_type u8
	data       []u8
	// Raw browser-host video frames arrive in CSS top-to-bottom row order.
	// Other native image bridges retain their historical Quartz row order.
	native_rows_are_top_down bool
	// The native URL decoder would produce these same pixels without applying
	// additional format or color-profile handling. Retained image commands may
	// then share the request's bitmap instead of decoding the resource again.
	native_resource_replay_compatible bool
}

pub fn (bitmap &Bitmap_) clone() &Bitmap_ {
	return &Bitmap_{
		width:      bitmap.width
		height:     bitmap.height
		pitch:      bitmap.pitch
		format:     bitmap.format
		alpha_type: bitmap.alpha_type
		data:       bitmap.data.clone()
		native_rows_are_top_down: bitmap.native_rows_are_top_down
		native_resource_replay_compatible: bitmap.native_resource_replay_compatible
	}
}

pub enum DecodedImageColorSpace {
	srgb
	display_p3
}

// Gfx::DecodedImageFrame keeps decoded pixels and their color space together.
// Bitmap_ is the V host's raw pixel storage, matching Gfx::Bitmap.
@[heap]
pub struct DecodedImageFrame_ {
pub:
	bitmap_      &Bitmap_ = unsafe { nil }
	color_space_ DecodedImageColorSpace
}

pub fn DecodedImageFrame_.create(bitmap &Bitmap_) &DecodedImageFrame_ {
	return &DecodedImageFrame_{
		bitmap_: bitmap
	}
}

pub fn DecodedImageFrame_.create_with_color_space(bitmap &Bitmap_, color_space DecodedImageColorSpace) &DecodedImageFrame_ {
	return &DecodedImageFrame_{
		bitmap_: bitmap
		color_space_: color_space
	}
}

// Gfx::DecodedImageFrame's alpha-type overload keeps the source bitmap when it
// already has the requested interpretation and clones it before changing the
// interpretation otherwise.
pub fn DecodedImageFrame_.create_with_alpha_type(bitmap &Bitmap_, alpha_type u8, color_space DecodedImageColorSpace) &DecodedImageFrame_ {
	if bitmap.alpha_type == alpha_type {
		return DecodedImageFrame_.create_with_color_space(bitmap, color_space)
	}
	converted := &Bitmap_{
		width:      bitmap.width
		height:     bitmap.height
		pitch:      bitmap.pitch
		format:     bitmap.format
		alpha_type: alpha_type
		data:       bitmap.data.clone()
		native_rows_are_top_down: bitmap.native_rows_are_top_down
		native_resource_replay_compatible: bitmap.native_resource_replay_compatible
	}
	return DecodedImageFrame_.create_with_color_space(converted, color_space)
}

pub fn (frame &DecodedImageFrame_) bitmap() &Bitmap_ {
	return frame.bitmap_
}

pub fn (frame &DecodedImageFrame_) color_space() DecodedImageColorSpace {
	return frame.color_space_
}

pub fn (frame &DecodedImageFrame_) width() int {
	return frame.bitmap_.width
}

pub fn (frame &DecodedImageFrame_) height() int {
	return frame.bitmap_.height
}

pub fn (a &CSSAnimation_) cancel() {
	if a.target != unsafe { nil } && a.cancel_callback != unsafe { nil } {
		a.cancel_callback(a.target)
	}
}

pub fn (a &CSSAnimation_) play() ! {
	if a.target != unsafe { nil } && a.play_callback != unsafe { nil } {
		a.play_callback(a.target)
	}
}

pub fn (a &CSSAnimation_) pause() ! {
	if a.target != unsafe { nil } && a.pause_callback != unsafe { nil } {
		a.pause_callback(a.target)
	}
}

pub fn (a &CSSAnimation_) last_css_animation_play_state() ?CSSAnimationPlayState_ {
	if a.target != unsafe { nil } && a.last_play_state_callback != unsafe { nil } {
		return a.last_play_state_callback(a.target)
	}
	return none
}

pub struct CSSPixelPoint_ {
pub mut:
	x_ f64
	y_ f64
}

pub fn (p CSSPixelPoint_) x() f64 {
	return p.x_
}

pub fn (p CSSPixelPoint_) y() f64 {
	return p.y_
}

pub fn (mut p CSSPixelPoint_) set_x(v f64) {
	p.x_ = v
}

pub fn (mut p CSSPixelPoint_) set_y(v f64) {
	p.y_ = v
}

pub fn (p CSSPixelPoint_) is_zero() bool {
	return p.x_ == 0 && p.y_ == 0
}

pub struct CSSPixelRect_ {
pub mut:
	x_      f64
	y_      f64
	width_  f64
	height_ f64
}

pub fn (r CSSPixelRect_) width() f64 {
	return r.width_
}

pub fn (r CSSPixelRect_) height() f64 {
	return r.height_
}

fn css_pixel_rect_intersects_rect(rect CSSPixelRect_, other Rect) bool {
	return rect.x_ < other.x + other.width && rect.x_ + rect.width_ > other.x && rect.y_ < other.y + other.height && rect.y_ + rect.height_ > other.y
}

pub enum Dir {
	ltr
	rtl
	auto_
}

pub enum Directionality {
	ltr
	rtl
}

pub enum TranslationMode {
	translate_enabled
	no_translate
}

pub enum FullscreenRequester {
	bindings
	web_driver
}

pub enum RequestFullscreenError {
	false_
	unsupported_element
	element_ready_check_failed
	no_transient_user_activation
	element_node_doc_is_not_pending_doc
}

// Union type for custom element reaction queue
pub type CustomElementReaction = CustomElementUpgradeReaction | CustomElementCallbackReaction

const namespace_html_uri = 'http://www.w3.org/1999/xhtml'
const namespace_svg_uri = 'http://www.w3.org/2000/svg'
const namespace_xml_uri = 'http://www.w3.org/XML/1998/namespace'
const namespace_xmlns_uri = 'http://www.w3.org/2000/xmlns/'

pub enum ValidationContext {
	element
	attribute
}

fn contains_any_code_point(value string, invalid []u32) bool {
	for ch in value.runes() {
		if u32(ch) in invalid {
			return true
		}
	}
	return false
}

// Name delimiters are ASCII. Ordinary parser names need neither a rune vector
// nor a delimiter vector. Preserve the existing decoder for non-ASCII input,
// including its treatment of malformed UTF-8 supplied by native callers.
fn contains_invalid_name_ascii(value string, attribute bool) bool {
	for byte in value {
		if byte >= 0x80 {
			if attribute {
				return contains_any_code_point(value, [u32(9), 10, 12, 13, 32, 0, 47, 61, 62])
			}
			return contains_any_code_point(value, [u32(9), 10, 12, 13, 32, 0, 47, 62])
		}
		if byte == 9 || byte == 10 || byte == 12 || byte == 13 || byte == 32
			|| byte == 0 || byte == 47 || byte == 62 || (attribute && byte == 61) {
			return true
		}
	}
	return false
}

fn is_ascii_alpha_code_point(ch u32) bool {
	return (ch >= `A` && ch <= `Z`) || (ch >= `a` && ch <= `z`)
}

fn is_ascii_lower_alpha_code_point(ch u32) bool {
	return ch >= `a` && ch <= `z`
}

fn is_ascii_upper_alpha_code_point(ch u32) bool {
	return ch >= `A` && ch <= `Z`
}

fn is_ascii_digit_code_point(ch u32) bool {
	return ch >= `0` && ch <= `9`
}

// https://dom.spec.whatwg.org/#valid-namespace-prefix
pub fn is_valid_namespace_prefix(prefix string) bool {
	// A string is a valid namespace prefix if its length is at least 1 and it does not contain ASCII whitespace, U+0000 NULL, U+002F (/), or U+003E (>).
	return prefix.len > 0 && !contains_invalid_name_ascii(prefix, false)
}

// https://dom.spec.whatwg.org/#valid-attribute-local-name
pub fn is_valid_attribute_local_name(local_name string) bool {
	// A string is a valid attribute local name if its length is at least 1 and it does not contain ASCII whitespace, U+0000 NULL, U+002F (/), U+003D (=), or U+003E (>).
	return local_name.len > 0 && !contains_invalid_name_ascii(local_name, true)
}

// https://dom.spec.whatwg.org/#valid-element-local-name
pub fn is_valid_element_local_name(name string) bool {
	// 1. If name's length is 0, then return false.
	if name.len == 0 {
		return false
	}

	// 2. If name's 0th code point is an ASCII alpha, then:
	if is_ascii_alpha_code_point(u32(name[0])) {
		// 1. If name contains ASCII whitespace, U+0000 NULL, U+002F (/), or U+003E (>), then return false.
		if contains_invalid_name_ascii(name, false) {
			return false
		}

		// 2. Return true.
		return true
	}
	runes := name.runes()
	first_code_point := u32(runes[0])

	// 3. If name's 0th code point is not U+003A (:), U+005F (_), or in the range U+0080 to U+10FFFF, inclusive, then return false.
	if first_code_point != `:` && first_code_point != `_` && (first_code_point < 0x0080 || first_code_point > 0x10ffff) {
		return false
	}

	// 4. If name's subsequent code points, if any, are not ASCII alphas, ASCII digits, U+002D (-), U+002E (.),
	//    U+003A (:), U+005F (_), or in the range U+0080 to U+10FFFF, inclusive, then return false.
	for i := 1; i < runes.len; i++ {
		code_point := u32(runes[i])
		if !is_ascii_alpha_code_point(code_point) && !is_ascii_digit_code_point(code_point) && code_point != `-` && code_point != `.` && code_point != `:` && code_point != `_` && (code_point < 0x0080 || code_point > 0x10ffff) {
			return false
		}
	}

	// 5. Return true.
	return true
}

// https://html.spec.whatwg.org/multipage/custom-elements.html#valid-custom-element-name
pub fn is_valid_custom_element_name(name string) bool {
	// A string name is a valid custom element name if all of the following are true:
	// - name is a valid element local name;
	if !is_valid_element_local_name(name) {
		return false
	}

	runes := name.runes()
	// - name's 0th code point is an ASCII lower alpha;
	if runes.len == 0 || !is_ascii_lower_alpha_code_point(u32(runes[0])) {
		return false
	}

	// - name does not contain any ASCII upper alphas;
	// - name contains a U+002D (-); and
	mut contains_hyphen := false
	for ch in runes {
		code_point := u32(ch)
		if is_ascii_upper_alpha_code_point(code_point) {
			return false
		}
		if code_point == `-` {
			contains_hyphen = true
		}
	}
	if !contains_hyphen {
		return false
	}

	// - name is not one of the following:
	//   - "annotation-xml"
	//   - "color-profile"
	//   - "font-face"
	//   - "font-face-src"
	//   - "font-face-uri"
	//   - "font-face-format"
	//   - "font-face-name"
	//   - "missing-glyph"
	if name in ['annotation-xml', 'color-profile', 'font-face', 'font-face-src', 'font-face-uri',
		'font-face-format', 'font-face-name', 'missing-glyph'] {
		return false
	}

	return true
}

fn namespace_matches(namespace_ ?string, value string) bool {
	ns := namespace_ or { return false }
	return ns == value
}

// Compare two optional strings for equality without using `?string == ?string`, which triggers a V
// codegen bug (the auto-generated `builtin___option_string__eq` is sometimes emitted as a call but never
// defined, breaking the C build). Both none is equal; a value vs none is not.
fn option_string_equal(a ?string, b ?string) bool {
	if a_value := a {
		b_value := b or { return false }
		return a_value == b_value
	}
	if _ := b {
		return false
	}
	return true
}

// https://dom.spec.whatwg.org/#validate-and-extract
pub fn validate_and_extract(namespace_ ?string, qualified_name string, context ValidationContext) !QualifiedName {
	// 1. If namespace is the empty string, then set it to null.
	mut normalized_namespace := namespace_
	if ns := normalized_namespace {
		if ns.len == 0 {
			normalized_namespace = none
		}
	}

	// 2. Let prefix be null.
	mut prefix := ?string(none)

	// 3. Let localName be qualifiedName.
	mut local_name := qualified_name

	// 4. If qualifiedName contains a U+003A (:):
	mut colon_position := -1
	for index, byte in qualified_name.bytes() {
		if byte == `:` {
			colon_position = index
			break
		}
	}
	if colon_position >= 0 {
		// 1. Set prefix to the part of qualifiedName before the first U+003A (:).
		prefix = qualified_name[..colon_position]

		// 2. Set localName to the part of qualifiedName after the first U+003A (:).
		local_name = qualified_name[colon_position + 1..]

		// 3. If prefix is not a valid namespace prefix, then throw an "InvalidCharacterError" DOMException.
		if prefix_value := prefix {
			if !is_valid_namespace_prefix(prefix_value) {
				return error('InvalidCharacterError: Prefix not a valid namespace prefix')
			}
		}
	}

	// 6. If context is "attribute" and localName is not a valid attribute local name, then throw an "InvalidCharacterError" DOMException.
	if context == .attribute && !is_valid_attribute_local_name(local_name) {
		return error('InvalidCharacterError: Local name not a valid attribute local name')
	}

	// 7. If context is "element" and localName is not a valid element local name, then throw an "InvalidCharacterError" DOMException.
	if context == .element && !is_valid_element_local_name(local_name) {
		return error('InvalidCharacterError: Local name not a valid element local name')
	}

	// 8. If prefix is non-null and namespace is null, then throw a "NamespaceError" DOMException.
	if prefix != none && normalized_namespace == none {
		return error('NamespaceError: Prefix is non-null and namespace is null')
	}

	// 9. If prefix is "xml" and namespace is not the XML namespace, then throw a "NamespaceError" DOMException.
	if prefix_value := prefix {
		if prefix_value == 'xml' && !namespace_matches(normalized_namespace, namespace_xml_uri) {
			return error("NamespaceError: Prefix is 'xml' and namespace is not the XML namespace")
		}
	}

	// 10. If either qualifiedName or prefix is "xmlns" and namespace is not the XMLNS namespace, then throw a "NamespaceError" DOMException.
	prefix_is_xmlns := if prefix_value := prefix { prefix_value == 'xmlns' } else { false }
	if qualified_name == 'xmlns' || prefix_is_xmlns {
		if !namespace_matches(normalized_namespace, namespace_xmlns_uri) {
			return error("NamespaceError: Either qualifiedName or prefix is 'xmlns' and namespace is not the XMLNS namespace")
		}
	}

	// 11. If namespace is the XMLNS namespace and neither qualifiedName nor prefix is "xmlns", then throw a "NamespaceError" DOMException.
	if namespace_matches(normalized_namespace, namespace_xmlns_uri) && !(qualified_name == 'xmlns' || prefix_is_xmlns) {
		return error('NamespaceError: Namespace is the XMLNS namespace and neither qualifiedName nor prefix is xmlns')
	}

	// 12. Return (namespace, prefix, localName).
	return QualifiedName.new(local_name, prefix, normalized_namespace)
}

// Valid shadow host names
const valid_shadow_host_names = ['article', 'aside', 'blockquote', 'body', 'div', 'footer', 'h1',
	'h2', 'h3', 'h4', 'h5', 'h6', 'header', 'main', 'nav', 'p', 'section', 'span']

// --- Element struct ---
@[heap]
pub struct Element {
	ParentNode
mut:
	rare_data_ &ElementRareData = unsafe { nil }
	interactive_data_ &ElementInteractiveData = unsafe { nil }
	custom_data_ &ElementCustomData = unsafe { nil }
	dependency_data_ &ElementDependencyData = unsafe { nil }
	binding_data_ &ElementBindingData = unsafe { nil }
pub mut:
	qualified_name                  QualifiedName

	attributes_          ?&NamedNodeMap
	inline_style_        ?&CSSStyleProperties_
	class_list_          ?&DOMTokenList
	shadow_root_         ?&ShadowRoot

	computed_properties_    ?&CSSComputedProperties_
	layout_node_with_style_ ?&LayoutNodeWithStyle_
	custom_property_data_   ?&CSSCustomPropertyData_
	font_environment_changed_ bool


	classes []string
	dir__   ?Dir
	// HTMLElement's cached state survives until its attribute-change steps
	// capture the previous selector state. Shared HTML storage lives in Element.
	content_editable_state_ string = 'inherit'

	id_   ?string
	name_ ?string

	custom_element_registry_      voidptr = unsafe { nil }



	has_css_defined_animations_flag bool
	animations_animatable_handle_   voidptr = unsafe { nil }

	// Boolean flags
	is_being_activated_                                                             bool
	in_top_layer                                                                    bool
	rendered_in_top_layer                                                           bool
	style_uses_attr_css_function                                                    bool
	style_uses_var_css_function                                                     bool
	style_uses_tree_counting_function                                               bool
	style_uses_if_css_function                                                      bool
	style_uses_inherit_css_function                                                 bool
	style_depends_on_size_container_query_                                          bool
	style_depends_on_container_relative_units_                                      bool
	style_depends_on_style_container_query_                                         bool
	is_size_query_container_                                                        bool
	is_style_query_container_                                                       bool
	child_style_uses_tree_counting_function                                         bool
	affected_by_has_pseudo_class_in_subject_position                                bool
	affected_by_has_pseudo_class_in_non_subject_position                            bool
	affected_by_direct_sibling_combinator                                           bool
	affected_by_indirect_sibling_combinator                                         bool
	affected_by_first_child_pseudo_class                                            bool
	affected_by_last_child_pseudo_class                                             bool
	affected_by_forward_positional_pseudo_class                                     bool
	affected_by_backward_positional_pseudo_class                                    bool
	affected_by_structural_pseudo_class_in_non_subject_position                     bool
	affected_by_sibling_combinator_in_non_subject_position                          bool
	affected_by_has_pseudo_class_with_relative_selector_that_has_sibling_combinator bool
	in_subtree_of_has_pseudo_class_relative_selector_with_sibling_combinator        bool
	in_has_scope                                                                    bool
	fullscreen_flag                                                                 bool

	sibling_invalidation_distance int

	counters_set_  ?&CSSCountersSet_
	ordinal_value_ ?int
	lang_value_    ?string

	had_duplicate_attribute_during_tokenization bool
	custom_element_state_                       CustomElementState = .undefined_
	proximity_to_the_viewport_                  ProximityToTheViewport = .not_determined
	captured_in_a_view_transition               bool
	is_contained_in_list_subtree                bool
	style_element_base_                         ?&StyleElementBase

	doc_ ?&Document
}

// Associate an internal UA shadow-tree element with an element-reference pseudo-element
// exposed by its host. The integer bridge avoids a dom -> css module dependency.
pub fn (mut e Element) set_associated_shadow_host_pseudo_element(pseudo_element int) {
	root := e.as_node().root()
	shadow_root := root.as_shadow_root() or {
		panic('associated shadow-host pseudo-element requires a shadow-tree element')
	}
	host := shadow_root.host() or {
		panic('associated shadow-host pseudo-element requires a shadow host')
	}
	mut mutable_host := unsafe { &Element(host) }
	mut data := mutable_host.ensure_rare_style_data()
	data.element_reference_pseudo_elements[pseudo_element] = &e
	mut state := e.copy_binding_data()
	state.associated_pseudo_element = pseudo_element
	e.binding_data_ = state
}

pub fn (e &Element) associated_shadow_host_pseudo_element() ?int {
	if e.binding_data_ == unsafe { nil } { return none }
	return e.binding_data_.associated_pseudo_element
}

pub fn (e &Element) element_reference_pseudo_element(pseudo_element int) ?&Element {
	if e.rare_data_ == unsafe { nil }
		|| e.rare_data_.style_data_ == unsafe { nil }
		|| pseudo_element !in e.rare_data_.style_data_.element_reference_pseudo_elements {
		return none
	}
	return unsafe { e.rare_data_.style_data_.element_reference_pseudo_elements[pseudo_element] }
}

pub struct StylePropertyMap_ {
pub mut:
	style ?&CSSStyleProperties_
}

fn create_style_property_map_for_bindings(style &CSSStyleProperties_) &StylePropertyMap_ {
	return &StylePropertyMap_{
		style: style
	}
}

pub struct StylePropertyMapReadOnly_ {}

// --- Constructor ---
pub fn Element.new(doc &Document, qname QualifiedName) &Element {
	return assign_unique_node_id(&Element{
		ParentNode: ParentNode{
			Node: Node{
				node_type: .element_node
				document_: doc
				unique_id_: UniqueNodeID(0)
			}
		}
		qualified_name: qname
		doc_: doc
	})
}

// --- Core methods ---
pub fn (mut e Element) initialize() {
	// Base::initialize(realm)
}

pub fn (mut e Element) visit_edges(mut visitor CellVisitor) {
	if attrs := e.attributes_ {
		visitor.visit(attrs)
	}
	if style := e.inline_style_ {
		visitor.visit(style)
	}
	if cl := e.class_list_ {
		visitor.visit(cl)
	}
	if sr := e.shadow_root_ {
		visitor.visit(sr)
	}
	if pl := e.cached_part_list() {
		visitor.visit(pl)
	}
	if ced := e.custom_element_definition() {
		visitor.visit(ced)
	}
	if cp := e.computed_properties_ {
		visitor.visit(cp)
	}
	if csm := e.cached_computed_style_map() {
		visitor.visit(csm)
	}
	if asm_ := e.cached_attribute_style_map() {
		visitor.visit(asm_)
	}
	if e.rare_data_ != unsafe { nil } {
		for _, pe in e.rare_data_.pseudo_element_data {
			visitor.visit(pe)
		}
	}
	if mut cs := e.counters_set_ {
		cs.visit_edges(visitor)
	}
}

// --- Name accessors ---
pub fn (e &Element) qualified_name_str() string {
	return e.qualified_name.as_string()
}

pub fn (e &Element) local_name() string {
	return e.qualified_name.local_name
}

pub fn (e &Element) lowercased_local_name() string {
	if e.qualified_name.lowercased_local_name.len > 0 {
		return e.qualified_name.lowercased_local_name
	}
	return to_ascii_lowercase(e.qualified_name.local_name)
}

pub fn (e &Element) namespace_uri() ?string {
	return e.qualified_name.namespace_
}

pub fn (e &Element) prefix() ?string {
	return e.qualified_name.prefix_
}

pub fn (e &Element) tag_name() string {
	return e.html_uppercased_qualified_name()
}

pub fn (e &Element) node_name() string {
	return e.html_uppercased_qualified_name()
}

fn (e &Element) make_html_uppercased_qualified_name() string {
	ns := e.namespace_uri() or { '' }
	if ns == namespace_html_uri {
		doc := e.document()
		if doc != unsafe { nil } && doc.document_type() == .html {
			return e.qualified_name_str().to_upper()
		}
	}
	return e.qualified_name_str()
}

pub fn (e &Element) html_uppercased_qualified_name() string {
	if cached := e.cached_uppercase_name() {
		return cached
	}
	return e.make_html_uppercased_qualified_name()
}

pub fn (e &Element) document() &Document {
	if d := e.doc_ {
		return d
	}
	return unsafe { nil }
}

pub fn (e &Element) id() ?string {
	return e.id_
}

pub fn (e &Element) get_name() ?string {
	return e.name_
}

// --- Attribute methods ---

// https://dom.spec.whatwg.org/#dom-element-getattribute
pub fn (e &Element) get_attribute(name string) ?string {
	attrs := e.attributes_ or { return none }
	attribute := attrs.get_attribute(name) or { return none }
	return attribute.value()
}

// https://dom.spec.whatwg.org/#dom-element-getattributens
pub fn (e &Element) get_attribute_ns(namespace_ ?string, name string) ?string {
	attrs := e.attributes_ or { return none }
	attribute := attrs.get_attribute_ns(namespace_, name) or { return none }
	return attribute.value()
}

// https://dom.spec.whatwg.org/#dom-element-getattributevalue
pub fn (e &Element) get_attribute_value(local_name string) string {
	return e.get_attribute(local_name) or { '' }
}

// https://dom.spec.whatwg.org/#dom-element-hasattribute
pub fn (e &Element) has_attribute(name string) bool {
	attrs := e.attributes_ or { return false }
	return attrs.get_attribute(name) != none
}

// https://dom.spec.whatwg.org/#dom-element-hasattributens
pub fn (e &Element) has_attribute_ns(namespace_ ?string, name string) bool {
	attrs := e.attributes_ or { return false }
	return attrs.get_attribute_ns(namespace_, name) != none
}

// https://dom.spec.whatwg.org/#dom-element-hasattributes
pub fn (e &Element) has_attributes() bool {
	attrs := e.attributes_ or { return false }
	return !attrs.is_empty()
}

// https://dom.spec.whatwg.org/#dom-element-setattributevalue
pub fn (mut e Element) set_attribute_value(local_name string, value string) {
	e.set_attribute_value_ns(local_name, value, none, none)
}

// https://dom.spec.whatwg.org/#concept-element-attributes-set-value
pub fn (mut e Element) set_attribute_value_ns(local_name string, value string, prefix ?string, namespace_ ?string) {
	mut attrs := e.ensure_attributes()
	normalized_namespace := normalize_attribute_namespace(namespace_)
	if existing := attrs.get_attribute_ns(normalized_namespace, local_name) {
		old_value := existing.value_
		unsafe {
			existing.value_ = value
		}
		existing.handle_attribute_changes(e, old_value, value)
	} else {
		qualified_name := QualifiedName.new(local_name, prefix, normalized_namespace)
		attrs.append_attribute(&Attr_{
			name_: qualified_name.as_string()
			value_: value
			local_name_: local_name
			prefix__: prefix
			namespace_uri_: normalized_namespace
		})
	}
}

// https://dom.spec.whatwg.org/#dom-element-setattribute
pub fn (mut e Element) set_attribute_for_bindings(qualified_name string, value string) ! {
	if !is_valid_attribute_local_name(qualified_name) {
		return error('InvalidCharacterError: Attribute name must not be empty or contain invalid characters')
	}

	mut actual_name := qualified_name
	if e.namespace_uri() or { '' } == namespace_html_uri {
		doc := e.document()
		if doc != unsafe { nil } && doc.document_type() == .html {
			actual_name = to_ascii_lowercase(qualified_name)
		}
	}

	verified_value := e.document().trusted_types_compliant_attribute_value(&e, actual_name, none, value)!
	e.set_attribute_value(actual_name, verified_value)
}

// https://dom.spec.whatwg.org/#dom-element-setattributens
pub fn (mut e Element) set_attribute_ns_for_bindings(namespace_ ?string, qualified_name string, value string) ! {
	extracted := validate_and_extract(namespace_, qualified_name, .attribute)!
	verified_value := e.document().trusted_types_compliant_attribute_value(&e, extracted.local_name, extracted.namespace_, value)!
	e.set_attribute_value_ns(extracted.local_name, verified_value, extracted.prefix_, extracted.namespace_)
}

// https://dom.spec.whatwg.org/#dom-element-setattributenode
pub fn (mut e Element) set_attribute_node_for_bindings(attr &Attr_) !&Attr_ {
	// The setAttributeNode(attr) and setAttributeNodeNS(attr) methods steps are to
	// return the result of setting an attribute given attr and this.
	mut attrs := e.attributes()
	return attrs.set_attribute(attr)!
}

// https://dom.spec.whatwg.org/#dom-element-setattributenodens
pub fn (mut e Element) set_attribute_node_ns_for_bindings(attr &Attr_) !&Attr_ {
	// The setAttributeNode(attr) and setAttributeNodeNS(attr) methods steps are to
	// return the result of setting an attribute given attr and this.
	mut attrs := e.attributes()
	return attrs.set_attribute(attr)!
}

// https://dom.spec.whatwg.org/#dom-element-appendattribute
pub fn (mut e Element) append_attribute_by_name(name string, value string) {
	mut attrs := e.ensure_attributes()
	attrs.append_attribute(&Attr_{
		name_: name
		value_: value
		local_name_: name
	})
}

pub fn (mut e Element) append_attribute(attr &Attr_) {
	mut attrs := e.ensure_attributes()
	attrs.append_attribute(attr)
}

// https://dom.spec.whatwg.org/#dom-element-removeattribute
pub fn (mut e Element) remove_attribute(name string) {
	if mut attrs := e.attributes_ {
		attrs.remove_attribute(name)
	}
}

// https://dom.spec.whatwg.org/#dom-element-removeattributens
pub fn (mut e Element) remove_attribute_ns(namespace_ ?string, name string) {
	if mut attrs := e.attributes_ {
		index := attrs.attribute_index_by_namespace(namespace_, name) or { return }
		attrs.remove_attribute_at_index(index)
	}
}

// https://dom.spec.whatwg.org/#dom-element-removeattributenode
pub fn (mut e Element) remove_attribute_node(attr &Attr_) !&Attr_ {
	mut attrs := e.attributes()
	return attrs.remove_attribute_node_checked(attr)!
}

// https://dom.spec.whatwg.org/#dom-element-toggleattribute
pub fn (mut e Element) toggle_attribute(name string, force ?bool) !bool {
	if name.len == 0 {
		return error('InvalidCharacterError: Attribute name must not be empty')
	}

	mut actual_name := name
	ns := e.namespace_uri() or { '' }
	if ns == namespace_html_uri {
		doc := e.document()
		if doc != unsafe { nil } && doc.document_type() == .html {
			actual_name = to_ascii_lowercase(name)
		}
	}

	existing := e.has_attribute(actual_name)

	if !existing {
		if force == none || force or { false } {
			e.set_attribute_value(actual_name, '')
			return true
		}
		return false
	}

	if force == none || !force or { true } {
		e.remove_attribute(actual_name)
		return false
	}

	return true
}

// https://dom.spec.whatwg.org/#dom-element-getattributenames
pub fn (e &Element) get_attribute_names() []string {
	attrs := e.attributes_ or { return [] }
	mut names := []string{cap: attrs.length()}
	for i := 0; i < attrs.length(); i++ {
		if a := attrs.item(i) {
			names << a.name()
		}
	}
	return names
}

pub fn (e &Element) attribute_list_size() int {
	attrs := e.attributes_ or { return 0 }
	return attrs.length()
}

// Immutable access to the attribute list for read-only iteration (e.g. serialization).
// Returns none when the element has no attributes.
pub fn (e &Element) attribute_list() ?&NamedNodeMap {
	return e.attributes_
}

pub fn (e &Element) get_attribute_node(name string) ?&Attr_ {
	attrs := e.attributes_ or { return none }
	return attrs.get_attribute(name)
}

pub fn (e &Element) get_attribute_node_ns(namespace_ ?string, name string) ?&Attr_ {
	attrs := e.attributes_ or { return none }
	return attrs.get_attribute_ns(namespace_, name)
}

pub fn (mut e Element) attributes() &NamedNodeMap {
	return e.ensure_attributes()
}

fn (mut e Element) ensure_attributes() &NamedNodeMap {
	if attrs := e.attributes_ {
		return attrs
	}
	new_attrs := &NamedNodeMap{
		element: &e
	}
	e.attributes_ = new_attrs
	return new_attrs
}

// --- Attribute associated elements ---

// https://html.spec.whatwg.org/multipage/common-dom-interfaces.html#attr-associated-element
pub fn (e &Element) get_the_attribute_associated_element(content_attribute string, explicitly_set ?&Element) ?&Element {
	// 1. Let element be the result of running reflectedTarget's get the element.
	if exp := explicitly_set {
		// 3. If reflectedTarget's explicitly set attr-element is a descendant of any of
		// element's shadow-including ancestors, then return it. The C++ implementation
		// represents that as a root check against element's shadow-including root.
		if exp.as_node().root() == e.as_node().shadow_including_root() {
			return exp
		}
		return none
	}
	// 2. Let contentAttributeValue be the result of running reflectedTarget's get the content attribute.
	content_attribute_value := e.get_attribute(content_attribute) or { return none }
	doc := e.document()
	if doc == unsafe { nil } {
		return none
	}
	// 4. Otherwise, if contentAttributeValue is not null, return the first element
	// candidate, in tree order, whose root is the same as element's root and whose
	// ID is contentAttributeValue.
	candidate := doc.get_element_by_id(content_attribute_value) or { return none }
	if candidate.as_node().root() != e.as_node().root() {
		return none
	}
	return candidate
}

// --- Class / Part lists ---

// https://dom.spec.whatwg.org/#dom-element-classlist
pub fn (mut e Element) class_list() &DOMTokenList {
	if cl := e.class_list_ {
		return cl
	}
	new_cl := DOMTokenList.create(&e, 'class')
	e.class_list_ = new_cl
	return new_cl
}

// https://drafts.csswg.org/css-shadow-1/#dom-element-part
pub fn (mut e Element) part_list() &DOMTokenList {
	if pl := e.cached_part_list() {
		return pl
	}
	new_pl := DOMTokenList.create(&e, 'part')
	mut state := e.copy_binding_data()
	state.part_list = new_pl
	e.binding_data_ = state
	return new_pl
}

pub fn (e &Element) has_class(class_name string) bool {
	for c in e.classes {
		if c == class_name {
			return true
		}
	}
	return false
}

pub fn (e &Element) has_class_case_insensitive(class_name string) bool {
	lower := to_ascii_lowercase(class_name)
	for c in e.classes {
		if to_ascii_lowercase(c) == lower {
			return true
		}
	}
	return false
}

// --- Shadow DOM ---
fn is_valid_shadow_host_name(name string) bool {
	if name in valid_shadow_host_names {
		return true
	}
	if is_valid_custom_element_name(name) {
		return true
	}
	return false
}

// https://dom.spec.whatwg.org/#concept-attach-a-shadow-root
pub fn (mut e Element) attach_a_shadow_root(mode ShadowRootMode, clonable bool, serializable bool, delegates_focus bool, slot_assignment SlotAssignmentMode) ! {
	e.attach_a_shadow_root_with_registry(mode, clonable, serializable, delegates_focus, slot_assignment, e.document().custom_element_registry())!
}

pub fn (mut e Element) attach_a_shadow_root_with_registry(mode ShadowRootMode, clonable bool, serializable bool, delegates_focus bool, slot_assignment SlotAssignmentMode, registry voidptr) ! {
	ns := e.namespace_uri() or { return error('NotSupportedError: Element namespace is not HTML') }
	if ns != namespace_html_uri {
		return error('NotSupportedError: Element namespace is not HTML')
	}
	if !is_valid_shadow_host_name(e.local_name()) {
		return error('NotSupportedError: Element local name is not a valid shadow host name')
	}
	if is_valid_custom_element_name(e.local_name()) || e.custom_element_is_value() != none {
		if def := look_up_custom_element_definition(e.custom_element_registry(), e.namespace_uri(), e.local_name(), e.custom_element_is_value()) {
			if def.disable_shadow() {
				return error('NotSupportedError: Custom element definition disables shadow roots')
			}
		}
	}
	if e.is_shadow_host() {
		if sr := e.shadow_root_ {
			if !sr.declarative || sr.mode != mode {
				return error('NotSupportedError: Element already is a shadow host')
			}
			// Remove all children and set declarative to false
			mut shadow_node := sr.as_node()
			shadow_node.remove_all_children(false)
			unsafe {
				sr.declarative = false
			}
			return
		}
	}
	shadow := assign_unique_node_id(&ShadowRoot{
		DocumentFragment: DocumentFragment{
			ParentNode: ParentNode{
				Node: Node{
					node_type: .document_fragment_node
					document_: e.document()
					unique_id_: UniqueNodeID(0)
				}
			}
			host_: e
			is_shadow_root_: true
		}
		mode: mode
		clonable_: clonable
		serializable_: serializable
		delegates_focus_: delegates_focus
		slot_assignment_: slot_assignment
		custom_element_registry_: registry
	})
	mut document := unsafe { &Document(e.document()) }
	document.register_shadow_root(shadow)
	e.set_shadow_root(shadow)
}

// UA widgets may have shadow roots even when their tag is not a valid author
// shadow host. This is the DOM boundary used by native HTML controls.
pub fn (mut e Element) attach_a_user_agent_shadow_root(slot_assignment SlotAssignmentMode) &ShadowRoot {
	if existing := e.shadow_root_ {
		return existing
	}
	shadow := assign_unique_node_id(&ShadowRoot{
		DocumentFragment: DocumentFragment{
			ParentNode: ParentNode{
				Node: Node{
					node_type: .document_fragment_node
					document_: e.document()
					unique_id_: UniqueNodeID(0)
				}
			}
			host_: e
			is_shadow_root_: true
		}
		mode: .closed
		slot_assignment_: slot_assignment
		user_agent_internal_: true
	})
	mut document := unsafe { &Document(e.document()) }
	document.register_shadow_root(shadow)
	e.set_shadow_root(shadow)
	return shadow
}

// https://dom.spec.whatwg.org/#dom-element-attachshadow
pub fn (mut e Element) attach_shadow(init ShadowRootInit) !&ShadowRoot {
	mut registry := e.document().custom_element_registry()
	if init.custom_element_registry != none {
		registry = init.custom_element_registry or { unsafe { nil } }
	}
	if registry != unsafe { nil } && !custom_element_registry_is_scoped(registry)
		&& registry != e.document().custom_element_registry() {
		return error("NotSupportedError: registry must be scoped or the document's registry")
	}
	e.attach_a_shadow_root_with_registry(init.mode, init.clonable, init.serializable, init.delegates_focus, init.slot_assignment, registry)!
	return e.shadow_root_ or { return error('Shadow root not set') }
}

// https://dom.spec.whatwg.org/#dom-element-shadowroot
pub fn (e &Element) shadow_root_for_bindings() ?&ShadowRoot {
	shadow := e.shadow_root_ or { return none }
	if shadow.mode == .closed {
		return none
	}
	return shadow
}

pub fn (e &Element) is_shadow_host() bool {
	return e.shadow_root_ != none
}

pub fn (e &Element) shadow_root() ?&ShadowRoot {
	return e.shadow_root_
}

pub fn (mut e Element) set_shadow_root(sr ?&ShadowRoot) {
	current_shadow_root := e.shadow_root_ or { unsafe { nil } }
	new_shadow_root := sr or { unsafe { nil } }
	if voidptr(current_shadow_root) == voidptr(new_shadow_root) {
		return
	}
	if current_shadow_root != unsafe { nil } {
		mut current_fragment := unsafe { &DocumentFragment(current_shadow_root) }
		current_fragment.set_host(none)
		mut current_node := unsafe { &Node(current_shadow_root) }
		current_node.set_is_connected(false)
		if e.is_connected() {
			old_root := unsafe { &Node(current_shadow_root) }
			current_node.visit_shadow_including_descendants(fn [old_root] (descendant &Node) TraversalDecision {
				mut mutable_descendant := unsafe { &Node(descendant) }
				mutable_descendant.removed_from_with_context(.no, old_root, old_root)
				return .@continue
			})
		}
	}
	e.shadow_root_ = sr
	mut document := e.document()
	document.invalidate_layout_stabilization_count()
	if new_shadow_root != unsafe { nil } {
		mut new_fragment := unsafe { &DocumentFragment(new_shadow_root) }
		new_fragment.set_host(&e)
		mut new_node := unsafe { &Node(new_shadow_root) }
		new_node.set_is_connected(e.is_connected())
	}
	mut node := unsafe { &Node(&e) }
	node.invalidate_style(.element_set_shadow_root)
	node.set_needs_layout_tree_update(true, .element_set_shadow_root)
}

// --- Selector matching ---

// https://dom.spec.whatwg.org/#dom-element-matches
pub fn (e &Element) matches(selectors string) !bool {
	// 1. Let s be the result of parse a selector from selectors.
	maybe_selectors := parse_selector(e.document(), selectors)

	// 2. If s is failure, then throw a "SyntaxError" DOMException.
	selector_list := maybe_selectors or { return error('SyntaxError: Failed to parse selector') }

	// 3. If the result of match a selector against an element, using s, this, and scoping root this, returns success, then return true; otherwise, return false.
	scoping_root := unsafe { &ParentNode(e) }
	for selector in selector_list.selectors {
		if selector_engine_matches(selector, e, scoping_root) {
			return true
		}
	}
	return false
}

// https://dom.spec.whatwg.org/#dom-element-closest
pub fn (e &Element) closest(selectors string) ?&Element {
	// 1. Let s be the result of parse a selector from selectors.
	maybe_selectors := parse_selector(e.document(), selectors)

	// 2. If s is failure, then throw a "SyntaxError" DOMException.
	selector_list := maybe_selectors or { return none }

	scoping_root := unsafe { &ParentNode(e) }
	matches_selectors := fn [selector_list, scoping_root] (element &Element) bool {
		// 4. For each element in elements, if match a selector against an element, using s, element, and scoping root this, returns success, return element.
		for selector in selector_list.selectors {
			if selector_engine_matches(selector, element, scoping_root) {
				return true
			}
		}
		return false
	}

	// 3. Let elements be this's inclusive ancestors that are elements, in reverse tree order.
	mut element := ?&Element(e)
	for element != none {
		current := element or { break }
		if matches_selectors(current) {
			return current
		}
		element = current.as_node().parent_element()
	}
	// 5. Return null.
	return none
}

// --- CSSOM View: client* ---

// https://drafts.csswg.org/cssom-view/#dom-element-clienttop
pub fn (e &Element) client_top() int {
	document := e.document()
	_ = document.update_style_for_element(e, false)
	style := e.el_computed_properties() or { return 0 }
	if !client_geometry_has_box(style.display()) {
		return 0
	}
	return int(style.client_border_top_width_)
}

// https://drafts.csswg.org/cssom-view/#dom-element-clientleft
pub fn (e &Element) client_left() int {
	document := e.document()
	_ = document.update_style_for_element(e, false)
	style := e.el_computed_properties() or { return 0 }
	if !client_geometry_has_box(style.display()) {
		return 0
	}
	return int(style.client_border_left_width_)
}

fn client_geometry_has_box(display CSSDisplay_) bool {
	return !display.is_none() && !display.is_contents()
		&& !(display.is_inline_outside() && display.is_flow_inside())
}

fn client_size_has_committed_box(layout &LayoutNode) bool {
	if !layout.has_geometry_ || layout.display_.is_none() || layout.display_.is_contents() {
		return false
	}
	// Inline fragments have retained geometry in the V bridge, but do not
	// constitute Painting::has_committed_box(). Atomic/replaced inlines do.
	return !(layout.display_.is_inline_outside() && layout.display_.is_flow_inside()
		&& !layout.is_atomic_inline_ && !layout.is_replaced_box_)
}

fn (e &Element) client_size_uses_viewport() bool {
	// Element.cpp checks the concrete HTMLHtmlElement/HTMLBodyElement types
	// before layout; SVG/XML elements with the same local name do not qualify.
	return e.is_html_element()
		&& ((e.local_name() == 'html' && !e.document().in_quirks_mode())
		|| (e.local_name() == 'body' && e.document().in_quirks_mode()))
}

// https://drafts.csswg.org/cssom-view/#dom-element-clientwidth
pub fn (e &Element) client_width() int {
	if e.client_size_uses_viewport() {
		return int(e.document().viewport_rect().width)
	}
	mut document := unsafe { &Document(e.document()) }
	document.update_layout(.element_client_width)
	layout := e.as_node().layout_node() or { return 0 }
	if !client_size_has_committed_box(layout) {
		return 0
	}
	return int((layout.content_width_ + layout.box_model().padding_left + layout.box_model().padding_right) / e.document().layout_coordinate_scale())
}

// https://drafts.csswg.org/cssom-view/#dom-element-clientheight
pub fn (e &Element) client_height() int {
	if e.client_size_uses_viewport() {
		return int(e.document().viewport_rect().height)
	}
	mut document := unsafe { &Document(e.document()) }
	document.update_layout(.element_client_height)
	layout := e.as_node().layout_node() or { return 0 }
	if !client_size_has_committed_box(layout) {
		return 0
	}
	return int((layout.content_height_ + layout.box_model().padding_top + layout.box_model().padding_bottom) / e.document().layout_coordinate_scale())
}

// https://drafts.csswg.org/cssom-view/#dom-element-currentcsszoom
pub fn (e &Element) current_css_zoom() f64 {
	return 1.0
}

// --- Layout node ---
pub fn (e &Element) el_layout_node() ?&LayoutNodeWithStyle_ {
	return e.layout_node_with_style_
}

pub fn (e &Element) el_unsafe_layout_node() ?&LayoutNodeWithStyle_ {
	return e.layout_node_with_style_
}

pub fn (e &Element) create_layout_node(style &CSSComputedProperties_) ?&LayoutNodeWithStyle_ {
	// The full C++ implementation selects concrete Layout node subclasses from the
	// computed display type. The V layout tree is still a stub, so preserve the
	// observable "display: none" and scripting-enabled noscript checks.
	if e.local_name() == 'noscript' && e.document().is_scripting_enabled() {
		return none
	}
	display := style.display()
	return create_layout_node_for_display_type(e.document(), display, style, e)
}

pub fn create_layout_node_for_display_type(document &Document, display CSSDisplay_, style &CSSComputedProperties_, element &Element) ?&LayoutNodeWithStyle_ {
	_ = document
	if display.is_none() {
		return none
	}
	kind := if display.is_table_inside() || display.is_table_row_group()
		|| display.is_table_header_group() || display.is_table_footer_group()
		|| display.is_table_row() {
		LayoutNodeKind.box
	} else if display.is_list_item() {
		LayoutNodeKind.list_item_box
	} else if display.is_table_cell() || display.is_table_column()
		|| display.is_table_column_group() || display.is_table_caption()
		|| display.is_math_inside() {
		LayoutNodeKind.block_container
	} else if display.is_inline_outside() {
		if display.is_flow_root_inside() {
			LayoutNodeKind.block_container
		} else if display.is_flow_inside() {
			LayoutNodeKind.inline_node
		} else if display.is_flex_inside() || display.is_grid_inside() {
			LayoutNodeKind.box
		} else {
			LayoutNodeKind.inline_node
		}
	} else if display.is_flex_inside() || display.is_grid_inside() {
		LayoutNodeKind.box
	} else if display.is_flow_inside() || display.is_flow_root_inside() || display.is_contents()
		|| display.is_ruby_inside() {
		LayoutNodeKind.block_container
	} else {
		LayoutNodeKind.inline_node
	}
	return &LayoutNodeWithStyle_{
		layout_node_: &LayoutNode{
			dom_node_: element.as_node()
			display_: display
		}
		applied_properties_: style
		kind_: kind
	}
}

pub fn (e &Element) paintable_box() ?&PaintableBox {
	return e.as_node().paintable_box()
}

// --- Style / Computed properties ---
pub fn (e &Element) el_computed_properties() ?&CSSComputedProperties_ {
	return e.computed_properties_
}

pub fn (e &Element) has_pending_font_input_update() bool {
	return e.font_environment_changed_
}

// Font inputs do not invalidate selector/cascade inputs. Keep their pending
// state separate so a simultaneous ordinary style mutation still wins.
pub fn (mut e Element) set_pending_font_input_update(value bool) {
	if e.font_environment_changed_ == value { return }
	e.font_environment_changed_ = value
	if !value { return }
	mut node := e.as_node()
	node.set_child_needs_style_update(true)
	for ancestor := node.parent_or_shadow_host(); ancestor != none; {
		mut current := unsafe { &Node(ancestor or { break }) }
		current.set_child_needs_style_update(true)
		ancestor = current.parent_or_shadow_host()
	}
	if e.document() != unsafe { nil } {
		mut document := unsafe { &Document(e.document()) }
		document.record_style_invalidation()
		document.mark_needs_repaint(.no)
	}
}

pub fn (e &Element) computed_properties_for_pseudo(pseudo_element ?int) ?&CSSComputedProperties_ {
	if pe := pseudo_element {
		if pseudo := e.get_pseudo_element(pe) {
			return pseudo.computed_properties()
		}
		return none
	}
	return e.computed_properties_
}

pub fn (mut e Element) set_computed_properties(pseudo_element ?int, style ?&CSSComputedProperties_) {
	if pe := pseudo_element {
		if s := style {
			mut pseudo := e.ensure_pseudo_element(pe)
			pseudo.set_computed_properties(s)
		} else if existing := e.get_pseudo_element(pe) {
			unsafe {
				existing.computed_props = none
			}
		}
		return
	}
	if e.is_connected() {
		old_names := if old_style := e.computed_properties_ {
			old_style.anchor_names()
		} else {
			[]string{}
		}
		new_names := if new_style := style {
			new_style.anchor_names()
		} else {
			[]string{}
		}
		update_anchor_name_map_for_root(e.as_node().root(), old_names, new_names, &e)
	}
	e.computed_properties_ = style
}

// The native embedder reconstructs history from markup after closing the old
// script runtime. Its discarded document no longer needs resolved styles.
pub fn (mut e Element) discard_native_computed_properties() {
	e.computed_properties_ = none
	if e.rare_data_ != unsafe { nil } {
		for _, mut pseudo in e.rare_data_.pseudo_element_data {
			pseudo.computed_props = none
		}
	}
}

pub fn (e &Element) get_pseudo_element(typ int) ?&PseudoElement_ {
	// Optional map lookup creates an error object on every miss in the
	// compatibility compiler. Most elements have no requested pseudo-element.
	if e.rare_data_ == unsafe { nil } || typ !in e.rare_data_.pseudo_element_data { return none }
	return unsafe { e.rare_data_.pseudo_element_data[typ] }
}

fn (mut e Element) ensure_pseudo_element(typ int) &PseudoElement_ {
	mut data := e.ensure_rare_data()
	if existing := data.pseudo_element_data[typ] {
		return existing
	}
	pe := &PseudoElement_{}
	data.pseudo_element_data[typ] = pe
	return pe
}

pub fn (e &Element) has_pseudo_element(typ int) bool {
	pe := e.get_pseudo_element(typ) or { return false }
	return pe.layout_node() != none
}

pub fn (e &Element) has_pseudo_elements() bool {
	if e.rare_data_ == unsafe { nil } { return false }
	for _, pe in e.rare_data_.pseudo_element_data {
		if pe.layout_node() != none {
			return true
		}
	}
	return false
}

pub fn (mut e Element) clear_pseudo_element_nodes() {
	if e.rare_data_ == unsafe { nil } { return }
	for _, mut pe in e.rare_data_.pseudo_element_data {
		pe.set_layout_node(none)
	}
}

pub fn (mut e Element) clear_pseudo_element_layout_nodes() {
	e.clear_pseudo_element_nodes()
}

pub fn (mut e Element) set_pseudo_element_node(pseudo_element int, node ?&LayoutNodeWithStyle_) {
	if node != none {
		mut pe := e.ensure_pseudo_element(pseudo_element)
		pe.set_layout_node(node)
	} else if existing := e.get_pseudo_element(pseudo_element) {
		// Layout clears synthetic ownership before rebuilding an element. A
		// missing pseudo has no layout node to clear and needs no rare data.
		// Preserve an existing record's computed style when its box disappears.
		mut pe := unsafe { &PseudoElement_(existing) }
		pe.set_layout_node(none)
	}
}

pub fn (e &Element) get_pseudo_element_node(pseudo_element int) ?&LayoutNodeWithStyle_ {
	pe := e.get_pseudo_element(pseudo_element) or { return none }
	return pe.layout_node()
}

// --- Inline style ---
pub fn (e &Element) el_inline_style() ?&CSSStyleProperties_ {
	return e.inline_style_
}

pub fn (mut e Element) set_inline_style(style ?&CSSStyleProperties_) {
	e.inline_style_ = style
	if e.cached_attribute_style_map() != none {
		mut state := e.copy_binding_data()
		state.attribute_style_map = none
		e.binding_data_ = state
	}
	mut node := unsafe { &Node(&e) }
	node.set_needs_style_update(true)
}

// https://drafts.csswg.org/cssom/#dom-elementcssinlinestyle-style
pub fn (mut e Element) style_for_bindings() &CSSStyleProperties_ {
	if s := e.inline_style_ {
		return s
	}
	new_style := create_element_inline_style(&e)
	e.inline_style_ = new_style
	return new_style
}

pub fn (mut e Element) el_attribute_style_map() &StylePropertyMap_ {
	if m := e.cached_attribute_style_map() {
		return m
	}
	new_map := create_style_property_map_for_bindings(e.style_for_bindings())
	mut state := e.copy_binding_data()
	state.attribute_style_map = new_map
	e.binding_data_ = state
	return new_map
}

// https://www.w3.org/TR/css-typed-om-1/#dom-element-attributestylemap
pub fn (mut e Element) attribute_style_map() &StylePropertyMap_ {
	return e.el_attribute_style_map()
}

// --- Custom property data ---
pub fn (mut e Element) set_custom_property_data(pseudo_element ?int, data ?&CSSCustomPropertyData_) {
	if pe := pseudo_element {
		if d := data {
			mut pseudo := e.ensure_pseudo_element(pe)
			pseudo.set_custom_property_data(d)
		} else if existing := e.get_pseudo_element(pe) {
			unsafe {
				existing.custom_prop_data = none
			}
		}
		return
	}
	e.custom_property_data_ = data
}

pub fn (e &Element) custom_property_data(pseudo_element ?int) ?&CSSCustomPropertyData_ {
	if pe := pseudo_element {
		pe_data := e.get_pseudo_element(pe) or { return none }
		return pe_data.custom_property_data()
	}
	return e.custom_property_data_
}

// --- run_attribute_change_steps ---
pub fn (mut e Element) run_attribute_change_steps(local_name string, old_value ?string, value ?string, namespace_ ?string) {
	if e.as_node().is_html_base_element() {
		mut base := unsafe { &HTMLBaseElement(&e) }
		base.attribute_changed(local_name, old_value, value, namespace_)
	} else if e.as_node().is_html_meta_element() {
		mut meta := unsafe { &HTMLMetaElement(&e) }
		meta.attribute_changed(local_name, old_value, value, namespace_)
	} else {
		e.attribute_changed(local_name, old_value, value, namespace_)
	}
	if namespace_ == none && e.is_html_element() && e.local_name() == 'option'
		&& local_name == 'label' {
		option := unsafe { &HTMLOptionElement(&e) }
		if hook := option.label_changed_hook_ {
			hook(option)
		}
	}
	if namespace_ == none && e.is_html_element() && e.local_name() == 'track'
		&& to_ascii_lowercase(local_name) in ['kind', 'label', 'srclang', 'src', 'id'] {
		track := unsafe { &HTMLTrackElement(&e) }
		if hook := track.track_attribute_changed_hook_ {
			hook(track, local_name, value)
		}
	}
	if namespace_ == none && e.is_html_element() && e.local_name() == 'video'
		&& local_name == 'poster' {
		video := unsafe { &HTMLVideoElement(&e) }
		if hook := video.video_poster_attribute_changed_hook_ {
			hook(video, value)
		}
	}
	if !option_string_equal(old_value, value) {
		e.invalidate_style_after_attribute_change(local_name, old_value, value)
	}
}

// --- recompute_style ---
pub fn (mut e Element) recompute_style() RequiredInvalidationAfterStyleChange {
	style_computer := e.document().style_computer()
	if style_computer.css_handle == unsafe { nil }
		|| style_computer.recompute_style_callback == unsafe { nil } {
		return RequiredInvalidationAfterStyleChange{}
	}
	return style_computer.recompute_style_callback(style_computer.css_handle, &e)
}

pub fn (mut e Element) reset_style_dependency_flags() {
	e.style_uses_attr_css_function = false
	e.style_uses_var_css_function = false
	e.style_uses_tree_counting_function = false
	e.style_uses_if_css_function = false
	e.style_uses_inherit_css_function = false
	e.style_depends_on_size_container_query_ = false
	e.style_depends_on_container_relative_units_ = false
	e.style_depends_on_style_container_query_ = false
}

pub fn (mut e Element) set_style_uses_attr_css_function() {
	e.style_uses_attr_css_function = true
}

pub fn (mut e Element) set_style_uses_var_css_function() {
	e.style_uses_var_css_function = true
}

pub fn (mut e Element) set_style_uses_if_css_function() {
	e.style_uses_if_css_function = true
}

pub fn (mut e Element) set_style_uses_inherit_css_function() {
	e.style_uses_inherit_css_function = true
}

pub fn (e &Element) style_depends_on_size_container_query() bool {
	return e.style_depends_on_size_container_query_
}

pub fn (mut e Element) set_style_depends_on_size_container_query() {
	e.style_depends_on_size_container_query_ = true
}

pub fn (e &Element) style_depends_on_container_relative_units() bool {
	return e.style_depends_on_container_relative_units_
}

pub fn (mut e Element) set_style_depends_on_container_relative_units() {
	e.style_depends_on_size_container_query_ = true
	e.style_depends_on_container_relative_units_ = true
}

pub fn (e &Element) style_depends_on_style_container_query() bool {
	return e.style_depends_on_style_container_query_
}

pub fn (mut e Element) set_style_depends_on_style_container_query() {
	e.style_depends_on_style_container_query_ = true
}

pub fn (mut e Element) invalidate_descendant_styles_depending_on_style_container_query() {
	if !e.is_style_query_container_ {
		return
	}
	mut document := unsafe { &Document(e.document()) }
	document.record_style_query_container_scan()
	e.as_node().for_each_shadow_including_descendant(fn (node &Node) TraversalDecision {
		if element := node.as_element() {
			if element.style_depends_on_style_container_query() {
				mut mutable_element := unsafe { &Element(element) }
				mutable_element.set_needs_style_update(true)
			}
		}
		return .@continue
	})
}

pub fn (e &Element) is_style_query_container() bool {
	return e.is_style_query_container_
}

pub fn (mut e Element) set_is_style_query_container() {
	e.is_style_query_container_ = true
}

pub fn (mut e Element) refresh_inherited_custom_property_data() bool {
	mut parent_data := ?&CSSCustomPropertyData_(none)
	if parent := e.element_to_inherit_style_from(none) {
		if data := parent.custom_property_data(none) {
			parent_data = data.inheritable(e.document())
		}
	}
	current_data := e.custom_property_data_
	if current := current_data {
		if current.is_animation_overlay() {
			if optional_custom_property_data_identical(current.parent, parent_data) {
				return false
			}
			e.custom_property_data_ = CSSCustomPropertyData_.create_animation_overlay(current.own_values,
				parent_data)
			return true
		}
	}
	if optional_custom_property_data_identical(current_data, parent_data) {
		return false
	}
	e.custom_property_data_ = parent_data
	return true
}

pub fn (e &Element) is_size_query_container() bool {
	return e.is_size_query_container_
}

pub fn (mut e Element) set_is_size_query_container() {
	e.is_size_query_container_ = true
}

pub fn (e &Element) style_uses_attr_css_function() bool {
	return e.style_uses_attr_css_function
}

pub fn (e &Element) style_uses_var_css_function() bool {
	return e.style_uses_var_css_function
}

pub fn (e &Element) style_uses_if_css_function() bool {
	return e.style_uses_if_css_function
}

pub fn (e &Element) style_uses_inherit_css_function() bool {
	return e.style_uses_inherit_css_function
}

// --- recompute_inherited_style ---
pub fn (mut e Element) recompute_inherited_style() RequiredInvalidationAfterStyleChange {
	style_computer := e.document().style_computer()
	if style_computer.css_handle == unsafe { nil }
		|| style_computer.recompute_inherited_style_callback == unsafe { nil } {
		return RequiredInvalidationAfterStyleChange{}
	}
	return style_computer.recompute_inherited_style_callback(style_computer.css_handle, &e)
}

// --- Inner/Outer HTML ---

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-element-innerhtml
pub fn (mut e Element) set_inner_html(value string) ! {
	compliant_string := e.document().trusted_types_compliant_html(value, 'element-inner-html')!
	mut node := unsafe { &Node(&e) }
	node.unsafely_set_html(&e, compliant_string)!
	node.set_needs_style_update(true)
	if node.is_connected() {
		node.set_needs_layout_tree_update(true, .element_set_inner_html)
	}
}

pub fn (e &Element) inner_html() !string {
	return e.as_node().serialize_fragment(.yes, .inner)
}

pub fn (e &Element) outer_html() !string {
	return e.as_node().serialize_fragment(.yes, .outer)
}

pub fn (mut e Element) set_outer_html(value string) ! {
	compliant_string := e.document().trusted_types_compliant_html(value, 'element-outer-html')!
	parent := e.as_node().parent() or { return }
	if parent.is_document() {
		return error('NoModificationAllowedError: Cannot set outer HTML on document')
	}
	mut context := ?&Element(none)
	if parent.is_document_fragment() {
		context = create_element(e.document(), 'body', namespace_html_, none, none, false)!
	} else {
		context = parent.as_element()
	}
	context_element := context or {
		return error('NoModificationAllowedError: Cannot set outer HTML without an element context')
	}

	fragment := parse_fragment_fallback(context_element, compliant_string)!
	mut mutable_parent := unsafe { &Node(parent) }
	mutable_parent.replace_child(fragment.as_node(), e.as_node())!
}

// https://html.spec.whatwg.org/multipage/dom.html#dom-innertext (the setter)
// Set the element's contents to `input` as rendered text: each run of characters that are not a line
// break becomes a Text node, and each line break (LF, CR, or a CRLF pair) becomes a `<br>` element.
// The resulting fragment replaces all of the element's children.
pub fn (mut e Element) set_inner_text(input string) {
	doc := e.document()
	// 1. Build the rendered text fragment.
	frag := doc.create_document_fragment()
	mut fragment_node := unsafe { &Node(frag) }
	mut i := 0
	for i < input.len {
		// Collect a run of characters that are not U+000A LF or U+000D CR.
		start := i
		for i < input.len && input[i] != `\n` && input[i] != `\r` {
			i++
		}
		if i > start {
			fragment_node.append_child(doc.create_text_node(input[start..i]).as_node()) or {}
		}
		// Each following line break becomes a <br> (a CRLF pair counts as a single break).
		for i < input.len && (input[i] == `\n` || input[i] == `\r`) {
			if input[i] == `\r` && i + 1 < input.len && input[i + 1] == `\n` {
				i++
			}
			i++
			br := doc.create_element_ns(namespace_html_, 'br') or { continue }
			fragment_node.append_child(br.as_node()) or {}
		}
	}
	// 2. Replace all within the element with the fragment.
	mut node := unsafe { &Node(&e) }
	node.replace_all(fragment_node)
	node.set_needs_style_update(true)
}

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-element-sethtmlunsafe
pub fn (mut e Element) set_html_unsafe(html string) ! {
	compliant_html := e.document().trusted_types_compliant_html(html, 'element-set-html-unsafe')!
	mut node := unsafe { &Node(&e) }
	node.unsafely_set_html(&e, compliant_html)!
}

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-element-gethtml
pub fn (e &Element) get_html(options GetHTMLOptions) !string {
	serializable_shadow_roots := if options.serializable_shadow_roots {
		SerializableShadowRoots.yes
	} else {
		.no
	}
	return html_parser_serialize_html_fragment(e.as_node(), serializable_shadow_roots, []&ShadowRoot{}, .inner)
}

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#the-insertadjacenthtml()-method
pub fn (mut e Element) insert_adjacent_html(position string, text string) ! {
	compliant_string := e.document().trusted_types_compliant_html(text, 'element-insert-adjacent-html')!
	lower_pos := to_ascii_lowercase(position)
	if lower_pos !in ['beforebegin', 'afterbegin', 'beforeend', 'afterend'] {
		return error('SyntaxError: insertAdjacentHTML: invalid position argument')
	}
	mut context_node := ?&Node(none)
	if lower_pos in ['beforebegin', 'afterend'] {
		parent := e.as_node().parent() or {
			return error('NoModificationAllowedError: insertAdjacentHTML: context is null or a Document')
		}
		if parent.is_document() {
			return error('NoModificationAllowedError: insertAdjacentHTML: context is null or a Document')
		}
		context_node = unsafe { &Node(parent) }
	} else {
		context_node = unsafe { &Node(e.as_node()) }
	}
	context := context_node or { return }
	mut context_element := context.as_element()
	if context_element == none {
		context_element = create_element(e.document(), 'body', namespace_html_, none, none, false)!
	} else if element := context_element {
		if element.document().document_type() == .html && element.local_name() == 'html' && element.namespace_uri() or {
			''
		} == namespace_html_ {
			context_element = create_element(e.document(), 'body', namespace_html_, none, none, false)!
		}
	}
	element_context := context_element or { return }
	fragment := parse_fragment_fallback(element_context, compliant_string)!
	match lower_pos {
		'beforebegin' {
			parent := e.as_node().parent() or { return }
			mut mutable_parent := unsafe { &Node(parent) }
			mutable_parent.insert_before(fragment.as_node(), e.as_node(), false)
		}
		'afterbegin' {
			mut node := unsafe { &Node(&e) }
			node.insert_before(fragment.as_node(), e.as_node().first_child(), false)
		}
		'beforeend' {
			mut node := unsafe { &Node(&e) }
			node.append_child(fragment.as_node())!
		}
		'afterend' {
			parent := e.as_node().parent() or { return }
			mut mutable_parent := unsafe { &Node(parent) }
			mutable_parent.insert_before(fragment.as_node(), e.as_node().next_sibling(), false)
		}
		else {}
	}
}

fn html_parser_parse_html_fragment(context_element &Element, markup string, allow_declarative_shadow_roots AllowDeclarativeShadowRoots, scripting_mode ParserScriptingMode) ![]&Node {
	if hook := context_element.document().html_fragment_parsing_hook() {
		if hook.parse_fragment != unsafe { nil } {
			return hook.parse_fragment(hook.target, context_element, markup, allow_declarative_shadow_roots, scripting_mode)
		}
	}
	// DOM can be used without importing the html module. In that configuration there is no HTML
	// tree builder to call, so preserve the markup as text rather than silently dropping it.
	if markup.len == 0 {
		return []&Node{}
	}
	return [new_text_node(context_element.document(), markup).as_node()]
}

fn xml_fragment_parser_parse_xml_fragment(context_element &Element, markup string, allow_declarative_shadow_roots AllowDeclarativeShadowRoots, scripting_mode ParserScriptingMode) ![]&Node {
	if hook := context_element.document().html_fragment_parsing_hook() {
		if hook.parse_xml_fragment != unsafe { nil } {
			return hook.parse_xml_fragment(hook.target, context_element, markup, allow_declarative_shadow_roots, scripting_mode)
		}
	}
	return error('InvalidStateError: the XML fragment parser hook is not installed for this document')
}

fn append_nodes_to_new_fragment(document &Document, new_children []&Node) !&DocumentFragment {
	fragment := new_document_fragment(document)
	mut fragment_node := unsafe { &Node(fragment.as_node()) }
	for child in new_children {
		fragment_node.append_child(child)!
	}
	return fragment
}

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#fragment-parsing-algorithm-steps
pub fn (e &Element) parse_fragment(markup string) !&DocumentFragment {
	return e.parse_fragment_with_scripting_mode(markup, .inert)
}

pub fn (e &Element) parse_fragment_with_scripting_mode(markup string, scripting_mode ParserScriptingMode) !&DocumentFragment {
	// 1. Let algorithm be the HTML fragment parsing algorithm.
	// 2. If context's node document is an XML document, then set algorithm to the XML fragment parsing algorithm.
	new_children := if e.document().is_xml_document() {
		xml_fragment_parser_parse_xml_fragment(e, markup, .no, scripting_mode)!
	} else {
		html_parser_parse_html_fragment(e, markup, .no, scripting_mode)!
	}

	// 4. Let fragment be a new DocumentFragment whose node document is context's node document.
	// 5. For each node of newChildren, in tree order: append node to fragment.
	// 6. Return fragment.
	return append_nodes_to_new_fragment(e.document(), new_children)
}

fn parse_fragment_fallback(context_element &Element, html string) !&DocumentFragment {
	return context_element.parse_fragment(html)
}

fn html_escape_text(value string) string {
	return value.replace('&', '&amp;').replace(' ', '&nbsp;').replace('<', '&lt;').replace('>', '&gt;')
}

fn html_escape_attribute(value string) string {
	return html_escape_text(value).replace('"', '&quot;')
}

fn html_serialized_tag_name(element &Element) string {
	namespace_ := element.namespace_uri() or { '' }
	if namespace_ in [namespace_html_uri, namespace_svg_uri, 'http://www.w3.org/1998/Math/MathML'] {
		return element.local_name()
	}
	return element.qualified_name_str()
}

fn html_serialized_attribute_name(attribute &Attr_) string {
	namespace_ := attribute.namespace_uri_ or { return attribute.local_name_ }
	return match namespace_ {
		namespace_xml_uri {
			'xml:${attribute.local_name_}'
		}
		namespace_xmlns_uri {
			if attribute.local_name_ == 'xmlns' {
				'xmlns'
			} else {
				'xmlns:${attribute.local_name_}'
			}
		}
		namespace_xlink_uri {
			'xlink:${attribute.local_name_}'
		}
		else {
			attribute.name_
		}
	}
}

fn serialize_element_start_tag(mut builder strings.Builder, element &Element) string {
	tag_name := html_serialized_tag_name(element)
	builder.write_string('<')
	builder.write_string(tag_name)
	if is_value := element.custom_element_is_value() {
		if !element.has_attribute('is') {
			builder.write_string(' is="')
			builder.write_string(html_escape_attribute(is_value))
			builder.write_string('"')
		}
	}
	if attrs := element.attributes_ {
		for attr in attrs.attrs {
			builder.write_string(' ')
			builder.write_string(html_serialized_attribute_name(attr))
			builder.write_string('="')
			builder.write_string(html_escape_attribute(attr.value()))
			builder.write_string('"')
		}
	}
	builder.write_string('>')
	return tag_name
}

fn serialize_html_node(node &Node, serializable_shadow_roots SerializableShadowRoots, shadow_roots []&ShadowRoot, mode FragmentSerializationMode) string {
	if node.is_comment() {
		comment := node.character_data() or { return '' }
		return '<!--${comment.data()}-->'
	}
	if processing_instruction := node.as_processing_instruction() {
		return '<?${processing_instruction.target()} ${processing_instruction.data()}>'
	}
	if document_type := node.as_document_type() {
		return '<!DOCTYPE ${document_type.name()}>'
	}
	if attr := node.as_attr() {
		return html_escape_attribute(attr.value())
	}
	if node.is_text() || node.is_cdata_section() {
		character_data := node.character_data() or { return '' }
		if parent := node.parent() {
			if parent_element := parent.as_element() {
				name := parent_element.local_name()
				if name in ['style', 'script', 'xmp', 'iframe', 'noembed', 'noframes', 'plaintext'] || (name == 'noscript' && !node.is_scripting_disabled()) {
					return character_data.data()
				}
			}
		}
		return html_escape_text(character_data.data())
	}
	if element := node.as_element() {
		mut builder := strings.new_builder(0)
		if mode == .outer {
			tag_name := serialize_element_start_tag(mut builder, element)
			if element.serializes_as_void() {
				return builder.str()
			}
			builder.write_string(serialize_html_node(node, serializable_shadow_roots, shadow_roots, .inner))
			builder.write_string('</${tag_name}>')
			return builder.str()
		}

		actual_node := if element.is_html_element() && element.local_name() == 'template' {
			template_element := unsafe { &HTMLTemplateElement(element) }
			template_element.content().as_node()
		} else {
			node
		}

		if shadow_root := element.shadow_root() {
			mut explicitly_included := false
			for candidate in shadow_roots {
				if voidptr(candidate) == voidptr(shadow_root) {
					explicitly_included = true
					break
				}
			}
			if (serializable_shadow_roots == .yes && shadow_root.serializable()) || explicitly_included {
				mode_name := if shadow_root.mode() == .open { 'open' } else { 'closed' }
				builder.write_string('<template shadowrootmode="${mode_name}"')
				if shadow_root.delegates_focus() {
					builder.write_string(' shadowrootdelegatesfocus=""')
				}
				if shadow_root.serializable() {
					builder.write_string(' shadowrootserializable=""')
				}
				if shadow_root.clonable() {
					builder.write_string(' shadowrootclonable=""')
				}
				document_registry := shadow_root.document().custom_element_registry()
				shadow_registry := shadow_root.custom_element_registry()
				if !((document_registry == unsafe { nil } && shadow_registry == unsafe { nil })
					|| (is_a_global_custom_element_registry(document_registry)
						&& is_a_global_custom_element_registry(shadow_registry))) {
					builder.write_string(' shadowrootcustomelementregistry=""')
				}
				builder.write_string('>')
				builder.write_string(serialize_html_node(shadow_root_as_node(shadow_root), serializable_shadow_roots, shadow_roots, .inner))
				builder.write_string('</template>')
			}
		}

		for child in actual_node.children {
			builder.write_string(serialize_html_node(child, serializable_shadow_roots, shadow_roots, .outer))
		}
		return builder.str()
	}
	mut builder := strings.new_builder(0)
	for child in node.children {
		builder.write_string(serialize_html_node(child, serializable_shadow_roots, shadow_roots, .outer))
	}
	return builder.str()
}

fn html_parser_serialize_html_fragment(node &Node, serializable_shadow_roots SerializableShadowRoots, shadow_roots []&ShadowRoot, fragment_serialization_mode FragmentSerializationMode) string {
	_ = serializable_shadow_roots
	_ = shadow_roots
	return serialize_html_node(node, serializable_shadow_roots, shadow_roots, fragment_serialization_mode)
}

fn html_serialize_node_to_xml_string(node &Node, require_well_formed RequireWellFormed) !string {
	mut state := XMLSerializationState{}
	return serialize_xml_node(node, require_well_formed, map[string]string{}, mut state)
}

struct XMLSerializationState {
mut:
	next_generated_prefix int = 1
}

fn xml_escape_text(value string) string {
	return value.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
}

fn xml_escape_attribute(value string) string {
	return value.replace('&', '&amp;').replace('"', '&quot;').replace('\t', '&#9;').replace('\n', '&#10;').replace('\r', '&#13;').replace('<', '&lt;')
}

fn xml_data_is_well_formed(value string) bool {
	for ch in value.runes() {
		if ch == 0 || ch in [rune(0xfffe), rune(0xffff)] {
			return false
		}
	}
	return true
}

fn xml_qualified_name(prefix ?string, local_name string) string {
	if actual_prefix := prefix {
		if actual_prefix.len > 0 {
			return '${actual_prefix}:${local_name}'
		}
	}
	return local_name
}

fn serialize_xml_node(node &Node, require_well_formed RequireWellFormed, inherited_namespaces map[string]string, mut state XMLSerializationState) !string {
	if node.is_document() || node.is_document_fragment() || node.is_shadow_root() {
		mut builder := strings.new_builder(0)
		for child in node.children {
			builder.write_string(serialize_xml_node(child, require_well_formed, inherited_namespaces, mut state)!)
		}
		return builder.str()
	}
	if element := node.as_element() {
		return serialize_xml_element(element, require_well_formed, inherited_namespaces, mut state)
	}
	if character_data := node.as_character_data() {
		data := character_data.data()
		if require_well_formed == .yes && !xml_data_is_well_formed(data) {
			return error('InvalidStateError: Character data is not well-formed XML')
		}
		if node.is_comment() {
			if require_well_formed == .yes && (data.contains('--') || data.ends_with('-')) {
				return error('InvalidStateError: Comment is not well-formed XML')
			}
			return '<!--${data}-->'
		}
		if node.is_cdata_section() {
			if require_well_formed == .yes && data.contains(']]>') {
				return error('InvalidStateError: CDATA section is not well-formed XML')
			}
			return '<![CDATA[${data}]]>'
		}
		if processing_instruction := node.as_processing_instruction() {
			if require_well_formed == .yes && (to_ascii_lowercase(processing_instruction.target_) == 'xml' || data.contains('?>')) {
				return error('InvalidStateError: Processing instruction is not well-formed XML')
			}
			return if data.len > 0 {
				'<?${processing_instruction.target_} ${data}?>'
			} else {
				'<?${processing_instruction.target_}?>'
			}
		}
		return xml_escape_text(data)
	}
	if document_type := node.as_document_type() {
		mut result := '<!DOCTYPE ${document_type.name()}'
		if document_type.public_id().len > 0 {
			result += ' PUBLIC "${xml_escape_attribute(document_type.public_id())}"'
			if document_type.system_id().len > 0 {
				result += ' "${xml_escape_attribute(document_type.system_id())}"'
			}
		} else if document_type.system_id().len > 0 {
			result += ' SYSTEM "${xml_escape_attribute(document_type.system_id())}"'
		}
		return result + '>'
	}
	return ''
}

fn serialize_xml_element(element &Element, require_well_formed RequireWellFormed, inherited_namespaces map[string]string, mut state XMLSerializationState) !string {
	mut namespaces := inherited_namespaces.clone()
	mut attributes := if attrs := element.attributes_ { attrs.attrs.clone() } else { []&Attr_{} }
	mut declared_here := map[string]bool{}
	for attribute in attributes {
		if option_string_equal(attribute.namespace_uri_, namespace_xmlns_uri) {
			prefix := if attribute.prefix__ or { '' } == 'xmlns' {
				attribute.local_name_
			} else {
				''
			}
			namespaces[prefix] = attribute.value_
			declared_here[prefix] = true
		}
	}

	mut generated_declarations := []string{}
	element_namespace := element.namespace_uri() or { '' }
	element_prefix := element.prefix()
	element_prefix_key := element_prefix or { '' }
	if element_namespace.len > 0 && namespaces[element_prefix_key] != element_namespace {
		declaration_name := if element_prefix_key.len > 0 {
			'xmlns:${element_prefix_key}'
		} else {
			'xmlns'
		}
		generated_declarations << '${declaration_name}="${xml_escape_attribute(element_namespace)}"'
		namespaces[element_prefix_key] = element_namespace
		declared_here[element_prefix_key] = true
	} else if element_namespace.len == 0 && (namespaces[''] or { '' }).len > 0 {
		generated_declarations << 'xmlns=""'
		namespaces[''] = ''
		declared_here[''] = true
	}

	mut serialized_attributes := []string{}
	for attribute in attributes {
		attribute_namespace := attribute.namespace_uri_ or { '' }
		mut attribute_prefix := attribute.prefix__
		if attribute_namespace == namespace_xmlns_uri {
			serialized_attributes << '${attribute.name_}="${xml_escape_attribute(attribute.value_)}"'
			continue
		}
		if attribute_namespace == namespace_xml_uri {
			attribute_prefix = 'xml'
			namespaces['xml'] = namespace_xml_uri
		} else if attribute_namespace == namespace_xlink_uri {
			attribute_prefix = 'xlink'
			if namespaces['xlink'] != namespace_xlink_uri && !declared_here['xlink'] {
				generated_declarations << 'xmlns:xlink="${namespace_xlink_uri}"'
				namespaces['xlink'] = namespace_xlink_uri
				declared_here['xlink'] = true
			}
		} else if attribute_namespace.len > 0 {
			mut prefix_key := attribute_prefix or { '' }
			if prefix_key.len == 0 {
				for {
					prefix_key = 'ns${state.next_generated_prefix}'
					state.next_generated_prefix++
					if prefix_key !in namespaces {
						break
					}
				}
				attribute_prefix = prefix_key
			}
			if namespaces[prefix_key] != attribute_namespace && !declared_here[prefix_key] {
				generated_declarations << 'xmlns:${prefix_key}="${xml_escape_attribute(attribute_namespace)}"'
				namespaces[prefix_key] = attribute_namespace
				declared_here[prefix_key] = true
			}
		}
		attribute_name := xml_qualified_name(attribute_prefix, attribute.local_name_)
		serialized_attributes << '${attribute_name}="${xml_escape_attribute(attribute.value_)}"'
	}

	qualified_name := xml_qualified_name(element_prefix, element.local_name())
	mut builder := strings.new_builder(0)
	builder.write_string('<${qualified_name}')
	for declaration in generated_declarations {
		builder.write_string(' ${declaration}')
	}
	for attribute in serialized_attributes {
		builder.write_string(' ${attribute}')
	}
	builder.write_string('>')
	for child in element.as_node().children {
		builder.write_string(serialize_xml_node(child, require_well_formed, namespaces, mut state)!)
	}
	builder.write_string('</${qualified_name}>')
	return builder.str()
}

// --- Focus / Active ---
pub fn (e &Element) is_focused() bool {
	return e.document().focused_area() or { return false } == e.as_node()
}

pub fn (e &Element) is_the_active_element() bool {
	return e.document().active_element() or { return false } == e
}

pub fn (e &Element) is_being_activated() bool {
	return e.is_being_activated_
}

// Kept for compatibility with callers that used the V-prefixed accessor.
pub fn (e &Element) el_is_being_activated() bool {
	return e.is_being_activated()
}

pub fn (mut e Element) set_being_activated(active bool) {
	if e.is_being_activated_ == active {
		return
	}
	e.is_being_activated_ = active
	mut node := unsafe { &Node(&e) }
	// CSS::Invalidation::invalidate_style_after_active_state_change records the
	// changed pseudo-class instead of invalidating every descendant. Pointer
	// input activates the whole ancestor chain, including html and body.
	if e.document().style_computer().invalidation_plan_callback == unsafe { nil } {
		node.invalidate_style(.element_set_active)
		return
	}
	node.invalidate_style_with_properties(.element_set_active, [
		InvalidationProperty{ type_: .pseudo_class, pseudo_class_name: 'active' },
	], StyleInvalidationOptions{ invalidate_self: true })
}

pub fn (e &Element) is_target() bool {
	doc := e.document()
	if doc == unsafe { nil } {
		return false
	}
	return doc.target_element() or { return false } == e
}

pub fn (e &Element) is_document_element() bool {
	doc := e.document()
	if doc == unsafe { nil } {
		return false
	}
	root := doc.document_element() or { return false }
	return voidptr(root) == voidptr(e)
}

// --- Void elements ---
pub fn (e &Element) is_void_element() bool {
	name := e.local_name()
	return name in ['area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta',
		'param', 'source', 'track', 'wbr']
}

pub fn (e &Element) serializes_as_void() bool {
	return e.is_void_element() || e.local_name() in ['basefont', 'bgsound', 'frame', 'keygen']
}

// --- Bounding rects ---

fn bounding_rect_from_client_rects(list []CSSPixelRect_) Rect {
	// 2. If the list is empty return a DOMRect object whose x, y, width and height members are zero.
	if list.len == 0 {
		return Rect{}
	}

	// 3. If all rectangles in list have zero width or height, return the first rectangle in list.
	mut all_rectangle_has_zero_width_or_height := true
	for rect in list {
		if rect.width() != 0 && rect.height() != 0 {
			all_rectangle_has_zero_width_or_height = false
			break
		}
	}
	first := list[0]
	if all_rectangle_has_zero_width_or_height {
		return Rect{
			x: first.x_
			y: first.y_
			width: first.width_
			height: first.height_
		}
	}

	// 4. Otherwise, return a DOMRect object describing the smallest rectangle that includes all of the rectangles in
	//    list of which the height or width is not zero.
	mut left := first.x_
	mut top := first.y_
	mut right := first.x_ + first.width_
	mut bottom := first.y_ + first.height_
	for i := 1; i < list.len; i++ {
		rect := list[i]
		if rect.width() == 0 || rect.height() == 0 {
			continue
		}
		if rect.x_ < left {
			left = rect.x_
		}
		if rect.y_ < top {
			top = rect.y_
		}
		if rect.x_ + rect.width_ > right {
			right = rect.x_ + rect.width_
		}
		if rect.y_ + rect.height_ > bottom {
			bottom = rect.y_ + rect.height_
		}
	}
	return Rect{
		x: left
		y: top
		width: right - left
		height: bottom - top
	}
}

// https://drafts.csswg.org/cssom-view/#dom-element-getboundingclientrect
pub fn (e &Element) get_bounding_client_rect() Rect {
	// 1. Let list be the result of invoking getClientRects() on element.
	return bounding_rect_from_client_rects(e.get_client_rects())
}

fn compute_client_rects_assuming_layout_clean(e &Element) []CSSPixelRect_ {
	layout := e.as_node().layout_node() or { return [] }
	if !layout.has_geometry_ {
		return []
	}
	rects := [
		CSSPixelRect_{
			x_: layout.border_box_.x
			y_: layout.border_box_.y
			width_: layout.border_box_.width
			height_: layout.border_box_.height
		},
	]
	if paintable := e.document().unsafe_paintable() {
		return paintable.transform_client_rects(e.as_node(), rects)
	}
	return rects
}

pub fn (e &Element) get_client_rects() []CSSPixelRect_ {
	mut document := unsafe { &Document(e.document()) }
	document.update_layout(.element_get_client_rects)
	document.update_paint_and_hit_testing_properties_if_needed()
	return compute_client_rects_assuming_layout_clean(e)
}

pub fn (e &Element) client_rects_assuming_layout_clean() []CSSPixelRect_ {
	return compute_client_rects_assuming_layout_clean(e)
}

pub fn (e &Element) bounding_client_rect_assuming_layout_clean() Rect {
	return bounding_rect_from_client_rects(e.client_rects_assuming_layout_clean())
}

// https://drafts.csswg.org/cssom-view/#dom-element-getboundingclientrect
// Bindings counterpart of `get_bounding_client_rect`. The V port lacks the
// IDL DOMRect type, so the existing `Rect` is returned directly.
pub fn (e &Element) get_bounding_client_rect_for_bindings() Rect {
	return e.get_bounding_client_rect()
}

// https://drafts.csswg.org/cssom-view/#dom-element-getclientrects
// Bindings counterpart of `get_client_rects`. The V port lacks the IDL
// DOMRectList type, so a slice of `CSSPixelRect_` is returned directly.
pub fn (e &Element) get_client_rects_for_bindings() []CSSPixelRect_ {
	return e.get_client_rects()
}

// --- Tab index ---
fn parse_html_integer(value string) ?int {
	mut index := 0
	for index < value.len && is_ascii_whitespace(value[index]) {
		index++
	}
	if index >= value.len {
		return none
	}

	mut sign := 1
	if value[index] == `-` {
		sign = -1
		index++
	} else if value[index] == `+` {
		index++
	}
	if index >= value.len || value[index] < `0` || value[index] > `9` {
		return none
	}

	mut result := 0
	for index < value.len && value[index] >= `0` && value[index] <= `9` {
		result = result * 10 + int(value[index] - `0`)
		index++
	}
	return sign * result
}

pub fn (e &Element) default_tab_index_value() int {
	if e.is_html_element() && e.local_name() in ['iframe', 'object'] {
		return 0
	}
	return -1
}

// https://html.spec.whatwg.org/multipage/interaction.html#dom-tabindex
pub fn (e &Element) tab_index() int {
	tab_index := parse_html_integer(e.get_attribute_value('tabindex')) or {
		return e.default_tab_index_value()
	}
	return tab_index
}

pub fn (mut e Element) set_tab_index(tab_index int) {
	e.set_attribute_value('tabindex', tab_index.str())
}

// --- Scrolling ---
pub enum TreatOverflowClipOnBodyParentAsOverflowHidden {
	no
	yes
}

fn overflow_value_makes_box_a_scroll_container(value CSSOverflow_) bool {
	return value in [.hidden, .scroll, .auto_]
}

fn (e &Element) document_window() ?&Window {
	doc := e.document()
	if doc == unsafe { nil } {
		return none
	}
	return doc.get_window()
}

fn (e &Element) is_document_body_element(document &Document) bool {
	body := document.body() or { return false }
	return unsafe { &Element(body) } == e
}

// https://drafts.csswg.org/cssom-view/#potentially-scrollable
pub fn (e &Element) is_potentially_scrollable() bool {
	return e.is_potentially_scrollable_with_overflow_clip_treatment(.no)
}

pub fn (e &Element) is_potentially_scrollable_with_overflow_clip_treatment(treat_overflow_clip_on_body_parent_as_overflow_hidden TreatOverflowClipOnBodyParentAsOverflowHidden) bool {
	// NOTE: Ensure that layout is up-to-date before looking at metrics.
	mut document := unsafe { &Document(e.document()) }
	document.update_layout(.element_is_potentially_scrollable)

	// An element body (which will be the body element) is potentially scrollable if all of the following conditions are true:
	// - body has an associated box.
	if e.el_layout_node() == none {
		return false
	}

	// - body's parent element's computed value of the overflow-x or overflow-y properties is neither visible nor clip.
	parent := e.as_node().parent_element() or { return false }
	parent_properties := parent.el_computed_properties() or { return false }
	if parent_properties.overflow_x() == .visible || parent_properties.overflow_y() == .visible {
		return false
	}
	// NOTE: When treating 'overflow:clip' as 'overflow:hidden', we can never fail this condition.
	if treat_overflow_clip_on_body_parent_as_overflow_hidden == .no && (parent_properties.overflow_x() == .clip || parent_properties.overflow_y() == .clip) {
		return false
	}

	// - body's computed value of the overflow-x or overflow-y properties is neither visible nor clip.
	computed_properties := e.el_computed_properties() or { return false }
	if computed_properties.overflow_x() in [.visible, .clip] || computed_properties.overflow_y() in [
		.visible,
		.clip,
	] {
		return false
	}

	return true
}

pub fn (e &Element) is_scroll_container() bool {
	// NB: We should only call this if we know that computed_properties has already been computed.
	if e.is_document_element() {
		return true
	}
	computed_properties := e.el_computed_properties() or { return false }
	return overflow_value_makes_box_a_scroll_container(computed_properties.overflow_x()) || overflow_value_makes_box_a_scroll_container(computed_properties.overflow_y())
}

// https://drafts.csswg.org/cssom-view/#dom-element-scrolltop
pub fn (e &Element) scroll_top() f64 {
	// 1. Let document be the element's node document.
	doc := e.document()

	// 2. If document is not the active document, return zero and terminate these steps.
	if doc == unsafe { nil } || !doc.is_active() {
		return 0.0
	}

	// 3. Let window be the value of document's defaultView attribute.
	// FIXME: The specification expects defaultView to be a Window object, but defaultView actually returns a WindowProxy object.
	window := e.document_window() or { return 0.0 }

	// 5. If the element is the root element and document is in quirks mode, return zero and terminate these steps.
	if e.is_document_element() && doc.in_quirks_mode() {
		return 0.0
	}

	// 6. If the element is the root element return the value of scrollY on window.
	if e.is_document_element() {
		return window.scroll_y()
	}

	// NOTE: Ensure that layout is up-to-date before looking at metrics.
	mut document := unsafe { &Document(doc) }
	document.update_layout(.element_scroll_top)

	// 7. If the element is the body element, document is in quirks mode, and the element is not potentially scrollable, return the value of scrollY on window.
	if e.is_document_body_element(doc) && doc.in_quirks_mode() && !e.is_potentially_scrollable() {
		return window.scroll_y()
	}

	// 8. If the element does not have any associated box, return zero and terminate these steps.
	if pb := e.paintable_box() {
		// 9. Return the y-coordinate of the scrolling area at the alignment point with the top of the padding edge of the element.
		// FIXME: Is this correct?
		return pb.scroll_offset().y()
	}
	return 0.0
}

// https://drafts.csswg.org/cssom-view/#dom-element-scrollleft
pub fn (e &Element) scroll_left() f64 {
	// 1. Let document be the element's node document.
	doc := e.document()

	// 2. If document is not the active document, return zero and terminate these steps.
	if doc == unsafe { nil } || !doc.is_active() {
		return 0.0
	}

	// 3. Let window be the value of document's defaultView attribute.
	// FIXME: The specification expects defaultView to be a Window object, but defaultView actually returns a WindowProxy object.
	window := e.document_window() or { return 0.0 }

	// 5. If the element is the root element and document is in quirks mode, return zero and terminate these steps.
	if e.is_document_element() && doc.in_quirks_mode() {
		return 0.0
	}

	// 6. If the element is the root element return the value of scrollX on window.
	if e.is_document_element() {
		return window.scroll_x()
	}

	// NOTE: Ensure that layout is up-to-date before looking at metrics.
	mut document := unsafe { &Document(doc) }
	document.update_layout(.element_scroll_left)

	// 7. If the element is the body element, document is in quirks mode, and the element is not potentially scrollable, return the value of scrollX on window.
	if e.is_document_body_element(doc) && doc.in_quirks_mode() && !e.is_potentially_scrollable() {
		return window.scroll_x()
	}

	// 8. If the element does not have any associated box, return zero and terminate these steps.
	if pb := e.paintable_box() {
		// 9. Return the x-coordinate of the scrolling area at the alignment point with the left of the padding edge of the element.
		// FIXME: Is this correct?
		return pb.scroll_offset().x()
	}
	return 0.0
}

// https://drafts.csswg.org/cssom-view/#dom-element-scrollleft
pub fn (mut e Element) set_scroll_left(x_ f64) {
	// 1. Let x be the given value.

	// 2. Normalize non-finite values for x.
	x := normalize_non_finite(x_)

	// 3. Let document be the element's node document.
	doc := e.document()

	// 4. If document is not the active document, terminate these steps.
	if doc == unsafe { nil } || !doc.is_active() {
		return
	}

	// 5. Let window be the value of document's defaultView attribute.
	// FIXME: The specification expects defaultView to be a Window object, but defaultView actually returns a WindowProxy object.
	mut window := e.document_window() or { return }

	// 7. If the element is the root element and document is in quirks mode, terminate these steps.
	if e.is_document_element() && doc.in_quirks_mode() {
		return
	}

	// 8. If the element is the root element invoke scroll() on window with x as first argument and scrollY on window as second argument, and terminate these steps.
	if e.is_document_element() {
		window.scroll(x, window.scroll_y())
		return
	}

	// NOTE: Ensure that layout is up-to-date before looking at metrics or scrolling the page.
	mut document := unsafe { &Document(doc) }
	document.update_layout(.element_set_scroll_left)

	// 9. If the element is the body element, document is in quirks mode, and the element is not potentially scrollable, invoke scroll() on window with x as first argument and scrollY on window as second argument, and terminate these steps.
	if e.is_document_body_element(doc) && doc.in_quirks_mode() && !e.is_potentially_scrollable() {
		window.scroll(x, window.scroll_y())
		return
	}

	// 10. If the element does not have any associated box, the element has no associated scrolling box, or the element has no overflow, terminate these steps.
	if mut pb := e.paintable_box() {
		if !e.is_scroll_container() {
			return
		}

		// FIXME: or the element has no overflow.

		mut offset := pb.scroll_offset()
		offset.set_x(x)
		if navigable := doc.cached_navigable() {
			navigable.perform_a_scroll_of_an_element(&e, offset, .auto_, ScrollSnapSelectionStrategy_{})
		} else { pb.set_scroll_offset(offset) }
	}
}

// https://drafts.csswg.org/cssom-view/#dom-element-scrolltop
pub fn (mut e Element) set_scroll_top(y_ f64) {
	// 1. Let y be the given value.

	// 2. Normalize non-finite values for y.
	y := normalize_non_finite(y_)

	// 3. Let document be the element's node document.
	doc := e.document()

	// 4. If document is not the active document, terminate these steps.
	if doc == unsafe { nil } || !doc.is_active() {
		return
	}

	// 5. Let window be the value of document's defaultView attribute.
	// FIXME: The specification expects defaultView to be a Window object, but defaultView actually returns a WindowProxy object.
	mut window := e.document_window() or { return }

	// 7. If the element is the root element and document is in quirks mode, terminate these steps.
	if e.is_document_element() && doc.in_quirks_mode() {
		return
	}

	// 8. If the element is the root element invoke scroll() on window with scrollX on window as first argument and y as second argument, and terminate these steps.
	if e.is_document_element() {
		window.scroll(window.scroll_x(), y)
		return
	}

	// NOTE: Ensure that layout is up-to-date before looking at metrics or scrolling the page.
	mut document := unsafe { &Document(doc) }
	document.update_layout(.element_set_scroll_top)

	// 9. If the element is the body element, document is in quirks mode, and the element is not potentially scrollable, invoke scroll() on window with scrollX as first argument and y as second argument, and terminate these steps.
	if e.is_document_body_element(doc) && doc.in_quirks_mode() && !e.is_potentially_scrollable() {
		window.scroll(window.scroll_x(), y)
		return
	}

	// 10. If the element does not have any associated box, the element has no associated scrolling box, or the element has no overflow, terminate these steps.
	if mut pb := e.paintable_box() {
		if !e.is_scroll_container() {
			return
		}

		// FIXME: or the element has no overflow.

		mut offset := pb.scroll_offset()
		offset.set_y(y)
		if navigable := doc.cached_navigable() {
			navigable.perform_a_scroll_of_an_element(&e, offset, .auto_, ScrollSnapSelectionStrategy_{})
		} else { pb.set_scroll_offset(offset) }
	}
}

// https://drafts.csswg.org/cssom-view/#dom-element-scrollwidth
pub fn (mut e Element) scroll_width() int {
	doc := e.document()
	if doc == unsafe { nil } || !doc.is_active() {
		return 0
	}
	if pb := e.paintable_box() {
		if r := pb.scrollable_overflow_rect() {
			return int(r.width())
		}
	}
	if layout := e.as_node().layout_node() {
		if layout.has_geometry_ {
			return int((layout.content_width_ + layout.box_model().padding_left + layout.box_model().padding_right) / e.document().layout_coordinate_scale())
		}
	}
	return 0
}

// https://drafts.csswg.org/cssom-view/#dom-element-scrollheight
pub fn (mut e Element) scroll_height() int {
	doc := e.document()
	if doc == unsafe { nil } || !doc.is_active() {
		return 0
	}
	if pb := e.paintable_box() {
		if r := pb.scrollable_overflow_rect() {
			return int(r.height())
		}
	}
	if layout := e.as_node().layout_node() {
		if layout.has_geometry_ {
			return int((layout.content_height_ + layout.box_model().padding_top + layout.box_model().padding_bottom) / e.document().layout_coordinate_scale())
		}
	}
	return 0
}

fn normalize_non_finite(v f64) f64 {
	if math.is_nan(v) || math.is_inf(v, 0) {
		return 0.0
	}
	return v
}

// https://drafts.csswg.org/cssom-view/#dom-element-scroll
pub fn (mut e Element) el_scroll(x_ f64, y_ f64) &Promise {
	return e.el_scroll_with_options(ScrollToOptions_{left: x_, top: y_})
}

pub fn (mut e Element) el_scroll_with_options(options ScrollToOptions_) &Promise {
	return e.el_scroll_with_snap_strategy(options.left or { e.scroll_left() }, options.top or { e.scroll_top() }, options.behavior, none)
}

fn (mut e Element) el_scroll_with_snap_strategy(x_ f64, y_ f64, behavior ScrollBehavior,
	snap_strategy ?ScrollSnapSelectionStrategy_) &Promise {
	x := normalize_non_finite(x_)
	y := normalize_non_finite(y_)
	doc := e.document()
	if doc == unsafe { nil } || !doc.is_active() {
		return Promise.resolved(js_undefined())
	}
	mut window := e.document_window() or { return Promise.resolved(js_undefined()) }
	if e.is_document_element() && doc.in_quirks_mode() {
		return Promise.resolved(js_undefined())
	}
	if x == 0 && y == 0 && e.el_scroll_offset().is_zero() && !e.is_document_body_element(doc)
		&& !e.is_document_element() {
		mut document := unsafe { &Document(doc) }
		document.update_style()
		if computed := e.el_computed_properties() {
			if computed.scroll_snap_strictness_none_ { return Promise.resolved(js_undefined()) }
		} else { return Promise.resolved(js_undefined()) }
	}
	mut document := unsafe { &Document(doc) }
	document.update_layout(.element_scroll)
	if e.is_document_element() {
		return window.scroll_with_options(x, y, behavior, snap_strategy or { ScrollSnapSelectionStrategy_{} })
	}
	if e.is_document_body_element(doc) && doc.in_quirks_mode() && !e.is_potentially_scrollable() {
		return window.scroll_with_options(x, y, behavior, snap_strategy or { ScrollSnapSelectionStrategy_{} })
	}
	layout_node := e.as_node().layout_node() or { return Promise.resolved(js_undefined()) }
	if !layout_node.is_scroll_container_ { return Promise.resolved(js_undefined()) }
	if navigable := doc.cached_navigable() {
		return navigable.perform_a_scroll_of_an_element(&e, CSSPixelPoint_{x_: x, y_: y}, behavior, snap_strategy or { ScrollSnapSelectionStrategy_{} })
	}
	// Detached translated DOM fixtures use their retained paintable directly.
	if mut pb := e.paintable_box() {
		mut offset := pb.scroll_offset()
		offset.set_x(x)
		offset.set_y(y)
		if strategy := snap_strategy {
			pb.set_scroll_offset_with_snap_strategy(offset, strategy)
		} else {
			pb.set_scroll_offset(offset)
		}
	}
	return Promise.resolved(js_undefined())
}

pub fn (mut e Element) scroll_by(x_ f64, y_ f64) &Promise {
	return e.scroll_by_with_options(ScrollToOptions_{left: x_, top: y_})
}

pub fn (mut e Element) scroll_by_with_options(options ScrollToOptions_) &Promise {
	x := normalize_non_finite(options.left or { 0 })
	y := normalize_non_finite(options.top or { 0 })
	start := CSSPixelPoint_{ x_: e.scroll_left(), y_: e.scroll_top() }
	return e.el_scroll_with_snap_strategy(start.x() + x, start.y() + y, options.behavior,
		ScrollSnapSelectionStrategy_{
			type_: .end_position_and_direction
			start_offset: start
			displacement: CSSPixelPoint_{ x_: x, y_: y }
		})
}

pub fn (e &Element) el_scroll_offset() CSSPixelPoint_ {
	return e.interactive_scroll_offset()
}

pub fn (e &Element) snapped_scroll_areas_x() []ScrollSnapAreaReference_ {
	if e.interactive_data_ == unsafe { nil } { return []ScrollSnapAreaReference_{} }
	return e.interactive_data_.snapped_scroll_areas_x_.clone()
}

pub fn (e &Element) snapped_scroll_areas_y() []ScrollSnapAreaReference_ {
	if e.interactive_data_ == unsafe { nil } { return []ScrollSnapAreaReference_{} }
	return e.interactive_data_.snapped_scroll_areas_y_.clone()
}

pub fn (mut e Element) set_snapped_scroll_areas(x []ScrollSnapAreaReference_,
	y []ScrollSnapAreaReference_) {
	if x.len == 0 && y.len == 0 && (e.interactive_data_ == unsafe { nil }
		|| (e.interactive_data_.snapped_scroll_areas_x_.len == 0 && e.interactive_data_.snapped_scroll_areas_y_.len == 0)) { return }
	mut state := e.copy_interactive_data()
	state.snapped_scroll_areas_x_ = x.clone()
	state.snapped_scroll_areas_y_ = y.clone()
	e.interactive_data_ = state
}

// https://w3c.github.io/csswg-drafts/cssom-view-1/#dom-element-scrollintoview
pub fn (mut e Element) scroll_into_view() &Promise {
	return e.scroll_into_view_with_options(ScrollIntoViewOptions{})
}

// --- Fullscreen ---

// https://fullscreen.spec.whatwg.org/#dom-element-requestfullscreen
pub fn (mut e Element) request_fullscreen(requester FullscreenRequester) &Promise {
	mut promise := Promise.create()
	mut doc := e.document()
	if doc == unsafe { nil } || !doc.is_fully_active() {
		promise.reject(js_string('TypeError: Document not fully active.'))
		return promise
	}
	operation_error := e.is_element_allowed_to_enter_fullscreen(requester)
	if operation_error != .false_ {
		promise.reject(js_string('TypeError: Element is not allowed to enter fullscreen (${operation_error}).'))
		return promise
	}

	// Ladybird queues the platform fullscreen-enter operation here. Until the V
	// embedder provides that queue, perform its observable DOM effects at this
	// typed boundary and settle the promise synchronously.
	doc.fullscreen_element_within_doc(mut e)
	doc.append_pending_fullscreen_change(.change, e)
	doc.run_fullscreen_steps()
	promise.resolve(js_undefined())
	return promise
}

pub fn (e &Element) is_element_allowed_to_enter_fullscreen(requester FullscreenRequester) RequestFullscreenError {
	// This's namespace is the HTML namespace or this is an SVG svg element.
	namespace_ := e.namespace_uri() or { '' }
	is_mathml_math := namespace_ == 'http://www.w3.org/1998/Math/MathML'
		&& e.local_name() == 'math'
	if !(namespace_ == namespace_html_uri || e.is_svg_svg_element() || is_mathml_math) {
		return .unsupported_element
	}

	// This is not a dialog element.
	if e.is_html_element() && e.local_name() == 'dialog' {
		return .unsupported_element
	}

	// The fullscreen element ready check for this returns true.
	if !e.is_element_ready_for_fullscreen() {
		return .element_ready_check_failed
	}

	// FIXME: Handle user-generated orientation changes, as upstream does.
	// WebDriver deliberately bypasses transient activation.
	if requester != .web_driver {
		window := e.document().window
		if window == unsafe { nil } || !window.has_transient_activation() {
			return .no_transient_user_activation
		}
	}
	return .false_
}

pub fn (e &Element) is_element_ready_for_fullscreen() bool {
	// A fullscreen element ready check requires the element to be connected.
	if !e.is_connected() {
		return false
	}

	// The node document must be allowed to use the "fullscreen" feature.
	if !e.document().is_allowed_to_use_feature(.fullscreen) {
		return false
	}

	// If the element is in the HTML namespace, the C++ implementation also checks
	// that the element's popover visibility state is hidden. Popover state is not
	// represented in this port; the default HTML element state is hidden.
	return true
}

pub fn (mut e Element) set_fullscreen_flag(v bool) {
	e.fullscreen_flag = v
}

pub fn (e &Element) is_fullscreen_element() bool {
	return e.fullscreen_flag
}

pub fn (e &Element) in_top_layer() bool {
	return e.in_top_layer
}

pub fn (mut e Element) set_in_top_layer(value bool) {
	e.in_top_layer = value
}

pub fn (e &Element) rendered_in_top_layer() bool {
	return e.rendered_in_top_layer
}

pub fn (mut e Element) set_rendered_in_top_layer(value bool) {
	e.rendered_in_top_layer = value
}

fn (mut e Element) exit_fullscreen_on_element_removal() {
	// 1. Let document be removedNode's node document.
	mut document := unsafe { &Document(e.document()) }

	// 2. Let nodes be removedNode's shadow-including inclusive descendants that
	//    have their fullscreen flag set, in shadow-including tree order.
	mut fullscreen_elements := []&Element{}
	fullscreen_elements_ptr := &fullscreen_elements
	e.as_node().visit_shadow_including_inclusive_descendants(fn [fullscreen_elements_ptr] (node &Node) TraversalDecision {
		element := node.as_element() or { return .@continue }
		if element.is_fullscreen_element() {
			dom_ptr_push(fullscreen_elements_ptr, element)
		}
		return .@continue
	})

	// 3. For each node in nodes:
	for mut element in fullscreen_elements {
		// 1. If node is document's fullscreen element, exit fullscreen document.
		if fullscreen_element := document.fullscreen_element() {
			if voidptr(fullscreen_element) == voidptr(element) {
				document.exit_fullscreen()
			} else {
				// 2. Otherwise, unfullscreen node.
				document.unfullscreen_element(mut element)
			}
		} else {
			document.unfullscreen_element(mut element)
		}

		// 3. If document's top layer contains node, remove from the top layer immediately given node.
		if element.in_top_layer() {
			document.remove_an_element_from_the_top_layer_immediately(element)
		}
	}
}

// --- Actually disabled ---
fn (e &Element) is_html_element_with_local_name(name string) bool {
	return e.is_html_element() && e.local_name() == name
}

fn (e &Element) first_ancestor_fieldset_element() ?&Element {
	for ancestor := e.as_node().parent(); ancestor != none;  {
		current := ancestor or { break }
		if element := current.as_element() {
			if element.is_html_element_with_local_name('fieldset') {
				return element
			}
		}
		ancestor = current.parent()
	}
	return none
}

fn (e &Element) first_legend_element_child() ?&Element {
	for child in e.as_node().children {
		if element := child.as_element() {
			if element.is_html_element_with_local_name('legend') {
				return element
			}
		}
	}
	return none
}

fn (e &Element) is_disabled_by_fieldset_ancestor() bool {
	for fieldset_ancestor := e.first_ancestor_fieldset_element(); fieldset_ancestor != none;  {
		fieldset := fieldset_ancestor or { break }
		if fieldset.has_attribute('disabled') {
			if legend := fieldset.first_legend_element_child() {
				if !e.as_node().is_descendant_of(legend.as_node()) {
					return true
				}
			} else {
				return true
			}
		}
		fieldset_ancestor = fieldset.first_ancestor_fieldset_element()
	}
	return false
}

fn (e &Element) form_control_enabled() bool {
	// https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#concept-fe-disabled
	// A form control is disabled if any of the following are true:
	// - The element is a button, input, select, textarea, or form-associated custom element, and the disabled attribute is specified on this element (regardless of its value); or
	// FIXME: This doesn't check for form-associated custom elements.
	if e.has_attribute('disabled') {
		return false
	}

	// - The element is a descendant of a fieldset element whose disabled attribute is specified, and is not a descendant of that fieldset element's first legend element child, if any.
	if e.is_disabled_by_fieldset_ancestor() {
		return false
	}

	return true
}

fn (e &Element) option_element_disabled() bool {
	// An option element is disabled if its disabled attribute is present or if it is a child of an optgroup element whose disabled attribute is present.
	if e.has_attribute('disabled') {
		return true
	}
	parent := e.as_node().parent() or { return false }
	parent_element := parent.as_element() or { return false }
	return parent_element.is_html_element_with_local_name('optgroup') && parent_element.has_attribute('disabled')
}

fn (e &Element) fieldset_element_disabled() bool {
	// A fieldset element is a disabled fieldset if it matches any of the following conditions:
	// - Its disabled attribute is specified
	if e.has_attribute('disabled') {
		return true
	}

	// - It is a descendant of another fieldset element whose disabled attribute is specified, and is not a descendant of that fieldset element's first legend element child, if any.
	return e.is_disabled_by_fieldset_ancestor()
}

// HTMLFormAssociatedElement is a C++ mixin rather than a DOM interface. Keep
// the corresponding membership test here so generic attribute changes can
// invalidate the live form-control paint state without depending on HTML.
fn (e &Element) is_form_associated_element() bool {
	return (e.is_html_element() && e.local_name() in ['button', 'fieldset', 'input', 'object',
		'output', 'select', 'textarea']) || e.is_form_associated_custom_element()
}

// https://html.spec.whatwg.org/multipage/semantics-other.html#concept-element-disabled
pub fn (e &Element) is_actually_disabled() bool {
	// An element is said to be actually disabled if it is one of the following:
	// - a button element that is disabled
	// - an input element that is disabled
	// - a select element that is disabled
	// - a textarea element that is disabled
	if e.is_html_element() && e.local_name() in ['button', 'input', 'select', 'textarea'] {
		return !e.form_control_enabled()
	}

	// - an optgroup element that has a disabled attribute
	if e.is_html_element_with_local_name('optgroup') {
		return e.has_attribute('disabled')
	}

	// - an option element that is disabled
	if e.is_html_element_with_local_name('option') {
		return e.option_element_disabled()
	}

	// - a fieldset element that is a disabled fieldset
	if e.is_html_element_with_local_name('fieldset') {
		return e.fieldset_element_disabled()
	}

	// FIXME: - a form-associated custom element that is disabled
	return false
}

// --- Insert adjacent ---
fn (mut e Element) insert_adjacent(where_ string, node &Node) !&Node {
	match to_ascii_lowercase(where_) {
		'beforebegin' {
			parent := e.as_node().parent() or { return unsafe { nil } }
			mut mutable_parent := unsafe { &Node(parent) }
			return mutable_parent.pre_insert(node, e.as_node())!
		}
		'afterbegin' {
			mut element_node := unsafe { &Node(e.as_node()) }
			return element_node.pre_insert(node, e.as_node().first_child())!
		}
		'beforeend' {
			mut element_node := unsafe { &Node(e.as_node()) }
			return element_node.pre_insert(node, none)!
		}
		'afterend' {
			parent := e.as_node().parent() or { return unsafe { nil } }
			mut mutable_parent := unsafe { &Node(parent) }
			return mutable_parent.pre_insert(node, e.as_node().next_sibling())!
		}
		else {
			return error("SyntaxError: Unknown position '${where_}'. Must be one of 'beforebegin', 'afterbegin', 'beforeend' or 'afterend'")
		}
	}
}

pub fn (mut e Element) insert_adjacent_element(where_ string, element &Element) !&Element {
	returned_node := e.insert_adjacent(where_, element.as_node())!
	if returned_node == unsafe { nil } {
		return unsafe { nil }
	}
	return returned_node.as_element() or { unsafe { nil } }
}

pub fn (mut e Element) insert_adjacent_text(where_ string, data string) ! {
	text := new_text_node(e.document(), data)
	e.insert_adjacent(where_, text.as_node())!
}

// --- check_visibility ---

// https://drafts.csswg.org/cssom-view-1/#dom-element-checkvisibility
pub fn (e &Element) check_visibility(options ?CheckVisibilityOptions) bool {
	// NOTE: Ensure that layout is up-to-date before looking at metrics.
	mut document := unsafe { &Document(e.document()) }
	document.update_layout_if_needed_for_node(e.as_node(), .element_check_visibility)

	// 1. If this does not have an associated box, return false.
	if e.paintable_box() == none {
		return false
	}

	// 2. If an ancestor of this in the flat tree has content-visibility: hidden, return false.
	mut ancestor := e.as_node().flat_tree_parent_element()
	for ancestor != none {
		element := ancestor or { break }
		if computed_properties := element.el_computed_properties() {
			if computed_properties.content_visibility() == .hidden {
				return false
			}
		}
		ancestor = element.as_node().flat_tree_parent_element()
	}

	// AD-HOC: Since the rest of the steps use the options, we can return early if we haven't been given any options.
	opts := options or { return true }

	// 3. If either the opacityProperty or the checkOpacity dictionary members of options are true, and this, or an
	//    ancestor of this in the flat tree, has a computed opacity value of 0, return false.
	if opts.opacity_property || opts.check_opacity {
		mut element_or_ancestor := ?&Element(e)
		for element_or_ancestor != none {
			element := element_or_ancestor or { break }
			if computed_properties := element.el_computed_properties() {
				if computed_properties.opacity() == 0.0 {
					return false
				}
			}
			element_or_ancestor = element.as_node().flat_tree_parent_element()
		}
	}

	// 4. If either the visibilityProperty or the checkVisibilityCSS dictionary members of options are true, and this
	//    is invisible, return false.
	if opts.visibility_property || opts.check_visibility_css {
		if computed_properties := e.el_computed_properties() {
			if computed_properties.visibility() == .hidden {
				return false
			}
		}
	}

	// 5. If the contentVisibilityAuto dictionary member of options is true and an ancestor of this in the flat tree
	//    skips its contents due to content-visibility: auto, return false.
	// FIXME: Currently we do not skip any content if content-visibility is auto: https://drafts.csswg.org/css-contain-2/#proximity-to-the-viewport
	skipped_contents_due_to_content_visibility_auto := false
	if opts.content_visibility_auto && skipped_contents_due_to_content_visibility_auto {
		mut parent_element := e.as_node().flat_tree_parent_element()
		for parent_element != none {
			element := parent_element or { break }
			if computed_properties := element.el_computed_properties() {
				if computed_properties.content_visibility() == .auto_ {
					return false
				}
			}
			parent_element = element.as_node().flat_tree_parent_element()
		}
	}

	// 6. Return true.
	return true
}

// --- Intersection observers ---
pub fn (mut e Element) register_intersection_observer(observer voidptr) {
	mut state := e.copy_dependency_data()
	state.intersection_observers = state.intersection_observers.clone()
	state.intersection_observers << observer
	e.dependency_data_ = state
}

pub fn (mut e Element) unregister_intersection_observer(observer voidptr) {
	if !e.has_registered_intersection_observer(observer) { return }
	mut state := e.copy_dependency_data()
	state.intersection_observers = state.intersection_observers.filter(it != observer)
	e.dependency_data_ = state
}

pub fn (e &Element) has_registered_intersection_observer(observer voidptr) bool {
	return observer in e.intersection_observers()
}

// --- Custom elements ---
fn (mut e Element) enqueue_an_element_on_the_appropriate_element_queue() {
	// 1. Let reactionsStack be element's relevant agent's custom element reactions stack.
	// 2. If reactionsStack is empty, add element to reactionsStack's backup element queue.
	// The current V port has no HTML agent or microtask queue, so the backup queue
	// is stored on the node document and processed by future custom-element runtime wiring.
	mut document := unsafe { &Document(e.document()) }
	document.enqueue_custom_element_reaction_element(e)
}

// Mirrors the C++ Element::ensure_custom_element_reaction_queue() accessor.
// The optional queue publishes a snapshot; mutation goes through the dedicated
// enqueue helpers so Element value copies retain their own queue membership.
pub fn (e &Element) ensure_custom_element_reaction_queue() []CustomElementReaction {
	if e.custom_data_ == unsafe { nil } { return []CustomElementReaction{} }
	return e.custom_data_.reactions.clone()
}

// Bindings/MainThreadVM's invoke-custom-element-reactions algorithm consumes
// the queue. Keep mutation at the DOM boundary instead of exposing the backing
// slice to another module.
pub fn (mut e Element) take_custom_element_reactions() []CustomElementReaction {
	reactions := e.ensure_custom_element_reaction_queue()
	if reactions.len == 0 { return reactions }
	mut state := e.copy_custom_data()
	state.reactions = []CustomElementReaction{}
	e.custom_data_ = state
	return reactions
}

// https://html.spec.whatwg.org/multipage/custom-elements.html#enqueue-a-custom-element-upgrade-reaction
pub fn (mut e Element) enqueue_a_custom_element_upgrade_reaction(definition &CustomElementDefinition) {
	mut state := e.copy_custom_data()
	state.reactions = state.reactions.clone()
	state.reactions << CustomElementUpgradeReaction{
		custom_element_definition: definition
	}
	e.custom_data_ = state
	e.enqueue_an_element_on_the_appropriate_element_queue()
}

// https://html.spec.whatwg.org/multipage/custom-elements.html#enqueue-a-custom-element-callback-reaction
pub fn (mut e Element) enqueue_a_custom_element_callback_reaction(callback_name string, arguments []string) {
	_ = callback_name
	mut state := e.copy_custom_data()
	state.reactions = state.reactions.clone()
	state.reactions << CustomElementCallbackReaction{
		arguments: arguments.clone()
	}
	e.custom_data_ = state
	e.enqueue_an_element_on_the_appropriate_element_queue()
}

pub fn (mut e Element) ensure_custom_state_set() &CustomStateSet {
	if cs := e.custom_state_set() {
		return cs
	}
	new_cs := CustomStateSet.create(&e)
	mut state := e.copy_custom_data()
	state.state_set = new_cs
	e.custom_data_ = state
	return new_cs
}

pub fn (e &Element) custom_state_set() ?&CustomStateSet {
	if e.custom_data_ == unsafe { nil } { return none }
	return e.custom_data_.state_set
}

pub fn (e &Element) custom_element_definition() ?&CustomElementDefinition {
	if e.custom_data_ == unsafe { nil } { return none }
	return e.custom_data_.definition
}

// https://dom.spec.whatwg.org/#element-custom-element-registry
pub fn (e &Element) custom_element_registry() voidptr {
	return e.custom_element_registry_
}

pub fn (mut e Element) set_custom_element_registry(registry voidptr) {
	e.custom_element_registry_ = registry
}

pub fn (mut e Element) set_custom_element_definition(definition ?&CustomElementDefinition) {
	if definition == none && e.custom_element_definition() == none { return }
	mut state := e.copy_custom_data()
	state.definition = definition
	e.custom_data_ = state
}

pub fn (e &Element) is_form_associated_custom_element() bool {
	definition := e.custom_element_definition() or { return false }
	return e.custom_element_state_ == .custom && definition.form_associated()
}

pub fn (e &Element) popover_target_element() ?&Element {
	if e.interactive_data_ == unsafe { nil } { return none }
	return e.interactive_data_.popover_target_element_
}

pub fn (mut e Element) set_popover_target_element(value ?&Element) {
	if value == none && e.popover_target_element() == none { return }
	if target := value {
		if previous := e.popover_target_element() {
			if voidptr(target) == voidptr(previous) { return }
		}
	}
	mut state := e.copy_interactive_data()
	state.popover_target_element_ = value
	e.interactive_data_ = state
}











pub fn (mut element HTMLElement) set_subtree_inertness(is_inert bool) {
	element.set_inert(is_inert)
	element_node := unsafe { &Node(&element) }
	element_node.visit_subtree(fn [is_inert] (node &Node) TraversalDecision {
		descendant := node.as_element() or { return .@continue }
		if !descendant.is_html_element() {
			return .@continue
		}
		mut html_descendant := unsafe { &HTMLElement(descendant) }
		if descendant.has_attribute('inert') {
			return .skip_children_and_continue
		}
		html_descendant.set_inert(is_inert)
		return .@continue
	})
}







pub fn (element &HTMLElement) popover() ?string {
	return unsafe { &Element(element) }.get_attribute('popover')
}

pub fn (mut element HTMLElement) show_popover() ! {
	if element.popover() == none {
		return error('NotSupportedError: element does not have a popover attribute')
	}
	element.set_popover_visibility_state(.showing)
	mut base := unsafe { &Element(&element) }
	mut document := unsafe { &Document(base.document()) }
	document.add_an_element_to_the_top_layer(base)
}

pub fn (mut element HTMLElement) hide_popover() {
	element.set_popover_visibility_state(.hidden)
	mut base := unsafe { &Element(&element) }
	mut document := unsafe { &Document(base.document()) }
	document.remove_an_element_from_the_top_layer_immediately(base)
}

// https://html.spec.whatwg.org/multipage/custom-elements.html#concept-upgrade-an-element
pub fn (mut e Element) upgrade_element(definition &CustomElementDefinition) ! {
	if e.custom_element_state_ != .undefined_ && e.custom_element_state_ != .uncustomized {
		return
	}
	e.set_custom_element_definition(definition)
	e.set_custom_element_state(.failed)

	if attrs := e.attributes_ {
		for i := 0; i < attrs.length(); i++ {
			if a := attrs.item(i) {
				e.enqueue_a_custom_element_callback_reaction('attributeChangedCallback', [
					a.local_name_,
					'',
					a.value(),
					a.namespace_uri_ or { '' },
				])
			}
		}
	}

	if e.is_connected() {
		e.enqueue_a_custom_element_callback_reaction('connectedCallback', [])
	}

	e.set_custom_element_state(.custom)
}

// https://html.spec.whatwg.org/multipage/custom-elements.html#concept-try-upgrade
pub fn (mut e Element) try_to_upgrade() {
	definition := look_up_custom_element_definition(e.custom_element_registry(), e.namespace_uri(), e.local_name(), e.custom_element_is_value()) or { return }
	e.enqueue_a_custom_element_upgrade_reaction(definition)
}

// https://dom.spec.whatwg.org/#concept-element-defined
pub fn (e &Element) is_defined() bool {
	return e.custom_element_state_ == .uncustomized || e.custom_element_state_ == .custom
}

// https://dom.spec.whatwg.org/#concept-element-custom
pub fn (e &Element) is_custom() bool {
	return e.custom_element_state_ == .custom
}

pub fn (mut e Element) set_custom_element_state(state CustomElementState) {
	if e.custom_element_state_ == state {
		return
	}
	e.custom_element_state_ = state
}

// https://html.spec.whatwg.org/multipage/dom.html#html-element-constructors
pub fn (mut e Element) setup_custom_element_from_constructor(definition &CustomElementDefinition, is_value_ ?string) {
	e.set_custom_element_state(.custom)
	e.set_custom_element_definition(definition)
	e.set_is_value(is_value_)
}

pub fn (mut e Element) set_prefix(value ?string) {
	e.qualified_name.prefix_ = value
}

// https://dom.spec.whatwg.org/#locate-a-namespace-prefix
pub fn (e &Element) locate_a_namespace_prefix(namespace_ ?string) ?string {
	if option_string_equal(e.namespace_uri(), namespace_) {
		if p := e.prefix() {
			return p
		}
	}
	if attrs := e.attributes_ {
		for i := 0; i < attrs.length(); i++ {
			if a := attrs.item(i) {
				if (a.prefix__ or { '' }) == 'xmlns' && a.value() == namespace_ or { '' } {
					return a.local_name_
				}
			}
		}
	}
	if parent := e.as_node().parent_element() {
		return parent.locate_a_namespace_prefix(namespace_)
	}
	return none
}

pub fn (e &Element) for_each_attribute(callback fn (&Attr_)) {
	attrs := e.attributes_ or { return }
	for i := 0; i < attrs.length(); i++ {
		if a := attrs.item(i) {
			callback(a)
		}
	}
}

pub fn (e &Element) for_each_attribute_name_value(callback fn (string, string)) {
	attrs := e.attributes_ or { return }
	for i := 0; i < attrs.length(); i++ {
		if a := attrs.item(i) {
			callback(a.name(), a.value())
		}
	}
}

// --- Directionality ---
pub fn (e &Element) dir() ?Dir {
	return e.dir__
}

// https://html.spec.whatwg.org/multipage/dom.html#the-directionality
pub fn (e &Element) directionality() Directionality {
	if d := e.dir__ {
		match d {
			.ltr {
				return .ltr
			}
			.rtl {
				return .rtl
			}
			.auto_ {
				if result := e.auto_directionality() {
					return result
				}
				return .ltr
			}
		}
	}
	if e.local_name() == 'bdi' {
		if result := e.auto_directionality() {
			return result
		}
		return .ltr
	}
	if is_html_element_with_local_name(e, 'input') && to_ascii_lowercase(e.get_attribute_value('type')) == 'tel' {
		return .ltr
	}
	return e.parent_directionality()
}

fn (e &Element) auto_directionality() ?Directionality {
	if e.is_auto_directionality_form_associated_element() {
		value := if is_html_element_with_local_name(e, 'textarea') {
			e.as_node().text_content() or { '' }
		} else {
			e.get_attribute_value('value')
		}
		for r in value.runes() {
			code_point := u32(r)
			if is_ltr_code_point_for_directionality(code_point) {
				break
			}
			if is_rtl_code_point_for_directionality(code_point) {
				return .rtl
			}
		}
		if value.len == 0 {
			return .ltr
		}
		return none
	}

	if is_html_element_with_local_name(e, 'slot') && e.as_node().root().is_shadow_root() {
		slot := unsafe { &HTMLSlotElement(e) }
		assigned_nodes := slot.assigned_nodes()
		if assigned_nodes.len > 0 {
			for child in assigned_nodes {
				child_direction := if child.is_text() {
					unsafe { &Text(child) }.directionality()
				} else if child_element := child.as_element() {
					child_element.contained_text_auto_directionality(true)
				} else {
					?Directionality(none)
				}
				if direction := child_direction {
					return direction
				}
			}
			return none
		}
	}

	return e.contained_text_auto_directionality(false)
}

pub fn (e &Element) contained_text_auto_directionality(can_exclude_root bool) ?Directionality {
	if can_exclude_root && element_is_filtered_for_auto_directionality(e) {
		return none
	}
	return contained_text_auto_directionality_for_subtree(e.as_node(), e, can_exclude_root)
}

// https://html.spec.whatwg.org/multipage/dom.html#parent-directionality
pub fn (e &Element) parent_directionality() Directionality {
	parent := e.as_node().parent() or { return .ltr }
	if shadow_root := parent.as_shadow_root() {
		if shadow_root.host_ != unsafe { nil } {
			return shadow_root.host_.directionality()
		}
		return .ltr
	}
	if element := parent.as_element() {
		return element.directionality()
	}
	return .ltr
}

pub fn (e &Element) is_auto_directionality_form_associated_element() bool {
	if is_html_element_with_local_name(e, 'textarea') {
		return true
	}
	if !is_html_element_with_local_name(e, 'input') {
		return false
	}
	type_ := to_ascii_lowercase(e.get_attribute_value('type'))
	input_type := if type_.len == 0 { 'text' } else { type_ }
	return input_type in ['hidden', 'text', 'search', 'tel', 'url', 'email', 'password', 'submit',
		'reset', 'button']
}

// --- Translation mode ---
pub fn (e &Element) translation_mode() TranslationMode {
	if translate := e.get_attribute('translate') {
		val := to_ascii_lowercase(translate)
		if val == '' || val == 'yes' {
			return .translate_enabled
		}
		if val == 'no' {
			return .no_translate
		}
	}
	if parent := e.as_node().parent_element() {
		return parent.translation_mode()
	}
	return .translate_enabled
}

fn element_is_filtered_for_auto_directionality(element &Element) bool {
	return is_html_element_with_local_name(element, 'script') || is_html_element_with_local_name(element, 'style') || is_html_element_with_local_name(element, 'textarea') || element.dir() != none
}

fn descendant_is_filtered_for_auto_directionality(descendant &Node, root &Element, can_exclude_root bool) bool {
	if element := descendant.as_element() {
		if element_is_filtered_for_auto_directionality(element) {
			return true
		}
	}
	for ancestor := descendant.parent(); ancestor != none;  {
		current := ancestor or { break }
		if current == root.as_node() {
			if can_exclude_root && element_is_filtered_for_auto_directionality(root) {
				return true
			}
			break
		}
		if element := current.as_element() {
			if element_is_filtered_for_auto_directionality(element) {
				return true
			}
		}
		ancestor = current.parent()
	}
	return false
}

fn contained_text_auto_directionality_for_subtree(node &Node, root &Element, can_exclude_root bool) ?Directionality {
	for child in node.children {
		if descendant_is_filtered_for_auto_directionality(child, root, can_exclude_root) {
			continue
		}

		if child_element := child.as_element() {
			if is_html_element_with_local_name(child_element, 'slot') {
				if shadow_root := child.root().as_shadow_root() {
					if shadow_root.host_ != unsafe { nil } {
						return shadow_root.host_.directionality()
					}
				}
			}
			if direction := contained_text_auto_directionality_for_subtree(child, root, can_exclude_root) {
				return direction
			}
			continue
		}

		if child.is_text() {
			if direction := unsafe { &Text(child) }.directionality() {
				return direction
			}
		}
		if direction := contained_text_auto_directionality_for_subtree(child, root, can_exclude_root) {
			return direction
		}
	}
	return none
}

// --- Counters ---
pub fn (e &Element) has_non_empty_counters_set() bool {
	return e.counters_set_ != none
}

pub fn (e &Element) el_counters_set() ?&CSSCountersSet_ {
	return e.counters_set_
}

pub fn (mut e Element) ensure_counters_set() &CSSCountersSet_ {
	if cs := e.counters_set_ {
		return cs
	}
	new_cs := &CSSCountersSet_{}
	e.counters_set_ = new_cs
	return new_cs
}

pub fn (mut e Element) set_counters_set(cs ?&CSSCountersSet_) {
	e.counters_set_ = cs
}

// --- Proximity to viewport ---
pub fn (e &Element) proximity_to_the_viewport() ProximityToTheViewport {
	return e.proximity_to_the_viewport_
}

pub fn (mut e Element) determine_proximity_to_the_viewport() {
	// An element that has content-visibility: auto is close to the viewport when
	// its paint containment box's overflow clip edge intersects the viewport, or
	// a user-agent defined margin around the viewport.
	viewport_rect := e.document().viewport_rect()
	expanded_viewport := Rect{
		x: viewport_rect.x - viewport_rect.width
		y: viewport_rect.y - viewport_rect.height
		width: viewport_rect.width * 3
		height: viewport_rect.height * 3
	}

	// FIXME: We don't have paint containment or the overflow clip edge yet, so this
	// uses the available scrollable overflow rect for the current paintable box.
	if paintable_box := e.paintable_box() {
		if rect := paintable_box.scrollable_overflow_rect() {
			if css_pixel_rect_intersects_rect(rect, expanded_viewport) {
				e.proximity_to_the_viewport_ = .close_to_the_viewport
				return
			}
		}
	}

	// The element's proximity has been computed and is not close to the viewport.
	e.proximity_to_the_viewport_ = .far_away_from_the_viewport
}

pub fn (mut e Element) is_relevant_to_the_user() bool {
	// The element is relevant when it is close to the viewport.
	if e.proximity_to_the_viewport_ == .close_to_the_viewport {
		return true
	}

	// Focus or selection anywhere in the element's subtree also keeps its
	// contents relevant, independent of viewport proximity.
	document := e.document()
	if focused_area := document.focused_area() {
		if e.as_node().is_inclusive_ancestor_of(focused_area) {
			return true
		}
	}
	if selection := document.get_selection() {
		if selection.contains_node(e.as_node(), true) {
			return true
		}
	}

	// Top-layer elements and descendants captured by a view transition are
	// rendered even when their containing content-visibility box is offscreen.
	return element_subtree_has_relevant_contents(e, e)
}

fn element_subtree_has_relevant_contents(root &Element, element &Element) bool {
	if element.in_top_layer()
		|| (voidptr(element) != voidptr(root) && element.captured_in_a_view_transition()) {
		return true
	}
	for child in element.as_node().children {
		if child_element := child.as_element() {
			if element_subtree_has_relevant_contents(root, child_element) {
				return true
			}
		}
	}
	return false
}

// https://drafts.csswg.org/css-contain-2/#skips-its-contents
pub fn (mut e Element) skips_its_contents() bool {
	computed_properties := e.el_computed_properties() or { return false }

	// https://drafts.csswg.org/css-contain-2/#valdef-content-visibility-hidden
	// The element skips its contents.
	if computed_properties.content_visibility() == .hidden {
		return true
	}

	// https://drafts.csswg.org/css-contain-2/#valdef-content-visibility-auto
	// If the element is not relevant to the user, it also skips its contents.
	if computed_properties.content_visibility() == .auto_ && !e.is_relevant_to_the_user() {
		return true
	}

	return false
}

// --- Pseudo-class matching ---
pub fn (e &Element) matches_enabled_pseudo_class() bool {
	return e.is_html_element() && e.local_name() in ['button', 'input', 'select', 'textarea',
		'optgroup', 'option', 'fieldset'] && !e.is_actually_disabled()
}

pub fn (e &Element) matches_disabled_pseudo_class() bool {
	return e.is_actually_disabled()
}

pub fn (e &Element) matches_checked_pseudo_class() bool {
	if !e.is_html_element() {
		return false
	}
	if e.local_name() == 'input' {
		type_ := to_ascii_lowercase(e.get_attribute_value('type'))
		input := unsafe { &HTMLInputElement(e) }
		return type_ in ['checkbox', 'radio'] && input.checked()
	}
	return e.local_name() == 'option' && e.has_attribute('selected')
}

pub fn (e &Element) matches_unchecked_pseudo_class() bool {
	if !e.is_html_element() {
		return false
	}
	if e.local_name() == 'input' {
		type_ := to_ascii_lowercase(e.get_attribute_value('type'))
		input := unsafe { &HTMLInputElement(e) }
		return type_ in ['checkbox', 'radio'] && !input.checked()
	}
	return e.local_name() == 'option' && !e.has_attribute('selected')
}

// https://html.spec.whatwg.org/multipage/semantics-other.html#selector-required
//
// The `required` attribute only *applies* to some input types, so an input of a
// type it does not apply to is neither required nor optional.
fn input_required_applies(e &Element) bool {
	return to_ascii_lowercase(e.get_attribute_value('type')) in ['', 'text', 'search', 'tel', 'url',
		'email', 'password', 'date', 'month', 'week', 'time', 'datetime-local', 'number', 'checkbox',
		'radio', 'file']
}

pub fn (e &Element) matches_required_pseudo_class() bool {
	if !e.is_html_element() {
		return false
	}
	// - input elements that are required
	if e.local_name() == 'input' {
		return input_required_applies(e) && e.has_attribute('required')
	}
	// - select and textarea elements that have a required attribute
	if e.local_name() in ['select', 'textarea'] {
		return e.has_attribute('required')
	}
	return false
}

// https://html.spec.whatwg.org/multipage/semantics-other.html#selector-optional
pub fn (e &Element) matches_optional_pseudo_class() bool {
	if !e.is_html_element() {
		return false
	}
	// - input elements to which the required attribute applies that are not required
	if e.local_name() == 'input' {
		if input_required_applies(e) && !e.has_attribute('required') {
			return true
		}
		// AD-HOC: Chromium and WebKit also match for hidden inputs (and WPT expects
		// this). See https://github.com/whatwg/html/issues/11273
		return to_ascii_lowercase(e.get_attribute_value('type')) == 'hidden'
	}
	// - select and textarea elements that do not have a required attribute
	if e.local_name() in ['select', 'textarea'] {
		return !e.has_attribute('required')
	}
	return false
}

// https://html.spec.whatwg.org/multipage/semantics-other.html#selector-default
pub fn (e &Element) matches_default_pseudo_class() bool {
	if !e.is_html_element() {
		return false
	}
	// - input elements to which the checked attribute applies and that have a checked attribute
	if e.local_name() == 'input' {
		return to_ascii_lowercase(e.get_attribute_value('type')) in ['checkbox', 'radio']
			&& e.has_attribute('checked')
	}
	// - option elements that have a selected attribute
	if e.local_name() == 'option' {
		return e.has_attribute('selected')
	}
	// FIXME: Submit buttons that are default buttons of their form owner also
	//        match; that needs the form owner's default-button lookup.
	return false
}

pub fn (e &Element) matches_placeholder_shown_pseudo_class() bool {
	if !e.is_html_element() || !e.has_attribute('placeholder') {
		return false
	}
	if e.local_name() == 'input' {
		return e.get_attribute_value('value').len == 0
	}
	if e.local_name() == 'textarea' {
		return (e.as_node().text_content() or { '' }).len == 0
	}
	return false
}

pub fn (e &Element) matches_link_pseudo_class() bool {
	name := e.local_name()
	return ((e.is_html_element() && (name == 'a' || name == 'area')) || (e.is_svg_element() && name == 'a')) && e.has_attribute('href')
}

// https://drafts.csswg.org/selectors/#visited-pseudo
// Keep visited links indistinguishable from unvisited links. This is the same
// privacy-preserving policy currently used by upstream Ladybird.
pub fn (_ &Element) matches_visited_pseudo_class() bool {
	return false
}

pub fn (e &Element) matches_local_link_pseudo_class() bool {
	if !e.matches_link_pseudo_class() {
		return false
	}
	href := e.get_attribute('href') or { return false }
	target_url := e.document().encoding_parse_url(href) or { return false }
	document_url := e.document().url
	if target_url.fragment() != none {
		return target_url == document_url
	}
	mut target_without_fragment := target_url
	mut document_without_fragment := document_url
	target_without_fragment.set_fragment(none)
	document_without_fragment.set_fragment(none)
	return target_without_fragment == document_without_fragment
}

pub fn (e &Element) affected_by_pseudo_class(pseudo_class PseudoClass) bool {
	if props := e.computed_properties_ {
		if props.has_attempted_match_against_pseudo_class(pseudo_class) {
			return true
		}
	}
	if e.rare_data_ == unsafe { nil } { return false }
	for _, pseudo_element in e.rare_data_.pseudo_element_data {
		props := pseudo_element.computed_properties() or { continue }
		if props.has_attempted_match_against_pseudo_class(pseudo_class) {
			return true
		}
	}
	return false
}

pub fn (e &Element) includes_properties_from_invalidation_set(set StyleInvalidationSet) bool {
	for property in set.properties {
		matches := match property.type_ {
			.id { e.id() or { '' } == property.name }
			.class { e.has_class(property.name) }
			.tag_name { e.local_name() == property.name }
			.attribute {
				e.has_attribute(property.name)
					|| property.name in e.removed_attribute_names()
			}
			.pseudo_class { e.matches_invalidation_pseudo_class(property.pseudo_class_name) }
			.invalidate_self, .invalidate_whole_subtree { true }
		}
		if matches {
			return true
		}
	}
	return false
}

fn (e &Element) matches_invalidation_pseudo_class(name string) bool {
	return match name {
		'enabled' { e.matches_enabled_pseudo_class() }
		'disabled' { e.matches_disabled_pseudo_class() }
		'defined' { e.is_defined() }
		'placeholder-shown' { e.matches_placeholder_shown_pseudo_class() }
		'checked' { e.matches_checked_pseudo_class() }
		'paused' { e.matches_media_pseudo_class(.paused) }
		'playing' { e.matches_media_pseudo_class(.playing) }
		'muted' { e.matches_media_pseudo_class(.muted) }
		'seeking' { e.matches_media_pseudo_class(.seeking) }
		'buffering' { e.matches_media_pseudo_class(.buffering) }
		'stalled' { e.matches_media_pseudo_class(.stalled) }
		'has' {
			e.affected_by_has_pseudo_class_in_subject_position
				|| e.affected_by_has_pseudo_class_in_non_subject_position
		}
		'empty' {
			if !e.as_node().has_children() {
				true
			} else {
				mut is_empty := true
				for child in e.as_node().children {
					if child.is_element() {
						is_empty = false
						break
					}
					if character_data := child.character_data() {
						if character_data.data().len != 0 {
							is_empty = false
							break
						}
					}
				}
				is_empty
			}
		}
		'required' { e.matches_required_pseudo_class() }
		'optional' { e.matches_optional_pseudo_class() }
		'read-write' { e.matches_read_write_pseudo_class() }
		'read-only' { !e.matches_read_write_pseudo_class() }
		'link', 'any-link' { e.matches_link_pseudo_class() }
		'local-link' { e.matches_local_link_pseudo_class() }
		'root' { e.is_html_element() && e.local_name() == 'html' }
		'host' { e.is_shadow_host() }
		'hover' {
			hovered := e.document().get_hovered_node() or { return false }
			e.as_node().is_same_node(hovered) || e.as_node().is_shadow_including_ancestor_of(hovered)
		}
		'focus' { e.is_focused() }
		'focus-visible' { e.is_focused() && e.should_indicate_focus() }
		'focus-within' {
			focused := e.document().focused_area() or { return false }
			e.as_node().is_inclusive_ancestor_of(focused)
		}
		'active' { e.is_being_activated() }
		'target' {
			target := e.document().target_element() or { return false }
			target == e
		}
		'first-child' { e.as_node().previous_element_sibling() == none }
		'last-child' { e.as_node().next_element_sibling() == none }
		'only-child' {
			has_previous_sibling := e.as_node().previous_element_sibling() != none
			has_next_sibling := e.as_node().next_element_sibling() != none
			!has_previous_sibling && !has_next_sibling
		}
		else { false }
	}
}

// --- Invalidation flags ---
pub fn (e &Element) affected_by_forward_structural_changes() bool {
	return e.affected_by_direct_sibling_combinator || e.affected_by_indirect_sibling_combinator || e.affected_by_first_child_pseudo_class || e.affected_by_forward_positional_pseudo_class
}

pub fn (e &Element) affected_by_backward_structural_changes() bool {
	return e.affected_by_last_child_pseudo_class || e.affected_by_backward_positional_pseudo_class
}

pub fn (mut e Element) invalidate_style_if_affected_by_has() {
	if e.affected_by_has_pseudo_class_in_subject_position {
		e.set_needs_style_update(true)
	}
	if e.affected_by_has_pseudo_class_in_subject_position
		|| e.affected_by_has_pseudo_class_in_non_subject_position {
		mut node := unsafe { &Node(&e) }
		// Propagating a changed match is style work, not a new DOM mutation.
		// Whole-subtree fallback plans must not queue another :has() walk.
		node.invalidate_style_with_properties(.has_pseudo_class_match_change, [InvalidationProperty{
			type_: .pseudo_class
			pseudo_class_name: 'has'
		}], StyleInvalidationOptions{})
	}
}

pub fn (mut e Element) set_needs_style_update(v bool) {
	mut node := unsafe { &Node(&e) }
	node.set_needs_style_update(v)
}

pub fn (e &Element) needs_style_update() bool {
	return e.as_node().needs_style_update()
}

pub fn (e &Element) entire_subtree_needs_style_update() bool {
	return e.as_node().entire_subtree_needs_style_update()
}

// --- List ordinals ---
pub fn (e &Element) number_of_owned_list_items() int {
	mut number_of_owned_li_elements := 0
	for _ in e.numbered_items_owned_by_list_owner() {
		number_of_owned_li_elements++
	}
	return number_of_owned_li_elements
}

// Wraps `numbered_items_owned_by_list_owner` to mirror the C++ template
// `Element::for_each_numbered_item_owned_by_list_owner(Callback)` API.
pub fn (e &Element) for_each_numbered_item_owned_by_list_owner(callback fn (&Element) TraversalDecision) {
	for item in e.numbered_items_owned_by_list_owner() {
		if callback(item) == .@break {
			return
		}
	}
}

fn (e &Element) numbered_items_owned_by_list_owner() []&Element {
	mut items := []&Element{}
	root := e.as_node()
	mut current := root.first_child() or { return items }
	for {
		mut node_for_next := unsafe { &Node(current) }
		if element := current.as_element() {
			mut mutable_element := unsafe { &Element(element) }
			mutable_element.is_contained_in_list_subtree = true

			if element.is_html_ol_ul_menu_element() && current.unsafe_layout_node() != none {
				// Skip rendered list nodes and their descendants. A display:contents
				// list has no box, so its list items are owned and numbered by the
				// closest rendered ancestor instead.
				for {
					last := node_for_next.last_child() or { break }
					node_for_next = unsafe { &Node(last) }
				}
			} else {
				// NB: unsafe_layout_node() because list ordinal computation happens during style
				//     recalculation when layout is inherently stale.
				if current.unsafe_layout_node() != none {
					if computed_properties := element.el_computed_properties() {
						if computed_properties.display().is_list_item() {
							items << element
						}
					}
				}
			}
		}
		current = node_for_next.next_in_pre_order(root) or { break }
	}
	return items
}

pub fn (e &Element) list_owner() ?&Element {
	// Any element whose computed value of 'display' is 'list-item' has a list owner, which is determined as follows:
	if !e.is_contained_in_list_subtree {
		computed_properties := e.el_computed_properties() or { return none }
		if !computed_properties.display().is_list_item() {
			return none
		}
	}

	// 1. If the element is not being rendered, return null; the element has no list owner.
	// NB: unsafe_layout_node() because list ordinal computation happens during style recalculation
	//     when layout is inherently stale.
	if e.as_node().unsafe_layout_node() == none {
		return none
	}

	// 2. Let ancestor be the element's parent.
	mut ancestor := e.as_node().parent_element() or { return none }

	// 3. If the element has an ol, ul, or menu ancestor, set ancestor to the closest such ancestor element.
	mut ancestor_node := ancestor.as_node().parent()
	for ancestor_node != none {
		node := ancestor_node or { break }
		if element := node.as_element() {
			if element.is_html_ol_ul_menu_element() {
				ancestor = unsafe { &Element(element) }
				break
			}
		}
		ancestor_node = node.parent()
	}

	// 4. Return the closest inclusive ancestor of ancestor that produces a CSS box.
	mut inclusive_ancestor := ancestor.as_node()
	for {
		if element := inclusive_ancestor.as_element() {
			// The V layout bridge is installed before marker layout, while paintable
			// materialization happens later. A bridged layout node is the equivalent
			// evidence that this inclusive ancestor produces a CSS box.
			if inclusive_ancestor.unsafe_layout_node() != none {
				ancestor = unsafe { &Element(element) }
				break
			}
		}
		inclusive_ancestor = inclusive_ancestor.parent() or { break }
	}
	return ancestor
}

pub fn (e &Element) maybe_invalidate_ordinals_for_list_owner(skip_node ?&Element) {
	owner := e.list_owner() or { return }
	for item in owner.numbered_items_owned_by_list_owner() {
		if skipped := skip_node {
			if voidptr(item) == voidptr(skipped) {
				continue
			}
		}

		mut mutable_item := unsafe { &Element(item) }
		mutable_item.ordinal_value_ = none

		// Invalidate just the first ordinal in the list of numbered items.
		// NOTE: This works since this item is the first accessed (preorder) when rendering the list.
		//       It will trigger a recalculation of all ordinals on the [first] call to ordinal_value().
		break
	}
}

fn (e &Element) ol_starting_value() int {
	// 1. If the ol element has a start attribute, then:
	if start := e.get_attribute('start') {
		// 1. Let parsed be the result of parsing the value of the attribute as an integer.
		// 2. If parsed is not an error, then return parsed.
		if parsed := parse_html_integer(start) {
			return parsed
		}
	}

	// 2. If the ol element has a reversed attribute, then return the number of owned li elements.
	if e.has_attribute('reversed') {
		items := e.numbered_items_owned_by_list_owner()
		// A valid li[value] is a counter-set pin. CSS reversed counters derive their implicit
		// initial value by counting back from the first pin, rather than from the item count.
		// This deliberately differs from the removed HTML ordinal model.
		for index, item in items {
			if item.is_html_li_element() {
				if value := item.get_attribute('value') {
					if parsed := parse_html_integer(value) {
						return parsed + index
					}
				}
			}
		}
		return items.len
	}

	// 3. Return 1.
	return 1
}

pub fn (mut e Element) ordinal_value() int {
	if v := e.ordinal_value_ {
		return v
	}

	owner := e.list_owner() or { return 1 }

	// 1. Let i be 1. [Not necessary]
	// 2. If owner is an ol element, let numbering be owner's starting value. Otherwise, let numbering be 1.
	mut numbering := 1
	mut reversed := false
	if owner.is_html_ol_element() {
		numbering = owner.ol_starting_value()
		reversed = owner.has_attribute('reversed')
	}

	// 3. Loop : If i is greater than the number of list items that owner owns, then return; all of owner's owned list items have been assigned ordinal values.
	// NOTE: We use `owner->for_each_numbered_item_in_list` to iterate through the owner's list of owned elements.
	//       As a result, we don't need `i` as counter (spec) in the list of children, with no material consequences.
	for item in owner.numbered_items_owned_by_list_owner() {
		// 4. Let item be the ith of owner's owned list items, in tree order. [Not necessary]
		// 5. If item is an li element that has a value attribute, then:
		if item.is_html_li_element() {
			if value_attribute := item.get_attribute('value') {
				// 1. Let parsed be the result of parsing the value of the attribute as an integer.
				// 2. If parsed is not an error, then set numbering to parsed.
				if parsed := parse_html_integer(value_attribute) {
					numbering = parsed
				}
			}
		}

		// 6. The ordinal value of item is numbering.
		mut mutable_item := unsafe { &Element(item) }
		mutable_item.ordinal_value_ = numbering

		// 7. If owner is an ol element, and owner has a reversed attribute, decrement numbering by 1; otherwise, increment numbering by 1.
		if reversed {
			numbering--
		} else {
			numbering++
		}

		// 8. Increment i by 1. [Not necessary]
		// 9. Go to the step labeled loop.
	}

	return e.ordinal_value_ or { 1 }
}

// --- View transition ---

// https://drafts.csswg.org/css-view-transitions-1/#capture-the-image
pub fn (e &Element) capture_the_image() &DecodedImageFrame_ {
	_ = e
	// Element.cpp retains this 1x1 BGRA premultiplied capture until its source
	// image-capture algorithm is implemented.
	return DecodedImageFrame_.create(&Bitmap_{
		width: 1
		height: 1
		pitch: 4
		format: 2
		alpha_type: 2
		data: []u8{len: 4}
	})
}

pub fn (e &Element) captured_in_a_view_transition() bool {
	return e.captured_in_a_view_transition
}

pub fn (mut e Element) set_captured_in_a_view_transition(v bool) {
	e.captured_in_a_view_transition = v
}

// https://drafts.csswg.org/css-images-4/#element-not-rendered
pub fn (e &Element) not_rendered() bool {
	return e.el_layout_node() == none
}

// https://drafts.csswg.org/css-view-transitions-1/#document-scoped-view-transition-name
pub fn (e &Element) document_scoped_view_transition_name() ?string {
	props := e.el_computed_properties() or { return none }
	return props.view_transition_name()
}

pub fn (mut e Element) play_or_cancel_animations_after_display_property_change() {
	// OPTIMIZATION: We don't care about elements with no CSS defined animations.
	if !e.has_css_defined_animations_flag || e.rare_data_ == unsafe { nil }
		|| e.rare_data_.style_data_ == unsafe { nil } {
		return
	}

	// OPTIMIZATION: We don't care about animations in disconnected subtrees.
	if !e.is_connected() {
		return
	}

	// If display computes to none when ignoring animation and transition cascade
	// origins, terminate running animations. Restoring the underlying display
	// resumes each animation according to its last CSS animation-play-state.
	has_display_none_inclusive_ancestor := e.as_node().has_inclusive_ancestor_with_display_none_ignoring_animations()
	for _, animations in e.rare_data_.style_data_.css_defined_animations {
		for _, animation in animations {
			if has_display_none_inclusive_ancestor {
				animation.cancel()
				continue
			}
			play_state := animation.last_css_animation_play_state() or { continue }
			match play_state {
				.running { animation.play() or {} }
				.paused { animation.pause() or {} }
			}
		}
	}
}

// --- Pointer capture ---
pub fn (mut e Element) set_pointer_capture(pointer_id int) {
	_ = pointer_id
}

pub fn (mut e Element) release_pointer_capture(pointer_id int) {
	_ = pointer_id
}

pub fn (e &Element) has_pointer_capture(pointer_id int) bool {
	_ = pointer_id
	return false
}

pub fn (e &Element) request_pointer_lock(options ?PointerLockOptions) &webidl.Promise {
	_ = e
	_ = options
	return webidl.create_rejected_promise_from_dom_exception(webidl.DOMException.create('NotSupportedError', 'request_pointer_lock() is not implemented'))
}

// --- Lang ---

// https://html.spec.whatwg.org/multipage/dom.html#the-lang-and-xml:lang-attributes
pub fn (e &Element) lang() ?string {
	if cached := e.lang_value_ {
		if cached.len == 0 {
			return none
		}
		return cached
	}

	mut value := ''
	if xml_lang := e.get_attribute_ns(namespace_xml_uri, 'lang') {
		value = xml_lang
	} else {
		ns := e.namespace_uri() or { '' }
		if ns == namespace_html_uri || ns == namespace_svg_uri {
			if lang_attr := e.get_attribute('lang') {
				value = lang_attr
			}
		}
		if value.len == 0 {
			if parent := e.as_node().parent() {
				if shadow_root := parent.as_shadow_root() {
					if shadow_root.host_ != unsafe { nil } {
						value = shadow_root.host_.lang() or { '' }
					}
				} else if parent_element := parent.as_element() {
					value = parent_element.lang() or { '' }
				}
			}
		}
		if value.len == 0 {
			doc := e.document()
			if doc != unsafe { nil } {
				if pragma_language := doc.pragma_set_default_language {
					value = pragma_language
				} else if http_language := doc.http_content_language {
					value = http_language
				}
			}
		}
	}
	mut mutable_element := unsafe { &Element(e) }
	mutable_element.lang_value_ = value
	if value.len == 0 {
		return none
	}
	return value
}

pub fn (mut e Element) invalidate_lang_value() {
	if e.lang_value_ != none {
		e.lang_value_ = none
		e.set_needs_style_update(true)
	}
}

fn schedule_has_invalidation_for_inherited_attribute_change(element &Element, pseudo_class_name string) {
	node := element.as_node()
	// Language/direction caches are still invalidated by the caller. A pending
	// complete style pass already rematches every affected :has() subject.
	if node.document().needs_full_style_update() { return }
	// Resolve the same scope snapshot before invalidation, without retaining the
	// changed node in a captured callback after this synchronous walk returns.
	scopes := node.observing_style_scopes()
	record_inherited_attribute_invalidation(scopes.first, node, pseudo_class_name)
	for scope in scopes.additional {
		record_inherited_attribute_invalidation(scope, node, pseudo_class_name)
	}
}

fn record_inherited_attribute_invalidation(scope &StyleScope, node &Node, pseudo_class_name string) {
	mut mutable_scope := unsafe { &StyleScope(scope) }
	mutable_scope.record_pending_has_invalidation_mutation_properties(node, [
		InvalidationProperty{
			type_: .pseudo_class
			pseudo_class_name: pseudo_class_name
		},
	])
	mutable_scope.schedule_ancestors_style_invalidation_due_to_presence_of_has(node)
}

// CSS/Invalidation/LanguageInvalidator.cpp:22–61. Keep the existing V
// publication bridge shared by attribute changes and Source Meta pragmas.
pub fn (mut e Element) invalidate_style_after_language_change() {
	e.publish_language_and_directionality(false)
}

fn (mut e Element) publish_language_and_directionality(is_directionality_change bool) {
	e.as_node().visit_shadow_including_inclusive_descendants(fn [is_directionality_change] (node &Node) TraversalDecision {
		if element := node.as_element() {
			mut mutable_element := unsafe { &Element(element) }
			if !is_directionality_change {
				mutable_element.invalidate_lang_value()
			}
			mutable_element.set_needs_style_update(true)
			return .@continue
		}
		if is_directionality_change {
			return .@continue
		}
		layout_node := node.unsafe_layout_node() or { return .@continue }
		parent_element := node.parent_or_shadow_host_element() or { return .@continue }
		computed := parent_element.el_computed_properties() or { return .@continue }
		if !computed.has_casing_text_transform() {
			return .@continue
		}
		mut mutable_layout_node := unsafe { &LayoutNode(layout_node) }
		mutable_layout_node.invalidate_text_for_rendering()
		mutable_layout_node.set_needs_layout_update(.language_change_under_casing_text_transform)
		return .@continue
	})
	schedule_has_invalidation_for_inherited_attribute_change(&e, if is_directionality_change {
		'dir'
	} else {
		'lang'
	})
}

// --- is_connected ---
pub fn (e &Element) is_connected() bool {
	return e.as_node().is_connected()
}

// --- attribute_changed ---

// https://dom.spec.whatwg.org/#concept-element-attributes-change-ext
pub fn (mut e Element) attribute_changed(local_name string, old_value ?string, value ?string, namespace_ ?string) {
	// HTMLMediaElement runs its src/controls hooks after the base attribute steps.
	// The pinned Source hook checks local name even for a foreign namespace.
	defer {
		if local_name == 'src' && e.is_html_element() && e.local_name() in ['audio', 'video'] {
			if hook := e.document().media_element_source_attribute_changed_hook_ {
				hook(&e, value)
			}
		}
		if local_name == 'controls' && e.is_html_element() && e.local_name() in ['audio', 'video'] {
			if hook := e.document().media_element_controls_attribute_changed_hook_ {
				hook(&e, value)
			}
		}
	}
	// HTMLElement's base hook and body/frameset WindowEventHandlers run after
	// Element's attribute steps, including the pinned source namespace FIXME.
	defer {
		if e.is_html_element() && (is_global_event_handler_content_attribute(local_name)
			|| (e.local_name() in ['body', 'frameset']
				&& is_window_event_handler_content_attribute(local_name))) {
			unsafe { &EventTarget(&e) }.element_event_handler_attribute_changed(local_name, value)
		}
	}
	// HTMLStyleElement::attribute_changed() and SVGStyleElement::attribute_changed() run
	// style_element_attribute_changed() after the base Element steps.
	defer {
		if mut style_element_base := e.style_element_base() {
			style_element_base.style_element_attribute_changed(local_name, value)
		}
	}
	if namespace_ != none {
		if e.is_svg_element() && e.local_name() == 'use' && local_name == 'href' {
			e.svg_use_process_the_url()
		}
		if e.is_svg_element() {
			e.update_use_elements_that_reference_this()
		}
		return
	}

	value_or_empty := value or { '' }
	if local_name in ['autoplay', 'preload'] && e.is_html_element() && e.local_name() in ['audio', 'video'] {
		if hook := e.document().media_element_resource_attribute_changed_hook_ {
			hook(&e)
		}
	}
	// HTMLLinkElement::attribute_changed forwards media to its associated
	// sheet without replacing the sheet or fetching the resource again.
	if e.is_html_element() && e.local_name() == 'link' && local_name == 'media' {
		mut link := unsafe { &HTMLLinkElement(&e) }
		link.set_linked_style_sheet_media(value_or_empty)
	}

	if local_name == 'inert' && e.is_html_element() {
		mut html_element := unsafe { &HTMLElement(&e) }
		html_element.set_subtree_inertness(value != none)
	}
	if local_name == 'contenteditable' && e.is_html_element() {
		states := if !option_string_equal(old_value, value) {
			previous_read_write_states(e.as_node())
		} else {
			[]PreviousReadWriteState{}
		}
		e.content_editable_state_ = parse_content_editable_state(value)
		mut node := e.as_node()
		node.recompute_editable_subtree_flags_and_repaint()
		invalidate_previous_read_write_states(states)
	}

	if local_name == 'slot' {
		// 1. If value is oldValue, then return.
		if option_string_equal(value, old_value) {
			return
		}

		// 2. If value is null and oldValue is the empty string, then return.
		if value == none && old_value or { '\x01' } == '' {
			return
		}

		// 3. If value is the empty string and oldValue is null, then return.
		if value or { '\x01' } == '' && old_value == none {
			return
		}

		// 4-5. Update the slottable name maintained by SlottableMixin.
		mut element_node := unsafe { &Node(&e) }
		element_node.set_slottable_name(value or { '' })
		// 6. If element is assigned, then run assign slottables for element's assigned slot.
		if assigned_slot := unsafe { &Node(&e) }.assigned_slot_internal() {
			assign_slottables(assigned_slot)
		}

		// 7. Run assign a slot for element.
		assign_a_slot(unsafe { &Node(&e) })
		return
	}

	if local_name == 'id' {
		if value_or_empty.len == 0 {
			e.id_ = none
		} else {
			e.id_ = value_or_empty
		}
		if e.is_connected() {
			mut doc := unsafe { &Document(e.document()) }
			doc.element_id_changed(&e, old_value)
		}
	} else if local_name == 'name' {
		if value_or_empty.len == 0 {
			e.name_ = none
		} else {
			e.name_ = value_or_empty
		}
		if e.is_connected() {
			mut doc := unsafe { &Document(e.document()) }
			doc.element_name_changed(&e)
		}
	} else if local_name == 'class' {
		if value_or_empty.len == 0 {
			e.classes.clear()
		} else {
			e.classes = value_or_empty.split(' ').filter(it.len > 0)
		}
		mut owner_document := unsafe { &Document(e.document()) }
		owner_document.note_element_classes(e.classes)
		if mut cl := e.class_list_ {
			cl.associated_attribute_changed(value_or_empty)
		}
	} else if local_name == 'style' {
		mut inline_style := e.inline_style_ or {
			style := create_element_inline_style(&e)
			e.inline_style_ = style
			style
		}
		if inline_style.is_updating() {
			return
		}
		inline_style.set_declarations_from_text(value_or_empty)
		e.set_needs_style_update(true)
	} else if local_name == 'dir' || local_name == 'lang' {
		is_dir := local_name == 'dir'
		if is_dir {
			lowercase_value := to_ascii_lowercase(value_or_empty)
			if lowercase_value == 'ltr' {
				e.dir__ = .ltr
			} else if lowercase_value == 'rtl' {
				e.dir__ = .rtl
			} else if lowercase_value == 'auto' {
				e.dir__ = .auto_
			} else {
				e.dir__ = none
			}
		}
		if is_dir {
			e.publish_language_and_directionality(true)
		} else {
			e.invalidate_style_after_language_change()
		}
	} else if local_name == 'part' {
		e.set_element_parts(value_or_empty.split(' ').filter(it.len > 0))
		if mut pl := e.cached_part_list() {
			pl.associated_attribute_changed(value_or_empty)
		}
		e.set_needs_style_update(true)
	} else if local_name == 'exportparts' {
		if shadow_root := e.shadow_root() {
			shadow_node := unsafe { &Node(shadow_root) }
			shadow_node.for_each_in_subtree(fn (node &Node) TraversalDecision {
				if element := node.as_element() {
					if element.has_part_names() {
						mut mutable_element := unsafe { &Element(element) }
						mutable_element.set_needs_style_update(true)
					}
				}
				return .@continue
			})
		}
	}

	if local_name == 'name' && e.local_name() == 'slot' {
		html_slot_element_name_attribute_changed(unsafe { &HTMLSlotElement(&e) }, old_value, value)
	}

	// HTMLTableElement::attribute_changed(): cellpadding is cached because its
	// presentational hint applies to descendant cells rather than the table.
	if e.is_html_element() && e.local_name() == 'table' && local_name == 'cellpadding' {
		mut table := unsafe { &HTMLTableElement(&e) }
		old_cellpadding := table.cellpadding_
		mut new_cellpadding := u32(1)
		if source := value {
			parsed := parse_html_integer(source) or { 0 }
			new_cellpadding = if parsed < 0 { u32(0) } else { u32(parsed) }
		}
		table.cellpadding_ = new_cellpadding
		if old_cellpadding != table.cellpadding_ {
			e.as_node().for_each_in_subtree(fn (node &Node) TraversalDecision {
				if cell := node.as_element() {
					if cell.is_html_element() && cell.local_name() in ['td', 'th'] {
						mut mutable_cell := unsafe { &Element(cell) }
						mutable_cell.set_needs_style_update(true)
					}
				}
				return .@continue
			})
		}
	}

	if e.is_html_element() && e.local_name() == 'li' && local_name == 'value' {
		if owner := e.list_owner() {
			mut owner_node := unsafe { &Node(owner.as_node()) }
			owner_node.set_needs_layout_tree_update(true, .html_ol_list_element_ordinal_values)
			mut list_item := unsafe { &Element(&e) }
			list_item.maybe_invalidate_ordinals_for_list_owner(none)
		}
	}

	if e.is_html_element() && e.local_name() == 'ol' && local_name in ['reversed', 'start', 'type'] {
		mut list_node := unsafe { &Node(e.as_node()) }
		list_node.set_needs_layout_tree_update(true, .html_ol_list_element_ordinal_values)
		for child in e.as_node().children_as_vector() {
			if first_child_element := child.as_element() {
				mut mutable_first_child := unsafe { &Element(first_child_element) }
				mutable_first_child.maybe_invalidate_ordinals_for_list_owner(none)
				break
			}
		}
	}

	if e.is_svg_element() {
		if e.local_name() == 'use' && local_name in ['href', 'xlink:href'] {
			e.svg_use_process_the_url()
		}
		if (e.local_name() == 'clipPath' && local_name == 'clipPathUnits')
			|| (e.local_name() == 'mask'
				&& local_name in ['maskUnits', 'maskContentUnits', 'x', 'y', 'width', 'height']) {
			e.mark_svg_resource_box_referencing_elements_for_layout_update()
		}
		e.update_use_elements_that_reference_this()
		e.note_svg_paint_resource_description_may_have_changed()
	}

	// CheckBoxPaintable and RadioButtonPaintable read enabledness directly from
	// the live element while recording. Attribute style invalidation alone does
	// not discard their retained paint commands.
	if namespace_ == none && local_name == 'disabled' && e.is_html_element() {
		if e.is_form_associated_element() {
			mut node := unsafe { &Node(e.as_node()) }
			node.set_needs_repaint(.paint_commands)
		}
		// Toggling a fieldset changes the enabledness of every form-associated
		// descendant outside its first legend, so conservatively repaint all of
		// them just like HTMLFieldSetElement::attribute_changed().
		if e.local_name() == 'fieldset' {
			e.as_node().for_each_in_subtree(fn (descendant &Node) TraversalDecision {
				if element := descendant.as_element() {
					if element.is_form_associated_element() {
						mut mutable_descendant := unsafe { &Node(descendant) }
						mutable_descendant.set_needs_repaint(.paint_commands)
					}
				}
				return .@continue
			})
		}
	}
}

fn html_slot_element_name_attribute_changed(slot &HTMLSlotElement, old_value ?string, value ?string) {
	// 1. If value is oldValue, then return.
	if option_string_equal(value, old_value) {
		return
	}

	// 2. If value is null and oldValue is the empty string, then return.
	if value == none && old_value or { '\x01' } == '' {
		return
	}

	// 3. If value is the empty string and oldValue is null, then return.
	if value or { '\x01' } == '' && old_value == none {
		return
	}

	root := unsafe { &Element(slot) }.as_node().root()
	if mut shadow_root := root.as_shadow_root() {
		shadow_root.unregister_slot(slot)
	}

	// 4-5. Null and the empty string both set the slot's name to the empty string;
	// otherwise its name is value.
	mut mutable_slot := unsafe { &HTMLSlotElement(slot) }
	mutable_slot.set_slot_name(value or { '' })

	if mut shadow_root := root.as_shadow_root() {
		shadow_root.register_slot(slot)
	}
	dom_assign_slottables_for_a_tree(root)
}

// Kept separate from assign_slottables_for_a_tree so Element's attribute-change
// implementation does not need to move the DOM algorithm out of its owning file.
fn dom_assign_slottables_for_a_tree(root &Node) {
	assign_slottables_for_a_tree(root)
}

fn (mut e Element) invalidate_style_after_attribute_change(attribute_name string, old_value ?string, new_value ?string) {
	if trace_style_invalidation_sources {
		trace_style_invalidation_source(e.as_node(), .element_attribute_change, 'attribute(${attribute_name})')
	}
	mut node := unsafe { &Node(&e) }
	// The full pass visits host shadow scopes as well as the light tree. Avoid
	// building class/id deltas or selector plans that it immediately discards.
	if e.document().needs_full_style_update() {
		node.set_needs_style_update(true)
		return
	}
	style_computer := e.document().style_computer()
	if style_computer.invalidation_plan_callback == unsafe { nil } {
		// A DOM-only consumer has no CSS rule cache to produce an invalidation plan. Conservatively
		// invalidate the subtree so selector and inheritance changes remain correct.
		node.invalidate_style(.element_attribute_change)
		e.invalidate_hosted_shadow_tree_after_attribute_change(style_computer)
		return
	}

	mut changed_properties := []InvalidationProperty{}
	mut options := StyleInvalidationOptions{
		invalidate_self: attribute_name == 'style' || e.style_uses_attr_css_function
	}
	if attribute_name == 'class' {
		old_classes := old_value or { '' }.fields()
		new_classes := new_value or { '' }.fields()
		for old_class in old_classes {
			if old_class !in new_classes {
				changed_properties << InvalidationProperty{
					type_: .class
					name: old_class
				}
			}
		}
		for new_class in new_classes {
			if new_class !in old_classes {
				changed_properties << InvalidationProperty{
					type_: .class
					name: new_class
				}
			}
		}
	} else if attribute_name == 'id' {
		if old_id := old_value {
			changed_properties << InvalidationProperty{
				type_: .id
				name: old_id
			}
		}
		if new_id := new_value {
			changed_properties << InvalidationProperty{
				type_: .id
				name: new_id
			}
		}
	} else {
		pseudo_classes := match attribute_name {
			'disabled' { ['disabled', 'enabled'] }
			'placeholder' { ['placeholder-shown'] }
			'value' { ['checked'] }
			'required' { ['required', 'optional'] }
			else { []string{} }
		}
	for pseudo_class_name in pseudo_classes {
			changed_properties << InvalidationProperty{
				type_: .pseudo_class
				pseudo_class_name: pseudo_class_name
			}
		}
	}
	if new_value == none && attribute_name !in e.removed_attribute_names() {
		mut state := e.copy_dependency_data()
		state.removed_attributes = state.removed_attributes.clone()
		state.removed_attributes << attribute_name
		e.dependency_data_ = state
	}
	changed_properties << InvalidationProperty{
		type_: .attribute
		name: attribute_name
	}
	// Presentational-hint detection belongs to the concrete HTML element subclasses. Recomputing the
	// changed element is conservative until those subclass hooks are represented in this module.
	options.invalidate_self = true
	node.invalidate_style_with_properties(.element_attribute_change, changed_properties, options)
	e.invalidate_hosted_shadow_tree_after_attribute_change(style_computer)
}

pub fn (mut e Element) clear_removed_attributes_for_style_invalidation() {
	if e.removed_attribute_names().len == 0 { return }
	mut state := e.copy_dependency_data()
	state.removed_attributes = []string{}
	e.dependency_data_ = state
}

fn (mut e Element) invalidate_hosted_shadow_tree_after_attribute_change(style_computer &StyleComputer) {
	shadow_root := e.shadow_root() or { return }
	if style_computer.shadow_root_may_match_host_callback == unsafe { nil }
		|| !style_computer.shadow_root_may_match_host_callback(style_computer.css_handle, shadow_root) {
		return
	}
	mut shadow_node := unsafe { &Node(shadow_root) }
	shadow_node.set_entire_subtree_needs_style_update(true)
	shadow_node.set_needs_style_update(true)
}

// --- Hidden / Accessibility ---
pub fn (e &Element) is_hidden() bool {
	if e.as_node().unsafe_layout_node() == none {
		return true
	}
	if computed := e.el_computed_properties() {
		if computed.visibility() in [.hidden, .collapse] || computed.content_visibility() == .hidden {
			return true
		}
	}
	mut self_or_ancestor := ?&Node(e.as_node())
	for self_or_ancestor != none {
		current := self_or_ancestor or { break }
		if element := current.as_element() {
			if element.get_attribute('aria-hidden') or { '' } == 'true' {
				return true
			}
		}
		self_or_ancestor = current.parent_or_shadow_host()
	}
	return false
}

pub fn (e &Element) has_hidden_ancestor() bool {
	mut self_or_ancestor := ?&Node(e.as_node())
	for self_or_ancestor != none {
		current := self_or_ancestor or { break }
		if element := current.as_element() {
			if element.is_hidden() {
				return true
			}
		}
		self_or_ancestor = current.parent_or_shadow_host()
	}
	return false
}

// Returns true when this element's id is mentioned by another element's
// aria-labelledby attribute somewhere in the same root subtree.
//
// The C++ implementation consults Web::ARIA::AriaData, which collects every
// IDREF-list ARIA attribute. The translated ARIA module depends on DOM and
// therefore cannot be imported here without a cycle, so this DOM-side bridge
// scans aria-labelledby tokens directly.
pub fn (e &Element) is_referenced() bool {
	id := e.id() or { return false }
	root := e.as_node().root()
	return id_referenced_in_subtree(root, id)
}

fn id_referenced_in_subtree(node &Node, id string) bool {
	if element := node.as_element() {
		if element.is_html_element() {
			if labelled_by := element.get_attribute('aria-labelledby') {
				for token in labelled_by.fields() {
					if token == id {
						return true
					}
				}
			}
		}
	}
	for child in node.children {
		if id_referenced_in_subtree(child, id) {
			return true
		}
	}
	return false
}

pub fn (e &Element) has_referenced_and_hidden_ancestor() bool {
	for ancestor := e.as_node().parent_or_shadow_host(); ancestor != none;  {
		current := ancestor or { break }
		if element := current.as_element() {
			if element.is_referenced() && element.is_hidden() {
				return true
			}
		}
		ancestor = current.parent_or_shadow_host()
	}
	return false
}

pub fn (e &Element) exclude_from_accessibility_tree() bool {
	val := e.get_attribute('aria-hidden') or { return false }
	return val == 'true'
}

pub fn (e &Element) include_in_accessibility_tree() bool {
	if e.exclude_from_accessibility_tree() {
		return false
	}
	if e.is_focused() {
		return true
	}
	return false
}

// --- Rendering blocking ---

// https://html.spec.whatwg.org/multipage/dom.html#block-rendering
pub fn (mut e Element) block_rendering() {
	mut doc := unsafe { &Document(e.document()) }
	if doc == unsafe { nil } {
		return
	}
	if doc.allows_adding_render_blocking_elements() {
		doc.add_render_blocking_element(e)
	}
}

// https://html.spec.whatwg.org/multipage/dom.html#unblock-rendering
pub fn (mut e Element) unblock_rendering() {
	mut doc := unsafe { &Document(e.document()) }
	if doc == unsafe { nil } {
		return
	}
	doc.remove_render_blocking_element(e)
}

// https://html.spec.whatwg.org/multipage/urls-and-fetching.html#potentially-render-blocking
pub fn (e &Element) is_potentially_render_blocking() bool {
	return e.is_implicitly_potentially_render_blocking()
}

pub fn (e &Element) is_implicitly_potentially_render_blocking() bool {
	return false
}

// --- Computed style map ---

// https://drafts.css-houdini.org/css-typed-om-1/#dom-element-computedstylemap
pub fn (mut e Element) computed_style_map() &StylePropertyMapReadOnly_ {
	if csm := e.cached_computed_style_map() {
		return csm
	}
	new_csm := &StylePropertyMapReadOnly_{}
	mut state := e.copy_dependency_data()
	state.computed_style_map = new_csm
	e.dependency_data_ = state
	return new_csm
}

// --- CSS random base value ---
pub fn (mut e Element) ensure_css_random_base_value(key string) f64 {
	mut data := e.ensure_rare_style_data()
	if key in data.element_specific_css_random_base_values {
		return data.element_specific_css_random_base_values[key]
	}
	val := rand.f64()
	data.element_specific_css_random_base_values[key] = val
	return val
}

// --- Focus indication ---

// https://drafts.csswg.org/selectors/#indicate-focus
pub fn (e &Element) should_indicate_focus() bool {
	return e.is_focused()
}


// --- Tokenization flag ---
pub fn (mut e Element) set_had_duplicate_attribute_during_tokenization() {
	e.had_duplicate_attribute_during_tokenization = true
}

// --- Style tracking ---
pub fn (mut e Element) set_style_uses_tree_counting_function() {
	e.style_uses_tree_counting_function = true
}

// --- Lifecycle callbacks ---
pub fn (mut e Element) inserted() {
	mut owner_document := unsafe { &Document(e.document()) }
	owner_document.note_element_local_name(e.local_name().to_lower())
	owner_document.note_element_classes(e.classes)
	if attributes := e.attributes_ {
		for attribute in attributes.attrs {
			owner_document.note_element_attribute_name(e.local_name(), attribute.local_name_)
		}
	}
	mut node := unsafe { &Node(e.as_node()) }
	node.recompute_editable_subtree_flag()
	node.set_needs_style_update(true)

	if e.is_connected() {
		mut doc := unsafe { &Document(e.document()) }
		if e.id_ != none {
			doc.element_with_id_was_added(e)
		}
		if e.name_ != none {
			doc.element_with_name_was_added(e)
		}
		if e.custom_element_registry() != unsafe { nil } {
			if custom_element_registry_is_scoped(e.custom_element_registry()) {
				custom_element_registry_append_document(e.custom_element_registry(), e.document())
			}
			if e.is_custom() {
				e.enqueue_a_custom_element_callback_reaction('connectedCallback', [])
			} else {
				e.try_to_upgrade()
			}
		}
		if e.has_attribute('autofocus') && doc.is_fully_active()
			&& doc.active_sandboxing_flag_bits() & u32(512) == 0 && doc.allow_focus() {
			if navigable := doc.navigable() {
				if top_level_traversable := navigable.traversable_navigable() {
					if top_document := top_level_traversable.active_document() {
						mut mutable_top_document := unsafe { &Document(top_document) }
						mutable_top_document.add_autofocus_candidate(e)
					}
				}
			}
		}
	}

	e.play_or_cancel_animations_after_display_property_change()
	if e.is_svg_element() {
		e.update_use_elements_that_reference_this()
		e.note_svg_paint_resource_description_may_have_changed()
		if e.local_name() == 'use' && e.document().is_completely_loaded() {
			e.svg_use_process_the_url()
		}
	}

	// HTMLStyleElement::inserted() and SVGStyleElement::inserted().
	if mut style_element_base := e.style_element_base() {
		style_element_base.update_a_style_block_for_dynamic_change()
	}
}

pub fn (mut e Element) removed_from(old_parent ?&Node, old_root &Node) {
	e.removed_from_with_context(.yes, old_parent, old_root)
}

pub fn (mut e Element) removed_from_with_context(is_subtree_root NodeIsSubtreeRoot, old_ancestor ?&Node, old_root &Node) {
	mut node := unsafe { &Node(e.as_node()) }
	node.in_editable_subtree_ = false
	node.layout_node_ = unsafe { nil }
	node.paintable_ = unsafe { nil }
	e.clear_pseudo_element_layout_nodes()

	if e.id_ != none {
		if mut shadow_root := old_root.as_shadow_root() {
			mut id_map := unsafe { &ElementByIdMap(shadow_root.element_by_id()) }
			id_map.remove(e.id_ or { '' }, e)
		}
	}

	if old_root.is_connected() {
		mut doc := unsafe { &Document(e.document()) }
		if e.id_ != none {
			doc.element_with_id_was_removed(e)
		}
		if e.name_ != none {
			doc.element_with_name_was_removed(e)
		}
		if computed_properties := e.el_computed_properties() {
			update_anchor_name_map_for_root(old_root, computed_properties.anchor_names(), [], &e)
		}
	}

	e.play_or_cancel_animations_after_display_property_change()
	e.exit_fullscreen_on_element_removal()
	if e.is_svg_element() {
		mut old_ancestor_described_paint_resource := false
		if old_ancestor_node := old_ancestor {
			if old_ancestor_element := old_ancestor_node.as_element() {
				old_ancestor_described_paint_resource = old_ancestor_element.describes_svg_paint_resource()
			}
		}
		if e.describes_svg_paint_resource() || old_ancestor_described_paint_resource {
			mut document := unsafe { &Document(e.document()) }
			document.note_svg_paint_resources_changed()
		}
		old_root_is_use_shadow_tree := svg_root_is_use_element_shadow_root(old_root)
		current_root_is_use_shadow_tree := svg_root_is_use_element_shadow_root(e.as_node().root())
		if !old_root_is_use_shadow_tree && !current_root_is_use_shadow_tree {
			e.remove_from_use_element_that_reference_this()
			e.mark_svg_resource_box_referencing_elements_for_layout_tree_update()
			if e.id() != none {
				mut document := unsafe { &Document(e.document()) }
				document.set_needs_repaint_with_invalidation(.paint_commands)
			}
		}
	}

	// https://html.spec.whatwg.org/multipage/interactive-elements.html#the-dialog-element:html-element-removing-steps
	// HTMLDialogElement::removed_from() runs after HTMLElement::removed_from().
	// Keep this at the translated DOM dispatch boundary until Node's lifecycle
	// callbacks preserve the concrete HTML element type.
	if e.is_html_element() && e.local_name() == 'dialog' {
		mut dialog := unsafe { &HTMLDialogElement(e) }
		if e.in_top_layer() {
			mut document := unsafe { &Document(e.document()) }
			document.remove_an_element_from_the_top_layer_immediately(e)
		}
		dialog.is_modal_ = false
	}

	// HTMLStyleElement::removed_from() and SVGStyleElement::removed_from().
	if mut style_element_base := e.style_element_base() {
		style_element_base.update_a_style_block_for_dynamic_change()
	}
	node.run_removed_from_lifecycle_hook(is_subtree_root, old_ancestor, old_root)
}

pub fn (mut e Element) moved_from(old_parent ?&Node) {
	e.moved_from_with_context(.yes, old_parent)
}

pub fn (mut e Element) moved_from_with_context(is_subtree_root NodeIsSubtreeRoot, old_ancestor ?&Node) {
	mut node := unsafe { &Node(e.as_node()) }
	node.recompute_editable_subtree_flag()
	// Language is inherited through the parent/host chain but cached on every
	// element. A cross-parent move changes that input without changing an
	// attribute, so discard the moved subtree's cached values before the next
	// selector match. Directionality is derived live in V and needs no cache
	// publication equivalent.
	if is_subtree_root == .yes {
		old_parent := old_ancestor
		new_parent := node.parent()
		mut parent_changed := new_parent != none
		if old_parent_node := old_parent {
			parent_changed = if new_parent_node := new_parent {
				old_parent_node != new_parent_node
			} else {
				true
			}
		}
		if parent_changed {
			node.for_each_shadow_including_inclusive_descendant(fn (descendant &Node) TraversalDecision {
				if element := descendant.as_element() {
					mut mutable_element := unsafe { &Element(element) }
					mutable_element.invalidate_lang_value()
				}
				return .@continue
			})
		}
	}
	if e.is_svg_element() {
		mut old_ancestor_described_paint_resource := false
		if old_ancestor_node := old_ancestor {
			if old_ancestor_element := old_ancestor_node.as_element() {
				old_ancestor_described_paint_resource = old_ancestor_element.describes_svg_paint_resource()
			}
		}
		if e.describes_svg_paint_resource() || old_ancestor_described_paint_resource {
			mut document := unsafe { &Document(e.document()) }
			document.note_svg_paint_resources_changed()
		}
	}

	// HTMLStyleElement::moved_from() and SVGStyleElement::moved_from().
	if mut style_element_base := e.style_element_base() {
		style_element_base.style_element_moved()
	}
	node.run_moved_from_lifecycle_hook(is_subtree_root, old_ancestor)
}

// SVGUseElement::adopted_from(). URL parsing is document-relative, so an
// adopted use element must resolve and clone its target from its new owner
// document. The V implementation observes referenced elements by walking the
// live document instead of retaining a document-specific observer/registry.
pub fn (mut e Element) adopted_from(_ &Document) {
	if e.is_svg_element() && e.local_name() == 'use' {
		e.svg_use_process_the_url()
	}

	// HTMLStyleElement::adopted_from() and SVGStyleElement::adopted_from().
	if style_element_base := e.style_element_base() {
		mut document := unsafe { &Document(e.document()) }
		style_element_base.retarget_style_load_event_delayer(mut document)
	}
}

pub fn (mut e Element) children_changed(metadata ChildrenChangedMetadata) {
	_ = metadata
	e.set_needs_style_update(true)

	if e.child_style_uses_tree_counting_function {
		for child in e.as_node().children {
			if element := child.as_element() {
				mut mutable_element := unsafe { &Element(element) }
				mutable_element.set_needs_style_update(true)
				mut node := unsafe { &Node(e.as_node()) }
				node.set_child_needs_style_update(true)
			}
		}
	}
	if e.is_svg_element() {
		e.update_use_elements_that_reference_this()
		e.note_svg_paint_resource_description_may_have_changed()
	}

	// HTMLStyleElement::children_changed() and SVGStyleElement::children_changed().
	if mut style_element_base := e.style_element_base() {
		style_element_base.update_a_style_block_for_dynamic_change()
	}
}

// --- element_to_inherit_style_from ---
pub fn (e &Element) element_to_inherit_style_from(pseudo_element ?int) ?&Element {
	if pseudo_element != none {
		return e
	}
	if assigned_slot := e.as_node().assigned_slot_internal() {
		return html_slot_element_as_element(assigned_slot)
	}
	return e.as_node().parent_or_shadow_host_element()
}

// --- Serialize ---
fn serialize_pseudo_element_as_json(element &Element, pseudo_element_type PseudoElement, mut sb strings.Builder, wrote_child bool) bool {
	pseudo_element := element.get_pseudo_element(int(pseudo_element_type)) or { return wrote_child }
	if pseudo_element.layout_node() == none {
		return wrote_child
	}
	if wrote_child {
		sb.write_string(',')
	}
	sb.write_string('{"name":${json_quote('::${pseudo_element_name(pseudo_element_type)}')},"type":"pseudo-element","parent-id":${element.as_node().unique_id().value()},"pseudo-element":${int(pseudo_element_type)}}')
	return true
}

pub fn (e &Element) serialize_children_as_json(mut sb strings.Builder) {
	has_pseudo_elements := e.has_pseudo_elements()
	if !e.is_shadow_host() && !e.as_node().has_children() && !has_pseudo_elements {
		return
	}

	sb.write_string(',"children":[')
	mut wrote_child := false

	if has_pseudo_elements {
		for pseudo_element_type in [PseudoElement.backdrop, .marker, .before] {
			wrote_child = serialize_pseudo_element_as_json(e, pseudo_element_type, mut sb, wrote_child)
		}
	}

	if shadow_root := e.shadow_root() {
		if wrote_child {
			sb.write_string(',')
		}
		unsafe { &Node(shadow_root) }.serialize_tree_as_json(mut sb)
		wrote_child = true
	}

	for child in e.as_node().children {
		if child.is_uninteresting_whitespace_node() {
			continue
		}
		if wrote_child {
			sb.write_string(',')
		}
		child.serialize_tree_as_json(mut sb)
		wrote_child = true
	}

	if has_pseudo_elements {
		wrote_child = serialize_pseudo_element_as_json(e, .after, mut sb, wrote_child)
		mut pseudo_element_types := e.rare_data_.pseudo_element_data.keys()
		pseudo_element_types.sort()
		for pseudo_element_type_int in pseudo_element_types {
			pseudo_element := e.rare_data_.pseudo_element_data[pseudo_element_type_int] or { continue }
			pseudo_element_type := unsafe { PseudoElement(pseudo_element_type_int) }
			if pseudo_element_type in [.after, .backdrop, .before, .marker]
				|| pseudo_element.layout_node() == none {
				continue
			}
			wrote_child = serialize_pseudo_element_as_json(e, pseudo_element_type, mut sb, wrote_child)
		}
	}

	sb.write_string(']')
}

// --- get_an_elements_target ---
pub fn (e &Element) get_an_elements_target(target ?string) string {
	mut resolved_target := target
	if resolved_target == none {
		if attr_target := e.get_attribute('target') {
			resolved_target = attr_target
		} else {
			doc := e.document()
			if doc != unsafe { nil } {
				if base_element := doc.first_base_element_with_target_in_tree_order() {
					resolved_target = unsafe { &Element(base_element) }.get_attribute('target')
				}
			}
		}
	}
	if t := resolved_target {
		if contains_ascii_tab_or_newline(t) && t.contains('<') {
			return '_blank'
		}
		return t
	}
	return ''
}

// https://html.spec.whatwg.org/multipage/links.html#get-an-element's-noopener
pub fn (e &Element) get_an_elements_noopener(url URL, target string) TokenizedFeatureNoOpener {
	_ = url
	// 1. If element's link types include the noopener or noreferrer keyword, then return true.
	rel := to_ascii_lowercase(e.get_attribute_value('rel'))
	link_types := split_on_ascii_whitespace(rel)
	if 'noopener' in link_types || 'noreferrer' in link_types {
		return .yes
	}

	// 2. If element's link types do not include the opener keyword and target is
	// an ASCII case-insensitive match for "_blank", then return true.
	if 'opener' !in link_types && to_ascii_lowercase(target) == '_blank' {
		return .yes
	}

	// 3. Blob URL origin checks depend on URL/relevant settings objects outside the DOM port.
	// 4. Return false.
	return .no
}

// https://html.spec.whatwg.org/multipage/links.html#following-hyperlinks-2
pub fn (mut e Element) follow_the_hyperlink(hyperlink_suffix ?string, user_involvement UserNavigationInvolvement) {
	// 1. If subject cannot navigate, then return.
	if e.cannot_navigate() {
		return
	}

	// 2. Let targetAttributeValue be the empty string.
	mut target_attribute_value := ''

	// 3. If subject is an a or area element, then set targetAttributeValue to the
	// result of getting an element's target given subject.
	if is_html_element_with_local_name(e, 'a') || is_html_element_with_local_name(e, 'area') || (e.is_svg_element() && e.local_name() == 'a') {
		target_attribute_value = e.get_an_elements_target(none)
	}

	// 4. Let urlRecord be the result of encoding-parsing a URL given subject's href
	// attribute value, relative to subject's node document.
	// 5. If urlRecord is failure, then return.
	url_record := e.document().encoding_parse_url(e.get_attribute_value('href')) or { return }

	// 6. Let noopener be the result of getting an element's noopener with subject, urlRecord, and targetAttributeValue.
	noopener := e.get_an_elements_noopener(url_record, target_attribute_value)

	// 7. Let targetNavigable be the first return value of applying the rules for choosing a navigable given
	//    targetAttributeValue, subject's node navigable, and noopener.
	navigable := e.document().navigable() or { return }
	// 8. If targetNavigable is null, then return.
	target_navigable := navigable.choose_a_navigable(target_attribute_value, noopener) or { return }

	// 9. Let urlString be the result of applying the URL serializer to urlRecord.
	url_string := url_record.serialize()

	// 10. If hyperlinkSuffix is non-null, then append it to urlString.
	mut url := url_record
	if suffix := hyperlink_suffix {
		url = dom_url_parse(url_string + suffix, url_record, 'UTF-8') or { return }
	}

	// 11. Let referrerPolicy be the current state of subject's referrerpolicy content attribute.
	referrer_policy := e.get_attribute_value('referrerpolicy')

	// FIXME: 12. If subject's link types includes the noreferrer keyword, then set referrerPolicy to "no-referrer".

	// 13. Navigate targetNavigable to urlString using subject's node document, with referrerPolicy set to referrerPolicy
	//     and userInvolvement set to userInvolvement.
	target_navigable.navigate(url, e.document(), referrer_policy, user_involvement) or {}
}

// https://html.spec.whatwg.org/multipage/links.html#downloading-hyperlinks
pub fn (mut e Element) download_the_hyperlink(hyperlink_suffix ?string, user_involvement UserNavigationInvolvement) {
	// 1. If subject cannot navigate, then return.
	if e.cannot_navigate() {
		return
	}

	// 2. Sandboxed documents cannot initiate downloads. SandboxingFlagSet is
	// represented as a cycle-safe bitset in DOM; bit 15 is HTML's sandboxed
	// downloads browsing-context flag.
	if e.document().active_sandboxing_flag_bits() & u32(32768) != 0 {
		return
	}

	// 3-4. Encoding-parse the href relative to the subject's document.
	mut url := e.document().encoding_parse_url(e.get_attribute_value('href')) or { return }

	// 5. The image-map suffix is appended to the serialized URL and parsed again.
	if suffix := hyperlink_suffix {
		url = dom_url_parse(url.serialize() + suffix, url, 'UTF-8') or { return }
	}

	// Read the attribute once before the navigate event can run script.
	download_attribute := e.get_attribute('download')
	navigable := e.document().navigable() or { return }
	navigable.download_hyperlink(url, user_involvement, e, download_attribute,
		e.document().origin())
}

// HTML's user navigation involvement of an event, https://html.spec.whatwg.org/multipage/browsing-the-web.html#event-uni.
// NB: DOM cannot import HTML, which owns this algorithm.
fn user_navigation_involvement_of_event(event &Event) UserNavigationInvolvement {
	// 1. Assert: event's type is "click".
	assert event.type_name() == 'click'

	// 2. If event's isTrusted is initialized to true, then return "activation".
	// 3. Return "none".
	return if event.is_trusted() { .activation } else { .none }
}

fn event_as_mouse_event(event &Event) ?&MouseEvent {
	if event.interface_ !in [.mouse_event, .wheel_event, .pointer_event] {
		return none
	}
	return unsafe { &MouseEvent(event) }
}

// https://html.spec.whatwg.org/multipage/links.html#hyperlink
pub fn (e &Element) creates_a_hyperlink() bool {
	// NB: The href attribute on a and area elements is not required; when those elements do not have href attributes
	//     they do not create hyperlinks.
	return (is_html_element_with_local_name(e, 'a') || is_html_element_with_local_name(e, 'area'))
		&& e.has_attribute('href')
}

fn event_target_is_ismap_image(event &Event) bool {
	target := event.target() or { return false }
	node := event_target_as_node(target) or { return false }
	image := node.as_element() or { return false }
	return is_html_element_with_local_name(image, 'img') && image.has_attribute('ismap')
}

// https://html.spec.whatwg.org/multipage/links.html#links-created-by-a-and-area-elements
pub fn (mut e Element) activate_the_hyperlink(event &Event) {
	// The activation behavior of an a or area element element given an event event is:

	// 1. If element has no href attribute, then return.
	// NB: SVG a elements may create a hyperlink using the deprecated xlink:href attribute.
	is_svg_a := e.is_svg_element() && e.local_name() == 'a'
	if !e.has_attribute('href') && !(is_svg_a && e.has_attribute_ns(namespace_xlink_uri, 'href')) {
		return
	}

	mouse_event := event_as_mouse_event(event)

	// AD-HOC: Do not activate the element for clicks with the ctrl/cmd modifier present. This lets
	//         the browser process open the link in a new tab.
	if mouse := mouse_event {
		if mouse.platform_ctrl_key() {
			return
		}
	}

	// 2. Let hyperlinkSuffix be null.
	mut hyperlink_suffix := ?string(none)

	// 3. If element is an a element, and event's target is an img with an ismap attribute specified:
	if is_html_element_with_local_name(e, 'a') && event_target_is_ismap_image(event) {
		// 1. Let x and y be 0.
		mut x := 0.0
		mut y := 0.0

		// 2. If event's isTrusted attribute is initialized to true, then set x to the distance in CSS pixels from the
		//    left edge of the image to the location of the click, and set y to the distance in CSS pixels from the
		//    top edge of the image to the location of the click.
		if event.is_trusted() {
			if mouse := mouse_event {
				x = mouse.offset_x()
				y = mouse.offset_y()
			}
		}

		// 3. If x is negative, set x to 0.
		if x < 0 {
			x = 0
		}

		// 4. If y is negative, set y to 0.
		if y < 0 {
			y = 0
		}

		// 5. Set hyperlinkSuffix to the concatenation of U+003F (?), the value of x expressed as a base-ten integer
		//    using ASCII digits, U+002C (,), and the value of y expressed as a base-ten integer using ASCII digits.
		hyperlink_suffix = '?${int(x)},${int(y)}'
	}

	// 4. Let userInvolvement be event's user navigation involvement.
	user_involvement := user_navigation_involvement_of_event(event)

	// 5. If the user has expressed a preference to download the hyperlink, then set userInvolvement to "browser UI".
	// NB: There is currently no way for the user to express a preference to download a hyperlink at activation
	//     time.

	// 6. If element has a download attribute, or if the user has expressed a preference to download the
	//    hyperlink, then download the hyperlink created by element with hyperlinkSuffix set to hyperlinkSuffix and
	//    userInvolvement set to userInvolvement.
	if e.has_attribute('download') {
		e.download_the_hyperlink(hyperlink_suffix, user_involvement)
		return
	}

	// 7. Otherwise, follow the hyperlink created by element with hyperlinkSuffix set to hyperlinkSuffix and
	//    userInvolvement set to userInvolvement.
	e.follow_the_hyperlink(hyperlink_suffix, user_involvement)
}

// --- Misc helpers ---
pub fn (e &Element) cannot_navigate() bool {
	doc := e.document()
	if doc == unsafe { nil } || !doc.is_fully_active() {
		return true
	}
	is_anchor := is_html_element_with_local_name(e, 'a') || (e.is_svg_element() && e.local_name() == 'a')
	return !is_anchor && !e.is_connected()
}

fn contains_ascii_tab_or_newline(value string) bool {
	for ch in value {
		if ch == `\t` || ch == `\n` || ch == `\r` {
			return true
		}
	}
	return false
}

pub fn (e &Element) is_html_element() bool {
	ns := e.namespace_uri() or { return false }
	return ns == namespace_html_uri
}

pub fn (e &Element) is_svg_element() bool {
	ns := e.namespace_uri() or { return false }
	return ns == namespace_svg_uri
}

pub fn (e &Element) is_svg_svg_element() bool {
	return e.is_svg_element() && e.local_name() == 'svg'
}

// https://svgwg.org/svg2-draft/coords.html#EstablishingANewSVGViewport
// The `svg` element and a `symbol` element instanced by a `use` element are the
// elements that establish a new SVG viewport.
pub fn (e &Element) is_svg_symbol_element() bool {
	return e.is_svg_element() && e.local_name() == 'symbol'
}

pub fn (e &Element) is_direct_child_of_svg_use_shadow_tree() bool {
	parent := e.as_node().parent() or { return false }
	shadow_root := parent.as_shadow_root() or { return false }
	host := shadow_root.host() or { return false }
	return host.is_svg_element() && host.local_name() == 'use'
}

fn svg_root_is_use_element_shadow_root(root &Node) bool {
	shadow_root := root.as_shadow_root() or { return false }
	host := shadow_root.host() or { return false }
	return host.is_svg_element() && host.local_name() == 'use'
}

fn (e &Element) svg_use_href() string {
	if href := e.get_attribute('href') {
		return href
	}
	if href := e.get_attribute_ns('http://www.w3.org/1999/xlink', 'href') {
		return href
	}
	return e.get_attribute_value('xlink:href')
}

fn (e &Element) svg_use_reference_url() ?URL {
	if !e.is_svg_element() || e.local_name() != 'use' {
		return none
	}
	href := e.svg_use_href()
	if href.len == 0 {
		return none
	}
	mut base := e.document().base_url()
	// A nested use cloned from an external symbol retains that symbol's URL
	// as its reference base after adoption into the embedding document.
	if shadow := e.as_node().root().as_shadow_root() {
		if host := shadow.host() {
			if host.is_svg_element() && host.local_name() == 'use' {
				if reference := host.svg_use_reference_url() { base = reference }
			}
		}
	}
	return dom_url_parse(href, base, e.document().encoding_or_default())
}

fn (e &Element) svg_use_reference_is_same_document(reference URL) bool {
	mut reference_without_fragment := reference
	reference_without_fragment.set_fragment(none)
	mut document_without_fragment := e.document().url
	document_without_fragment.set_fragment(none)
	return reference_without_fragment == document_without_fragment
}

pub fn (e &Element) svg_use_references_same_document() bool {
	reference := e.svg_use_reference_url() or { return false }
	return e.svg_use_reference_is_same_document(reference)
}

fn (e &Element) svg_use_referenced_element() ?&Element {
	reference := e.svg_use_reference_url() or { return none }
	fragment := reference.fragment() or { return none }
	if !e.svg_use_reference_is_same_document(reference) {
		resource := e.document().svg_use_resource_document(reference) or { return none }
		return resource.get_element_by_id(url_percent_decode(fragment))
	}
	return e.document().get_element_by_id(url_percent_decode(fragment))
}

fn svg_use_target_has_cycle(target &Element, mut visiting map[i64]bool) bool {
	key := target.as_node().unique_id().value()
	if visiting[key] {
		return true
	}
	visiting[key] = true
	if target.is_svg_element() && target.local_name() == 'use' {
		if referenced := target.svg_use_referenced_element() {
			if svg_use_target_has_cycle(referenced, mut visiting) {
				visiting.delete(key)
				return true
			}
		}
	}
	for child in target.as_node().children_as_vector() {
		if child_element := child.as_element() {
			if svg_use_target_has_cycle(child_element, mut visiting) {
				visiting.delete(key)
				return true
			}
		}
	}
	visiting.delete(key)
	return false
}

pub fn (e &Element) is_valid_svg_use_reference_element(target &Element) bool {
	if !target.is_svg_element() {
		return false
	}
	mut visiting := map[i64]bool{}
	return !svg_use_target_has_cycle(target, mut visiting)
}

fn (mut e Element) svg_use_clone_element_tree_as_our_shadow_tree(target ?&Element) {
	if !e.is_svg_element() || e.local_name() != 'use' {
		return
	}
	mut shadow_root := e.attach_a_user_agent_shadow_root(.named)
	mut shadow_node := unsafe { &Node(shadow_root) }
	shadow_node.remove_all_children(true)
	to_clone := target or {
		shadow_root.set_uses_document_style_sheets(false)
		return
	}
	same_document := if reference := e.svg_use_reference_url() {
		e.svg_use_reference_is_same_document(reference)
	} else {
		false
	}
	shadow_root.set_uses_document_style_sheets(same_document)
	if !e.is_valid_svg_use_reference_element(to_clone) {
		return
	}
	clone_node := to_clone.as_node().clone_node(e.document(), true, none) or { return }
	if mut clone_element := clone_node.as_element() {
		if clone_element.local_name() in ['svg', 'symbol'] {
			if e.has_attribute('width') {
				clone_element.set_attribute_value('width', e.get_attribute_value('width'))
			}
			if e.has_attribute('height') {
				clone_element.set_attribute_value('height', e.get_attribute_value('height'))
			}
		}
	}
	shadow_node.append_child(clone_node) or {}
	// Initial loading has not run inserted()'s document-complete branch yet.
	// Nested instances need their adopted shadow-tree base before first layout.
	if !e.document().is_completely_loaded() {
		clone_node.for_each_in_subtree(fn (node &Node) TraversalDecision {
			if element := node.as_element() {
				if element.is_svg_element() && element.local_name() == 'use' {
					mut nested := unsafe { &Element(element) }
					nested.svg_use_process_the_url()
				}
			}
			return .@continue
		})
	}
}

fn (mut e Element) svg_use_process_the_url() {
	target := e.svg_use_referenced_element()
	e.svg_use_clone_element_tree_as_our_shadow_tree(target)
}

pub fn (mut e Element) svg_element_changed(svg_element &Element) {
	if !e.is_svg_element() || e.local_name() != 'use' {
		return
	}
	to_clone := e.svg_use_referenced_element() or { return }
	if to_clone == svg_element || to_clone.as_node().is_ancestor_of(svg_element.as_node()) {
		e.svg_use_clone_element_tree_as_our_shadow_tree(to_clone)
	}
}

pub fn (mut e Element) svg_element_removed(svg_element &Element) {
	if !e.is_svg_element() || e.local_name() != 'use' {
		return
	}
	reference := e.svg_use_reference_url() or { return }
	fragment := reference.fragment() or { return }
	if !e.svg_use_reference_is_same_document(reference)
		|| svg_element.get_attribute_value('id') != url_percent_decode(fragment) {
		return
	}
	if shadow_root := e.shadow_root() {
		mut shadow_node := unsafe { &Node(shadow_root) }
		shadow_node.remove_all_children(true)
	}
}

pub fn (mut e Element) update_use_elements_that_reference_this() {
	if !e.is_svg_element() || e.local_name() == 'use' || e.id() == none || !e.is_connected()
		|| !e.document().is_completely_loaded() || e.as_node().root().as_shadow_root() != none {
		return
	}
	document_root := unsafe { &Node(e.document()) }
	changed_element := unsafe { &Element(e) }
	document_root.visit_subtree(fn [changed_element] (node &Node) TraversalDecision {
		if use_element := node.as_element() {
			if use_element.is_svg_element() && use_element.local_name() == 'use' {
				mut mutable_use := unsafe { &Element(use_element) }
				mutable_use.svg_element_changed(changed_element)
			}
		}
		return .@continue
	})
}

pub fn (mut e Element) remove_from_use_element_that_reference_this() {
	if !e.is_svg_element() || e.local_name() == 'use' || e.id() == none {
		return
	}
	document_root := unsafe { &Node(e.document()) }
	removed_element := unsafe { &Element(e) }
	document_root.visit_subtree(fn [removed_element] (node &Node) TraversalDecision {
		if use_element := node.as_element() {
			if use_element.is_svg_element() && use_element.local_name() == 'use' {
				mut mutable_use := unsafe { &Element(use_element) }
				mutable_use.svg_element_removed(removed_element)
			}
		}
		return .@continue
	})
}

pub fn (mut d Document) refresh_svg_use_shadow_trees() {
	document_root := unsafe { &Node(d) }
	document_root.for_each_in_subtree(fn (node &Node) TraversalDecision {
		if use_element := node.as_element() {
			if use_element.is_svg_element() && use_element.local_name() == 'use' {
				mut mutable_use := unsafe { &Element(use_element) }
				mutable_use.svg_use_process_the_url()
			}
		}
		return .@continue
	})
}

// Resource boxes for masks, clip paths, and patterns are attached to the
// referencing element's layout subtree. Keep the reverse edge so mutations of
// the resource invalidate every independently built resource subtree.
pub fn (mut e Element) register_svg_resource_box_referencing_element(referencing_element &Element) {
	for existing in e.svg_box_references() {
		if voidptr(existing) == voidptr(referencing_element) {
			return
		}
	}
	mut state := e.copy_dependency_data()
	state.svg_boxes = state.svg_boxes.clone()
	state.svg_boxes << referencing_element
	e.dependency_data_ = state
}

pub fn (mut e Element) mark_svg_resource_box_referencing_elements_for_layout_tree_update() {
	for referencing_element in e.svg_box_references() {
		mut node := unsafe { &Node(referencing_element.as_node()) }
		node.set_needs_layout_tree_update(true, .svg_resource_element_removed)
	}
	if e.svg_box_references().len > 0 {
		mut state := e.copy_dependency_data()
		state.svg_boxes = []&Element{}
		e.dependency_data_ = state
	}
}

pub fn (mut e Element) mark_svg_resource_box_referencing_elements_for_layout_update() {
	for referencing_element in e.svg_box_references() {
		mut node := unsafe { &Node(referencing_element.as_node()) }
		node.set_needs_layout_update(.svg_resource_element_attribute_change)
	}
}

pub fn (mut e Element) register_svg_paint_resource_referencing_element(referencing_element &Element) {
	// Paint projection registers dependencies, but its arena is retired after
	// the last scene. The resource retains this list for later invalidation.
	owner := e.document().native_storage()
	use_document := owner != unsafe { nil }
		&& voidptr(owner) == voidptr(platform.current_retained_arena())
	persistent := platform.enter_persistent_if(!use_document && platform.transient_arena_entered())
	mut retained := if use_document { platform.enter_retained_allocations() } else { platform.RetainedAllocationScope{} }
	defer {
		retained.finish()
		platform.leave_persistent(persistent)
	}
	for existing in e.svg_paint_references() {
		if voidptr(existing) == voidptr(referencing_element) {
			return
		}
	}
	mut state := e.copy_dependency_data()
	state.svg_paint = state.svg_paint.clone()
	state.svg_paint << referencing_element
	e.dependency_data_ = state
}

fn (mut e Element) mark_svg_paint_resource_referencing_elements_for_repaint() {
	for referencing_element in e.svg_paint_references() {
		mut node := unsafe { &Node(referencing_element.as_node()) }
		node.set_needs_repaint(.paint_commands)
	}
}

fn (e &Element) svg_paint_resource_element() ?&Element {
	if !e.is_svg_element() {
		return none
	}
	if e.local_name() in ['linearGradient', 'radialGradient', 'pattern', 'filter'] {
		return e
	}
	parent := e.as_node().parent_element() or { return none }
	return parent.svg_paint_resource_element()
}

pub fn (e &Element) describes_svg_paint_resource() bool {
	return e.svg_paint_resource_element() != none
}

pub fn (e &Element) note_svg_paint_resource_description_may_have_changed() {
	resource := e.svg_paint_resource_element() or { return }
	mut mutable_resource := unsafe { &Element(resource) }
	mutable_resource.mark_svg_paint_resource_referencing_elements_for_repaint()
	mut document := unsafe { &Document(e.document()) }
	document.note_svg_paint_resources_changed()
}

pub fn (mut d Document) note_svg_paint_resources_changed() {
	// Before the first committed layout there is no retained resource
	// description or display list to invalidate.
	if d.layout_engine_handle() != unsafe { nil } {
		// Ladybird republishes the resource descriptions in its visual-context
		// arena. V embeds those descriptions in the renderer paint tree, so
		// rebuild that transport from the retained DOM/layout state.
		d.set_needs_full_layout_tree_update(true)
		d.set_needs_repaint()
	}
}

// https://svgwg.org/svg2-draft/types.html#__svg__SVGElement__ownerSVGElement
//
// The nearest ancestor `svg` element in the flat tree; none when this element is
// the outermost `svg` element.
pub fn (e &Element) owner_svg_element() ?&Element {
	if !e.is_svg_element() {
		return none
	}
	mut ancestor := e.as_node().flat_tree_parent()
	for {
		current := ancestor or { return none }
		if element := current.as_element() {
			if element.is_svg_svg_element() {
				return element
			}
		}
		ancestor = current.flat_tree_parent()
	}
	return none
}

// https://svgwg.org/svg2-draft/types.html#__svg__SVGElement__viewportElement
//
// The nearest ancestor that establishes a new SVG viewport.
pub fn (e &Element) viewport_element() ?&Element {
	if !e.is_svg_element() {
		return none
	}
	mut ancestor := e.as_node().parent()
	for {
		current := ancestor or { return none }
		if element := current.as_element() {
			if element.is_svg_svg_element() || element.is_svg_symbol_element() {
				return element
			}
		}
		ancestor = current.parent_or_shadow_host()
	}
	return none
}

// https://svgwg.org/svg2-draft/struct.html#__svg__SVGSVGElement__deselectAll
//
// Equivalent to calling document.getSelection().removeAllRanges().
pub fn (e &Element) deselect_all() {
	if !e.is_svg_svg_element() {
		return
	}
	mut selection := e.document().get_selection() or { return }
	selection.remove_all_ranges()
}

pub fn (e &Element) is_html_ol_ul_menu_element() bool {
	name := e.local_name()
	return name == 'ol' || name == 'ul' || name == 'menu'
}

pub fn (e &Element) is_html_ol_element() bool {
	return e.namespace_uri() or { '' } == namespace_html_ && e.local_name() == 'ol'
}

pub fn (e &Element) is_html_li_element() bool {
	return e.namespace_uri() or { '' } == namespace_html_ && e.local_name() == 'li'
}

pub fn (e &Element) id_reference_exists(id string) bool {
	doc := e.document()
	if doc == unsafe { nil } {
		return false
	}
	return doc.get_element_by_id(id) != none
}

pub fn (e &Element) is_scripting_enabled() bool {
	doc := e.document()
	if doc == unsafe { nil } {
		return false
	}
	return doc.is_scripting_enabled()
}

pub fn (mut e Element) append_child(child &Element) {
	mut node := unsafe { &Node(&e) }
	node.append_child(child.as_node()) or {}
}

// https://html.spec.whatwg.org/multipage/common-dom-interfaces.html#attr-associated-elements
//
// Returns `none` only when the attribute is absent and there are no explicitly
// set attribute elements (matching C++'s `Optional<...>` empty result). When
// some explicitly set elements exist but none qualify, an empty list is
// returned to mirror the spec behaviour.
pub fn (e &Element) get_the_attribute_associated_elements(content_attribute string, explicitly_set_attribute_elements ?[]&Element) ?[]&Element {
	mut elements := []&Element{}

	// 3. If reflectedTarget's explicitly set attr-elements is not null:
	if explicit := explicitly_set_attribute_elements {
		shadow_root := e.as_node().shadow_including_root()
		for attr_element in explicit {
			if attr_element == unsafe { nil } {
				continue
			}
			// 1. If attrElement is not a descendant of any of element's
			//    shadow-including ancestors, then continue.
			if attr_element.as_node().shadow_including_root() != shadow_root {
				continue
			}
			elements << attr_element
		}
		return elements
	}

	// 4. Otherwise:
	// 1. Let contentAttributeValue be the result of running reflectedTarget's
	//    get the content attribute.
	content_attribute_value := e.get_attribute(content_attribute) or { return none }

	// 3. Let tokens be contentAttributeValue, split on ASCII whitespace.
	doc := e.document()
	for token in content_attribute_value.fields() {
		if token.len == 0 {
			continue
		}
		// 1. Let candidate be the first element ... whose ID is token.
		if doc != unsafe { nil } {
			if candidate := doc.get_element_by_id(token) {
				elements << candidate
			}
		}
	}

	return elements
}
