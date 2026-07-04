// Copyright (c) 2020-2026, the Ladybird developers.
//
// SPDX-License-Identifier: BSD-2-Clause
//
// Translated from:
// - Libraries/LibWeb/DOM/MutationObserver.cpp/.h
// - Libraries/LibWeb/DOM/MutationRecord.cpp/.h
// - Libraries/LibWeb/DOM/MutationType.cpp/.h
// - Libraries/LibWeb/DOM/ShadowRoot.cpp/.h
// - Libraries/LibWeb/DOM/Slot.cpp/.h
// - Libraries/LibWeb/DOM/SlotRegistry.cpp/.h
// - Libraries/LibWeb/DOM/Slottable.cpp/.h
// - Libraries/LibWeb/DOM/StyleInvalidator.cpp/.h
// - Libraries/LibWeb/DOM/StyleElementBase.cpp/.h
// - Libraries/LibWeb/DOM/DOMImplementation.cpp/.h
// - Libraries/LibWeb/DOM/ElementFactory.cpp/.h
// - Libraries/LibWeb/DOM/ElementByIdMap.cpp/.h
// - Libraries/LibWeb/DOM/AccessibilityTreeNode.cpp/.h
// - Libraries/LibWeb/DOM/AdoptedStyleSheets.cpp/.h
// - Libraries/LibWeb/DOM/DocumentLoadEventDelayer.cpp/.h
// - Libraries/LibWeb/DOM/DocumentLoading.cpp/.h
// - Libraries/LibWeb/DOM/DocumentObserver.cpp/.h
// - Libraries/LibWeb/DOM/EditingHostManager.cpp/.h
// - Libraries/LibWeb/DOM/PseudoElement.cpp/.h
// - Libraries/LibWeb/DOM/AbstractElement.cpp/.h
// - Libraries/LibWeb/DOM/Utils.cpp/.h
// - Libraries/LibWeb/DOM/XMLDocument.cpp/.h

module dom

import strings

pub const mutation_type_attributes = 'attributes'
pub const mutation_type_character_data = 'characterData'
pub const mutation_type_child_list = 'childList'

pub fn mutation_type_to_string(type_ MutationType) string {
	return match type_ {
		.attributes { mutation_type_attributes }
		.character_data { mutation_type_character_data }
		.child_list { mutation_type_child_list }
	}
}

pub fn mutation_type_from_string(type_ string) MutationType {
	return match type_ {
		mutation_type_attributes { .attributes }
		mutation_type_character_data { .character_data }
		mutation_type_child_list { .child_list }
		else { .child_list }
	}
}

// https://dom.spec.whatwg.org/#mutationrecord
pub fn MutationRecord.create(type_ string, target &Node, added_nodes []&Node, removed_nodes []&Node, previous_sibling ?&Node, next_sibling ?&Node, attribute_name ?string, attribute_namespace ?string, old_value ?string) &MutationRecord {
	return &MutationRecord{
		type_:               mutation_type_from_string(type_)
		target:              target
		added_nodes:         added_nodes
		removed_nodes:       removed_nodes
		previous_sibling:    previous_sibling or { unsafe { nil } }
		next_sibling:        next_sibling or { unsafe { nil } }
		attribute_name:      attribute_name
		attribute_namespace: attribute_namespace
		old_value:           old_value
	}
}

pub fn (record &MutationRecord) type_() string {
	return mutation_type_to_string(record.type_)
}

pub fn (record &MutationRecord) target_() &Node {
	return record.target
}

pub fn (record &MutationRecord) added_nodes_() []&Node {
	return record.added_nodes
}

pub fn (record &MutationRecord) removed_nodes_() []&Node {
	return record.removed_nodes
}

pub fn (record &MutationRecord) previous_sibling_() ?&Node {
	if record.previous_sibling == unsafe { nil } {
		return none
	}
	return record.previous_sibling
}

pub fn (record &MutationRecord) next_sibling_() ?&Node {
	if record.next_sibling == unsafe { nil } {
		return none
	}
	return record.next_sibling
}

pub fn (record &MutationRecord) attribute_name_() ?string {
	return record.attribute_name
}

pub fn (record &MutationRecord) attribute_namespace_() ?string {
	return record.attribute_namespace
}

pub fn (record &MutationRecord) old_value_() ?string {
	return record.old_value
}

pub fn (mut record MutationRecord) initialize() {}

pub fn (mut record MutationRecord) visit_edges(mut visitor CellVisitor) {
	visitor.visit(record.target)
	for node in record.added_nodes {
		visitor.visit(node)
	}
	for node in record.removed_nodes {
		visitor.visit(node)
	}
	visitor.visit(record.previous_sibling)
	visitor.visit(record.next_sibling)
}

// https://dom.spec.whatwg.org/#dom-mutationobserver-mutationobserver
pub fn MutationObserver.construct_impl(callback ?&CallbackType) !&MutationObserver {
	// The new MutationObserver(callback) constructor steps are to set this's callback to callback.
	return &MutationObserver{
		callback_: callback
	}
}

pub fn (mut observer MutationObserver) initialize() {}

pub fn (mut observer MutationObserver) visit_edges(mut visitor CellVisitor) {
	if callback := observer.callback_ {
		visitor.visit(callback)
	}
	for record in observer.record_queue {
		visitor.visit(record)
	}
	for node in observer.node_list_ {
		visitor.visit(node)
	}
}

// https://dom.spec.whatwg.org/#dom-mutationobserver-observe
pub fn (mut observer MutationObserver) observe(target &Node, mut options MutationObserverOptions) ! {
	// 1. If either options["attributeOldValue"] or options["attributeFilter"] exists, and
	// options["attributes"] does not exist, then set options["attributes"] to true.
	if (options.attribute_old_value != none || options.attribute_filter != none)
		&& options.attributes == none {
		options.attributes = true
	}

	// 2. If options["characterDataOldValue"] exists and options["characterData"] does not exist,
	// then set options["characterData"] to true.
	if options.character_data_old_value != none && options.character_data == none {
		options.character_data = true
	}

	// 3. If none of options["childList"], options["attributes"], and options["characterData"] is true,
	// then throw a TypeError.
	if !options.child_list && !(options.attributes or { false }) && !(options.character_data or {
		false
	}) {
		return error('TypeError: Options must have one of childList, attributes or characterData set to true.')
	}

	// 4. If options["attributeOldValue"] is true and options["attributes"] is false, then throw a TypeError.
	if (options.attribute_old_value or { false }) && !(options.attributes or { false }) {
		return error('TypeError: attributes must be true if attributeOldValue is true.')
	}

	// 5. If options["attributeFilter"] is present and options["attributes"] is false, then throw a TypeError.
	if options.attribute_filter != none && !(options.attributes or { false }) {
		return error('TypeError: attributes must be true if attributeFilter is present.')
	}

	// 6. If options["characterDataOldValue"] is true and options["characterData"] is false, then throw a TypeError.
	if (options.character_data_old_value or { false }) && !(options.character_data or { false }) {
		return error('TypeError: characterData must be true if characterDataOldValue is true.')
	}

	// 7. For each registered of target's registered observer list, if registered's observer is this:
	for registered_observer in target.registered_observer_list_ {
		if registered_observer.observer_ == &observer {
			// 1. For each node of this's node list, remove all transient registered observers whose source is registered
			// from node's registered observer list.
			for node in observer.node_list_ {
				mut mutable_node := unsafe { &Node(node) }
				for i := mutable_node.registered_observer_list_.len - 1; i >= 0; i-- {
					transient_observer := mutable_node.registered_observer_list_[i]
					if transient_observer.is_transient() {
						if source := transient_observer.source() {
							if source == registered_observer {
								mutable_node.registered_observer_list_.delete(i)
							}
						}
					}
				}
			}
			// 2. Set registered's options to options.
			mut mutable_registered_observer := unsafe { &RegisteredObserver(registered_observer) }
			mutable_registered_observer.set_options(options)
			return
		}
	}

	// 8. Otherwise append a new registered observer whose observer is this and options is options.
	mut mutable_target := unsafe { &Node(target) }
	mutable_target.add_registered_observer(RegisteredObserver.create(observer, options))
	observer.node_list_ << target
}

// https://dom.spec.whatwg.org/#dom-mutationobserver-disconnect
pub fn (mut observer MutationObserver) disconnect() {
	// 1. For each node of this's node list, remove any registered observer from node's registered observer list for which this is the observer.
	for node in observer.node_list_ {
		mut mutable_node := unsafe { &Node(node) }
		for i := mutable_node.registered_observer_list_.len - 1; i >= 0; i-- {
			if mutable_node.registered_observer_list_[i].observer_ == &observer {
				mutable_node.registered_observer_list_.delete(i)
			}
		}
	}
	// 2. Empty this's record queue.
	observer.record_queue.clear()
}

// https://dom.spec.whatwg.org/#dom-mutationobserver-takerecords
pub fn (mut observer MutationObserver) take_records() []&MutationRecord {
	// 1. Let records be a clone of this's record queue.
	records := observer.record_queue.clone()
	// 2. Empty this's record queue.
	observer.record_queue.clear()
	// 3. Return records.
	return records
}

pub fn RegisteredObserver.create(observer &MutationObserver, options MutationObserverOptions) &RegisteredObserver {
	return &RegisteredObserver{
		observer_: observer
		options_:  options
	}
}

pub fn (mut registered RegisteredObserver) set_options(options MutationObserverOptions) {
	registered.options_ = options
}

pub fn (registered &RegisteredObserver) is_transient() bool {
	return registered.transient_
}

pub fn (registered &RegisteredObserver) source() ?&RegisteredObserver {
	if registered.source_ == unsafe { nil } {
		return none
	}
	return registered.source_
}

pub fn (mut registered RegisteredObserver) visit_edges(mut visitor CellVisitor) {
	visitor.visit(registered.observer_)
}

pub fn TransientRegisteredObserver.create(observer &MutationObserver, options MutationObserverOptions, source &RegisteredObserver) &TransientRegisteredObserver {
	return &TransientRegisteredObserver{
		RegisteredObserver: RegisteredObserver{
			observer_:  observer
			options_:   options
			transient_: true
			source_:    source
		}
	}
}

pub fn (registered &TransientRegisteredObserver) source() ?&RegisteredObserver {
	return registered.RegisteredObserver.source()
}

pub fn (registered &TransientRegisteredObserver) is_transient() bool {
	_ = registered
	return true
}

pub fn (mut registered TransientRegisteredObserver) visit_edges(mut visitor CellVisitor) {
	registered.RegisteredObserver.visit_edges(mut visitor)
	if source := registered.RegisteredObserver.source() {
		visitor.visit(source)
	}
}

fn shadow_root_as_node(shadow_root &ShadowRoot) &Node {
	return unsafe { &Node(shadow_root) }
}

fn shadow_root_as_document_fragment(shadow_root &ShadowRoot) &DocumentFragment {
	return unsafe { &DocumentFragment(shadow_root) }
}

pub fn (shadow_root &ShadowRoot) mode() ShadowRootMode {
	return shadow_root.mode
}

pub fn (mut shadow_root ShadowRoot) set_slot_assignment(slot_assignment SlotAssignmentMode) {
	shadow_root.slot_assignment_ = slot_assignment
}

pub fn (mut shadow_root ShadowRoot) set_delegates_focus(delegates_focus bool) {
	shadow_root.delegates_focus_ = delegates_focus
}

pub fn (shadow_root &ShadowRoot) declarative() bool {
	return shadow_root.declarative
}

pub fn (mut shadow_root ShadowRoot) set_clonable(clonable bool) {
	shadow_root.clonable_ = clonable
}

pub fn (mut shadow_root ShadowRoot) set_serializable(serializable bool) {
	shadow_root.serializable_ = serializable
}

pub fn (shadow_root &ShadowRoot) available_to_element_internals() bool {
	return shadow_root.available_to_element_internals_
}

pub fn (mut shadow_root ShadowRoot) set_available_to_element_internals(available bool) {
	shadow_root.available_to_element_internals_ = available
}

pub fn (shadow_root &ShadowRoot) is_user_agent_internal() bool {
	return shadow_root.user_agent_internal_
}

pub fn (mut shadow_root ShadowRoot) set_user_agent_internal(user_agent_internal bool) {
	shadow_root.user_agent_internal_ = user_agent_internal
}

pub fn (shadow_root &ShadowRoot) uses_document_style_sheets() bool {
	return shadow_root.uses_document_style_sheets_
}

pub fn (mut shadow_root ShadowRoot) set_uses_document_style_sheets(value bool) {
	shadow_root.uses_document_style_sheets_ = value
}

pub fn (mut shadow_root ShadowRoot) finalize() {
	mut document := unsafe { &Document(shadow_root.document()) }
	if document != unsafe { nil } {
		document.unregister_shadow_root(shadow_root)
	}
}

// https://fullscreen.spec.whatwg.org/#dom-document-fullscreenelement
pub fn (shadow_root &ShadowRoot) fullscreen_element_for_bindings() ?&Element {
	// 1. If this is a shadow root and its host is not connected, then return null.
	host := shadow_root.host() or { return none }
	if !host.as_node().is_connected() {
		return none
	}

	document := shadow_root.document()
	fullscreen_element := document.fullscreen_element() or { return none }

	// 2. Let candidate be the result of retargeting fullscreen element against this.
	candidate_target := retarget(unsafe { &EventTarget(fullscreen_element.as_node()) }, unsafe {
		&EventTarget(shadow_root_as_node(shadow_root))
	}) or { return none }
	candidate_node := event_target_as_node(candidate_target) or { return none }
	candidate := candidate_node.as_element() or { return none }

	// 3. If candidate and this are in the same tree, then return candidate.
	if candidate.as_node().root() == shadow_root_as_node(shadow_root).root() {
		return candidate
	}

	// 4. Return null.
	return none
}

pub fn (mut shadow_root ShadowRoot) initialize() {}

// https://dom.spec.whatwg.org/#dom-shadowroot-onslotchange
pub fn (mut shadow_root ShadowRoot) set_onslotchange(event_handler ?&CallbackType) {
	shadow_root.onslotchange_ = event_handler
	unsafe { &EventTarget(shadow_root_as_node(&shadow_root)) }.set_event_handler_attribute('slotchange',
		event_handler)
}

// https://dom.spec.whatwg.org/#dom-shadowroot-onslotchange
pub fn (shadow_root &ShadowRoot) onslotchange() ?&CallbackType {
	event_handler := unsafe { &EventTarget(shadow_root_as_node(shadow_root)) }.event_handler_attribute('slotchange') or {
		return shadow_root.onslotchange_
	}
	return event_handler
}

