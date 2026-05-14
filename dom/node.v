// Copyright (c) 2018-2024, Andreas Kling <andreas@ladybird.org>
// Copyright (c) 2021-2022, Linus Groh <linusg@serenityos.org>
// Copyright (c) 2021, Luke Wilde <lukew@serenityos.org>
// Copyright (c) 2024-2025, Jelle Raaijmakers <jelle@ladybird.org>
// Copyright (c) 2025, Shannon Booth <shannon@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause
//
// Translated from Libraries/LibWeb/DOM/Node.cpp

module dom

import strings

pub type UniqueNodeID = i64

pub fn (id UniqueNodeID) value() i64 {
	return i64(id)
}

pub enum NameOrDescription {
	name
	description
}

pub struct GetRootNodeOptions {
pub mut:
	composed bool
}

pub enum IsDescendant {
	no
	yes
}

pub enum ShouldComputeRole {
	no
	yes
}

pub enum SetNeedsLayoutReason {
	character_data_replace_data
	finalize_a_cross_document_navigation
	generated_content_image_finished_loading
	html_canvas_element_width_or_height_change
	html_image_element_react_to_changes_in_the_environment
	html_image_element_update_the_image_data
	html_video_element_set_video_track
	keyframe_effect
	layout_tree_update
	navigable_set_viewport_size
	svg_graphics_element_transform_change
	svg_image_element_fetch_the_document
	svg_image_filter_fetch
	svg_view_box_change
	style_change
}

pub fn set_needs_layout_reason_to_string(reason SetNeedsLayoutReason) string {
	return match reason {
		.character_data_replace_data { 'CharacterDataReplaceData' }
		.finalize_a_cross_document_navigation { 'FinalizeACrossDocumentNavigation' }
		.generated_content_image_finished_loading { 'GeneratedContentImageFinishedLoading' }
		.html_canvas_element_width_or_height_change { 'HTMLCanvasElementWidthOrHeightChange' }
		.html_image_element_react_to_changes_in_the_environment { 'HTMLImageElementReactToChangesInTheEnvironment' }
		.html_image_element_update_the_image_data { 'HTMLImageElementUpdateTheImageData' }
		.html_video_element_set_video_track { 'HTMLVideoElementSetVideoTrack' }
		.keyframe_effect { 'KeyframeEffect' }
		.layout_tree_update { 'LayoutTreeUpdate' }
		.navigable_set_viewport_size { 'NavigableSetViewportSize' }
		.svg_graphics_element_transform_change { 'SVGGraphicsElementTransformChange' }
		.svg_image_element_fetch_the_document { 'SVGImageElementFetchTheDocument' }
		.svg_image_filter_fetch { 'SVGImageFilterFetch' }
		.svg_view_box_change { 'SVGViewBoxChange' }
		.style_change { 'StyleChange' }
	}
}

pub enum SetNeedsLayoutTreeUpdateReason {
	element_set_inner_html
	element_set_shadow_root
	details_element_opened_or_closed
	html_input_element_src_attribute
	html_ol_list_element_ordinal_values
	html_object_element_update_layout_and_child_objects
	keyframe_effect
	node_insert_before
	node_insert_before_with_display_contents
	node_remove
	node_set_text_content
	none
	style_change
}

pub fn set_needs_layout_tree_update_reason_to_string(reason SetNeedsLayoutTreeUpdateReason) string {
	return match reason {
		.element_set_inner_html { 'ElementSetInnerHTML' }
		.element_set_shadow_root { 'ElementSetShadowRoot' }
		.details_element_opened_or_closed { 'DetailsElementOpenedOrClosed' }
		.html_input_element_src_attribute { 'HTMLInputElementSrcAttribute' }
		.html_ol_list_element_ordinal_values { 'HTMLOListElementOrdinalValues' }
		.html_object_element_update_layout_and_child_objects { 'HTMLObjectElementUpdateLayoutAndChildObjects' }
		.keyframe_effect { 'KeyframeEffect' }
		.node_insert_before { 'NodeInsertBefore' }
		.node_insert_before_with_display_contents { 'NodeInsertBeforeWithDisplayContents' }
		.node_remove { 'NodeRemove' }
		.node_set_text_content { 'NodeSetTextContent' }
		.none { 'None' }
		.style_change { 'StyleChange' }
	}
}

pub enum StyleInvalidationReason {
	base_url_changed
	css_font_loaded
	html_iframe_element_geometry_change
	html_object_element_update_layout_and_child_objects
	navigable_set_viewport_size
	node_insert_before
	node_remove
	node_set_text_content
	settings_change
	style_change
}

pub fn style_invalidation_reason_to_string(reason StyleInvalidationReason) string {
	return match reason {
		.base_url_changed { 'BaseURLChanged' }
		.css_font_loaded { 'CSSFontLoaded' }
		.html_iframe_element_geometry_change { 'HTMLIFrameElementGeometryChange' }
		.html_object_element_update_layout_and_child_objects { 'HTMLObjectElementUpdateLayoutAndChildObjects' }
		.navigable_set_viewport_size { 'NavigableSetViewportSize' }
		.node_insert_before { 'NodeInsertBefore' }
		.node_remove { 'NodeRemove' }
		.node_set_text_content { 'NodeSetTextContent' }
		.settings_change { 'SettingsChange' }
		.style_change { 'StyleChange' }
	}
}

pub struct StyleInvalidationOptions {
pub mut:
	invalidate_self bool = true
}

pub enum FragmentSerializationMode {
	inner
	outer
}

pub enum RequireWellFormed {
	no
	yes
}

pub enum InvalidateDisplayList {
	no
	yes
}

pub enum MutationType {
	attributes
	character_data
	child_list
}

pub const document_position_equal = u16(0)
pub const document_position_disconnected = u16(1)
pub const document_position_preceding = u16(2)
pub const document_position_following = u16(4)
pub const document_position_contains = u16(8)
pub const document_position_contained_by = u16(16)
pub const document_position_implementation_specific = u16(32)

@[heap]
pub struct Paintable {
pub mut:
	needs_repaint bool
	is_box        bool
}

pub fn (p &Paintable) is_paintable_box() bool {
	return p.is_box
}

pub fn (mut p Paintable) set_needs_repaint(should_invalidate_display_list InvalidateDisplayList) {
	_ = should_invalidate_display_list
	p.needs_repaint = true
}

@[heap]
pub struct PaintableBox {
	Paintable
pub mut:
	visible          bool = true
	scrollable       bool
	stacking_context bool
}

pub fn (p &PaintableBox) could_be_scrolled_by_wheel_event() bool {
	return p.scrollable
}

pub fn (p &PaintableBox) is_visible() bool {
	return p.visible
}

pub fn (p &PaintableBox) has_stacking_context() bool {
	return p.stacking_context
}

pub struct InvalidationProperty {
pub mut:
	name string
}

@[heap]
pub struct MutationObserver {
pub mut:
	callback_    ?&CallbackType
	node_list_   []&Node
	record_queue []&MutationRecord
}

pub fn (mut mo MutationObserver) enqueue_record(record &MutationRecord) {
	mo.record_queue << record
}

pub struct MutationObserverOptions {
pub mut:
	subtree                  bool
	attributes               ?bool
	attribute_filter         ?[]string
	attribute_old_value      ?bool
	character_data           ?bool
	character_data_old_value ?bool
	child_list               bool
}

@[heap]
pub struct RegisteredObserver {
pub mut:
	observer_ &MutationObserver = unsafe { nil }
	options_  MutationObserverOptions
}

pub fn (ro &RegisteredObserver) observer() &MutationObserver {
	return ro.observer_
}

pub fn (ro &RegisteredObserver) options() MutationObserverOptions {
	return ro.options_
}

@[heap]
pub struct TransientRegisteredObserver {
	RegisteredObserver
pub mut:
	source_ &RegisteredObserver = unsafe { nil }
}

@[heap]
pub struct MutationRecord {
pub mut:
	type_               MutationType
	target              &Node = unsafe { nil }
	added_nodes         []&Node
	removed_nodes       []&Node
	previous_sibling    &Node = unsafe { nil }
	next_sibling        &Node = unsafe { nil }
	attribute_name      ?string
	attribute_namespace ?string
	old_value           ?string
}

pub struct ChildrenChangedMetadata {
pub mut:
	type_ ChildrenChangedType
	node  &Node = unsafe { nil }
}

pub enum ChildrenChangedType {
	inserted
	removal
	mutation
}

@[heap]
pub struct HTMLAnchorElement {
	HTMLElement
}

@[heap]
pub struct HTMLSlotElement {
	HTMLElement
pub mut:
	assigned_nodes_          []&Node
	manually_assigned_nodes_ []&Node
}

pub fn (s &HTMLSlotElement) assigned_nodes_internal() []&Node {
	return s.assigned_nodes_
}

pub fn (s &HTMLSlotElement) assigned_nodes() []&Node {
	return s.assigned_nodes_
}

pub struct AssignedNodesOptions {
pub mut:
	flatten bool
}

@[heap]
pub struct HTMLImageElement {
	HTMLElement
}

@[heap]
pub struct HTMLInputElement {
	HTMLElement
}

@[heap]
pub struct HTMLSelectElement {
	HTMLElement
}

@[heap]
pub struct HTMLTableElement {
	HTMLElement
}

@[heap]
pub struct HTMLFieldSetElement {
	HTMLElement
}

@[heap]
pub struct HTMLLegendElement {
	HTMLElement
}

fn allocate_unique_id(node &Node) UniqueNodeID {
	_ = node
	// The C++ implementation keeps a process-wide directory. The current V
	// port does not have GC lifecycle hooks yet, so this is a stable stub.
	return UniqueNodeID(0)
}

fn deallocate_unique_id(node_id UniqueNodeID) {
	_ = node_id
}

pub fn Node.from_unique_id(unique_id UniqueNodeID) ?&Node {
	_ = unique_id
	return none
}

pub fn Node.new_with_realm(realm voidptr, document &Document, node_type NodeType) &Node {
	_ = realm
	mut node := &Node{
		node_type: node_type
		document_: document
	}
	node.unique_id_ = allocate_unique_id(node)
	return node
}

pub fn Node.new(document &Document, node_type NodeType) &Node {
	return Node.new_with_realm(unsafe { nil }, document, node_type)
}

pub fn (mut n Node) finalize() {
	deallocate_unique_id(n.unique_id_)
}

pub fn (mut n Node) visit_edges(mut visitor CellVisitor) {
	visitor.visit(n.document_)
	visitor.visit(n.child_nodes_)
	visitor.visit(n.layout_node_)
	visitor.visit(n.paintable_)
	for child in n.children {
		visitor.visit(child)
	}
	for observer in n.registered_observer_list_ {
		visitor.visit(observer)
	}
	if assigned_slot := n.assigned_slot_ {
		visitor.visit(assigned_slot)
	}
	if manual_slot_assignment := n.manual_slot_assignment_ {
		visitor.visit(manual_slot_assignment)
	}
}

pub fn (n &Node) type_() NodeType {
	return n.node_type
}

pub fn (n &Node) is_element() bool {
	return n.node_type == .element_node
}

pub fn (n &Node) is_text() bool {
	return n.node_type == .text_node || n.node_type == .cdata_section_node
}

pub fn (n &Node) is_exclusive_text() bool {
	return n.node_type == .text_node
}

pub fn (n &Node) is_document() bool {
	return n.node_type == .document_node
}

pub fn (n &Node) is_document_type() bool {
	return n.node_type == .document_type_node
}

pub fn (n &Node) is_comment() bool {
	return n.node_type == .comment_node
}

pub fn (n &Node) is_character_data() bool {
	return n.node_type == .text_node || n.node_type == .comment_node
		|| n.node_type == .cdata_section_node || n.node_type == .processing_instruction_node
}

pub fn (n &Node) is_document_fragment() bool {
	return n.node_type == .document_fragment_node
}

pub fn (n &Node) is_parent_node() bool {
	return n.is_element() || n.is_document() || n.is_document_fragment()
}

pub fn (n &Node) is_slottable() bool {
	return n.is_element() || n.is_text() || n.is_cdata_section()
}

pub fn (n &Node) is_attribute() bool {
	return n.node_type == .attribute_node
}

pub fn (n &Node) is_cdata_section() bool {
	return n.node_type == .cdata_section_node
}

pub fn (n &Node) is_shadow_root() bool {
	return n.is_document_fragment() && n.as_shadow_root() != none
}

pub fn (n &Node) node_type_value() u16 {
	return u16(int(n.node_type))
}

pub fn (n &Node) unique_id() UniqueNodeID {
	return n.unique_id_
}

pub fn (n &Node) document() &Document {
	if n.document_ != unsafe { nil } {
		return n.document_
	}
	if n.is_document() {
		return unsafe { &Document(n) }
	}
	return unsafe { nil }
}

