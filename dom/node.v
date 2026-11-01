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

import platform
import math
import strings
import encoding.utf8

pub type UniqueNodeID = i64

const namespace_xlink_uri = 'http://www.w3.org/1999/xlink'

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
	editable_state_change
	finalize_a_cross_document_navigation
	generated_content_image_finished_loading
	html_canvas_element_width_or_height_change
	html_image_element_react_to_changes_in_the_environment
	html_image_element_update_the_image_data
	html_video_element_natural_dimensions_changed
	html_video_element_set_video_track
	keyframe_effect
	language_change_under_casing_text_transform
	layout_tree_update
	navigable_set_viewport_size
	svg_graphics_element_transform_change
	svg_image_element_fetch_the_document
	svg_image_filter_fetch
	svg_resource_element_attribute_change
	svg_view_box_change
	style_change
}

pub fn set_needs_layout_reason_to_string(reason SetNeedsLayoutReason) string {
	return match reason {
		.character_data_replace_data { 'CharacterDataReplaceData' }
		.editable_state_change { 'EditableStateChange' }
		.finalize_a_cross_document_navigation { 'FinalizeACrossDocumentNavigation' }
		.generated_content_image_finished_loading { 'GeneratedContentImageFinishedLoading' }
		.html_canvas_element_width_or_height_change { 'HTMLCanvasElementWidthOrHeightChange' }
		.html_image_element_react_to_changes_in_the_environment {
			'HTMLImageElementReactToChangesInTheEnvironment'
		}
		.html_image_element_update_the_image_data { 'HTMLImageElementUpdateTheImageData' }
		.html_video_element_natural_dimensions_changed {
			'HTMLVideoElementNaturalDimensionsChanged'
		}
		.html_video_element_set_video_track { 'HTMLVideoElementSetVideoTrack' }
		.keyframe_effect { 'KeyframeEffect' }
		.language_change_under_casing_text_transform { 'LanguageChangeUnderCasingTextTransform' }
		.layout_tree_update { 'LayoutTreeUpdate' }
		.navigable_set_viewport_size { 'NavigableSetViewportSize' }
		.svg_graphics_element_transform_change { 'SVGGraphicsElementTransformChange' }
		.svg_image_element_fetch_the_document { 'SVGImageElementFetchTheDocument' }
		.svg_image_filter_fetch { 'SVGImageFilterFetch' }
		.svg_resource_element_attribute_change { 'SVGResourceElementAttributeChange' }
		.svg_view_box_change { 'SVGViewBoxChange' }
		.style_change { 'StyleChange' }
	}
}

pub enum SetNeedsLayoutTreeUpdateReason {
	character_data_replace_data
	element_set_inner_html
	element_set_shadow_root
	details_element_opened_or_closed
	html_image_element_update_the_image_data
	html_input_element_src_attribute
	html_ol_list_element_ordinal_values
	html_object_element_update_layout_and_child_objects
	keyframe_effect
	language_change_under_casing_text_transform
	node_insert_before
	node_insert_before_with_display_contents
	node_remove
	node_set_text_content
	none
	shadow_root_set_inner_html
	style_change
	svg_resource_element_removed
}

pub fn set_needs_layout_tree_update_reason_to_string(reason SetNeedsLayoutTreeUpdateReason) string {
	return match reason {
		.character_data_replace_data { 'CharacterDataReplaceData' }
		.element_set_inner_html { 'ElementSetInnerHTML' }
		.element_set_shadow_root { 'ElementSetShadowRoot' }
		.details_element_opened_or_closed { 'DetailsElementOpenedOrClosed' }
		.html_image_element_update_the_image_data { 'HTMLImageElementUpdateTheImageData' }
		.html_input_element_src_attribute { 'HTMLInputElementSrcAttribute' }
		.html_ol_list_element_ordinal_values { 'HTMLOListElementOrdinalValues' }
		.html_object_element_update_layout_and_child_objects {
			'HTMLObjectElementUpdateLayoutAndChildObjects'
		}
		.keyframe_effect { 'KeyframeEffect' }
		.language_change_under_casing_text_transform { 'LanguageChangeUnderCasingTextTransform' }
		.node_insert_before { 'NodeInsertBefore' }
		.node_insert_before_with_display_contents { 'NodeInsertBeforeWithDisplayContents' }
		.node_remove { 'NodeRemove' }
		.node_set_text_content { 'NodeSetTextContent' }
		.none { 'None' }
		.shadow_root_set_inner_html { 'ShadowRootSetInnerHTML' }
		.style_change { 'StyleChange' }
		.svg_resource_element_removed { 'SVGResourceElementRemoved' }
	}
}

pub enum StyleInvalidationReason {
	adopted_style_sheets_list
	base_url_changed
	css_font_loaded
	element_attribute_change
	custom_state_set_change
	element_set_active
	element_set_shadow_root
	has_pseudo_class_match_change
	html_details_or_dialog_open_attribute_change
	html_dialog_element_set_is_modal
	html_iframe_element_geometry_change
	html_input_element_set_checked
	html_object_element_update_layout_and_child_objects
	html_option_element_selected_change
	navigable_set_viewport_size
	node_insert_before
	node_remove
	node_set_text_content
	settings_change
	style_change
	style_sheet_delete_rule
	style_sheet_insert_rule
	style_sheet_list_add_sheet
	style_sheet_list_remove_sheet
	style_sheet_disabled_state_change
	style_sheet_replace
	media_query_changed_match_state
	media_list_set_media_text
	media_list_append_medium
	media_list_delete_medium
	counter_style_cache_invalidated
	other
}

pub fn style_invalidation_reason_to_string(reason StyleInvalidationReason) string {
	return match reason {
		.adopted_style_sheets_list { 'AdoptedStyleSheetsList' }
		.base_url_changed { 'BaseURLChanged' }
		.css_font_loaded { 'CSSFontLoaded' }
		.element_attribute_change { 'ElementAttributeChange' }
		.custom_state_set_change { 'CustomStateSetChange' }
		.element_set_active { 'ElementSetActive' }
		.element_set_shadow_root { 'ElementSetShadowRoot' }
		.has_pseudo_class_match_change { 'HasPseudoClassMatchChange' }
		.html_details_or_dialog_open_attribute_change { 'HTMLDetailsOrDialogOpenAttributeChange' }
		.html_dialog_element_set_is_modal { 'HTMLDialogElementSetIsModal' }
		.html_iframe_element_geometry_change { 'HTMLIFrameElementGeometryChange' }
		.html_input_element_set_checked { 'HTMLInputElementSetChecked' }
		.html_object_element_update_layout_and_child_objects {
			'HTMLObjectElementUpdateLayoutAndChildObjects'
		}
		.html_option_element_selected_change { 'HTMLOptionElementSelectedChange' }
		.navigable_set_viewport_size { 'NavigableSetViewportSize' }
		.node_insert_before { 'NodeInsertBefore' }
		.node_remove { 'NodeRemove' }
		.node_set_text_content { 'NodeSetTextContent' }
		.settings_change { 'SettingsChange' }
		.style_change { 'StyleChange' }
		.style_sheet_delete_rule { 'StyleSheetDeleteRule' }
		.style_sheet_insert_rule { 'StyleSheetInsertRule' }
		.style_sheet_list_add_sheet { 'StyleSheetListAddSheet' }
		.style_sheet_list_remove_sheet { 'StyleSheetListRemoveSheet' }
		.style_sheet_disabled_state_change { 'StyleSheetDisabledStateChange' }
		.style_sheet_replace { 'StyleSheetReplace' }
		.media_query_changed_match_state { 'MediaQueryChangedMatchState' }
		.media_list_set_media_text { 'MediaListSetMediaText' }
		.media_list_append_medium { 'MediaListAppendMedium' }
		.media_list_delete_medium { 'MediaListDeleteMedium' }
		.counter_style_cache_invalidated { 'CounterStyleCacheInvalidated' }
		.other { 'Other' }
	}
}

pub struct StyleInvalidationOptions {
pub mut:
	invalidate_self bool
}

pub enum FragmentSerializationMode {
	inner
	outer
}

pub enum SerializableShadowRoots {
	no
	yes
}

pub enum AllowDeclarativeShadowRoots {
	no
	yes
}

pub enum RequireWellFormed {
	no
	yes
}

pub enum InvalidateDisplayList {
	no
	paint_commands
	paint_commands_and_hit_test_list
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

pub type PaintableSetNeedsRepaintCallback = fn (voidptr, voidptr, InvalidateDisplayList)

pub type PaintableScrollAncestorToOffsetCallback = fn (voidptr, voidptr, int)

pub type PaintableImageContentsChangedCallback = fn (voidptr, voidptr) bool

pub type PaintableBoxTypeAgnosticPositionCallback = fn (voidptr, voidptr) CSSPixelPoint_

pub enum ScrollSnapSelectionType_ {
	end_position
	direction
	end_position_and_direction
}

pub struct ScrollSnapSelectionStrategy_ {
pub:
	type_                       ScrollSnapSelectionType_ = .end_position
	start_offset                ?CSSPixelPoint_
	displacement                CSSPixelPoint_
	starting_positions_boundary ?CSSPixelPoint_
}

pub struct ScrollSnapAreaReference_ {
pub:
	element_id     i64
	pseudo_element int = -1
}

pub struct ScrollSnapDestination_ {
pub:
	position        CSSPixelPoint_
	snapped_x       bool
	snapped_y       bool
	evaluated_x     bool
	evaluated_y     bool
	snapped_areas_x []ScrollSnapAreaReference_
	snapped_areas_y []ScrollSnapAreaReference_
}

pub type PaintableAdjustScrollDestinationCallback = fn (voidptr, voidptr, CSSPixelPoint_, ScrollSnapSelectionStrategy_) ScrollSnapDestination_

pub type PaintableInverseTransformPointCallback = fn (voidptr, voidptr, CSSPixelPoint_) CSSPixelPoint_

// Shared immutable dispatch; each paintable retains its own target and handle.
pub struct PaintableCallbacks {
pub:
	set_needs_repaint_callback                   PaintableSetNeedsRepaintCallback = unsafe { nil }
	image_contents_changed_callback              PaintableImageContentsChangedCallback = unsafe { nil }
	scroll_ancestor_to_offset_into_view_callback PaintableScrollAncestorToOffsetCallback = unsafe { nil }
	box_type_agnostic_position_callback          PaintableBoxTypeAgnosticPositionCallback = unsafe { nil }
	inverse_transform_point_callback            PaintableInverseTransformPointCallback = unsafe { nil }
	adjust_scroll_destination_callback           PaintableAdjustScrollDestinationCallback = unsafe { nil }
}

@[heap]
pub struct Paintable {
pub mut:
	needs_repaint                                bool
	is_box                                       bool
	selection_state                              SelectionState
	layout_handle                                voidptr = unsafe { nil }
	repaint_callback_target                      voidptr = unsafe { nil }
	callbacks                                    &PaintableCallbacks = unsafe { nil }
}

pub enum SelectionState {
	none
	start
	end
	start_and_end
	full
}

pub fn (p &Paintable) is_paintable_box() bool {
	return p.is_box
}

pub fn (mut p Paintable) set_needs_repaint(should_invalidate_display_list InvalidateDisplayList) {
	p.needs_repaint = true
	if p.repaint_callback_target != unsafe { nil } && p.callbacks != unsafe { nil }
		&& p.callbacks.set_needs_repaint_callback != unsafe { nil } {
		p.callbacks.set_needs_repaint_callback(p.repaint_callback_target, p.layout_handle, should_invalidate_display_list)
	}
}

// Painting::push_replaced_image_paint_facts() followed by
// set_needs_repaint(PaintCommands) for this paintable's image provider. Returns
// false when its retained paint input cannot take the new contents.
pub fn (mut p Paintable) image_provider_contents_changed() bool {
	if p.repaint_callback_target == unsafe { nil } || p.callbacks == unsafe { nil }
		|| p.callbacks.image_contents_changed_callback == unsafe { nil } {
		return false
	}
	p.needs_repaint = true
	return p.callbacks.image_contents_changed_callback(p.repaint_callback_target, p.layout_handle)
}

pub fn (mut p Paintable) set_selection_state(state SelectionState) {
	if p.selection_state == state {
		return
	}
	p.selection_state = state
	// Paintable::set_selection_state() invalidates the box itself, or the text
	// paintable's containing block. The downstream callback retains the source
	// Layout::Node and performs that same targeted cache invalidation.
	p.set_needs_repaint(.paint_commands)
}

pub fn (p &Paintable) scroll_ancestor_to_offset_into_view(offset int) {
	if p.repaint_callback_target != unsafe { nil } && p.callbacks != unsafe { nil }
		&& p.callbacks.scroll_ancestor_to_offset_into_view_callback != unsafe { nil } {
		p.callbacks.scroll_ancestor_to_offset_into_view_callback(p.repaint_callback_target, p.layout_handle, offset)
	}
}

pub fn (p &Paintable) box_type_agnostic_position() CSSPixelPoint_ {
	if p.repaint_callback_target != unsafe { nil } && p.callbacks != unsafe { nil }
		&& p.callbacks.box_type_agnostic_position_callback != unsafe { nil } {
		return p.callbacks.box_type_agnostic_position_callback(p.repaint_callback_target, p.layout_handle)
	}
	return CSSPixelPoint_{}
}

pub fn (p &Paintable) inverse_transform_point(point CSSPixelPoint_) CSSPixelPoint_ {
	if p.repaint_callback_target != unsafe { nil } && p.callbacks != unsafe { nil }
		&& p.callbacks.inverse_transform_point_callback != unsafe { nil } {
		return p.callbacks.inverse_transform_point_callback(p.repaint_callback_target, p.layout_handle, point)
	}
	return point
}

@[heap]
pub struct PaintableBox {
	Paintable
pub mut:
	visible                   bool = true
	scrollable                bool
	stacking_context          bool
	has_scrollable_overflow_  bool
	wheel_scrolls_horizontal_ bool
	wheel_scrolls_vertical_   bool
	scroll_offset_            CSSPixelPoint_
	scrollable_overflow_rect_ ?CSSPixelRect_
	padding_box_x_            f64
	padding_box_y_            f64
	padding_box_width_        f64
	padding_box_height_       f64
	dom_node_                 &Node = unsafe { nil }
	snap_areas_              &PaintableSnapAreas = unsafe { nil }
}

pub fn (p &PaintableBox) could_be_scrolled_by_wheel_event() bool {
	return p.wheel_scrolls_horizontal_ || p.wheel_scrolls_vertical_
}

pub fn (p &PaintableBox) could_be_scrolled_horizontally_by_wheel_event() bool {
	return p.wheel_scrolls_horizontal_
}

pub fn (p &PaintableBox) could_be_scrolled_vertically_by_wheel_event() bool {
	return p.wheel_scrolls_vertical_
}

// Translation of PaintableBox::handle_mousewheel(). Returning false at a
// clamped edge lets EventHandler continue up the containing-block chain.
pub fn (mut p PaintableBox) handle_mousewheel(delta_x f64, delta_y f64) bool {
	if (delta_x == 0 || !p.wheel_scrolls_horizontal_)
		&& (delta_y == 0 || !p.wheel_scrolls_vertical_) {
		return false
	}
	current := p.scroll_offset()
	return p.set_scroll_offset_with_snap_strategy(CSSPixelPoint_{
		x_: current.x() + delta_x
		y_: current.y() + delta_y
	}, ScrollSnapSelectionStrategy_{
		type_: .end_position_and_direction
		start_offset: current
		displacement: CSSPixelPoint_{ x_: delta_x, y_: delta_y }
	})
}

pub fn (p &PaintableBox) is_visible() bool {
	return p.visible
}

pub fn (p &PaintableBox) has_stacking_context() bool {
	return p.stacking_context
}

pub fn (p &PaintableBox) has_scrollable_overflow() bool {
	return p.has_scrollable_overflow_
}

pub fn (p &PaintableBox) scroll_offset() CSSPixelPoint_ {
	// Painting::PaintableBox keeps element scroll state on the DOM element so it
	// survives layout-tree and paintable reconstruction.
	if p.dom_node_ != unsafe { nil } {
		if element := p.dom_node_.as_element() {
			return element.el_scroll_offset()
		}
	}
	return p.scroll_offset_
}

// Translation of Painting::PaintableBox::set_scroll_offset(). The retained
// display-list phase buckets remain valid: replay consumes a refreshed scroll
// snapshot, so only the assembled display list is discarded.
pub fn (mut p PaintableBox) set_scroll_offset(requested_offset CSSPixelPoint_) bool {
	return p.set_scroll_offset_with_snap_strategy(requested_offset, ScrollSnapSelectionStrategy_{})
}

// Rust painting/chrome_geometry.rs: scroll_offset_bounds(). Overflow and
// scrollport share document coordinates, including reverse writing modes.
pub fn (p &PaintableBox) minimum_scroll_offset() CSSPixelPoint_ {
	overflow := p.scrollable_overflow_rect_ or { return CSSPixelPoint_{} }
	return CSSPixelPoint_{x_: math.min(overflow.x_ - p.padding_box_x_, 0), y_: math.min(overflow.y_ - p.padding_box_y_, 0)}
}

pub fn (p &PaintableBox) maximum_scroll_offset() CSSPixelPoint_ {
	overflow := p.scrollable_overflow_rect_ or { return CSSPixelPoint_{} }
	return CSSPixelPoint_{x_: math.max(overflow.x_ + overflow.width() - p.padding_box_x_ - p.padding_box_width_, 0), y_: math.max(overflow.y_ + overflow.height() - p.padding_box_y_ - p.padding_box_height_, 0)}
}

pub fn (p &PaintableBox) clamp_scroll_offset(offset CSSPixelPoint_) CSSPixelPoint_ {
	if p.scrollable_overflow_rect_ == none { return offset }
	minimum := p.minimum_scroll_offset()
	maximum := p.maximum_scroll_offset()
	return CSSPixelPoint_{x_: math.max(minimum.x(), math.min(maximum.x(), offset.x())), y_: math.max(minimum.y(), math.min(maximum.y(), offset.y()))}
}

pub fn (mut p PaintableBox) set_scroll_offset_without_snapping(requested_offset CSSPixelPoint_) bool {
	if p.scrollable_overflow_rect_ == none { return false }
	return p.commit_scroll_offset(p.clamp_scroll_offset(requested_offset))
}

pub fn (mut p PaintableBox) set_scroll_offset_with_snap_strategy(requested_offset CSSPixelPoint_, strategy ScrollSnapSelectionStrategy_) bool {
	return p.apply_scroll_snap_destination(p.select_scroll_snap_destination(requested_offset, strategy))
}

pub fn (p &PaintableBox) select_scroll_snap_destination(requested_offset CSSPixelPoint_, strategy ScrollSnapSelectionStrategy_) ScrollSnapDestination_ {
	if p.scrollable_overflow_rect_ == none { return ScrollSnapDestination_{position: p.scroll_offset()} }
	offset := p.clamp_scroll_offset(requested_offset)
	if p.repaint_callback_target != unsafe { nil } && p.callbacks != unsafe { nil }
		&& p.callbacks.adjust_scroll_destination_callback != unsafe { nil } {
		destination := p.callbacks.adjust_scroll_destination_callback(p.repaint_callback_target, p.layout_handle, offset,
			strategy)
		return destination
	}
	return ScrollSnapDestination_{position: offset}
}

pub fn (mut p PaintableBox) record_scroll_snap_destination(destination ScrollSnapDestination_) {
	previous := p.snapped_areas()
	x := if destination.evaluated_x { destination.snapped_areas_x.clone() } else { previous.x }
	y := if destination.evaluated_y { destination.snapped_areas_y.clone() } else { previous.y }
	if destination.evaluated_x || destination.evaluated_y {
		p.snap_areas_ = retained_paintable_snap_areas(x, y)
	}
	if p.dom_node_ != unsafe { nil } {
		if mut element := p.dom_node_.as_element() {
			element.set_snapped_scroll_areas(x, y)
		}
	}
}

pub fn (mut p PaintableBox) apply_scroll_snap_destination(destination ScrollSnapDestination_) bool {
	p.record_scroll_snap_destination(destination)
	return p.set_scroll_offset_without_snapping(destination.position)
}

fn (mut p PaintableBox) commit_scroll_offset(offset CSSPixelPoint_) bool {
	if p.scroll_offset() == offset {
		return false
	}

	p.scroll_offset_ = offset
	if p.dom_node_ != unsafe { nil } {
		if mut element := p.dom_node_.as_element() {
			element.set_scroll_offset(none, offset)
		}
		mut document := unsafe { &Document(p.dom_node_.document()) }
		if document != unsafe { nil } {
			document.append_pending_scroll_event(PendingScrollEvent{target: p.dom_node_, type_: 'scroll'})
		}
	}
	p.set_needs_repaint(.no)
	return true
}

pub fn (p &PaintableBox) scrollable_overflow_rect() ?CSSPixelRect_ {
	return p.scrollable_overflow_rect_
}

pub enum InvalidationPropertyType {
	invalidate_self
	invalidate_whole_subtree
	class
	id
	tag_name
	attribute
	pseudo_class
}

pub struct InvalidationProperty {
pub mut:
	type_             InvalidationPropertyType
	name              string
	pseudo_class_name string
}

@[heap]
pub struct MutationObserver {
pub mut:
	callback_    ?&CallbackType
	delivery_queue_ ?&MutationObserverDeliveryQueue
	transient_nodes_ []&Node
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
	observer_  &MutationObserver = unsafe { nil }
	options_   MutationObserverOptions
	transient_ bool
	source_    &RegisteredObserver = unsafe { nil }
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
pub mut:
	rel_list_ ?&DOMTokenList
}

@[heap]
pub struct HTMLSlotElement {
	HTMLElement
pub mut:
	name_                    string
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
pub mut:
	image_element_model_        voidptr = unsafe { nil }
	dimension_attribute_source_ ?&Element
}

@[heap]
pub struct HTMLInputElement {
	HTMLElement

