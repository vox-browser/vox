module layout

import dom
import css
import html
import os
import svg
import time
import url

const audio_controls_markup = '<style>
.container { overflow: hidden; }
.controls { display: flex; flex-direction: column; font-family: sans-serif; font-size: 12px; color: white; user-select: none; }
.container.audio > .controls { inset: 0; background: rgb(38, 38, 38); justify-content: center; }
.timeline { z-index: 1; height: 5px; padding: 5px 0; margin: -5px 0; background: rgb(20, 20, 20); background-clip: content-box; flex-shrink: 0; }
.timeline-fill { height: 100%; background: #9d7cf2; width: 0%; }
.button-bar { display: flex; align-items: center; padding: 4px 8px; gap: 8px; min-height: 30px; }
.control-button { background: none; border: none; padding: 0; display: flex; align-items: center; justify-content: center; width: 24px; height: 24px; }
.icon { width: 24px; height: 24px; }
.play-pause-icon path { display: none; }
.play-pause-icon:not(.playing) .play-path { display: inline; }
.mute-button { margin-left: auto; }
.mute-button.muted > .icon > .volume-low, .mute-button.muted > .icon > .volume-high, .mute-button.muted > .icon > .speaker { clip-path: url(#muted-clip); }
.timestamp { min-width: 0; overflow: clip; white-space: nowrap; font-variant-numeric: tabular-nums; }
</style><div class="container audio"><div class="controls visible"><div class="timeline"><div class="timeline-fill"></div></div><div class="button-bar"><button class="control-button play-pause-button"><svg class="icon play-pause-icon" viewBox="0 0 24 24"><path class="play-path" d="m6 5 13 7-13 7Z"/></svg></button><span class="timestamp">00:00 / 00:00</span><button class="control-button mute-button high muted"><svg class="icon" viewBox="0 0 24 24"><defs><clipPath id="muted-clip"><path d="M3 0h21v21ZM0 0v24h24z"/></clipPath></defs><path class="muted-line" d="m5 5 14 14-1.5 1.5-14-14z"/><path class="volume-high" d="M14 4.08v2.04c2.23.55 4 2.9 4 5.88 0 2.97-1.77 5.33-4 5.88v2.04c3.45-.56 6-3.96 6-7.92s-2.55-7.36-6-7.92Z"/><path class="volume-low" d="M14 7.67v8.66c.35-.25.66-.55.92-.9A5.7 5.7 0 0 0 16 12c0-1.3-.39-2.5-1.08-3.43a4.24 4.24 0 0 0-.92-.9Z"/><path class="speaker" d="M4 9v6h4l4 5V4L8 9Z"/></svg></button></div></div></div>'

enum SVGReferencedResourceKind {
	mask
	clip_path
	pattern
}

struct TreeBuilderState {
mut:
	quote_nesting_level       u32
	registered_counter_styles map[string]css.CounterStyle
	counter_sets              map[string]css.CountersSet
	last_child_by_parent      map[string]string
	last_processed_key        string
	counter_tree_order_index  i64
}

fn abstract_element_counter_key(abstract_element &dom.AbstractElement) string {
	pseudo_suffix := if pseudo := abstract_element.pseudo_element() {
		':${int(pseudo) + 1}'
	} else {
		':0'
	}
	return '${abstract_element.element().as_node().unique_id().value()}${pseudo_suffix}'
}

fn abstract_element_counter_id(abstract_element &dom.AbstractElement) i64 {
	return abstract_element.element().as_node().unique_id().value() * 16 + if pseudo := abstract_element.pseudo_element() {
		i64(int(pseudo) + 1)
	} else {
		0
	}
}

fn abstract_element_counter_parent(abstract_element &dom.AbstractElement) ?dom.AbstractElement {
	if abstract_element.pseudo_element() != none {
		return dom.AbstractElement.new(abstract_element.element(), none)
	}
	parent := abstract_element.element().as_node().parent_element() or { return none }
	return dom.AbstractElement.new(parent, none)
}

fn resolve_layout_counters(mut builder_state TreeBuilderState, abstract_element dom.AbstractElement, computed &css.ComputedProperties) {
	parent := abstract_element_counter_parent(&abstract_element)
	parent_key := if parent_element := parent {
		abstract_element_counter_key(&parent_element)
	} else {
		''
	}
	parent_counters := if parent_key.len > 0 {
		builder_state.counter_sets[parent_key]
	} else {
		none
	}
	previous_sibling_counters := if previous_sibling_key := builder_state.last_child_by_parent[parent_key] {
		builder_state.counter_sets[previous_sibling_key]
	} else {
		none
	}
	previous_element_counters := if builder_state.last_processed_key.len > 0 {
		builder_state.counter_sets[builder_state.last_processed_key]
	} else {
		none
	}
	builder_state.counter_tree_order_index++
	origin := css.CounterOriginatingElement{
		id: abstract_element_counter_id(&abstract_element)
		parent_id: if parent_element := parent {
			abstract_element_counter_id(&parent_element)} else {
			none}
		tree_order_index: builder_state.counter_tree_order_index
		debug_description: abstract_element.debug_description()
	}
	mut mutable_abstract_element := abstract_element
	resolved := css.resolve_counters_for_layout(mut mutable_abstract_element, computed, origin, parent != none, parent_counters, previous_sibling_counters, previous_element_counters)
	key := abstract_element_counter_key(&abstract_element)
	if counters := resolved {
		builder_state.counter_sets[key] = counters
	} else {
		builder_state.counter_sets.delete(key)
	}
	if parent_key.len > 0 {
		builder_state.last_child_by_parent[parent_key] = key
	}
	builder_state.last_processed_key = key
}

fn resolve_marker_layout_counters(mut builder_state TreeBuilderState, abstract_element dom.AbstractElement, computed &css.ComputedProperties) {
	host := dom.AbstractElement.new(abstract_element.element(), none)
	host_key := abstract_element_counter_key(&host)
	host_counters := builder_state.counter_sets[host_key]
	builder_state.counter_tree_order_index++
	origin := css.CounterOriginatingElement{
		id: abstract_element_counter_id(&abstract_element)
		parent_id: abstract_element_counter_id(&host)
		tree_order_index: builder_state.counter_tree_order_index
		debug_description: abstract_element.debug_description()
	}
	mut mutable_abstract_element := abstract_element
	resolved := css.resolve_counters_for_layout(mut mutable_abstract_element, computed, origin, true, host_counters, none, host_counters)
	key := abstract_element_counter_key(&abstract_element)
	if counters := resolved {
		builder_state.counter_sets[key] = counters
	} else {
		builder_state.counter_sets.delete(key)
	}
}

// Layout::TreeBuilder::build(): compute style, construct the typed layout-node
// hierarchy (including text, generated content, special/replaced boxes and
// SVG), then perform anonymous-inline, continuation and table fixups before
// assigning containing blocks and layout indexes.
pub fn build_layout_tree(document &dom.Document) ?&Node {
	mut timing_checkpoint := time.sys_mono_now()
	root_element := document.document_element() or { return none }
	materialize_svg_use_shadow_trees(document)
	materialize_audio_controls_shadow_trees(document)
	timing_checkpoint = layout_timing_checkpoint('    materialize', timing_checkpoint)
	// HTML cannot own concrete CSSStyleSheet objects because css imports html's
	// DOM layer. Synchronize <style> elements at the boundary, then perform the
	// same top-down style pass that Document::update_style() performs upstream.
	css.sync_document_style_elements(document)
	timing_checkpoint = layout_timing_checkpoint('    sync_styles', timing_checkpoint)
	mut style_computer := css.css_style_computer_for(document)
	viewport_rect := document.viewport_rect()
	style_computer.set_viewport_rect(css.CSSPixelRect.new(viewport_rect.x, viewport_rect.y, viewport_rect.width, viewport_rect.height))
	css.begin_style_profile()
	css.recompute_style_for_subtree(mut style_computer, root_element.as_node())
	css.end_style_profile()
	timing_checkpoint = layout_timing_checkpoint('    style', timing_checkpoint)
	// The layout tree's root is the Viewport (whose DOM node is the Document itself); the root element's box
	// is its child. This is faithful to TreeBuilder recursing from the Document node, where
	// `is<DOM::Document>` allocates a Layout::Viewport with the document style.
	document_style := style_computer.create_document_style()
	mut viewport := unsafe { &Node(Viewport.new(document, document_style)) }
	mut builder_state := TreeBuilderState{
		registered_counter_styles: css.registered_counter_styles_for_document(document)
	}
	if root_element_box := build_layout_box_for_element(document, root_element, style_computer, mut builder_state) {
		propagate_overflow_to_viewport(root_element_box, mut viewport)
		viewport.append_child(root_element_box)
	}
	timing_checkpoint = layout_timing_checkpoint('    build_boxes', timing_checkpoint)
	// Top-layer elements do not generate boxes at their DOM-tree position.
	// Their ::backdrop and principal box are siblings of the root element under
	// the viewport, in top-layer order.
	for top_layer_element in document.top_layer_elements_for_layout() {
		if !top_layer_element.rendered_in_top_layer() {
			continue
		}
		if backdrop := build_backdrop_pseudo_element(document, top_layer_element, mut builder_state) {
			viewport.append_child(backdrop)
		}
		if top_layer_box := build_layout_box_for_element(document, top_layer_element, style_computer, mut builder_state) {
			viewport.append_child(top_layer_box)
		}
	}
	attach_referenced_svg_resources_in_subtree(mut viewport, document, style_computer, mut builder_state)
	fixup_inline_continuations(mut viewport, document)
	fixup_table_tree(mut viewport, document)
	recompute_containing_blocks(viewport)
	assign_layout_indexes(viewport)
	layout_timing_checkpoint('    tree_fixups', timing_checkpoint)
	return viewport
}

fn layout_timing_checkpoint(label string, previous u64) u64 {
	now := time.sys_mono_now()
	if os.getenv('LADYBIRD_DEBUG_TIMING') != '' {
		eprintln('Ladybird V timing: ${label} ${(now - previous) / 1_000_000} ms')
	}
	return now
}

fn materialize_audio_controls_shadow_trees(document &dom.Document) {
	root := unsafe { &dom.Node(document) }
	for mut audio in css.query_selector_all(root, 'audio') {
		if !audio.has_attribute('controls') || audio.shadow_root() != none {
			continue
		}
		mut shadow_root := audio.attach_a_user_agent_shadow_root(.named)
		mut shadow_node := unsafe { &dom.Node(shadow_root) }
		for child in html.parse_html_fragment(audio, audio_controls_markup) {
			shadow_node.append_child(child) or {}
		}
	}
}

fn containment_is_active(containment css.Containment) bool {
	return containment.size_containment || containment.inline_size_containment || containment.layout_containment || containment.style_containment || containment.paint_containment
}

// CSS Overflow 3 viewport propagation. This runs after the element layout
// nodes exist and before formatting-context selection, matching
// DOM::Document::update_layout(): the source element's used overflow becomes
// visible, so propagating body overflow does not spuriously create a BFC.
fn propagate_overflow_to_viewport(root &Node, mut viewport Node) {
	root_styled := root.as_node_with_style() or { return }
	if containment_is_active(root_styled.computed_values().contain()) {
		return
	}
	mut origin := root_styled
	root_dom := root.dom_node() or { return }
	root_element := root_dom.as_element() or { return }
	if root_element.is_html_element() && root_element.local_name() == 'html' && root_styled.computed_values().overflow_x() == .visible && root_styled.computed_values().overflow_y() == .visible {
		for child in root.children() {
			child_dom := child.dom_node() or { continue }
			child_element := child_dom.as_element() or { continue }
			if !child_element.is_html_element() || child_element.local_name() != 'body' {
				continue
			}
			child_styled := child.as_node_with_style() or { break }
			if containment_is_active(child_styled.computed_values().contain()) {
				return
			}
			origin = child_styled
			break
		}
	}
	viewport_styled := viewport.as_node_with_style() or { return }
	mut viewport_computed := unsafe { &css.ComputedProperties(viewport_styled.computed_values()) }
	mut origin_computed := unsafe { &css.ComputedProperties(origin.computed_values()) }
	for property_id in [css.PropertyID.overflow_x, .overflow_y] {
		overflow := if property_id == .overflow_x {
			origin_computed.overflow_x()
		} else {
			origin_computed.overflow_y()
		}
		viewport_value := match overflow {
			.visible { 'auto' }
			.clip { 'hidden' }
			else { overflow.str() }
		}
		viewport_computed.set_property_without_modifying_flags(property_id, &dom.StyleValue{
			css_text: viewport_value
		})
		origin_computed.set_property_without_modifying_flags(property_id, &dom.StyleValue{
			css_text: 'visible'
		})
	}
}

// The result of laying out a document: the root layout box and the LayoutState holding every box's geometry.
pub struct DocumentLayoutResult {
pub:
	root  &Node = unsafe { nil }
	state &LayoutState = unsafe { nil }
}

fn document_layout_update_callback(target voidptr, document &dom.Document, viewport_width f64, viewport_height f64) voidptr {
	_ = target
	result := run_document_layout(document, viewport_width, viewport_height) or {
		return unsafe { nil }
	}
	result_ptr := &DocumentLayoutResult{
		root: result.root
		state: result.state
	}
	return voidptr(result_ptr)
}

fn document_rendered_text_callback(target voidptr, document &dom.Document, element &dom.Element) string {
	_ = target
	viewport_width := document.viewport_rect().width
	author_rules := css.flatten_media_rules(collect_document_author_rules(document), viewport_width)
	return inner_text(element, author_rules)
}

pub fn install_document_layout_hook(document &dom.Document) {
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_layout_update_hook(dom.DocumentLayoutUpdateHook{
		callback: document_layout_update_callback
	})
	mutable_document.set_rendered_text_hook(dom.DocumentRenderedTextHook{
		callback: document_rendered_text_callback
	})
}

// The UsedValues (geometry) computed for `box`, if any.
pub fn (result &DocumentLayoutResult) used_values_for(box &NodeWithStyle) ?&UsedValues {
	return result.state.try_get(box)
}

// Build `document`'s layout tree and lay it out within a viewport of
// `viewport_width` × `viewport_height` px — the real-engine equivalent of
// Document::update_layout. Returns none for a document with no root element.
//
// The layout root is the Viewport (the initial containing block): its content box is pinned to the viewport
// rectangle (definite in both axes), so the root element fills the viewport width and root-level percentage
// heights resolve against the viewport height. The selected independent
// formatting context handles block, inline, flex, grid, table, SVG, fieldset,
// and replaced content.
pub fn run_document_layout(document &dom.Document, viewport_width f64, viewport_height f64) ?DocumentLayoutResult {
	mut timing_checkpoint := time.sys_mono_now()
	install_document_layout_hook(document)
	root := build_layout_tree(document) or { return none }
	timing_checkpoint = layout_timing_checkpoint('    build_tree_total', timing_checkpoint)
	viewport := root.as_viewport() or { return none }
	// TreeBuilder upstream associates each DOM node with its Layout::Node as it
	// is created. Install the opaque bridge before layout as well, so algorithms
	// which run during layout (notably list-item ordinal resolution) observe the
	// same complete layout tree. Geometry is refreshed after layout below.
	attach_layout_nodes(root)
	mut state := LayoutState.new()
	layout_viewport(mut state, viewport, viewport_width, viewport_height)
	layout_absolutely_positioned_descendants(mut state, root)
	resolve_relative_insets(mut state, root)
	measure_document_scrollable_overflow(mut state, root)
	timing_checkpoint = layout_timing_checkpoint('    geometry', timing_checkpoint)
	attach_layout_nodes_with_state(root, state)
	layout_timing_checkpoint('    attach_layout', timing_checkpoint)
	return DocumentLayoutResult{
		root: root
		state: state
	}
}

fn build_layout_box_for_element(document &dom.Document, element &dom.Element, style_computer &css.StyleComputer, mut builder_state TreeBuilderState) ?&Node {
	return build_layout_box_for_element_with_svg_resource_kind(document, element, style_computer, mut builder_state, none)
}

fn build_layout_box_for_element_with_svg_resource_kind(document &dom.Document, element &dom.Element, style_computer &css.StyleComputer, mut builder_state TreeBuilderState, svg_resource_kind ?SVGReferencedResourceKind) ?&Node {
	computed := css.computed_properties_for_element(element) or {
		style_computer.compute_style(dom.AbstractElement.new(element, none))
	}

	// `display: none` produces no box (and neither do its descendants).
	if computed.display().is_none() {
		return none
	}

	mut box_node := if resource_kind := svg_resource_kind {
		match resource_kind {
			.mask { unsafe { &Node(SVGMaskBox.new(document, element, computed)) } }
			.clip_path { unsafe { &Node(SVGClipBox.new(document, element, computed)) } }
			.pattern { unsafe { &Node(SVGPatternBox.new(document, element, computed)) } }
		}
	} else {
		create_layout_node_for_element(document, element, computed) or { return none }
	}
	resolve_layout_counters(mut builder_state, dom.AbstractElement.new(element, none), computed)
	if !box_node.can_have_children() {
		return box_node
	}
	// TreeBuilder does not descend into a content-visibility:hidden element and
	// does not generate its ::before/::after or marker children. The principal
	// box itself remains, with its own padding/border and zero automatic content
	// size.
	if computed.content_visibility() == .hidden {
		return box_node
	}

	// Collect generated ::before content, DOM children, then generated ::after
	// content in tree order.
	mut children := []&Node{}
	if before := build_generated_pseudo_element(document, element, .before, .before, mut builder_state) {
		children << before
	}
	for child_node in layout_tree_children_for_element(element) {
		// Textarea light-DOM text initializes its value; rendering traverses the
		// UA-internal shadow tree instead.
		if element.is_html_element() && element.local_name() in ['textarea', 'select', 'details'] {
			continue
		}
		if child_element := child_node.as_element() {
			if child_element.rendered_in_top_layer() {
				continue
			}
			if child_box := build_layout_box_for_element(document, child_element, style_computer, mut builder_state) {
				if child_box.display().is_contents() {
					// A display:contents element generates no principal box. Its generated
					// content and DOM children participate directly in the parent's layout.
					for contents_child in child_box.children_.clone() {
						children << contents_child
					}
				} else {
					children << child_box
				}
			}
		} else if child_node.is_text() {
			if character_data := child_node.as_character_data() {
				children << unsafe { &Node(TextNode.new(document, child_node, character_data.data())) }
			}
		}
	}
	if element.is_html_element() && element.local_name() == 'input' {
		mut internal_children := build_input_internal_layout_children(document, element, computed)
		for mut internal_child in internal_children {
			mark_ua_internal_layout_subtree(mut internal_child)
		}
		children << internal_children
	} else if element.is_html_element() && element.local_name() == 'textarea' {
		mut internal_children := build_textarea_internal_layout_children(document, element, computed)
		for mut internal_child in internal_children {
			mark_ua_internal_layout_subtree(mut internal_child)
		}
		children << internal_children
	} else if element.is_html_element() && element.local_name() == 'select' {
		mut internal_children := build_select_internal_layout_children(document, element, computed)
		for mut internal_child in internal_children {
			mark_ua_internal_layout_subtree(mut internal_child)
		}
		children << internal_children
	} else if element.is_html_element() && element.local_name() == 'details' {
		children << build_details_internal_layout_children(document, element, computed, style_computer, mut builder_state)
	} else if element.is_html_element() && element.local_name() == 'progress' {
		mut internal_children := build_progress_internal_layout_children(document, element, computed)
		for mut internal_child in internal_children {
			mark_ua_internal_layout_subtree(mut internal_child)
		}
		children << internal_children
	}
	mut list_item_marker := ?&Node(none)
	if box_node.is_list_item_box() {
		if marker := build_list_item_marker(document, element, computed, mut builder_state) {
			list_item_marker = marker
			mut list_item := unsafe { &ListItemBox(box_node) }
			list_item.set_marker(marker)
		}
	}
	if after := build_generated_pseudo_element(document, element, .after, .after, mut builder_state) {
		children << after
	}
	if computed.display().is_contents() {
		// Keep a transient node only while recursively collecting this element's
		// children. The caller unboxes these children into the actual layout parent.
		for child in children {
			box_node.append_child(child)
		}
		return box_node
	}
	if element.is_html_element() && element.local_name() == 'audio' && element.shadow_root() != none {
		wrapper_style := computed.clone_for_anonymous_with_display(css.Display.from_short(.inline_block))
		mut wrapper := unsafe { &Node(BlockContainer.new(document, none, wrapper_style)) }
		wrapper.anonymous_ = true
		for child in children {
			wrapper.append_child(child)
		}
		wrapper.set_children_are_inline(false)
		children = [wrapper]
	}

	// SVGBox children are appended directly in TreeBuilder.cpp. SVG geometry is
	// not block/inline flow content and must never acquire anonymous HTML block
	// wrappers. SVGSVGBox is a ReplacedBox rather than an SVGBox, but establishes
	// the same SVG child-layout boundary.
	if box_node.is_svg_box() || (box_node.is_svg_svg_box() && box_node.display().is_inline_outside()) {
		for child in children {
			box_node.append_child(child)
			// SVGBox descendants take TreeBuilder.cpp's direct append path and do
			// not affect this invariant. Text, nested SVGSVGBox, and any other
			// non-SVGBox child take the ordinary insertion path and do.
			if !child.is_svg_box() {
				if child.is_inline() {
					box_node.set_children_are_inline(true)
				} else if child.as_node_with_style() != none && child.is_in_flow() {
					box_node.set_children_are_inline(false)
				}
			}
		}
	} else {
		attach_children_maintaining_inline_invariant(mut box_node, children, document, computed)
	}
	if element.is_html_element() && element.local_name() == 'audio' && element.shadow_root() != none {
		box_node.set_children_are_inline(false)
	}
	// SVGBox children take TreeBuilder's direct-append path and therefore do not
	// switch an SVG viewport into inline-child mode by themselves.
	if box_node.is_svg_svg_box() && children.len > 0 && children.all(it.is_svg_box()) {
		box_node.set_children_are_inline(false)
	}
	// The marker is a direct child maintained by ListItemBox; it does not
	// participate in the block/inline child classification of list contents.
	if marker := list_item_marker {
		mut mutable_marker := unsafe { &Node(marker) }
		box_node.children_.prepend(mutable_marker)
		mutable_marker.parent_ = box_node
	}
	fixup_fieldset_content_box(mut box_node, document)
	fixup_button_layout_tree(mut box_node, document)
	return box_node
}

fn layout_tree_children_for_element(element &dom.Element) []&dom.Node {
	if shadow_root := element.shadow_root() {
		return unsafe { &dom.Node(shadow_root) }.children_as_vector()
	}
	if element.is_html_element() && element.local_name() == 'slot' {
		slot := unsafe { &dom.HTMLSlotElement(element) }
		assigned := slot.assigned_nodes_internal()
		if assigned.len > 0 {
			return assigned.clone()
		}
	}
	return element.as_node().children_as_vector()
}

fn build_details_internal_layout_children(document &dom.Document, element &dom.Element, host_computed &css.ComputedProperties, style_computer &css.StyleComputer, mut builder_state TreeBuilderState) []&Node {
	light_children := element.as_node().children_as_vector()
	mut summary_node := ?&dom.Node(none)
	for child in light_children {
		if child_element := child.as_element() {
			if child_element.is_html_element() && child_element.local_name() == 'summary' {
				summary_node = child
				break
			}
		}
	}
	mut children := []&Node{}
	if summary_dom_node := summary_node {
		if summary_element := summary_dom_node.as_element() {
			if summary_box := build_layout_box_for_element(document, summary_element, style_computer, mut builder_state) {
				children << summary_box
			}
		}
	}
	slot_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'slot') or {
		return children
	}
	slot_style := computed_style_with_overrides(host_computed, {
		css.PropertyID.display:            'block'
		css.PropertyID.content_visibility: if element.has_attribute('open') {
			'visible'
		} else {
			'hidden'
		}
	})
	mut slot := unsafe {
		&Node(BlockContainer.new(document, slot_element.as_node(), slot_style))
	}
	if element.has_attribute('open') {
		mut slot_children := []&Node{}
		for child in light_children {
			if summary_dom_node := summary_node {
				if voidptr(child) == voidptr(summary_dom_node) {
					continue
				}
			}
			if child_element := child.as_element() {
				if child_box := build_layout_box_for_element(document, child_element, style_computer, mut builder_state) {
					slot_children << child_box
				}
			} else if child.is_text() {
				if character_data := child.as_character_data() {
					slot_children << unsafe {
						&Node(TextNode.new(document, child, character_data.data()))
					}
				}
			}
		}
		attach_children_maintaining_inline_invariant(mut slot, slot_children, document, slot_style)
	}
	mark_ua_internal_layout_subtree(mut slot)
	children << slot
	return children
}

fn svg_resource_url_from_style_value(value css.StyleValue) ?string {
	return match value {
		css.URLStyleValue {
			value.url().url()
		}
		css.ImageStyleValue {
			value.url_.url()
		}
		css.StyleValueList {
			mut result := ?string(none)
			for item in value.values() {
				if item_url := svg_resource_url_from_style_value(item) {
					result = item_url
					break
				}
			}
			result
		}
		css.ShorthandStyleValue {
			mut result := ?string(none)
			for item in value.values() {
				if item_url := svg_resource_url_from_style_value(item) {
					result = item_url
					break
				}
			}
			result
		}
		else {
			none
		}
	}
}

fn svg_resource_fragment_for_property(computed &css.ComputedProperties, property_id css.PropertyID) ?string {
	mut reference := ?string(none)
	if declared := computed.property(property_id, .yes) {
		if parsed := css.parse_css_value_logic(property_id, declared.css_text) {
			reference = svg_resource_url_from_style_value(parsed)
		}
	}
	resolved_reference := reference or { return none }
	fragment_offset := resolved_reference.index('#') or { return none }
	if fragment_offset + 1 >= resolved_reference.len {
		return none
	}
	// SVGGraphicsElement::resolve_url_to_element() resolves the URL fragment,
	// which the URL parser exposes percent-decoded.
	return url.percent_decode(resolved_reference[fragment_offset + 1..]).bytestr()
}

fn layout_node_has_dom_ancestor(node &Node, target &dom.Element) bool {
	target_id := target.as_node().unique_id().value()
	mut ancestor := ?&Node(node)
	for {
		candidate := ancestor or { return false }
		if candidate_dom := candidate.dom_node() {
			if candidate_dom.unique_id().value() == target_id {
				return true
			}
		}
		ancestor = candidate.parent()
	}
	return false
}

fn svg_resource_target_in_tree_scope(owner &Node, document &dom.Document, fragment string) ?&dom.Element {
	if owner_dom := owner.dom_node() {
		if shadow_root := owner_dom.containing_shadow_root() {
			parent_node := unsafe { &dom.ParentNode(shadow_root) }
			if target := parent_node.get_element_by_id(fragment) {
				return target
			}
		}
	}
	return document.get_element_by_id(fragment)
}

fn attach_referenced_svg_resource(mut owner Node, document &dom.Document, style_computer &css.StyleComputer, mut builder_state TreeBuilderState, property_id css.PropertyID, expected_tag string, resource_kind SVGReferencedResourceKind) {
	computed := owner.computed_values()
	fragment := svg_resource_fragment_for_property(computed, property_id) or { return }
	target := svg_resource_target_in_tree_scope(owner, document, fragment) or { return }
	if !target.is_svg_element() || target.local_name() != expected_tag || layout_node_has_dom_ancestor(owner, target) {
		return
	}
	resource := build_layout_box_for_element_with_svg_resource_kind(document, target, style_computer, mut builder_state, resource_kind) or { return }
	owner.append_child(resource)
}

fn node_can_reference_svg_resources(node &Node) bool {
	return node.is_svg_graphics_box() || node.is_svg_foreign_object_box() || node.is_svg_svg_box()
}

// TreeBuilder::update_layout_tree_after_children(): each reference gets its own
// resource layout subtree because objectBoundingBox units depend on the box
// which owns that particular reference.
fn attach_referenced_svg_resources_in_subtree(mut node Node, document &dom.Document, style_computer &css.StyleComputer, mut builder_state TreeBuilderState) {
	if node_can_reference_svg_resources(node) {
		attach_referenced_svg_resource(mut node, document, style_computer, mut builder_state, .mask_image, 'mask', .mask)
		attach_referenced_svg_resource(mut node, document, style_computer, mut builder_state, .clip_path, 'clipPath', .clip_path)

		mut seen_patterns := map[i64]bool{}
		for property_id in [css.PropertyID.fill, css.PropertyID.stroke] {
			computed := node.computed_values()
			fragment := svg_resource_fragment_for_property(computed, property_id) or { continue }
			target := svg_resource_target_in_tree_scope(node, document, fragment) or { continue }
			target_id := target.as_node().unique_id().value()
			if target.is_svg_element() && target.local_name() == 'pattern' && !seen_patterns[target_id] && !layout_node_has_dom_ancestor(node, target) {
				if resource := build_layout_box_for_element_with_svg_resource_kind(document, target, style_computer, mut builder_state, .pattern) {
					node.append_child(resource)
					seen_patterns[target_id] = true
				}
			}
		}
	}
	// Include newly appended resources in this snapshot so references within a
	// mask, clip path, or pattern are resolved recursively as upstream builds it.
	mut children := node.children_.clone()
	for mut child in children {
		attach_referenced_svg_resources_in_subtree(mut child, document, style_computer, mut builder_state)
	}
}

// SVGUseElement::process_the_url()/update_shadow_tree(). The DOM translation
// does not yet expose SVGUseElement's closed shadow root, so materialize its
// same-document clone before the style and layout-tree passes. Keeping the
// clone below <use> gives TreeBuilder the same instance tree that upstream
// traverses through get_an_element_by_id() and clone_node(true).
fn materialize_svg_use_shadow_trees(document &dom.Document) {
	root := unsafe { &dom.Node(document) }
	for use_element in css.query_selector_all(root, 'use') {
		if !use_element.is_svg_element() || use_element.local_name() != 'use' {
			continue
		}
		mut already_materialized := false
		for child in use_element.as_node().children_as_vector() {
			if child.as_element() != none {
				already_materialized = true
				break
			}
		}
		if already_materialized {
			continue
		}
		mut href := use_element.get_attribute_value('href').trim_space()
		if href.len == 0 {
			href = use_element.get_attribute_value('xlink:href').trim_space()
		}
		if href.len == 0 {
			href = (use_element.get_attribute_ns('http://www.w3.org/1999/xlink', 'href') or { '' }).trim_space()
		}
		mut target := ?&dom.Element(none)
		if href.starts_with('#') && href.len > 1 {
			target = document.get_element_by_id(url.percent_decode(href[1..]).bytestr())
		} else if fragment_offset := href.index('#') {
			if fragment_offset + 1 < href.len {
				external_reference := href[..fragment_offset]
				if external_document := svg_image_document_for_source(document, external_reference) {
					target = external_document.get_element_by_id(url.percent_decode(href[fragment_offset + 1..]).bytestr())
				}
			}
		}
		resolved_target := target or { continue }
		if voidptr(resolved_target) == voidptr(use_element) || !resolved_target.is_svg_element() || !svg.valid_use_reference_tag(resolved_target.local_name()) {
			continue
		}
		clone := resolved_target.as_node().clone_node(document, true, none) or { continue }
		mut use_node := use_element.as_node()
		use_node.append_child(clone) or { continue }
	}
}

fn computed_style_with_overrides(base &css.ComputedProperties, overrides map[css.PropertyID]string) &css.ComputedProperties {
	mut computed := base.clone_for_anonymous_block()
	for property_id, value in overrides {
		computed.set_property_without_modifying_flags(property_id, &dom.StyleValue{
			css_text: value
		})
	}
	return computed
}

// HTMLProgressElement::create_shadow_tree_if_needed(). Its closed UA shadow
// root contains the ::slider-track element and its ::slider-fill child.
fn build_progress_internal_layout_children(document &dom.Document, element &dom.Element, host_computed &css.ComputedProperties) []&Node {
	track_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		return []
	}
	track_style := computed_style_with_overrides(host_computed, {
		css.PropertyID.display:             'block'
		css.PropertyID.height:              '100%'
		css.PropertyID.border_top_width:    '1px'
		css.PropertyID.border_right_width:  '1px'
		css.PropertyID.border_bottom_width: '1px'
		css.PropertyID.border_left_width:   '1px'
		css.PropertyID.border_top_style:    'solid'
		css.PropertyID.border_right_style:  'solid'
		css.PropertyID.border_bottom_style: 'solid'
		css.PropertyID.border_left_style:   'solid'
	})
	mut track := unsafe {
		&Node(BlockContainer.new(document, track_element.as_node(), track_style))
	}

	fill_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		return []
	}
	mut fill_overrides := {
		css.PropertyID.display: 'block'
		css.PropertyID.height:  '100%'
	}
	value_text := element.get_attribute_value('value').trim_space()
	if value_text.len > 0 {
		mut maximum := element.get_attribute_value('max').trim_space().f64()
		if element.get_attribute_value('max').trim_space() == '' || maximum <= 0 {
			maximum = 1
		}
		mut value := value_text.f64()
		if value < 0 {
			value = 0
		} else if value > maximum {
			value = maximum
		}
		fill_overrides[css.PropertyID.width] = '${value / maximum * 100}%'
	}
	fill_style := computed_style_with_overrides(host_computed, fill_overrides)
	mut fill := unsafe { &Node(BlockContainer.new(document, fill_element.as_node(), fill_style)) }
	fill.set_children_are_inline(false)
	track.append_child(fill)
	track.set_children_are_inline(false)
	return [track]
}

