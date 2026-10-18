// Copyright (c) 2026, libweb_v contributors
//
// SPDX-License-Identifier: BSD-2-Clause
//
// Inline DOM methods translated from the upstream class headers. Getter names
// are qualified where a V field already occupies the C++ method name.
module dom

// --- Element ---------------------------------------------------------------

pub fn (e &Element) is_dom_element() bool {
	return true
}

pub fn (e &Element) part_names() []string {
	return e.parts.clone()
}

pub fn (e &Element) class_names() []string {
	return e.classes.clone()
}

pub fn (e &Element) supports_dimension_attributes() bool {
	return false
}

pub fn (e &Element) is_presentational_hint(_ string) bool {
	return false
}

pub fn (e &Element) element_child_style_uses_tree_counting_function() bool {
	return e.child_style_uses_tree_counting_function
}

pub fn (mut e Element) set_child_style_uses_tree_counting_function() {
	e.child_style_uses_tree_counting_function = true
}

pub fn (mut e Element) did_receive_focus() {
}

pub fn (mut e Element) did_lose_focus() {
}

pub fn (e &Element) to_element() &Element {
	return e
}

pub fn (e &Element) custom_element_is_value() ?string {
	return e.is_value
}

pub fn (mut e Element) set_is_value(value ?string) {
	e.is_value = value
}

pub fn (e &Element) element_affected_by_has_pseudo_class_in_subject_position() bool {
	return e.affected_by_has_pseudo_class_in_subject_position
}

pub fn (mut e Element) set_affected_by_has_pseudo_class_in_subject_position(value bool) {
	e.affected_by_has_pseudo_class_in_subject_position = value
}

pub fn (e &Element) element_affected_by_has_pseudo_class_in_non_subject_position() bool {
	return e.affected_by_has_pseudo_class_in_non_subject_position
}

pub fn (mut e Element) set_affected_by_has_pseudo_class_in_non_subject_position(value bool) {
	e.affected_by_has_pseudo_class_in_non_subject_position = value
}

pub fn (e &Element) element_affected_by_has_pseudo_class_with_relative_selector_that_has_sibling_combinator() bool {
	return e.affected_by_has_pseudo_class_with_relative_selector_that_has_sibling_combinator
}

pub fn (mut e Element) set_affected_by_has_pseudo_class_with_relative_selector_that_has_sibling_combinator(value bool) {
	e.affected_by_has_pseudo_class_with_relative_selector_that_has_sibling_combinator = value
}

pub fn (mut e Element) set_in_subtree_of_has_pseudo_class_relative_selector_with_sibling_combinator(value bool) {
	e.in_subtree_of_has_pseudo_class_relative_selector_with_sibling_combinator = value
}

pub fn (mut e Element) set_in_has_scope(value bool) {
	e.in_has_scope = value
}

pub fn (e &Element) element_affected_by_direct_sibling_combinator() bool {
	return e.affected_by_direct_sibling_combinator
}

pub fn (mut e Element) set_affected_by_direct_sibling_combinator(value bool) {
	e.affected_by_direct_sibling_combinator = value
}

pub fn (e &Element) element_affected_by_indirect_sibling_combinator() bool {
	return e.affected_by_indirect_sibling_combinator
}

pub fn (mut e Element) set_affected_by_indirect_sibling_combinator(value bool) {
	e.affected_by_indirect_sibling_combinator = value
}

pub fn (e &Element) element_affected_by_first_child_pseudo_class() bool {
	return e.affected_by_first_child_pseudo_class
}

pub fn (mut e Element) set_affected_by_first_child_pseudo_class(value bool) {
	e.affected_by_first_child_pseudo_class = value
}

pub fn (e &Element) element_affected_by_last_child_pseudo_class() bool {
	return e.affected_by_last_child_pseudo_class
}

pub fn (mut e Element) set_affected_by_last_child_pseudo_class(value bool) {
	e.affected_by_last_child_pseudo_class = value
	if value {
		if parent := e.as_node().parent() {
			mut mutable_parent := unsafe { &Node(parent) }
			mutable_parent.set_has_child_affected_by_backward_structural_changes(true)
		}
	}
}

pub fn (e &Element) element_affected_by_forward_positional_pseudo_class() bool {
	return e.affected_by_forward_positional_pseudo_class
}

pub fn (mut e Element) set_affected_by_forward_positional_pseudo_class(value bool) {
	e.affected_by_forward_positional_pseudo_class = value
}