// https://dom.spec.whatwg.org/#ref-for-get-the-parent
pub fn (shadow_root &ShadowRoot) get_parent(event &Event) ?&EventTarget {
	if !event.composed() && event.path().len > 0 {
		first_invocation_target := event.path()[0].invocation_target
		if first_invocation_target != unsafe { nil } {
			first_invocation_node := unsafe { &Node(first_invocation_target) }
			if first_invocation_node.root() == shadow_root_as_node(shadow_root) {
				return none
			}
		}
	}
	host := shadow_root.host() or { return none }
	return unsafe { &EventTarget(host.as_node()) }
}

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-shadowroot-innerhtml
pub fn (shadow_root &ShadowRoot) inner_html() !string {
	return shadow_root_as_node(shadow_root).serialize_fragment(.yes, .inner)
}

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-shadowroot-innerhtml
pub fn (mut shadow_root ShadowRoot) set_inner_html(value string) ! {
	// 1. Trusted Types compliance is not translated yet; treat value as the compliant string.
	// 2. Let context be this's host.
	context := shadow_root.host() or { return error('ShadowRoot has no host') }

	// 3. Let fragment be the result of invoking the fragment parsing algorithm steps with context and compliantString.
	// 4. Replace all with fragment within this.
	mut node := unsafe { &Node(&shadow_root) }
	node.unsafely_set_html(context, value)!

	// NOTE: We do not have HTMLTemplateElement in the current V DOM yet.
	node.set_needs_style_update(true)
	if node.is_connected() {
		mut document := unsafe { &Document(node.document()) }
		document.invalidate_layout_tree(.shadow_root_set_inner_html)
	}
}

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-element-gethtml
pub fn (shadow_root &ShadowRoot) get_html(options GetHTMLOptions) !string {
	// ShadowRoot's getHTML(options) method steps are to return the result
	// of HTML fragment serialization algorithm with this,
	// options["serializableShadowRoots"], and options["shadowRoots"].
	serializable_shadow_roots := if options.serializable_shadow_roots {
		SerializableShadowRoots.yes
	} else {
		SerializableShadowRoots.no
	}
	return html_parser_serialize_html_fragment(shadow_root_as_node(shadow_root),
		serializable_shadow_roots, []&ShadowRoot{}, .inner)
}

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-shadowroot-sethtmlunsafe
pub fn (mut shadow_root ShadowRoot) set_html_unsafe(html string) ! {
	// 1. Trusted Types compliance is not translated yet; treat html as the compliant HTML.
	// 2. Unsafely set HTML given this, this's shadow host, and compliantHTML.
	context := shadow_root.host() or { return error('ShadowRoot has no host') }
	mut node := unsafe { &Node(&shadow_root) }
	node.unsafely_set_html(context, html)!
}

pub fn (shadow_root &ShadowRoot) active_element() ?&Element {
	document := shadow_root.document()
	mut candidate := document.focused_area()
	if candidate == none && document.browsing_context != unsafe { nil }
		&& !unsafe { &Node(document) }.is_inert() {
		candidate = unsafe { &Node(document) }
	}
	candidate_node := candidate or { return none }
	retargeted := retarget(unsafe { &EventTarget(candidate_node) }, unsafe {
		&EventTarget(shadow_root_as_node(shadow_root))
	}) or { return none }
	retargeted_node := event_target_as_node(retargeted) or { return none }
	if retargeted_node.root() != shadow_root_as_node(shadow_root) {
		return none
	}
	if retargeted_node.is_document() {
		candidate_document := unsafe { &Document(retargeted_node) }
		if body := candidate_document.body() {
			return html_element_as_element(body)
		}
		return candidate_document.document_element()
	}
	return retargeted_node.as_element()
}

pub fn (mut shadow_root ShadowRoot) style_sheets() &StyleSheetList {
	if shadow_root.style_sheets_ == unsafe { nil } {
		shadow_root.style_sheets_ = &StyleSheetList{}
	}
	return shadow_root.style_sheets_
}

pub fn (mut shadow_root ShadowRoot) style_sheets_for_bindings() &StyleSheetList {
	return shadow_root.style_sheets()
}

pub fn (shadow_root &ShadowRoot) adopted_style_sheets() []&CSSStyleSheet {
	return shadow_root.adopted_style_sheets_.clone()
}

pub fn (mut shadow_root ShadowRoot) set_adopted_style_sheets(new_value VoidPtr) ! {
	// In C++ this consumes a JS iterable and appends CSSStyleSheet values into the observable array.
	// JS iteration is outside this DOM-only port, so callers can use set_adopted_style_sheet_list()
	// when they already have translated CSSStyleSheet references.
	_ = new_value
	shadow_root.adopted_style_sheets_.clear()
}

pub fn (mut shadow_root ShadowRoot) set_adopted_style_sheet_list(sheets []&CSSStyleSheet) {
	shadow_root.adopted_style_sheets_ = sheets.clone()
}

pub fn (shadow_root &ShadowRoot) for_each_css_style_sheet(callback fn (&CSSStyleSheet)) {
	mut mutable_shadow_root := unsafe { &ShadowRoot(shadow_root) }
	for style_sheet in mutable_shadow_root.style_sheets().sheets {
		callback(style_sheet)
	}
	for style_sheet in shadow_root.adopted_style_sheets() {
		callback(style_sheet)
	}
}

pub fn (shadow_root &ShadowRoot) for_each_active_css_style_sheet(callback fn (&CSSStyleSheet)) {
	shadow_root.for_each_css_style_sheet(fn [callback] (style_sheet &CSSStyleSheet) {
		if !style_sheet.disabled {
			callback(style_sheet)
		}
	})
}

pub fn (mut shadow_root ShadowRoot) visit_edges(mut visitor CellVisitor) {
	mut fragment := shadow_root_as_document_fragment(&shadow_root)
	fragment.visit_edges(mut visitor)
	visitor.visit(shadow_root.style_sheets_)
	visitor.visit(shadow_root.element_by_id_)
	visitor.visit(shadow_root.slot_registry_)
	for style_sheet in shadow_root.adopted_style_sheets_ {
		visitor.visit(style_sheet)
	}
	mut event_target := unsafe { &EventTarget(shadow_root_as_node(&shadow_root)) }
	event_target.visit_edges(mut visitor)
	if handler := shadow_root.onslotchange_ {
		visitor.visit(handler)
	}
}

pub fn (mut shadow_root ShadowRoot) get_animations() ![]&Animation {
	mut document := unsafe { &Document(shadow_root.document()) }
	document.update_style()
	return []
}

pub fn (shadow_root &ShadowRoot) element_by_id() &ElementByIdMap {
	mut mutable_shadow_root := unsafe { &ShadowRoot(shadow_root) }
	if mutable_shadow_root.element_by_id_ == unsafe { nil } {
		mutable_shadow_root.element_by_id_ = &ElementByIdMap{}
	}
	return mutable_shadow_root.element_by_id_
}

pub fn (shadow_root &ShadowRoot) first_slot_with_name(name string) ?&HTMLSlotElement {
	if shadow_root.slot_registry_ != unsafe { nil } {
		registry := unsafe { &SlotRegistry(shadow_root.slot_registry_) }
		return registry.first_slot_with_name(name)
	}
	return none
}

// https://drafts.csswg.org/css-shadow-1/#shadow-root-part-element-map
pub fn (shadow_root &ShadowRoot) part_element_map() map[string][]AbstractElement {
	return shadow_root.calculate_part_element_map()
}

// https://drafts.csswg.org/css-shadow-1/#calculate-the-part-element-map
pub fn (shadow_root &ShadowRoot) calculate_part_element_map() map[string][]AbstractElement {
	// To calculate the part element map of a shadow root, outerRoot:
	mut part_element_map := map[string][]AbstractElement{}
	map_ptr := &part_element_map

	// 1. For each descendant el within outerRoot:
	shadow_root_as_node(shadow_root).for_each_in_subtree(fn [map_ptr] (node &Node) TraversalDecision {
		element := node.as_element() or { return .@continue }

		// 1. For each name in el's part name list, append el to outerRoot's part element map[name].
		for name in element.parts {
			unsafe {
				mut current := *map_ptr
				mut entries := current[name] or { []AbstractElement{} }
				entries << AbstractElement.new(element, none)
				current[name] = entries
				*map_ptr = current
			}
		}

		// FIXME: The rest concerns forwarded part names, which are not implemented yet.
		return .@continue
	})

	return part_element_map
}

// https://dom.spec.whatwg.org/#concept-slot
pub struct Slot {
pub mut:
	name_          string
	assigned_nodes []&Node
}

pub fn (slot &Slot) slot_name() string {
	return slot.name_
}

pub fn (mut slot Slot) set_slot_name(name string) {
	slot.name_ = name
}

pub fn (slot &Slot) assigned_nodes_internal() []&Node {
	return slot.assigned_nodes
}

pub fn (mut slot Slot) set_assigned_nodes(assigned_nodes []&Node) {
	slot.assigned_nodes = assigned_nodes
}

pub fn (mut slot Slot) visit_edges(mut visitor CellVisitor) {
	for node in slot.assigned_nodes {
		visitor.visit(node)
	}
}

@[heap]
pub struct SlotRegistry {
mut:
	slots []&HTMLSlotElement
}

pub fn (mut registry SlotRegistry) add(slot &HTMLSlotElement) {
	registry.slots = registry.slots.filter(it != unsafe { nil } && it != slot)

	if registry.slots.len == 0 || !registry.try_insert_in_tree_order(slot) {
		registry.slots << slot
	}
}

fn (mut registry SlotRegistry) try_insert_in_tree_order(slot &HTMLSlotElement) bool {
	// Walk forward from the slot being added to find the next registered slot. If found,
	// insert before it so the registry keeps slot tree order as DOM mutations reorder nodes.
	slot_node := html_slot_element_as_node(slot)
	shadow_root := slot_node.root()
	mut maybe_node := slot_node.next_in_pre_order(shadow_root)
	for maybe_node != none {
		node := maybe_node or { break }
		if element := node.as_element() {
			if element.local_name() == 'slot' {
				following_slot := unsafe { &HTMLSlotElement(element) }
				for index, registered_slot in registry.slots {
					if registered_slot == following_slot {
						registry.slots.insert(index, slot)
						return true
					}
				}
			}
		}
		maybe_node = node.next_in_pre_order(shadow_root)
	}
	return false
}

pub fn (mut registry SlotRegistry) remove(slot &HTMLSlotElement) {
	registry.slots = registry.slots.filter(it != unsafe { nil } && it != slot)
}

pub fn (registry &SlotRegistry) first_slot_with_name(name string) ?&HTMLSlotElement {
	for slot in registry.slots {
		if slot == unsafe { nil } {
			continue
		}
		if html_slot_element_name(slot) == name {
			return slot
		}
	}
	return none
}

pub fn (registry &SlotRegistry) for_each_slot(callback fn (&HTMLSlotElement)) {
	for slot in registry.slots {
		if slot == unsafe { nil } {
			continue
		}
		callback(slot)
	}
}

pub fn (registry &SlotRegistry) is_empty() bool {
	for slot in registry.slots {
		if slot != unsafe { nil } {
			return false
		}
	}
	return true
}

pub enum OpenFlag {
	set
	unset
}

fn html_slot_element_as_node(slot &HTMLSlotElement) &Node {
	return unsafe { &Node(slot) }
}

fn html_slot_element_as_element(slot &HTMLSlotElement) &Element {
	return unsafe { &Element(slot) }
}

fn html_slot_element_name(slot &HTMLSlotElement) string {
	return html_slot_element_as_element(slot).get_attribute('name') or { '' }
}

pub fn (slot &HTMLSlotElement) slot_name() string {
	return html_slot_element_name(slot)
}

pub fn (mut slot HTMLSlotElement) set_slot_name(name string) {
	mut element := unsafe { &Element(&slot) }
	element.set_attribute_value('name', name)
}

pub fn (mut slot HTMLSlotElement) set_assigned_nodes(assigned_nodes []&Node) {
	slot.assigned_nodes_ = assigned_nodes
}

pub fn (mut slot HTMLSlotElement) visit_edges(mut visitor CellVisitor) {
	mut element := unsafe { &Element(&slot) }
	element.visit_edges(mut visitor)
	for node in slot.assigned_nodes_ {
		visitor.visit(node)
	}
	for node in slot.manually_assigned_nodes_ {
		visitor.visit(node)
	}
}

pub fn (slot &HTMLSlotElement) manually_assigned_nodes() []&Node {
	return slot.manually_assigned_nodes_
}

pub fn (mut slot HTMLSlotElement) remove_manually_assigned_node(node &Node) {
	slot.manually_assigned_nodes_ = slot.manually_assigned_nodes_.filter(it != node)
}

pub fn (mut slot HTMLSlotElement) set_manually_assigned_nodes(nodes []&Node) {
	slot.manually_assigned_nodes_ = nodes.clone()
}

// https://html.spec.whatwg.org/multipage/scripting.html#dom-slot-assignednodes
pub fn (slot &HTMLSlotElement) assigned_nodes_with_options(options AssignedNodesOptions) []&Node {
	// 1. If options["flatten"] is false, then return this's assigned nodes.
	if !options.flatten {
		return slot.assigned_nodes_internal().clone()
	}

	// 2. Return the result of finding flattened slottables with this.
	return find_flattened_slottables(slot)
}

// https://html.spec.whatwg.org/multipage/scripting.html#dom-slot-assignedelements
pub fn (slot &HTMLSlotElement) assigned_elements(options AssignedNodesOptions) []&Element {
	// 1. If options["flatten"] is false, then return this's assigned nodes, filtered to contain only Element nodes.
	nodes := if options.flatten {
		// 2. Return the result of finding flattened slottables with this, filtered to contain only Element nodes.
		find_flattened_slottables(slot)
	} else {
		slot.assigned_nodes_internal()
	}
	mut elements := []&Element{}
	for node in nodes {
		if element := node.as_element() {
			elements << element
		}
	}
	return elements
}

// https://html.spec.whatwg.org/multipage/scripting.html#dom-slot-assign
pub fn (mut slot HTMLSlotElement) assign(nodes []&Node) {
	// 1. For each node of this's manually assigned nodes, set node's manual slot assignment to null.
	for manually_assigned_node in slot.manually_assigned_nodes_ {
		mut node := unsafe { &Node(manually_assigned_node) }
		node.set_manual_slot_assignment(none)
	}

	// 2. Let nodesSet be a new ordered set.
	mut nodes_set := []&Node{}

	// 3. For each node of nodes:
	for node in nodes {
		if !node.is_slottable() {
			continue
		}

		// 1. If node's manual slot assignment refers to a slot, then remove node from that slot's manually assigned nodes.
		if previous_slot := node.manual_slot_assignment() {
			mut mutable_previous_slot := unsafe { &HTMLSlotElement(previous_slot) }
			mutable_previous_slot.remove_manually_assigned_node(node)
		}

		// 2. Set node's manual slot assignment to this.
		mut mutable_node := unsafe { &Node(node) }
		mutable_node.set_manual_slot_assignment(&slot)

		// 3. Append node to nodesSet.
		if node !in nodes_set {
			nodes_set << node
		}
	}

	// 4. Set this's manually assigned nodes to nodesSet.
	slot.manually_assigned_nodes_ = nodes_set

	// 5. Run assign slottables for a tree for this's root.
	assign_slottables_for_a_tree(html_slot_element_as_node(&slot).root())
}

pub fn (node &Node) slottable_name() string {
	if element := node.as_element() {
		return element.get_attribute('slot') or { '' }
	}
	return ''
}

pub fn (node &Node) assigned_slot_internal() ?&HTMLSlotElement {
	return node.assigned_slot_
}

pub fn (mut node Node) set_assigned_slot(assigned_slot ?&HTMLSlotElement) {
	node.assigned_slot_ = assigned_slot
}

pub fn (node &Node) manual_slot_assignment() ?&HTMLSlotElement {
	return node.manual_slot_assignment_
}

pub fn (mut node Node) set_manual_slot_assignment(manual_slot_assignment ?&HTMLSlotElement) {
	node.manual_slot_assignment_ = manual_slot_assignment
}

// https://dom.spec.whatwg.org/#dom-slotable-assignedslot
pub fn (node &Node) assigned_slot() ?&HTMLSlotElement {
	// The assignedSlot getter steps are to return the result of find a slot given this and with the open flag set.
	return find_a_slot(node, .set)
}

pub fn assigned_slot_for_node(node &Node) ?&HTMLSlotElement {
	if !node.is_slottable() {
		return none
	}
	return node.assigned_slot_internal()
}

// https://dom.spec.whatwg.org/#find-a-slot
pub fn find_a_slot(slottable &Node, open_flag OpenFlag) ?&HTMLSlotElement {
	// 1. If slottable's parent is null, then return null.
	parent := slottable.parent_element() or { return none }

	// 2. Let shadow be slottable's parent's shadow root.
	shadow := parent.shadow_root() or { return none }

	// 4. If the open flag is set and shadow's mode is not "open", then return null.
	if open_flag == .set && shadow.mode != .open {
		return none
	}

	// 5. If shadow's slot assignment is "manual", then return the slot in shadow's descendants whose manually assigned
	// nodes contains slottable, if any; otherwise null.
	if shadow.slot_assignment_ == .manual {
		return find_manual_slot_in_tree(shadow_root_as_node(shadow), slottable)
	}

	// 6. Return the first slot in tree order in shadow's descendants whose name is slottable's name, if any.
	return shadow.first_slot_with_name(slottable.slottable_name())
}