pub fn (n &Node) owner_document() ?&Document {
	// The ownerDocument getter steps are to return null, if this is a document; otherwise this's node document.
	if n.is_document() {
		return none
	}
	if n.document_ == unsafe { nil } {
		return none
	}
	return n.document_
}

pub fn (n &Node) parent() ?&Node {
	if n.parent_ == unsafe { nil } {
		return none
	}
	return n.parent_
}

pub fn (n &Node) parent_node() ?&Node {
	return n.parent()
}

pub fn (n &Node) first_child() ?&Node {
	if n.children.len == 0 {
		return none
	}
	return n.children[0]
}

pub fn (n &Node) last_child() ?&Node {
	if n.children.len == 0 {
		return none
	}
	return n.children[n.children.len - 1]
}

pub fn (n &Node) child_count() int {
	return n.children.len
}

pub fn (n &Node) has_children() bool {
	return n.children.len > 0
}

pub fn (n &Node) has_child_nodes() bool {
	return n.has_children()
}

pub fn (n &Node) index() int {
	parent := n.parent() or { return 0 }
	for i, child in parent.children {
		if child == n {
			return i
		}
	}
	return 0
}

pub fn (n &Node) previous_sibling() ?&Node {
	parent := n.parent() or { return none }
	idx := n.index()
	if idx <= 0 {
		return none
	}
	return parent.children[idx - 1]
}

pub fn (n &Node) next_sibling() ?&Node {
	parent := n.parent() or { return none }
	idx := n.index()
	if idx + 1 >= parent.children.len {
		return none
	}
	return parent.children[idx + 1]
}

pub fn (n &Node) root() &Node {
	parent := n.parent() or { return n }
	return parent.root()
}

pub fn (n &Node) is_descendant_of(other &Node) bool {
	for ancestor := n.parent(); ancestor != none; {
		current := ancestor or { break }
		if current == other {
			return true
		}
		ancestor = current.parent()
	}
	return false
}

pub fn (n &Node) is_inclusive_descendant_of(other &Node) bool {
	return n == other || n.is_descendant_of(other)
}

pub fn (n &Node) is_ancestor_of(other &Node) bool {
	return other.is_descendant_of(n)
}

pub fn (n &Node) is_inclusive_ancestor_of(other &Node) bool {
	return n == other || n.is_ancestor_of(other)
}

pub fn (n &Node) as_element() ?&Element {
	if !n.is_element() {
		return none
	}
	return unsafe { &Element(n) }
}

pub fn (e &Element) as_node() &Node {
	return unsafe { &Node(e) }
}

pub fn (t &Text) as_node() &Node {
	return unsafe { &Node(t) }
}

pub fn (df &DocumentFragment) as_node() &Node {
	return unsafe { &Node(df) }
}

pub fn (n &Node) as_document_fragment() ?&DocumentFragment {
	if !n.is_document_fragment() {
		return none
	}
	return unsafe { &DocumentFragment(n) }
}

pub fn (n &Node) as_shadow_root() ?&ShadowRoot {
	if !n.is_document_fragment() {
		return none
	}
	shadow := unsafe { &ShadowRoot(n) }
	if shadow.host_ == unsafe { nil } && !shadow.declarative && shadow.style_scope_.str() == '' {
		return none
	}
	return shadow
}

pub fn (n &Node) as_character_data() ?&CharacterData {
	if !n.is_character_data() {
		return none
	}
	return unsafe { &CharacterData(n) }
}

pub fn (n &Node) as_attr() ?&Attr {
	if !n.is_attribute() {
		return none
	}
	return unsafe { &Attr(n) }
}

pub fn (n &Node) dispatch_event_simple(event_name string, bubbles bool) {
	_ = event_name
	_ = bubbles
}

pub fn (n &Node) dispatch_event(event &Event) {
	_ = event
}

pub fn (n &Node) has_event_listener(type_ string) bool {
	return type_ in n.event_listener_types
}

// https://dom.spec.whatwg.org/#dom-node-baseuri
pub fn (n &Node) base_uri() string {
	// Return this's node document's document base URL, serialized.
	doc := n.document()
	if doc == unsafe { nil } {
		return ''
	}
	return doc.base_url().to_string()
}

pub fn (n &Node) enclosing_link_element() ?&HTMLAnchorElement {
	for current := ?&Node(n); current != none; {
		node := current or { break }
		if element := node.as_element() {
			if element.local_name() == 'a' && element.has_attribute('href') {
				return unsafe { &HTMLAnchorElement(element) }
			}
		}
		current = node.parent()
	}
	return none
}

pub fn (n &Node) enclosing_html_element() ?&HTMLElement {
	for current := ?&Node(n); current != none; {
		node := current or { break }
		if element := node.as_element() {
			if element.is_html_element() {
				return unsafe { &HTMLElement(element) }
			}
		}
		current = node.parent()
	}
	return none
}

pub fn (n &Node) enclosing_html_element_with_attribute(attribute string) ?&HTMLElement {
	for current := ?&Node(n); current != none; {
		node := current or { break }
		if element := node.as_element() {
			if element.is_html_element() && element.has_attribute(attribute) {
				return unsafe { &HTMLElement(element) }
			}
		}
		current = node.parent()
	}
	return none
}

pub fn (n &Node) alternative_text() ?string {
	return none
}

// https://dom.spec.whatwg.org/#concept-descendant-text-content
pub fn (n &Node) descendant_text_content() string {
	mut builder := strings.new_builder(0)
	n.for_each_in_subtree(fn [mut builder] (node &Node) TraversalDecision {
		if node.is_text() {
			if data := node.character_data() {
				builder.write_string(data.data_)
			}
		}
		return .@continue
	})
	return builder.str()
}

// https://dom.spec.whatwg.org/#dom-node-textcontent
pub fn (n &Node) text_content() ?string {
	// The textContent getter steps are to return the following, switching on the interface this implements:
	if n.is_document_fragment() || n.is_element() {
		// If DocumentFragment or Element, return the descendant text content of this.
		return n.descendant_text_content()
	}
	if character_data := n.character_data() {
		// If CharacterData, return this's data.
		return character_data.data_
	}
	if attr := n.as_attr() {
		// If Attr node, return this's value.
		return attr.value_
	}
	// Otherwise, return null.
	return none
}

// https://dom.spec.whatwg.org/#ref-for-dom-node-textcontent%E2%91%A0
pub fn (mut n Node) set_text_content(maybe_content ?string) ! {
	// The textContent setter steps are to, if the given value is null, act as if it was the empty string instead,
	// and then do as described below, switching on the interface this implements:
	content := maybe_content or { '' }
	if n.is_document_fragment() || n.is_element() {
		// If DocumentFragment or Element, string replace all with the given value within this.
		// OPTIMIZATION: Replacing nothing with nothing is a no-op. Avoid all invalidation in this case.
		if n.children.len == 0 && content.len == 0 {
			return
		}
		n.string_replace_all(content)
	} else if mut character_data := n.character_data_mut() {
		// If CharacterData, replace data with node this, offset 0, count this's length, and data the given value.
		character_data.replace_data(0, character_data.length_in_utf16_code_units(), content)!
	} else if mut attr := n.attr_mut() {
		// If Attr, set an existing attribute value with this and the given value.
		attr.set_value(content)!
	}
	// Otherwise, do nothing.
	if n.is_connected() {
		n.invalidate_style(.node_set_text_content)
		n.set_needs_layout_tree_update(true, .node_set_text_content)
	}
	doc := n.document()
	if doc != unsafe { nil } {
		mut mutable_doc := unsafe { &Document(doc) }
		mutable_doc.bump_dom_tree_version()
	}
}

// https://dom.spec.whatwg.org/#dom-node-normalize
pub fn (mut n Node) normalize() ! {
	// The normalize() method steps are to run these steps for each descendant exclusive Text node node of this.
	mut text_nodes := []&Node{}
	n.for_each_in_inclusive_subtree(fn [mut text_nodes] (node &Node) TraversalDecision {
		if node.is_exclusive_text() {
			text_nodes << node
		}
		return .@continue
	})
	for text_node in text_nodes {
		mut node := unsafe { &Node(text_node) }
		if mut data := node.character_data_mut() {
			mut length := data.length_in_utf16_code_units()
			// If length is zero, then remove node and continue with the next exclusive Text node, if any.
			if length == 0 {
				if node.parent() != none {
					node.remove(false)
				}
				continue
			}
			mut append_data := ''
			for text_sibling in contiguous_exclusive_text_nodes_excluding_self(node) {
				if current_data := text_sibling.character_data() {
					append_data += current_data.data_
				}
			}
			data.replace_data(length, 0, append_data)!

			mut current_node := node.next_sibling()
			for current_node != none {
				current := current_node or { break }
				if !current.is_exclusive_text() {
					break
				}

				document := node.document()
				if document != unsafe { nil } {
					for live_range in document.live_ranges_ {
						mut range := unsafe { &Range(live_range) }
						if range.start_container_ == current {
							range.start_offset_ += length
							range.start_container_ = node
						}
						if range.end_container_ == current {
							range.end_offset_ += length
							range.end_container_ = node
						}
						if parent := current.parent() {
							if range.start_container_ == parent && range.start_offset_ == current.index() {
								range.start_container_ = node
								range.start_offset_ = length
							}
							if range.end_container_ == parent && range.end_offset_ == current.index() {
								range.end_container_ = node
								range.end_offset_ = length
							}
						}
					}
				}

				if current_data := current.character_data() {
					length += current_data.length_in_utf16_code_units()
				} else {
					length += current.length()
				}
				current_node = current.next_sibling()
			}

			for text_sibling in contiguous_exclusive_text_nodes_excluding_self(node) {
				mut removable := unsafe { &Node(text_sibling) }
				removable.remove(false)
			}
		}
	}
}

fn contiguous_exclusive_text_nodes_excluding_self(node &Node) []&Node {
	// The contiguous exclusive Text nodes of a node node are node, node's previous sibling exclusive Text node, if any,
	// and its contiguous exclusive Text nodes, and node's next sibling exclusive Text node, if any,
	// and its contiguous exclusive Text nodes, avoiding any duplicates.
	// NOTE: The callers of this method require node itself to be excluded.
	mut nodes := []&Node{}
	for sibling := node.previous_sibling(); sibling != none; {
		current := sibling or { break }
		if !current.is_exclusive_text() {
			break
		}
		nodes.prepend(current)
		sibling = current.previous_sibling()
	}
	for sibling := node.next_sibling(); sibling != none; {
		current := sibling or { break }
		if !current.is_exclusive_text() {
			break
		}
		nodes << current
		sibling = current.next_sibling()
	}
	return nodes
}

// https://dom.spec.whatwg.org/#dom-node-nodevalue
pub fn (n &Node) node_value() ?string {
	// The nodeValue getter steps are to return the following, switching on the interface this implements:
	if attr := n.as_attr() {
		// If Attr, return this's value.
		return attr.value_
	}
	if character_data := n.character_data() {
		// If CharacterData, return this's data.
		return character_data.data_
	}
	// Otherwise, return null.
	return none
}

// https://dom.spec.whatwg.org/#ref-for-dom-node-nodevalue%E2%91%A0
pub fn (mut n Node) set_node_value(maybe_value ?string) ! {
	// The nodeValue setter steps are to, if the given value is null, act as if it was the empty string instead,
	// and then do as described below, switching on the interface this implements:
	value := maybe_value or { '' }
	if mut attr := n.attr_mut() {
		// If Attr, set an existing attribute value with this and the given value.
		attr.set_value(value)!
	} else if mut character_data := n.character_data_mut() {
		// If CharacterData, replace data with node this, offset 0, count this's length, and data the given value.
		character_data.set_data(value)
	}
	// Otherwise, do nothing.
}

// https://html.spec.whatwg.org/multipage/document-sequences.html#node-navigable
pub fn (n &Node) navigable() ?&Navigable {
	doc := n.document()
	if doc == unsafe { nil } {
		return none
	}
	if doc.cached_navigable_ != unsafe { nil } {
		return doc.cached_navigable_
	}
	// To get the node navigable of a node node, return the navigable whose active document is node's node document,
	// or null if there is no such navigable.
	return none
}

fn reason_may_affect_has_selectors(reason StyleInvalidationReason) bool {
	// :has() selectors match based on DOM state only (structure, attributes, pseudo-classes). Reasons that don't change
	// any DOM state can't affect :has() matching, so we can skip scheduling :has() ancestor invalidation.
	return reason !in [.base_url_changed, .css_font_loaded, .html_iframe_element_geometry_change,
		.html_object_element_update_layout_and_child_objects, .navigable_set_viewport_size,
		.settings_change]
}

