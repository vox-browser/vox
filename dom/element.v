// Copyright (c) 2018-2024, Andreas Kling <andreas@ladybird.org>
// Copyright (c) 2022-2023, Sam Atkins <atkinssj@serenityos.org>
// Copyright (c) 2025, Simon Farre <simon.farre.cx@gmail.com>
//
// SPDX-License-Identifier: BSD-2-Clause
//
// Translated from Libraries/LibWeb/DOM/Element.cpp

module dom

import math
import strings

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
	attrs []&Attr_
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

pub fn (n &NamedNodeMap) get_attribute(name string) ?&Attr_ {
	for a in n.attrs {
		if a.name_ == name {
			return a
		}
	}
	return none
}

pub fn (n &NamedNodeMap) get_attribute_ns(namespace_ ?string, local_name string) ?&Attr_ {
	for a in n.attrs {
		if a.namespace_uri_ == namespace_ && a.local_name_ == local_name {
			return a
		}
	}
	return none
}

pub fn (mut n NamedNodeMap) append_attribute(attr &Attr_) {
	n.attrs << attr
}

pub fn (mut n NamedNodeMap) remove_attribute(name string) {
	n.attrs = n.attrs.filter(it.name_ != name)
}

pub fn (mut n NamedNodeMap) remove_attribute_node(attr &Attr_) {
	n.attrs = n.attrs.filter(it != attr)
}

// Attr_ is named with underscore to avoid conflict with document.v's empty Attr stub
@[heap]
pub struct Attr_ {
pub mut:
	name_          string
	value_         string
	local_name_    string
	prefix__       ?string
	namespace_uri_ ?string
}

pub fn (a &Attr_) name() string {
	return a.name_
}

pub fn (a &Attr_) value() string {
	return a.value_
}

pub struct DOMTokenList_ {
pub mut:
	tokens []string
}

pub fn (mut d DOMTokenList_) associated_attribute_changed(value string) {
	_ = value
}

