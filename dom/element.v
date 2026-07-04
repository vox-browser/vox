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
	return n.element != unsafe { nil } && n.element.is_html_element()
		&& n.element.document().is_html_document()
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
		if attribute.namespace_uri_ == normalized_namespace && attribute.local_name_ == local_name {
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

// Attr_ is named with underscore to avoid conflict with document.v's empty Attr stub
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

pub fn (a &Attr_) owner_element() ?&Element {
	return a.owner_element_
}

pub fn (mut a Attr_) set_owner_element(element ?&Element) {
	a.owner_element_ = element
}

pub fn (a &Attr_) handle_attribute_changes(element &Element, old_value ?string, new_value ?string) {
	mut mutable_element := unsafe { &Element(element) }
	mutable_element.attribute_changed(a.local_name_, old_value, new_value, a.namespace_uri_)
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

pub enum TokenizedFeatureNoOpener {
	no
	yes
}

pub type TaskID = int

pub enum TaskSource {
	dom_manipulation
}

pub struct PointerLockOptions {}

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

@[heap]
pub struct CustomElementDefinition {
pub mut:
	disable_shadow_     bool
	construction_stack  []&Element
	name_               string
	local_name_         string
	observed_attributes []string
}

pub fn (d &CustomElementDefinition) disable_shadow() bool {
	return d.disable_shadow_
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

pub struct CustomStateSet_ {}

@[heap]
pub struct CSSStyleProperties_ {
pub mut:
	is_updating_       bool
	associated_element ?&Element
}

pub fn (c &CSSStyleProperties_) is_updating() bool {
	return c.is_updating_
}

fn create_element_inline_style(element &Element) &CSSStyleProperties_ {
	return &CSSStyleProperties_{
		associated_element: element
	}
}

@[heap]
pub struct CSSComputedProperties_ {
pub mut:
	display_            CSSDisplay_           = CSSDisplay_{}
	overflow_x_         CSSOverflow_          = .visible
	overflow_y_         CSSOverflow_          = .visible
	content_visibility_ CSSContentVisibility_ = .visible
	opacity_            f32                   = 1.0
	visibility_         CSSVisibility_        = .visible
	font_weight_        f64                   = 400
	math_depth_         int
	math_style_         CSSMathStyle_ = .normal
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
	return none
}

pub fn (c &CSSComputedProperties_) has_attempted_match_against_pseudo_class(pseudo_class PseudoClass) bool {
	_ = c
	_ = pseudo_class
	// Stub for CSS::ComputedProperties selector matching bookkeeping.
	return false
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

@[heap]
pub struct CSSCascadedProperties_ {}

@[heap]
pub struct CSSCustomPropertyData_ {
pub mut:
	properties map[string]&CSSStyleValue_
}

pub fn (data &CSSCustomPropertyData_) get(name string) ?&CSSStyleValue_ {
	return data.properties[name] or { return none }
}

@[heap]
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
		relayout:            true
		rebuild_layout_tree: true
		repaint:             true
	}
}

@[heap]
pub struct PseudoElement_ {
pub mut:
	layout_node_     ?&LayoutNodeWithStyle_
	computed_props   ?&CSSComputedProperties_
	cascaded_props   ?&CSSCascadedProperties_
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

pub fn (n &LayoutNodeWithStyle_) previous_in_pre_order() ?&LayoutNodeWithStyle_ {
	_ = n
	// Stub for Layout::Node::previous_in_pre_order() until the layout tree is ported.
	return none
}

pub fn (n &LayoutNodeWithStyle_) previous_sibling() ?&LayoutNodeWithStyle_ {
	_ = n
	// Stub for Layout::Node::previous_sibling() until the layout tree is ported.
	return none
}

pub fn (n &LayoutNodeWithStyle_) dom_node() ?&Node {
	_ = n
	// Stub for Layout::Node::dom_node() until layout nodes retain DOM back-pointers.
	return none
}

pub fn (n &LayoutNodeWithStyle_) is_generated_for_pseudo_element() bool {
	_ = n
	// Stub for generated pseudo-element layout metadata.
	return false
}

pub fn (n &LayoutNodeWithStyle_) pseudo_element_generator() ?&Element {
	_ = n
	// Stub for Layout::NodeWithStyle::pseudo_element_generator().
	return none
}

pub fn (n &LayoutNodeWithStyle_) generated_for_pseudo_element() ?PseudoElement {
	_ = n
	// Stub for Layout::NodeWithStyle::generated_for_pseudo_element().
	return none
}

pub fn (n &LayoutNodeWithStyle_) is_before(other &LayoutNodeWithStyle_) bool {
	_ = n
	_ = other
	// Stub for Layout::Node::is_before().
	return false
}

pub struct ImmutableBitmap_ {
pub mut:
	width  int = 1
	height int = 1
}

pub fn (a &CSSAnimation_) cancel() {}

pub fn (a &CSSAnimation_) play() ! {}

pub fn (a &CSSAnimation_) pause() ! {}

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

fn css_pixel_rect_intersects_rect(rect CSSPixelRect_, other Rect) bool {
	return rect.x_ < other.x + other.width && rect.x_ + rect.width_ > other.x
		&& rect.y_ < other.y + other.height && rect.y_ + rect.height_ > other.y
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
	unsupported_element
	element_ready_check_failed
	no_transient_user_activation
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
	return prefix.len > 0 && !contains_any_code_point(prefix, [u32(9), 10, 12, 13, 32, 0, 47, 62])
}

// https://dom.spec.whatwg.org/#valid-attribute-local-name
pub fn is_valid_attribute_local_name(local_name string) bool {
	// A string is a valid attribute local name if its length is at least 1 and it does not contain ASCII whitespace, U+0000 NULL, U+002F (/), U+003D (=), or U+003E (>).
	return local_name.len > 0
		&& !contains_any_code_point(local_name, [u32(9), 10, 12, 13, 32, 0, 47, 61, 62])
}

// https://dom.spec.whatwg.org/#valid-element-local-name
pub fn is_valid_element_local_name(name string) bool {
	// 1. If name's length is 0, then return false.
	if name.len == 0 {
		return false
	}

	runes := name.runes()
	first_code_point := u32(runes[0])

	// 2. If name's 0th code point is an ASCII alpha, then:
	if is_ascii_alpha_code_point(first_code_point) {
		// 1. If name contains ASCII whitespace, U+0000 NULL, U+002F (/), or U+003E (>), then return false.
		if contains_any_code_point(name, [u32(9), 10, 12, 13, 32, 0, 47, 62]) {
			return false
		}

		// 2. Return true.
		return true
	}

	// 3. If name's 0th code point is not U+003A (:), U+005F (_), or in the range U+0080 to U+10FFFF, inclusive, then return false.
	if first_code_point != `:` && first_code_point != `_`
		&& (first_code_point < 0x0080 || first_code_point > 0x10ffff) {
		return false
	}

	// 4. If name's subsequent code points, if any, are not ASCII alphas, ASCII digits, U+002D (-), U+002E (.),
	//    U+003A (:), U+005F (_), or in the range U+0080 to U+10FFFF, inclusive, then return false.
	for i := 1; i < runes.len; i++ {
		code_point := u32(runes[i])
		if !is_ascii_alpha_code_point(code_point) && !is_ascii_digit_code_point(code_point)
			&& code_point != `-` && code_point != `.` && code_point != `:` && code_point != `_`
			&& (code_point < 0x0080 || code_point > 0x10ffff) {
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
	if namespace_matches(normalized_namespace, namespace_xmlns_uri) && !(qualified_name == 'xmlns'
		|| prefix_is_xmlns) {
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
pub mut:
	qualified_name                  QualifiedName
	html_uppercased_qualified_name_ ?string

	attributes_          ?&NamedNodeMap
	inline_style_        ?&CSSStyleProperties_
	attribute_style_map_ ?&StylePropertyMap_
	class_list_          ?&DOMTokenList
	shadow_root_         ?&ShadowRoot
	part_list_           ?&DOMTokenList

	cascaded_properties_  ?&CSSCascadedProperties_
	computed_properties_  ?&CSSComputedProperties_
	custom_property_data_ ?&CSSCustomPropertyData_

	pseudo_element_data map[int]&PseudoElement_

	use_pseudo_element ?int

	classes []string
	parts   []string
	dir__   ?Dir

	id_   ?string
	name_ ?string

	custom_element_reaction_queue []CustomElementReaction
	custom_element_definition_    ?&CustomElementDefinition
	is_value                      ?string
	custom_state_set_             ?&CustomStateSet_

	registered_intersection_observers []IntersectionObserverRegistration_
	computed_style_map_cache_         ?&StylePropertyMapReadOnly_

	scroll_offset_ CSSPixelPoint_

	css_defined_animations_         map[string]&CSSAnimation_
	has_css_defined_animations_flag bool

	// Boolean flags
	is_being_activated_                                                             bool
	in_top_layer                                                                    bool
	rendered_in_top_layer                                                           bool
	style_uses_attr_css_function                                                    bool
	style_uses_var_css_function                                                     bool
	style_uses_tree_counting_function                                               bool
	style_uses_if_css_function                                                      bool
	style_uses_inherit_css_function                                                 bool
	child_style_uses_tree_counting_function                                         bool
	affected_by_has_pseudo_class_in_subject_position                                bool
	affected_by_has_pseudo_class_in_non_subject_position                            bool
	affected_by_direct_sibling_combinator                                           bool
	affected_by_indirect_sibling_combinator                                         bool
	affected_by_first_child_pseudo_class                                            bool
	affected_by_last_child_pseudo_class                                             bool
	affected_by_forward_positional_pseudo_class                                     bool
	affected_by_backward_positional_pseudo_class                                    bool
	affected_by_has_pseudo_class_with_relative_selector_that_has_sibling_combinator bool
	fullscreen_flag                                                                 bool

	sibling_invalidation_distance int

	counters_set_  ?&CSSCountersSet_
	ordinal_value_ ?int
	lang_value_    ?string

	had_duplicate_attribute_during_tokenization bool
	custom_element_state_                       CustomElementState     = .undefined_
	proximity_to_the_viewport_                  ProximityToTheViewport = .not_determined
	captured_in_a_view_transition               bool
	is_contained_in_list_subtree                bool

	element_specific_css_random_base_value_cache map[string]f64

	doc_ ?&Document
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
		ParentNode:     ParentNode{
			Node: Node{
				node_type:  .element_node
				document_:  doc
				unique_id_: UniqueNodeID(0)
			}
		}
		qualified_name: qname
		doc_:           doc
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
			name_:          qualified_name.as_string()
			value_:         value
			local_name_:    local_name
			prefix__:       prefix
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

	e.set_attribute_value(actual_name, value)
}

// https://dom.spec.whatwg.org/#dom-element-setattributens
pub fn (mut e Element) set_attribute_ns_for_bindings(namespace_ ?string, qualified_name string, value string) ! {
	extracted := validate_and_extract(namespace_, qualified_name, .attribute)!
	e.set_attribute_value_ns(extracted.local_name, value, extracted.prefix_, extracted.namespace_)
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
		name_:       name
		value_:      value
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
	if pl := e.part_list_ {
		return pl
	}
	new_pl := DOMTokenList.create(&e, 'part')
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
	ns := e.namespace_uri() or { return error('NotSupportedError: Element namespace is not HTML') }
	if ns != namespace_html_uri {
		return error('NotSupportedError: Element namespace is not HTML')
	}
	if !is_valid_shadow_host_name(e.local_name()) {
		return error('NotSupportedError: Element local name is not a valid shadow host name')
	}
	if is_valid_custom_element_name(e.local_name()) || e.is_value != none {
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
	shadow := assign_unique_node_id(&ShadowRoot{
		DocumentFragment: DocumentFragment{
			ParentNode: ParentNode{
				Node: Node{
					node_type:  .document_fragment_node
					document_:  e.document()
					unique_id_: UniqueNodeID(0)
				}
			}
			host_:      e
		}
		mode:             mode
		clonable_:        clonable
		serializable_:    serializable
		delegates_focus_: delegates_focus
		slot_assignment_: slot_assignment
	})
	e.shadow_root_ = shadow
}

// https://dom.spec.whatwg.org/#dom-element-attachshadow
pub fn (mut e Element) attach_shadow(init ShadowRootInit) !&ShadowRoot {
	e.attach_a_shadow_root(init.mode, init.clonable, init.serializable, init.delegates_focus,
		init.slot_assignment)!
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
	if current_shadow_root == new_shadow_root {
		return
	}
	if current_shadow_root != unsafe { nil } {
		mut current_fragment := unsafe { &DocumentFragment(current_shadow_root) }
		current_fragment.set_host(none)
	}
	e.shadow_root_ = sr
	if new_shadow_root != unsafe { nil } {
		mut new_fragment := unsafe { &DocumentFragment(new_shadow_root) }
		new_fragment.set_host(&e)
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
	_ = style
	_ = element
	if display.is_none() {
		return none
	}
	// Stub for Layout::{Box,ListItemBox,BlockContainer,InlineNode} allocation.
	return &LayoutNodeWithStyle_{}
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
	if e.attribute_style_map_ != none {
		e.attribute_style_map_ = none
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
	if m := e.attribute_style_map_ {
		return m
	}
	new_map := create_style_property_map_for_bindings(e.style_for_bindings())
	e.attribute_style_map_ = new_map
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
	if e.cascaded_properties_ == none || e.computed_properties_ == none
		|| e.el_unsafe_layout_node() == none {
		return RequiredInvalidationAfterStyleChange{}
	}
	return RequiredInvalidationAfterStyleChange{}
}

// --- Inner/Outer HTML ---

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-element-innerhtml
pub fn (mut e Element) set_inner_html(value string) ! {
	// Trusted Types compliance is not translated yet; treat value as the compliant string.
	mut node := unsafe { &Node(&e) }
	node.unsafely_set_html(&e, value)!
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
	// Trusted Types compliance is not translated yet; treat value as the compliant string.
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

	fragment := parse_fragment_fallback(context_element, value)!
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
	mut node := unsafe { &Node(&e) }
	node.unsafely_set_html(&e, html)!
}

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-element-gethtml
pub fn (e &Element) get_html(options GetHTMLOptions) !string {
	_ = options
	return e.as_node().serialize_fragment(.yes, .inner)
}

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#the-insertadjacenthtml()-method
pub fn (mut e Element) insert_adjacent_html(position string, text string) ! {
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
			context_element = create_element(e.document(), 'body', namespace_html_, none, none,
				false)!
		}
	}
	element_context := context_element or { return }
	fragment := parse_fragment_fallback(element_context, text)!
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

fn html_parser_parse_html_fragment(context_element &Element, markup string, allow_declarative_shadow_roots AllowDeclarativeShadowRoots) ![]&Node {
	_ = allow_declarative_shadow_roots
	// Stub for HTML::HTMLParser::parse_html_fragment until the HTML parser is ported.
	if markup.len == 0 {
		return []&Node{}
	}
	return [new_text_node(context_element.document(), markup).as_node()]
}

fn xml_fragment_parser_parse_xml_fragment(context_element &Element, markup string, allow_declarative_shadow_roots AllowDeclarativeShadowRoots) ![]&Node {
	_ = allow_declarative_shadow_roots
	// Stub for XMLFragmentParser::parse_xml_fragment until the XML parser is ported.
	if markup.len == 0 {
		return []&Node{}
	}
	return [new_text_node(context_element.document(), markup).as_node()]
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
	// 1. Let algorithm be the HTML fragment parsing algorithm.
	// 2. If context's node document is an XML document, then set algorithm to the XML fragment parsing algorithm.
	new_children := if e.document().is_xml_document() {
		xml_fragment_parser_parse_xml_fragment(e, markup, .no)!
	} else {
		html_parser_parse_html_fragment(e, markup, .no)!
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
	return value.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
}

fn html_escape_attribute(value string) string {
	return html_escape_text(value).replace('"', '&quot;')
}

fn serialize_element_start_tag(mut builder strings.Builder, element &Element) {
	builder.write_string('<')
	builder.write_string(element.qualified_name_str())
	if attrs := element.attributes_ {
		for attr in attrs.attrs {
			builder.write_string(' ')
			builder.write_string(attr.name())
			builder.write_string('="')
			builder.write_string(html_escape_attribute(attr.value()))
			builder.write_string('"')
		}
	}
	builder.write_string('>')
}

fn serialize_node_fallback(node &Node, mode FragmentSerializationMode) string {
	if character_data := node.character_data() {
		return html_escape_text(character_data.data())
	}
	if attr := node.as_attr() {
		return html_escape_attribute(attr.value())
	}
	if document_type := node.as_document_type() {
		return '<!DOCTYPE ${document_type.name()}>'
	}
	if element := node.as_element() {
		mut builder := strings.new_builder(0)
		if mode == .outer {
			serialize_element_start_tag(mut builder, element)
		}
		for child in node.children {
			builder.write_string(serialize_node_fallback(child, .outer))
		}
		if mode == .outer && !element.serializes_as_void() {
			builder.write_string('</')
			builder.write_string(element.qualified_name_str())
			builder.write_string('>')
		}
		return builder.str()
	}
	mut builder := strings.new_builder(0)
	for child in node.children {
		builder.write_string(serialize_node_fallback(child, .outer))
	}
	return builder.str()
}

fn html_parser_serialize_html_fragment(node &Node, serializable_shadow_roots SerializableShadowRoots, shadow_roots []&ShadowRoot, fragment_serialization_mode FragmentSerializationMode) string {
	_ = serializable_shadow_roots
	_ = shadow_roots
	// Stub for HTML::HTMLParser::serialize_html_fragment until the HTML serializer is ported.
	return serialize_node_fallback(node, fragment_serialization_mode)
}

fn html_serialize_node_to_xml_string(node &Node, require_well_formed RequireWellFormed) !string {
	_ = require_well_formed
	// Stub for HTML::serialize_node_to_xml_string until the XML serializer is ported.
	return serialize_node_fallback(node, .outer)
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
	node.invalidate_style(.element_set_active)
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
	return doc.document_element() or { return false } == e
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

// https://drafts.csswg.org/cssom-view/#dom-element-getboundingclientrect
pub fn (e &Element) get_bounding_client_rect() Rect {
	// 1. Let list be the result of invoking getClientRects() on element.
	list := e.get_client_rects()

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
			x:      first.x_
			y:      first.y_
			width:  first.width_
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
		x:      left
		y:      top
		width:  right - left
		height: bottom - top
	}
}

pub fn (e &Element) get_client_rects() []CSSPixelRect_ {
	return []
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
	if treat_overflow_clip_on_body_parent_as_overflow_hidden == .no
		&& (parent_properties.overflow_x() == .clip || parent_properties.overflow_y() == .clip) {
		return false
	}

	// - body's computed value of the overflow-x or overflow-y properties is neither visible nor clip.
	computed_properties := e.el_computed_properties() or { return false }
	if computed_properties.overflow_x() in [.visible, .clip]
		|| computed_properties.overflow_y() in [.visible, .clip] {
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
	return overflow_value_makes_box_a_scroll_container(computed_properties.overflow_x())
		|| overflow_value_makes_box_a_scroll_container(computed_properties.overflow_y())
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

		// 11. Scroll the element to x,scrollTop, with the scroll behavior being "auto".
		// FIXME: Implement this in terms of calling "scroll the element".
		mut offset := pb.scroll_offset()
		offset.set_x(x)
		pb.set_scroll_offset(offset)
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

		// 11. Scroll the element to scrollLeft,y, with the scroll behavior being "auto".
		// FIXME: Implement this in terms of calling "scroll the element".
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
	// This's namespace is the HTML namespace or this is an SVG svg element.
	// MathML math element support is not represented in the current V DOM type set.
	if !(e.namespace_uri() or { '' } == namespace_html_uri || e.is_svg_svg_element()) {
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

	// Fullscreen support is represented by Document.is_allowed_to_use_feature().
	// Transient user activation is owned by Window/HTML agent state, which is not
	// translated in this DOM-only V port. WebDriver and bindings share the same
	// successful path until that state exists.
	_ = requester
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

fn (mut e Element) exit_fullscreen_on_element_removal() {
	// 1. Let document be removedNode's node document.
	mut document := unsafe { &Document(e.document()) }

	// 2. Let nodes be removedNode's shadow-including inclusive descendants that
	//    have their fullscreen flag set, in shadow-including tree order.
	mut fullscreen_elements := []&Element{}
	fullscreen_elements_ptr := &fullscreen_elements
	e.as_node().for_each_shadow_including_inclusive_descendant(fn [fullscreen_elements_ptr] (node &Node) TraversalDecision {
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
			if fullscreen_element == element {
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
	for ancestor := e.as_node().parent(); ancestor != none; {
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
	for fieldset_ancestor := e.first_ancestor_fieldset_element(); fieldset_ancestor != none; {
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
	return parent_element.is_html_element_with_local_name('optgroup')
		&& parent_element.has_attribute('disabled')
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

pub fn (mut e Element) register_intersection_observer(registration IntersectionObserverRegistration_) {
	e.registered_intersection_observers << registration
}

pub fn (mut e Element) unregister_intersection_observer(observer voidptr) {
	e.registered_intersection_observers =
		e.registered_intersection_observers.filter(it.observer != observer)
}

// Mirrors the C++ Element::get_intersection_observer_registration accessor used
// from Document during intersection observer notification dispatch.
pub fn (mut e Element) get_intersection_observer_registration(observer voidptr) ?&IntersectionObserverRegistration_ {
	for i := 0; i < e.registered_intersection_observers.len; i++ {
		if e.registered_intersection_observers[i].observer == observer {
			return unsafe { &e.registered_intersection_observers[i] }
		}
	}
	return none
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
// In V the queue is always represented as an in-place slice (no lazy
// allocation needed), so this simply returns it. V slices share their backing
// array, so callers may iterate the result; mutation should still go through
// the dedicated enqueue helpers.
pub fn (e &Element) ensure_custom_element_reaction_queue() []CustomElementReaction {
	return e.custom_element_reaction_queue
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
	definition := e.document().lookup_custom_element_definition(e.namespace_uri(), e.local_name(),
		e.is_value) or { return }
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
	if is_html_element_with_local_name(e, 'input')
		&& to_ascii_lowercase(e.get_attribute_value('type')) == 'tel' {
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
	return is_html_element_with_local_name(element, 'script')
		|| is_html_element_with_local_name(element, 'style')
		|| is_html_element_with_local_name(element, 'textarea') || element.dir() != none
}

fn descendant_is_filtered_for_auto_directionality(descendant &Node, root &Element, can_exclude_root bool) bool {
	if element := descendant.as_element() {
		if element_is_filtered_for_auto_directionality(element) {
			return true
		}
	}
	for ancestor := descendant.parent(); ancestor != none; {
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
			if direction := contained_text_auto_directionality_for_subtree(child, root,
				can_exclude_root)
			{
				return direction
			}
			continue
		}

		if child.is_text() {
			if direction := unsafe { &Text(child) }.directionality() {
				return direction
			}
		}
		if direction := contained_text_auto_directionality_for_subtree(child, root,
			can_exclude_root)
		{
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
		x:      viewport_rect.x - viewport_rect.width
		y:      viewport_rect.y - viewport_rect.height
		width:  viewport_rect.width * 3
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
	return e.proximity_to_the_viewport_ == .close_to_the_viewport
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
	return e.is_html_element()
		&& e.local_name() in ['button', 'input', 'select', 'textarea', 'optgroup', 'option', 'fieldset']
		&& !e.is_actually_disabled()
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
	return ((e.is_html_element() && (name == 'a' || name == 'area'))
		|| (e.is_svg_element() && name == 'a')) && e.has_attribute('href')
}

pub fn (e &Element) matches_local_link_pseudo_class() bool {
	return false
}

pub fn (e &Element) affected_by_pseudo_class(pseudo_class PseudoClass) bool {
	if props := e.computed_properties_ {
		if props.has_attempted_match_against_pseudo_class(pseudo_class) {
			return true
		}
	}
	for _, pseudo_element in e.pseudo_element_data {
		props := pseudo_element.computed_properties() or { continue }
		if props.has_attempted_match_against_pseudo_class(pseudo_class) {
			return true
		}
	}
	return false
}

pub fn (e &Element) includes_properties_from_invalidation_set(set StyleInvalidationSet) bool {
	for property in set.properties {
		name := property.name
		if name.len == 0 {
			continue
		}
		if e.id() or { '' } == name || e.local_name() == name || e.has_class(name)
			|| e.has_attribute(name) {
			return true
		}
	}
	return false
}

// --- Invalidation flags ---

pub fn (e &Element) affected_by_forward_structural_changes() bool {
	return e.affected_by_direct_sibling_combinator || e.affected_by_indirect_sibling_combinator
		|| e.affected_by_first_child_pseudo_class || e.affected_by_forward_positional_pseudo_class
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

			if element.is_html_ol_ul_menu_element() {
				// Skip list nodes and their descendents. They have their own, unrelated ordinals.
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
			// NB: unsafe_paintable_box() because this runs during list ordinal computation as part of
			//     style recalculation, when layout is inherently stale.
			if inclusive_ancestor.unsafe_paintable_box() != none {
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
			if item == skipped {
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
		return e.number_of_owned_list_items()
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
pub fn (e &Element) capture_the_image() &ImmutableBitmap_ {
	_ = e
	// FIXME: Actually implement this. Matches the C++ placeholder with a 1x1 bitmap.
	return &ImmutableBitmap_{}
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
	if !e.has_css_defined_animations_flag {
		return
	}

	// OPTIMIZATION: We don't care about animations in disconnected subtrees.
	if !e.is_connected() {
		return
	}

	// Setting display:none terminates running CSS animations. Restart/pause state
	// tracking lives in CSSAnimation and is not ported, so this is a narrow stub.
	has_display_none_inclusive_ancestor := e.as_node().has_inclusive_ancestor_with_display_none()
	for _, animation in e.css_defined_animations_ {
		if has_display_none_inclusive_ancestor {
			animation.cancel()
		} else {
			animation.play() or {}
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

pub fn (e &Element) request_pointer_lock(options ?PointerLockOptions) &Promise {
	_ = e
	_ = options
	// Stub for Pointer Lock; C++ returns a rejected NotSupportedError promise.
	return &Promise{}
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

// --- is_connected ---

pub fn (e &Element) is_connected() bool {
	return e.as_node().is_connected()
}

// --- attribute_changed ---

// https://dom.spec.whatwg.org/#concept-element-attributes-change-ext
pub fn (mut e Element) attribute_changed(local_name string, old_value ?string, value ?string, namespace_ ?string) {
	if namespace_ != none {
		return
	}

	value_or_empty := value or { '' }

	if local_name == 'slot' {
		// 1. If value is oldValue, then return.
		if value == old_value {
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

		// 4-5. The slottable name is reflected from the slot attribute by slottable_name().
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
	} else if local_name == 'lang' {
		e.as_node().for_each_in_inclusive_subtree(fn (node &Node) TraversalDecision {
			if element := node.as_element() {
				mut mutable_element := unsafe { &Element(element) }
				mutable_element.invalidate_lang_value()
			}
			return .@continue
		})
	} else if local_name == 'part' {
		e.parts.clear()
		if value_or_empty.len > 0 {
			e.parts = value_or_empty.split(' ').filter(it.len > 0)
		}
		if mut pl := e.part_list_ {
			pl.associated_attribute_changed(value_or_empty)
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
	for ancestor := e.as_node().parent_or_shadow_host(); ancestor != none; {
		current := ancestor or { break }
		if element := current.as_element() {
			if element.is_hidden() {
				return true
			}
		}
		ancestor = current.parent_or_shadow_host()
	}
	return false
}

// Returns true when this element's id is mentioned by another element's
// aria-labelledby attribute somewhere in the same root subtree.
//
// The C++ implementation consults Web::ARIA::AriaData, which collects every
// IDREF-list ARIA attribute. The V port currently lacks AriaData, so we scan
// the root subtree for HTML elements whose aria-labelledby tokens contain our
// id. This covers the dominant accessibility use case.
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
	for ancestor := e.as_node().parent_or_shadow_host(); ancestor != none; {
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
	if csm := e.computed_style_map_cache_ {
		return csm
	}
	new_csm := &StylePropertyMapReadOnly_{}
	e.computed_style_map_cache_ = new_csm
	return new_csm
}

// --- CSS random base value ---

pub fn (mut e Element) ensure_css_random_base_value(key string) f64 {
	if key in e.element_specific_css_random_base_value_cache {
		return e.element_specific_css_random_base_value_cache[key]
	}
	val := rand.f64()
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
	return parse_html_integer(e.get_attribute_value('tabindex')) != none
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
	}

	// play_or_cancel_animations_after_display_property_change() depends on the animation/style subsystems.
}

pub fn (mut e Element) removed_from(old_parent ?&Node, old_root &Node) {
	_ = old_parent
	mut node := unsafe { &Node(e.as_node()) }
	node.in_editable_subtree_ = false
	node.layout_node_ = unsafe { nil }
	node.paintable_ = unsafe { nil }

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
	}

	// play_or_cancel_animations_after_display_property_change() depends on the animation/style subsystems.
	e.exit_fullscreen_on_element_removal()
}

pub fn (mut e Element) moved_from(old_parent ?&Node) {
	_ = old_parent
	mut node := unsafe { &Node(e.as_node()) }
	node.recompute_editable_subtree_flag()
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

pub fn (e &Element) serialize_children_as_json(mut sb strings.Builder) {
	_ = sb
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
	_ = user_involvement
	// 1. If subject cannot navigate, then return.
	if e.cannot_navigate() {
		return
	}

	// 2. Let targetAttributeValue be the empty string.
	mut target_attribute_value := ''

	// 3. If subject is an a or area element, then set targetAttributeValue to the
	// result of getting an element's target given subject.
	if is_html_element_with_local_name(e, 'a')
		|| is_html_element_with_local_name(e, 'area')
		|| (e.is_svg_element() && e.local_name() == 'a') {
		target_attribute_value = e.get_an_elements_target(none)
	}

	// 4. Let urlRecord be the result of encoding-parsing a URL given subject's href
	// attribute value, relative to subject's node document.
	url_record := e.document().encoding_parse_url(e.get_attribute_value('href')) or { return }

	// 5. If urlRecord is failure, then return. [Handled above.]
	// 6. Let noopener be the result of getting an element's noopener with subject, urlRecord, and targetAttributeValue.
	_ = e.get_an_elements_noopener(url_record, target_attribute_value)

	// 7-13. Choosing a navigable and performing navigation are outside the DOM port.
	// Preserve URL suffix construction to keep the parsed URL path exercised.
	mut url_string := url_record.serialize()
	if suffix := hyperlink_suffix {
		url_string += suffix
	}
	_ = url_string
}

// --- Misc helpers ---

pub fn (e &Element) cannot_navigate() bool {
	doc := e.document()
	if doc == unsafe { nil } || !doc.is_fully_active() {
		return true
	}
	is_anchor := is_html_element_with_local_name(e, 'a')
		|| (e.is_svg_element() && e.local_name() == 'a')
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