fn mark_ua_internal_layout_subtree(mut node Node) {
	node.set_is_in_ua_internal_shadow_tree(true)
	mut children := node.children()
	for mut child in children {
		mark_ua_internal_layout_subtree(mut child)
	}
}

// HTMLInputElement's UA-internal shadow trees. The DOM port does not yet
// materialize closed UA shadow roots, so TreeBuilder creates the equivalent
// styled layout subtree at the same boundary where upstream descends into it.
fn build_input_internal_layout_children(document &dom.Document, element &dom.Element, host_computed &css.ComputedProperties) []&Node {
	type_ := element.get_attribute_value('type').trim_space().to_lower()
	if type_ in ['', 'text', 'search', 'url', 'tel', 'email', 'password', 'number'] {
		outer_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
			return []
		}
		outer_style := computed_style_with_overrides(host_computed, {
			css.PropertyID.display:              'flex'
			css.PropertyID.height:               '100%'
			css.PropertyID.align_items:          'center'
			css.PropertyID.white_space_collapse: 'preserve'
			css.PropertyID.text_wrap_mode:       'nowrap'
			css.PropertyID.padding_top:          '1px'
			css.PropertyID.padding_right:        '2px'
			css.PropertyID.padding_bottom:       '1px'
			css.PropertyID.padding_left:         '2px'
		})
		mut outer := unsafe { &Node(Box.new(document, outer_element.as_node(), outer_style)) }
		inner_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
			return []
		}
		inner_height := '1lh'
		inner_line_height := '${host_computed.line_height().to_double()}px'
		mut value := element.get_attribute_value('value')
		if type_ == 'password' {
			value = '●'.repeat(value.runes().len)
		}
		placeholder := element.get_attribute_value('placeholder')
		placeholder_is_visible := value.len == 0 && placeholder.len > 0
		inner_style := computed_style_with_overrides(outer_style, {
			css.PropertyID.display:              if placeholder_is_visible {
				'inline'
			} else {
				'block'
			}
			css.PropertyID.width:                if placeholder_is_visible { '0' } else { '100%' }
			css.PropertyID.height:               inner_height
			css.PropertyID.line_height:          inner_line_height
			css.PropertyID.align_items:          'center'
			css.PropertyID.overflow_x:           'auto'
			css.PropertyID.overflow_y:           'auto'
			css.PropertyID.white_space_collapse: 'collapse'
			css.PropertyID.text_wrap_mode:       'nowrap'
		})
		mut inner := unsafe {
			&Node(BlockContainer.new(document, inner_element.as_node(), inner_style))
		}
		text := document.create_text_node(value)
		mut text_layout_node := TextNode.new(document, text.as_node(), value)
		text_layout_node.is_empty_editable_ = true
		inner.append_child(unsafe { &Node(text_layout_node) })
		inner.set_children_are_inline(true)
		outer.append_child(inner)
		if placeholder_is_visible {
			placeholder_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
				return []
			}
			placeholder_base := css.computed_properties_for_pseudo_element(element, .placeholder) or {
				host_computed
			}
			placeholder_style := computed_style_with_overrides(placeholder_base, {
				css.PropertyID.display:              'block'
				css.PropertyID.width:                '100%'
				css.PropertyID.height:               inner_height
				css.PropertyID.line_height:          inner_line_height
				css.PropertyID.align_items:          'center'
				css.PropertyID.overflow_x:           'hidden'
				css.PropertyID.overflow_y:           'hidden'
				css.PropertyID.white_space_collapse: 'collapse'
				css.PropertyID.text_wrap_mode:       'nowrap'
			})
			mut placeholder_box := unsafe {
				&Node(BlockContainer.new(document, placeholder_element.as_node(), placeholder_style))
			}
			placeholder_text := document.create_text_node(placeholder)
			placeholder_box.append_child(unsafe {
				&Node(TextNode.new(document, placeholder_text.as_node(), placeholder))
			})
			placeholder_box.set_children_are_inline(true)
			outer.append_child(placeholder_box)
		}
		if type_ == 'number' && host_computed.appearance() != .textfield {
			up_button := build_number_input_stepper_button(document, host_computed, 'M7.41,15.41L12,10.83L16.59,15.41L18,14L12,8L6,14L7.41,15.41Z') or { return [] }
			down_button := build_number_input_stepper_button(document, host_computed, 'M7.41,8.58L12,13.17L16.59,8.58L18,10L12,16L6,10L7.41,8.58Z') or { return [] }
			outer.append_child(up_button)
			outer.append_child(down_button)
		}
		outer.set_children_are_inline(false)
		return [outer]
	}
	if type_ in ['submit', 'reset', 'button'] {
		span_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
			return []
		}
		span_style := computed_style_with_overrides(host_computed, {
			css.PropertyID.display: 'inline-block'
		})
		mut span := unsafe {
			&Node(BlockContainer.new(document, span_element.as_node(), span_style))
		}
		mut label := element.get_attribute_value('value')
		if label.len == 0 {
			label = if type_ == 'submit' {
				'Submit'
			} else if type_ == 'reset' {
				'Reset'
			} else {
				''
			}
		}
		text := document.create_text_node(label)
		mut text_layout_node := TextNode.new(document, text.as_node(), label)
		text_layout_node.is_empty_editable_ = true
		span.append_child(unsafe { &Node(text_layout_node) })
		span.set_children_are_inline(true)
		return [span]
	}
	if type_ == 'file' {
		multiple := element.has_attribute('multiple')
		button_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'button') or {
			return []
		}
		button_style := computed_style_with_overrides(host_computed, {
			css.PropertyID.display:             'inline-block'
			css.PropertyID.border_top_width:    '1px'
			css.PropertyID.border_right_width:  '1px'
			css.PropertyID.border_bottom_width: '1px'
			css.PropertyID.border_left_width:   '1px'
			css.PropertyID.border_top_style:    'outset'
			css.PropertyID.border_right_style:  'outset'
			css.PropertyID.border_bottom_style: 'outset'
			css.PropertyID.border_left_style:   'outset'
			css.PropertyID.padding_top:         '1px'
			css.PropertyID.padding_right:       '4px'
			css.PropertyID.padding_bottom:      '1px'
			css.PropertyID.padding_left:        '4px'
		})
		mut button := unsafe {
			&Node(BlockContainer.new(document, button_element.as_node(), button_style))
		}
		// The pseudo button is an HTML button and therefore receives the same
		// anonymous button-layout wrappers as any other button. In particular,
		// the flex wrapper carries height:100%, justify-content:center and the
		// button's min-height; those values participate in intrinsic sizing.
		button_outer_style := button_style.clone_for_button_flex_wrapper()
		mut button_outer := unsafe {
			&Node(BlockContainer.new(document, none, button_outer_style))
		}
		button_outer.anonymous_ = true
		button_inner_style := button_style.clone_for_anonymous_with_display(css.Display.from_short(.block))
		mut button_inner := unsafe {
			&Node(BlockContainer.new(document, none, button_inner_style))
		}
		button_inner.anonymous_ = true
		button_inner.is_button_content_box_ = true
		button_label := if multiple { 'Select files...' } else { 'Select file...' }
		button_text := document.create_text_node(button_label)
		button_inner.append_child(unsafe {
			&Node(TextNode.new(document, button_text.as_node(), button_label))
		})
		button_inner.set_children_are_inline(true)
		button_outer.append_child(button_inner)
		button_outer.set_children_are_inline(false)
		button.append_child(button_outer)
		button.set_children_are_inline(false)

		label_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'label') or {
			return []
		}
		label_style := computed_style_with_overrides(host_computed, {
			css.PropertyID.display:      'inline'
			css.PropertyID.padding_left: '4px'
		})
		mut label := unsafe { &Node(InlineNode.new(document, label_element.as_node(), label_style)) }
		status_label := if multiple { 'No files selected.' } else { 'No file selected.' }
		status_text := document.create_text_node(status_label)
		label.append_child(unsafe {
			&Node(TextNode.new(document, status_text.as_node(), status_label))
		})
		label.set_children_are_inline(true)
		// The input itself uses button layout. TreeBuilder's button fixup wraps
		// these inline UA-shadow children in the anonymous flex/content pair.
		return [button, label]
	}
	if type_ == 'range' {
		mut minimum := element.get_attribute_value('min').trim_space().f64()
		mut maximum := element.get_attribute_value('max').trim_space().f64()
		if element.get_attribute_value('min').trim_space() == '' {
			minimum = 0
		}
		if element.get_attribute_value('max').trim_space() == '' {
			maximum = 100
		}
		mut value := element.get_attribute_value('value').trim_space().f64()
		if element.get_attribute_value('value').trim_space() == '' {
			value = minimum + (maximum - minimum) / 2
		}
		position := if maximum > minimum {
			raw_position := (value - minimum) / (maximum - minimum) * 100
			if raw_position < 0 {
				0.0
			} else if raw_position > 100 {
				100.0
			} else {
				raw_position
			}
		} else {
			50.0
		}
		track_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
			return []
		}
		track_style := computed_style_with_overrides(host_computed, {
			css.PropertyID.display:             'block'
			css.PropertyID.position:            'relative'
			css.PropertyID.width:               '100%'
			css.PropertyID.height:              '4px'
			css.PropertyID.margin_top:          '6px'
			css.PropertyID.border_top_width:    '1px'
			css.PropertyID.border_right_width:  '1px'
			css.PropertyID.border_bottom_width: '1px'
			css.PropertyID.border_left_width:   '1px'
			css.PropertyID.border_top_style:    'solid'
			css.PropertyID.border_right_style:  'solid'
			css.PropertyID.border_bottom_style: 'solid'
			css.PropertyID.border_left_style:   'solid'
		})
		mut track := unsafe {
			&Node(BlockContainer.new(document, track_element.as_node(), track_style))
		}
		fill_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
			return []
		}
		fill_style := computed_style_with_overrides(host_computed, {
			css.PropertyID.display:  'block'
			css.PropertyID.position: 'absolute'
			css.PropertyID.width:    '${position}%'
			css.PropertyID.height:   '100%'
		})
		fill := unsafe { &Node(BlockContainer.new(document, fill_element.as_node(), fill_style)) }
		thumb_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
			return []
		}
		thumb_style := computed_style_with_overrides(host_computed, {
			css.PropertyID.display:     'block'
			css.PropertyID.width:       '16px'
			css.PropertyID.height:      '16px'
			css.PropertyID.margin_top:  '-6px'
			css.PropertyID.margin_left: '${position}%'
			css.PropertyID.transform:   'translateX(-50%)'
			css.PropertyID.z_index:     '1'
		})
		thumb := unsafe {
			&Node(BlockContainer.new(document, thumb_element.as_node(), thumb_style))
		}
		track.append_child(fill)
		track.append_child(thumb)
		track.set_children_are_inline(false)
		return [track]
	}
	return []
}