pub fn (e &Element) element_affected_by_backward_positional_pseudo_class() bool {
	return e.affected_by_backward_positional_pseudo_class
}

pub fn (mut e Element) set_affected_by_backward_positional_pseudo_class(value bool) {
	e.affected_by_backward_positional_pseudo_class = value
	if value {
		if parent := e.as_node().parent() {
			mut mutable_parent := unsafe { &Node(parent) }
			mutable_parent.set_has_child_affected_by_backward_structural_changes(true)
		}
	}
}

pub fn (mut e Element) set_affected_by_structural_pseudo_class_in_non_subject_position() {
	e.affected_by_structural_pseudo_class_in_non_subject_position = true
}

pub fn (mut e Element) set_affected_by_sibling_combinator_in_non_subject_position() {
	e.affected_by_sibling_combinator_in_non_subject_position = true
}

pub fn (e &Element) element_sibling_invalidation_distance() int {
	return e.sibling_invalidation_distance
}

pub fn (mut e Element) set_sibling_invalidation_distance(value int) {
	e.sibling_invalidation_distance = value
}

pub fn (e &Element) computed_properties_changed() {
}

pub fn Element.create_layout_node_for_display_type(document &Document, display CSSDisplay_, style &CSSComputedProperties_, element &Element) ?&LayoutNodeWithStyle_ {
	return create_layout_node_for_display_type(document, display, style, element)
}

pub fn (mut e Element) set_scroll_offset(pseudo_element_type ?PseudoElement, offset CSSPixelPoint_) {
	if pseudo_element := pseudo_element_type {
		if mut data := e.get_pseudo_element(int(pseudo_element)) {
			if data.scroll_offset() != offset {
				mut document := unsafe { &Document(e.document()) }
				if document != unsafe { nil } {
					document.invalidate_scroll_state()
				}
			}
			data.set_scroll_offset(offset)
		}
		return
	}
	if e.interactive_scroll_offset() == offset { return }
	if e.interactive_scroll_offset() != offset {
		mut document := unsafe { &Document(e.document()) }
		if document != unsafe { nil } {
			document.invalidate_scroll_state()
		}
	}
	mut state := e.copy_interactive_data()
	state.scroll_offset_ = offset
	e.interactive_data_ = state
}

// --- Small value/object surfaces -------------------------------------------

pub fn (a &Attr) node_name() string {
	return a.name_
}

pub fn (d &DocumentFragment) node_name() string {
	return '#document-fragment'
}

pub fn (t &Text) node_name() string {
	return '#text'
}

pub fn (e &Event) is_dom_event() bool {
	return true
}

pub fn (e &EventTarget) is_dom_event_target() bool {
	return true
}

pub fn (m &EditingHostManager) as_cell() voidptr {
	return voidptr(m)
}

pub fn (c &HTMLCollection) html_collection_root() &ParentNode {
	return c.root
}

pub fn (i &NodeIterator) node_iterator_root() &Node {
	return i.root
}

pub fn (i &NodeIterator) node_iterator_what_to_show() u32 {
	return i.what_to_show
}

pub fn (w &TreeWalker) tree_walker_root() &Node {
	return w.root
}

pub fn (w &TreeWalker) tree_walker_what_to_show() u32 {
	return w.what_to_show
}

pub fn (o &MutationObserver) mutation_observer_node_list() []&Node {
	return o.node_list_.clone()
}

pub fn (o &MutationObserver) callback() ?&CallbackType {
	return o.callback_
}

pub fn (r &MutationRecord) mutation_record_target() ?&Node {
	if r.target == unsafe { nil } {
		return none
	}
	return r.target
}

pub fn (r &MutationRecord) mutation_record_added_nodes() []&Node {
	return r.added_nodes.clone()
}

pub fn (r &MutationRecord) mutation_record_removed_nodes() []&Node {
	return r.removed_nodes.clone()
}

pub fn (r &MutationRecord) mutation_record_previous_sibling() ?&Node {
	if r.previous_sibling == unsafe { nil } {
		return none
	}
	return r.previous_sibling
}

pub fn (r &MutationRecord) mutation_record_next_sibling() ?&Node {
	if r.next_sibling == unsafe { nil } {
		return none
	}
	return r.next_sibling
}

pub fn (r &MutationRecord) mutation_record_attribute_name() ?string {
	return r.attribute_name
}