	// HTMLInputElement's checkedness is state, not merely the reflected content
	// attribute. These fields are used by RadioNodeList and the input algorithms.
pub mut:
	checkedness_             bool
	checkedness_initialized_ bool
	dirty_checkedness_       bool
	indeterminate_           bool
	is_open_                 bool
	input_element_model_     voidptr = unsafe { nil }
}

// HTMLInputElement checkedness is live control state. The content attribute is
// only its default until an interaction or IDL setter makes checkedness dirty.
pub fn (e &HTMLInputElement) checked() bool {
	if e.checkedness_initialized_ {
		return e.checkedness_
	}
	return unsafe { &Element(e) }.has_attribute('checked')
}

pub fn (mut e HTMLInputElement) set_checkedness(value bool, dirty bool) {
	e.checkedness_ = value
	e.checkedness_initialized_ = true
	e.dirty_checkedness_ = dirty
}

pub fn (e &HTMLInputElement) indeterminate() bool {
	return e.indeterminate_
}

pub fn (mut e HTMLInputElement) set_indeterminate(value bool) {
	if e.indeterminate_ == value {
		return
	}
	e.indeterminate_ = value
	mut node := unsafe { &Node(e) }
	node.invalidate_style(.other)
	node.set_needs_repaint(.paint_commands)
}

pub fn (e &HTMLInputElement) supports_a_picker() bool {
	type_ := unsafe { &Element(e) }.get_attribute_value('type').trim_space().to_lower()
	return type_ in ['file', 'color']
}

pub fn (e &HTMLInputElement) is_open() bool {
	return e.is_open_
}

pub fn (mut e HTMLInputElement) set_is_open(value bool) {
	if e.is_open_ == value {
		return
	}
	e.is_open_ = value
	mut node := unsafe { &Node(e) }
	node.invalidate_style(.other)
}

@[heap]
pub struct HTMLSelectElement {
	HTMLElement
pub mut:
	select_element_model_ voidptr = unsafe { nil }
	is_open_              bool
}

pub fn (e &HTMLSelectElement) is_open() bool {
	return e.is_open_
}

pub fn (mut e HTMLSelectElement) set_is_open(value bool) {
	if e.is_open_ == value {
		return
	}
	e.is_open_ = value
	mut node := unsafe { &Node(e) }
	node.invalidate_style(.other)
}

@[heap]
pub struct HTMLTableElement {
	HTMLElement
pub mut:
	cellpadding_ ?u32
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
	// The C++ implementation keeps a process-wide directory from integer IDs to nodes.
	// This V port is compiled without mutable module globals, so use the live node pointer
	// as the opaque process-local ID and reconstruct it in Node.from_unique_id().
	return UniqueNodeID(i64(voidptr(node)))
}

// Node identity is by pointer, but V compares `&Node` structurally (by value), which makes
// distinct nodes with equal fields (e.g. two fresh empty elements) compare equal and would
// recurse through parent/child cycles. Every `n == other` in the DOM means "is the same
// node", so compare the process-local unique id (the node's address) instead. Requires each
// node to have been assigned its id at creation via assign_unique_node_id.
pub fn (a Node) ==(b Node) bool {
	return a.unique_id_ == b.unique_id_
}

// Assign a node its process-local unique id (its own address) right after allocation. Every
// node factory that builds a node via a struct literal (rather than Node.new) must call this,
// otherwise the node keeps unique_id_ == 0 and compares equal to every other unassigned node.
fn assign_unique_node_id[T](node &T) &T {
	unsafe {
		mut n := &Node(node)
		n.EventTarget.data.kind = .node
		n.unique_id_ = UniqueNodeID(i64(voidptr(node)))
	}
	return node
}

fn deallocate_unique_id(node_id UniqueNodeID) {
	// Pointer-backed IDs do not have a separate directory entry to remove.
	_ = node_id
}

pub fn Node.from_unique_id(unique_id UniqueNodeID) ?&Node {
	if unique_id.value() == 0 {
		return none
	}
	return unsafe { &Node(voidptr(unique_id.value())) }
}

pub fn Node.new_with_realm(realm voidptr, document &Document, node_type NodeType) &Node {
	_ = realm
	mut node := &Node{
		node_type: node_type
		document_: document
		is_connected_: node_type == .document_node
	}
	node.EventTarget.data.kind = .node
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
	n.EventTarget.visit_edges(mut visitor)
	visitor.visit(n.document_)
	visitor.visit(n.child_nodes_)
	visitor.visit(n.layout_node_)
	visitor.visit(n.paintable_)
	for child in n.children {
		visitor.visit(child)
	}
	for observer in n.registered_observers() {
		visitor.visit(observer)
	}
	if assigned_slot := n.assigned_slot_internal() {
		visitor.visit(assigned_slot)
	}
	if manual_slot_assignment := n.manual_slot_assignment() {
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
	return n.node_type == .text_node || n.node_type == .comment_node || n.node_type == .cdata_section_node || n.node_type == .processing_instruction_node
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
	if n.unique_id_ == UniqueNodeID(0) {
		mut mutable_node := unsafe { &Node(n) }
		mutable_node.unique_id_ = allocate_unique_id(n)
	}
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
	return if n.parent_ == unsafe { nil } { 0 } else { n.index_in_parent_ }
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
	// Follow the live parent links without recursive frames or temporary options.
	mut current := unsafe { n }
	for current.parent_ != unsafe { nil } {
		current = current.parent_
	}
	return current
}

// ===== NonDocumentTypeChildNode mixin (https://dom.spec.whatwg.org/#nondocumenttypechildnode) =====

// https://dom.spec.whatwg.org/#dom-nondocumenttypechildnode-previouselementsibling
pub fn (n &Node) previous_element_sibling() ?&Element {
	mut sibling := n.previous_sibling()
	for {
		s := sibling or { break }
		if element := s.as_element() {
			return element
		}
		sibling = s.previous_sibling()
	}
	return none
}

// https://dom.spec.whatwg.org/#dom-nondocumenttypechildnode-nextelementsibling
pub fn (n &Node) next_element_sibling() ?&Element {
	mut sibling := n.next_sibling()
	for {
		s := sibling or { break }
		if element := s.as_element() {
			return element
		}
		sibling = s.next_sibling()
	}
	return none
}

// ===== ChildNode mixin (https://dom.spec.whatwg.org/#childnode) =====
fn node_or_string_list_contains(nodes []NodeOrString, target &Node) bool {
	for node_or_string in nodes {
		if node_or_string.is_text {
			continue
		}
		if candidate := node_or_string.node {
			if candidate.is_same_node(target) {
				return true
			}
		}
	}
	return false
}

// This's first preceding sibling not in `nodes`, or none.
fn (n &Node) viable_previous_sibling_for_insertion(nodes []NodeOrString) ?&Node {
	mut sibling := n.previous_sibling()
	for {
		s := sibling or { break }
		if !node_or_string_list_contains(nodes, s) {
			return s
		}
		sibling = s.previous_sibling()
	}
	return none
}

// This's first following sibling not in `nodes`, or none.
fn (n &Node) viable_next_sibling_for_insertion(nodes []NodeOrString) ?&Node {
	mut sibling := n.next_sibling()
	for {
		s := sibling or { break }
		if !node_or_string_list_contains(nodes, s) {
			return s
		}
		sibling = s.next_sibling()
	}
	return none
}

// https://dom.spec.whatwg.org/#dom-childnode-before
pub fn (mut n Node) before(nodes []NodeOrString) ! {
	mut parent := n.parent() or { return }
	viable_previous_sibling := n.viable_previous_sibling_for_insertion(nodes)
	node_to_insert := convert_nodes_to_single_node(nodes, n.document())!
	// If viablePreviousSibling is null, use parent's first child; otherwise its next sibling.
	before_sibling := if vps := viable_previous_sibling {
		vps.next_sibling()
	} else {
		parent.first_child()
	}
	parent.pre_insert(node_to_insert, before_sibling)!
}

// https://dom.spec.whatwg.org/#dom-childnode-after
pub fn (mut n Node) after(nodes []NodeOrString) ! {
	mut parent := n.parent() or { return }
	viable_next_sibling := n.viable_next_sibling_for_insertion(nodes)
	node_to_insert := convert_nodes_to_single_node(nodes, n.document())!
	parent.pre_insert(node_to_insert, viable_next_sibling)!
}

// https://dom.spec.whatwg.org/#dom-childnode-replacewith
pub fn (mut n Node) replace_with(nodes []NodeOrString) ! {
	mut parent := n.parent() or { return }
	viable_next_sibling := n.viable_next_sibling_for_insertion(nodes)
	node_to_insert := convert_nodes_to_single_node(nodes, n.document())!
	// If this's parent is still parent, replace this with node within parent (it may have been
	// inserted into node during the conversion).
	if current_parent := n.parent() {
		if current_parent.is_same_node(parent) {
			parent.replace_child(node_to_insert, n)!
			return
		}
	}
	parent.pre_insert(node_to_insert, viable_next_sibling)!
}

pub fn (n &Node) is_descendant_of(other &Node) bool {
	for ancestor := n.parent(); ancestor != none;  {
		current := ancestor or { break }
		if current.is_same_node(other) {
			return true
		}
		ancestor = current.parent()
	}
	return false
}

pub fn (n &Node) is_inclusive_descendant_of(other &Node) bool {
	return n.is_same_node(other) || n.is_descendant_of(other)
}

pub fn (n &Node) is_ancestor_of(other &Node) bool {
	return other.is_descendant_of(n)
}

pub fn (n &Node) is_inclusive_ancestor_of(other &Node) bool {
	return n.is_same_node(other) || n.is_ancestor_of(other)
}

// https://dom.spec.whatwg.org/#dom-node-contains
// Returns true if `other` is an inclusive descendant of this node (false when `other` is null).
pub fn (n &Node) contains(other ?&Node) bool {
	target := other or { return false }
	return n.is_inclusive_ancestor_of(target)
}

pub fn (n &Node) as_element() ?&Element {
	if !n.is_element() {
		return none
	}
	return unsafe { &Element(n) }
}

pub fn (n &Node) as_document() ?&Document {
	if !n.is_document() {
		return none
	}
	return unsafe { &Document(n) }
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
	fragment := unsafe { &DocumentFragment(n) }
	if !fragment.is_shadow_root_ {
		return none
	}
	return unsafe { &ShadowRoot(n) }
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
	event := Event.create(event_name, EventInit{
		bubbles: bubbles
	})
	event_target_dispatch_event(unsafe { &EventTarget(n) }, event)
}

pub fn (n &Node) dispatch_event(event &Event) {
	event_target_dispatch_event(unsafe { &EventTarget(n) }, event)
}

pub fn (n &Node) has_event_listener(type_ string) bool {
	return unsafe { &EventTarget(n) }.has_event_listener(type_)
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
	for current := ?&Node(n); current != none;  {
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
	for current := ?&Node(n); current != none;  {
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
	for current := ?&Node(n); current != none;  {
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

// A closure can only mutate a captured value-type (array/builder/map) through a pointer,
// because V captures such variables by value. Append to an array through its pointer.
@[inline]
fn dom_ptr_push[T](p &[]T, item T) {
	unsafe {
		mut a := *p
		a << item
		*p = a
	}
}

// https://dom.spec.whatwg.org/#concept-descendant-text-content
pub fn (n &Node) descendant_text_content() string {
	return n.collect_text_content(true)
}

// These synchronous reads invoke no callbacks. Count first so the returned
// string needs one exact allocation, with no builder growth or spare copy left
// in the document's arena. Ordinary children exclude shadow/template contents.
fn (n &Node) text_content_byte_length(recursive bool) int {
	mut length := 0
	for child in n.children {
		if child.is_text() {
			if data := child.character_data() { length += data.data_.len }
		} else if recursive {
			length += child.text_content_byte_length(true)
		}
	}
	return length
}

fn (n &Node) copy_text_content_bytes(buffer &u8, recursive bool) int {
	mut written := 0
	for child in n.children {
		if child.is_text() {
			if data := child.character_data() {
				unsafe { vmemcpy(buffer + written, data.data_.str, data.data_.len) }
				written += data.data_.len
			}
		} else if recursive {
			written += child.copy_text_content_bytes(unsafe { buffer + written }, true)
		}
	}
	return written
}

fn (n &Node) collect_text_content(recursive bool) string {
	length := n.text_content_byte_length(recursive)
	if length == 0 { return '' }
	bytes := []u8{len:length + 1}
	n.copy_text_content_bytes(unsafe { &u8(bytes.data) }, recursive)
	return unsafe { (&u8(bytes.data)).vstring_with_len(length) }
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
	text_nodes_ptr := &text_nodes
	n.visit_inclusive_subtree(fn [text_nodes_ptr] (node &Node) TraversalDecision {
		if node.is_exclusive_text() {
			dom_ptr_push(text_nodes_ptr, node)
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

				for _, live_range in dom_live_ranges {
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
	for sibling := node.previous_sibling(); sibling != none;  {
		current := sibling or { break }
		if !current.is_exclusive_text() {
			break
		}
		nodes.prepend(current)
		sibling = current.previous_sibling()
	}
	for sibling := node.next_sibling(); sibling != none;  {
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
	// To get the node navigable of a node node, return the navigable whose active document is node's node document,
	// or null if there is no such navigable.
	return doc.navigable()
}

fn reason_may_affect_has_selectors(reason StyleInvalidationReason) bool {
	// :has() selectors match based on DOM state only (structure, attributes, pseudo-classes). Reasons that don't change
	// any DOM state can't affect :has() matching, so we can skip scheduling :has() ancestor invalidation.
	return reason !in [.base_url_changed, .css_font_loaded, .html_iframe_element_geometry_change,
		.html_object_element_update_layout_and_child_objects, .navigable_set_viewport_size,
		.settings_change, .style_sheet_disabled_state_change, .style_sheet_replace,
		.has_pseudo_class_match_change]
}

fn schedule_has_walk_for_parent(mutated_node &Node, style_scope &StyleScope, parent &Node, reason StyleInvalidationReason) {
	if !style_scope.may_have_has_selectors() {
		return
	}
	is_child_list_mutation := reason == .node_remove || reason == .node_insert_before
	has_sibling_combinator_has_selectors := is_child_list_mutation
		&& style_scope.may_have_has_selectors_with_relative_selector_that_has_sibling_combinator()
	if is_child_list_mutation
		&& style_scope.pending_has_invalidation_covers_all_child_list_mutation_features(parent) {
		return
	}
	if is_child_list_mutation && style_scope.has_featureless_sensitive_has_selectors() {
		mut mutable_style_scope := unsafe { &StyleScope(style_scope) }
		mutable_style_scope.record_conservative_pending_has_invalidation(parent, true)
		if has_sibling_combinator_has_selectors {
			invalidate_children_affected_by_has_sibling_combinators(parent)
		}
		return
	}

	// Sibling-combinator :has() selectors are sensitive to featureless insertions/removals because a plain node can
	// still change adjacency and following-sibling relationships.
	may_affect_has_match := mutated_node.is_character_data()
		|| style_scope.subtree_may_affect_has_selectors(mutated_node)
		|| has_sibling_combinator_has_selectors
	if !may_affect_has_match {
		return
	}

	mut mutable_style_scope := unsafe { &StyleScope(style_scope) }
	mutable_style_scope.record_pending_has_invalidation_mutation_features(parent, mutated_node, true)
	mutable_style_scope.schedule_ancestors_style_invalidation_due_to_presence_of_has(parent)
	if !has_sibling_combinator_has_selectors {
		return
	}
	invalidate_children_affected_by_has_sibling_combinators(parent)
}

fn invalidate_children_affected_by_has_sibling_combinators(parent &Node) {
	for child in parent.children {
		if element := child.as_element() {
			if element.affected_by_has_pseudo_class_with_relative_selector_that_has_sibling_combinator {
				mut mutable_element := unsafe { &Element(element) }
				mutable_element.invalidate_style_if_affected_by_has()
			}
		}
	}
}

fn invalidate_structurally_affected_siblings(node &Node, reason StyleInvalidationReason) {
	is_insertion_or_removal := reason == .node_insert_before || reason == .node_remove
	mut last_child_transition_target := ?&Element(none)
	mut first_child_transition_target := ?&Element(none)
	if is_insertion_or_removal {
		previous_element := node.previous_element_sibling()
		next_element := node.next_element_sibling()
		if next_element == none {
			last_child_transition_target = previous_element
		}
		if previous_element == none {
			first_child_transition_target = next_element
		}

		if parent := node.parent() {
			if parent.has_child_affected_by_backward_structural_changes() {
				for sibling := node.previous_sibling(); sibling != none;  {
					current := sibling or { break }
					mut mutable_document := unsafe { &Document(node.document()) }
					mutable_document.record_previous_sibling_invalidation_walk_visit()
					if element := current.as_element() {
						is_last_child_transition_target := if target := last_child_transition_target {
							voidptr(element) == voidptr(target)
						} else {
							false
						}
						needs_mark := element.affected_by_backward_positional_pseudo_class
							|| (element.affected_by_last_child_pseudo_class
								&& is_last_child_transition_target)
						if needs_mark {
							mark_sibling_for_style_update(element)
						}
					}
					sibling = current.previous_sibling()
				}
			}
		}
	}

	mut current_sibling_distance := 1
	for sibling := node.next_sibling(); sibling != none;  {
		current := sibling or { break }
		if element := current.as_element() {
			mut needs_to_invalidate := false
			is_first_child_transition_target := if target := first_child_transition_target {
				voidptr(element) == voidptr(target)
			} else {
				false
			}
			if is_insertion_or_removal {
				if element.affected_by_indirect_sibling_combinator {
					needs_to_invalidate = true
				} else if element.affected_by_forward_positional_pseudo_class {
					needs_to_invalidate = true
				} else if element.affected_by_first_child_pseudo_class
					&& is_first_child_transition_target {
					needs_to_invalidate = true
				} else if element.affected_by_direct_sibling_combinator
					&& current_sibling_distance <= element.sibling_invalidation_distance {
					needs_to_invalidate = true
				}
			} else if element.affected_by_indirect_sibling_combinator {
				needs_to_invalidate = true
			} else if element.affected_by_forward_positional_pseudo_class {
				needs_to_invalidate = true
			} else if element.affected_by_direct_sibling_combinator
				&& current_sibling_distance <= element.sibling_invalidation_distance {
				needs_to_invalidate = true
			}
			if needs_to_invalidate {
				mark_sibling_for_style_update(element)
			}
			current_sibling_distance++
		}
		sibling = current.next_sibling()
	}
}

fn mark_descendant_shadow_roots_for_style_update(element &Element) {
	element.as_node().for_each_shadow_including_inclusive_descendant(fn (inclusive_descendant &Node) TraversalDecision {
		descendant_element := inclusive_descendant.as_element() or { return .@continue }
		shadow_root := descendant_element.shadow_root() or { return .@continue }
		mut shadow_node := unsafe { &Node(shadow_root) }
		shadow_node.set_entire_subtree_needs_style_update(true)
		shadow_node.set_needs_style_update(true)
		return .@continue
	})
}

fn mark_sibling_for_style_update(element &Element) {
	mut node := element.as_node()
	if element.affected_by_structural_pseudo_class_in_non_subject_position
		|| element.affected_by_sibling_combinator_in_non_subject_position {
		node.set_entire_subtree_needs_style_update(true)
		return
	}
	node.set_needs_style_update(true)
	mark_descendant_shadow_roots_for_style_update(element)
}

fn mark_ancestors_as_having_child_needing_style_update(node &Node) {
	for ancestor := node.parent_or_shadow_host(); ancestor != none;  {
		mut current := unsafe { &Node(ancestor or { break }) }
		current.set_child_needs_style_update(true)
		ancestor = current.parent_or_shadow_host()
	}
}

fn element_is_affected_by_same_parent_move(element &Element) bool {
	return element.affected_by_forward_structural_changes()
		|| element.affected_by_backward_structural_changes()
		|| element.affected_by_has_pseudo_class_in_subject_position
		|| element.affected_by_has_pseudo_class_in_non_subject_position
		|| element.affected_by_has_pseudo_class_with_relative_selector_that_has_sibling_combinator
}

fn schedule_has_walk_for_parent_scopes(mutated_node &Node, parent &Node, reason StyleInvalidationReason) {
	// Resolve the same complete scope snapshot before scheduling can mutate roots.
	scopes := parent.observing_style_scopes()
	schedule_has_walk_for_parent(mutated_node, scopes.first, parent, reason)
	for scope in scopes.additional {
		schedule_has_walk_for_parent(mutated_node, scope, parent, reason)
	}
}

fn invalidate_style_after_same_parent_move(node &Node, reason StyleInvalidationReason) {
	document := node.document()
	if document.needs_full_style_update() {
		return
	}

	if parent := node.parent_or_shadow_host() {
		schedule_has_walk_for_parent_scopes(node, parent, reason)
	}

	for ancestor := node.parent_or_shadow_host(); ancestor != none;  {
		current := ancestor or { break }
		if current.entire_subtree_needs_style_update() {
			return
		}
		ancestor = current.parent_or_shadow_host()
	}

	mut mutable_node := unsafe { &Node(node) }
	if element := node.as_element() {
		if element.affected_by_structural_pseudo_class_in_non_subject_position
			|| element.affected_by_sibling_combinator_in_non_subject_position {
			mutable_node.set_entire_subtree_needs_style_update(true)
		} else if element_is_affected_by_same_parent_move(element) {
			mutable_node.set_needs_style_update(true)
		}
	} else if !node.is_character_data() {
		mutable_node.set_needs_style_update(true)
	}
	invalidate_structurally_affected_siblings(node, reason)
	mark_ancestors_as_having_child_needing_style_update(node)
}

pub fn (mut n Node) invalidate_style(reason StyleInvalidationReason) {
	doc := n.document()
	if doc == unsafe { nil } {
		return
	}
	// A full pass recomputes every observing scope, including :has() anchors.
	// Do not first accumulate selective mutation histories which that pass
	// immediately discards. Document invalidations still update their counters.
	if !n.is_document() && doc.needs_full_style_update() { return }
	style_scope := n.style_scope()
	if reason == .node_remove || reason == .node_insert_before {
		if parent := n.parent_or_shadow_host() {
			schedule_has_walk_for_parent_scopes(unsafe { &Node(n) }, parent, reason)
		}
	} else if style_scope.may_have_has_selectors() && reason_may_affect_has_selectors(reason) {
		mut mutable_style_scope := unsafe { &StyleScope(style_scope) }
		mutable_style_scope.record_pending_has_invalidation_mutation_features(unsafe { &Node(n) },
			unsafe { &Node(n) }, false)
		mutable_style_scope.schedule_ancestors_style_invalidation_due_to_presence_of_has(&n)
	}
	// Character data has no style of its own. Its observable :has() ancestor
	// invalidation was scheduled above, so no direct invalidation remains.
	if n.is_character_data() {
		return
	}
	if n.is_document() {
		mut mutable_doc := unsafe { &Document(doc) }
		mutable_doc.record_full_style_invalidation()
		mutable_doc.set_needs_full_style_update(true)
		return
	}
	if doc.needs_full_style_update() {
		return
	}
	for ancestor := n.parent_or_shadow_host(); ancestor != none;  {
		current := ancestor or { break }
		if current.entire_subtree_needs_style_update() {
			return
		}
		ancestor = current.parent_or_shadow_host()
	}
	// When invalidating style for a node, we actually invalidate:
	// - the node itself
	// - all of its descendants
	// - preceding siblings that depend on following-sibling counts (only on DOM insert/remove)
	// - subsequent siblings that depend on previous siblings or sibling combinators
	// FIXME: This is a lot of invalidation and we should implement more sophisticated invalidation to do less work!
	n.set_entire_subtree_needs_style_update(true)
	invalidate_structurally_affected_siblings(unsafe { &Node(n) }, reason)
	mark_ancestors_as_having_child_needing_style_update(unsafe { &Node(n) })
}

pub fn (node &Node) style_scope() &StyleScope {
	document := node.document()
	if document != unsafe { nil } && document.shadow_roots.len == 0
		&& document.style_scope_adoption_depth_ == 0 {
		return document.style_scope()
	}
	root := node.root()
	if shadow_root := root.as_shadow_root() {
		if shadow_root.uses_document_style_sheets() {
			return node.document().style_scope()
		}
		return shadow_root.style_scope()
	}
	return node.document().style_scope()
}

struct ObservingStyleScopes {
	first &StyleScope
mut:
	additional []&StyleScope
}

fn (mut scopes ObservingStyleScopes) add(scope &StyleScope) {
	if voidptr(scope) == voidptr(scopes.first) || scope in scopes.additional {
		return
	}
	scopes.additional << scope
}

fn (node &Node) observing_style_scopes() ObservingStyleScopes {
	// Without any shadow roots in the owning document, every ancestor observes
	// the same document scope. Avoid allocating a collection and walking each
	// ancestor back to its root before the first style calculation.
	document := node.document()
	if document != unsafe { nil } && document.shadow_roots.len == 0
		&& document.style_scope_adoption_depth_ == 0 {
		return ObservingStyleScopes{
			first: document.style_scope()
		}
	}
	mut scopes := ObservingStyleScopes{first: node.style_scope()}
	if element := node.as_element() {
		if shadow_root := element.shadow_root() {
			scopes.add(shadow_root.style_scope())
		}
	}
	// Ordinary parent edges stay in one tree and have the same effective scope.
	// Resolve it again only when leaving a shadow root for its host. Adoption
	// hooks retain the per-node lookup while document ownership is in transition.
	mut reuse_ancestor_scope := document != unsafe { nil } && document.style_scope_adoption_depth_ == 0
	mut previous := unsafe { node }
	for ancestor := node.parent_or_shadow_host(); ancestor != none;  {
		current := ancestor or { break }
		if voidptr(current.document()) != voidptr(document) {
			reuse_ancestor_scope = false
		}
		if !reuse_ancestor_scope || previous.is_shadow_root() {
			scopes.add(current.style_scope())
		}
		if element := current.as_element() {
			if shadow_root := element.shadow_root() {
				scopes.add(shadow_root.style_scope())
			}
		}
		previous = current
		ancestor = current.parent_or_shadow_host()
	}
	return scopes
}

pub fn (node &Node) for_each_style_scope_which_may_observe_the_node(callback fn (&StyleScope)) {
	// Resolve the complete scope snapshot before any callback can mutate roots.
	scopes := node.observing_style_scopes()
	callback(scopes.first)
	for scope in scopes.additional {
		callback(scope)
	}
}

pub fn (d &Document) style_computer() &StyleComputer {
	if d.style_computer != unsafe { nil } {
		return d.style_computer
	}
	return &StyleComputer{}
}

pub fn (mut d Document) style_invalidator() &StyleInvalidator {
	if d.style_invalidator_ == unsafe { nil } {
		d.style_invalidator_ = &StyleInvalidator{}
	}
	return d.style_invalidator_
}

pub fn (d CSSDisplay_) is_contents() bool {
	// Mirrored from CSS::Display::is_contents() by the dom<->css bridge (computed_properties_to_dom).
	return d.is_contents_
}

pub fn (d CSSDisplay_) is_inline_outside() bool {
	// Mirrored from CSS::Display::is_inline_outside() by the dom<->css bridge (computed_properties_to_dom).
	return d.is_inline_outside_
}

pub fn (d CSSDisplay_) is_flow_inside() bool {
	// Mirrored from CSS::Display::is_flow_inside() by the dom<->css bridge (computed_properties_to_dom).
	return d.is_flow_inside_
}

// The following read the fields populated by the layout module (layout/dom_layout_bridge.v) when it
// attaches the real layout tree onto the DOM; before attachment they return the empty/none defaults.
pub fn (ln &LayoutNode) display() CSSDisplay_ {
	return ln.display_
}

pub fn (ln &LayoutNode) is_atomic_inline() bool {
	return ln.is_atomic_inline_
}

pub fn (ln &LayoutNode) is_replaced_box() bool {
	return ln.is_replaced_box_
}

pub fn (ln &LayoutNode) parent() ?&LayoutNode {
	return ln.parent_
}

pub fn (ln &LayoutNode) containing_block() ?&LayoutNode {
	return ln.containing_block_
}

pub fn (ln &LayoutNode) is_anonymous() bool {
	return ln.is_anonymous_
}

pub fn (ln &LayoutNode) dom_node() ?&Node {
	return ln.dom_node_
}

pub fn (ln &LayoutNode) is_text_node() bool {
	return ln.is_text_node_
}

pub fn (ln &LayoutNode) overflow_x() CSSOverflow_ {
	return ln.overflow_x_
}

pub fn (ln &LayoutNode) user_select_is_none() bool {
	return ln.user_select_none_
}

pub fn (ln &LayoutNode) white_space_collapse_is_not_collapse() bool {
	return ln.white_space_collapse_is_not_collapse_
}

pub fn (ln &LayoutNode) real_layout_handle() voidptr {
	return ln.layout_handle
}

fn element_allows_accessible_name_from_content(element &Element, should_compute_role ShouldComputeRole) bool {
	if allows := element.document().element_allows_accessible_name_from_content(element, should_compute_role == .yes) {
		return allows
	}
	role := element_aria_role(element) or { return false }
	return aria_role_allows_name_from_content(role)
}

// The HTML/ARIA implementation above is the normal engine path. This local
// fallback keeps standalone DOM-only tests useful when no owning HTML module
// has installed the document callback.
fn element_aria_role(element &Element) ?string {
	if value := element.get_attribute('role') {
		for token in value.fields() {
			if token.len > 0 {
				return token.to_lower()
			}
		}
	}
	if !element.is_html_element() {
		return none
	}
	return html_local_name_to_default_aria_role(element.local_name())
}

// https://www.w3.org/TR/html-aria/ — implicit ARIA semantics for HTML
// elements relevant to name-from-content. The mapping below covers the
// elements whose default roles appear in `aria_role_allows_name_from_content`.
fn html_local_name_to_default_aria_role(name string) ?string {
	return match name {
		'button' { 'button' }
		'a' { 'link' }
		'area' { 'link' }
		'h1', 'h2', 'h3', 'h4', 'h5', 'h6' { 'heading' }
		'th' { 'columnheader' }
		'td' { 'cell' }
		'tr' { 'row' }
		'option' { 'option' }
		'summary' { 'button' }
		else { none }
	}
}

// https://www.w3.org/TR/wai-aria-1.2/#namefromcontent
fn aria_role_allows_name_from_content(role string) bool {
	return role in [
		'button',
		'cell',
		'checkbox',
		'columnheader',
		'gridcell',
		'heading',
		'link',
		'menuitem',
		'menuitemcheckbox',
		'menuitemradio',
		'option',
		'radio',
		'row',
		'rowheader',
		'sectionhead',
		'switch',
		'tab',
		'tooltip',
		'treeitem',
	]
}

fn append_layout_rendered_text(node &LayoutNode, mut builder strings.Builder) {
	if node.rendered_text_.len > 0 {
		builder.write_string(node.rendered_text_)
	}
	for child in node.children_ {
		append_layout_rendered_text(child, mut builder)
	}
}

fn append_generated_content_text(node &LayoutNode, pseudo_element PseudoElement, mut builder strings.Builder) {
	if generated_for := node.generated_for_pseudo_element() {
		if generated_for == pseudo_element {
			append_layout_rendered_text(node, mut builder)
			return
		}
	}
	for child in node.children_ {
		append_generated_content_text(child, pseudo_element, mut builder)
	}
}

fn generated_content_text(element &Element, pseudo_element PseudoElement) string {
	layout_node := element.as_node().layout_node() or { return '' }
	mut builder := strings.new_builder(0)
	append_generated_content_text(layout_node, pseudo_element, mut builder)
	return builder.str()
}

fn rendered_text_for_accessibility(node &Node) ?string {
	layout_node := node.layout_node() or { return none }
	if !layout_node.is_text_node_ {
		return none
	}
	return layout_node.rendered_text_
}

fn element_is_referenced_for_accessibility(element &Element) bool {
	return element.is_referenced()
}

fn element_has_referenced_and_hidden_ancestor(element &Element) bool {
	return element.has_referenced_and_hidden_ancestor()
}

fn append_accessible_text(mut builder strings.Builder, text string) {
	if text.len == 0 {
		return
	}
	if builder.len > 0 {
		builder.write_string(' ')
	}
	builder.write_string(text)
}

pub fn (mut n Node) invalidate_style_with_properties(reason StyleInvalidationReason, properties []InvalidationProperty, options StyleInvalidationOptions) {
	if n.is_character_data() {
		return
	}
	doc := n.document()
	if doc == unsafe { nil } {
		return
	}
	if doc.needs_full_style_update() {
		if options.invalidate_self { n.set_needs_style_update(true) }
		return
	}
	style_scopes := n.observing_style_scopes()
	style_scope := style_scopes.first
	additional_scopes := style_scopes.additional
	mut properties_used_in_has_selectors := false
	for property in properties {
		if doc.style_computer().invalidation_property_used_in_has_selector(property, style_scope) {
			properties_used_in_has_selectors = true
		}
		for additional_scope in additional_scopes {
			if doc.style_computer().invalidation_property_used_in_has_selector(property, additional_scope) {
				properties_used_in_has_selectors = true
			}
		}
	}
	if properties_used_in_has_selectors {
		mut mutable_style_scope := unsafe { &StyleScope(style_scope) }
		mutable_style_scope.record_pending_has_invalidation_mutation_properties(unsafe { &Node(n) },
			properties)
		mutable_style_scope.schedule_ancestors_style_invalidation_due_to_presence_of_has(&n)
		for additional_scope in additional_scopes {
			mut mutable_additional_scope := unsafe { &StyleScope(additional_scope) }
			mutable_additional_scope.record_pending_has_invalidation_mutation_properties(unsafe { &Node(n) },
				properties)
			mutable_additional_scope.schedule_ancestors_style_invalidation_due_to_presence_of_has(&n)
		}
	}
	if options.invalidate_self {
		n.set_needs_style_update(true)
	}
	mut document := unsafe { &Document(doc) }
	mut invalidator := document.style_invalidator()
	plan := doc.style_computer().invalidation_plan_for_properties(properties, style_scope)
	if invalidator.enqueue_invalidation_plan(&n, reason, *plan) {
		return
	}
	for additional_scope in additional_scopes {
		additional_plan := doc.style_computer().invalidation_plan_for_properties(properties, additional_scope)
		if invalidator.enqueue_invalidation_plan(&n, reason, *additional_plan) {
			return
		}
	}
}

pub fn (n &Node) child_text_content() string {
	if !n.is_parent_node() {
		return ''
	}
	return n.collect_text_content(false)
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
	// Documents created through direct V struct literals predate the cached flag,
	// but a Document is always its own connected shadow-including root.
	return n.is_connected_ || n.is_document()
}

pub fn (mut n Node) set_is_connected(is_connected bool) {
	n.is_connected_ = is_connected
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
	if !(node.is_document_fragment() || node.is_document_type() || node.is_element() || node.is_text() || node.is_comment() || node.node_type == .processing_instruction_node || node.is_cdata_section()) {
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
			if node_element_child_count == 1 && (node_has_child_element(n) || node_child_is_document_type(child) || node_has_following_doctype(child)) {
				return error('HierarchyRequestError: Invalid node type for insertion')
			}
		} else if node.is_element() {
			if node_has_child_element(n) || node_child_is_document_type(child) || node_has_following_doctype(child) {
				return error('HierarchyRequestError: Invalid node type for insertion')
			}
		} else if node.is_document_type() {
			if node_has_child_document_type(n) || node_has_preceding_element(child) || (child == none && node_has_child_element(n)) {
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
	if !(node.is_document_fragment() || node.is_document_type() || node.is_element() || node.is_text() || node.is_comment() || node.node_type == .processing_instruction_node || node.is_cdata_section()) {
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
			if node_element_child_count == 1 && (node_first_child_element_is_not(n, child) || node_has_following_doctype(child)) {
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

fn collect_nodes_for_post_connection(node &Node, mut nodes []&Node) {
	// This collector has no observable callbacks: retain the traversal's exact
	// node, shadow-root, light-child order without a captured visitor lifetime.
	nodes << node
	if element := node.as_element() {
		if shadow_root := element.shadow_root() {
			collect_nodes_for_post_connection(shadow_root_as_node(shadow_root), mut nodes)
		}
	}
	for child in node.children {
		collect_nodes_for_post_connection(child, mut nodes)
	}
}

fn run_post_connection_steps(nodes []&Node) {
	// Snapshot before invoking any step; callbacks can change the tree. Only
	// that local pointer vector uses temporary storage, never callback writes.
	scratch := platform.begin_thread_scratch('post-connection snapshot')
	mut snapshot := []&Node{}
	for node in nodes { collect_nodes_for_post_connection(node, mut snapshot) }
	scratch.leave()
	for node in snapshot {
		if node.is_connected() {
			mut mutable_node := unsafe { &Node(node) }
			mutable_node.post_connection()
		}
	}
	scratch.finish()
}

fn register_slot_descendants_with_shadow_root(node &Node) {
	shadow_root := node.root().as_shadow_root() or { return }
	node.visit_inclusive_subtree(fn [shadow_root] (inclusive_descendant &Node) TraversalDecision {
		if slot := node_as_html_slot_element(inclusive_descendant) {
			mut mutable_shadow_root := unsafe { &ShadowRoot(shadow_root) }
			mutable_shadow_root.register_slot(slot)
		}
		return .@continue
	})
}

fn unregister_slot_descendants_from_shadow_root(node &Node, root &Node) []&HTMLSlotElement {
	shadow_root := root.as_shadow_root() or { return [] }
	return unregister_slot_descendants_from_shadow_root_impl(node, shadow_root)
}

fn unregister_slot_descendants_from_shadow_root_impl(node &Node,
	shadow_root &ShadowRoot) []&HTMLSlotElement {
	mut descendant_slots := []&HTMLSlotElement{}
	if slot := node_as_html_slot_element(node) {
		mut mutable_shadow_root := unsafe { &ShadowRoot(shadow_root) }
		mutable_shadow_root.unregister_slot(slot)
		descendant_slots << slot
	}
	for child in node.children {
		descendant_slots << unregister_slot_descendants_from_shadow_root_impl(child,
			shadow_root)
	}
	return descendant_slots
}

// https://dom.spec.whatwg.org/#concept-node-insert
pub fn (mut n Node) insert_before(node &Node, child ?&Node, suppress_observers bool) {
	if n.document() != unsafe { nil } {
		n.document().notify_editing_history_dom_mutation()
	}
	// 1. Let nodes be node's children, if node is a DocumentFragment node; otherwise << node >>.
	scratch := platform.begin_thread_scratch('insertion snapshot')
	mut nodes := []&Node{}
	if node.is_document_fragment() {
		nodes = node.children_as_vector()
	} else {
		nodes << node
	}
	// Only this private vector is temporary. Restore the caller's owner before
	// adoption, observer records, and reentrant callbacks publish their data.
	scratch.leave()
	defer { scratch.finish() }
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
		for _, live_range in dom_live_ranges {
			mut range := unsafe { &Range(live_range) }
			if range.start_container_ == &n && range.start_offset_ > child_node.index() {
				range.start_offset_ += count
			}
			if range.end_container_ == &n && range.end_offset_ > child_node.index() {
				range.end_offset_ += count
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
		node: node
	})
	run_post_connection_steps(nodes)
	if n.is_connected() {
		// NB: Called during DOM insertion, layout is not up to date.
		if layout_node := n.unsafe_layout_node() {
			if layout_node.display().is_contents() {
				if parent_element := n.parent_element() {
					mut parent_node := unsafe { &Node(parent_element.as_node()) }
					parent_node.set_needs_layout_tree_update(true, .node_insert_before_with_display_contents)
				}
			}
		}
		n.set_needs_layout_tree_update(true, .node_insert_before)
	}
	// AD-HOC: invalidate the ordinal of the first list_item of the list_owner of the child node, if any.
	if child_node := child {
		if child_element := child_node.as_element() {
			mut mutable_child_element := unsafe { &Element(child_element) }
			mutable_child_element.maybe_invalidate_ordinals_for_list_owner(none)
		}
	} else if element := n.as_element() {
		if !element.is_html_ol_ul_menu_element() {
			mut mutable_element := unsafe { &Element(element) }
			mutable_element.maybe_invalidate_ordinals_for_list_owner(none)
		}
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
	// 4. For each live range whose start node is an inclusive descendant of node, set its start to (parent, index).
	for _, live_range in dom_live_ranges {
		mut range := unsafe { &Range(live_range) }
		if range.start_container_.is_inclusive_descendant_of(node) {
			range.start_container_ = parent
			range.start_offset_ = index
		}
	}
	// 5. For each live range whose end node is an inclusive descendant of node, set its end to (parent, index).
	for _, live_range in dom_live_ranges {
		mut range := unsafe { &Range(live_range) }
		if range.end_container_.is_inclusive_descendant_of(node) {
			range.end_container_ = parent
			range.end_offset_ = index
		}
	}
	// 6. For each live range whose start node is parent and start offset is greater than index, decrease its start offset by 1.
	for _, live_range in dom_live_ranges {
		mut range := unsafe { &Range(live_range) }
		if range.start_container_ == parent && range.start_offset_ > index {
			range.start_offset_--
		}
	}
	// 7. For each live range whose end node is parent and end offset is greater than index, decrease its end offset by 1.
	for _, live_range in dom_live_ranges {
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
	if n.document() != unsafe { nil } {
		n.document().notify_editing_history_dom_mutation()
	}
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
	descendant_slots := unregister_slot_descendants_from_shadow_root(&n, parent_root)
	if descendant_slots.len > 0 {
		assign_slottables_for_a_tree(parent_root)
		for slot in descendant_slots {
			assign_slottables(slot)
		}
	}
	n.removed_from_with_context(.yes, parent, parent_root)
	n.visit_shadow_including_descendants(fn [parent, parent_root] (descendant &Node) TraversalDecision {
		mut mutable_descendant := unsafe { &Node(descendant) }
		mutable_descendant.removed_from_with_context(.no, parent, parent_root)
		return .@continue
	})
	// For each inclusive ancestor of parent, copy subtree observers into transient observers on the removed node.
	for ancestor := ?&Node(parent); ancestor != none;  {
		inclusive_ancestor := ancestor or { break }
		for registered in inclusive_ancestor.registered_observers() {
			if registered.options().subtree {
				transient_observer := TransientRegisteredObserver.create(registered.observer(), registered.options(), registered)
				n.add_registered_observer(unsafe { &RegisteredObserver(transient_observer) })
				mut observer := unsafe { &MutationObserver(registered.observer()) }
				observer.add_transient_registered_node(&n)
			}
		}
		ancestor = inclusive_ancestor.parent()
	}
	if !suppress_observers {
		mut removed := []&Node{}
		removed << &n
		mutable_parent.queue_tree_mutation_record([]&Node{}, removed, old_previous_sibling, old_next_sibling)
	}
	mutable_parent.children_changed(ChildrenChangedMetadata{
		type_: .removal
		node: n
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
	if reference_child == none || (reference_child or { unsafe { nil } }.parent_ == n && child.parent() == none) {
		n.insert_before(node, reference_child, true)
	}
	n.queue_tree_mutation_record(nodes, removed_nodes, previous_sibling, reference_child or {
		unsafe { nil }
	})
	return child
}

// https://dom.spec.whatwg.org/#concept-node-clone
pub fn (n &Node) clone_node(document ?&Document, subtree bool, parent ?&Node) !&Node {
	return n.clone_node_with_registry(document, subtree, parent, unsafe { nil })
}

pub fn (n &Node) clone_node_with_registry(document ?&Document, subtree bool, parent ?&Node, fallback_registry voidptr) !&Node {
	// To clone a node given a node node and an optional document document (default node's node document),
	// boolean subtree (default false), and node-or-null parent (default null):
	doc := document or { n.document() }
	working_copy := n.clone_single_node_with_registry(doc, fallback_registry)!
	n.cloned(working_copy, subtree)!
	if parent_node := parent {
		mut mutable_parent := unsafe { &Node(parent_node) }
		mutable_parent.append_child(working_copy)!
	}
	if subtree {
		for child in n.children {
			child.clone_node_with_registry(doc, subtree, working_copy, fallback_registry)!
		}
	}
	if element := n.as_element() {
		if shadow_root := element.shadow_root() {
			if shadow_root.clonable() {
				mut copy_element := working_copy.as_element() or {
					return error('InvalidStateError: Element clone did not produce an element')
				}
				mut shadow_root_registry := shadow_root.custom_element_registry()
				if is_a_global_custom_element_registry(shadow_root_registry) {
					shadow_root_registry = doc.effective_global_custom_element_registry()
				}
				copy_element.attach_a_shadow_root_with_registry(shadow_root.mode_(), true, shadow_root.serializable(), shadow_root.delegates_focus(), shadow_root.slot_assignment(), shadow_root_registry)!
				mut copy_shadow_root := copy_element.shadow_root() or {
					return error('InvalidStateError: Cloned shadow root was not attached')
				}
				copy_shadow_root.set_declarative(shadow_root.declarative)
				copy_shadow_root.set_keep_custom_element_registry_null(shadow_root.keep_custom_element_registry_null())
				copy_shadow_root_node := unsafe { &Node(copy_shadow_root) }
				for child in shadow_root_as_node(shadow_root).children {
					child.clone_node_with_registry(doc, subtree, copy_shadow_root_node, unsafe { nil })!
				}
			}
		}
	}
	return working_copy
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
		if node_has_child_element(&new_parent) || node_child_is_document_type(child) || node_has_following_doctype(child) {
			return error('HierarchyRequestError: Invalid node type for insertion')
		}
	}
	old_parent := n.parent() or { return }
	is_same_parent_move := old_parent == new_parent
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
	if old_parent.is_connected() {
		// Since the tree structure is about to change, we need to invalidate both style and layout.
		if is_same_parent_move {
			invalidate_style_after_same_parent_move(unsafe { &Node(n) }, .node_remove)
		} else {
			n.invalidate_style(.node_remove)
		}
		if n.unsafe_layout_node() != none {
			mut mutable_old_parent_for_layout := unsafe { &Node(old_parent) }
			mutable_old_parent_for_layout.set_needs_layout_tree_update(true, .node_remove)
		}
	}
	mut mutable_old_parent := unsafe { &Node(old_parent) }
	mutable_old_parent.remove_child_impl(n)
	if assigned_slot := assigned_slot_for_node(&n) {
		assign_slottables(assigned_slot)
	}
	old_parent_root := old_parent.root()
	signal_slot_change_if_empty_slot(old_parent, old_parent_root)
	descendant_slots := unregister_slot_descendants_from_shadow_root(&n, old_parent_root)
	if descendant_slots.len > 0 {
		assign_slottables_for_a_tree(old_parent_root)
		for slot in descendant_slots {
			assign_slottables(slot)
		}
	}
	if child_node := child {
		for _, live_range in dom_live_ranges {
			mut range := unsafe { &Range(live_range) }
			if range.start_container_ == &new_parent && range.start_offset_ > child_node.index() {
				range.start_offset_++
			}
			if range.end_container_ == &new_parent && range.end_offset_ > child_node.index() {
				range.end_offset_++
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
	if is_same_parent_move {
		invalidate_style_after_same_parent_move(unsafe { &Node(n) }, .node_insert_before)
	} else {
		n.invalidate_style(.node_insert_before)
	}
	if n.is_connected() {
		new_parent.set_needs_layout_tree_update(true, .node_insert_before)
	}
	moved_node := &n
	n.visit_shadow_including_inclusive_descendants(fn [old_parent, moved_node] (inclusive_descendant &Node) TraversalDecision {
		mut mutable_descendant := unsafe { &Node(inclusive_descendant) }
		if inclusive_descendant == moved_node {
			mutable_descendant.moved_from_with_context(.yes, old_parent)
		} else {
			mutable_descendant.moved_from_with_context(.no, old_parent)
		}
		return .@continue
	})
	mut removed_from_old_parent := []&Node{}
	removed_from_old_parent << &n
	mutable_old_parent.queue_tree_mutation_record([]&Node{}, removed_from_old_parent, old_previous_sibling, old_next_sibling)
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
	return n.clone_single_node_with_registry(document, unsafe { nil })
}

pub fn (n &Node) clone_single_node_with_registry(document &Document, fallback_registry voidptr) !&Node {
	// To clone a single node given a node node and document document:
	mut working_copy := unsafe { &Node(nil) }
	if element := n.as_element() {
		mut registry := element.custom_element_registry()
		if registry == unsafe { nil } {
			registry = fallback_registry
		}
		if is_a_global_custom_element_registry(registry) {
			registry = document.effective_global_custom_element_registry()
		}
		// 2. If node is an element, create an element with the same local name, namespace, prefix, is value, and registry.
		mut element_copy := create_element_with_registry(document, element.local_name(), element.namespace_uri(), element.prefix(), element.custom_element_is_value(), false, registry)!
		if attrs := element.attributes_ {
			for attr in attrs.attrs {
				element_copy.append_attribute(&Attr_{
					name_: attr.name_
					value_: attr.value_
					local_name_: attr.local_name_
					prefix__: attr.prefix__
					namespace_uri_: attr.namespace_uri_
				})
			}
		}
		working_copy = element_copy.as_node()
	} else if n.is_document() {
		source_document := unsafe { &Document(n) }
		mut document_copy := Document.create(source_document.url)
		document_copy.set_encoding(source_document.get_encoding())
		document_copy.set_content_type(source_document.get_content_type())
		document_copy.set_url(source_document.url)
		document_copy.set_origin(source_document.origin())
		document_copy.set_document_type(source_document.document_type())
		document_copy.set_quirks_mode(source_document.mode())
		document_copy.set_allow_declarative_shadow_roots(source_document.allow_declarative_shadow_roots())
		if custom_element_registry_is_scoped(source_document.custom_element_registry()) {
			document_copy.set_custom_element_registry(source_document.custom_element_registry())
		}
		working_copy = unsafe { &Node(document_copy) }
	} else if document_type := n.as_document_type() {
		mut document_type_copy := DocumentType.new(document)
		document_type_copy.set_name(document_type.name())
		document_type_copy.set_public_id(document_type.public_id())
		document_type_copy.set_system_id(document_type.system_id())
		working_copy = document_type_copy.as_node()
	} else if attr := n.as_attr() {
		working_copy = attr.clone(document).as_node()
	} else if n.is_text() {
		data := n.character_data() or {
			return error('InvalidStateError: Text node missing character data')
		}
		if n.is_cdata_section() {
			working_copy = CDATASection.new(document, data.data_).as_node()
		} else {
			working_copy = Text.new(document, data.data_).as_node()
		}
	} else if n.is_comment() {
		data := n.character_data() or {
			return error('InvalidStateError: Comment node missing character data')
		}
		working_copy = Comment.new(document, data.data_).as_node()
	} else if processing_instruction := n.as_processing_instruction() {
		working_copy = ProcessingInstruction.new(document, processing_instruction.data(), processing_instruction.target()).as_node()
	} else if n.is_document_fragment() {
		working_copy = DocumentFragment.new(document).as_node()
	} else {
		return error('NotSupportedError: Missing code for cloning this node type')
	}
	mut document_to_use := unsafe { &Document(document) }
	if n.is_document() {
		document_to_use = unsafe { &Document(working_copy) }
	}
	mut mutable_copy := unsafe { &Node(working_copy) }
	mutable_copy.set_document(document_to_use)
	return working_copy
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
	node_needs_style_update := n.needs_style_update()
	subtree_needs_style_update := n.entire_subtree_needs_style_update()
	descendants_need_style_update := n.child_needs_style_update()
	n.document_ = document
	if element := n.as_element() {
		mut mutable_element := unsafe { &Element(element) }
		mutable_element.doc_ = document
	}
	if node_needs_style_update {
		// NOTE: We unset and reset the "needs style update" flag here.
		// This ensures that there's a pending style update in the new document
		// that will eventually assign some style to this node if needed.
		n.set_needs_style_update(false)
		n.set_needs_style_update(true)
	}
	if subtree_needs_style_update || descendants_need_style_update {
		for ancestor := n.parent_or_shadow_host(); ancestor != none;  {
			mut current := unsafe { &Node(ancestor or { break }) }
			if current.child_needs_style_update_ {
				break
			}
			current.child_needs_style_update_ = true
			ancestor = current.parent_or_shadow_host()
		}
	}
}

pub fn (mut n Node) recompute_editable_subtree_flag() bool {
	mut new_value := false
	if n.is_document() {
		doc := n.document()
		new_value = doc != unsafe { nil } && doc.design_mode_enabled_state()
	} else if element := n.as_element() {
		if element.is_html_element() {
			state := html_content_editable_state(element)
			if state == 'true' || state == 'plaintext-only' {
				new_value = true
			} else if state == 'false' {
				new_value = false
			} else if parent := n.parent() {
				new_value = parent.in_editable_subtree_
			}
		} else if parent := n.parent() {
			new_value = parent.in_editable_subtree_
		}
	} else if parent := n.parent() {
		new_value = parent.in_editable_subtree_
	}
	changed := n.in_editable_subtree_ != new_value
	n.in_editable_subtree_ = new_value
	return changed
}

pub fn (mut n Node) recompute_editable_subtree_flags_and_repaint() {
	n.for_each_in_inclusive_subtree(fn (node &Node) TraversalDecision {
		mut mutable_node := unsafe { &Node(node) }
		if mutable_node.recompute_editable_subtree_flag() {
			mutable_node.set_needs_repaint(.paint_commands_and_hit_test_list)
		}
		if mut layout_node := node.unsafe_layout_node() {
			editable := node.is_editable_or_editing_host()
			if layout_node.is_editable_or_editing_host_ != editable {
				layout_node.is_editable_or_editing_host_ = editable
				mutable_node.set_needs_repaint(.paint_commands_and_hit_test_list)
			}
			is_editing_host := node.is_editing_host()
			if layout_node.is_editing_host_ != is_editing_host {
				layout_node.is_editing_host_ = is_editing_host
				mutable_node.set_needs_layout_update(.editable_state_change)
			}
			if layout_node.bridge_callbacks().refresh_empty_text_fragment_callback != unsafe { nil }
				&& layout_node.bridge_callbacks().refresh_empty_text_fragment_callback(layout_node.layout_handle) {
				mutable_node.set_needs_layout_update(.editable_state_change)
			}
		}
		return .@continue
	})
}

// https://w3c.github.io/editing/docs/execCommand/#editable
pub fn (n &Node) is_editable() bool {
	// Something is editable if it is a node; it is not an editing host;
	if n.is_editing_host() {
		return false
	}
	// it does not have a contenteditable attribute set to the false state;
	if element := n.as_element() {
		if element.is_html_element() && html_content_editable_state(element) == 'false' {
			return false
		}
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
	if element := n.as_element() {
		return element.is_html_element() || element.is_svg_element() || element.namespace_uri() or {
			''
		} == 'http://www.w3.org/1998/Math/MathML'
	}
	parent := n.parent() or { return false }
	parent_element := parent.as_element() or { return false }
	return parent_element.is_html_element()
}

// https://html.spec.whatwg.org/multipage/interaction.html#editing-host
pub fn (n &Node) is_editing_host() bool {
	element := n.as_element() or { return false }
	if !element.is_html_element() {
		return false
	}
	state := html_content_editable_state(element)
	if (state == 'true' || state == 'plaintext-only') && (n.parent() == none || !(n.parent() or {
		unsafe { nil }
	}).in_editable_subtree_) {
		return true
	}
	if parent := n.parent() {
		if parent.is_document() {
			doc := parent.document()
			return doc != unsafe { nil } && doc.design_mode_enabled_state()
		}
	}
	return false
}

fn html_content_editable_state(element &Element) string {
	return element.content_editable_state_
}

fn parse_content_editable_state(attribute_value ?string) string {
	value := attribute_value or { return 'inherit' }
	normalized := to_ascii_lowercase(value)
	if normalized == '' || normalized == 'true' {
		return 'true'
	}
	if normalized == 'plaintext-only' {
		return 'plaintext-only'
	}
	if normalized == 'false' {
		return 'false'
	}
	return 'inherit'
}

pub fn (n &Node) editing_host_is_plaintext_only() bool {
	host := n.editing_host() or { return false }
	element := host.as_element() or { return false }
	return element.is_html_element() && html_content_editable_state(element) == 'plaintext-only'
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
		for ancestor := n.parent(); ancestor != none;  {
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
	mut mutable_layout := unsafe { &LayoutNode(layout_node) }
	mutable_layout.is_editing_host_ = n.is_editing_host()
	mutable_layout.is_editable_or_editing_host_ = n.is_editable_or_editing_host()
	if element := n.as_element() {
		unsafe {
			mut styled_node := layout_style_wrapper_for_attachment(element, layout_node)
			styled_node.applied_properties_ = element.el_computed_properties()
			element.layout_node_with_style_ = styled_node
		}
	}
}

pub fn (mut n Node) detach_layout_node() {
	if n.layout_node_ != unsafe { nil } {
		if n.layout_node_.bridge_callbacks().clear_image_observers_callback != unsafe { nil } {
			n.layout_node_.bridge_callbacks().clear_image_observers_callback(n.layout_node_.layout_handle)
		}
	}
	n.layout_node_ = unsafe { nil }
	if element := n.as_element() {
		unsafe {
			element.layout_node_with_style_ = none
		}
	}
}

pub fn (mut n Node) clear_layout_node_and_paintable() {
	n.detach_layout_node()
	n.paintable_ = unsafe { nil }
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
	if value && reason in [.node_insert_before, .node_remove, .node_set_text_content] {
		if owner := n.first_letter_owner_for_layout_subtree_from(&n) {
			if owner.as_node() != &n {
				mut owner_node := unsafe { &Node(owner.as_node()) }
				owner_node.set_needs_layout_tree_update(true, reason)
			}
		}
	}
	if n.needs_layout_tree_update == value {
		return
	}
	n.needs_layout_tree_update = value
	// NOTE: If this is a shadow root, we need to propagate the layout tree update to the host.
	if shadow_root := n.as_shadow_root() {
		if host := shadow_root.host() {
			mut host_node := unsafe { &Node(host.as_node()) }
			host_node.set_needs_layout_tree_update(value, reason)
		}
	}
	if n.needs_layout_tree_update {
		mut document := unsafe { &Document(n.document()) }
		document.mark_needs_repaint(.no)
		for ancestor := n.flat_tree_parent(); ancestor != none;  {
			mut current := unsafe { &Node(ancestor or { break }) }
			if current.child_needs_layout_tree_update {
				break
			}
			current.child_needs_layout_tree_update = true
			ancestor = current.flat_tree_parent()
		}
		// If this is an element with display: contents, we need to propagate the layout tree update to the parent.
		if element := n.as_element() {
			if properties := element.el_computed_properties() {
				if properties.display().is_contents() {
					if parent_element := n.parent_or_shadow_host_element() {
						mut parent_node := unsafe { &Node(parent_element.as_node()) }
						parent_node.set_needs_layout_tree_update(true, reason)
					}
				}
			}
		}
		if layout_node := n.unsafe_layout_node() {
			mut mutable_layout_node := unsafe { &LayoutNode(layout_node) }
			mutable_layout_node.set_needs_layout_update(.layout_tree_update)
			// If the layout node has an anonymous parent, rebuild from the nearest non-anonymous ancestor.
			// FIXME: This is not optimal, and we should figure out how to rebuild a smaller part of the tree.
			if layout_parent := layout_node.parent() {
				if layout_parent.is_anonymous() {
					mut ancestor := ?&LayoutNode(layout_parent)
					for ancestor != none {
						current := ancestor or { break }
						if !current.is_anonymous() {
							break
						}
						ancestor = current.parent()
					}
					if nearest := ancestor {
						if dom_node := nearest.dom_node() {
							mut mutable_dom_node := unsafe { &Node(dom_node) }
							mutable_dom_node.set_needs_layout_tree_update(true, reason)
						}
					}
				}
			}
		}
	}
}

// DOM/Node.cpp: a generated first-letter owned by an ancestor may live inside
// this node's layout subtree even when its DOM style owner lies outside it.
pub fn (n &Node) first_letter_owner_for_layout_subtree_from(inclusive_ancestor &Node) ?&Element {
	layout_root := n.unsafe_layout_node() or { return none }
	mut ancestor := ?&Node(inclusive_ancestor)
	for ancestor != none {
		current := ancestor or { break }
		if element := current.as_element() {
			if element.computed_properties_for_pseudo(int(PseudoElement.first_letter)) != none {
				if pseudo := element.get_pseudo_element_node(int(PseudoElement.first_letter)) {
					mut layout_ancestor := ?&LayoutNode(pseudo.layout_node_)
					for layout_ancestor != none {
						layout_current := layout_ancestor or { break }
						if voidptr(layout_current) == voidptr(layout_root) { return element }
						layout_ancestor = layout_current.parent()
					}
				} else {
					return element
				}
			}
		}
		ancestor = current.parent_or_shadow_host()
	}
	return none
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
		doc := n.document()
		if doc != unsafe { nil } {
			mut mutable_document := unsafe { &Document(doc) }
			mutable_document.record_style_invalidation()
			mutable_document.mark_needs_repaint(.no)
		}
		for ancestor := n.parent_or_shadow_host(); ancestor != none;  {
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
	n.needs_style_update_ = value
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

pub fn (n &Node) has_child_affected_by_backward_structural_changes() bool {
	return n.has_child_affected_by_backward_structural_changes_
}

pub fn (mut n Node) set_has_child_affected_by_backward_structural_changes(value bool) {
	n.has_child_affected_by_backward_structural_changes_ = value
}

pub fn (mut n Node) post_connection() {}

pub fn (mut n Node) inserted() {
	// Insertion visits shadow-including inclusive descendants in tree order, so
	// the parent (or shadow host) already has its cached connection state.
	if shadow_root := n.as_shadow_root() {
		n.is_connected_ = if host := shadow_root.host() {
			host.as_node().is_connected()
		} else {
			false
		}
	} else if parent := n.parent() {
		n.is_connected_ = parent.is_connected()
	}
	if element := n.as_element() {
		if n.is_html_base_element() {
			mut base := unsafe { &HTMLBaseElement(element) }
			base.inserted()
			return
		}
		if n.is_html_meta_element() {
			mut meta := unsafe { &HTMLMetaElement(element) }
			meta.inserted()
			return
		}
		mut mutable_element := unsafe { &Element(element) }
		mutable_element.inserted()
		return
	}
	if shadow_root := n.as_shadow_root() {
		registry := shadow_root.custom_element_registry()
		if n.is_connected() && custom_element_registry_is_scoped(registry) {
			custom_element_registry_append_document(registry, n.document())
		}
	}
	n.recompute_editable_subtree_flag()
	n.set_needs_style_update(true)
}

pub fn (mut n Node) removed_from(old_parent ?&Node, old_root &Node) {
	n.removed_from_with_context(.yes, old_parent, old_root)
}

pub fn (mut n Node) removed_from_with_context(is_subtree_root NodeIsSubtreeRoot, old_ancestor ?&Node, old_root &Node) {
	n.is_connected_ = false
	if element := n.as_element() {
		if n.is_html_base_element() {
			mut base := unsafe { &HTMLBaseElement(element) }
			base.removed_from_with_context(is_subtree_root, old_ancestor, old_root)
			return
		}
		if n.is_html_meta_element() {
			mut meta := unsafe { &HTMLMetaElement(element) }
			meta.removed_from_with_context(is_subtree_root, old_ancestor, old_root)
			return
		}
		mut mutable_element := unsafe { &Element(element) }
		mutable_element.removed_from_with_context(is_subtree_root, old_ancestor, old_root)
		return
	}
	n.in_editable_subtree_ = false
	n.layout_node_ = unsafe { nil }
	n.paintable_ = unsafe { nil }
	n.run_removed_from_lifecycle_hook(is_subtree_root, old_ancestor, old_root)
}

// https://dom.spec.whatwg.org/#concept-node-move-ext
pub fn (mut n Node) moved_from(old_parent ?&Node) {
	n.moved_from_with_context(.yes, old_parent)
}

pub fn (mut n Node) moved_from_with_context(is_subtree_root NodeIsSubtreeRoot, old_ancestor ?&Node) {
	if element := n.as_element() {
		mut mutable_element := unsafe { &Element(element) }
		mutable_element.moved_from_with_context(is_subtree_root, old_ancestor)
		return
	}
	n.recompute_editable_subtree_flag()
	n.run_moved_from_lifecycle_hook(is_subtree_root, old_ancestor)
}

pub fn (mut n Node) adopted_from(old_document &Document) {
	n.recompute_editable_subtree_flag()
	if shadow_root := n.as_shadow_root() {
		mut mutable_shadow_root := unsafe { &ShadowRoot(shadow_root) }
		mutable_shadow_root.adopted_from(old_document)
	} else if element := n.as_element() {
		mut mutable_element := unsafe { &Element(element) }
		mutable_element.adopted_from(old_document)
	}
	if n.hooks_ != unsafe { nil } {
		if hook := n.hooks_.adopted_from {
			if hook.callback != unsafe { nil } {
				hook.callback(hook.target, old_document)
			}
		}
	}
}

pub fn (mut n Node) set_adopted_from_hook(hook ?NodeAdoptedFromHook) {
	if hook == none && n.hooks_ == unsafe { nil } { return }
	mut hooks := n.ensure_hooks()
	hooks.adopted_from = hook
}

pub fn (mut n Node) set_lifecycle_hook(hook ?NodeLifecycleHook) {
	if hook == none && n.hooks_ == unsafe { nil } { return }
	mut hooks := n.ensure_hooks()
	hooks.lifecycle = hook
}

fn (n &Node) run_removed_from_lifecycle_hook(is_subtree_root NodeIsSubtreeRoot, old_ancestor ?&Node, old_root &Node) {
	if n.hooks_ == unsafe { nil } { return }
	hook := n.hooks_.lifecycle or { return }
	if hook.removed_from != unsafe { nil } {
		hook.removed_from(hook.target, is_subtree_root, old_ancestor, old_root)
	}
}

fn (n &Node) run_moved_from_lifecycle_hook(is_subtree_root NodeIsSubtreeRoot, old_ancestor ?&Node) {
	if n.hooks_ == unsafe { nil } { return }
	hook := n.hooks_.lifecycle or { return }
	if hook.moved_from != unsafe { nil } {
		hook.moved_from(hook.target, is_subtree_root, old_ancestor)
	}
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
	if n.is_slottable() {
		if slot := n.assigned_slot_internal() {
			return html_slot_element_as_node(slot)
		}
	}
	// Otherwise, this is the parent or shadow host.
	return n.parent_or_shadow_host()
}

pub fn (n &Node) flat_tree_parent_element() ?&Element {
	for parent := n.flat_tree_parent(); parent != none;  {
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
			node_root: n
			is_live: true
			live_scope: .children
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
	mut node1 := unsafe { &Node(other_node) }
	mut node2 := unsafe { &Node(n) }
	mut has_attr1 := false
	mut has_attr2 := false
	if attr := node1.as_attr() {
		has_attr1 = true
		owner := attr.owner_element() or {
			return document_position_disconnected | document_position_implementation_specific | document_position_following
		}
		node1 = unsafe { &Node(owner.as_node()) }
	}
	if attr := node2.as_attr() {
		has_attr2 = true
		owner := attr.owner_element() or {
			return document_position_disconnected | document_position_implementation_specific | document_position_following
		}
		node2 = unsafe { &Node(owner.as_node()) }
	}
	if node1.root() != node2.root() {
		return document_position_disconnected | document_position_implementation_specific | document_position_following
	}
	mut node1_ancestors := []&Node{}
	for current := ?&Node(node1); current != none;  {
		node := current or { break }
		node1_ancestors << node
		current = node.parent()
	}
	mut node2_ancestors := []&Node{}
	for current := ?&Node(node2); current != none;  {
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
			for sibling := ?&Node(ancestor1); sibling != none;  {
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
	if (node1_ancestors.len < node2_ancestors.len && !has_attr1) || (node1 == node2 && has_attr2) {
		return document_position_contains | document_position_preceding
	}
	if (node1_ancestors.len > node2_ancestors.len && !has_attr2) || (node1 == node2 && has_attr1) {
		return document_position_contained_by | document_position_following
	}
	if node1_ancestors.len < node2_ancestors.len {
		return document_position_preceding
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
	layout_node := n.layout_node() or { return true }
	if parent := layout_node.parent() {
		if parent.is_anonymous() {
			return true
		}
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
	object.write_string('{"name":${json_quote(n.node_name())},"id":${n.unique_id().value()}')
	if n.is_document() {
		object.write_string(',"type":"document"')
	} else if n.is_element() {
		object.write_string(',"type":"element"')
		if element := n.as_element() {
			if namespace := element.namespace_uri() {
				object.write_string(',"namespace":${json_quote(namespace)}')
			}
			if attrs := element.attributes_ {
				if attrs.attrs.len > 0 {
					object.write_string(',"attributes":{')
					for i, attr in attrs.attrs {
						if i > 0 {
							object.write_string(',')
						}
						object.write_string('${json_quote(attr.name_)}:${json_quote(attr.value_)}')
					}
					object.write_string('}')
				}
			}
		}
		if paintable_box := n.paintable_box() {
			if paintable_box.could_be_scrolled_by_wheel_event() {
				object.write_string(',"scrollable":true')
			}
			if !paintable_box.is_visible() {
				object.write_string(',"invisible":true')
			}
			if paintable_box.has_stacking_context() {
				object.write_string(',"stackingContext":true')
			}
		}
	} else if n.is_text() {
		object.write_string(',"type":"text"')
		if text := n.text_content() {
			object.write_string(',"text":${json_quote(text)}')
		}
	} else if n.is_comment() {
		object.write_string(',"type":"comment"')
		if data := n.node_value() {
			object.write_string(',"data":${json_quote(data)}')
		}
	} else if n.is_shadow_root() {
		object.write_string(',"type":"shadow-root"')
		if shadow_root := n.as_shadow_root() {
			mode := if shadow_root.mode == .open { 'open' } else { 'closed' }
			object.write_string(',"mode":${json_quote(mode)}')
		}
	}
	object.write_string(',"visible":${n.layout_node() != none}')
	if element := n.as_element() {
		element.serialize_children_as_json(mut object)
	} else if n.children.len > 0 {
		object.write_string(',"children":[')
		mut wrote_child := false
		for child in n.children {
			if child.is_uninteresting_whitespace_node() {
				continue
			}
			if wrote_child {
				object.write_string(',')
			}
			child.serialize_tree_as_json(mut object)
			wrote_child = true
		}
		object.write_string(']')
	}
	object.write_string('}')
}

fn json_quote(value string) string {
	mut builder := strings.new_builder(value.len + 2)
	builder.write_string('"')
	for r in value.runes() {
		match r {
			`"` {
				builder.write_string('\\"')
			}
			`\\` {
				builder.write_string('\\\\')
			}
			`\b` {
				builder.write_string('\\b')
			}
			`\f` {
				builder.write_string('\\f')
			}
			`\n` {
				builder.write_string('\\n')
			}
			`\r` {
				builder.write_string('\\r')
			}
			`\t` {
				builder.write_string('\\t')
			}
			else {
				if u32(r) < 0x20 {
					builder.write_string('\\u${u32(r):04x}')
				} else {
					builder.write_rune(r)
				}
			}
		}
	}
	builder.write_string('"')
	return builder.str()
}

// https://html.spec.whatwg.org/multipage/webappapis.html#concept-n-script
pub fn (n &Node) is_scripting_enabled() bool {
	return !n.is_scripting_disabled()
}

// https://html.spec.whatwg.org/multipage/webappapis.html#concept-n-noscript
pub fn (n &Node) is_scripting_disabled() bool {
	document := n.document()
	return document == unsafe { nil } || document.browsing_context == unsafe { nil }
		|| !document.is_scripting_enabled_by_embedder()
		|| !n.relevant_settings_scripting_enabled()
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
	return n.is_same_node(other) || n.is_shadow_including_descendant_of(other)
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
	// 1. Let context document be the value of node's node document.
	context_document := n.document()

	// 2. If context document is an HTML document, return the result of HTML fragment serialization algorithm with node, false, and << >>.
	if context_document != unsafe { nil } && context_document.is_html_document() {
		return html_parser_serialize_html_fragment(n, .no, []&ShadowRoot{}, fragment_serialization_mode)
	}

	// 3. Return the XML serialization of node given require well-formed.
	// AD-HOC: XML serialization algorithm returns the "outer" XML serialization of the node.
	//         For inner, concatenate the serialization of all children.
	if fragment_serialization_mode == .inner {
		mut builder := strings.new_builder(0)
		for child in n.children {
			child_markup := html_serialize_node_to_xml_string(child, require_well_formed)!
			builder.write_string(child_markup)
		}
		return builder.str()
	}
	return html_serialize_node_to_xml_string(n, require_well_formed)
}

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#unsafely-set-html
pub fn (mut n Node) unsafely_set_html(context_element &Element, html string) ! {
	// 1. Let newChildren be the result of the HTML fragment parsing algorithm given contextElement, html, and true.
	new_children := html_parser_parse_html_fragment(context_element, html, .yes, .inert)!

	// 2. Let fragment be a new DocumentFragment whose node document is contextElement's node document.
	fragment := new_document_fragment(context_element.document())

	// 3. For each node in newChildren, append node to fragment.
	mut fragment_node := unsafe { &Node(fragment.as_node()) }
	for child in new_children {
		fragment_node.append_child(child)!
	}

	// 4. Replace all within contextElement (or within a template element's template contents).
	mut target := unsafe { &n }
	if context_element.is_html_element() && context_element.local_name() == 'template' {
		template_element := unsafe { &HTMLTemplateElement(context_element) }
		target = template_element.content().as_node()
	}
	target.replace_all(fragment.as_node())
}

// https://dom.spec.whatwg.org/#dom-node-issamenode
pub fn (n &Node) is_same_node(other_node ?&Node) bool {
	// The isSameNode(otherNode) method steps are to return true if otherNode is this; otherwise false.
	// The compatibility compiler's value-based equality operator copies heap
	// Node records. Identity/ancestry walks need only these pointer addresses.
	return if other := other_node { voidptr(n) == voidptr(other) } else { false }
}

// https://dom.spec.whatwg.org/#dom-node-isequalnode
pub fn (n &Node) is_equal_node(other_node ?&Node) bool {
	// The isEqualNode(otherNode) method steps are to return true if otherNode is non-null and this equals otherNode; otherwise false.
	other := other_node or { return false }
	if voidptr(n) == voidptr(other) {
		return true
	}
	if n.node_type != other.node_type {
		return false
	}
	if to_ascii_lowercase(n.node_name()) != to_ascii_lowercase(other.node_name()) {
		return false
	}

	// The following are equal, switching on the interface A implements:
	if document_type := n.as_document_type() {
		other_document_type := other.as_document_type() or { return false }
		if document_type.name() != other_document_type.name() || document_type.public_id() != other_document_type.public_id() || document_type.system_id() != other_document_type.system_id() {
			return false
		}
	} else if element := n.as_element() {
		other_element := other.as_element() or { return false }
		if !option_string_equal(element.namespace_uri(), other_element.namespace_uri()) || !option_string_equal(element.prefix(), other_element.prefix()) || element.local_name() != other_element.local_name() || element.attribute_list_size() != other_element.attribute_list_size() {
			return false
		}
		if attrs := element.attributes_ {
			for attribute in attrs.attrs {
				other_attribute := other_element.get_attribute_node_ns(attribute.namespace_uri_, attribute.local_name_) or { return false }
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
		if !option_string_equal(attr.namespace_uri(), other_attr.namespace_uri()) || attr.local_name() != other_attr.local_name() || attr.value() != other_attr.value() {
			return false
		}
	} else if processing_instruction := n.as_processing_instruction() {
		other_processing_instruction := other.as_processing_instruction() or { return false }
		if processing_instruction.target() != other_processing_instruction.target() || processing_instruction.data() != other_processing_instruction.data() {
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
	// To locate a namespace for a node using prefix, switch on the interface node implements:
	if element := n.as_element() {
		// 1. If prefix is "xml", then return the XML namespace.
		// 2. If prefix is "xmlns", then return the XMLNS namespace.
		if p := prefix {
			if p == 'xml' {
				return namespace_xml_uri
			}
			if p == 'xmlns' {
				return namespace_xmlns_uri
			}
		}
		if ns := element.namespace_uri() {
			if option_string_equal(element.prefix(), prefix) {
				return ns
			}
		}
		if attrs := element.attributes_ {
			for attr in attrs.attrs {
				if attr.namespace_uri_ or { '' } == namespace_xmlns_uri {
					if (attr.prefix__ or { '' }) == 'xmlns' && prefix != none && attr.local_name_ == prefix or {
						''
					} {
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
	if n.is_document_type() || n.is_document_fragment() {
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
	return option_string_equal(default_namespace, actual_namespace)
}

pub fn (n &Node) is_inert() bool {
	if element := n.as_element() {
		if element.has_attribute('inert') || (element.is_html_element() && unsafe { &HTMLElement(element) }.inert()) {
			return true
		}
	}
	if enclosing := n.enclosing_html_element() {
		return enclosing.inert() || enclosing.has_attribute('inert')
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
	builder.write_string(to_ascii_lowercase(n.node_name()))
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
		for mut paintable in layout_node.paintables() {
			paintable.set_needs_repaint(should_invalidate_display_list)
		}
	}
}

// ImageProvider::image_provider_contents_changed(). Returns whether the
// provider's new contents reached every paintable without a layout pass.
pub fn (mut n Node) image_provider_contents_changed() bool {
	layout_node := n.unsafe_layout_node() or { return false }
	mut paintables := layout_node.paintables()
	if paintables.len == 0 {
		return false
	}
	mut pushed := true
	for mut paintable in paintables {
		if !paintable.image_provider_contents_changed() {
			pushed = false
		}
	}
	return pushed
}

pub fn (mut n Node) set_needs_layout_update(reason SetNeedsLayoutReason) {
	if mut node := n.unsafe_layout_node() {
		node.set_needs_layout_update(reason)
		mut document := unsafe { &Document(n.document()) }
		document.mark_needs_repaint(.no)
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
	mut document := unsafe { &Document(target.document()) }

	// 1. Let interestedObservers be an empty map.
	// mutationObserver -> mappedOldValue
	mut interested_observers := []&MutationObserver{}
	mut mapped_old_values := []?string{}

	// 2. Let nodes be the inclusive ancestors of target.
	// 3. For each node of nodes, and then for each registered of node's registered observer list:
	mut current := ?&Node(target)
	for current != none {
		node := current or { break }
		for registered_observer in node.registered_observers() {
			// 1. Let options be registered's options.
			options := registered_observer.options()

			// 2. If none of the following are true
			//      - node is not target and options["subtree"] is false
			//      - type is "attributes" and options["attributes"] either does not exist or is false
			//      - type is "attributes", options["attributeFilter"] exists, and options["attributeFilter"] does not contain name or namespace is non-null
			//      - type is "characterData" and options["characterData"] either does not exist or is false
			//      - type is "childList" and options["childList"] is false
			//    then:
			if voidptr(node) != voidptr(target) && !options.subtree {
				continue
			}
			mut should_use_old_value := false
			match type_ {
				.attributes {
					if !(options.attributes or { false }) {
						continue
					}
					if attribute_filter := options.attribute_filter {
						if attribute_namespace != none {
							continue
						}
						name := attribute_name or { '' }
						if name !in attribute_filter {
							continue
						}
					}
					if options.attribute_old_value or { false } {
						should_use_old_value = true
					}
				}
				.character_data {
					if !(options.character_data or { false }) {
						continue
					}
					if options.character_data_old_value or { false } {
						should_use_old_value = true
					}
				}
				.child_list {
					if !options.child_list {
						continue
					}
				}
			}

			// 1. Let mo be registered's observer.
			observer := registered_observer.observer()

			// 2. If interestedObservers[mo] does not exist, then set interestedObservers[mo] to null.
			mut observer_index := -1
			for i, interested_observer in interested_observers {
				if voidptr(interested_observer) == voidptr(observer) {
					observer_index = i
					break
				}
			}
			if observer_index == -1 {
				interested_observers << observer
				mapped_old_values << ?string(none)
				observer_index = interested_observers.len - 1
			}

			// 3. If either type is "attributes" and options["attributeOldValue"] is true, or type is
			//    "characterData" and options["characterDataOldValue"] is true, then set interestedObservers[mo] to oldValue.
			if should_use_old_value {
				mapped_old_values[observer_index] = old_value
			}
		}
		current = node.parent()
	}

	// OPTIMIZATION: If there are no interested observers, bail without doing any more work.
	if interested_observers.len == 0 {
		return
	}

	// Deferred records and observer queues must survive a transient native call.
	mut storage := target.document().native_storage()
	mut allocation_scope := platform.RetainedArenaScope{}
	if storage != unsafe { nil } { allocation_scope = storage.enter_nested() }
	persistent := platform.enter_persistent_if(storage == unsafe { nil } && platform.transient_arena_entered())
	defer { platform.leave_persistent(persistent); allocation_scope.finish() }

	// 4. For each observer -> mappedOldValue of interestedObservers:
	mut delivery_queues := []&MutationObserverDeliveryQueue{}
	for i, observer in interested_observers {
		// 1. Let record be a new MutationRecord object with its type set to type, target set to target, attributeName set to name, attributeNamespace set to namespace, oldValue set to mappedOldValue,
		//    addedNodes set to addedNodes, removedNodes set to removedNodes, previousSibling set to previousSibling, and nextSibling set to nextSibling.
		record := MutationRecord.create(mutation_type_to_string(type_), target, added_nodes, removed_nodes, previous_sibling, next_sibling, attribute_name, attribute_namespace, mapped_old_values[i])

		// 2. Enqueue record to observer's record queue.
		mut mutable_observer := unsafe { &MutationObserver(observer) }
		mutable_observer.enqueue_record(record)

		// 3. Append observer to the surrounding agent's pending mutation observers.
		if queue := observer.delivery_queue_ {
			mut owned_queue := unsafe { &MutationObserverDeliveryQueue(queue) }
			owned_queue.add_pending(observer)
			mut present := false
			for existing in delivery_queues { if voidptr(existing) == voidptr(queue) { present = true; break } }
			if !present { delivery_queues << queue }
		} else if document != unsafe { nil } {
			document.pending_mutation_observers << observer
		}
	}
	// Schedule only after every interested observer has its record. Native host
	// entry can service an existing JavaScript job queue while enqueueing a job.
	for mut queue in delivery_queues { queue.ensure_microtask() }

	// 5. Queue a mutation observer microtask.
	if document != unsafe { nil } {
		queue_mutation_observer_microtask(mut document)
	}
}

// https://dom.spec.whatwg.org/#queue-a-tree-mutation-record
pub fn (mut n Node) queue_tree_mutation_record(added_nodes []&Node, removed_nodes []&Node, previous_sibling &Node, next_sibling &Node) {
	// 1. Assert: either addedNodes or removedNodes is not empty.
	if added_nodes.len == 0 && removed_nodes.len == 0 {
		return
	}
	// 2. Queue a mutation record of "childList" for target with null, null, null, addedNodes, removedNodes, previousSibling, and nextSibling.
	n.queue_mutation_record(.child_list, none, none, none, added_nodes, removed_nodes, previous_sibling, next_sibling)
}

pub fn (mut n Node) append_child_impl(node &Node) {
	if !n.is_child_allowed(node) {
		return
	}
	mut mutable_node := unsafe { &Node(node) }
	mutable_node.parent_ = n
	mutable_node.index_in_parent_ = n.children.len
	n.children << node
}

pub fn (mut n Node) insert_before_impl(node &Node, child ?&Node) {
	child_node := child or {
		n.append_child_impl(node)
		return
	}

	index := child_node.index_in_parent_
	mut mutable_node := unsafe { &Node(node) }
	mutable_node.parent_ = n
	n.children.insert(index, node)
	for child_index := index; child_index < n.children.len; child_index++ {
		mut current := unsafe { &Node(n.children[child_index]) }
		current.index_in_parent_ = child_index
	}
}

pub fn (mut n Node) remove_child_impl(node &Node) {
	index := node.index_in_parent_
	if index < 0 || index >= n.children.len || n.children[index] != node {
		return
	}
	n.children.delete(index)
	mut mutable_node := unsafe { &Node(node) }
	mutable_node.parent_ = unsafe { nil }
	mutable_node.index_in_parent_ = -1
	for child_index := index; child_index < n.children.len; child_index++ {
		mut current := unsafe { &Node(n.children[child_index]) }
		current.index_in_parent_ = child_index
	}
}

pub fn (n &Node) is_child_allowed(node &Node) bool {
	if n.is_document() {
		return unsafe { &Document(n) }.is_child_allowed(node)
	}
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
	if element := n.as_element() {
		if element.is_html_element() && element.local_name() == 'template' {
			html_template_element_cloned(unsafe { &HTMLTemplateElement(element) }, copy, subtree)!
		}
	}
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
	_ = should_compute_role
	// The text alternative for a given element is computed as follows:
	// 1. Set the root node to the given element, the current node to the root node, and the total accumulated text to the
	//    empty string (""). If the root node's role prohibits naming, return the empty string ("").
	node_id := n.unique_id()
	visited_nodes[node_id] = true
	if element := n.as_element() {
		// A. Hidden Not Referenced:
		// AD-HOC: As in Ladybird C++, this is intentionally handled while visiting text nodes below
		// instead of returning early here, so referenced or visible descendants can still contribute.

		// B. Otherwise:
		// - if computing a name, and the current node has an aria-labelledby attribute that contains at least one valid
		//   IDREF, and the current node is not already part of an aria-labelledby traversal, process its IDREFs in the
		//   order they occur:
		// - or, if computing a description, and the current node has an aria-describedby attribute that contains at least
		//   one valid IDREF, and the current node is not already part of an aria-describedby traversal, process its IDREFs
		//   in the order they occur:
		reference_attribute := if target == .name { 'aria-labelledby' } else { 'aria-describedby' }
		if idrefs := element.get_attribute(reference_attribute) {
			if Node.first_valid_id(idrefs, document) != none {
				mut accumulated_text := strings.new_builder(0)
				for id_ref in idrefs.fields() {
					referenced_element := document.get_element_by_id(id_ref) or { continue }
					referenced_node := referenced_element.as_node()
					// AD-HOC: Required by WPT labelledby cases; a referenced node's own aria-label contributes.
					if target == .name {
						if aria_label := referenced_element.get_attribute('aria-label') {
							if aria_label.trim_space().len > 0 {
								accumulated_text.write_string(' ')
								accumulated_text.write_string(aria_label)
							}
						}
					}
					if visited_nodes[referenced_node.unique_id()] {
						continue
					}
					result := referenced_node.name_or_description(target, document, mut visited_nodes, .no, .yes)!
					accumulated_text.write_string(' ')
					accumulated_text.write_string(result)
				}
				if accumulated_text.str().trim_space().len == 0 && target == .name {
					if aria_label := element.get_attribute('aria-label') {
						if aria_label.trim_space().len > 0 {
							return aria_label
						}
					}
				}
				return accumulated_text.str()
			}
		}

		// D. AriaLabel: Otherwise, if the current node has an aria-label attribute whose value is not undefined, not
		//    the empty string, nor, when trimmed of whitespace, is not the empty string:
		if target == .name {
			if aria_label := element.get_attribute('aria-label') {
				if aria_label.trim_space().len > 0 && element.local_name() != 'slot' {
					return aria_label
				}
			}
		}

		// C. Embedded Control. The concrete HTML element and form-control
		// implementations live above DOM's module boundary; the installed HTML
		// hook executes the same labels/role/value dispatch as Node.cpp.
		if embedded_control_value := document.embedded_control_label_value(element) {
			return embedded_control_value
		}

		// E. Host Language Label: Otherwise, if the current node's native markup provides an attribute (e.g. alt) or
		//    element (e.g. HTML label or SVG title) that defines a text alternative, return that alternative in the form
		//    of a flat string as defined by the host language.
		if target == .name && element.local_name() == 'img' && element.has_attribute('alt') {
			return element.get_attribute('alt') or { '' }
		}
		if target == .name && element.is_svg_element() {
			for child in n.children {
				if child_element := child.as_element() {
					if child_element.local_name() == 'title' {
						return child.text_content() or { '' }
					}
				}
			}
			if title := element.get_attribute_ns(namespace_xlink_uri, 'title') {
				return title
			}
		}
		if target == .name && element.local_name() == 'table' {
			for child in n.children {
				if child_element := child.as_element() {
					if child_element.local_name() == 'caption' {
						return child.text_content() or { '' }
					}
				}
			}
		}
		if target == .name && element.local_name() == 'fieldset' {
			for child in n.children {
				if child_element := child.as_element() {
					if child_element.local_name() == 'legend' {
						return child.text_content() or { '' }
					}
				}
			}
		}
		if target == .name && element.local_name() == 'input' {
			input_type := to_ascii_lowercase(element.get_attribute('type') or { 'text' })
			if input_type in ['button', 'submit', 'reset'] {
				if value := element.get_attribute('value') {
					return value
				}
			}
			if input_type == 'image' {
				if alt := element.get_attribute('alt') {
					return alt
				}
			}
		}

		// F. Name From Content: Otherwise, if the current node's role allows name from content, or if the current node
		//    is referenced by aria-labelledby, aria-describedby, or is a native host language text alternative element
		//    (e.g. label in HTML), or is a descendant of a native host language text alternative element:
		if element_allows_accessible_name_from_content(element, should_compute_role) || element_is_referenced_for_accessibility(element) || is_descendant == .yes {
			mut accumulated_text := strings.new_builder(0)
			accumulated_text.write_string(generated_content_text(element, .before))
			mut child_nodes := n.children.clone()
			if element.is_shadow_host() {
				if shadow_root := element.shadow_root() {
					shadow_root_node := shadow_root_as_node(shadow_root)
					if shadow_root_node.is_connected() {
						child_nodes = shadow_root_node.children_as_vector()
					}
				}
			}
			if slot := node_as_html_slot_element(n) {
				if text := element.as_node().text_content() {
					accumulated_text.write_string(text)
				}
				child_nodes = slot.assigned_nodes()
			}
			for child_node in child_nodes {
				if !child_node.is_element() && !child_node.is_text() {
					continue
				}
				mut should_add_space := true
				// Node.cpp updates layout before consulting the child's display. Apart
				// from spacing, this also ensures TextNode::text_for_rendering() is
				// available for step G of the accessible-name algorithm.
				mut mutable_document := unsafe { &Document(document) }
				mutable_document.update_layout(.node_name_or_description)
				if layout_node := child_node.layout_node() {
					display := layout_node.display()
					if display.is_inline_outside() && display.is_flow_inside() {
						should_add_space = false
					}
				}
				if visited_nodes[child_node.unique_id()] {
					continue
				}
				result := child_node.name_or_description(target, document, mut visited_nodes, .yes, should_compute_role)!
				if should_add_space {
					accumulated_text.write_string(' ')
					accumulated_text.write_string(result)
				} else {
					accumulated_text.write_string(result)
				}
			}
			accumulated_text.write_string(generated_content_text(element, .after))
			if accumulated_text.len > 0 {
				return accumulated_text.str()
			}
		}
	}

	// G. Text Node: Otherwise, if the current node is a Text Node, return its textual contents.
	if n.is_text() {
		if parent_element := n.parent_element() {
			if !element_is_referenced_for_accessibility(parent_element) && parent_element.is_hidden() && parent_element.has_hidden_ancestor() && !element_has_referenced_and_hidden_ancestor(parent_element) {
				return ''
			}
		}
		if text := rendered_text_for_accessibility(n) {
			return text
		}
		return n.text_content() or { '' }
	}

	// I. Otherwise, if the current node has a Tooltip attribute, return its value.
	if element := n.as_element() {
		if !element.is_html_element() {
			return ''
		}
		if title := element.get_attribute('title') {
			if title.len > 0 {
				return title
			}
		}
	}

	// 3. After all steps are completed, the total accumulated text is used as the accessible name or accessible description
	//    of the element that initiated the computation.
	return ''
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
	element := n.as_element() or { return '' }
	described_by := element.get_attribute('aria-describedby') or { return '' }
	mut visited_nodes := map[UniqueNodeID]bool{}
	mut builder := strings.new_builder(0)
	for id in described_by.fields() {
		description_element := document.get_element_by_id(id) or { continue }
		description := description_element.as_node().name_or_description(.description, document, mut visited_nodes, .no, .yes)!
		append_accessible_text(mut builder, description)
	}
	return builder.str()
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
	mut state := n.copy_cold_data()
	state.registered_observers = state.registered_observers.clone()
	state.registered_observers << registered_observer
	n.cold_data_ = state
}

pub fn (n &Node) has_inclusive_ancestor_with_display_none_ignoring_animations() bool {
	for ancestor := ?&Node(n); ancestor != none;  {
		current := ancestor or { break }
		if element := current.as_element() {
			if props := element.el_computed_properties() {
				if props.display_is_none_ignoring_animations() {
					return true
				}
			}
		}
		ancestor = current.parent_or_shadow_host()
	}
	return false
}

pub fn (n &Node) has_inclusive_ancestor_with_event_listener(type_ string) bool {
	for ancestor := ?&Node(n); ancestor != none;  {
		current := ancestor or { break }
		if current.has_event_listener(type_) {
			return true
		}
		ancestor = current.parent_or_shadow_host()
	}
	doc := n.document()
	if doc != unsafe { nil } && doc.window != unsafe { nil } {
		if unsafe { &EventTarget(doc.window) }.has_event_listener(type_) {
			return true
		}
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
		return (element.local_name() == 'a' || element.local_name() == 'area') && element.has_attribute('href')
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
		decision := callback(child)
		if decision == .@break {
			return .@break
		}
		if decision == .skip_children_and_continue {
			continue
		}
		if child.for_each_in_subtree(callback) == .@break {
			return .@break
		}
	}
	return .@continue
}

pub fn (n &Node) for_each_in_inclusive_subtree(callback fn (&Node) TraversalDecision) TraversalDecision {
	decision := callback(n)
	if decision == .@break {
		return .@break
	}
	if decision == .skip_children_and_continue {
		return .@continue
	}
	return n.for_each_in_subtree(callback)
}

// https://dom.spec.whatwg.org/#concept-shadow-including-inclusive-descendant
pub fn (n &Node) for_each_shadow_including_inclusive_descendant(callback fn (&Node) TraversalDecision) TraversalDecision {
	decision := callback(n)
	if decision == .@break {
		return .@break
	}
	if decision == .skip_children_and_continue {
		return .@continue
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

// The visit_* traversals run the matching for_each_* traversal and then
// release its callback, which must be a closure literal written at the call.
// A closure passed to a traversal otherwise stays registered, with the nodes
// and documents it captured, after the traversal returns.
pub fn (n &Node) visit_subtree(callback fn (&Node) TraversalDecision) TraversalDecision {
	decision := n.for_each_in_subtree(callback)
	platform.release_closure(voidptr(callback))
	return decision
}

pub fn (n &Node) visit_inclusive_subtree(callback fn (&Node) TraversalDecision) TraversalDecision {
	decision := n.for_each_in_inclusive_subtree(callback)
	platform.release_closure(voidptr(callback))
	return decision
}

pub fn (n &Node) visit_shadow_including_descendants(callback fn (&Node) TraversalDecision) TraversalDecision {
	decision := n.for_each_shadow_including_descendant(callback)
	platform.release_closure(voidptr(callback))
	return decision
}

pub fn (n &Node) visit_shadow_including_inclusive_descendants(callback fn (&Node) TraversalDecision) TraversalDecision {
	decision := n.for_each_shadow_including_inclusive_descendant(callback)
	platform.release_closure(voidptr(callback))
	return decision
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
	return assign_unique_node_id(&Text{
		CharacterData: CharacterData{
			Node: Node{
				node_type: .text_node
				document_: document
				unique_id_: UniqueNodeID(0)
			}
			data_: data
		}
	})
}

pub fn new_document_fragment(document &Document) &DocumentFragment {
	return assign_unique_node_id(&DocumentFragment{
		ParentNode: ParentNode{
			Node: Node{
				node_type: .document_fragment_node
				document_: document
				unique_id_: UniqueNodeID(0)
			}
		}
	})
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
	// DOM offsets count UTF-16 units, but callers only need the length. Avoid
	// allocating a rune vector on every text replacement and range query.
	if utf8.validate_str(value) {
		mut length := 0
		for index := 0; index < value.len; index++ {
			byte := value[index]
			if byte & 0xc0 != 0x80 {
				length += if byte >= 0xf0 { 2 } else { 1 }
			}
		}
		return length
	}
	mut length := 0
	for r in value.runes() {
		length += if u32(r) > 0xffff { 2 } else { 1 }
	}
	return length
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
	a.set_value_with_attribute_steps(value)!
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

// https://dom.spec.whatwg.org/#dom-documentorshadowroot-customelementregistry
pub fn (sr &ShadowRoot) custom_element_registry() voidptr {
	return sr.custom_element_registry_
}

pub fn (mut sr ShadowRoot) set_custom_element_registry(registry voidptr) {
	sr.custom_element_registry_ = registry
}

pub fn (sr &ShadowRoot) keep_custom_element_registry_null() bool {
	return sr.keep_custom_element_registry_null_
}

pub fn (mut sr ShadowRoot) set_keep_custom_element_registry_null(value bool) {
	sr.keep_custom_element_registry_null_ = value
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

pub fn (ss &StyleScope) may_have_has_selectors() bool {
	if ss.may_have_has_selectors_callback != unsafe { nil } && ss.css_handle != unsafe { nil } {
		return ss.may_have_has_selectors_callback(ss.css_handle)
	}
	return false
}

pub fn (ss &StyleScope) may_have_has_selectors_with_relative_selector_that_has_sibling_combinator() bool {
	if ss.may_have_sibling_has_callback != unsafe { nil } && ss.css_handle != unsafe { nil } {
		return ss.may_have_sibling_has_callback(ss.css_handle)
	}
	return true
}

pub fn (ss &StyleScope) have_local_link_selectors() bool {
	if ss.have_local_link_selectors_callback != unsafe { nil }
		&& ss.css_handle != unsafe { nil } {
		return ss.have_local_link_selectors_callback(ss.css_handle)
	}
	return false
}

pub fn (ss &StyleScope) subtree_may_affect_has_selectors(node &Node) bool {
	if ss.subtree_may_affect_has_callback != unsafe { nil } && ss.css_handle != unsafe { nil } {
		return ss.subtree_may_affect_has_callback(ss.css_handle, node)
	}
	return true
}

pub fn (ss &StyleScope) pending_has_invalidation_covers_all_child_list_mutation_features(node &Node) bool {
	if ss.pending_has_covers_child_list != unsafe { nil } && ss.css_handle != unsafe { nil } {
		return ss.pending_has_covers_child_list(ss.css_handle, node)
	}
	return false
}

pub fn (ss &StyleScope) has_featureless_sensitive_has_selectors() bool {
	if ss.has_featureless_sensitive_callback != unsafe { nil } && ss.css_handle != unsafe { nil } {
		return ss.has_featureless_sensitive_callback(ss.css_handle)
	}
	return false
}

pub fn (mut ss StyleScope) record_pending_has_invalidation_mutation_features(node &Node, mutation_root &Node, includes_descendants bool) {
	if ss.record_has_mutation_callback != unsafe { nil } && ss.css_handle != unsafe { nil } {
		ss.record_has_mutation_callback(ss.css_handle, node, mutation_root, includes_descendants)
	}
}

pub fn (mut ss StyleScope) record_pending_has_invalidation_mutation_properties(node &Node, properties []InvalidationProperty) {
	if ss.record_has_properties_callback != unsafe { nil } && ss.css_handle != unsafe { nil } {
		ss.record_has_properties_callback(ss.css_handle, node, properties)
	}
}

pub fn (mut ss StyleScope) record_conservative_pending_has_invalidation(node &Node, may_affect_sibling_relationships bool) {
	if ss.record_conservative_has_callback != unsafe { nil } && ss.css_handle != unsafe { nil } {
		ss.record_conservative_has_callback(ss.css_handle, node, may_affect_sibling_relationships)
	}
}

pub fn (mut ss StyleScope) schedule_ancestors_style_invalidation_due_to_presence_of_has(node &Node) {
	if ss.schedule_has_invalidation_callback != unsafe { nil } && ss.css_handle != unsafe { nil } {
		ss.schedule_has_invalidation_callback(ss.css_handle, node)
	}
}

pub fn (sc &StyleComputer) invalidation_property_used_in_has_selector(property InvalidationProperty, style_scope &StyleScope) bool {
	if sc.invalidation_property_used_in_has_callback != unsafe { nil } && sc.css_handle != unsafe { nil } {
		return sc.invalidation_property_used_in_has_callback(sc.css_handle, property, style_scope)
	}
	return false
}

pub fn (sc &StyleComputer) invalidation_plan_for_properties(properties []InvalidationProperty, style_scope &StyleScope) &InvalidationPlan {
	if sc.invalidation_plan_callback != unsafe { nil } && sc.css_handle != unsafe { nil } {
		plan := sc.invalidation_plan_callback(sc.css_handle, properties, style_scope)
		return &plan
	}
	return &InvalidationPlan{}
}

pub struct InvalidationPlan {
pub mut:
	invalidate_self          bool
	invalidate_whole_subtree bool
	descendant_rules         []DescendantInvalidationRule
	sibling_rules            []SiblingInvalidationRule
}

pub fn (mut si StyleInvalidator) enqueue_invalidation_plan(node &Node, reason StyleInvalidationReason, plan InvalidationPlan) bool {
	if invalidation_plan_is_empty(plan) {
		return false
	}
	if plan.invalidate_whole_subtree {
		mut mutable_node := unsafe { &Node(node) }
		mutable_node.invalidate_style(reason)
		return true
	}
	if plan.invalidate_self {
		mut mutable_node := unsafe { &Node(node) }
		mutable_node.set_needs_style_update(true)
	}
	si.add_pending_invalidation(node, reason, plan)
	if element := node.as_element() {
		for sibling_rule in plan.sibling_rules {
			mut mutable_element := unsafe { &Element(element) }
			si.apply_sibling_invalidation(mut mutable_element, reason, sibling_rule)
		}
	}
	return false
}

pub fn (mut ln LayoutNode) set_needs_layout_update(reason SetNeedsLayoutReason) {
	_ = reason
	if ln.layout_handle != unsafe { nil } && ln.bridge_callbacks().set_needs_layout_update_callback != unsafe { nil } {
		ln.bridge_callbacks().set_needs_layout_update_callback(ln.layout_handle, true)
	}
	if ln.needs_layout_update_ {
		return
	}
	ln.needs_layout_update_ = true
	mut ancestor := ln.parent_
	for {
		parent := ancestor or { break }
		if parent.needs_layout_update_ {
			break
		}
		unsafe {
			parent.needs_layout_update_ = true
		}
		ancestor = parent.parent_
	}
}

pub fn (mut ln LayoutNode) invalidate_text_for_rendering() {
	if ln.layout_handle != unsafe { nil }
		&& ln.bridge_callbacks().invalidate_text_for_rendering_callback != unsafe { nil } {
		ln.bridge_callbacks().invalidate_text_for_rendering_callback(ln.layout_handle)
	}
}

pub fn (ln &LayoutNode) needs_layout_update() bool {
	return ln.needs_layout_update_
}

pub fn (mut ln LayoutNode) reset_needs_layout_update() {
	ln.needs_layout_update_ = false
	if ln.layout_handle != unsafe { nil } && ln.bridge_callbacks().set_needs_layout_update_callback != unsafe { nil } {
		ln.bridge_callbacks().set_needs_layout_update_callback(ln.layout_handle, false)
	}
}

pub fn (ln &LayoutNode) apply_style(css_computed_properties_handle voidptr) {
	if ln.layout_handle == unsafe { nil } || ln.bridge_callbacks().apply_style_callback == unsafe { nil } || css_computed_properties_handle == unsafe { nil } {
		return
	}
	ln.bridge_callbacks().apply_style_callback(ln.layout_handle, css_computed_properties_handle)
}

pub fn (ln &LayoutNode) apply_inherited_color_style(style voidptr) bool {
	if ln.layout_handle != unsafe { nil } && style != unsafe { nil }
		&& ln.bridge_callbacks().apply_color_style_callback != unsafe { nil }
		&& ln.bridge_callbacks().apply_color_style_callback(ln.layout_handle, style) {
		return true
	}
	ln.apply_style(style)
	return false
}

// The sampler knows which animated values changed before mutating the shared
// computed style. Embedders may retain paint geometry for compositor-only
// samples; other updates and embedders keep the ordinary style path. Returns
// true only when the embedder retained its paint transport for the sample.
pub fn (ln &LayoutNode) apply_animated_style(css_computed_properties_handle voidptr,
	only_compositor_changes bool) bool {
	if !only_compositor_changes || ln.bridge_callbacks().apply_animated_style_callback == unsafe { nil } {
		ln.apply_style(css_computed_properties_handle)
		return false
	}
	if ln.layout_handle == unsafe { nil } || css_computed_properties_handle == unsafe { nil } {
		return false
	}
	return ln.bridge_callbacks().apply_animated_style_callback(ln.layout_handle, css_computed_properties_handle)
}

pub fn (ln &LayoutNode) paintables() []&Paintable {
	return ln.paintables_.clone()
}