pub fn (mut n Node) invalidate_style(reason StyleInvalidationReason) {
	if n.is_character_data() {
		return
	}
	// When invalidating style for a node, we actually invalidate:
	// - the node itself
	// - all of its descendants
	// - preceding siblings that depend on following-sibling counts (only on DOM insert/remove)
	// - subsequent siblings that depend on previous siblings or sibling combinators
	// FIXME: This is a lot of invalidation and we should implement more sophisticated invalidation to do less work!
	if n.is_document() {
		doc := n.document()
		if doc != unsafe { nil } {
			mut mutable_doc := unsafe { &Document(doc) }
			mutable_doc.set_needs_full_style_update(true)
		}
		return
	}
	n.set_entire_subtree_needs_style_update(true)
	for ancestor := n.parent_or_shadow_host(); ancestor != none; {
		mut current := unsafe { &Node(ancestor or { break }) }
		current.child_needs_style_update_ = true
		ancestor = current.parent_or_shadow_host()
	}
}

pub fn (mut n Node) invalidate_style_with_properties(reason StyleInvalidationReason, properties []InvalidationProperty, options StyleInvalidationOptions) {
	if n.is_character_data() {
		return
	}
	// This covers the C++ overload taking invalidation properties and options.
	_ = properties
	_ = reason_may_affect_has_selectors(reason)
	if options.invalidate_self {
		n.set_needs_style_update(true)
	}
}

pub fn (n &Node) child_text_content() string {
	if !n.is_parent_node() {
		return ''
	}
	mut builder := strings.new_builder(0)
	for child in n.children {
		if child.is_text() {
			if content := child.text_content() {
				builder.write_string(content)
			}
		}
	}
	return builder.str()
}

// https://dom.spec.whatwg.org/#concept-shadow-including-root
pub fn (n &Node) shadow_including_root() &Node {
	// The shadow-including root of an object is its root's host's shadow-including root,
	// if the object's root is a shadow root; otherwise its root.
	node_root := n.root()
	if shadow_root := node_root.as_shadow_root() {
		if shadow_root.host_ != unsafe { nil } {
			return shadow_root.host_.as_node().shadow_including_root()
		}
	}
	return node_root
}

// https://dom.spec.whatwg.org/#concept-closed-shadow-hidden
pub fn (n &Node) is_closed_shadow_hidden_from(b &Node) bool {
	// A node A is closed-shadow-hidden from a node B if all of the following conditions are true:
	a_root := n.root()
	// - A's root is a shadow root.
	shadow_root := a_root.as_shadow_root() or { return false }
	// - A's root is not a shadow-including inclusive ancestor of B.
	if a_root.is_shadow_including_inclusive_ancestor_of(b) {
		return false
	}
	// - A's root is a shadow root whose mode is "closed" or A's root's host is closed-shadow-hidden from B.
	if shadow_root.mode == .closed {
		return true
	}
	if shadow_root.host_ != unsafe { nil } {
		return shadow_root.host_.as_node().is_closed_shadow_hidden_from(b)
	}
	return false
}

// https://dom.spec.whatwg.org/#connected
pub fn (n &Node) is_connected() bool {
	// An element is connected if its shadow-including root is a document.
	return n.shadow_including_root().is_document()
}

// https://html.spec.whatwg.org/multipage/infrastructure.html#browsing-context-connected
pub fn (n &Node) is_browsing_context_connected() bool {
	// A node is browsing-context connected when it is connected and its shadow-including root's browsing context is non-null.
	doc := n.shadow_including_root().document()
	return n.is_connected() && doc != unsafe { nil } && doc.browsing_context != unsafe { nil }
}

// https://dom.spec.whatwg.org/#concept-node-ensure-pre-insertion-validity
pub fn (n &Node) ensure_pre_insertion_validity(realm voidptr, node &Node, child ?&Node) ! {
	_ = realm
	// 1. If parent is not a Document, DocumentFragment, or Element node, then throw a "HierarchyRequestError" DOMException.
	if !n.is_document() && !n.is_document_fragment() && !n.is_element() {
		return error('HierarchyRequestError: Can only insert into a document, document fragment or element')
	}
	// 2. If node is a host-including inclusive ancestor of parent, then throw a "HierarchyRequestError" DOMException.
	if node.is_host_including_inclusive_ancestor_of(n) {
		return error('HierarchyRequestError: New node is an ancestor of this node')
	}
	// 3. If child is non-null and its parent is not parent, then throw a "NotFoundError" DOMException.
	if child_node := child {
		if child_node.parent_ != n {
			return error('NotFoundError: This node is not the parent of the given child')
		}
	}
	// FIXME: All the following "Invalid node type for insertion" messages could be more descriptive.
	if !(node.is_document_fragment() || node.is_document_type() || node.is_element()
		|| node.is_text() || node.is_comment() || node.node_type == .processing_instruction_node
		|| node.is_cdata_section()) {
		return error('HierarchyRequestError: Invalid node type for insertion')
	}
	if (node.is_text() && n.is_document()) || (node.is_document_type() && !n.is_document()) {
		return error('HierarchyRequestError: Invalid node type for insertion')
	}

	// 6. If parent is a document, and any of the statements below, switched on the interface node implements, are true, then throw a "HierarchyRequestError" DOMException.
	if n.is_document() {
		if node.is_document_fragment() {
			node_element_child_count := node_child_element_count(node)
			if node_element_child_count > 1 || node_has_child_text(node) {
				return error('HierarchyRequestError: Invalid node type for insertion')
			}
			if node_element_child_count == 1
				&& (node_has_child_element(n) || node_child_is_document_type(child)
				|| node_has_following_doctype(child)) {
				return error('HierarchyRequestError: Invalid node type for insertion')
			}
		} else if node.is_element() {
			if node_has_child_element(n) || node_child_is_document_type(child)
				|| node_has_following_doctype(child) {
				return error('HierarchyRequestError: Invalid node type for insertion')
			}
		} else if node.is_document_type() {
			if node_has_child_document_type(n) || node_has_preceding_element(child)
				|| (child == none && node_has_child_element(n)) {
				return error('HierarchyRequestError: Invalid node type for insertion')
			}
		}
	}
}

fn (n &Node) ensure_replacement_validity(node &Node, child &Node) ! {
	if !n.is_document() && !n.is_document_fragment() && !n.is_element() {
		return error('HierarchyRequestError: Can only insert into a document, document fragment or element')
	}
	if node.is_host_including_inclusive_ancestor_of(n) {
		return error('HierarchyRequestError: New node is an ancestor of this node')
	}
	if child.parent_ != n {
		return error('NotFoundError: This node is not the parent of the given child')
	}
	if !(node.is_document_fragment() || node.is_document_type() || node.is_element()
		|| node.is_text() || node.is_comment() || node.node_type == .processing_instruction_node
		|| node.is_cdata_section()) {
		return error('HierarchyRequestError: Invalid node type for insertion')
	}
	if (node.is_text() && n.is_document()) || (node.is_document_type() && !n.is_document()) {
		return error('HierarchyRequestError: Invalid node type for insertion')
	}
	if n.is_document() {
		if node.is_document_fragment() {
			node_element_child_count := node_child_element_count(node)
			if node_element_child_count > 1 || node_has_child_text(node) {
				return error('HierarchyRequestError: Invalid node type for insertion')
			}
			if node_element_child_count == 1
				&& (node_first_child_element_is_not(n, child) || node_has_following_doctype(child)) {
				return error('HierarchyRequestError: Invalid node type for insertion')
			}
		} else if node.is_element() {
			if node_first_child_element_is_not(n, child) || node_has_following_doctype(child) {
				return error('HierarchyRequestError: Invalid node type for insertion')
			}
		} else if node.is_document_type() {
			if node_first_child_document_type_is_not(n, child) || node_has_preceding_element(child) {
				return error('HierarchyRequestError: Invalid node type for insertion')
			}
		}
	}
}

fn node_child_element_count(node &Node) int {
	mut count := 0
	for child in node.children {
		if child.is_element() {
			count++
		}
	}
	return count
}

fn node_has_child_text(node &Node) bool {
	for child in node.children {
		if child.is_text() {
			return true
		}
	}
	return false
}

fn node_has_child_element(node &Node) bool {
	return node_first_child_element(node) != none
}

fn node_first_child_element(node &Node) ?&Node {
	for child in node.children {
		if child.is_element() {
			return child
		}
	}
	return none
}

fn node_has_child_document_type(node &Node) bool {
	return node_first_child_document_type(node) != none
}

fn node_first_child_document_type(node &Node) ?&Node {
	for child in node.children {
		if child.is_document_type() {
			return child
		}
	}
	return none
}

fn node_child_is_document_type(child ?&Node) bool {
	if child_node := child {
		return child_node.is_document_type()
	}
	return false
}

fn node_has_following_doctype(child ?&Node) bool {
	child_node := child or { return false }
	parent := child_node.parent() or { return false }
	mut found_child := false
	for sibling in parent.children {
		if sibling == child_node {
			found_child = true
			continue
		}
		if found_child && sibling.is_document_type() {
			return true
		}
	}
	return false
}

fn node_has_preceding_element(child ?&Node) bool {
	child_node := child or { return false }
	parent := child_node.parent() or { return false }
	for sibling in parent.children {
		if sibling == child_node {
			return false
		}
		if sibling.is_element() {
			return true
		}
	}
	return false
}

fn node_first_child_element_is_not(parent &Node, child &Node) bool {
	if first_element := node_first_child_element(parent) {
		return first_element != child
	}
	return true
}

fn node_first_child_document_type_is_not(parent &Node, child &Node) bool {
	if first_doctype := node_first_child_document_type(parent) {
		return first_doctype != child
	}
	return true
}

fn node_as_html_slot_element(node &Node) ?&HTMLSlotElement {
	element := node.as_element() or { return none }
	if element.local_name() != 'slot' {
		return none
	}
	return unsafe { &HTMLSlotElement(element) }
}

fn assign_slot_for_inserted_child(parent &Node, child &Node) {
	element := parent.as_element() or { return }
	shadow_root := element.shadow_root() or { return }
	if shadow_root.slot_assignment() == .named && child.is_slottable() {
		assign_a_slot(child.as_slottable())
	}
}

fn signal_slot_change_if_empty_slot(node &Node, root &Node) {
	slot := node_as_html_slot_element(node) or { return }
	if root.is_shadow_root() && slot.assigned_nodes_internal().len == 0 {
		signal_a_slot_change(slot)
	}
}

fn register_slot_descendants_with_shadow_root(node &Node) {
	shadow_root := node.root().as_shadow_root() or { return }
	node.for_each_in_inclusive_subtree(fn [shadow_root] (inclusive_descendant &Node) TraversalDecision {
		if slot := node_as_html_slot_element(inclusive_descendant) {
			mut mutable_shadow_root := unsafe { &ShadowRoot(shadow_root) }
			mutable_shadow_root.register_slot(slot)
		}
		return .@continue
	})
}

fn unregister_slot_descendants_from_shadow_root(node &Node, root &Node) bool {
	has_descendant_slot := node_has_html_slot_in_inclusive_subtree(node)
	if shadow_root := root.as_shadow_root() {
		unregister_slot_descendants_from_shadow_root_impl(node, shadow_root)
	}
	return has_descendant_slot
}

fn node_has_html_slot_in_inclusive_subtree(node &Node) bool {
	if node_as_html_slot_element(node) != none {
		return true
	}
	for child in node.children {
		if node_has_html_slot_in_inclusive_subtree(child) {
			return true
		}
	}
	return false
}

fn unregister_slot_descendants_from_shadow_root_impl(node &Node, shadow_root &ShadowRoot) {
	if slot := node_as_html_slot_element(node) {
		mut mutable_shadow_root := unsafe { &ShadowRoot(shadow_root) }
		mutable_shadow_root.unregister_slot(slot)
	}
	for child in node.children {
		unregister_slot_descendants_from_shadow_root_impl(child, shadow_root)
	}
}