fn build_number_input_stepper_button(document &dom.Document, host_computed &css.ComputedProperties, path_data string) ?&Node {
	button_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'button') or {
		return none
	}
	button_style := computed_style_with_overrides(host_computed, {
		css.PropertyID.display:             'block'
		css.PropertyID.border_top_width:    '1px'
		css.PropertyID.border_right_width:  '1px'
		css.PropertyID.border_bottom_width: '1px'
		css.PropertyID.border_left_width:   '1px'
		css.PropertyID.border_top_style:    'solid'
		css.PropertyID.border_right_style:  'solid'
		css.PropertyID.border_bottom_style: 'solid'
		css.PropertyID.border_left_style:   'solid'
		css.PropertyID.padding_top:         '0'
		css.PropertyID.padding_right:       '0'
		css.PropertyID.padding_bottom:      '0'
		css.PropertyID.padding_left:        '0'
	})
	mut button := unsafe {
		&Node(BlockContainer.new(document, button_element.as_node(), button_style))
	}
	flex_style := button_style.clone_for_button_flex_wrapper()
	mut flex_wrapper := unsafe { &Node(BlockContainer.new(document, none, flex_style)) }
	flex_wrapper.anonymous_ = true
	content_style := button_style.clone_for_anonymous_with_display(css.Display.from_short(.block))
	mut content_wrapper := unsafe { &Node(BlockContainer.new(document, none, content_style)) }
	content_wrapper.anonymous_ = true
	content_wrapper.is_button_content_box_ = true

	mut svg_element := document.create_element_ns('http://www.w3.org/2000/svg', 'svg') or {
		return none
	}
	svg_element.set_attribute_value('xmlns', 'http://www.w3.org/2000/svg')
	svg_element.set_attribute_value('viewBox', '0 0 24 24')
	svg_style := computed_style_with_overrides(host_computed, {
		css.PropertyID.display: 'inline'
		css.PropertyID.width:   '1em'
		css.PropertyID.height:  '1em'
	})
	mut svg_box := create_layout_node_for_svg_element(document, svg_element, svg_style)?
	mut path_element := document.create_element_ns('http://www.w3.org/2000/svg', 'path') or {
		return none
	}
	path_element.set_attribute_value('fill', 'currentColor')
	path_element.set_attribute_value('d', path_data)
	path_style := computed_style_with_overrides(host_computed, {
		css.PropertyID.display: 'inline'
	})
	path_box := create_layout_node_for_svg_element(document, path_element, path_style)?
	svg_box.append_child(path_box)
	svg_box.set_children_are_inline(false)
	content_wrapper.append_child(svg_box)
	content_wrapper.set_children_are_inline(true)
	flex_wrapper.append_child(content_wrapper)
	flex_wrapper.set_children_are_inline(false)
	button.append_child(flex_wrapper)
	button.set_children_are_inline(false)
	return button
}