pub struct ShadowRootInit {
pub mut:
	mode            ShadowRootMode
	delegates_focus bool
	slot_assignment SlotAssignmentMode = .named
	clonable        bool
	serializable    bool
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

// https://w3c.github.io/csswg-drafts/cssom-view-1/#dictdef-scrollintoviewoptions
pub struct ScrollIntoViewOptions {
pub mut:
	block    ScrollLogicalPosition = .start
	inline_  ScrollLogicalPosition = .nearest
	behavior ScrollBehavior        = .auto_
}

pub enum ScrollLogicalPosition {
	start
	center
	end_
	nearest
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

pub struct CustomElementDefinition {
pub mut:
	disable_shadow_     bool
	construction_stack  []&Element
	name_               string
	observed_attributes []string
}

pub fn (d &CustomElementDefinition) disable_shadow() bool {
	return d.disable_shadow_
}

pub struct CustomStateSet_ {}

@[heap]
pub struct CSSStyleProperties_ {
pub mut:
	is_updating_ bool
}

pub fn (c &CSSStyleProperties_) is_updating() bool {
	return c.is_updating_
}

@[heap]
pub struct CSSComputedProperties_ {
pub mut:
	display_    CSSDisplay_ = CSSDisplay_{}
	overflow_x_ CSSOverflow_ = .visible
	overflow_y_ CSSOverflow_ = .visible
}

pub fn (c &CSSComputedProperties_) display() CSSDisplay_ {
	return c.display_
}

pub fn (c &CSSComputedProperties_) overflow_x() CSSOverflow_ {
	return c.overflow_x_
}

pub fn (c &CSSComputedProperties_) overflow_y() CSSOverflow_ {
	return c.overflow_y_
}

pub fn (c &CSSComputedProperties_) view_transition_name() ?string {
	return none
}

pub struct CSSDisplay_ {
pub mut:
	is_none_      bool
	is_list_item_ bool
}

pub fn (d CSSDisplay_) is_none() bool {
	return d.is_none_
}

pub fn (d CSSDisplay_) is_list_item() bool {
	return d.is_list_item_
}

pub enum CSSOverflow_ {
	visible
	hidden
	scroll
	auto_
	clip
}

@[heap]
pub struct CSSCascadedProperties_ {}

@[heap]
pub struct CSSCustomPropertyData_ {}

pub struct CSSCountersSet_ {}

pub fn (mut c CSSCountersSet_) visit_edges(visitor &CellVisitor) {
	_ = visitor
}

pub struct RequiredInvalidationAfterStyleChange {
pub mut:
	relayout            bool
	rebuild_layout_tree bool
	repaint             bool
}

pub fn (r RequiredInvalidationAfterStyleChange) is_none() bool {
	return !r.relayout && !r.rebuild_layout_tree && !r.repaint
}

fn required_invalidation_full() RequiredInvalidationAfterStyleChange {
	return RequiredInvalidationAfterStyleChange{
		relayout: true
		rebuild_layout_tree: true
		repaint: true
	}
}

@[heap]
pub struct PseudoElement_ {
pub mut:
	layout_node_     ?&LayoutNodeWithStyle_
	computed_props   ?&CSSComputedProperties_
	cascaded_props   ?&CSSCascadedProperties_
	custom_prop_data ?&CSSCustomPropertyData_
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

pub fn (p &PseudoElement_) cascaded_properties() ?&CSSCascadedProperties_ {
	return p.cascaded_props
}

pub fn (mut p PseudoElement_) set_cascaded_properties(props ?&CSSCascadedProperties_) {
	p.cascaded_props = props
}

pub fn (p &PseudoElement_) custom_property_data() ?&CSSCustomPropertyData_ {
	return p.custom_prop_data
}

pub fn (mut p PseudoElement_) set_custom_property_data(data ?&CSSCustomPropertyData_) {
	p.custom_prop_data = data
}

@[heap]
pub struct LayoutNodeWithStyle_ {}

pub fn (n &LayoutNodeWithStyle_) apply_style(props &CSSComputedProperties_) {
	_ = props
}

pub fn (n &LayoutNodeWithStyle_) is_scroll_container() bool {
	return false
}

pub struct PaintableBox_ {
pub mut:
	scroll_offset_ CSSPixelPoint_
}

pub fn (p &PaintableBox_) scroll_offset() CSSPixelPoint_ {
	return p.scroll_offset_
}

pub fn (mut p PaintableBox_) set_scroll_offset(offset CSSPixelPoint_) {
	p.scroll_offset_ = offset
}

pub fn (p &PaintableBox_) scrollable_overflow_rect() ?CSSPixelRect_ {
	return CSSPixelRect_{}
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

pub struct IntersectionObserverRegistration_ {
pub mut:
	observer voidptr
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
	true_
}

// Union type for custom element reaction queue
pub type CustomElementReaction = CustomElementUpgradeReaction | CustomElementCallbackReaction

const namespace_html_uri = 'http://www.w3.org/1999/xhtml'
const namespace_svg_uri = 'http://www.w3.org/2000/svg'
const namespace_xml_uri = 'http://www.w3.org/XML/1998/namespace'

// Valid shadow host names
const valid_shadow_host_names = ['article', 'aside', 'blockquote', 'body', 'div', 'footer',
	'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'header', 'main', 'nav', 'p', 'section', 'span']

// --- Element struct ---

@[heap]
pub struct Element {
	ParentNode
pub mut:
	qualified_name                  QualifiedName
	html_uppercased_qualified_name_ ?string

	attributes_      ?&NamedNodeMap
	inline_style_    ?&CSSStyleProperties_
	attribute_style_map_ ?&StylePropertyMap_
	class_list_      ?&DOMTokenList_
	shadow_root_     ?&ShadowRoot
	part_list_       ?&DOMTokenList_

	cascaded_properties_ ?&CSSCascadedProperties_
	computed_properties_ ?&CSSComputedProperties_
	custom_property_data_ ?&CSSCustomPropertyData_

	pseudo_element_data map[int]&PseudoElement_

	use_pseudo_element ?int

	classes []string
	parts   []string
	dir__   ?Dir

	id_   ?string
	name_ ?string

	custom_element_reaction_queue  []CustomElementReaction
	custom_element_definition_     ?&CustomElementDefinition
	is_value                       ?string
	custom_state_set_              ?&CustomStateSet_

	registered_intersection_observers []IntersectionObserverRegistration_
	computed_style_map_cache_         ?&StylePropertyMapReadOnly_

	scroll_offset_ CSSPixelPoint_

	// Boolean flags
	is_being_activated                                                         bool
	in_top_layer                                                               bool
	rendered_in_top_layer                                                      bool
	style_uses_attr_css_function                                               bool
	style_uses_var_css_function                                                bool
	style_uses_tree_counting_function                                          bool
	style_uses_if_css_function                                                 bool
	style_uses_inherit_css_function                                            bool
	child_style_uses_tree_counting_function                                    bool
	affected_by_has_pseudo_class_in_subject_position                           bool
	affected_by_has_pseudo_class_in_non_subject_position                       bool
	affected_by_direct_sibling_combinator                                      bool
	affected_by_indirect_sibling_combinator                                    bool
	affected_by_first_child_pseudo_class                                       bool
	affected_by_last_child_pseudo_class                                        bool
	affected_by_forward_positional_pseudo_class                                bool
	affected_by_backward_positional_pseudo_class                               bool
	affected_by_has_pseudo_class_with_relative_selector_that_has_sibling_combinator bool
	fullscreen_flag                                                            bool

	sibling_invalidation_distance int

	counters_set_  ?&CSSCountersSet_
	ordinal_value_ ?int
	lang_value_    ?string

	had_duplicate_attribute_during_tokenization bool
	custom_element_state_                       CustomElementState = .undefined_
	proximity_to_the_viewport_                  ProximityToTheViewport = .not_determined
	captured_in_a_view_transition               bool
	is_contained_in_list_subtree                bool

	element_specific_css_random_base_value_cache map[string]f64

	doc_ ?&Document
}

pub struct StylePropertyMap_ {}

pub struct StylePropertyMapReadOnly_ {}

// --- Constructor ---

pub fn Element.new(doc &Document, qname QualifiedName) &Element {
	return &Element{
		qualified_name: qname
		doc_: doc
	}
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
	if pl := e.part_list_ {
		visitor.visit(pl)
	}
	if ced := e.custom_element_definition_ {
		visitor.visit(ced)
	}
	if cp := e.cascaded_properties_ {
		visitor.visit(cp)
	}
	if cp := e.computed_properties_ {
		visitor.visit(cp)
	}
	if csm := e.computed_style_map_cache_ {
		visitor.visit(csm)
	}
	if asm_ := e.attribute_style_map_ {
		visitor.visit(asm_)
	}
	for _, pe in e.pseudo_element_data {
		visitor.visit(pe)
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
	return e.qualified_name.local_name.to_lower()
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
	if cached := e.html_uppercased_qualified_name_ {
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
	mut attrs := e.ensure_attributes()
	if existing := attrs.get_attribute(local_name) {
		unsafe {
			existing.value_ = value
		}
	} else {
		attrs.append_attribute(&Attr_{
			name_: local_name
			value_: value
			local_name_: local_name
		})
	}
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
		for a in attrs.attrs {
			if a.namespace_uri_ == namespace_ && a.local_name_ == name {
				attrs.remove_attribute_node(a)
				return
			}
		}
	}
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
			actual_name = name.to_lower()
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

	if force == none || !(force or { true }) {
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
	new_attrs := &NamedNodeMap{}
	e.attributes_ = new_attrs
	return new_attrs
}

// --- Attribute associated elements ---

// https://html.spec.whatwg.org/multipage/common-dom-interfaces.html#attr-associated-element
pub fn (e &Element) get_the_attribute_associated_element(content_attribute string, explicitly_set ?&Element) ?&Element {
	if exp := explicitly_set {
		return exp
	}
	content_attribute_value := e.get_attribute(content_attribute) or { return none }
	doc := e.document()
	if doc == unsafe { nil } {
		return none
	}
	return doc.get_element_by_id(content_attribute_value)
}

// --- Class / Part lists ---

// https://dom.spec.whatwg.org/#dom-element-classlist
pub fn (mut e Element) class_list() &DOMTokenList_ {
	if cl := e.class_list_ {
		return cl
	}
	new_cl := &DOMTokenList_{}
	e.class_list_ = new_cl
	return new_cl
}

// https://drafts.csswg.org/css-shadow-1/#dom-element-part
pub fn (mut e Element) part_list() &DOMTokenList_ {
	if pl := e.part_list_ {
		return pl
	}
	new_pl := &DOMTokenList_{}
	e.part_list_ = new_pl
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
	lower := class_name.to_lower()
	for c in e.classes {
		if c.to_lower() == lower {
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
	if name.contains('-') && name.len > 0 {
		return true
	}
	return false
}

// https://dom.spec.whatwg.org/#concept-attach-a-shadow-root
pub fn (mut e Element) attach_a_shadow_root(mode ShadowRootMode, clonable bool, serializable bool, delegates_focus bool, slot_assignment SlotAssignmentMode) ! {
	ns := e.namespace_uri() or { return error('NotSupportedError: Element namespace is not HTML') }
	if ns != namespace_html_uri {
		return error('NotSupportedError: Element namespace is not HTML')
	}
	if !is_valid_shadow_host_name(e.local_name()) {
		return error('NotSupportedError: Element local name is not a valid shadow host name')
	}
	if e.local_name().contains('-') || e.is_value != none {
		if def := e.custom_element_definition_ {
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
			unsafe {
				sr.declarative = false
			}
			return
		}
	}
	shadow := &ShadowRoot{
		mode: mode
	}
	e.shadow_root_ = shadow
}

// https://dom.spec.whatwg.org/#dom-element-attachshadow
pub fn (mut e Element) attach_shadow(init ShadowRootInit) !&ShadowRoot {
	e.attach_a_shadow_root(init.mode, init.clonable, init.serializable, init.delegates_focus, init.slot_assignment)!
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
	e.shadow_root_ = sr
}

// --- Selector matching ---

// https://dom.spec.whatwg.org/#dom-element-matches
pub fn (e &Element) matches(selectors string) !bool {
	_ = selectors
	return false
}

// https://dom.spec.whatwg.org/#dom-element-closest
pub fn (e &Element) closest(selectors string) ?&Element {
	_ = selectors
	return none
}

// --- CSSOM View: client* ---

// https://drafts.csswg.org/cssom-view/#dom-element-clienttop
pub fn (e &Element) client_top() int {
	return 0
}

// https://drafts.csswg.org/cssom-view/#dom-element-clientleft
pub fn (e &Element) client_left() int {
	return 0
}

// https://drafts.csswg.org/cssom-view/#dom-element-clientwidth
pub fn (e &Element) client_width() int {
	return 0
}

// https://drafts.csswg.org/cssom-view/#dom-element-clientheight
pub fn (e &Element) client_height() int {
	return 0
}

// https://drafts.csswg.org/cssom-view/#dom-element-currentcsszoom
pub fn (e &Element) current_css_zoom() f64 {
	return 1.0
}

// --- Layout node ---

pub fn (e &Element) el_layout_node() ?&LayoutNodeWithStyle_ {
	return none
}

pub fn (e &Element) el_unsafe_layout_node() ?&LayoutNodeWithStyle_ {
	return none
}

pub fn (e &Element) paintable_box() ?&PaintableBox_ {
	return none
}

// --- Style / Computed properties ---

pub fn (e &Element) el_computed_properties() ?&CSSComputedProperties_ {
	return e.computed_properties_
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
	e.computed_properties_ = style
}

pub fn (e &Element) el_cascaded_properties(pseudo_element ?int) ?&CSSCascadedProperties_ {
	if pe := pseudo_element {
		if pseudo := e.get_pseudo_element(pe) {
			return pseudo.cascaded_properties()
		}
		return none
	}
	return e.cascaded_properties_
}

pub fn (mut e Element) set_cascaded_properties(pseudo_element ?int, cascaded ?&CSSCascadedProperties_) {
	if pe := pseudo_element {
		if c := cascaded {
			mut pseudo := e.ensure_pseudo_element(pe)
			pseudo.set_cascaded_properties(c)
		} else if existing := e.get_pseudo_element(pe) {
			unsafe {
				existing.cascaded_props = none
			}
		}
		return
	}
	e.cascaded_properties_ = cascaded
}

pub fn (e &Element) get_pseudo_element(typ int) ?&PseudoElement_ {
	return e.pseudo_element_data[typ] or { return none }
}

fn (mut e Element) ensure_pseudo_element(typ int) &PseudoElement_ {
	if existing := e.pseudo_element_data[typ] {
		return existing
	}
	pe := &PseudoElement_{}
	e.pseudo_element_data[typ] = pe
	return pe
}

pub fn (e &Element) has_pseudo_element(typ int) bool {
	pe := e.pseudo_element_data[typ] or { return false }
	return pe.layout_node() != none
}

pub fn (e &Element) has_pseudo_elements() bool {
	for _, pe in e.pseudo_element_data {
		if pe.layout_node() != none {
			return true
		}
	}
	return false
}

pub fn (mut e Element) clear_pseudo_element_nodes() {
	for _, mut pe in e.pseudo_element_data {
		pe.set_layout_node(none)
	}
}

pub fn (mut e Element) set_pseudo_element_node(pseudo_element int, node ?&LayoutNodeWithStyle_) {
	mut pe := e.ensure_pseudo_element(pseudo_element)
	pe.set_layout_node(node)
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
}

// https://drafts.csswg.org/cssom/#dom-elementcssinlinestyle-style
pub fn (mut e Element) style_for_bindings() &CSSStyleProperties_ {
	if s := e.inline_style_ {
		return s
	}
	new_style := &CSSStyleProperties_{}
	e.inline_style_ = new_style
	return new_style
}

pub fn (mut e Element) el_attribute_style_map() &StylePropertyMap_ {
	if m := e.attribute_style_map_ {
		return m
	}
	new_map := &StylePropertyMap_{}
	e.attribute_style_map_ = new_map
	return new_map
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
	e.attribute_changed(local_name, old_value, value, namespace_)
	if old_value != value {
		e.invalidate_style_after_attribute_change(local_name, old_value, value)
	}
}

// --- recompute_style ---

pub fn (mut e Element) recompute_style() RequiredInvalidationAfterStyleChange {
	e.style_uses_attr_css_function = false
	e.style_uses_var_css_function = false
	e.style_uses_tree_counting_function = false
	e.style_uses_if_css_function = false
	e.style_uses_inherit_css_function = false
	e.affected_by_has_pseudo_class_in_subject_position = false
	e.affected_by_has_pseudo_class_in_non_subject_position = false
	e.affected_by_has_pseudo_class_with_relative_selector_that_has_sibling_combinator = false
	e.affected_by_direct_sibling_combinator = false
	e.affected_by_indirect_sibling_combinator = false
	e.affected_by_first_child_pseudo_class = false
	e.affected_by_last_child_pseudo_class = false
	e.affected_by_forward_positional_pseudo_class = false
	e.affected_by_backward_positional_pseudo_class = false
	e.sibling_invalidation_distance = 0

	mut invalidation := RequiredInvalidationAfterStyleChange{}
	if e.computed_properties_ == none {
		invalidation = required_invalidation_full()
	}
	return invalidation
}

// --- recompute_inherited_style ---

pub fn (mut e Element) recompute_inherited_style() RequiredInvalidationAfterStyleChange {
	if e.cascaded_properties_ == none || e.computed_properties_ == none || e.el_unsafe_layout_node() == none {
		return RequiredInvalidationAfterStyleChange{}
	}
	return RequiredInvalidationAfterStyleChange{}
}

// --- Inner/Outer HTML ---

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-element-innerhtml
pub fn (mut e Element) set_inner_html(value string) ! {
	_ = value
}

pub fn (e &Element) inner_html() !string {
	return ''
}

pub fn (e &Element) outer_html() !string {
	return ''
}

pub fn (mut e Element) set_outer_html(value string) ! {
	_ = value
}

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-element-sethtmlunsafe
pub fn (mut e Element) set_html_unsafe(html string) ! {
	_ = html
}

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-element-gethtml
pub fn (e &Element) get_html(options GetHTMLOptions) !string {
	_ = options
	return ''
}

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#the-insertadjacenthtml()-method
pub fn (mut e Element) insert_adjacent_html(position string, text string) ! {
	lower_pos := position.to_lower()
	if lower_pos !in ['beforebegin', 'afterbegin', 'beforeend', 'afterend'] {
		return error('SyntaxError: insertAdjacentHTML: invalid position argument')
	}
	_ = text
}

// --- Focus / Active ---

pub fn (e &Element) is_focused() bool {
	// Stub: would check if document's focused area is this element
	return false
}

pub fn (e &Element) is_the_active_element() bool {
	// Stub: would check if document's active element is this element
	return false
}

pub fn (e &Element) el_is_being_activated() bool {
	return e.is_being_activated
}

pub fn (mut e Element) set_being_activated(active bool) {
	if e.is_being_activated == active {
		return
	}
	e.is_being_activated = active
}

pub fn (e &Element) is_target() bool {
	doc := e.document()
	if doc == unsafe { nil } {
		return false
	}
	// Stub: would compare doc's target element with this
	_ = doc
	return false
}

pub fn (e &Element) is_document_element() bool {
	doc := e.document()
	if doc == unsafe { nil } {
		return false
	}
	return doc.document_element() or { return false } == e
}

// --- Void elements ---

pub fn (e &Element) is_void_element() bool {
	name := e.local_name()
	return name in ['area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link',
		'meta', 'param', 'source', 'track', 'wbr']
}

pub fn (e &Element) serializes_as_void() bool {
	return e.is_void_element()
}

// --- Bounding rects ---

// https://drafts.csswg.org/cssom-view/#dom-element-getboundingclientrect
pub fn (e &Element) get_bounding_client_rect() Rect {
	return Rect{}
}

pub fn (e &Element) get_client_rects() []CSSPixelRect_ {
	return []
}

// --- Tab index ---

pub fn (e &Element) default_tab_index_value() int {
	return -1
}

// https://html.spec.whatwg.org/multipage/interaction.html#dom-tabindex
pub fn (e &Element) tab_index() int {
	tab_str := e.get_attribute_value('tabindex')
	if tab_str.len == 0 {
		return e.default_tab_index_value()
	}
	return tab_str.int()
}

pub fn (mut e Element) set_tab_index(tab_index int) {
	e.set_attribute_value('tabindex', tab_index.str())
}

// --- Scrolling ---

// https://drafts.csswg.org/cssom-view/#potentially-scrollable
pub fn (e &Element) is_potentially_scrollable() bool {
	if e.el_layout_node() == none {
		return false
	}
	return false
}

pub fn (e &Element) is_scroll_container() bool {
	if e.is_document_element() {
		return true
	}
	return false
}

// https://drafts.csswg.org/cssom-view/#dom-element-scrolltop
pub fn (e &Element) scroll_top() f64 {
	doc := e.document()
	if doc == unsafe { nil } || !doc.is_active() {
		return 0.0
	}
	if e.is_document_element() && doc.in_quirks_mode() {
		return 0.0
	}
	if e.is_document_element() {
		// Would return window.scroll_y()
		return 0.0
	}
	if pb := e.paintable_box() {
		return pb.scroll_offset().y()
	}
	return 0.0
}

// https://drafts.csswg.org/cssom-view/#dom-element-scrollleft
pub fn (e &Element) scroll_left() f64 {
	doc := e.document()
	if doc == unsafe { nil } || !doc.is_active() {
		return 0.0
	}
	if e.is_document_element() && doc.in_quirks_mode() {
		return 0.0
	}
	if e.is_document_element() {
		// Would return window.scroll_x()
		return 0.0
	}
	if pb := e.paintable_box() {
		return pb.scroll_offset().x()
	}
	return 0.0
}

// https://drafts.csswg.org/cssom-view/#dom-element-scrollleft
pub fn (mut e Element) set_scroll_left(x_ f64) {
	x := normalize_non_finite(x_)
	doc := e.document()
	if doc == unsafe { nil } || !doc.is_active() {
		return
	}
	if e.is_document_element() && doc.in_quirks_mode() {
		return
	}
	if e.is_document_element() {
		// Would invoke window.scroll(x, window.scroll_y())
		return
	}
	if mut pb := e.paintable_box() {
		mut offset := pb.scroll_offset()
		offset.set_x(x)
		pb.set_scroll_offset(offset)
	}
}

// https://drafts.csswg.org/cssom-view/#dom-element-scrolltop
pub fn (mut e Element) set_scroll_top(y_ f64) {
	y := normalize_non_finite(y_)
	doc := e.document()
	if doc == unsafe { nil } || !doc.is_active() {
		return
	}
	if e.is_document_element() && doc.in_quirks_mode() {
		return
	}
	if e.is_document_element() {
		// Would invoke window.scroll(window.scroll_x(), y)
		return
	}
	if mut pb := e.paintable_box() {
		mut offset := pb.scroll_offset()
		offset.set_y(y)
		pb.set_scroll_offset(offset)
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
	x := normalize_non_finite(x_)
	y := normalize_non_finite(y_)
	doc := e.document()
	if doc == unsafe { nil } || !doc.is_active() {
		return &Promise{}
	}
	if e.is_document_element() && doc.in_quirks_mode() {
		return &Promise{}
	}
	if e.is_document_element() {
		// Would invoke window.scroll()
		return &Promise{}
	}
	if mut pb := e.paintable_box() {
		mut offset := pb.scroll_offset()
		offset.set_x(x)
		offset.set_y(y)
		pb.set_scroll_offset(offset)
	}
	return &Promise{}
}

pub fn (mut e Element) scroll_by(x_ f64, y_ f64) &Promise {
	x := normalize_non_finite(x_)
	y := normalize_non_finite(y_)
	return e.el_scroll(e.scroll_left() + x, e.scroll_top() + y)
}

pub fn (e &Element) el_scroll_offset() CSSPixelPoint_ {
	return e.scroll_offset_
}

pub fn (mut e Element) set_scroll_offset_internal(typ ?int, offset CSSPixelPoint_) {
	_ = typ
	e.scroll_offset_ = offset
}

// https://w3c.github.io/csswg-drafts/cssom-view-1/#dom-element-scrollintoview
pub fn (mut e Element) scroll_into_view() &Promise {
	return &Promise{}
}

// --- Fullscreen ---

// https://fullscreen.spec.whatwg.org/#dom-element-requestfullscreen
pub fn (mut e Element) request_fullscreen(requester FullscreenRequester) &Promise {
	promise := &Promise{}
	doc := e.document()
	if doc == unsafe { nil } || !doc.is_fully_active() {
		return promise
	}
	_ = e.is_element_allowed_to_enter_fullscreen(requester)
	return promise
}

pub fn (e &Element) is_element_allowed_to_enter_fullscreen(requester FullscreenRequester) RequestFullscreenError {
	_ = requester
	return .false_
}

pub fn (e &Element) is_element_ready_for_fullscreen() bool {
	return true
}

pub fn (mut e Element) set_fullscreen_flag(v bool) {
	e.fullscreen_flag = v
}

pub fn (e &Element) is_fullscreen_element() bool {
	return e.fullscreen_flag
}

fn (mut e Element) exit_fullscreen_on_element_removal() {
	// Stub
}

// --- Actually disabled ---

// https://html.spec.whatwg.org/multipage/semantics-other.html#concept-element-disabled
pub fn (e &Element) is_actually_disabled() bool {
	return false
}

// --- Insert adjacent ---

pub fn (mut e Element) insert_adjacent_element(where_ string, element &Element) ?&Element {
	_ = where_
	_ = element
	return none
}

pub fn (mut e Element) insert_adjacent_text(where_ string, data string) ! {
	_ = where_
	_ = data
}

// --- check_visibility ---

// https://drafts.csswg.org/cssom-view-1/#dom-element-checkvisibility
pub fn (e &Element) check_visibility(options ?CheckVisibilityOptions) bool {
	if e.el_layout_node() == none {
		return false
	}
	return true
}

// --- Intersection observers ---

pub fn (mut e Element) register_intersection_observer(registration IntersectionObserverRegistration_) {
	e.registered_intersection_observers << registration
}

pub fn (mut e Element) unregister_intersection_observer(observer voidptr) {
	e.registered_intersection_observers = e.registered_intersection_observers.filter(it.observer != observer)
}

// --- Custom elements ---

fn (mut e Element) enqueue_an_element_on_the_appropriate_element_queue() {
	// Stub
}

// https://html.spec.whatwg.org/multipage/custom-elements.html#enqueue-a-custom-element-upgrade-reaction
pub fn (mut e Element) enqueue_a_custom_element_upgrade_reaction(definition &CustomElementDefinition) {
	e.custom_element_reaction_queue << CustomElementUpgradeReaction{
		custom_element_definition: definition
	}
	e.enqueue_an_element_on_the_appropriate_element_queue()
}

// https://html.spec.whatwg.org/multipage/custom-elements.html#enqueue-a-custom-element-callback-reaction
pub fn (mut e Element) enqueue_a_custom_element_callback_reaction(callback_name string, arguments []string) {
	_ = callback_name
	e.custom_element_reaction_queue << CustomElementCallbackReaction{
		arguments: arguments
	}
	e.enqueue_an_element_on_the_appropriate_element_queue()
}

pub fn (mut e Element) ensure_custom_state_set() &CustomStateSet_ {
	if cs := e.custom_state_set_ {
		return cs
	}
	new_cs := &CustomStateSet_{}
	e.custom_state_set_ = new_cs
	return new_cs
}

// https://html.spec.whatwg.org/multipage/custom-elements.html#concept-upgrade-an-element
pub fn (mut e Element) upgrade_element(definition &CustomElementDefinition) ! {
	if e.custom_element_state_ != .undefined_ && e.custom_element_state_ != .uncustomized {
		return
	}
	e.custom_element_definition_ = definition
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
	// Stub
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
	e.custom_element_definition_ = definition
	e.is_value = is_value_
}

pub fn (mut e Element) set_prefix(value ?string) {
	e.qualified_name.prefix_ = value
}

// https://dom.spec.whatwg.org/#locate-a-namespace-prefix
pub fn (e &Element) locate_a_namespace_prefix(namespace_ ?string) ?string {
	if e.namespace_uri() == namespace_ {
		if p := e.prefix() {
			return p
		}
	}
	if attrs := e.attributes_ {
		for i := 0; i < attrs.length(); i++ {
			if a := attrs.item(i) {
				if (a.prefix__ or { '' }) == 'xmlns' && a.value() == (namespace_ or { '' }) {
					return a.local_name_
				}
			}
		}
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

// --- Directionality ---

pub fn (e &Element) dir() ?Dir {
	return e.dir__
}

// https://html.spec.whatwg.org/multipage/dom.html#the-directionality
pub fn (e &Element) directionality() Directionality {
	if d := e.dir__ {
		match d {
			.ltr { return .ltr }
			.rtl { return .rtl }
			.auto_ {
				if result := e.auto_directionality() {
					return result
				}
			}
		}
	}
	return e.parent_directionality()
}

fn (e &Element) auto_directionality() ?Directionality {
	return none
}

pub fn (e &Element) contained_text_auto_directionality(can_exclude_root bool) ?Directionality {
	_ = can_exclude_root
	return none
}

// https://html.spec.whatwg.org/multipage/dom.html#parent-directionality
pub fn (e &Element) parent_directionality() Directionality {
	return .ltr
}

pub fn (e &Element) is_auto_directionality_form_associated_element() bool {
	return false
}

// --- Translation mode ---

pub fn (e &Element) translation_mode() TranslationMode {
	if e.has_attribute('translate') {
		val := e.get_attribute_value('translate')
		if val == 'no' {
			return .no_translate
		}
	}
	return .translate_enabled
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
	// Stub
}

pub fn (mut e Element) is_relevant_to_the_user() bool {
	return e.proximity_to_the_viewport_ == .close_to_the_viewport
}

// https://drafts.csswg.org/css-contain-2/#skips-its-contents
pub fn (e &Element) skips_its_contents() bool {
	return false
}

// --- Pseudo-class matching ---

pub fn (e &Element) matches_enabled_pseudo_class() bool {
	return !e.is_actually_disabled()
}

pub fn (e &Element) matches_disabled_pseudo_class() bool {
	return e.is_actually_disabled()
}

pub fn (e &Element) matches_checked_pseudo_class() bool {
	return false
}

pub fn (e &Element) matches_unchecked_pseudo_class() bool {
	return !e.matches_checked_pseudo_class()
}

pub fn (e &Element) matches_placeholder_shown_pseudo_class() bool {
	return false
}

pub fn (e &Element) matches_link_pseudo_class() bool {
	name := e.local_name()
	return name == 'a' || name == 'area'
}

pub fn (e &Element) matches_local_link_pseudo_class() bool {
	return false
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
}

pub fn (mut e Element) set_needs_style_update(v bool) {
	_ = v
}

pub fn (e &Element) needs_style_update() bool {
	return false
}

pub fn (e &Element) entire_subtree_needs_style_update() bool {
	return false
}

// --- List ordinals ---

pub fn (e &Element) number_of_owned_list_items() int {
	return 0
}

pub fn (e &Element) list_owner() ?&Element {
	return none
}

pub fn (mut e Element) ordinal_value() int {
	if v := e.ordinal_value_ {
		return v
	}
	return 0
}

// --- View transition ---

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

// --- Lang ---

// https://html.spec.whatwg.org/multipage/dom.html#the-lang-and-xml:lang-attributes
pub fn (e &Element) lang() ?string {
	if cached := e.lang_value_ {
		if cached.len == 0 {
			return none
		}
		return cached
	}
	if xml_lang := e.get_attribute_ns(namespace_xml_uri, 'lang') {
		return xml_lang
	}
	ns := e.namespace_uri() or { '' }
	if ns == namespace_html_uri || ns == namespace_svg_uri {
		if lang_attr := e.get_attribute('lang') {
			return lang_attr
		}
	}
	return none
}

pub fn (mut e Element) invalidate_lang_value() {
	if e.lang_value_ != none {
		e.lang_value_ = none
		e.set_needs_style_update(true)
	}
}

// --- is_connected ---

pub fn (e &Element) is_connected() bool {
	doc := e.document()
	return doc != unsafe { nil }
}

// --- attribute_changed ---

// https://dom.spec.whatwg.org/#concept-element-attributes-change-ext
pub fn (mut e Element) attribute_changed(local_name string, old_value ?string, value ?string, namespace_ ?string) {
	if namespace_ != none {
		return
	}

	value_or_empty := value or { '' }

	if local_name == 'id' {
		if value_or_empty.len == 0 {
			e.id_ = none
		} else {
			e.id_ = value_or_empty
		}
	} else if local_name == 'name' {
		if value_or_empty.len == 0 {
			e.name_ = none
		} else {
			e.name_ = value_or_empty
		}
	} else if local_name == 'class' {
		if value_or_empty.len == 0 {
			e.classes.clear()
		} else {
			e.classes = value_or_empty.split(' ').filter(it.len > 0)
		}
		if mut cl := e.class_list_ {
			cl.associated_attribute_changed(value_or_empty)
		}
	} else if local_name == 'style' {
		if s := e.inline_style_ {
			if s.is_updating() {
				return
			}
		}
		e.set_needs_style_update(true)
	} else if local_name == 'dir' {
		if value_or_empty.to_lower() == 'ltr' {
			e.dir__ = .ltr
		} else if value_or_empty.to_lower() == 'rtl' {
			e.dir__ = .rtl
		} else if value_or_empty.to_lower() == 'auto' {
			e.dir__ = .auto_
		} else {
			e.dir__ = none
		}
	} else if local_name == 'lang' {
		e.invalidate_lang_value()
	} else if local_name == 'part' {
		e.parts.clear()
		if value_or_empty.len > 0 {
			e.parts = value_or_empty.split(' ').filter(it.len > 0)
		}
		if mut pl := e.part_list_ {
			pl.associated_attribute_changed(value_or_empty)
		}
	} else if local_name == 'slot' {
		if value == old_value {
			return
		}
	}
}

fn (mut e Element) invalidate_style_after_attribute_change(attribute_name string, old_value ?string, new_value ?string) {
	_ = attribute_name
	_ = old_value
	_ = new_value
	e.set_needs_style_update(true)
}

// --- Hidden / Accessibility ---

pub fn (e &Element) is_hidden() bool {
	if e.has_attribute('hidden') {
		return true
	}
	val := e.get_attribute('aria-hidden') or { return false }
	return val == 'true'
}

pub fn (e &Element) has_hidden_ancestor() bool {
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
	doc := e.document()
	if doc == unsafe { nil } {
		return
	}
	if doc.allows_adding_render_blocking_elements() {
		doc.add_render_blocking_element(e)
	}
}

// https://html.spec.whatwg.org/multipage/dom.html#unblock-rendering
pub fn (mut e Element) unblock_rendering() {
	doc := e.document()
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
	if csm := e.computed_style_map_cache_ {
		return csm
	}
	new_csm := &StylePropertyMapReadOnly_{}
	e.computed_style_map_cache_ = new_csm
	return new_csm
}

// --- CSS random base value ---

pub fn (mut e Element) ensure_css_random_base_value(key string) f64 {
	if v := e.element_specific_css_random_base_value_cache[key] {
		return v
	}
	val := 0.5
	e.element_specific_css_random_base_value_cache[key] = val
	return val
}

// --- Focus indication ---

// https://drafts.csswg.org/selectors/#indicate-focus
pub fn (e &Element) should_indicate_focus() bool {
	return e.is_focused()
}

// https://html.spec.whatwg.org/multipage/interaction.html#tabindex-value
pub fn (e &Element) is_focusable() bool {
	tab_str := e.get_attribute_value('tabindex')
	return tab_str.len > 0
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
	// Stub
}

pub fn (mut e Element) removed_from(old_parent ?&Node) {
	_ = old_parent
	e.exit_fullscreen_on_element_removal()
}

pub fn (mut e Element) moved_from(old_parent ?&Node) {
	_ = old_parent
}

pub fn (mut e Element) children_changed() {
	// Stub
}

// --- element_to_inherit_style_from ---

pub fn (e &Element) element_to_inherit_style_from(pseudo_element ?int) ?&Element {
	if pseudo_element != none {
		return e
	}
	return none
}

// --- Serialize ---

pub fn (e &Element) serialize_children_as_json(mut sb strings.Builder) {
	_ = sb
}

// --- get_an_elements_target ---

pub fn (e &Element) get_an_elements_target(target ?string) string {
	if t := target {
		return t
	}
	return e.get_attribute('target') or { '' }
}

// --- Misc helpers ---

pub fn (e &Element) cannot_navigate() bool {
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

pub fn (e &Element) is_html_ol_ul_menu_element() bool {
	name := e.local_name()
	return name == 'ol' || name == 'ul' || name == 'menu'
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
	_ = child
}