fn find_manual_slot_in_tree(root &Node, slottable &Node) ?&HTMLSlotElement {
	for child in root.children {
		if element := child.as_element() {
			if element.local_name() == 'slot' {
				slot := unsafe { &HTMLSlotElement(element) }
				if slottable in slot.manually_assigned_nodes() {
					return slot
				}
			}
		}
		if slot := find_manual_slot_in_tree(child, slottable) {
			return slot
		}
	}
	return none
}

// https://dom.spec.whatwg.org/#find-slotables
pub fn find_slottables(slot &HTMLSlotElement) []&Node {
	// 1. Let result be an empty list.
	mut result := []&Node{}

	// 2. Let root be slot's root.
	root := html_slot_element_as_node(slot).root()

	// 3. If root is not a shadow root, then return result.
	shadow_root := root.as_shadow_root() or { return result }

	// 4. Let host be root's host.
	host := shadow_root.host() or { return result }

	// 5. If root's slot assignment is "manual", then:
	if shadow_root.slot_assignment_ == .manual {
		// 2. For each slottable slottable of slot's manually assigned nodes, if slottable's parent is host,
		// append slottable to result.
		for slottable in slot.manually_assigned_nodes() {
			if parent := slottable.parent() {
				if parent == host.as_node() {
					result << slottable
				}
			}
		}
		return result
	}

	// 6. Otherwise, for each slottable child slottable of host, in tree order:
	for child in host.as_node().children {
		if !child.is_slottable() {
			continue
		}
		// 1. Let foundSlot be the result of finding a slot given slottable.
		found_slot := find_a_slot(child, .unset) or { continue }

		// 2. If foundSlot is slot, then append slottable to result.
		if found_slot == slot {
			result << child
		}
	}

	// 7. Return result.
	return result
}

// https://dom.spec.whatwg.org/#find-flattened-slotables
pub fn find_flattened_slottables(slot &HTMLSlotElement) []&Node {
	// 1. Let result be empty.
	mut result := []&Node{}

	// 2. If slot's root is not a shadow root, then return result.
	if html_slot_element_as_node(slot).root().as_shadow_root() == none {
		return result
	}

	// 3. Let slottables be the result of finding slottables given slot.
	mut slottables := find_slottables(slot)

	// 4. If slottables is the empty list, then append each slottable child of slot, in tree order, to slottables.
	if slottables.len == 0 {
		for child in html_slot_element_as_node(slot).children {
			if child.is_slottable() {
				slottables << child
			}
		}
	}

	// 5. For each node of slottables:
	for node in slottables {
		// 1. If node is a slot whose root is a shadow root, recurse.
		if element := node.as_element() {
			if element.local_name() == 'slot' && node.root().as_shadow_root() != none {
				result << find_flattened_slottables(unsafe { &HTMLSlotElement(element) })
				continue
			}
		}
		// 2. Otherwise, append node to result.
		result << node
	}

	// 6. Return result.
	return result
}

// https://dom.spec.whatwg.org/#assign-slotables
pub fn assign_slottables(slot &HTMLSlotElement) {
	// 1. Let slottables be the result of finding slottables for slot.
	slottables := find_slottables(slot)

	// 2. If slottables and slot's assigned nodes are not identical, then run signal a slot change for slot.
	if slottables != slot.assigned_nodes_internal() {
		signal_a_slot_change(slot)
	}

	// Clear any previously assigned slottables before installing the new assignment list.
	for old_slottable in slot.assigned_nodes_internal() {
		mut old_node := unsafe { &Node(old_slottable) }
		old_node.set_assigned_slot(none)
	}

	// 4. For each slottable in slottables, set slottable's assigned slot to slot.
	for slottable in slottables {
		mut node := unsafe { &Node(slottable) }
		node.set_assigned_slot(slot)
	}

	// 3. Set slot's assigned nodes to slottables.
	// NOTE: We do this step last so that we can move the slottables list.
	mut mutable_slot := unsafe { &HTMLSlotElement(slot) }
	mutable_slot.assigned_nodes_ = slottables
}

// https://dom.spec.whatwg.org/#assign-slotables-for-a-tree
pub fn assign_slottables_for_a_tree(root &Node) {
	// To assign slottables for a tree, given a node root, run assign slottables for each slot of root's inclusive
	// descendants, in tree order.
	if shadow_root := root.as_shadow_root() {
		if shadow_root.slot_registry_ != unsafe { nil } {
			registry := unsafe { &SlotRegistry(shadow_root.slot_registry_) }
			registry.for_each_slot(fn (slot &HTMLSlotElement) {
				assign_slottables(slot)
			})
		}
		return
	}

	if element := root.as_element() {
		if element.local_name() != 'slot' {
			return
		}
		root.for_each_in_inclusive_subtree(fn (node &Node) TraversalDecision {
			if descendant_element := node.as_element() {
				if descendant_element.local_name() == 'slot' {
					assign_slottables(unsafe { &HTMLSlotElement(descendant_element) })
				}
			}
			return .@continue
		})
	}
}

// https://dom.spec.whatwg.org/#assign-a-slot
pub fn assign_a_slot(slottable &Node) {
	// 1. Let slot be the result of finding a slot with slottable.
	slot := find_a_slot(slottable, .unset) or { return }

	// 2. If slot is non-null, then run assign slottables for slot.
	assign_slottables(slot)
}

// https://dom.spec.whatwg.org/#signal-a-slot-change
pub fn signal_a_slot_change(slot &HTMLSlotElement) {
	// 1. Append slot to slot's relevant agent's signal slots.
	mut document := unsafe { &Document(html_slot_element_as_node(slot).document()) }
	if document != unsafe { nil } && slot !in document.signal_slots {
		document.signal_slots << slot
	}

	// 2. Queue a mutation observer microtask.
	if document != unsafe { nil } {
		queue_mutation_observer_microtask(mut document)
	}
}

fn queue_mutation_observer_microtask(mut document Document) {
	// 1. If the surrounding agent's mutation observer microtask queued is true, then return.
	if document.mutation_observer_microtask_queued {
		return
	}

	// 2. Set the surrounding agent's mutation observer microtask queued to true.
	document.mutation_observer_microtask_queued = true

	// 3. Queue a microtask to notify mutation observers.
	// This DOM-only port has no JS microtask queue, so run the checkpoint immediately.
	document.notify_mutation_observers()
}

pub fn (mut document Document) notify_mutation_observers() {
	// https://dom.spec.whatwg.org/#notify-mutation-observers
	// 1. Set the surrounding agent's mutation observer microtask queued to false.
	document.mutation_observer_microtask_queued = false

	// 2. Let notifySet be a clone of the surrounding agent's pending mutation observers.
	// 3. Empty the surrounding agent's pending mutation observers.
	notify_set := document.pending_mutation_observers.clone()
	document.pending_mutation_observers.clear()

	// 4. Let signalSet be a clone of the surrounding agent's signal slots.
	// 5. Empty the surrounding agent's signal slots.
	signal_set := document.signal_slots.clone()
	document.signal_slots.clear()

	// 6. For each mo of notifySet:
	for mutation_observer in notify_set {
		// 1. Let records be a clone of mo's record queue.
		// 2. Empty mo's record queue.
		mut mutable_observer := unsafe { &MutationObserver(mutation_observer) }
		records := mutable_observer.take_records()

		// 3. For each node of mo's node list, remove all transient registered observers whose observer is mo from
		//    node's registered observer list.
		for node in mutation_observer.node_list_ {
			if node == unsafe { nil } {
				continue
			}
			mut mutable_node := unsafe { &Node(node) }
			for i := mutable_node.registered_observer_list_.len - 1; i >= 0; i-- {
				registered_observer := mutable_node.registered_observer_list_[i]
				if registered_observer.is_transient()
					&& registered_observer.observer() == mutation_observer {
					mutable_node.registered_observer_list_.delete(i)
				}
			}
		}

		// 4. If records is not empty, then invoke mo's callback with << records, mo >> and "report", and with
		//    callback this value mo.
		if records.len != 0 {
			if callback := mutation_observer.callback_ {
				if mutation_callback := callback.mutation_callback {
					mutation_callback(records, mutation_observer)
				}
			}
		}
	}

	// 7. For each slot of signalSet, fire an event named slotchange, with its bubbles attribute set to true, at slot.
	for slot in signal_set {
		slotchange_event := Event.create('slotchange', EventInit{
			bubbles: true
		})
		event_target_dispatch_event(unsafe { &EventTarget(html_slot_element_as_node(slot)) },
			slotchange_event)
	}
}

pub struct StyleInvalidationSet {
pub mut:
	properties []InvalidationProperty
}

pub struct DescendantInvalidationRule {
pub mut:
	match_set StyleInvalidationSet
	match_any bool
	payload   ?InvalidationPlan
}

pub struct SiblingInvalidationRule {
pub mut:
	match_set StyleInvalidationSet
	match_any bool
	reach     SiblingInvalidationReach
	payload   ?InvalidationPlan
}

pub enum SiblingInvalidationReach {
	adjacent
	subsequent
}

fn element_matches_invalidation_rule(element &Element, match_set StyleInvalidationSet, match_any bool) bool {
	return match_any || element_includes_properties_from_invalidation_set(element, match_set)
}

fn element_includes_properties_from_invalidation_set(element &Element, match_set StyleInvalidationSet) bool {
	_ = element
	_ = match_set
	// Stub for Element::includes_properties_from_invalidation_set() until selector invalidation metadata is ported.
	return false
}

fn invalidation_plan_is_empty(plan InvalidationPlan) bool {
	_ = plan
	// Stub for CSS::InvalidationPlan::is_empty().
	return true
}

fn invalidation_plan_invalidates_whole_subtree(plan InvalidationPlan) bool {
	_ = plan
	return false
}

fn invalidation_plan_invalidates_self(plan InvalidationPlan) bool {
	_ = plan
	return false
}

fn invalidation_plan_descendant_rules(plan InvalidationPlan) []DescendantInvalidationRule {
	_ = plan
	return []DescendantInvalidationRule{}
}

fn invalidation_plan_sibling_rules(plan InvalidationPlan) []SiblingInvalidationRule {
	_ = plan
	return []SiblingInvalidationRule{}
}

pub fn (mut invalidator StyleInvalidator) visit_edges(mut visitor CellVisitor) {
	_ = invalidator
	_ = visitor
}

pub fn (mut invalidator StyleInvalidator) invalidate(mut node Node) {
	invalidator.perform_pending_style_invalidations(mut node, false)
}

fn (mut invalidator StyleInvalidator) add_pending_invalidation(node &Node, reason StyleInvalidationReason, plan InvalidationPlan) {
	_ = invalidator
	_ = node
	_ = reason
	_ = plan
	// Stub for StyleInvalidator::m_pending_invalidations until StyleInvalidator stores pending rule state.
}

fn (mut invalidator StyleInvalidator) apply_invalidation_plan(mut element Element, reason StyleInvalidationReason, plan InvalidationPlan, invalidate_entire_subtree bool) bool {
	if invalidation_plan_is_empty(plan) {
		return invalidate_entire_subtree
	}
	mut node := unsafe { &Node(&element) }
	mut invalidate_subtree := invalidate_entire_subtree
	if invalidation_plan_invalidates_whole_subtree(plan) {
		node.invalidate_style(reason)
		invalidate_subtree = true
		node.set_needs_style_update_internal(true)
		if node.has_child_nodes() {
			node.set_child_needs_style_update(true)
		}
		return invalidate_subtree
	}

	if invalidation_plan_invalidates_self(plan) {
		node.set_needs_style_update(true)
	}

	for descendant_rule in invalidation_plan_descendant_rules(plan) {
		if payload := descendant_rule.payload {
			invalidator.add_pending_invalidation(node, reason, payload)
		}
	}

	for sibling_rule in invalidation_plan_sibling_rules(plan) {
		invalidator.apply_sibling_invalidation(mut element, reason, sibling_rule)
	}
	return invalidate_subtree
}

fn (mut invalidator StyleInvalidator) apply_sibling_invalidation(mut element Element, reason StyleInvalidationReason, sibling_rule SiblingInvalidationRule) {
	mut sibling := element.as_node().next_sibling()
	for sibling != none {
		node := sibling or { break }
		sibling_element := node.as_element() or {
			sibling = node.next_sibling()
			continue
		}
		if element_matches_invalidation_rule(sibling_element, sibling_rule.match_set,
			sibling_rule.match_any)
		{
			if payload := sibling_rule.payload {
				invalidator.enqueue_invalidation_plan(node, reason, payload)
			}
		}
		if sibling_rule.reach == .adjacent {
			break
		}
		sibling = node.next_sibling()
	}
}

fn (mut invalidator StyleInvalidator) perform_pending_style_invalidations(mut node Node, invalidate_entire_subtree bool) {
	mut invalidate_subtree := invalidate_entire_subtree || node.entire_subtree_needs_style_update()
	if invalidate_subtree {
		node.set_needs_style_update_internal(true)
		if node.has_child_nodes() {
			node.set_child_needs_style_update(true)
		}
	}

	for child in node.children {
		mut child_node := unsafe { &Node(child) }
		invalidator.perform_pending_style_invalidations(mut child_node, invalidate_subtree)
	}

	if element := node.as_element() {
		if shadow_root := element.shadow_root() {
			mut shadow_node := unsafe { &Node(shadow_root) }
			invalidator.perform_pending_style_invalidations(mut shadow_node, invalidate_subtree)
			if invalidate_subtree {
				node.set_child_needs_style_update(true)
			}
		}
	}

	node.set_entire_subtree_needs_style_update(false)
}

pub enum StyleElementAnyFailed {
	no
	yes
}

pub struct StyleElementBase {
pub mut:
	element_                     &Element = unsafe { nil }
	associated_css_style_sheet_  ?&CSSStyleSheet
	style_sheet_list_            ?&StyleSheetList
	document_load_event_delayer_ ?DocumentLoadEventDelayer
}

pub fn StyleElementBase.new(element &Element) StyleElementBase {
	return StyleElementBase{
		element_: element
	}
}

pub fn (base &StyleElementBase) as_element() &Element {
	return base.element_
}