fn build_select_internal_layout_children(document &dom.Document, element &dom.Element, host_computed &css.ComputedProperties) []&Node {
	options := css.query_selector_all(element.as_node(), 'option')
	mut selected_text := ''
	for option in options {
		if option.has_attribute('selected') {
			selected_text = (option.as_node().text_content() or { '' }).trim_space()
			break
		}
	}
	if selected_text == '' && options.len > 0 {
		selected_text = (options[0].as_node().text_content() or { '' }).trim_space()
	}
	outer_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		return []
	}
	outer_style := computed_style_with_overrides(host_computed, {
		css.PropertyID.display:     'flex'
		css.PropertyID.align_items: 'center'
	})
	mut outer := unsafe { &Node(Box.new(document, outer_element.as_node(), outer_style)) }
	text_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		return []
	}
	text_style := computed_style_with_overrides(host_computed, {
		css.PropertyID.display: 'block'
	})
	mut text_box := unsafe {
		&Node(BlockContainer.new(document, text_element.as_node(), text_style))
	}
	text := document.create_text_node(selected_text)
	text_box.append_child(unsafe { &Node(TextNode.new(document, text.as_node(), selected_text)) })
	text_box.set_children_are_inline(true)
	outer.append_child(text_box)

	arrow_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		return []
	}
	arrow_style := computed_style_with_overrides(host_computed, {
		css.PropertyID.display:     'block'
		css.PropertyID.width:       '16px'
		css.PropertyID.height:      '16px'
		css.PropertyID.margin_left: '4px'
	})
	mut arrow := unsafe {
		&Node(BlockContainer.new(document, arrow_element.as_node(), arrow_style))
	}
	mut svg_element := document.create_element_ns('http://www.w3.org/2000/svg', 'svg') or {
		return []
	}
	svg_element.set_attribute_value('width', '16')
	svg_element.set_attribute_value('height', '16')
	svg_element.set_attribute_value('viewBox', '0 0 16 16')
	svg_style := computed_style_with_overrides(host_computed, {
		css.PropertyID.display: 'inline'
		css.PropertyID.width:   '16px'
		css.PropertyID.height:  '16px'
	})
	mut svg_box := create_layout_node_for_svg_element(document, svg_element, svg_style) or {
		return []
	}
	mut path_element := document.create_element_ns('http://www.w3.org/2000/svg', 'path') or {
		return []
	}
	path_element.set_attribute_value('d', 'M 4 5.71875 L 12 5.71875 L 8 10.671875 Z')
	path_style := computed_style_with_overrides(host_computed, {
		css.PropertyID.display: 'inline'
	})
	path_box := create_layout_node_for_svg_element(document, path_element, path_style) or {
		return []
	}
	svg_box.append_child(path_box)
	svg_box.set_children_are_inline(false)
	arrow.append_child(svg_box)
	arrow.set_children_are_inline(true)
	outer.append_child(arrow)
	outer.set_children_are_inline(false)
	return [outer]
}