// https://dom.spec.whatwg.org/#concept-node-insert
pub fn (mut n Node) insert_before(node &Node, child ?&Node, suppress_observers bool) {
	// 1. Let nodes be node's children, if node is a DocumentFragment node; otherwise << node >>.
	mut nodes := []&Node{}
	if node.is_document_fragment() {
		nodes = node.children_as_vector()
	} else {
		nodes << node
	}
	// 2. Let count be nodes's size.
	count := nodes.len
	// 3. If count is 0, then return.
	if count == 0 {
		return
	}
	// 4. If node is a DocumentFragment node, then remove its children and queue a mutation record.
	if node.is_document_fragment() {
		mut fragment := unsafe { &Node(node) }
		fragment.remove_all_children(true)
		fragment.queue_tree_mutation_record([], nodes, unsafe { nil }, unsafe { nil })
	}
	if child_node := child {
		doc := n.document()
		if doc != unsafe { nil } {
			for live_range in doc.live_ranges_ {
				mut range := unsafe { &Range(live_range) }
				if range.start_container_ == &n && range.start_offset_ > child_node.index() {
					range.start_offset_ += count
				}
				if range.end_container_ == &n && range.end_offset_ > child_node.index() {
					range.end_offset_ += count
				}
			}
		}
	}
	previous_sibling := if child_node := child {
		child_node.previous_sibling() or { unsafe { nil } }
	} else {
		n.last_child() or { unsafe { nil } }
	}
	for node_to_insert in nodes {
		// 1. Adopt node into parent's node document.
		doc := n.document()
		if doc != unsafe { nil } {
			mut mutable_doc := unsafe { &Document(doc) }
			mutable_doc.adopt_node(node_to_insert)
		}
		if child == none {
			n.append_child_impl(node_to_insert)
		} else {
			n.insert_before_impl(node_to_insert, child)
		}
		assign_slot_for_inserted_child(&n, node_to_insert)
		signal_slot_change_if_empty_slot(&n, n.root())
		register_slot_descendants_with_shadow_root(node_to_insert)
		assign_slottables_for_a_tree(node_to_insert.root())
		mut inserted_node := unsafe { &Node(node_to_insert) }
		inserted_node.invalidate_style(.node_insert_before)
		inserted_node.for_each_shadow_including_inclusive_descendant(fn (inclusive_descendant &Node) TraversalDecision {
			mut mutable_descendant := unsafe { &Node(inclusive_descendant) }
			mutable_descendant.inserted()
			return .@continue
		})
	}
	if !suppress_observers {
		n.queue_tree_mutation_record(nodes, [], previous_sibling, child or { unsafe { nil } })
	}
	n.children_changed(ChildrenChangedMetadata{
		type_: .inserted
		node:  node
	})
	for node_to_insert in nodes {
		node_to_insert.for_each_shadow_including_inclusive_descendant(fn (inclusive_descendant &Node) TraversalDecision {
			if inclusive_descendant.is_connected() {
				mut mutable_descendant := unsafe { &Node(inclusive_descendant) }
				mutable_descendant.post_connection()
			}
			return .@continue
		})
	}
	if n.is_connected() {
		n.set_needs_layout_tree_update(true, .node_insert_before)
	}
	doc := n.document()
	if doc != unsafe { nil } {
		mut mutable_doc := unsafe { &Document(doc) }
		mutable_doc.bump_dom_tree_version()
	}
}

// https://dom.spec.whatwg.org/#concept-node-pre-insert
fn reference_child_for_pre_insert(child ?&Node, node &Node) ?&Node {
	if child_node := child {
		if child_node == node {
			return node.next_sibling()
		}
		return child_node
	}
	return none
}

pub fn (mut n Node) pre_insert(node &Node, child ?&Node) !&Node {
	// 1. Ensure pre-insertion validity of node into parent before child.
	n.ensure_pre_insertion_validity(unsafe { nil }, node, child)!
	// 2. Let referenceChild be child.
	// 3. If referenceChild is node, then set referenceChild to node's next sibling.
	reference_child := reference_child_for_pre_insert(child, node)
	// 4. Insert node into parent before referenceChild.
	n.insert_before(node, reference_child, false)
	// 5. Return node.
	return node
}

// https://dom.spec.whatwg.org/#dom-node-removechild
pub fn (mut n Node) remove_child(child &Node) !&Node {
	// The removeChild(child) method steps are to return the result of pre-removing child from this.
	return n.pre_remove(child)
}

// https://dom.spec.whatwg.org/#concept-node-pre-remove
pub fn (mut n Node) pre_remove(child &Node) !&Node {
	// 1. If child's parent is not parent, then throw a "NotFoundError" DOMException.
	if child.parent_ != n {
		return error('NotFoundError: Child does not belong to this node')
	}
	// 2. Remove child.
	mut mutable_child := unsafe { &Node(child) }
	mutable_child.remove(false)
	// 3. Return child.
	return child
}

// https://dom.spec.whatwg.org/#concept-node-append
pub fn (mut n Node) append_child(node &Node) !&Node {
	// To append a node node to a node parent: pre-insert node into parent before null.
	return n.pre_insert(node, none)
}

// https://dom.spec.whatwg.org/#live-range-pre-remove-steps
pub fn (mut n Node) live_range_pre_remove() {
	// 1. Let parent be node's parent.
	parent := n.parent() or { return }
	// 2. Assert: parent is not null.
	// 3. Let index be node's index.
	index := n.index()
	node := unsafe { &Node(&n) }
	document := n.document()
	// 4. For each live range whose start node is an inclusive descendant of node, set its start to (parent, index).
	for live_range in document.live_ranges_ {
		mut range := unsafe { &Range(live_range) }
		if range.start_container_.is_inclusive_descendant_of(node) {
			range.start_container_ = parent
			range.start_offset_ = index
		}
	}
	// 5. For each live range whose end node is an inclusive descendant of node, set its end to (parent, index).
	for live_range in document.live_ranges_ {
		mut range := unsafe { &Range(live_range) }
		if range.end_container_.is_inclusive_descendant_of(node) {
			range.end_container_ = parent
			range.end_offset_ = index
		}
	}
	// 6. For each live range whose start node is parent and start offset is greater than index, decrease its start offset by 1.
	for live_range in document.live_ranges_ {
		mut range := unsafe { &Range(live_range) }
		if range.start_container_ == parent && range.start_offset_ > index {
			range.start_offset_--
		}
	}
	// 7. For each live range whose end node is parent and end offset is greater than index, decrease its end offset by 1.
	for live_range in document.live_ranges_ {
		mut range := unsafe { &Range(live_range) }
		if range.end_container_ == parent && range.end_offset_ > index {
			range.end_offset_--
		}
	}
}

// https://dom.spec.whatwg.org/#concept-node-remove
pub fn (mut n Node) remove(suppress_observers bool) {
	// 1. Let parent be node's parent.
	parent := n.parent() or { return }
	n.live_range_pre_remove()
	doc := n.document()
	if doc != unsafe { nil } {
		for node_iterator in doc.node_iterators {
			mut mutable_node_iterator := unsafe { &NodeIterator(node_iterator) }
			mutable_node_iterator.run_pre_removing_steps(&n)
		}
	}
	old_previous_sibling := n.previous_sibling() or { unsafe { nil } }
	old_next_sibling := n.next_sibling() or { unsafe { nil } }
	if n.is_connected() {
		// Since the tree structure is about to change, we need to invalidate both style and layout.
		n.invalidate_style(.node_remove)
		if n.unsafe_layout_node() != none {
			mut mutable_parent := unsafe { &Node(parent) }
			mutable_parent.set_needs_layout_tree_update(true, .node_remove)
		}
	}
	mut mutable_parent := unsafe { &Node(parent) }
	mutable_parent.remove_child_impl(n)
	if assigned_slot := assigned_slot_for_node(&n) {
		assign_slottables(assigned_slot)
	}
	parent_root := parent.root()
	signal_slot_change_if_empty_slot(parent, parent_root)
	if unregister_slot_descendants_from_shadow_root(&n, parent_root) {
		assign_slottables_for_a_tree(parent_root)
		assign_slottables_for_a_tree(&n)
	}
	n.removed_from(parent, parent_root)
	n.for_each_shadow_including_descendant(fn [parent_root] (descendant &Node) TraversalDecision {
		mut mutable_descendant := unsafe { &Node(descendant) }
		mutable_descendant.removed_from(none, parent_root)
		return .@continue
	})
	if !suppress_observers {
		mut removed := []&Node{}
		removed << &n
		mutable_parent.queue_tree_mutation_record([]&Node{}, removed, old_previous_sibling,
			old_next_sibling)
	}
	mutable_parent.children_changed(ChildrenChangedMetadata{
		type_: .removal
		node:  n
	})
	if doc != unsafe { nil } {
		mut mutable_doc := unsafe { &Document(doc) }
		mutable_doc.bump_dom_tree_version()
	}
}

// https://dom.spec.whatwg.org/#concept-node-replace
pub fn (mut n Node) replace_child(node &Node, child &Node) !&Node {
	n.ensure_replacement_validity(node, child)!
	mut reference_child := child.next_sibling()
	if reference := reference_child {
		if reference == node {
			reference_child = node.next_sibling()
		}
	}
	previous_sibling := child.previous_sibling() or { unsafe { nil } }
	mut removed_nodes := []&Node{}
	if child.parent() != none {
		removed_nodes << child
		mut mutable_child := unsafe { &Node(child) }
		mutable_child.remove(true)
	}
	mut nodes := []&Node{}
	if node.is_document_fragment() {
		nodes = node.children_as_vector()
	} else {
		nodes << node
	}
	if reference_child == none
		|| ((reference_child or { unsafe { nil } }).parent_ == n && child.parent() == none) {
		n.insert_before(node, reference_child, true)
	}
	n.queue_tree_mutation_record(nodes, removed_nodes, previous_sibling, reference_child or {
		unsafe { nil }
	})
	return child
}

// https://dom.spec.whatwg.org/#concept-node-clone
pub fn (n &Node) clone_node(document ?&Document, subtree bool, parent ?&Node) !&Node {
	// To clone a node given a node node and an optional document document (default node's node document),
	// boolean subtree (default false), and node-or-null parent (default null):
	doc := document or { n.document() }
	copy := n.clone_single_node(doc)!
	n.cloned(copy, subtree)!
	if parent_node := parent {
		mut mutable_parent := unsafe { &Node(parent_node) }
		mutable_parent.append_child(copy)!
	}
	if subtree {
		for child in n.children {
			child.clone_node(doc, subtree, copy)!
		}
	}
	if element := n.as_element() {
		if shadow_root := element.shadow_root() {
			if shadow_root.clonable() {
				mut copy_element := copy.as_element() or {
					return error('InvalidStateError: Element clone did not produce an element')
				}
				copy_element.attach_a_shadow_root(shadow_root.mode_(), true, shadow_root.serializable(),
					shadow_root.delegates_focus(), shadow_root.slot_assignment())!
				mut copy_shadow_root := copy_element.shadow_root() or {
					return error('InvalidStateError: Cloned shadow root was not attached')
				}
				copy_shadow_root.set_declarative(shadow_root.declarative)
				copy_shadow_root_node := unsafe { &Node(copy_shadow_root) }
				for child in shadow_root_as_node(shadow_root).children {
					child.clone_node(doc, subtree, copy_shadow_root_node)!
				}
			}
		}
	}
	return copy
}

// https://dom.spec.whatwg.org/#move
pub fn (mut n Node) move_node(mut new_parent Node, child ?&Node) ! {
	if new_parent.shadow_including_root() != n.shadow_including_root() {
		return error('HierarchyRequestError: New parent is not in the same shadow tree')
	}
	if n.is_host_including_inclusive_ancestor_of(new_parent) {
		return error('HierarchyRequestError: New parent is an ancestor of this node')
	}
	if child_node := child {
		if child_node.parent_ != new_parent {
			return error('NotFoundError: Child does not belong to the new parent')
		}
	}
	if !(n.is_element() || n.is_character_data()) {
		return error('HierarchyRequestError: Invalid node type for insertion')
	}
	if n.is_text() && new_parent.is_document() {
		return error('HierarchyRequestError: Invalid node type for insertion')
	}
	if new_parent.is_document() && n.is_element() {
		if node_has_child_element(&new_parent) || node_child_is_document_type(child)
			|| node_has_following_doctype(child) {
			return error('HierarchyRequestError: Invalid node type for insertion')
		}
	}
	old_parent := n.parent() or { return }
	n.live_range_pre_remove()
	doc := n.document()
	if doc != unsafe { nil } {
		for node_iterator in doc.node_iterators {
			mut mutable_node_iterator := unsafe { &NodeIterator(node_iterator) }
			mutable_node_iterator.run_pre_removing_steps(&n)
		}
	}
	old_previous_sibling := n.previous_sibling() or { unsafe { nil } }
	old_next_sibling := n.next_sibling() or { unsafe { nil } }
	mut mutable_old_parent := unsafe { &Node(old_parent) }
	mutable_old_parent.remove_child_impl(n)
	if assigned_slot := assigned_slot_for_node(&n) {
		assign_slottables(assigned_slot)
	}
	old_parent_root := old_parent.root()
	signal_slot_change_if_empty_slot(old_parent, old_parent_root)
	if unregister_slot_descendants_from_shadow_root(&n, old_parent_root) {
		assign_slottables_for_a_tree(old_parent_root)
		assign_slottables_for_a_tree(&n)
	}
	if doc != unsafe { nil } {
		if child_node := child {
			for live_range in doc.live_ranges_ {
				mut range := unsafe { &Range(live_range) }
				if range.start_container_ == &new_parent && range.start_offset_ > child_node.index() {
					range.start_offset_++
				}
				if range.end_container_ == &new_parent && range.end_offset_ > child_node.index() {
					range.end_offset_++
				}
			}
		}
	}
	new_previous_sibling := if child_node := child {
		child_node.previous_sibling() or { unsafe { nil } }
	} else {
		new_parent.last_child() or { unsafe { nil } }
	}
	if child == none {
		new_parent.append_child_impl(n)
	} else {
		new_parent.insert_before_impl(n, child)
	}
	assign_slot_for_inserted_child(&new_parent, &n)
	register_slot_descendants_with_shadow_root(&n)
	signal_slot_change_if_empty_slot(&new_parent, new_parent.root())
	assign_slottables_for_a_tree(n.root())
	n.invalidate_style(.node_insert_before)
	if n.is_connected() {
		new_parent.set_needs_layout_tree_update(true, .node_insert_before)
	}
	moved_node := &n
	n.for_each_shadow_including_inclusive_descendant(fn [old_parent, moved_node] (inclusive_descendant &Node) TraversalDecision {
		mut mutable_descendant := unsafe { &Node(inclusive_descendant) }
		if inclusive_descendant == moved_node {
			mutable_descendant.moved_from(old_parent)
		} else {
			mutable_descendant.moved_from(none)
		}
		return .@continue
	})
	mut removed_from_old_parent := []&Node{}
	removed_from_old_parent << &n
	mutable_old_parent.queue_tree_mutation_record([]&Node{}, removed_from_old_parent,
		old_previous_sibling, old_next_sibling)
	mut added_to_new_parent := []&Node{}
	added_to_new_parent << &n
	new_parent.queue_tree_mutation_record(added_to_new_parent, []&Node{}, new_previous_sibling, child or {
		unsafe { nil }
	})
	if doc != unsafe { nil } {
		mut mutable_doc := unsafe { &Document(doc) }
		mutable_doc.bump_dom_tree_version()
	}
}