pub fn (r &MutationRecord) mutation_record_attribute_namespace() ?string {
	return r.attribute_namespace
}

pub fn (r &MutationRecord) mutation_record_old_value() ?string {
	return r.old_value
}

pub fn (mut n NamedNodeMap) remove_attribute_ns(namespace_ ?string, local_name string) ?&Attr_ {
	index := n.attribute_index_by_namespace(namespace_, local_name) or { return none }
	attribute := n.attrs[index]
	n.remove_attribute_at_index(index)
	return attribute
}

pub fn (n &NamedNodeMap) associated_element() &Element {
	return n.element
}

pub fn (q &QualifiedName) qualified_name_local_name() string {
	return q.local_name
}

pub fn (q &QualifiedName) qualified_name_namespace_() ?string {
	return q.namespace_
}

pub fn (q &QualifiedName) qualified_name_lowercased_local_name() string {
	return q.lowercased_local_name
}

pub fn (mut r Range) set_start_node(node &Node) {
	r.start_container_ = node
}

pub fn (mut r Range) set_start_offset(offset int) {
	r.start_offset_ = offset
}

pub fn (mut r Range) set_end_node(node &Node) {
	r.end_container_ = node
}

pub fn (mut r Range) set_end_offset(offset int) {
	r.end_offset_ = offset
}

pub fn (mut r Range) increase_start_offset(count int) {
	r.start_offset_ += count
}

pub fn (mut r Range) increase_end_offset(count int) {
	r.end_offset_ += count
}

pub fn (mut r Range) decrease_start_offset(count int) {
	r.start_offset_ -= count
}

pub fn (mut r Range) decrease_end_offset(count int) {
	r.end_offset_ -= count
}

pub fn (r &ShadowRoot) node_name() string {
	return '#shadow-root'
}

pub fn (r &ShadowRoot) is_shadow_root() bool {
	return true
}

pub fn (r &ShadowRoot) for_each_registered_slot(callback fn (&HTMLSlotElement)) {
	if r.slot_registry_ == unsafe { nil } {
		return
	}
	registry := unsafe { &SlotRegistry(r.slot_registry_) }
	for slot in registry.slots {
		callback(slot)
	}
}

pub fn (p &PseudoElement_) unsafe_layout_node() ?&LayoutNodeWithStyle_ {
	return p.layout_node_
}

// --- Document inline state -------------------------------------------------

pub fn (mut d Document) set_cookie_version_index(index int) {
	d.cookie_version_index = index
}

pub fn (mut d Document) reset_cookie_version() {
	d.cookie_version = -1
}

pub fn (d &Document) document_font_computer() &FontComputer {
	return d.font_computer
}

pub fn (mut d Document) style_sheets_for_bindings() &StyleSheetList {
	return d.style_sheets()
}

pub fn (d &Document) document_parser_cannot_change_the_mode() bool {
	return d.parser_cannot_change_the_mode
}

pub fn (mut d Document) set_parser_cannot_change_the_mode(value bool) {
	d.parser_cannot_change_the_mode = value
}

pub fn (d &Document) document_http_content_language() ?string {
	return d.http_content_language
}

pub fn (d &Document) document_ready_for_post_load_tasks() bool {
	return d.ready_for_post_load_tasks
}

pub fn (mut d Document) set_ready_for_post_load_tasks(value bool) {
	d.ready_for_post_load_tasks = value
	if value {
		if navigable := d.navigable() {
			if container_document := navigable.container_document() {
				container_document.schedule_html_parser_end_check()
			}
		}
	}
}

pub fn (mut d Document) set_current_script(script ?&HTMLScriptElement) {
	d.current_script = script or { unsafe { nil } }
}

pub fn (mut d Document) set_needs_media_query_evaluation() {
	d.needs_media_query_evaluation = true
}

pub fn (d &Document) for_each_node_iterator(callback fn (&NodeIterator)) {
	for iterator in d.node_iterators {
		callback(iterator)
	}
}

pub fn (d &Document) document_pending_scroll_events() []PendingScrollEvent {
	return d.pending_scroll_events.clone()
}

pub fn (mut d Document) set_load_timing_info(info DocumentLoadTimingInfo) {
	d.load_timing_info = info
}

pub fn (d &Document) document_load_timing_info() DocumentLoadTimingInfo {
	return d.load_timing_info
}

pub fn (d &Document) document_previous_document_unload_timing() DocumentUnloadTimingInfo {
	return d.previous_document_unload_timing
}