fn build_textarea_internal_layout_children(document &dom.Document, element &dom.Element, host_computed &css.ComputedProperties) []&Node {
	value := element.as_node().child_text_content()
	placeholder := element.get_attribute_value('placeholder')
	placeholder_is_visible := value.len == 0 && placeholder.len > 0
	outer_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		return []
	}
	outer_style := computed_style_with_overrides(host_computed, {
		css.PropertyID.display: 'block'
	})
	mut outer := unsafe {
		&Node(BlockContainer.new(document, outer_element.as_node(), outer_style))
	}
	inner_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		return []
	}
	inner_style := computed_style_with_overrides(outer_style, {
		css.PropertyID.display: if placeholder_is_visible { 'inline' } else { 'block' }
	})
	mut inner := &Node(unsafe { nil })
	if placeholder_is_visible {
		inner = unsafe { &Node(InlineNode.new(document, inner_element.as_node(), inner_style)) }
	} else {
		inner = unsafe { &Node(BlockContainer.new(document, inner_element.as_node(), inner_style)) }
	}
	text := document.create_text_node(value)
	mut text_layout_node := TextNode.new(document, text.as_node(), value)
	text_layout_node.is_empty_editable_ = true
	inner.append_child(unsafe { &Node(text_layout_node) })
	inner.set_children_are_inline(true)
	outer.append_child(inner)
	if placeholder_is_visible {
		placeholder_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
			return []
		}
		placeholder_base := css.computed_properties_for_pseudo_element(element, .placeholder) or {
			host_computed
		}
		placeholder_style := computed_style_with_overrides(placeholder_base, {
			css.PropertyID.display: 'inline'
		})
		mut placeholder_node := unsafe {
			&Node(InlineNode.new(document, placeholder_element.as_node(), placeholder_style))
		}
		placeholder_text := document.create_text_node(placeholder)
		placeholder_node.append_child(unsafe {
			&Node(TextNode.new(document, placeholder_text.as_node(), placeholder))
		})
		placeholder_node.set_children_are_inline(true)
		outer.append_child(placeholder_node)
	}
	outer.set_children_are_inline(placeholder_is_visible)
	return [outer]
}