// https://dom.spec.whatwg.org/#clone-a-single-node
pub fn (n &Node) clone_single_node(document &Document) !&Node {
	// To clone a single node given a node node and document document:
	mut copy := unsafe { &Node(nil) }
	if element := n.as_element() {
		// 2. If node is an element, create an element with the same local name, namespace, prefix, and is value.
		mut element_copy := create_element(document, element.local_name(), element.namespace_uri(),
			element.prefix(), element.is_value, false)!
		if attrs := element.attributes_ {
			for attr in attrs.attrs {
				element_copy.append_attribute(&Attr_{
					name_:          attr.name_
					value_:         attr.value_
					local_name_:    attr.local_name_
					prefix__:       attr.prefix__
					namespace_uri_: attr.namespace_uri_
				})
			}
		}
		copy = element_copy.as_node()
	} else if n.is_document() {
		document_copy := Document.create(n.document().url)
		copy = unsafe { &Node(document_copy) }
	} else if document_type := n.as_document_type() {
		mut document_type_copy := DocumentType.new(document)
		document_type_copy.set_name(document_type.name())
		document_type_copy.set_public_id(document_type.public_id())
		document_type_copy.set_system_id(document_type.system_id())
		copy = document_type_copy.as_node()
	} else if attr := n.as_attr() {
		copy = attr.clone(document).as_node()
	} else if n.is_text() {
		data := n.character_data() or { return error('InvalidStateError: Text node missing character data') }
		if n.is_cdata_section() {
			copy = CDATASection.new(document, data.data_).as_node()
		} else {
			copy = Text.new(document, data.data_).as_node()
		}
	} else if n.is_comment() {
		data := n.character_data() or { return error('InvalidStateError: Comment node missing character data') }
		copy = Comment.new(document, data.data_).as_node()
	} else if processing_instruction := n.as_processing_instruction() {
		copy = ProcessingInstruction.new(document, processing_instruction.data(), processing_instruction.target()).as_node()
	} else if n.is_document_fragment() {
		copy = DocumentFragment.new(document).as_node()
	} else {
		return error('NotSupportedError: Missing code for cloning this node type')
	}
	mut document_to_use := unsafe { &Document(document) }
	if n.is_document() {
		document_to_use = unsafe { &Document(copy) }
	}
	mut mutable_copy := unsafe { &Node(copy) }
	mutable_copy.set_document(document_to_use)
	return copy
}

// https://dom.spec.whatwg.org/#dom-node-clonenode
pub fn (n &Node) clone_node_binding(subtree bool) !&Node {
	// 1. If this is a shadow root, then throw a "NotSupportedError" DOMException.
	if n.is_shadow_root() {
		return error('NotSupportedError: Cannot clone shadow root')
	}
	// 2. Return the result of cloning a node given this with subtree set to subtree.
	return n.clone_node(none, subtree, none)
}

pub fn (mut n Node) set_document_from_document(document &Document) {
	n.set_document(document)
}

pub fn (mut n Node) set_document_from_named_node_map(document &Document) {
	n.set_document(document)
}

pub fn (mut n Node) set_document(document &Document) {
	if n.document_ == document {
		return
	}
	n.document_ = document
	if n.needs_style_update() || n.child_needs_style_update() {
		// NOTE: We unset and reset the "needs style update" flag here.
		// This ensures that there's a pending style update in the new document
		// that will eventually assign some style to this node if needed.
		n.set_needs_style_update(false)
		n.set_needs_style_update(true)
	}
}

pub fn (mut n Node) recompute_editable_subtree_flag() {
	mut new_value := false
	if n.is_document() {
		doc := n.document()
		new_value = doc != unsafe { nil } && doc.design_mode_enabled_state()
	} else if parent := n.parent() {
		new_value = parent.in_editable_subtree_
	}
	n.in_editable_subtree_ = new_value
}

// https://w3c.github.io/editing/docs/execCommand/#editable
pub fn (n &Node) is_editable() bool {
	// Something is editable if it is a node; it is not an editing host;
	if n.is_editing_host() {
		return false
	}
	// its parent is an editing host or editable;
	if parent := n.parent() {
		if !parent.in_editable_subtree_ {
			return false
		}
	} else {
		return false
	}
	// When a node is inert, if it is editable, the node behaves as if it were non-editable.
	if n.is_inert() {
		return false
	}
	return true
}

// https://html.spec.whatwg.org/multipage/interaction.html#editing-host
pub fn (n &Node) is_editing_host() bool {
	if element := n.as_element() {
		if state := element.get_attribute('contenteditable') {
			if state == '' || state == 'true' || state == 'plaintext-only' {
				return true
			}
		}
	}
	if parent := n.parent() {
		if parent.is_document() {
			doc := parent.document()
			return doc != unsafe { nil } && doc.design_mode_enabled_state()
		}
	}
	return false
}

pub fn (n &Node) is_editable_or_editing_host() bool {
	return n.is_editable() || n.is_editing_host()
}

// https://w3c.github.io/editing/docs/execCommand/#editing-host-of
pub fn (n &Node) editing_host() ?&Node {
	// node itself, if node is an editing host;
	if n.is_editing_host() {
		return n
	}
	// or the nearest ancestor of node that is an editing host, if node is editable.
	if n.is_editable() {
		for ancestor := n.parent(); ancestor != none; {
			current := ancestor or { break }
			if current.is_editing_host() {
				return current
			}
			ancestor = current.parent()
		}
	}
	// The editing host of node is null if node is neither editable nor an editing host.
	return none
}

pub fn (mut n Node) set_layout_node(layout_node &LayoutNode) {
	n.layout_node_ = layout_node
}

pub fn (mut n Node) detach_layout_node() {
	n.layout_node_ = unsafe { nil }
}

pub fn (n &Node) get_parent(event &Event) ?&EventTarget {
	_ = event
	// A node's get the parent algorithm, given an event, returns the node's assigned slot, if node is assigned;
	// otherwise node's parent.
	if assigned_slot := assigned_slot_for_node(n) {
		return unsafe { &EventTarget(assigned_slot) }
	}
	if parent := n.parent() {
		return unsafe { &EventTarget(parent) }
	}
	return none
}

pub fn (mut n Node) set_needs_layout_tree_update(value bool, reason SetNeedsLayoutTreeUpdateReason) {
	if n.needs_layout_tree_update == value {
		return
	}
	n.needs_layout_tree_update = value
	if n.needs_layout_tree_update {
		for ancestor := n.flat_tree_parent(); ancestor != none; {
			mut current := unsafe { &Node(ancestor or { break }) }
			if current.child_needs_layout_tree_update {
				break
			}
			current.child_needs_layout_tree_update = true
			ancestor = current.flat_tree_parent()
		}
		if layout_node := n.unsafe_layout_node() {
			mut mutable_layout_node := unsafe { &LayoutNode(layout_node) }
			mutable_layout_node.set_needs_layout_update(.layout_tree_update)
		}
	}
	_ = reason
}

pub fn (n &Node) needs_layout_tree_update_() bool {
	return n.needs_layout_tree_update
}

pub fn (n &Node) child_needs_layout_tree_update_() bool {
	return n.child_needs_layout_tree_update
}

pub fn (mut n Node) set_child_needs_layout_tree_update(value bool) {
	n.child_needs_layout_tree_update = value
}

pub fn (n &Node) needs_style_update() bool {
	return n.needs_style_update_
}

pub fn (mut n Node) set_needs_style_update(value bool) {
	if n.needs_style_update_ == value {
		return
	}
	n.needs_style_update_ = value
	if n.needs_style_update_ {
		for ancestor := n.parent_or_shadow_host(); ancestor != none; {
			mut current := unsafe { &Node(ancestor or { break }) }
			if current.child_needs_style_update_ {
				break
			}
			current.child_needs_style_update_ = true
			ancestor = current.parent_or_shadow_host()
		}
	}
}

pub fn (mut n Node) set_needs_style_update_internal(value bool) {
	_ = value
	n.needs_style_update_ = true
}

pub fn (n &Node) child_needs_style_update() bool {
	return n.child_needs_style_update_
}

pub fn (mut n Node) set_child_needs_style_update(value bool) {
	n.child_needs_style_update_ = value
}

pub fn (n &Node) entire_subtree_needs_style_update() bool {
	return n.entire_subtree_needs_style_update_
}

pub fn (mut n Node) set_entire_subtree_needs_style_update(value bool) {
	n.entire_subtree_needs_style_update_ = value
}

pub fn (mut n Node) post_connection() {}

pub fn (mut n Node) inserted() {
	if element := n.as_element() {
		mut mutable_element := unsafe { &Element(element) }
		mutable_element.inserted()
		return
	}
	n.recompute_editable_subtree_flag()
	n.set_needs_style_update(true)
}

pub fn (mut n Node) removed_from(old_parent ?&Node, old_root &Node) {
	if element := n.as_element() {
		mut mutable_element := unsafe { &Element(element) }
		mutable_element.removed_from(old_parent, old_root)
		return
	}
	_ = old_parent
	_ = old_root
	n.in_editable_subtree_ = false
	n.layout_node_ = unsafe { nil }
	n.paintable_ = unsafe { nil }
}

// https://dom.spec.whatwg.org/#concept-node-move-ext
pub fn (mut n Node) moved_from(old_parent ?&Node) {
	if element := n.as_element() {
		mut mutable_element := unsafe { &Element(element) }
		mutable_element.moved_from(old_parent)
		return
	}
	_ = old_parent
	n.recompute_editable_subtree_flag()
}

pub fn (mut n Node) adopted_from(old_document &Document) {
	_ = old_document
	n.recompute_editable_subtree_flag()
}

pub fn (n &Node) parent_or_shadow_host() ?&Node {
	if shadow_root := n.as_shadow_root() {
		if shadow_root.host_ != unsafe { nil } {
			return shadow_root.host_.as_node()
		}
	}
	return n.parent()
}

pub fn (n &Node) parent_or_shadow_host_node() ?&Node {
	return n.parent_or_shadow_host()
}

pub fn (n &Node) parent_or_shadow_host_element() ?&Element {
	if shadow_root := n.as_shadow_root() {
		if shadow_root.host_ != unsafe { nil } {
			return shadow_root.host_
		}
	}
	if parent := n.parent() {
		if element := parent.as_element() {
			return element
		}
		if parent_shadow := parent.as_shadow_root() {
			if parent_shadow.host_ != unsafe { nil } {
				return parent_shadow.host_
			}
		}
	}
	return none
}

pub fn (n &Node) flat_tree_parent() ?&Node {
	// If we're assigned to a slot, that slot is our flat tree parent.
	// Otherwise, this is the parent or shadow host.
	return n.parent_or_shadow_host()
}