pub fn (mut d Document) set_previous_document_unload_timing(info DocumentUnloadTimingInfo) {
	d.previous_document_unload_timing = info
}

pub fn (d &Document) was_created_via_cross_origin_redirects() bool {
	return d.was_created_via_cross_origin_redirects
}

pub fn (mut d Document) set_was_created_via_cross_origin_redirects(value bool) {
	d.was_created_via_cross_origin_redirects = value
}

pub fn (mut d Document) set_salvageable(value bool) {
	d.salvageable = value
}

pub fn (d &Document) document_last_animation_frame_timestamp() ?f64 {
	return d.last_animation_frame_timestamp
}

pub fn (d &Document) document_ready_to_run_scripts() bool {
	return d.ready_to_run_scripts
}

pub fn (mut d Document) set_ready_to_run_scripts() {
	d.ready_to_run_scripts = true
	if callback := d.deferred_parser_start {
		d.deferred_parser_start = none
		callback()
	}
}

pub fn (mut d Document) set_deferred_parser_start(callback fn ()) {
	assert d.deferred_parser_start == none
	d.deferred_parser_start = callback
}

pub fn (d &Document) has_deferred_parser_start() bool {
	return d.deferred_parser_start != none
}

pub fn (mut d Document) set_needs_invalidation_of_elements_affected_by_has() {
	d.needs_invalidation_of_elements_affected_by_has = true
}

pub fn (mut d Document) set_needs_accumulated_visual_contexts_update(value bool) {
	d.needs_accumulated_visual_contexts_update = value
}

pub fn (d &Document) document_needs_accumulated_visual_contexts_update() bool {
	return d.needs_accumulated_visual_contexts_update
}

// Compositor-only animation samples whose values the painting bridge retains.
// A full visual-context update, when also requested, supersedes this one.
pub fn (mut d Document) set_needs_compositor_visual_contexts_update() {
	d.needs_compositor_visual_contexts_update = true
}

pub fn (d &Document) for_each_shadow_root(callback fn (&ShadowRoot)) {
	for shadow_root in d.shadow_roots {
		callback(shadow_root)
	}
}

pub fn (d &Document) document_top_layer_elements() []&Element {
	return d.top_layer_elements.clone()
}

pub fn (d &Document) document_open_dialogs_list() []&HTMLDialogElement {
	return d.open_dialogs_list.clone()
}

pub fn (mut d Document) set_dialog_pointerdown_target(target ?&HTMLDialogElement) {
	d.dialog_pointerdown_target = target or { unsafe { nil } }
}

pub fn (d &Document) document_dialog_pointerdown_target() ?&HTMLDialogElement {
	if d.dialog_pointerdown_target == unsafe { nil } {
		return none
	}
	return d.dialog_pointerdown_target
}

pub fn (d &Document) document_rendering_suppression_for_view_transitions() bool {
	return d.rendering_suppression_for_view_transitions
}

pub fn (mut d Document) set_rendering_suppression_for_view_transitions(value bool) {
	if d.rendering_suppression_for_view_transitions == value {
		return
	}
	d.rendering_suppression_for_view_transitions = value
	if !value {
		d.request_frame()
	}
}

pub fn (d &Document) document_dynamic_view_transition_style_sheet() ?&CSSStyleSheet {
	if d.dynamic_view_transition_style_sheet == unsafe { nil } {
		return none
	}
	return d.dynamic_view_transition_style_sheet
}

pub fn (mut d Document) set_show_view_transition_tree(value bool) {
	d.show_view_transition_tree = value
}

pub fn (d &Document) document_script_blocking_style_sheet_set() []&Element {
	return d.script_blocking_style_sheet_set.clone()
}

pub fn (d &Document) document_registered_counter_styles() map[string]&CounterStyle {
	return d.registered_counter_styles.clone()
}

pub fn (d &Document) is_dom_document() bool {
	return true
}

pub fn (d &Document) global_event_handlers_to_event_target(_ string) &EventTarget {
	return unsafe { &EventTarget(d) }
}

// The GetNotifier/argument pack in C++ is represented by a callback that owns
// its invocation arguments. Snapshotting preserves observer removal semantics.
pub fn (d &Document) notify_each_document_observer(callback fn (&DocumentObserver)) {
	observers := d.document_observers.clone()
	for observer in observers {
		callback(observer)
	}
}