// TreeBuilder::wrap_in_button_layout_tree_if_needed(). HTML buttons (and the
// push-button input states) whose principal display is not flex/grid receive
// an anonymous column-flex wrapper and an anonymous content box.
fn node_uses_button_layout(node &Node) bool {
	dom_node := node.dom_node() or { return false }
	element := dom_node.as_element() or { return false }
	if element.local_name() == 'button' {
		return true
	}
	if element.local_name() != 'input' {
		return false
	}
	// HTMLInputElement::uses_button_layout(). Image buttons are buttons for
	// activation, but do not use the rendering section's button layout.
	type_ := element.get_attribute_value('type').trim_space().to_lower()
	return type_ in ['submit', 'reset', 'button', 'color', 'file']
}

fn fixup_button_layout_tree(mut node Node, document &dom.Document) {
	if !node_uses_button_layout(node) {
		return
	}
	if node.display().is_grid_inside() || node.display().is_flex_inside() {
		return
	}
	parent_style := node.as_node_with_style() or { return }
	flex_style := parent_style.computed_values().clone_for_button_flex_wrapper()
	mut flex_wrapper := unsafe { &Node(BlockContainer.new(document, none, flex_style)) }
	flex_wrapper.anonymous_ = true
	flex_wrapper.set_children_are_inline(false)
	// NodeWithStyle::create_anonymous_wrapper() makes the wrapper inline-block
	// when an empty inline-block parent creates it, so it participates correctly
	// in that parent's IFC.
	content_display := if node.is_inline_block() && !node.has_children() {
		css.Display.from_short(.inline_block)
	} else {
		css.Display.from_short(.block)
	}
	content_style := parent_style.computed_values().clone_for_anonymous_with_display(content_display)
	mut content_wrapper := unsafe { &Node(BlockContainer.new(document, none, content_style)) }
	content_wrapper.anonymous_ = true
	content_wrapper.is_button_content_box_ = true
	content_wrapper.set_children_are_inline(node.children_are_inline())
	for child in node.children_.clone() {
		content_wrapper.append_child(child)
	}
	flex_wrapper.append_child(content_wrapper)
	node.replace_children([flex_wrapper])
	node.set_children_are_inline(false)
}

fn fixup_fieldset_content_box(mut node Node, document &dom.Document) {
	fieldset := unsafe { &FieldSetBox(node) }
	if !node.is_fieldset_box() {
		return
	}
	legend := fieldset.rendered_legend() or { return }
	mut fieldset_style := node.as_node_with_style() or { return }
	content_style := fieldset_style.computed_values_.take_properties_for_fieldset_content_box()
	mut wrapper := unsafe { &Node(BlockContainer.new(document, none, content_style)) }
	wrapper.anonymous_ = true
	mut non_legend_children := []&Node{}
	for child in node.children_.clone() {
		if !layout_nodes_same(child, unsafe { &Node(legend) }) {
			non_legend_children << child
		}
	}
	for child in non_legend_children {
		wrapper.append_child(child)
	}
	wrapper.set_children_are_inline(non_legend_children.len > 0 && non_legend_children.all(it.is_inline()))
	node.replace_children([unsafe { &Node(legend) }, wrapper])
	node.set_children_are_inline(false)
}

fn build_generated_pseudo_element(document &dom.Document, element &dom.Element, dom_pseudo dom.PseudoElement, layout_pseudo css.PseudoElement, mut builder_state TreeBuilderState) ?&Node {
	computed := css.computed_properties_for_pseudo_element(element, dom_pseudo) or { return none }
	if computed.display().is_none() {
		return none
	}
	abstract_element := dom.AbstractElement.new(element, dom_pseudo)
	initial_quote_nesting_level := builder_state.quote_nesting_level
	initial_content_result := computed.content(&abstract_element, initial_quote_nesting_level, builder_state.registered_counter_styles)
	builder_state.quote_nesting_level = initial_content_result.final_quote_nesting_level
	initial_content := initial_content_result.content_data
	if initial_content.type_ in [.normal, .none_] {
		return none
	}
	resolve_layout_counters(mut builder_state, abstract_element, computed)
	content := computed.content(&abstract_element, initial_quote_nesting_level, builder_state.registered_counter_styles).content_data
	mut node := create_layout_node_for_generated_content(document, computed)
	node.set_generated_for(layout_pseudo, element)
	node.initial_quote_nesting_level_ = initial_quote_nesting_level
	if content.type_ == .list && node.can_have_children() {
		if content.items.len > 0 {
			for item in content.items {
				mut child := if item.type_ == .image {
					unsafe { &Node(ImageBox.new_generated(document, computed, item.value)) }
				} else {
					unsafe { &Node(TextNode.new_generated(document, item.value)) }
				}
				child.set_generated_for(layout_pseudo, element)
				node.append_child(child)
			}
		} else {
			// A generated string item creates a TextNode even when the string is
			// empty. The empty node still establishes inline generated content.
			node.append_child(unsafe { &Node(TextNode.new_generated(document, content.text)) })
		}
		node.set_children_are_inline(true)
	}
	if node.is_list_item_box() {
		if marker := build_list_item_marker(document, element, computed, mut builder_state) {
			mut mutable_marker := unsafe { &Node(marker) }
			node.children_.prepend(mutable_marker)
			mutable_marker.parent_ = node
			mut list_item := unsafe { &ListItemBox(node) }
			list_item.set_marker(mutable_marker)
		}
	}
	return node
}

fn build_backdrop_pseudo_element(document &dom.Document, element &dom.Element, mut builder_state TreeBuilderState) ?&Node {
	computed := css.computed_properties_for_pseudo_element(element, .backdrop) or { return none }
	if computed.display().is_none() {
		return none
	}
	resolve_layout_counters(mut builder_state, dom.AbstractElement.new(element, .backdrop), computed)
	mut node := create_layout_node_for_generated_content(document, computed)
	node.set_generated_for(.backdrop, element)
	return node
}