pub fn (n &Node) flat_tree_parent_element() ?&Element {
	for parent := n.flat_tree_parent(); parent != none; {
		current := parent or { break }
		if element := current.as_element() {
			return element
		}
		parent = current.flat_tree_parent()
	}
	return none
}

pub fn (n &Node) as_slottable() &Node {
	return n
}

pub fn (mut n Node) child_nodes() &NodeList {
	if n.child_nodes_ == unsafe { nil } {
		n.child_nodes_ = &NodeList{
			node_root:   n
			is_live:     true
			live_scope:  .children
			live_filter: always_accept_node
		}
	}
	return n.child_nodes_
}

pub fn (n &Node) children_as_vector() []&Node {
	return n.children.clone()
}

pub fn (mut n Node) remove_all_children(suppress_observers bool) {
	for n.children.len > 0 {
		child := n.children[0]
		mut mutable_child := unsafe { &Node(child) }
		mutable_child.remove(suppress_observers)
	}
}

// https://dom.spec.whatwg.org/#dom-node-comparedocumentposition
pub fn (n &Node) compare_document_position(other ?&Node) u16 {
	other_node := other or {
		return document_position_disconnected | document_position_implementation_specific | document_position_following
	}

	if n == other_node {
		return document_position_equal
	}
	node1 := other_node
	node2 := n
	if node1.root() != node2.root() {
		return document_position_disconnected | document_position_implementation_specific | document_position_following
	}
	mut node1_ancestors := []&Node{}
	for current := ?&Node(node1); current != none; {
		node := current or { break }
		node1_ancestors << node
		current = node.parent()
	}
	mut node2_ancestors := []&Node{}
	for current := ?&Node(node2); current != none; {
		node := current or { break }
		node2_ancestors << node
		current = node.parent()
	}
	mut i := node1_ancestors.len - 1
	mut j := node2_ancestors.len - 1
	for i >= 0 && j >= 0 {
		ancestor1 := node1_ancestors[i]
		ancestor2 := node2_ancestors[j]
		if ancestor1 != ancestor2 {
			for sibling := ?&Node(ancestor1); sibling != none; {
				node := sibling or { break }
				if node == ancestor2 {
					return document_position_preceding
				}
				sibling = node.next_sibling()
			}
			return document_position_following
		}
		i--
		j--
	}
	if node1_ancestors.len < node2_ancestors.len {
		return document_position_contains | document_position_preceding
	}
	if node1_ancestors.len > node2_ancestors.len {
		return document_position_contained_by | document_position_following
	}
	return document_position_following
}

// https://dom.spec.whatwg.org/#concept-tree-host-including-inclusive-ancestor
pub fn (n &Node) is_host_including_inclusive_ancestor_of(other &Node) bool {
	// An object A is a host-including inclusive ancestor of an object B,
	// if either A is an inclusive ancestor of B,
	if n.is_inclusive_ancestor_of(other) {
		return true
	}
	// or if B's root has a non-null host and A is a host-including inclusive ancestor of B's root's host.
	if fragment := other.root().as_document_fragment() {
		if fragment.host_ != unsafe { nil } {
			return n.is_host_including_inclusive_ancestor_of(fragment.host_.as_node())
		}
	}
	return false
}

// This function tells us whether a node is interesting enough to show up
// in the DOM inspector. This hides two things:
// - Non-rendered whitespace
// - Rendered whitespace between block-level elements
pub fn (n &Node) is_uninteresting_whitespace_node() bool {
	if !n.is_text() {
		return false
	}
	content := n.text_content() or { return false }
	if content.trim_space().len != 0 {
		return false
	}
	if n.layout_node() == none {
		return true
	}
	return false
}

pub fn (n &Node) serialize_child_as_json(mut children_array strings.Builder, child &Node) TraversalDecision {
	if child.is_uninteresting_whitespace_node() {
		return .@continue
	}
	child.serialize_tree_as_json(mut children_array)
	return .@continue
}

pub fn (n &Node) serialize_tree_as_json(mut object strings.Builder) {
	object.write_string('{"name":"${n.node_name()}","id":${n.unique_id_.value()}')
	if n.is_document() {
		object.write_string(',"type":"document"')
	} else if n.is_element() {
		object.write_string(',"type":"element"')
	} else if n.is_text() {
		object.write_string(',"type":"text"')
		if text := n.text_content() {
			object.write_string(',"text":"${text}"')
		}
	} else if n.is_comment() {
		object.write_string(',"type":"comment"')
		if data := n.node_value() {
			object.write_string(',"data":"${data}"')
		}
	} else if n.is_shadow_root() {
		object.write_string(',"type":"shadow-root"')
	}
	object.write_string(',"visible":${n.layout_node() != none}')
	if n.children.len > 0 {
		object.write_string(',"children":[')
		for i, child in n.children {
			if i > 0 {
				object.write_string(',')
			}
			child.serialize_tree_as_json(mut object)
		}
		object.write_string(']')
	}
	object.write_string('}')
}

// https://html.spec.whatwg.org/multipage/webappapis.html#concept-n-script
pub fn (n &Node) is_scripting_enabled() bool {
	// Scripting is enabled for a node node if node's node document's browsing context is non-null,
	// and scripting is enabled for node's relevant realm.
	doc := n.document()
	return doc != unsafe { nil } && doc.browsing_context != unsafe { nil }
}

// https://html.spec.whatwg.org/multipage/webappapis.html#concept-n-noscript
pub fn (n &Node) is_scripting_disabled() bool {
	// Scripting is disabled for a node when scripting is not enabled.
	return !n.is_scripting_enabled()
}

// https://dom.spec.whatwg.org/#concept-shadow-including-descendant
pub fn (n &Node) is_shadow_including_descendant_of(other &Node) bool {
	if n.is_descendant_of(other) {
		return true
	}
	if shadow_root := n.root().as_shadow_root() {
		if shadow_root.host_ != unsafe { nil } {
			return shadow_root.host_.as_node().is_shadow_including_inclusive_descendant_of(other)
		}
	}
	return false
}

// https://dom.spec.whatwg.org/#concept-shadow-including-inclusive-descendant
pub fn (n &Node) is_shadow_including_inclusive_descendant_of(other &Node) bool {
	// A shadow-including inclusive descendant is an object or one of its shadow-including descendants.
	return other == n || n.is_shadow_including_descendant_of(other)
}

// https://dom.spec.whatwg.org/#concept-shadow-including-ancestor
pub fn (n &Node) is_shadow_including_ancestor_of(other &Node) bool {
	// An object A is a shadow-including ancestor of an object B, if and only if B is a shadow-including descendant of A.
	return other.is_shadow_including_descendant_of(n)
}

// https://dom.spec.whatwg.org/#concept-shadow-including-inclusive-ancestor
pub fn (n &Node) is_shadow_including_inclusive_ancestor_of(other &Node) bool {
	// A shadow-including inclusive ancestor is an object or one of its shadow-including ancestors.
	return other.is_shadow_including_inclusive_descendant_of(n)
}

// https://dom.spec.whatwg.org/#concept-node-replace-all
pub fn (mut n Node) replace_all(node ?&Node) {
	// 1. Let removedNodes be parent's children.
	removed_nodes := n.children_as_vector()
	mut added_nodes := []&Node{}
	if new_node := node {
		if new_node.is_document_fragment() {
			added_nodes = new_node.children_as_vector()
		} else {
			added_nodes << new_node
		}
	}
	n.remove_all_children(true)
	if new_node := node {
		n.insert_before(new_node, none, true)
	}
	if added_nodes.len > 0 || removed_nodes.len > 0 {
		n.queue_tree_mutation_record(added_nodes, removed_nodes, unsafe { nil }, unsafe { nil })
	}
}

// https://dom.spec.whatwg.org/#string-replace-all
pub fn (mut n Node) string_replace_all(string_ string) {
	// 1. Let node be null.
	mut node := ?&Node(none)
	// 2. If string is not the empty string, then set node to a new Text node whose data is string and node document is parent's node document.
	if string_.len > 0 {
		text := new_text_node(n.document(), string_)
		node = text.as_node()
	}
	// 3. Replace all with node within parent.
	n.replace_all(node)
}

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#fragment-serializing-algorithm-steps
pub fn (n &Node) serialize_fragment(require_well_formed RequireWellFormed, fragment_serialization_mode FragmentSerializationMode) !string {
	_ = require_well_formed
	// 1. Let context document be the value of node's node document.
	// 2. If context document is an HTML document, return the result of HTML fragment serialization algorithm.
	// 3. Return the XML serialization of node given require well-formed.
	if fragment_serialization_mode == .inner {
		mut builder := strings.new_builder(0)
		for child in n.children {
			builder.write_string(child.serialize_fragment(require_well_formed, .outer)!)
		}
		return builder.str()
	}
	return n.text_content() or { '' }
}

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#unsafely-set-html
pub fn (mut n Node) unsafely_set_html(context_element &Element, html string) ! {
	_ = html
	// 1. Let newChildren be the result of the HTML fragment parsing algorithm given contextElement, html, and true.
	// 2. Let fragment be a new DocumentFragment whose node document is contextElement's node document.
	fragment := new_document_fragment(context_element.document())
	// 3. For each node in newChildren, append node to fragment.
	// 4. Replace all with fragment within contextElement.
	n.replace_all(fragment.as_node())
}

// https://dom.spec.whatwg.org/#dom-node-issamenode
pub fn (n &Node) is_same_node(other_node ?&Node) bool {
	// The isSameNode(otherNode) method steps are to return true if otherNode is this; otherwise false.
	return if other := other_node { n == other } else { false }
}

// https://dom.spec.whatwg.org/#dom-node-isequalnode
pub fn (n &Node) is_equal_node(other_node ?&Node) bool {
	// The isEqualNode(otherNode) method steps are to return true if otherNode is non-null and this equals otherNode; otherwise false.
	other := other_node or { return false }
	if n == other {
		return true
	}
	if n.node_type != other.node_type {
		return false
	}
	if n.node_name().to_lower() != other.node_name().to_lower() {
		return false
	}

	// The following are equal, switching on the interface A implements:
	if document_type := n.as_document_type() {
		other_document_type := other.as_document_type() or { return false }
		if document_type.name() != other_document_type.name()
			|| document_type.public_id() != other_document_type.public_id()
			|| document_type.system_id() != other_document_type.system_id() {
			return false
		}
	} else if element := n.as_element() {
		other_element := other.as_element() or { return false }
		if element.namespace_uri() != other_element.namespace_uri()
			|| element.prefix() != other_element.prefix()
			|| element.local_name() != other_element.local_name()
			|| element.attribute_list_size() != other_element.attribute_list_size() {
			return false
		}
		if attrs := element.attributes_ {
			for attribute in attrs.attrs {
				other_attribute := other_element.get_attribute_node_ns(attribute.namespace_uri_,
					attribute.local_name_) or {
					return false
				}
				if other_attribute.value() != attribute.value() {
					return false
				}
			}
		}
	} else if character_data := n.character_data() {
		other_character_data := other.character_data() or { return false }
		if character_data.data() != other_character_data.data() {
			return false
		}
	} else if attr := n.as_attr() {
		other_attr := other.as_attr() or { return false }
		if attr.namespace_uri() != other_attr.namespace_uri()
			|| attr.local_name() != other_attr.local_name()
			|| attr.value() != other_attr.value() {
			return false
		}
	} else if processing_instruction := n.as_processing_instruction() {
		other_processing_instruction := other.as_processing_instruction() or { return false }
		if processing_instruction.target() != other_processing_instruction.target()
			|| processing_instruction.data() != other_processing_instruction.data() {
			return false
		}
	}

	if n.child_count() != other.child_count() {
		return false
	}
	for i, child in n.children {
		if !child.is_equal_node(other.children[i]) {
			return false
		}
	}
	return true
}

pub fn (n &Node) get_in_scope_prefixes() []string {
	// https://html.spec.whatwg.org/multipage/xhtml.html#parsing-xhtml-fragments
	// "A namespace prefix is in scope if the DOM lookupNamespaceURI() method on the element would return a non-null value for that prefix."
	mut prefixes := []string{}
	mut seen_prefixes := []string{}
	add_in_scope_prefix(mut prefixes, mut seen_prefixes, 'xml')
	add_in_scope_prefix(mut prefixes, mut seen_prefixes, 'xmlns')

	mut current := ?&Element(none)
	if element := n.as_element() {
		current = unsafe { &Element(element) }
	} else if n.is_document() {
		doc := n.document()
		if doc != unsafe { nil } {
			current = doc.document_element()
		}
	} else if attr := n.as_attr() {
		if owner := attr.owner_element() {
			current = unsafe { &Element(owner) }
		}
	} else {
		current = n.parent_element()
	}

	for current != none {
		element := current or { break }
		if element.namespace_uri() != none {
			prefix := element.prefix() or { '' }
			add_in_scope_prefix(mut prefixes, mut seen_prefixes, prefix)
		}
		if attrs := element.attributes_ {
			for attr in attrs.attrs {
				if attr.namespace_uri_ or { '' } != namespace_xmlns_uri {
					continue
				}
				declared_prefix := if attr.prefix__ == none && attr.local_name_ == 'xmlns' {
					''
				} else if attr.prefix__ or { '' } == 'xmlns' {
					attr.local_name_
				} else {
					continue
				}
				if attr.value().len > 0 {
					add_in_scope_prefix(mut prefixes, mut seen_prefixes, declared_prefix)
				} else if declared_prefix !in seen_prefixes {
					seen_prefixes << declared_prefix
				}
			}
		}
		current = element.as_node().parent_element()
	}
	return prefixes
}