// https://html.spec.whatwg.org/multipage/semantics.html#update-a-style-block
pub fn (mut base StyleElementBase) update_a_style_block() {
	style_element := base.as_element()

	// OPTIMIZATION: Skip parsing CSS if we're in the middle of parsing a HTML fragment.
	if style_element.document().is_temporary_document_for_fragment_parsing() {
		return
	}

	// 1. Let element be the style element.
	// 2. If element has an associated CSS style sheet, remove the CSS style sheet in question.
	if associated_css_style_sheet := base.associated_css_style_sheet_ {
		if mut style_sheet_list := base.style_sheet_list_ {
			style_sheet_list.remove_a_css_style_sheet(associated_css_style_sheet)
		}
		base.style_sheet_list_ = none

		// FIXME: This should probably be handled by StyleSheet::set_owner_node().
		base.associated_css_style_sheet_ = none
	}

	// 3. If element is not connected, then return.
	if !style_element.as_node().is_connected() {
		return
	}

	// 4. If element's type attribute is present and its value is neither the empty string nor an ASCII
	// case-insensitive match for "text/css", then return.
	if type_attribute := style_element.get_attribute('type') {
		if type_attribute.len > 0 && to_ascii_lowercase(type_attribute) != 'text/css' {
			return
		}
	}

	// 5. If the Should element's inline behavior be blocked by Content Security Policy? algorithm returns "Blocked"
	// when executed upon the style element, "style", and the style element's child text content, then return. [CSP]
	if should_elements_inline_style_behavior_be_blocked_by_content_security_policy(style_element,
		style_element.as_node().child_text_content())
	{
		return
	}

	// 6. Create a CSS style sheet with the associated CSS style sheet properties.
	mut document := unsafe { &Document(style_element.document()) }
	mut style_sheet_list := style_element.document_or_shadow_root_style_sheets()
	style_sheet := &CSSStyleSheet{
		url: style_element.base_uri()
	}
	style_sheet_list.sheets << style_sheet
	base.style_sheet_list_ = style_sheet_list
	base.associated_css_style_sheet_ = style_sheet

	// 7. If element contributes a script-blocking style sheet, append element to its node document's set.
	if style_element.contributes_a_script_blocking_style_sheet() {
		base.document_load_event_delayer_ = DocumentLoadEventDelayer.new(mut document)
		document.script_blocking_style_sheet_set << style_element
	}

	// FIXME: 8. Potential render-blocking media matching is not translated yet.

	// AD-HOC: Check if we have already loaded the sheet's resources.
	loading_state := style_sheet.loading_state_value()
	if loading_state == .loaded || loading_state == .error {
		any_failed := if loading_state == .error {
			StyleElementAnyFailed.yes
		} else {
			StyleElementAnyFailed.no
		}
		base.finished_loading_critical_subresources(any_failed)
	}
}

// https://html.spec.whatwg.org/multipage/semantics.html#the-style-element:critical-subresources
pub fn (mut base StyleElementBase) finished_loading_critical_subresources(any_failed StyleElementAnyFailed) {
	// 1. Let element be the style element associated with the style sheet in question.
	mut element := unsafe { &Element(base.as_element()) }

	// 2. Let success be true.
	mut success := true

	// 3. If any critical subresource failed, set success to false.
	if any_failed == .yes {
		success = false
	}

	// 4. Queue an element task on the networking task source.
	if success {
		element.dispatch_event_simple('load', false)
	} else {
		element.dispatch_event_simple('error', false)
	}
	if element.contributes_a_script_blocking_style_sheet() {
		mut document := unsafe { &Document(element.document()) }
		document.script_blocking_style_sheet_set =
			document.script_blocking_style_sheet_set.filter(it != element)
	}
	element.unblock_rendering()
	if mut delayer := base.document_load_event_delayer_ {
		delayer.finish()
		base.document_load_event_delayer_ = none
	}
}

// https://www.w3.org/TR/cssom/#dom-linkstyle-sheet
pub fn (base &StyleElementBase) sheet() ?&CSSStyleSheet {
	return base.associated_css_style_sheet_
}

pub fn (base &StyleElementBase) style_sheet_list() ?&StyleSheetList {
	return base.style_sheet_list_
}

pub fn (mut base StyleElementBase) visit_style_element_edges(mut visitor CellVisitor) {
	if sheet := base.associated_css_style_sheet_ {
		visitor.visit(sheet)
	}
	if list := base.style_sheet_list_ {
		visitor.visit(list)
	}
}

fn should_elements_inline_style_behavior_be_blocked_by_content_security_policy(element &Element, child_text_content string) bool {
	_ = element
	_ = child_text_content
	// Stub for ContentSecurityPolicy::should_elements_inline_type_behavior_be_blocked_by_content_security_policy(..., Style, ...).
	return false
}

pub fn (element &Element) document_or_shadow_root_style_sheets() &StyleSheetList {
	root_node := element.as_node().root()
	if shadow_root := root_node.as_shadow_root() {
		mut mutable_shadow_root := unsafe { &ShadowRoot(shadow_root) }
		return mutable_shadow_root.style_sheets()
	}
	mut document := unsafe { &Document(element.document()) }
	return document.style_sheets()
}

pub fn (element &Element) document_or_shadow_root_element_by_id_map() &ElementByIdMap {
	root_node := element.as_node().root()
	if shadow_root := root_node.as_shadow_root() {
		return shadow_root.element_by_id()
	}
	return element.document().element_by_id_map()
}

pub fn (element &Element) contributes_a_script_blocking_style_sheet() bool {
	_ = element
	return false
}

pub fn (element &Element) base_uri() string {
	return element.as_node().base_uri()
}

pub fn (element &Element) dispatch_event_simple(event_name string, bubbles bool) {
	element.as_node().dispatch_event_simple(event_name, bubbles)
}

pub fn (mut element Element) queue_an_element_task(source string, callback fn ()) {
	_ = source
	callback()
}

pub fn DOMImplementation.create(document &Document) &DOMImplementation {
	return &DOMImplementation{
		document_: document
	}
}

pub fn (mut implementation DOMImplementation) initialize() {}

pub fn (mut implementation DOMImplementation) visit_edges(mut visitor CellVisitor) {
	if implementation.document_ != unsafe { nil } {
		visitor.visit(implementation.document_)
	}
}

// https://dom.spec.whatwg.org/#dom-domimplementation-createdocument
pub fn (implementation &DOMImplementation) create_document(namespace_ ?string, qualified_name string, doctype ?&DocumentType) !&XMLDocument {
	// 1. Let document be a new XMLDocument.
	mut xml_document := XMLDocument.create(url_about_blank())
	xml_document.ready_for_post_load_tasks = true

	// 2. Let element be null.
	mut element := ?&Element(none)

	// 3. If qualifiedName is not the empty string, then create an element in the requested namespace.
	if qualified_name.len > 0 {
		element = xml_document.create_element_ns(namespace_, qualified_name)!
	}

	// 4. If doctype is non-null, append doctype to document.
	if dt := doctype {
		mut document_node := unsafe { &Node(xml_document) }
		document_node.append_child(unsafe { &Node(dt) })!
	}

	// 5. If element is non-null, append element to document.
	if el := element {
		mut document_node := unsafe { &Node(xml_document) }
		document_node.append_child(el.as_node())!
	}

	// 6. document's origin is this's associated document's origin.
	if implementation.document_ != unsafe { nil } {
		xml_document.set_origin(implementation.document_.origin())
	}

	// 7. document's content type is determined by namespace.
	ns := namespace_ or { '' }
	if ns == namespace_html_ {
		xml_document.content_type = 'application/xhtml+xml'
	} else if ns == namespace_svg_uri {
		xml_document.content_type = 'image/svg+xml'
	} else {
		xml_document.content_type = 'application/xml'
	}

	// 8. Return document.
	return xml_document
}

// https://dom.spec.whatwg.org/#dom-domimplementation-createhtmldocument
pub fn (implementation &DOMImplementation) create_html_document(title ?string) !&Document {
	// 1. Let doc be a new document that is an HTML document.
	// HTMLDocument is not a distinct type in this V DOM port yet; this creates a Document with HTML type/content.
	mut html_document := Document.create(url_about_blank())
	// 2. Set doc's content type to "text/html".
	html_document.set_content_type('text/html')
	html_document.set_document_type(.html)
	html_document.ready_for_post_load_tasks = true

	// 3. Append a new doctype, with "html" as its name and with its node document set to doc, to doc.
	mut doctype := DocumentType.create(html_document)
	doctype.set_name('html')
	mut document_node := unsafe { &Node(html_document) }
	document_node.append_child(doctype.as_node())!

	// 4. Append the result of creating an element given doc, "html", and the HTML namespace, to doc.
	mut html_element := create_element(html_document, 'html', namespace_html_, none, none, false)!
	document_node.append_child(html_element.as_node())!

	// 5. Append the result of creating an element given doc, "head", and the HTML namespace, to the html element created earlier.
	mut head_element := create_element(html_document, 'head', namespace_html_, none, none, false)!
	mut html_node := unsafe { &Node(html_element) }
	html_node.append_child(head_element.as_node())!

	// 6. If title is given:
	if value := title {
		// 1. Append the result of creating an element given doc, "title", and the HTML namespace, to the head element created earlier.
		mut title_element := create_element(html_document, 'title', namespace_html_, none, none,
			false)!
		text := new_text_node(html_document, value)
		mut head_node := unsafe { &Node(head_element) }
		head_node.append_child(title_element.as_node())!

		// 2. Append a new Text node, with its data set to title (which could be the empty string) and its node document set to doc, to the title element created earlier.
		mut title_node := unsafe { &Node(title_element) }
		title_node.append_child(text.as_node())!
	}

	// 7. Append the result of creating an element given doc, "body", and the HTML namespace, to the html element created earlier.
	mut body_element := create_element(html_document, 'body', namespace_html_, none, none, false)!
	html_node.append_child(body_element.as_node())!

	// 8. doc's origin is this's associated document's origin.
	if implementation.document_ != unsafe { nil } {
		html_document.set_origin(implementation.document_.origin())
	}

	// 9. Return doc.
	return html_document
}

// https://dom.spec.whatwg.org/#dom-domimplementation-createdocumenttype
pub fn (implementation &DOMImplementation) create_document_type(name string, public_id string, system_id string) !&DocumentType {
	// 1. If name is not a valid doctype name, then throw an InvalidCharacterError.
	if !is_valid_doctype_name(name) {
		return error('InvalidCharacterError: Invalid doctype name')
	}

	// 2. Return a new doctype, with name as its name, publicId as its public ID, and systemId as its system ID,
	// and with its node document set to the associated document of this.
	mut document_type := DocumentType.create(implementation.document_)
	document_type.set_name(name)
	document_type.set_public_id(public_id)
	document_type.set_system_id(system_id)
	return document_type
}

// https://dom.spec.whatwg.org/#dom-domimplementation-hasfeature
pub fn (implementation &DOMImplementation) has_feature() bool {
	_ = implementation
	// The hasFeature() method steps are to return true.
	return true
}

const html_unknown_element_names = ['applet', 'bgsound', 'blink', 'isindex', 'keygen', 'multicol',
	'nextid', 'spacer']

const html_known_element_names = ['a', 'abbr', 'acronym', 'address', 'area', 'article', 'aside',
	'audio', 'b', 'base', 'basefont', 'bdi', 'bdo', 'big', 'blockquote', 'body', 'br', 'button',
	'canvas', 'caption', 'center', 'cite', 'code', 'col', 'colgroup', 'data', 'datalist', 'dd',
	'del', 'details', 'dfn', 'dialog', 'dir', 'div', 'dl', 'dt', 'em', 'embed', 'fieldset',
	'figcaption', 'figure', 'font', 'footer', 'form', 'frame', 'frameset', 'h1', 'h2', 'h3', 'h4',
	'h5', 'h6', 'head', 'header', 'hgroup', 'hr', 'html', 'i', 'iframe', 'img', 'input', 'ins',
	'kbd', 'label', 'legend', 'li', 'link', 'main', 'map', 'mark', 'marquee', 'menu', 'meta', 'meter',
	'nav', 'nobr', 'noembed', 'noframes', 'noscript', 'object', 'ol', 'optgroup', 'option', 'output',
	'p', 'param', 'picture', 'plaintext', 'pre', 'progress', 'q', 'rb', 'rp', 'rt', 'rtc', 'ruby',
	's', 'samp', 'script', 'search', 'section', 'select', 'selectedcontent', 'slot', 'small',
	'source', 'span', 'strike', 'strong', 'style', 'sub', 'summary', 'sup', 'table', 'tbody', 'td',
	'template', 'textarea', 'tfoot', 'th', 'thead', 'time', 'title', 'tr', 'track', 'tt', 'u',
	'ul', 'var', 'video', 'wbr', 'xmp']

pub fn valid_local_names_for_given_html_element_interface(html_element_interface_name string) []string {
	return match html_element_interface_name {
		'HTMLAnchorElement' {
			['a']
		}
		'HTMLAreaElement' {
			['area']
		}
		'HTMLAudioElement' {
			['audio']
		}
		'HTMLBaseElement' {
			['base']
		}
		'HTMLBodyElement' {
			['body']
		}
		'HTMLBRElement' {
			['br']
		}
		'HTMLButtonElement' {
			['button']
		}
		'HTMLCanvasElement' {
			['canvas']
		}
		'HTMLDataElement' {
			['data']
		}
		'HTMLDataListElement' {
			['datalist']
		}
		'HTMLDetailsElement' {
			['details']
		}
		'HTMLDialogElement' {
			['dialog']
		}
		'HTMLDirectoryElement' {
			['dir']
		}
		'HTMLDivElement' {
			['div']
		}
		'HTMLDListElement' {
			['dl']
		}
		'HTMLEmbedElement' {
			['embed']
		}
		'HTMLFieldSetElement' {
			['fieldset']
		}
		'HTMLFontElement' {
			['font']
		}
		'HTMLFormElement' {
			['form']
		}
		'HTMLFrameElement' {
			['frame']
		}
		'HTMLFrameSetElement' {
			['frameset']
		}
		'HTMLHeadElement' {
			['head']
		}
		'HTMLHeadingElement' {
			['h1', 'h2', 'h3', 'h4', 'h5', 'h6']
		}
		'HTMLHRElement' {
			['hr']
		}
		'HTMLHtmlElement' {
			['html']
		}
		'HTMLIFrameElement' {
			['iframe']
		}
		'HTMLImageElement' {
			['img']
		}
		'HTMLInputElement' {
			['input']
		}
		'HTMLLabelElement' {
			['label']
		}
		'HTMLLegendElement' {
			['legend']
		}
		'HTMLLIElement' {
			['li']
		}
		'HTMLLinkElement' {
			['link']
		}
		'HTMLMapElement' {
			['map']
		}
		'HTMLMarqueeElement' {
			['marquee']
		}
		'HTMLMenuElement' {
			['menu']
		}
		'HTMLMetaElement' {
			['meta']
		}
		'HTMLMeterElement' {
			['meter']
		}
		'HTMLModElement' {
			['ins', 'del']
		}
		'HTMLOListElement' {
			['ol']
		}
		'HTMLObjectElement' {
			['object']
		}
		'HTMLOptGroupElement' {
			['optgroup']
		}
		'HTMLOptionElement' {
			['option']
		}
		'HTMLOutputElement' {
			['output']
		}
		'HTMLParagraphElement' {
			['p']
		}
		'HTMLParamElement' {
			['param']
		}
		'HTMLPictureElement' {
			['picture']
		}
		'HTMLPreElement' {
			['pre', 'listing', 'xmp']
		}
		'HTMLProgressElement' {
			['progress']
		}
		'HTMLQuoteElement' {
			['blockquote', 'q']
		}
		'HTMLScriptElement' {
			['script']
		}
		'HTMLSelectedContentElement' {
			['selectedcontent']
		}
		'HTMLSelectElement' {
			['select']
		}
		'HTMLSlotElement' {
			['slot']
		}
		'HTMLSourceElement' {
			['source']
		}
		'HTMLSpanElement' {
			['span']
		}
		'HTMLStyleElement' {
			['style']
		}
		'HTMLTableCaptionElement' {
			['caption']
		}
		'HTMLTableCellElement' {
			['td', 'th']
		}
		'HTMLTableColElement' {
			['colgroup', 'col']
		}
		'HTMLTableRowElement' {
			['tr']
		}
		'HTMLTableElement' {
			['table']
		}
		'HTMLTableSectionElement' {
			['tbody', 'thead', 'tfoot']
		}
		'HTMLTemplateElement' {
			['template']
		}
		'HTMLTextAreaElement' {
			['textarea']
		}
		'HTMLTimeElement' {
			['time']
		}
		'HTMLTitleElement' {
			['title']
		}
		'HTMLTrackElement' {
			['track']
		}
		'HTMLUListElement' {
			['ul']
		}
		'HTMLVideoElement' {
			['video']
		}
		'HTMLElement' {
			['article', 'search', 'section', 'nav', 'aside', 'hgroup', 'header', 'footer', 'address',
				'dt', 'dd', 'figure', 'figcaption', 'main', 'em', 'strong', 'small', 's', 'cite',
				'dfn', 'abbr', 'ruby', 'rt', 'rp', 'code', 'var', 'samp', 'kbd', 'sub', 'sup',
				'i', 'b', 'u', 'mark', 'bdi', 'bdo', 'wbr', 'summary', 'noscript', 'acronym',
				'basefont', 'big', 'center', 'nobr', 'noembed', 'noframes', 'plaintext', 'rb',
				'rtc', 'strike', 'tt']
		}
		else {
			[]
		}
	}
}