fn build_list_item_marker(document &dom.Document, element &dom.Element, list_item_computed &css.ComputedProperties, mut builder_state TreeBuilderState) ?&Node {
	marker_computed := css.computed_properties_for_pseudo_element(element, .marker) or {
		list_item_computed.clone_for_anonymous_block()
	}
	if marker_computed.display().is_none() {
		return none
	}
	abstract_element := dom.AbstractElement.new(element, .marker)
	initial_content := marker_computed.content(&abstract_element, 0, builder_state.registered_counter_styles).content_data
	if initial_content.type_ == .none_ {
		return none
	}
	if initial_content.type_ == .list {
		resolve_marker_layout_counters(mut builder_state, abstract_element, marker_computed)
		content := marker_computed.content(&abstract_element, 0, builder_state.registered_counter_styles).content_data
		mut marker := create_layout_node_for_generated_content(document, marker_computed)
		marker.set_generated_for(.marker, element)
		if marker.can_have_children() {
			for item in content.items {
				mut child := if item.type_ == .image {
					unsafe { &Node(ImageBox.new_generated(document, marker_computed, item.value)) }
				} else {
					unsafe { &Node(TextNode.new_generated(document, item.value)) }
				}
				child.set_generated_for(.marker, element)
				marker.append_child(child)
			}
			marker.set_children_are_inline(content.items.len > 0)
		}
		return marker
	}
	list_style_type := list_item_computed.list_style_type(builder_state.registered_counter_styles)
	if list_style_type.kind == .none_ {
		return none
	}
	marker := ListItemMarkerBox.new(document, list_style_type, list_item_computed.list_style_position(), element, marker_computed)
	mut marker_node := unsafe { &Node(marker) }
	marker_node.set_generated_for(.marker, element)
	return marker_node
}

fn create_layout_node_for_generated_content(document &dom.Document, computed &css.ComputedProperties) &Node {
	display := computed.display()
	if display.is_inline_outside() && display.is_flow_inside() {
		return unsafe { &Node(InlineNode.new(document, none, computed)) }
	}
	if display.is_list_item() {
		return unsafe { &Node(ListItemBox.new(document, none, computed)) }
	}
	if display.is_flow_inside() || display.is_flow_root_inside() || display.is_list_item() {
		return unsafe { &Node(BlockContainer.new(document, none, computed)) }
	}
	return unsafe { &Node(Box.new(document, none, computed)) }
}

struct HTMLInputElementLayoutNodeResult {
	handled bool
	node    ?&Node
}

// HTMLInputElement::create_layout_node(). A result wrapper distinguishes the
// hidden-state null result from the generic display-type fallback.
fn html_input_element_create_layout_node(document &dom.Document, element &dom.Element, computed &css.ComputedProperties) HTMLInputElementLayoutNodeResult {
	type_ := element.get_attribute_value('type').trim_space().to_lower()
	if type_ == 'hidden' {
		return HTMLInputElementLayoutNodeResult{ handled: true }
	}
	if type_ == 'image' {
		return HTMLInputElementLayoutNodeResult{
			handled: true
			node: unsafe { &Node(ImageBox.new(document, element, computed)) }
		}
	}
	if computed.appearance() == .none_ {
		return HTMLInputElementLayoutNodeResult{}
	}
	if type_ == 'checkbox' {
		return HTMLInputElementLayoutNodeResult{
			handled: true
			node: unsafe { &Node(CheckBox.new(document, element, computed)) }
		}
	}
	if type_ == 'radio' {
		return HTMLInputElementLayoutNodeResult{
			handled: true
			node: unsafe { &Node(RadioButton.new(document, element, computed)) }
		}
	}
	if type_ in ['', 'text', 'search', 'url', 'tel', 'email', 'password', 'number'] {
		return HTMLInputElementLayoutNodeResult{
			handled: true
			node: unsafe { &Node(TextInputBox.new(document, element, computed)) }
		}
	}
	if type_ in ['submit', 'button', 'reset'] {
		return HTMLInputElementLayoutNodeResult{
			handled: true
			node: unsafe { &Node(BlockContainer.new(document, element.as_node(), computed)) }
		}
	}
	return HTMLInputElementLayoutNodeResult{}
}

// Element::create_layout_node_for_display_type plus HTMLBRElement's override.
pub fn htmlbr_element_create_layout_node(document &dom.Document, element &dom.HTMLBRElement, computed &css.ComputedProperties) &Node {
	dom_element := unsafe { &dom.Element(element) }
	return unsafe { &Node(BreakNode.new(document, dom_element.as_node(), computed)) }
}

pub fn html_br_element_create_layout_node(document &dom.Document, element &dom.HTMLBRElement, computed &css.ComputedProperties) &Node {
	return htmlbr_element_create_layout_node(document, element, computed)
}

pub fn html_audio_element_create_layout_node(document &dom.Document, element &dom.HTMLAudioElement, computed &css.ComputedProperties) &Node {
	dom_element := unsafe { &dom.Element(element) }
	return unsafe { &Node(AudioBox.new(document, dom_element, computed)) }
}

pub fn html_audio_element_layout_node(element &dom.HTMLAudioElement) ?&AudioBox {
	layout_placeholder := unsafe { &dom.Element(element) }.as_node().unsafe_layout_node() or {
		return none
	}
	handle := layout_placeholder.real_layout_handle()
	if handle == unsafe { nil } {
		return none
	}
	return unsafe { &AudioBox(handle) }
}

pub fn html_video_element_create_layout_node(document &dom.Document, element &dom.HTMLVideoElement, computed &css.ComputedProperties) &Node {
	dom_element := unsafe { &dom.Element(element) }
	return unsafe { &Node(VideoBox.new(document, dom_element, computed)) }
}

pub fn html_iframe_element_create_layout_node(document &dom.Document, element &dom.HTMLIFrameElement, computed &css.ComputedProperties) &Node {
	dom_element := unsafe { &dom.Element(element) }
	return unsafe { &Node(NavigableContainerViewport.new(document, dom_element, computed)) }
}

pub fn html_canvas_element_create_layout_node(document &dom.Document, element &dom.HTMLCanvasElement, computed &css.ComputedProperties) &Node {
	dom_element := unsafe { &dom.Element(element) }
	return unsafe { &Node(CanvasBox.new(document, dom_element, computed)) }
}

pub fn html_image_element_create_layout_node(document &dom.Document, element &dom.HTMLImageElement, computed &css.ComputedProperties) &Node {
	dom_element := unsafe { &dom.Element(element) }
	return unsafe { &Node(ImageBox.new(document, dom_element, computed)) }
}

pub fn html_object_element_create_layout_node(document &dom.Document, element &dom.HTMLObjectElement, computed &css.ComputedProperties) ?&Node {
	dom_element := unsafe { &dom.Element(element) }
	model := html.html_object_element_model_for_dom_element(element)
	// Upstream queues the representation steps when HTMLObjectElement is constructed. The
	// translated DOM creates the concrete model lazily at this boundary, so start that queued
	// work before choosing a layout-node type. It remains unknown while inactive/loading and
	// becomes children when the resource cannot be represented.
	if model.representation() == .unknown {
		html.html_object_element_queue_element_task_to_run_object_representation_steps(element)
	}
	match model.representation() {
		.content_navigable {
			return unsafe { &Node(NavigableContainerViewport.new(document, dom_element, computed)) }
		}
		.image {
			if model.image_data() != none {
				return unsafe { &Node(ImageBox.new(document, dom_element, computed)) }
			}
			return none
		}
		.children {
			display := computed.display()
			if display.is_inline_outside() {
				if display.is_flow_root_inside() {
					return unsafe {
						&Node(BlockContainer.new(document, dom_element.as_node(), computed))
					}
				}
				if display.is_flex_inside() || display.is_grid_inside() {
					return unsafe { &Node(Box.new(document, dom_element.as_node(), computed)) }
				}
				return unsafe { &Node(InlineNode.new(document, dom_element.as_node(), computed)) }
			}
			if display.is_table_inside() || display.is_table_row_group() || display.is_table_header_group() || display.is_table_footer_group() || display.is_table_row() {
				return unsafe { &Node(Box.new(document, dom_element.as_node(), computed)) }
			}
			if display.is_list_item() {
				return unsafe { &Node(ListItemBox.new(document, dom_element.as_node(), computed)) }
			}
			if display.is_table_cell() || display.is_table_column() || display.is_table_column_group() || display.is_table_caption() || display.is_math_inside() || display.is_flow_inside() || display.is_flow_root_inside() || display.is_contents() || display.is_ruby_inside() {
				return unsafe { &Node(BlockContainer.new(document, dom_element.as_node(), computed)) }
			}
			if display.is_flex_inside() || display.is_grid_inside() {
				return unsafe { &Node(Box.new(document, dom_element.as_node(), computed)) }
			}
			return unsafe { &Node(InlineNode.new(document, dom_element.as_node(), computed)) }
		}
		else {
			return none
		}
	}
}

pub fn htmli_frame_element_create_layout_node(document &dom.Document, element &dom.HTMLIFrameElement, computed &css.ComputedProperties) &Node {
	return html_iframe_element_create_layout_node(document, element, computed)
}

pub fn html_video_element_layout_node(element &dom.HTMLVideoElement) ?&VideoBox {
	layout_placeholder := unsafe { &dom.Element(element) }.as_node().unsafe_layout_node() or {
		return none
	}
	handle := layout_placeholder.real_layout_handle()
	if handle == unsafe { nil } {
		return none
	}
	return unsafe { &VideoBox(handle) }
}