fn add_in_scope_prefix(mut prefixes []string, mut seen_prefixes []string, prefix string) {
	if prefix !in seen_prefixes {
		prefixes << prefix
		seen_prefixes << prefix
	}
}

// https://dom.spec.whatwg.org/#locate-a-namespace
pub fn (n &Node) locate_a_namespace(prefix ?string) ?string {
	if p := prefix {
		if p == 'xml' {
			return namespace_xml_uri
		}
		if p == 'xmlns' {
			return namespace_xmlns_uri
		}
	}
	if element := n.as_element() {
		if ns := element.namespace_uri() {
			if element.prefix() == prefix {
				return ns
			}
		}
		if attrs := element.attributes_ {
			for attr in attrs.attrs {
				if attr.namespace_uri_ or { '' } == namespace_xmlns_uri {
					if (attr.prefix__ or { '' }) == 'xmlns' && prefix != none
						&& attr.local_name_ == (prefix or { '' }) {
						if attr.value().len > 0 {
							return attr.value()
						}
						return none
					}
					if prefix == none && attr.prefix__ == none && attr.local_name_ == 'xmlns' {
						if attr.value().len > 0 {
							return attr.value()
						}
						return none
					}
				}
			}
		}
		if parent := element.as_node().parent_element() {
			return parent.as_node().locate_a_namespace(prefix)
		}
		return none
	}
	if n.is_document() {
		doc := n.document()
		if doc != unsafe { nil } {
			if element := doc.document_element() {
				return element.as_node().locate_a_namespace(prefix)
			}
		}
		return none
	}
	if attr := n.as_attr() {
		if attr.owner_element_ != unsafe { nil } {
			return attr.owner_element_.as_node().locate_a_namespace(prefix)
		}
		return none
	}
	if parent := n.parent_element() {
		return parent.as_node().locate_a_namespace(prefix)
	}
	return none
}

// https://dom.spec.whatwg.org/#dom-node-lookupnamespaceuri
pub fn (n &Node) lookup_namespace_uri(prefix ?string) ?string {
	// 1. If prefix is the empty string, then set it to null.
	actual_prefix := if p := prefix {
		if p.len == 0 { none } else { prefix }
	} else {
		none
	}
	// 2. Return the result of running locate a namespace for this using prefix.
	return n.locate_a_namespace(actual_prefix)
}

// https://dom.spec.whatwg.org/#dom-node-lookupprefix
pub fn (n &Node) lookup_prefix(namespace_ ?string) ?string {
	// 1. If namespace is null or the empty string, then return null.
	ns := namespace_ or { return none }
	if ns.len == 0 {
		return none
	}
	if element := n.as_element() {
		return element.locate_a_namespace_prefix(namespace_)
	}
	if n.is_document() {
		doc := n.document()
		if doc != unsafe { nil } {
			if element := doc.document_element() {
				return element.locate_a_namespace_prefix(namespace_)
			}
		}
	}
	if attr := n.as_attr() {
		if attr.owner_element_ != unsafe { nil } {
			return attr.owner_element_.locate_a_namespace_prefix(namespace_)
		}
	}
	if parent := n.parent_element() {
		return parent.locate_a_namespace_prefix(namespace_)
	}
	return none
}

// https://dom.spec.whatwg.org/#dom-node-isdefaultnamespace
pub fn (n &Node) is_default_namespace(namespace_ ?string) bool {
	// 1. If namespace is the empty string, then set it to null.
	actual_namespace := if ns := namespace_ {
		if ns.len == 0 { none } else { namespace_ }
	} else {
		none
	}
	// 2. Let defaultNamespace be the result of running locate a namespace for this using null.
	default_namespace := n.locate_a_namespace(none)
	// 3. Return true if defaultNamespace is the same as namespace; otherwise false.
	return default_namespace == actual_namespace
}

pub fn (n &Node) is_inert() bool {
	if element := n.as_element() {
		if element.has_attribute('inert') {
			return true
		}
	}
	if enclosing := n.enclosing_html_element() {
		return enclosing.has_attribute('inert')
	}
	return false
}

// https://dom.spec.whatwg.org/#in-a-document-tree
pub fn (n &Node) in_a_document_tree() bool {
	// An element is in a document tree if its root is a document.
	return n.root().is_document()
}

// https://dom.spec.whatwg.org/#dom-node-getrootnode
pub fn (n &Node) get_root_node(options GetRootNodeOptions) &Node {
	// The getRootNode(options) method steps are to return this's shadow-including root if options["composed"] is true;
	if options.composed {
		return n.shadow_including_root()
	}
	// otherwise this's root.
	return n.root()
}

pub fn (n &Node) debug_description() string {
	mut builder := strings.new_builder(0)
	builder.write_string(n.node_name().to_lower())
	if element := n.as_element() {
		if id := element.id() {
			builder.write_string('#${id}')
		}
		for class_name in element.classes {
			builder.write_string('.${class_name}')
		}
	}
	return builder.str()
}

// https://dom.spec.whatwg.org/#concept-node-length
pub fn (n &Node) length() int {
	// 1. If node is a DocumentType or Attr node, then return 0.
	if n.is_document_type() || n.is_attribute() {
		return 0
	}
	// 2. If node is a CharacterData node, then return node's data's length.
	if character_data := n.character_data() {
		return character_data.length_in_utf16_code_units()
	}
	// 3. Return the number of node's children.
	return n.child_count()
}

pub fn (n &Node) layout_node() ?&LayoutNode {
	if n.layout_node_ == unsafe { nil } {
		return none
	}
	return n.layout_node_
}

pub fn (n &Node) unsafe_layout_node() ?&LayoutNode {
	return n.layout_node()
}

pub fn (mut n Node) set_paintable(paintable ?&Paintable) {
	n.paintable_ = paintable or { unsafe { nil } }
}

pub fn (mut n Node) clear_paintable() {
	n.paintable_ = unsafe { nil }
}

pub fn (mut n Node) set_needs_repaint(should_invalidate_display_list InvalidateDisplayList) {
	if mut layout_node := n.unsafe_layout_node() {
		layout_node.set_needs_repaint(should_invalidate_display_list)
	}
}

pub fn (mut n Node) set_needs_layout_update(reason SetNeedsLayoutReason) {
	if mut node := n.unsafe_layout_node() {
		node.set_needs_layout_update(reason)
	}
}

pub fn (n &Node) paintable() ?&Paintable {
	if n.paintable_ == unsafe { nil } {
		return none
	}
	return n.paintable_
}

pub fn (n &Node) unsafe_paintable() ?&Paintable {
	return n.paintable()
}

pub fn (n &Node) paintable_box() ?&PaintableBox {
	if paintable := n.paintable() {
		if paintable.is_paintable_box() {
			return unsafe { &PaintableBox(paintable) }
		}
	}
	return none
}

pub fn (n &Node) unsafe_paintable_box() ?&PaintableBox {
	return n.paintable_box()
}

// https://dom.spec.whatwg.org/#queue-a-mutation-record
pub fn (mut n Node) queue_mutation_record(type_ MutationType, attribute_name ?string, attribute_namespace ?string, old_value ?string, added_nodes []&Node, removed_nodes []&Node, previous_sibling &Node, next_sibling &Node) {
	target := unsafe { &Node(&n) }
	mut interested_observers := []&MutationObserver{}
	mut current := ?&Node(target)
	for current != none {
		node := current or { break }
		for registered_observer in node.registered_observer_list_ {
			options := registered_observer.options()
			if node != target && !options.subtree {
				continue
			}
			mut record_old_value := ?string(none)
			match type_ {
				.attributes {
					if !(options.attributes or { false }) {
						continue
					}
					if attribute_filter := options.attribute_filter {
						name := attribute_name or { '' }
						if name !in attribute_filter {
							continue
						}
					}
					if options.attribute_old_value or { false } {
						record_old_value = old_value
					}
				}
				.character_data {
					if !(options.character_data or { false }) {
						continue
					}
					if options.character_data_old_value or { false } {
						record_old_value = old_value
					}
				}
				.child_list {
					if !options.child_list {
						continue
					}
				}
			}
			observer := registered_observer.observer()
			if observer !in interested_observers {
				interested_observers << observer
			} else {
				continue
			}
			record := MutationRecord.create(mutation_type_to_string(type_), target, added_nodes,
				removed_nodes, previous_sibling, next_sibling, attribute_name,
				attribute_namespace, record_old_value)
			mut mutable_observer := unsafe { &MutationObserver(observer) }
			mutable_observer.enqueue_record(record)
		}
		current = node.parent()
	}
}

// https://dom.spec.whatwg.org/#queue-a-tree-mutation-record
pub fn (mut n Node) queue_tree_mutation_record(added_nodes []&Node, removed_nodes []&Node, previous_sibling &Node, next_sibling &Node) {
	// 1. Assert: either addedNodes or removedNodes is not empty.
	if added_nodes.len == 0 && removed_nodes.len == 0 {
		return
	}
	// 2. Queue a mutation record of "childList" for target with null, null, null, addedNodes, removedNodes, previousSibling, and nextSibling.
	n.queue_mutation_record(.child_list, none, none, none, added_nodes, removed_nodes,
		previous_sibling, next_sibling)
}

pub fn (mut n Node) append_child_impl(node &Node) {
	if !n.is_child_allowed(node) {
		return
	}
	mut mutable_node := unsafe { &Node(node) }
	mutable_node.parent_ = n
	n.children << node
}

pub fn (mut n Node) insert_before_impl(node &Node, child ?&Node) {
	child_node := child or {
		n.append_child_impl(node)
		return
	}

	mut index := n.children.len
	for i, existing in n.children {
		if existing == child_node {
			index = i
			break
		}
	}
	mut mutable_node := unsafe { &Node(node) }
	mutable_node.parent_ = n
	n.children.insert(index, node)
}

pub fn (mut n Node) remove_child_impl(node &Node) {
	n.children = n.children.filter(it != node)
	mut mutable_node := unsafe { &Node(node) }
	mutable_node.parent_ = unsafe { nil }
}

pub fn (n &Node) is_child_allowed(node &Node) bool {
	_ = node
	return true
}

pub fn (mut n Node) children_changed(metadata ChildrenChangedMetadata) {
	if element := n.as_element() {
		mut mutable_element := unsafe { &Element(element) }
		mutable_element.children_changed(metadata)
		return
	}
	_ = metadata
}

pub fn (n &Node) cloned(copy &Node, subtree bool) ! {
	_ = copy
	_ = subtree
}

pub fn (n &Node) build_accessibility_tree(mut parent AccessibilityTreeNode) {
	if n.is_uninteresting_whitespace_node() {
		return
	}
	if n.is_document() {
		document := unsafe { &Document(n) }
		if document_element := document.document_element() {
			if document_element.include_in_accessibility_tree() {
				parent.set_value(document_element.as_node())
				for child in document_element.as_node().children {
					child.build_accessibility_tree(mut parent)
				}
			}
		}
		return
	}
	if element := n.as_element() {
		if element.local_name() in ['script', 'style'] {
			return
		}
		if element.include_in_accessibility_tree() {
			current_node := AccessibilityTreeNode.create(n.document(), n)
			parent.append_child(current_node)
			if n.has_child_nodes() {
				mut mutable_current := unsafe { &AccessibilityTreeNode(current_node) }
				for child in n.children {
					child.build_accessibility_tree(mut mutable_current)
				}
			}
		} else if n.has_child_nodes() {
			for child in n.children {
				child.build_accessibility_tree(mut parent)
			}
		}
		return
	}
	if n.is_text() {
		parent.append_child(AccessibilityTreeNode.create(n.document(), n))
		if n.has_child_nodes() {
			for child in n.children {
				child.build_accessibility_tree(mut parent)
			}
		}
	}
}