// https://html.spec.whatwg.org/multipage/dom.html#elements-in-the-dom:element-interface
pub fn is_unknown_html_element(tag_name string) bool {
	// NOTE: This is intentionally case-sensitive.
	if tag_name in html_unknown_element_names {
		return true
	}
	if tag_name in html_known_element_names {
		return false
	}
	if is_valid_custom_element_name(tag_name) {
		return false
	}
	return true
}

fn new_element_storage(document &Document, qualified_name QualifiedName) Element {
	return Element{
		ParentNode:     ParentNode{
			Node: Node{
				node_type: .element_node
				document_: document
			}
		}
		qualified_name: qualified_name
		doc_:           document
	}
}

fn new_html_element_storage(document &Document, qualified_name QualifiedName) HTMLElement {
	return HTMLElement{
		Element: new_element_storage(document, qualified_name)
	}
}

fn new_svg_element_storage(document &Document, qualified_name QualifiedName) SVGElement {
	return SVGElement{
		Element: new_element_storage(document, qualified_name)
	}
}

fn new_mathml_element_storage(document &Document, qualified_name QualifiedName) MathMLElement {
	return MathMLElement{
		Element: new_element_storage(document, qualified_name)
	}
}

fn create_html_element(document &Document, qualified_name QualifiedName) &Element {
	tag_name := qualified_name.local_name
	match tag_name {
		'a' {
			return unsafe {
				&Element(&HTMLAnchorElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'area' {
			return unsafe {
				&Element(&HTMLAreaElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'audio' {
			return unsafe {
				&Element(&HTMLAudioElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'base' {
			return unsafe {
				&Element(&HTMLBaseElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'body' {
			return unsafe {
				&Element(&HTMLBodyElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'br' {
			return unsafe {
				&Element(&HTMLBRElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'button' {
			return unsafe {
				&Element(&HTMLButtonElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'canvas' {
			return unsafe {
				&Element(&HTMLCanvasElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'data' {
			return unsafe {
				&Element(&HTMLDataElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'datalist' {
			return unsafe {
				&Element(&HTMLDataListElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'details' {
			return unsafe {
				&Element(&HTMLDetailsElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'dialog' {
			return unsafe {
				&Element(&HTMLDialogElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'dir' {
			return unsafe {
				&Element(&HTMLDirectoryElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'div' {
			return unsafe {
				&Element(&HTMLDivElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'dl' {
			return unsafe {
				&Element(&HTMLDListElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'embed' {
			return unsafe {
				&Element(&HTMLEmbedElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'fieldset' {
			return unsafe {
				&Element(&HTMLFieldSetElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'font' {
			return unsafe {
				&Element(&HTMLFontElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'form' {
			return unsafe {
				&Element(&HTMLFormElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'frame' {
			return unsafe {
				&Element(&HTMLFrameElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'frameset' {
			return unsafe {
				&Element(&HTMLFrameSetElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'head' {
			return unsafe {
				&Element(&HTMLHeadElement{
					Element: new_element_storage(document, qualified_name)
				})
			}
		}
		'h1', 'h2', 'h3', 'h4', 'h5', 'h6' {
			return unsafe {
				&Element(&HTMLHeadingElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'hr' {
			return unsafe {
				&Element(&HTMLHRElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'html' {
			return unsafe {
				&Element(&HTMLHtmlElement{
					Element: new_element_storage(document, qualified_name)
				})
			}
		}
		'iframe' {
			return unsafe {
				&Element(&HTMLIFrameElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'img' {
			return unsafe {
				&Element(&HTMLImageElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'input' {
			return unsafe {
				&Element(&HTMLInputElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'label' {
			return unsafe {
				&Element(&HTMLLabelElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'legend' {
			return unsafe {
				&Element(&HTMLLegendElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'li' {
			return unsafe {
				&Element(&HTMLLIElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'link' {
			return unsafe {
				&Element(&HTMLLinkElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'map' {
			return unsafe {
				&Element(&HTMLMapElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'marquee' {
			return unsafe {
				&Element(&HTMLMarqueeElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'menu' {
			return unsafe {
				&Element(&HTMLMenuElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'meta' {
			return unsafe {
				&Element(&HTMLMetaElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'meter' {
			return unsafe {
				&Element(&HTMLMeterElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'ins', 'del' {
			return unsafe {
				&Element(&HTMLModElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'object' {
			return unsafe {
				&Element(&HTMLObjectElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'ol' {
			return unsafe {
				&Element(&HTMLOListElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'optgroup' {
			return unsafe {
				&Element(&HTMLOptGroupElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'option' {
			return unsafe {
				&Element(&HTMLOptionElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'output' {
			return unsafe {
				&Element(&HTMLOutputElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'p' {
			return unsafe {
				&Element(&HTMLParagraphElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'param' {
			return unsafe {
				&Element(&HTMLParamElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'picture' {
			return unsafe {
				&Element(&HTMLPictureElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'pre', 'listing', 'xmp' {
			return unsafe {
				&Element(&HTMLPreElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'progress' {
			return unsafe {
				&Element(&HTMLProgressElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'blockquote', 'q' {
			return unsafe {
				&Element(&HTMLQuoteElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'script' {
			return unsafe {
				&Element(&HTMLScriptElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'selectedcontent' {
			return unsafe {
				&Element(&HTMLSelectedContentElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'select' {
			return unsafe {
				&Element(&HTMLSelectElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'slot' {
			return unsafe {
				&Element(&HTMLSlotElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'source' {
			return unsafe {
				&Element(&HTMLSourceElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'span' {
			return unsafe {
				&Element(&HTMLSpanElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'style' {
			return unsafe {
				&Element(&HTMLStyleElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'summary' {
			return unsafe {
				&Element(&HTMLSummaryElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'caption' {
			return unsafe {
				&Element(&HTMLTableCaptionElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'td', 'th' {
			return unsafe {
				&Element(&HTMLTableCellElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'colgroup', 'col' {
			return unsafe {
				&Element(&HTMLTableColElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'table' {
			return unsafe {
				&Element(&HTMLTableElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'tr' {
			return unsafe {
				&Element(&HTMLTableRowElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'tbody', 'thead', 'tfoot' {
			return unsafe {
				&Element(&HTMLTableSectionElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'template' {
			return unsafe {
				&Element(&HTMLTemplateElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'textarea' {
			return unsafe {
				&Element(&HTMLTextAreaElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'time' {
			return unsafe {
				&Element(&HTMLTimeElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'title' {
			return unsafe {
				&Element(&HTMLTitleElement{
					Element: new_element_storage(document, qualified_name)
				})
			}
		}
		'track' {
			return unsafe {
				&Element(&HTMLTrackElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'ul' {
			return unsafe {
				&Element(&HTMLUListElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		'video' {
			return unsafe {
				&Element(&HTMLVideoElement{
					HTMLElement: new_html_element_storage(document, qualified_name)
				})
			}
		}
		else {}
	}

	if is_unknown_html_element(tag_name) {
		return unsafe {
			&Element(&HTMLUnknownElement{
				HTMLElement: new_html_element_storage(document, qualified_name)
			})
		}
	}
	return unsafe {
		&Element(&HTMLElement{
			Element: new_element_storage(document, qualified_name)
		})
	}
}

fn create_svg_element(document &Document, qualified_name QualifiedName) &Element {
	local_name := qualified_name.local_name
	match local_name {
		'svg' {
			return unsafe {
				&Element(&SVGSVGElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'circle' {
			return unsafe {
				&Element(&SVGCircleElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'desc' {
			return unsafe {
				&Element(&SVGDescElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'ellipse' {
			return unsafe {
				&Element(&SVGEllipseElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'feBlend' {
			return unsafe {
				&Element(&SVGFEBlendElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'feColorMatrix' {
			return unsafe {
				&Element(&SVGFEColorMatrixElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'feComponentTransfer' {
			return unsafe {
				&Element(&SVGFEComponentTransferElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'feComposite' {
			return unsafe {
				&Element(&SVGFECompositeElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'feDisplacementMap' {
			return unsafe {
				&Element(&SVGFEDisplacementMapElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'feDropShadow' {
			return unsafe {
				&Element(&SVGFEDropShadowElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'feFlood' {
			return unsafe {
				&Element(&SVGFEFloodElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'feFuncA' {
			return unsafe {
				&Element(&SVGFEFuncAElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'feFuncB' {
			return unsafe {
				&Element(&SVGFEFuncBElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'feFuncG' {
			return unsafe {
				&Element(&SVGFEFuncGElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'feFuncR' {
			return unsafe {
				&Element(&SVGFEFuncRElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'feGaussianBlur' {
			return unsafe {
				&Element(&SVGFEGaussianBlurElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'feImage' {
			return unsafe {
				&Element(&SVGFEImageElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'feMerge' {
			return unsafe {
				&Element(&SVGFEMergeElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'feMergeNode' {
			return unsafe {
				&Element(&SVGFEMergeNodeElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'feMorphology' {
			return unsafe {
				&Element(&SVGFEMorphologyElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'feOffset' {
			return unsafe {
				&Element(&SVGFEOffsetElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'feTurbulence' {
			return unsafe {
				&Element(&SVGFETurbulenceElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'filter' {
			return unsafe {
				&Element(&SVGFilterElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'line' {
			return unsafe {
				&Element(&SVGLineElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'linearGradient' {
			return unsafe {
				&Element(&SVGLinearGradientElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'mask' {
			return unsafe {
				&Element(&SVGMaskElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'metadata' {
			return unsafe {
				&Element(&SVGMetadataElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'path' {
			return unsafe {
				&Element(&SVGPathElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'pattern' {
			return unsafe {
				&Element(&SVGPatternElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'polygon' {
			return unsafe {
				&Element(&SVGPolygonElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'polyline' {
			return unsafe {
				&Element(&SVGPolylineElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'radialGradient' {
			return unsafe {
				&Element(&SVGRadialGradientElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'rect' {
			return unsafe {
				&Element(&SVGRectElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'g' {
			return unsafe {
				&Element(&SVGGElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'stop' {
			return unsafe {
				&Element(&SVGStopElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'style' {
			return unsafe {
				&Element(&SVGStyleElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'symbol' {
			return unsafe {
				&Element(&SVGSymbolElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'text' {
			return unsafe {
				&Element(&SVGTextElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'textPath' {
			return unsafe {
				&Element(&SVGTextPathElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'title' {
			return unsafe {
				&Element(&SVGTitleElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'tspan' {
			return unsafe {
				&Element(&SVGTSpanElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'use' {
			return unsafe {
				&Element(&SVGUseElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'script' {
			return unsafe {
				&Element(&SVGScriptElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'view' {
			return unsafe {
				&Element(&SVGViewElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'a' {
			return unsafe {
				&Element(&SVGAElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		'image' {
			return unsafe {
				&Element(&SVGImageElement{
					SVGElement: new_svg_element_storage(document, qualified_name)
				})
			}
		}
		else {}
	}

	lowercase_local_name := to_ascii_lowercase(local_name)
	if lowercase_local_name == 'clippath' {
		return unsafe {
			&Element(&SVGClipPathElement{
				SVGElement: new_svg_element_storage(document, qualified_name)
			})
		}
	}
	if lowercase_local_name == 'defs' {
		return unsafe {
			&Element(&SVGDefsElement{
				SVGElement: new_svg_element_storage(document, qualified_name)
			})
		}
	}
	if lowercase_local_name == 'foreignobject' {
		return unsafe {
			&Element(&SVGForeignObjectElement{
				SVGElement: new_svg_element_storage(document, qualified_name)
			})
		}
	}

	// https://svgwg.org/svg2-draft/types.html#ElementsInTheSVGDOM
	// Elements in the SVG namespace whose local name does not match an element defined in any
	// specification supported by the software must nonetheless implement the SVGElement interface.
	return unsafe {
		&Element(&SVGElement{
			Element: new_element_storage(document, qualified_name)
		})
	}
}

fn create_mathml_element(document &Document, qualified_name QualifiedName) &Element {
	local_name := qualified_name.local_name
	if local_name == 'mi' {
		return unsafe {
			&Element(&MathMLMiElement{
				MathMLElement: new_mathml_element_storage(document, qualified_name)
			})
		}
	}
	if local_name == 'mspace' {
		return unsafe {
			&Element(&MathMLMspaceElement{
				MathMLElement: new_mathml_element_storage(document, qualified_name)
			})
		}
	}

	// https://w3c.github.io/mathml-core/#dom-and-javascript
	// All the nodes representing MathML elements in the DOM must implement, and expose to scripts,
	// the following MathMLElement interface.
	return unsafe {
		&Element(&MathMLElement{
			Element: new_element_storage(document, qualified_name)
		})
	}
}

// https://dom.spec.whatwg.org/#concept-create-element
pub fn create_element(document &Document, local_name string, namespace_ ?string, prefix ?string, is_value ?string, synchronous_custom_elements_flag bool) !&Element {
	// 1. Let result be null.
	// NOTE: We collapse this into just returning an element where necessary.

	// 2. If registry is "default", then set registry to the result of looking up a custom element registry given document.
	// The V port's custom element definition set is currently stored on Document.

	// 3. Let definition be the result of looking up a custom element definition given registry, document, namespace, localName, and is.
	if definition := document.lookup_custom_element_definition(namespace_, local_name, is_value) {
		// 4. If definition is non-null, and definition's name is not equal to its local name (i.e., definition represents a customized built-in element), then:
		if definition.name() != definition.local_name() {
			mut element := create_element_internal(document, local_name, namespace_html_, prefix,
				.undefined_, is_value)
			if synchronous_custom_elements_flag {
				element.upgrade_element(definition) or {
					// If this step threw an exception, report it and set result's custom element state to "failed".
					report_custom_element_upgrade_exception(definition, err.str())
					element.set_custom_element_state(.failed)
				}
			} else {
				element.enqueue_a_custom_element_upgrade_reaction(definition)
			}
			return element
		}

		// 5. Otherwise, if definition is non-null, then:
		// The C++ implementation constructs through the JavaScript constructor for synchronous
		// autonomous custom elements. Constructor execution is outside this V DOM port, so the
		// translated path creates the element and performs the available upgrade bookkeeping.
		mut element := create_element_internal(document, local_name, namespace_html_, prefix,
			.undefined_, none)
		if synchronous_custom_elements_flag {
			element.upgrade_element(definition) or {
				// If any of these steps threw an exception, report it and set result to an HTMLUnknownElement in the failed state.
				report_custom_element_upgrade_exception(definition, err.str())
				mut fallback_element := unsafe {
					&Element(&HTMLUnknownElement{
						HTMLElement: new_html_element_storage(document, QualifiedName{
							local_name:            local_name
							prefix_:               prefix
							namespace_:            namespace_html_
							lowercased_local_name: to_ascii_lowercase(local_name)
						})
					})
				}
				fallback_element.set_custom_element_state(.failed)
				return fallback_element
			}
		} else {
			element.enqueue_a_custom_element_upgrade_reaction(definition)
		}
		return element
	}

	// 6. Otherwise:
	// 1. Let interface be the element interface for localName and namespace.
	// 2. Set result to the result of creating an element internal given document, interface, localName, namespace,
	//    prefix, "uncustomized", is, and registry.
	mut element := create_element_internal(document, local_name, namespace_, prefix, .uncustomized,
		is_value)

	// 3. If namespace is the HTML namespace, and either localName is a valid custom element name or is is non-null,
	//    then set result's custom element state to "undefined".
	ns := namespace_ or { '' }
	if ns == namespace_html_ && (is_valid_custom_element_name(local_name) || is_value != none) {
		element.set_custom_element_state(.undefined_)
	}
	return element
}

fn report_custom_element_upgrade_exception(definition &CustomElementDefinition, message string) {
	_ = definition
	_ = message
	// Stub for reporting the exception for definition's constructor's associated global object.
}

// https://dom.spec.whatwg.org/#create-an-element-internal
pub fn create_element_internal(document &Document, local_name string, namespace_ ?string, prefix ?string, state CustomElementState, is_value ?string) &Element {
	qualified_name := QualifiedName{
		local_name:            local_name
		prefix_:               prefix
		namespace_:            namespace_
		lowercased_local_name: to_ascii_lowercase(local_name)
	}
	ns := namespace_ or { '' }
	mut element := if ns == namespace_html_ {
		create_html_element(document, qualified_name)
	} else if ns == namespace_svg_uri {
		create_svg_element(document, qualified_name)
	} else if ns == 'http://www.w3.org/1998/Math/MathML' {
		create_mathml_element(document, qualified_name)
	} else {
		Element.new(document, qualified_name)
	}
	element.set_custom_element_state(state)
	element.is_value = is_value
	return element
}

pub fn (mut id_map ElementByIdMap) add(element_id string, element &Element) {
	mut elements := id_map.elements_by_id[element_id] or { []&Element{} }
	for existing in elements {
		if existing == element {
			return
		}
	}
	elements << element
	id_map.elements_by_id[element_id] = elements
	if elements.len == 1 {
		id_map.cached_first_element_by_id[element_id] = element
	} else {
		id_map.cached_first_element_by_id.delete(element_id)
	}
}

pub fn (mut id_map ElementByIdMap) remove(element_id string, element &Element) {
	mut elements := id_map.elements_by_id[element_id] or { return }
	elements = elements.filter(it != unsafe { nil } && it != element)
	if elements.len == 0 {
		id_map.elements_by_id.delete(element_id)
		id_map.cached_first_element_by_id.delete(element_id)
		return
	}
	if cached := id_map.cached_first_element_by_id[element_id] {
		if cached == element {
			id_map.cached_first_element_by_id.delete(element_id)
		}
	}
	id_map.elements_by_id[element_id] = elements
}

pub fn (id_map &ElementByIdMap) get(element_id string, scope_root &Node) ?&Element {
	_ = id_map.elements_by_id[element_id] or { return none }

	if element := id_map.cached_first_element_by_id[element_id] {
		return element
	}

	first_element := first_element_with_id_in_inclusive_subtree(scope_root, element_id) or {
		return none
	}
	mut mutable_id_map := unsafe { &ElementByIdMap(id_map) }
	mutable_id_map.cached_first_element_by_id[element_id] = first_element
	return first_element
}

fn first_element_with_id_in_inclusive_subtree(root &Node, element_id string) ?&Element {
	if element := root.as_element() {
		if id := element.id() {
			if id == element_id {
				return element
			}
		}
	}
	for child in root.children {
		if found := first_element_with_id_in_inclusive_subtree(child, element_id) {
			return found
		}
	}
	return none
}

pub fn (id_map &ElementByIdMap) for_each_element_with_id(element_id string, scope_root &Node, callback fn (&Element)) {
	if elements := id_map.elements_by_id[element_id] {
		if elements.len == 1 {
			callback(elements[0])
			return
		}
	} else {
		return
	}
	scope_root.for_each_in_inclusive_subtree(fn [element_id, callback] (node &Node) TraversalDecision {
		element := node.as_element() or { return .@continue }
		if id := element.id() {
			if id == element_id {
				callback(element)
			}
		}
		return .@continue
	})
}

pub fn (id_map &ElementByIdMap) for_each_id(callback fn (string)) {
	for id, _ in id_map.elements_by_id {
		callback(id)
	}
}

fn json_escape_string(value string) string {
	mut builder := strings.new_builder(value.len)
	for ch in value {
		match ch {
			`"` { builder.write_string('\\"') }
			`\\` { builder.write_string('\\\\') }
			`\n` { builder.write_string('\\n') }
			`\r` { builder.write_string('\\r') }
			`\t` { builder.write_string('\\t') }
			else { builder.write_u8(ch) }
		}
	}
	return builder.str()
}

pub fn AccessibilityTreeNode.create(document ?&Document, value ?&Node) &AccessibilityTreeNode {
	_ = document
	return &AccessibilityTreeNode{
		value_: value
	}
}

pub fn (node &AccessibilityTreeNode) value() ?&Node {
	return node.value_
}

pub fn (mut node AccessibilityTreeNode) set_value(value ?&Node) {
	node.value_ = value
}

pub fn (node &AccessibilityTreeNode) children() []&AccessibilityTreeNode {
	return node.children_.clone()
}

pub fn (mut node AccessibilityTreeNode) append_child(child &AccessibilityTreeNode) {
	node.children_ << child
}

pub fn (node &AccessibilityTreeNode) serialize_tree_as_json(mut object strings.Builder, document &Document) {
	value := node.value() or {
		object.write_string('{}')
		return
	}
	if value.is_element() {
		element := value.as_element() or {
			object.write_string('{}')
			return
		}
		object.write_string('{"type":"element"')
		name := element.accessible_name(document, .no) or { '' }
		description := element.accessible_description(document) or { '' }
		object.write_string(',"name":"${json_escape_string(name)}"')
		object.write_string(',"description":"${json_escape_string(description)}"')
		object.write_string(',"role":""')
	} else if value.is_text() {
		object.write_string('{"type":"text"')
		object.write_string(',"name":"${json_escape_string(value.text_content() or { '' })}"')
		object.write_string(',"role":"text leaf"')
	} else {
		object.write_string('{"type":"node"')
	}
	object.write_string(',"id":${value.unique_id().value()}')
	if node.children_.len > 0 {
		object.write_string(',"children":[')
		mut wrote_child := false
		for child in node.children_ {
			if child_value := child.value() {
				if child_value.is_uninteresting_whitespace_node() {
					continue
				}
			}
			if wrote_child {
				object.write_string(',')
			}
			child.serialize_tree_as_json(mut object, document)
			wrote_child = true
		}
		object.write_string(']')
	}
	object.write_string('}')
}

pub fn (mut node AccessibilityTreeNode) visit_edges(mut visitor CellVisitor) {
	if value := node.value_ {
		visitor.visit(value)
	}
	for child in node.children_ {
		visitor.visit(child)
	}
}

pub struct ObservableArray {
pub mut:
	values []&CSSStyleSheet
}

pub fn (mut array ObservableArray) clear() {
	array.values.clear()
}

pub fn (mut array ObservableArray) append(style_sheet &CSSStyleSheet) {
	array.values << style_sheet
}

pub fn (array &ObservableArray) items() []&CSSStyleSheet {
	return array.values
}

pub fn create_adopted_style_sheets_list(document_or_shadow_root &Node) &ObservableArray {
	_ = document_or_shadow_root
	return &ObservableArray{}
}

pub struct DocumentLoadEventDelayer {
mut:
	document &Document = unsafe { nil }
	active   bool
}

pub fn DocumentLoadEventDelayer.new(mut document Document) DocumentLoadEventDelayer {
	document.increment_number_of_things_delaying_the_load_event()
	return DocumentLoadEventDelayer{
		document: document
		active:   true
	}
}

pub fn (mut delayer DocumentLoadEventDelayer) move_from(mut other DocumentLoadEventDelayer) {
	delayer.document = other.document
	delayer.active = other.active
	other.document = unsafe { nil }
	other.active = false
}

pub fn (mut delayer DocumentLoadEventDelayer) finish() {
	if delayer.active && delayer.document != unsafe { nil } {
		mut document := unsafe { &Document(delayer.document) }
		document.decrement_number_of_things_delaying_the_load_event()
	}
	delayer.document = unsafe { nil }
	delayer.active = false
}

pub type ByteBuffer = []u8
pub type ReadonlyBytes = []u8

pub struct MimeType {
pub mut:
	essence_ string
	type_    string
}

pub fn (mime MimeType) essence() string {
	return mime.essence_
}

pub fn (mime MimeType) type_() string {
	return mime.type_
}

pub fn (mime MimeType) is_html() bool {
	return mime.essence_ == 'text/html' || mime.essence_ == 'application/xhtml+xml'
}

pub fn (mime MimeType) is_xml() bool {
	return mime.essence_.ends_with('+xml') || mime.essence_ in ['application/xml', 'text/xml']
}

pub fn (mime MimeType) is_javascript() bool {
	return mime.essence_ in ['text/javascript', 'application/javascript', 'application/ecmascript']
}

pub fn (mime MimeType) is_json() bool {
	return mime.essence_ == 'application/json' || mime.essence_.ends_with('+json')
}

pub fn (mime MimeType) is_image() bool {
	return mime.type_ == 'image'
}

pub fn (mime MimeType) is_audio_or_video() bool {
	return mime.type_ == 'audio' || mime.type_ == 'video'
}

pub fn mime_type_from_essence(essence string) MimeType {
	typ := if essence.contains('/') { essence.all_before('/') } else { essence }
	return MimeType{
		essence_: essence
		type_:    typ
	}
}

fn resolve_session_history_processing_signal(signal_to_continue_session_history_processing VoidPtr) {
	_ = signal_to_continue_session_history_processing
}

fn run_encoding_sniffing_algorithm(document &Document, data ByteBuffer, mime MimeType) string {
	_ = document
	_ = data
	_ = mime
	// Stub for HTML::run_encoding_sniffing_algorithm until the HTML parser/text codec ports exist.
	return 'UTF-8'
}

fn text_decoder_validate(data ByteBuffer, content_encoding ?string) bool {
	_ = data
	_ = content_encoding
	// Stub for TextCodec::Decoder::validate().
	return true
}

fn text_decoder_to_utf8(data ByteBuffer, content_encoding ?string) !string {
	_ = content_encoding
	// Stub for TextCodec::Decoder::to_utf8().
	return data.bytestr()
}

fn xml_decoder_label(document &Document, data ByteBuffer, mime MimeType, content_encoding ?string) string {
	if encoding := content_encoding {
		return encoding
	}
	return run_encoding_sniffing_algorithm(document, data, mime)
}

fn mime_type_parameter(mime MimeType, name string) ?string {
	_ = mime
	_ = name
	// Stub for MimeSniff::MimeType::parameters() until MIME parameters are represented.
	return none
}

fn parse_xml_document_into(document &Document, source string) bool {
	_ = document
	_ = source
	// Stub for XML::Parser + XMLDocumentBuilder. The DOM-side caller still follows the C++ control flow.
	return true
}

fn html_parser_the_end(document &Document) {
	mut mutable_document := unsafe { &Document(document) }
	mutable_document.completely_finish_loading()
}

fn html_parser_run_with_uncertain_encoding(document &Document, data ByteBuffer, mime MimeType, url URL) {
	_ = mime
	_ = url
	mut mutable_document := unsafe { &Document(document) }
	mutable_document.source = data.bytestr()
	html_parser_the_end(document)
}

fn html_parser_run_text_document(document &Document, data ByteBuffer, mime MimeType, url URL) string {
	encoding := run_encoding_sniffing_algorithm(document, data, mime)
	mut mutable_document := unsafe { &Document(document) }
	// Stub for the tokenizer sequence that emits <pre>\n, switches to PLAINTEXT,
	// inserts the body bytes, inserts EOF, and runs the parser.
	mutable_document.source = '<pre>\n${data.bytestr()}'
	_ = url
	html_parser_the_end(document)
	return encoding
}

fn sniff_resource_type(sniff_bytes ReadonlyBytes, supplied_type MimeType) MimeType {
	_ = sniff_bytes
	// Stub for MimeSniff::Resource::sniff(..., Browsing, supplied_type).
	return supplied_type
}

fn navigation_response_mime_type(navigation_params &NavigationParams) MimeType {
	essence := if navigation_params.response_mime_type == '' {
		'text/html'
	} else {
		navigation_params.response_mime_type
	}
	return mime_type_from_essence(essence)
}

fn navigation_response_url(navigation_params &NavigationParams) URL {
	if current_url := navigation_params.request_current_url {
		return current_url
	}
	return navigation_params.response_url
}

fn basename_from_url_string(url_string string) string {
	mut value := url_string
	for value.len > 1 && value.ends_with('/') {
		value = value[..value.len - 1]
	}
	index := value.last_index('/') or { return value }
	return value[index + 1..]
}

fn append_title_to_document_head(document &Document, document_url string) ! {
	title := basename_from_url_string(document_url)
	title_element := create_element(document, 'title', namespace_html_, none, none, false)!
	head := document.head() or { return }
	head_element := unsafe { &Element(head) }
	mut head_node := head_element.as_node()
	head_node.append_child(title_element.as_node())!
	mut title_node := title_element.as_node()
	title_node.append_child(new_text_node(document, title).as_node())!
}

fn append_media_document_style(document &Document) ! {
	style_element := create_element(document, 'style', namespace_html_, none, none, false)!
	mut style_node := style_element.as_node()
	style_node.string_replace_all('
        :root {
            background-color: #222;
        }
        img, video, audio {
            position: absolute;
            inset: 0;
            max-width: 100vw;
            max-height: 100vh;
            margin: auto;
        }
        img {
            background-color: #fff;
        }
    ')
	head := document.head() or { return }
	head_element := unsafe { &Element(head) }
	mut head_node := head_element.as_node()
	head_node.append_child(style_element.as_node())!
}

fn convert_to_xml_error_document(mut document Document, error_string string) {
	html_element := create_element(document, 'html', namespace_html_, none, none, false) or {
		return
	}
	body_element := create_element(document, 'body', namespace_html_, none, none, false) or {
		return
	}
	mut html_node := unsafe { &Node(html_element) }
	html_node.append_child(body_element.as_node()) or {}
	mut body_node := unsafe { &Node(body_element) }
	body_node.append_child(new_text_node(document, error_string).as_node()) or {}
	document.remove_all_children(true)
	mut document_node := unsafe { &Node(&document) }
	document_node.append_child(html_element.as_node()) or {}
}

pub fn build_xml_document(mut document Document, data ByteBuffer, content_encoding ?string) bool {
	// The actual HTTP headers and other metadata, not the headers as mutated or implied by the algorithms given in this specification,
	// are the ones that must be used when determining the character encoding according to the rules given in the above specifications.
	encoding := xml_decoder_label(&document, data, mime_type_from_essence('application/xml'),
		content_encoding)
	if !text_decoder_validate(data, encoding) {
		convert_to_xml_error_document(mut document,
			'XML Document contains improperly-encoded characters')
		return false
	}
	source := text_decoder_to_utf8(data, encoding) or {
		convert_to_xml_error_document(mut document, 'Failed to decode XML document: ${err}')
		return false
	}
	document.source = source
	return parse_xml_document_into(&document, source)
}

// https://html.spec.whatwg.org/multipage/document-lifecycle.html#navigate-html
fn load_html_document(navigation_params &NavigationParams, signal_to_continue_session_history_processing VoidPtr) !&Document {
	// 1. Let document be the result of creating and initializing a Document object given "html", "text/html", and navigationParams.
	mut document := Document.create_and_initialize(.html, 'text/html', navigation_params)!

	// 2. If document's URL is about:blank, then populate with html/head/body given document.
	// FIXME: The additional check for a non-empty body fixes issues with loading javascript urls in iframes, which
	//        default to an "about:blank" url. Is this a spec bug?
	if document.url_string() == 'about:blank' && navigation_params.response_body.len == 0 {
		document.populate_with_html_head_and_body()!
		// NB: Nothing else is added to the document, so mark it as loaded and resolve the signal_to_continue_session_history_processing.
		resolve_session_history_processing_signal(signal_to_continue_session_history_processing)
		html_parser_the_end(document)
	} else {
		// FIXME: Parse as we receive the document data, instead of waiting for the whole document to be fetched first.
		resolve_session_history_processing_signal(signal_to_continue_session_history_processing)
		html_parser_run_with_uncertain_encoding(document, navigation_params.response_body,
			navigation_response_mime_type(navigation_params),
			navigation_response_url(navigation_params))
	}

	// 4. Return document.
	return document
}

// https://html.spec.whatwg.org/multipage/document-lifecycle.html#read-xml
fn load_xml_document(navigation_params &NavigationParams, type_ MimeType, signal_to_continue_session_history_processing VoidPtr) !&Document {
	// When faced with displaying an XML file inline, create and initialize a Document object document,
	// given "xml", type, and navigationParams, and return that Document.
	mut document := Document.create_and_initialize(.xml, type_.essence(), navigation_params)!

	// FIXME: Actually follow the spec! This is just the ad-hoc code we had before, modified somewhat.
	content_encoding := mime_type_parameter(type_, 'charset')
	encoding := xml_decoder_label(document, navigation_params.response_body, type_,
		content_encoding)
	if !text_decoder_validate(navigation_params.response_body, encoding) {
		convert_to_xml_error_document(mut document,
			'XML Document contains improperly-encoded characters')
		// NB: This ensures that the `load` event gets fired for the frame loading this document.
		document.completely_finish_loading()
		// NB: If document is part of a session history entry's traversal, resolve the signal_to_continue_session_history_processing.
		resolve_session_history_processing_signal(signal_to_continue_session_history_processing)
		return document
	}

	source := text_decoder_to_utf8(navigation_params.response_body, encoding) or {
		convert_to_xml_error_document(mut document, 'Failed to decode XML document: ${err}')
		// NB: This ensures that the `load` event gets fired for the frame loading this document.
		document.completely_finish_loading()
		// NB: If document is part of session history traversal, resolve the signal_to_continue_session_history_processing.
		resolve_session_history_processing_signal(signal_to_continue_session_history_processing)
		return document
	}

	// NB: If document is part of session history traversal, resolve the signal_to_continue_session_history_processing.
	resolve_session_history_processing_signal(signal_to_continue_session_history_processing)
	document.source = source
	if !parse_xml_document_into(document, source) {
		convert_to_xml_error_document(mut document, 'Failed to parse XML document')
		// NB: XMLDocumentBuilder ensures that the `load` event gets fired. We don't need to do anything else here.
	}

	return document
}

// https://html.spec.whatwg.org/multipage/document-lifecycle.html#navigate-text
fn load_text_document(navigation_params &NavigationParams, type_ MimeType, signal_to_continue_session_history_processing VoidPtr) !&Document {
	// 1. Let document be the result of creating and initializing a Document object given "html", type, and navigationParams.
	mut document := Document.create_and_initialize(.html, type_.essence(), navigation_params)!

	// 2. Set document's parser cannot change the mode flag to true.
	document.parser_cannot_change_the_mode = true

	// 3. Set document's mode to "no-quirks".
	document.set_quirks_mode(.no)

	// 4. Create an HTML parser and associate it with the document. Act as if the tokenizer had emitted a start tag token
	//    with the tag name "pre" followed by a single U+000A LINE FEED (LF) character, and switch the HTML parser's tokenizer
	//    to the PLAINTEXT state.
	resolve_session_history_processing_signal(signal_to_continue_session_history_processing)
	encoding := html_parser_run_text_document(document, navigation_params.response_body, type_,
		navigation_response_url(navigation_params))
	document.set_encoding(encoding)

	// 5. User agents may add content to the head element of document, e.g., linking to a style sheet, providing
	//    script, or giving the document a title.
	append_title_to_document_head(document, document.url_string()) or {}

	// 6. Return document.
	return document
}

// https://html.spec.whatwg.org/multipage/document-lifecycle.html#navigate-media
fn load_media_document(navigation_params &NavigationParams, type_ MimeType, signal_to_continue_session_history_processing VoidPtr) !&Document {
	// 1. Let document be the result of creating and initializing a Document object given "html", type, and navigationParams.
	mut document := Document.create_and_initialize(.html, type_.essence(), navigation_params)!

	// 2. Set document's mode to "no-quirks".
	document.set_quirks_mode(.no)

	// 3. Populate with html/head/body given document.
	document.populate_with_html_head_and_body()!

	// 4. Append an element host element for the media, as described below, to the body element.
	// 5. Set the appropriate attribute of the element host element, as described below, to the address of the image,
	//    video, or audio resource.
	// 6. User agents may add content to the head element of document, or attributes to host element, e.g., to link
	//    to a style sheet, to provide a script, to give the document a title, or to make the media autoplay.
	append_media_document_style(document) or {}
	url_string := document.url_string()
	mut host_element := ?&Element(none)
	if type_.is_image() {
		mut img_element := create_element(document, 'img', namespace_html_, none, none, false)!
		img_element.set_attribute_value('src', url_string)
		host_element = img_element
	} else if type_.type_() == 'video' {
		mut video_element := create_element(document, 'video', namespace_html_, none, none, false)!
		video_element.set_attribute_value('src', url_string)
		video_element.set_attribute_value('autoplay', '')
		video_element.set_attribute_value('controls', '')
		host_element = video_element
	} else if type_.type_() == 'audio' {
		mut audio_element := create_element(document, 'audio', namespace_html_, none, none, false)!
		audio_element.set_attribute_value('src', url_string)
		audio_element.set_attribute_value('autoplay', '')
		audio_element.set_attribute_value('controls', '')
		host_element = audio_element
	} else {
		// FIXME: According to https://mimesniff.spec.whatwg.org/#audio-or-video-mime-type we might have to deal with
		//        "application/ogg" and figure out whether it's audio or video.
		panic('VERIFY_NOT_REACHED')
	}
	if media_element := host_element {
		body := document.body() or { return document }
		body_element := unsafe { &Element(body) }
		mut body_node := body_element.as_node()
		body_node.append_child(media_element.as_node())!
		append_title_to_document_head(document, url_string) or {}
	}

	// FIXME: 7. Process link headers given document, navigationParams's response, and "media".

	// 8. Act as if the user agent had stopped parsing document.
	// FIXME: We should not need to force the media file to load before saying that parsing has completed!
	//        However, if we don't, then we get stuck in HTMLParser::the_end() waiting for the media file to load, which
	//        never happens.
	resolve_session_history_processing_signal(signal_to_continue_session_history_processing)
	html_parser_the_end(document)

	// 9. Return document.
	return document
}

pub fn can_load_document_with_type(type_ MimeType) bool {
	if type_.is_html() || type_.is_xml() {
		return true
	}
	if type_.is_javascript() || type_.is_json()
		|| type_.essence() in ['text/css', 'text/plain', 'text/vtt', 'multipart/x-mixed-replace', 'application/pdf', 'text/pdf', 'text/markdown'] {
		return true
	}
	if type_.is_image() || type_.is_audio_or_video() {
		return true
	}
	return false
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#loading-a-document
pub fn load_document(navigation_params &NavigationParams, signal_to_continue_session_history_processing VoidPtr, sniff_bytes ReadonlyBytes) ?&Document {
	// 1. Let type be the computed type of navigationParams's response.
	supplied_type := navigation_response_mime_type(navigation_params)
	type_ := sniff_resource_type(sniff_bytes, supplied_type)

	// 2. If the user agent has been configured to process resources of the given type using some mechanism other than
	//    rendering the content in a navigable, then skip this step.
	//    Otherwise, if the type is one of the following types:

	// -> an HTML MIME type
	if type_.is_html() {
		return load_html_document(navigation_params, signal_to_continue_session_history_processing) or {
			return none
		}
	}

	// -> an XML MIME type that is not an explicitly supported XML MIME type
	//    FIXME: that is not an explicitly supported XML MIME type
	if type_.is_xml() {
		return load_xml_document(navigation_params, type_,
			signal_to_continue_session_history_processing) or { return none }
	}

	// -> a JavaScript MIME type
	// -> a JSON MIME type that is not an explicitly supported JSON MIME type
	// -> "text/css"
	// -> "text/plain"
	// -> "text/vtt"
	if type_.is_javascript() || type_.is_json()
		|| type_.essence() in ['text/css', 'text/plain', 'text/vtt'] {
		return load_text_document(navigation_params, type_,
			signal_to_continue_session_history_processing) or { return none }
	}

	// -> "multipart/x-mixed-replace"
	if type_.essence() == 'multipart/x-mixed-replace' {
		// FIXME: Return the result of loading a multipart/x-mixed-replace document, given navigationParams,
		//        sourceSnapshotParams, and initiatorOrigin.
	}

	// -> a supported image, video, or audio type
	if type_.is_image() || type_.is_audio_or_video() {
		return load_media_document(navigation_params, type_,
			signal_to_continue_session_history_processing) or { return none }
	}

	// -> "application/pdf"
	// -> "text/pdf"
	if type_.essence() in ['application/pdf', 'text/pdf'] {
		// FIXME: If the user agent's PDF viewer supported is true, return the result of creating a document for inline
		//        content that doesn't have a DOM given navigationParams's navigable, navigationParams's id,
		//        navigationParams's navigation timing type, and navigationParams's user involvement.
	}

	// FIXME: 3. If, given type, the new resource is to be handled by displaying some sort of inline content, e.g., a
	//    native rendering of the content or an error message because the specified type is not supported, then
	//    return the result of creating a document for inline content that doesn't have a DOM given navigationParams's
	//    navigable, navigationParams's id, navigationParams's navigation timing type, and navigationParams's user involvement.

	// FIXME: 4. Otherwise, the document's type is such that the resource will not affect navigationParams's navigable,
	//        e.g., because the resource is to be handed to an external application or because it is an unknown type
	//        that will be processed by handle as a download. Hand-off to external software given navigationParams's
	//        response, navigationParams's navigable, navigationParams's final sandboxing flag set,
	//        sourceSnapshotParams's has transient activation, and initiatorOrigin.

	// 5. Return null.
	return none
}

pub enum UserNavigationInvolvement {
	none
	browser_ui
	activation
}

// https://html.spec.whatwg.org/multipage/document-lifecycle.html#read-ua-inline
pub fn create_document_for_inline_content(navigable ?&Navigable, navigation_id ?string, user_involvement UserNavigationInvolvement, mutate_document fn (&Document)) &Document {
	_ = navigable
	_ = user_involvement
	mut document := Document.create(url_about_blank())
	document.set_document_type(.html)
	document.set_content_type('text/html')
	document.set_navigation_id(navigation_id)
	mutate_document(document)
	return document
}

pub fn DocumentObserver.create(mut document Document) &DocumentObserver {
	observer := &DocumentObserver{
		document_: document
	}
	document.register_document_observer(observer)
	return observer
}

pub fn (mut observer DocumentObserver) visit_edges(mut visitor CellVisitor) {
	if observer.document_ != unsafe { nil } {
		visitor.visit(observer.document_)
	}
}

pub fn (mut observer DocumentObserver) finalize() {
	if observer.document_ != unsafe { nil } {
		mut document := unsafe { &Document(observer.document_) }
		document.unregister_document_observer(observer)
		observer.document_ = unsafe { nil }
	}
}

pub fn (mut observer DocumentObserver) set_document(mut document Document) {
	if observer.document_ != unsafe { nil } {
		mut old_document := unsafe { &Document(observer.document_) }
		old_document.unregister_document_observer(observer)
	}
	observer.document_ = document
	document.register_document_observer(observer)
}

pub fn (observer &DocumentObserver) document() ?&Document {
	if observer.document_ == unsafe { nil } {
		return none
	}
	return observer.document_
}

pub fn (observer &DocumentObserver) document_became_active() ?fn () {
	return observer.document_became_active_
}

pub fn (mut observer DocumentObserver) set_document_became_active(callback ?fn ()) {
	observer.document_became_active_ = callback
}

pub fn (observer &DocumentObserver) document_became_inactive() ?fn () {
	return observer.document_became_inactive_
}

pub fn (mut observer DocumentObserver) set_document_became_inactive(callback ?fn ()) {
	observer.document_became_inactive_ = callback
}

pub fn (observer &DocumentObserver) document_completely_loaded() ?fn () {
	return observer.document_completely_loaded_
}

pub fn (mut observer DocumentObserver) set_document_completely_loaded(callback ?fn ()) {
	observer.document_completely_loaded_ = callback
}

pub fn (observer &DocumentObserver) document_readiness_observer() ?fn (DocumentReadyState) {
	return observer.document_readiness_observer_
}

pub fn (mut observer DocumentObserver) set_document_readiness_observer(callback ?fn (DocumentReadyState)) {
	observer.document_readiness_observer_ = callback
}

pub fn (observer &DocumentObserver) document_visibility_state_observer() ?fn (VisibilityState) {
	return observer.document_visibility_state_observer_
}

pub fn (mut observer DocumentObserver) set_document_visibility_state_observer(callback ?fn (VisibilityState)) {
	observer.document_visibility_state_observer_ = callback
}

pub fn (observer &DocumentObserver) document_page_showing_observer() ?fn (bool) {
	return observer.document_page_showing_observer_
}

pub fn (mut observer DocumentObserver) set_document_page_showing_observer(callback ?fn (bool)) {
	observer.document_page_showing_observer_ = callback
}

pub enum CollapseSelection {
	no
	yes
}

pub enum EventResult {
	handled
	dropped
}

pub fn EditingHostManager.create(mut document Document) &EditingHostManager {
	return &EditingHostManager{
		document_: document
	}
}

pub fn (mut manager EditingHostManager) visit_edges(mut visitor CellVisitor) {
	if manager.document_ != unsafe { nil } {
		visitor.visit(manager.document_)
	}
	if manager.active_contenteditable_element_ != unsafe { nil } {
		visitor.visit(manager.active_contenteditable_element_)
	}
}

pub fn (mut manager EditingHostManager) handle_insert(input_type string, value string) {
	// https://w3c.github.io/editing/docs/execCommand/#additional-requirements
	_ = input_type
	if manager.document_ == unsafe { nil } {
		return
	}
	mut document := unsafe { &Document(manager.document_) }
	document.exec_command('insertText', false, value) or {}
}

pub fn (mut manager EditingHostManager) select_all() {
	if manager.active_contenteditable_element_ == unsafe { nil }
		|| manager.document_ == unsafe { nil } {
		return
	}
	mut document := unsafe { &Document(manager.document_) }
	mut selection := document.get_selection() or { return }
	anchor := selection.anchor_node() or { return }
	focus := selection.focus_node() or { return }
	selection.set_base_and_extent(anchor, 0, focus, focus.length()) or {}
}

pub fn (mut manager EditingHostManager) set_selection_anchor(anchor_node &Node, anchor_offset int) {
	if manager.document_ == unsafe { nil } {
		return
	}
	mut document := unsafe { &Document(manager.document_) }
	mut selection := document.get_selection() or { return }
	selection.collapse(anchor_node, anchor_offset) or { return }
	document.reset_cursor_blink_cycle()
}

pub fn (mut manager EditingHostManager) set_selection_focus(focus_node &Node, focus_offset int) {
	if manager.document_ == unsafe { nil }
		|| manager.active_contenteditable_element_ == unsafe { nil } {
		return
	}
	if !manager.active_contenteditable_element_.is_ancestor_of(focus_node) {
		return
	}
	mut document := unsafe { &Document(manager.document_) }
	mut selection := document.get_selection() or { return }
	anchor := selection.anchor_node() or { return }
	selection.set_base_and_extent(anchor, selection.anchor_offset(), focus_node, focus_offset) or {
		return
	}
	document.reset_cursor_blink_cycle()
}

fn (manager &EditingHostManager) get_selection_for_navigation(collapse CollapseSelection) ?&Selection {
	if manager.document_ == unsafe { nil } {
		return none
	}
	document := unsafe { &Document(manager.document_) }
	selection := document.get_selection() or { return none }
	focus_node := selection.focus_node() or { return none }
	if !focus_node.is_text() {
		return none
	}
	if collapse == .yes && !focus_node.is_editable() {
		return none
	}
	return selection
}

pub fn (mut manager EditingHostManager) move_cursor_to_start(collapse CollapseSelection) {
	mut selection := manager.get_selection_for_navigation(collapse) or { return }
	node := selection.focus_node() or { return }
	if collapse == .yes {
		selection.collapse(node, 0) or { return }
		if manager.document_ != unsafe { nil } {
			mut document := unsafe { &Document(manager.document_) }
			document.reset_cursor_blink_cycle()
		}
	} else {
		anchor := selection.anchor_node() or { return }
		selection.set_base_and_extent(anchor, selection.anchor_offset(), node, 0) or { return }
	}
	selection.scroll_focus_into_view()
}

pub fn (mut manager EditingHostManager) move_cursor_to_end(collapse CollapseSelection) {
	mut selection := manager.get_selection_for_navigation(collapse) or { return }
	node := selection.focus_node() or { return }
	end_offset := node.length()
	if collapse == .yes {
		if manager.document_ != unsafe { nil } {
			mut document := unsafe { &Document(manager.document_) }
			document.reset_cursor_blink_cycle()
		}
		selection.collapse(node, end_offset) or { return }
	} else {
		anchor := selection.anchor_node() or { return }
		selection.set_base_and_extent(anchor, selection.anchor_offset(), node, end_offset) or {
			return
		}
	}
	selection.scroll_focus_into_view()
}

pub fn (mut manager EditingHostManager) increment_cursor_position_offset(collapse CollapseSelection) {
	mut selection := manager.get_selection_for_navigation(collapse) or { return }
	selection.move_offset_to_next_character(collapse == .yes)
}

pub fn (mut manager EditingHostManager) decrement_cursor_position_offset(collapse CollapseSelection) {
	mut selection := manager.get_selection_for_navigation(collapse) or { return }
	selection.move_offset_to_previous_character(collapse == .yes)
}

pub fn (mut manager EditingHostManager) increment_cursor_position_to_next_word(collapse CollapseSelection) {
	mut selection := manager.get_selection_for_navigation(collapse) or { return }
	selection.move_offset_to_next_word(collapse == .yes)
}

pub fn (mut manager EditingHostManager) decrement_cursor_position_to_previous_word(collapse CollapseSelection) {
	mut selection := manager.get_selection_for_navigation(collapse) or { return }
	selection.move_offset_to_previous_word(collapse == .yes)
}

pub fn (mut manager EditingHostManager) increment_cursor_position_to_next_line(collapse CollapseSelection) {
	if manager.document_ == unsafe { nil } {
		return
	}
	mut document := unsafe { &Document(manager.document_) }
	mut selection := document.get_selection() or { return }
	selection.move_offset_to_next_line(collapse == .yes)
}

pub fn (mut manager EditingHostManager) decrement_cursor_position_to_previous_line(collapse CollapseSelection) {
	if manager.document_ == unsafe { nil } {
		return
	}
	mut document := unsafe { &Document(manager.document_) }
	mut selection := document.get_selection() or { return }
	selection.move_offset_to_previous_line(collapse == .yes)
}

pub fn (mut manager EditingHostManager) handle_delete(input_type string) {
	// https://w3c.github.io/editing/docs/execCommand/#additional-requirements
	if manager.document_ == unsafe { nil } {
		return
	}
	command := if input_type == 'deleteContentBackward' { 'delete' } else { 'forwardDelete' }
	mut document := unsafe { &Document(manager.document_) }
	document.exec_command(command, false, '') or {}
}

pub fn (mut manager EditingHostManager) handle_return_key(ui_input_type string) EventResult {
	if manager.document_ == unsafe { nil } {
		return .dropped
	}
	command := if ui_input_type == 'insertParagraph' {
		'insertParagraph'
	} else {
		'insertLineBreak'
	}
	mut document := unsafe { &Document(manager.document_) }
	result := document.exec_command(command, false, '') or { return .dropped }
	return if result { .handled } else { .dropped }
}

pub fn (mut manager EditingHostManager) set_active_contenteditable_element(element ?&Node) {
	manager.active_contenteditable_element_ = element or { unsafe { nil } }
}

pub fn (manager &EditingHostManager) is_within_active_contenteditable(node &Node) bool {
	if manager.active_contenteditable_element_ == unsafe { nil } {
		return false
	}
	active := unsafe { &Node(manager.active_contenteditable_element_) }
	return active.is_shadow_including_inclusive_ancestor_of(node)
}

pub fn (mut pseudo PseudoElement_) visit_edges(mut visitor CellVisitor) {
	if layout := pseudo.layout_node_ {
		visitor.visit(layout)
	}
	if cascaded := pseudo.cascaded_props {
		visitor.visit(cascaded)
	}
	if computed := pseudo.computed_props {
		visitor.visit(computed)
	}
	if mut counters := pseudo.counters_set_ {
		counters.visit_edges(visitor)
	}
}

pub fn (pseudo &PseudoElement_) has_non_empty_counters_set() bool {
	return pseudo.counters_set_ != none
}

pub fn (pseudo &PseudoElement_) counters_set() ?&CSSCountersSet_ {
	return pseudo.counters_set_
}

pub fn (mut pseudo PseudoElement_) ensure_counters_set() &CSSCountersSet_ {
	if counters := pseudo.counters_set_ {
		return counters
	}
	counters := &CSSCountersSet_{}
	pseudo.counters_set_ = counters
	return counters
}

pub fn (mut pseudo PseudoElement_) set_counters_set(counters_set ?&CSSCountersSet_) {
	pseudo.counters_set_ = counters_set
}

pub fn (pseudo &PseudoElement_) scroll_offset() CSSPixelPoint_ {
	return pseudo.scroll_offset_
}

pub fn (mut pseudo PseudoElement_) set_scroll_offset(value CSSPixelPoint_) {
	pseudo.scroll_offset_ = value
}

@[heap]
pub struct PseudoElementTreeNode_ {
	PseudoElement_
}

pub struct CSSStyleValue_ {}

pub struct CSSAnimation_ {}

// Either an Element or a PseudoElement.
pub struct AbstractElement {
pub mut:
	element_             &Element = unsafe { nil }
	pseudo_element_      ?PseudoElement
	inheritance_override ?&Element
}

pub fn AbstractElement.new(element &Element, pseudo_element ?PseudoElement) AbstractElement {
	return AbstractElement{
		element_:        element
		pseudo_element_: pseudo_element
	}
}

pub fn (abstract_element &AbstractElement) document() &Document {
	return abstract_element.element_.document()
}

pub fn (abstract_element &AbstractElement) element() &Element {
	return abstract_element.element_
}

pub fn (abstract_element &AbstractElement) pseudo_element() ?PseudoElement {
	return abstract_element.pseudo_element_
}

pub struct TreeCountingFunctionResolutionContext {
pub mut:
	sibling_count int
	sibling_index int
}

pub fn (abstract_element &AbstractElement) tree_counting_function_resolution_context() TreeCountingFunctionResolutionContext {
	parent := abstract_element.element_.as_node().parent_element() or {
		return TreeCountingFunctionResolutionContext{
			sibling_count: 1
			sibling_index: 1
		}
	}
	mut count := 0
	mut index := 0
	for child in parent.as_node().children {
		if child.is_element() {
			count++
			if child == abstract_element.element_.as_node() {
				index = count
			}
		}
	}
	return TreeCountingFunctionResolutionContext{
		sibling_count: count
		sibling_index: index
	}
}

pub fn (abstract_element &AbstractElement) layout_node() ?&LayoutNodeWithStyle_ {
	if pseudo := abstract_element.pseudo_element_ {
		return abstract_element.element_.get_pseudo_element_node(int(pseudo))
	}
	return abstract_element.element_.el_layout_node()
}

pub fn (abstract_element &AbstractElement) unsafe_layout_node() ?&LayoutNodeWithStyle_ {
	if pseudo := abstract_element.pseudo_element_ {
		return abstract_element.element_.get_pseudo_element_node(int(pseudo))
	}
	return abstract_element.element_.el_unsafe_layout_node()
}

pub fn (abstract_element &AbstractElement) parent_element() ?&Element {
	if abstract_element.pseudo_element_ != none {
		return abstract_element.element_
	}
	return abstract_element.element_.as_node().parent_element()
}

pub fn (abstract_element &AbstractElement) element_to_inherit_style_from() ?AbstractElement {
	if override := abstract_element.inheritance_override {
		return AbstractElement.new(override, none)
	}
	pseudo := if p := abstract_element.pseudo_element_ { int(p) } else { none }
	element := abstract_element.element_.element_to_inherit_style_from(pseudo) or { return none }
	return AbstractElement.new(element, none)
}

pub enum AbstractElementWalkMethod {
	previous
	previous_sibling
}

pub fn (abstract_element &AbstractElement) walk_layout_tree(walk_method AbstractElementWalkMethod) ?AbstractElement {
	mut node := abstract_element.unsafe_layout_node() or { return none }
	for {
		node = match walk_method {
			.previous { node.previous_in_pre_order() or { return none } }
			.previous_sibling { node.previous_sibling() or { return none } }
		}

		if dom_node := node.dom_node() {
			if element := dom_node.as_element() {
				return AbstractElement.new(element, none)
			}
		}
		if node.is_generated_for_pseudo_element() {
			generator := node.pseudo_element_generator() or { continue }
			pseudo := node.generated_for_pseudo_element() or { continue }
			return AbstractElement.new(generator, pseudo)
		}
	}
	return none
}

pub fn (abstract_element &AbstractElement) previous_in_tree_order() ?AbstractElement {
	return abstract_element.walk_layout_tree(.previous)
}

pub fn (abstract_element &AbstractElement) previous_sibling_in_tree_order() ?AbstractElement {
	return abstract_element.walk_layout_tree(.previous_sibling)
}

pub fn (abstract_element &AbstractElement) is_before(other AbstractElement) bool {
	this_node := abstract_element.unsafe_layout_node() or { return false }
	other_node := other.unsafe_layout_node() or { return false }
	return this_node.is_before(other_node)
}

pub fn (mut abstract_element AbstractElement) set_inheritance_override(element &Element) {
	abstract_element.inheritance_override = element
}

pub fn (abstract_element &AbstractElement) computed_properties() ?&CSSComputedProperties_ {
	pseudo := if p := abstract_element.pseudo_element_ { int(p) } else { none }
	return abstract_element.element_.computed_properties_for_pseudo(pseudo)
}

pub fn (abstract_element &AbstractElement) custom_property_data() ?&CSSCustomPropertyData_ {
	pseudo := if p := abstract_element.pseudo_element_ { int(p) } else { none }
	return abstract_element.element_.custom_property_data(pseudo)
}

pub fn (mut abstract_element AbstractElement) set_custom_property_data(data ?&CSSCustomPropertyData_) {
	pseudo := if p := abstract_element.pseudo_element_ { int(p) } else { none }
	mut element := unsafe { &Element(abstract_element.element_) }
	element.set_custom_property_data(pseudo, data)
}

pub fn (abstract_element &AbstractElement) get_custom_property(name string) ?&CSSStyleValue_ {
	data := abstract_element.custom_property_data() or { return none }
	return data.get(name)
}

pub fn (abstract_element &AbstractElement) cascaded_properties() ?&CSSCascadedProperties_ {
	pseudo := if p := abstract_element.pseudo_element_ { int(p) } else { none }
	return abstract_element.element_.el_cascaded_properties(pseudo)
}

pub fn (mut abstract_element AbstractElement) set_cascaded_properties(cascaded_properties ?&CSSCascadedProperties_) {
	pseudo := if p := abstract_element.pseudo_element_ { int(p) } else { none }
	mut element := unsafe { &Element(abstract_element.element_) }
	element.set_cascaded_properties(pseudo, cascaded_properties)
}

pub fn (abstract_element &AbstractElement) has_non_empty_counters_set() bool {
	if pseudo := abstract_element.pseudo_element_ {
		pseudo_element := abstract_element.element_.get_pseudo_element(int(pseudo)) or {
			return false
		}
		return pseudo_element.has_non_empty_counters_set()
	}
	return abstract_element.element_.has_non_empty_counters_set()
}

pub fn (abstract_element &AbstractElement) counters_set() ?&CSSCountersSet_ {
	if pseudo := abstract_element.pseudo_element_ {
		pseudo_element := abstract_element.element_.get_pseudo_element(int(pseudo)) or {
			return none
		}
		return pseudo_element.counters_set()
	}
	return abstract_element.element_.el_counters_set()
}

pub fn (mut abstract_element AbstractElement) ensure_counters_set() &CSSCountersSet_ {
	if pseudo := abstract_element.pseudo_element_ {
		mut pseudo_element := abstract_element.element_.get_pseudo_element(int(pseudo)) or {
			return abstract_element.element_.ensure_counters_set()
		}
		return pseudo_element.ensure_counters_set()
	}
	return abstract_element.element_.ensure_counters_set()
}

pub fn (mut abstract_element AbstractElement) set_counters_set(counters_set ?&CSSCountersSet_) {
	if pseudo := abstract_element.pseudo_element_ {
		mut pseudo_element := abstract_element.element_.get_pseudo_element(int(pseudo)) or {
			return
		}
		pseudo_element.set_counters_set(counters_set)
		return
	}
	mut element := unsafe { &Element(abstract_element.element_) }
	element.set_counters_set(counters_set)
}

pub fn (abstract_element &AbstractElement) css_defined_animations() ?map[string]&CSSAnimation_ {
	if abstract_element.element_.has_css_defined_animations_flag {
		return abstract_element.element_.css_defined_animations_
	}
	return none
}

pub fn (mut abstract_element AbstractElement) set_has_css_defined_animations() {
	mut element := unsafe { &Element(abstract_element.element_) }
	element.has_css_defined_animations_flag = true
}

pub fn (abstract_element &AbstractElement) visit(mut visitor CellVisitor) {
	visitor.visit(abstract_element.element_)
	if override := abstract_element.inheritance_override {
		visitor.visit(override)
	}
}

pub fn (abstract_element &AbstractElement) debug_description() string {
	if pseudo := abstract_element.pseudo_element_ {
		return '${abstract_element.element_.debug_description()}::${pseudo_element_name(pseudo)}'
	}
	return abstract_element.element_.debug_description()
}

pub fn (abstract_element &AbstractElement) style_scope() &StyleScope {
	root := abstract_element.element_.as_node().root()
	if shadow_root := root.as_shadow_root() {
		if shadow_root.uses_document_style_sheets() {
			return shadow_root.document().style_scope()
		}
		return shadow_root.style_scope()
	}
	return root.document().style_scope()
}

pub fn (d &Document) style_scope() &StyleScope {
	return &d.style_scope_
}

pub fn pseudo_element_name(pseudo PseudoElement) string {
	return match pseudo {
		.before { 'before' }
		.after { 'after' }
		.first_line { 'first-line' }
		.first_letter { 'first-letter' }
		.marker { 'marker' }
		.placeholder { 'placeholder' }
		.selection { 'selection' }
	}
}

@[heap]
pub struct XMLDocument {
	Document
}

pub fn XMLDocument.create(url URL) &XMLDocument {
	mut document := &XMLDocument{}
	document.node_type = .document_node
	document.document_ = unsafe { &Document(document) }
	document.url = url
	document.type_ = .xml
	document.content_type = 'application/xml'
	return document
}

pub fn (mut document XMLDocument) initialize() {}

pub fn (document &XMLDocument) as_document() &Document {
	return unsafe { &Document(document) }
}