fn create_layout_node_for_element(document &dom.Document, element &dom.Element, computed &css.ComputedProperties) ?&Node {
	display := computed.display()
	if display.is_none() {
		return none
	}
	if element.is_svg_element() {
		return create_layout_node_for_svg_element(document, element, computed)
	}
	if element.is_html_element() {
		tag_name := element.local_name()
		if tag_name == 'br' {
			return htmlbr_element_create_layout_node(document, unsafe { &dom.HTMLBRElement(element) }, computed)
		}
		if tag_name == 'img' {
			return html_image_element_create_layout_node(document, unsafe {
				&dom.HTMLImageElement(element)
			}, computed)
		}
		if tag_name == 'canvas' {
			return html_canvas_element_create_layout_node(document, unsafe {
				&dom.HTMLCanvasElement(element)
			}, computed)
		}
		if tag_name == 'audio' {
			return html_audio_element_create_layout_node(document, unsafe {
				&dom.HTMLAudioElement(element)
			}, computed)
		}
		if tag_name == 'video' {
			return html_video_element_create_layout_node(document, unsafe {
				&dom.HTMLVideoElement(element)
			}, computed)
		}
		if tag_name == 'textarea' {
			return html_text_area_element_create_layout_node(document, element, computed)
		}
		if tag_name == 'fieldset' {
			return html_field_set_element_create_layout_node(document, element, computed)
		}
		if tag_name == 'legend' {
			return html_legend_element_create_layout_node(document, element, computed)
		}
		if tag_name == 'iframe' {
			return html_iframe_element_create_layout_node(document, unsafe {
				&dom.HTMLIFrameElement(element)
			}, computed)
		}
		if tag_name == 'embed' {
			return unsafe { &Node(ReplacedBox.new(document, element, computed)) }
		}
		if tag_name == 'object' {
			return html_object_element_create_layout_node(document, unsafe {
				&dom.HTMLObjectElement(element)
			}, computed)
		}
		if tag_name == 'input' {
			result := html_input_element_create_layout_node(document, element, computed)
			if result.handled {
				return result.node
			}
		}
	}
	if display.is_table_inside() || display.is_table_row_group() || display.is_table_header_group() || display.is_table_footer_group() || display.is_table_row() {
		return unsafe { &Node(Box.new(document, element.as_node(), computed)) }
	}
	if display.is_list_item() {
		return unsafe { &Node(ListItemBox.new(document, element.as_node(), computed)) }
	}
	if display.is_table_cell() || display.is_table_column() || display.is_table_column_group() || display.is_table_caption() || display.is_math_inside() {
		return unsafe { &Node(BlockContainer.new(document, element.as_node(), computed)) }
	}
	if display.is_inline_outside() {
		if display.is_flow_root_inside() {
			return unsafe { &Node(BlockContainer.new(document, element.as_node(), computed)) }
		}
		if display.is_flow_inside() {
			return unsafe { &Node(InlineNode.new(document, element.as_node(), computed)) }
		}
		if display.is_flex_inside() || display.is_grid_inside() {
			return unsafe { &Node(Box.new(document, element.as_node(), computed)) }
		}
		return unsafe { &Node(InlineNode.new(document, element.as_node(), computed)) }
	}
	if display.is_flex_inside() || display.is_grid_inside() {
		return unsafe { &Node(Box.new(document, element.as_node(), computed)) }
	}
	if display.is_flow_inside() || display.is_flow_root_inside() || display.is_contents() || display.is_ruby_inside() {
		return unsafe { &Node(BlockContainer.new(document, element.as_node(), computed)) }
	}
	return unsafe { &Node(InlineNode.new(document, element.as_node(), computed)) }
}

// SVGElement::create_layout_node() overrides. Elements which are never
// rendered (defs/title/desc/metadata and uninstantiated resources) deliberately
// return null, just as their C++ classes do.
fn create_layout_node_for_svg_element(document &dom.Document, element &dom.Element, computed &css.ComputedProperties) ?&Node {
	tag_name := element.local_name()
	if tag_name == 'svg' {
		return unsafe { &Node(SVGSVGBox.new(document, element, computed)) }
	}
	if tag_name in ['circle', 'ellipse', 'line', 'path', 'polygon', 'polyline', 'rect'] {
		return unsafe { &Node(SVGGeometryBox.new(document, element, computed)) }
	}
	if tag_name in ['g', 'a', 'use'] {
		return unsafe { &Node(SVGGraphicsBox.new(document, element, computed)) }
	}
	if tag_name == 'image' {
		return unsafe { &Node(SVGImageBox.new(document, element, computed)) }
	}
	if tag_name == 'text' {
		return unsafe { &Node(SVGTextBox.new(document, element, computed)) }
	}
	if tag_name == 'tspan' {
		mut ancestor := element.as_node().parent()
		for {
			candidate := ancestor or { return none }
			if candidate_element := candidate.as_element() {
				if candidate_element.is_svg_element() && candidate_element.local_name() == 'text' {
					return unsafe { &Node(SVGTextBox.new(document, element, computed)) }
				}
			}
			ancestor = candidate.parent()
		}
		return none
	}
	if tag_name == 'textPath' {
		return unsafe { &Node(SVGTextPathBox.new(document, element, computed)) }
	}
	if tag_name == 'foreignObject' {
		return unsafe { &Node(SVGForeignObjectBox.new(document, element, computed)) }
	}
	// SVG animation elements do not override SVGElement::create_layout_node();
	// they therefore use the ordinary display-type factory. Their initial
	// display is inline, which matters when script inserts text into one.
	if tag_name in ['animate', 'animateMotion', 'animateTransform', 'set'] {
		return unsafe { &Node(InlineNode.new(document, element.as_node(), computed)) }
	}
	if tag_name == 'symbol' {
		if parent := element.as_node().parent_element() {
			if parent.is_svg_element() && parent.local_name() == 'use' {
				return unsafe { &Node(SVGGraphicsBox.new(document, element, computed)) }
			}
		}
		return none
	}
	if tag_name in ['defs', 'desc', 'metadata', 'title', 'symbol', 'mask', 'clipPath', 'pattern',
		'linearGradient', 'radialGradient', 'stop', 'filter', 'style', 'script', 'view'] {
		return none
	}
	// Filter primitives and supported SVG elements without a more specific
	// paintable retain the SVGBox base layout identity.
	return unsafe { &Node(SVGBox.new(document, element, computed)) }
}

// Whether a layout node is inline-level for the purpose of the block/inline invariant.
fn child_is_inline_level(node &Node) bool {
	return node.is_inline()
}

// Attach `children` while maintaining TreeBuilder's invariant that the in-flow
// children of block-level boxes are either all block-level or all inline-level.
// Out-of-flow boxes do not select either mode; when an anonymous inline wrapper
// is already open they join it, matching insertion_parent_for_block_node().
fn attach_children_maintaining_inline_invariant(mut parent Node, children []&Node, document &dom.Document, parent_computed &css.ComputedProperties) {
	if children.len == 0 {
		return
	}

	mut any_block := false
	mut any_inline := false
	for child in children {
		if child.is_out_of_flow() {
			// insertion_parent_for_block_node() gives ordinary out-of-flow boxes a
			// special path that leaves the parent's inline/block mode unchanged. A
			// generated pseudo-element deliberately does not take that path: its
			// block-level display wraps existing inline siblings just like an in-flow
			// block before the node itself is inserted out of flow.
			if child.is_generated_for_pseudo_element() && !child_is_inline_level(child) && any_inline {
				any_block = true
			}
			continue
		}
		if child_is_inline_level(child) {
			any_inline = true
		} else {
			any_block = true
		}
	}
	force_inline_wrappers := parent.is_fieldset_box() || parent.is_svg_foreign_object_box() || parent.display().is_flex_inside() || parent.display().is_grid_inside()
	// TreeBuilder temporarily permits in-flow block children inside an inline
	// flow box. The continuation fixup performed after construction splits that
	// inline around those blocks.
	if parent.is_inline_node() && parent.display().is_inline_outside() && parent.display().is_flow_inside() {
		parent.set_children_are_inline(!any_block)
		for child in children {
			parent.append_child(child)
		}
		return
	}

	// All inline-level (an inline formatting context) or all block-level: attach directly.
	if (!any_block || !any_inline) && !force_inline_wrappers {
		parent.set_children_are_inline(any_inline && !any_block)
		for child in children {
			parent.append_child(child)
		}
		return
	}

	// Mixed, flex/grid, and fieldset content: in-flow block children stay
	// direct; each run of inline children goes into one anonymous block.
	parent.set_children_are_inline(false)
	mut seen_in_flow_block := false
	for child_index, child in children {
		if child_is_inline_level(child) {
			mut wrapper := last_anonymous_inline_wrapper_or_new(mut parent, document, parent_computed)
			wrapper.append_child(child)
		} else if child.is_out_of_flow() && !child.is_generated_for_pseudo_element() && !parent.display().is_flex_inside() && !parent.display().is_grid_inside() {
			if last := parent.last_child() {
				if last.is_anonymous() && last.children_are_inline() && !last.is_generated_for_pseudo_element() {
					mut wrapper := unsafe { &Node(last) }
					wrapper.append_child(child)
					continue
				}
			}
			// TreeBuilder starts in inline-child mode. Out-of-flow children
			// inserted before the first in-flow block are retroactively enclosed
			// when that first block causes anonymous-wrapper generation.
			mut followed_by_inline_before_block := false
			if !seen_in_flow_block {
				for next_index := child_index + 1; next_index < children.len; next_index++ {
					next_child := children[next_index]
					if next_child.is_out_of_flow() {
						continue
					}
					followed_by_inline_before_block = child_is_inline_level(next_child)
					break
				}
			}
			if followed_by_inline_before_block {
				mut wrapper := last_anonymous_inline_wrapper_or_new(mut parent, document, parent_computed)
				wrapper.append_child(child)
				continue
			}
			parent.append_child(child)
		} else {
			parent.append_child(child)
			if !child.is_out_of_flow() {
				seen_in_flow_block = true
			}
		}
	}
}

// Return `parent`'s last child if it is an anonymous wrapper holding inline content, otherwise create such a
// wrapper, append it, and return it (Layout::TreeBuilder's last_child_creating_anonymous_wrapper_if_needed).
fn last_anonymous_inline_wrapper_or_new(mut parent Node, document &dom.Document, parent_computed &css.ComputedProperties) &Node {
	if last := parent.last_child() {
		if last.is_anonymous() && last.children_are_inline() {
			return last
		}
	}
	wrapper := create_anonymous_block_wrapper(document, parent_computed)
	parent.append_child(wrapper)
	return wrapper
}

// NodeWithStyle::create_anonymous_wrapper — an anonymous block box with the
// parent's inherited values and initial non-inherited values.
fn create_anonymous_block_wrapper(document &dom.Document, parent_computed &css.ComputedProperties) &Node {
	anonymous_style := parent_computed.clone_for_anonymous_block()
	mut wrapper := BlockContainer.new(document, none, anonymous_style)
	wrapper.anonymous_ = true
	wrapper.children_are_inline_ = true
	return unsafe { &Node(wrapper) }
}