// https://www.w3.org/TR/accname-1.2/#mapping_additional_nd_te
pub fn (n &Node) name_or_description(target NameOrDescription, document &Document, mut visited_nodes map[UniqueNodeID]bool, is_descendant IsDescendant, should_compute_role ShouldComputeRole) !string {
	_ = target
	_ = document
	_ = is_descendant
	_ = should_compute_role
	// The text alternative for a given element is computed by the Accessible Name and Description Computation.
	// The host-language and ARIA-specific branches live in the element/html/svg ports; preserve cycle protection here.
	if visited_nodes[n.unique_id_] {
		return ''
	}
	visited_nodes[n.unique_id_] = true
	return n.text_content() or { '' }
}

// https://www.w3.org/TR/accname-1.2/#mapping_additional_nd_name
pub fn (n &Node) accessible_name(document &Document, should_compute_role ShouldComputeRole) !string {
	mut visited_nodes := map[UniqueNodeID]bool{}
	// User agents MUST compute an accessible name using the rules outlined below in the section titled Accessible Name and Description Computation.
	return n.name_or_description(.name, document, mut visited_nodes, .no, should_compute_role)
}

// https://www.w3.org/TR/accname-1.2/#mapping_additional_nd_description
pub fn (n &Node) accessible_description(document &Document) !string {
	if !n.is_element() {
		return ''
	}
	mut visited_nodes := map[UniqueNodeID]bool{}
	return n.name_or_description(.description, document, mut visited_nodes, .no, .yes)
}

pub fn Node.first_valid_id(value string, document &Document) ?string {
	for id in value.fields() {
		if document.get_element_by_id(id) != none {
			return id
		}
	}
	return none
}

pub fn (mut n Node) add_registered_observer(registered_observer &RegisteredObserver) {
	n.registered_observer_list_ << registered_observer
}

pub fn (n &Node) has_inclusive_ancestor_with_display_none() bool {
	for ancestor := ?&Node(n); ancestor != none; {
		current := ancestor or { break }
		if element := current.as_element() {
			if props := element.el_computed_properties() {
				if props.display().is_none() {
					return true
				}
			}
		}
		ancestor = current.parent_or_shadow_host()
	}
	return false
}

pub fn (n &Node) has_inclusive_ancestor_with_event_listener(type_ string) bool {
	for ancestor := ?&Node(n); ancestor != none; {
		current := ancestor or { break }
		if current.has_event_listener(type_) {
			return true
		}
		ancestor = current.parent_or_shadow_host()
	}
	return false
}

pub fn (n &Node) containing_shadow_root() ?&ShadowRoot {
	if shadow_root := n.as_shadow_root() {
		if shadow_root.host_ != unsafe { nil } {
			return shadow_root.host_.as_node().containing_shadow_root()
		}
	}
	if shadow_root := n.root().as_shadow_root() {
		return shadow_root
	}
	return none
}

pub fn encode_unique_node_id(value UniqueNodeID) i64 {
	return value.value()
}

pub fn decode_unique_node_id(value i64) UniqueNodeID {
	return UniqueNodeID(value)
}

pub fn (n &Node) node_name() string {
	return match n.node_type {
		.invalid {
			'#invalid'
		}
		.element_node {
			if element := n.as_element() {
				element.node_name()
			} else {
				'#element'
			}
		}
		.attribute_node {
			if attr := n.as_attr() {
				attr.name_
			} else {
				'#attribute'
			}
		}
		.text_node {
			'#text'
		}
		.cdata_section_node {
			'#cdata-section'
		}
		.entity_reference_node {
			'#entity-reference'
		}
		.entity_node {
			'#entity'
		}
		.processing_instruction_node {
			if pi := n.as_processing_instruction() {
				pi.target_
			} else {
				'#processing-instruction'
			}
		}
		.comment_node {
			'#comment'
		}
		.document_node {
			'#document'
		}
		.document_type_node {
			if dt := n.as_document_type() {
				dt.name_
			} else {
				'#document-type'
			}
		}
		.document_fragment_node {
			'#document-fragment'
		}
		.notation_node {
			'#notation'
		}
	}
}

pub fn (n &Node) parent_element() ?&Element {
	parent := n.parent() or { return none }
	return parent.as_element()
}

pub fn (n &Node) is_link_element() bool {
	if element := n.as_element() {
		return (element.local_name() == 'a' || element.local_name() == 'area')
			&& element.has_attribute('href')
	}
	return false
}

pub fn (n &Node) is_iframe_element() bool {
	if element := n.as_element() {
		return element.local_name() == 'iframe'
	}
	return false
}

pub fn (n &Node) has_loaded_icon() bool {
	return false
}

pub fn (n &Node) in_editable_subtree() bool {
	return n.in_editable_subtree_
}

pub fn (n &Node) for_each_child(callback fn (&Node) TraversalDecision) TraversalDecision {
	for child in n.children {
		if callback(child) == .@break {
			return .@break
		}
	}
	return .@continue
}

pub fn (n &Node) for_each_in_subtree(callback fn (&Node) TraversalDecision) TraversalDecision {
	for child in n.children {
		if callback(child) == .@break {
			return .@break
		}
		if child.for_each_in_subtree(callback) == .@break {
			return .@break
		}
	}
	return .@continue
}

pub fn (n &Node) for_each_in_inclusive_subtree(callback fn (&Node) TraversalDecision) TraversalDecision {
	if callback(n) == .@break {
		return .@break
	}
	return n.for_each_in_subtree(callback)
}

// https://dom.spec.whatwg.org/#concept-shadow-including-inclusive-descendant
pub fn (n &Node) for_each_shadow_including_inclusive_descendant(callback fn (&Node) TraversalDecision) TraversalDecision {
	if callback(n) == .@break {
		return .@break
	}
	return n.for_each_shadow_including_descendant(callback)
}

// https://dom.spec.whatwg.org/#concept-shadow-including-descendant
pub fn (n &Node) for_each_shadow_including_descendant(callback fn (&Node) TraversalDecision) TraversalDecision {
	if element := n.as_element() {
		if shadow_root := element.shadow_root() {
			shadow_root_node := unsafe { &Node(shadow_root) }
			if shadow_root_node.for_each_shadow_including_inclusive_descendant(callback) == .@break {
				return .@break
			}
		}
	}
	for child in n.children {
		if child.for_each_shadow_including_inclusive_descendant(callback) == .@break {
			return .@break
		}
	}
	return .@continue
}

pub fn (n &Node) character_data() ?&CharacterData {
	if !n.is_character_data() {
		return none
	}
	return unsafe { &CharacterData(n) }
}

pub fn (mut n Node) character_data_mut() ?&CharacterData {
	if !n.is_character_data() {
		return none
	}
	return unsafe { &CharacterData(n) }
}

pub fn (mut n Node) attr_mut() ?&Attr {
	if !n.is_attribute() {
		return none
	}
	return unsafe { &Attr(n) }
}

pub fn (n &Node) as_document_type() ?&DocumentType {
	if !n.is_document_type() {
		return none
	}
	return unsafe { &DocumentType(n) }
}

pub fn (n &Node) as_processing_instruction() ?&ProcessingInstruction {
	if n.node_type != .processing_instruction_node {
		return none
	}
	return unsafe { &ProcessingInstruction(n) }
}

pub fn new_text_node(document &Document, data string) &Text {
	return &Text{
		CharacterData: CharacterData{
			Node:  Node{
				node_type:  .text_node
				document_:  document
				unique_id_: UniqueNodeID(0)
			}
			data_: data
		}
	}
}

pub fn new_document_fragment(document &Document) &DocumentFragment {
	return &DocumentFragment{
		ParentNode: ParentNode{
			Node: Node{
				node_type:  .document_fragment_node
				document_:  document
				unique_id_: UniqueNodeID(0)
			}
		}
	}
}

pub fn (c &CharacterData) data() string {
	return c.data_
}

pub fn (mut c CharacterData) set_data(data string) {
	c.replace_data_with_mutation_steps(0, c.length_in_utf16_code_units(), data) or {}
}

pub fn (c &CharacterData) length_in_utf16_code_units() int {
	return utf16_code_unit_length(c.data_)
}

pub fn (mut c CharacterData) replace_data(offset int, count int, data string) ! {
	c.replace_data_with_mutation_steps(offset, count, data)!
}

fn utf16_code_unit_length(value string) int {
	mut length := 0
	for r in value.runes() {
		length += if u32(r) > 0xffff { 2 } else { 1 }
	}
	return length
}

fn byte_index_for_utf16_code_unit_offset(value string, offset int) int {
	if offset <= 0 {
		return 0
	}
	mut code_units := 0
	for byte_index, r in value {
		rune_units := if u32(r) > 0xffff { 2 } else { 1 }
		if code_units >= offset {
			return byte_index
		}
		code_units += rune_units
		if code_units > offset {
			return byte_index + utf8_char_len(r)
		}
	}
	return value.len
}

fn utf8_char_len(r rune) int {
	code_point := u32(r)
	if code_point < 0x80 {
		return 1
	}
	if code_point < 0x800 {
		return 2
	}
	if code_point < 0x10000 {
		return 3
	}
	return 4
}

pub fn (t &Text) data() string {
	return t.CharacterData.data_
}

pub fn (t &Text) length() int {
	return t.CharacterData.length_in_utf16_code_units()
}

pub fn (c &Comment) data() string {
	return c.CharacterData.data_
}

pub fn (pi &ProcessingInstruction) data() string {
	return pi.CharacterData.data_
}

pub fn (pi &ProcessingInstruction) target() string {
	return pi.target_
}

pub fn (mut a Attr) set_value(value string) ! {
	a.value_ = value
}

pub fn (a &Attr) value() string {
	return a.value_
}

pub fn (a &Attr) name() string {
	return a.name_
}

pub fn (a &Attr) local_name() string {
	return a.local_name_
}

pub fn (a &Attr) namespace_uri() ?string {
	return a.namespace_uri_
}

pub fn (a &Attr) prefix() ?string {
	return a.prefix__
}

pub fn (a &Attr) owner_element() ?&Element {
	if a.owner_element_ == unsafe { nil } {
		return none
	}
	return a.owner_element_
}

pub fn (df &DocumentFragment) host() ?&Element {
	if df.host_ == unsafe { nil } {
		return none
	}
	return df.host_
}

pub fn (sr &ShadowRoot) host() ?&Element {
	return sr.DocumentFragment.host()
}

pub fn (sr &ShadowRoot) mode_() ShadowRootMode {
	return sr.mode
}

pub fn (sr &ShadowRoot) clonable() bool {
	return sr.clonable_
}

pub fn (sr &ShadowRoot) serializable() bool {
	return sr.serializable_
}

pub fn (sr &ShadowRoot) delegates_focus() bool {
	return sr.delegates_focus_
}

pub fn (sr &ShadowRoot) slot_assignment() SlotAssignmentMode {
	return sr.slot_assignment_
}

pub fn (mut sr ShadowRoot) set_declarative(declarative bool) {
	sr.declarative = declarative
}

pub fn (mut sr ShadowRoot) register_slot(slot &HTMLSlotElement) {
	if sr.slot_registry_ == unsafe { nil } {
		sr.slot_registry_ = &SlotRegistry{}
	}
	mut registry := unsafe { &SlotRegistry(sr.slot_registry_) }
	registry.add(slot)
}

pub fn (mut sr ShadowRoot) unregister_slot(slot &HTMLSlotElement) {
	if sr.slot_registry_ == unsafe { nil } {
		return
	}
	mut registry := unsafe { &SlotRegistry(sr.slot_registry_) }
	registry.remove(slot)
}

pub fn (sr &ShadowRoot) style_scope() &StyleScope {
	return &sr.style_scope_
}

pub fn (ss &StyleScope) str() string {
	return ''
}

pub fn (ss &StyleScope) may_have_has_selectors() bool {
	return false
}

pub fn (mut ss StyleScope) schedule_ancestors_style_invalidation_due_to_presence_of_has(node &Node) {
	_ = node
}

pub fn (sc &StyleComputer) invalidation_property_used_in_has_selector(property InvalidationProperty, style_scope &StyleScope) bool {
	_ = property
	_ = style_scope
	return false
}

pub fn (sc &StyleComputer) invalidation_plan_for_properties(properties []InvalidationProperty, style_scope &StyleScope) &InvalidationPlan {
	_ = properties
	_ = style_scope
	return &InvalidationPlan{}
}

pub struct InvalidationPlan {}

pub fn (mut si StyleInvalidator) enqueue_invalidation_plan(node &Node, reason StyleInvalidationReason, plan InvalidationPlan) bool {
	_ = node
	_ = reason
	_ = plan
	return false
}

pub fn (mut ln LayoutNode) set_needs_layout_update(reason SetNeedsLayoutReason) {
	_ = reason
}

pub fn (mut ln LayoutNode) set_needs_repaint(should_invalidate_display_list InvalidateDisplayList) {
	_ = should_invalidate_display_list
}
