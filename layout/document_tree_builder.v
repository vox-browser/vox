module layout

import platform
import dom
import css
import html
import os
import painting
import svg
import time
import processmetrics
import url

enum SVGReferencedResourceKind {
	mask
	clip_path
	pattern
}

struct TreeBuilderState {
mut:
	workspace               &platform.Arena = unsafe { nil }
	allow_subtree_reuse      bool
	nonreusable_flow_roots   map[u64]bool
	quote_nesting_level      u32
	counter_sets             map[i64]css.CountersSet
	last_child_by_parent     map[i64]i64
	last_processed_key       i64 = -1
	counter_tree_order_index i64
	// Block-level pseudo-element boxes of an InlineNode, waiting to be inserted
	// into the nearest ancestor that is not an InlineNode.
	hoisted_pseudo_element_boxes map[u64][]&Node
}

// insertion_parent_for_block_node(): in-flow blocks and out-of-flow boxes stay
// in their inline-flow parent, but block-level pseudo-element boxes are
// anonymous and climb out of InlineNode ancestors. Table-internal pseudo boxes
// stay so table fixup can group them with their table-internal siblings.
fn pseudo_element_box_climbs_out_of_inline(node &Node) bool {
	if !node.is_generated_for_pseudo_element() || child_is_inline_level(node) {
		return false
	}
	display := node.display()
	return !display.is_internal_table() && !display.is_table_caption()
}

// Insert an InlineNode child's hoisted pseudo-element boxes where upstream's
// TreeBuilder places them in the nearest non-InlineNode ancestor: a ::before
// box was prepended to that ancestor, every other box was appended after the
// inline. Boxes keep their relative creation order.
fn insert_hoisted_pseudo_element_boxes(mut children []&Node, child &Node, mut builder_state TreeBuilderState) {
	key := u64(voidptr(child))
	hoisted := builder_state.hoisted_pseudo_element_boxes[key] or { return }
	builder_state.hoisted_pseudo_element_boxes.delete(key)
	mut prepend_index := 0
	for box in hoisted {
		if box.is_generated_for_before_pseudo_element() {
			children.insert(prepend_index, box)
			prepend_index++
		} else {
			children << box
		}
	}
}

fn abstract_element_counter_key(abstract_element dom.AbstractElement) i64 {
	// Node IDs are nonnegative. Reserve a lane for every current pseudo type
	// and a separate lane for the element itself, without formatting strings
	// for each parent, previous sibling and counter-free element.
	pseudo_lane := if pseudo := abstract_element.pseudo_element() {
		i64(int(pseudo) + 1)
	} else {
		i64(0)
	}
	assert pseudo_lane < 32
	node_id := abstract_element.element().as_node().unique_id().value()
	assert node_id >= 0 && node_id <= (i64(1) << 58) - 1
	return node_id * 32 + pseudo_lane
}

fn abstract_element_counter_id(abstract_element dom.AbstractElement) i64 {
	return abstract_element.element().as_node().unique_id().value() * 16 + if pseudo := abstract_element.pseudo_element() {
		i64(int(pseudo) + 1)
	} else {
		0
	}
}

fn abstract_element_counter_parent(abstract_element dom.AbstractElement) ?dom.AbstractElement {
	if abstract_element.pseudo_element() != none {
		return dom.AbstractElement.new(abstract_element.element(), none)
	}
	parent := abstract_element.element().as_node().parent_element() or { return none }
	return dom.AbstractElement.new(parent, none)
}

// Only counter creators retain their origin's diagnostic label. Inherited
// counters keep their existing creator, and a box with no counter operations
// cannot publish this origin. Avoid formatting every ordinary DOM node merely
// to discard its description during inheritance.
fn counter_origin_description(abstract_element dom.AbstractElement, computed &css.ComputedProperties) string {
	values := unsafe { &css.ComputedValues(computed) }
	if computed.display().is_none() || (!computed.display().is_list_item()
		&& values.counter_reset().len == 0 && values.counter_increment().len == 0
		&& values.counter_set().len == 0) {
		return ''
	}
	return abstract_element.debug_description()
}

fn resolve_layout_counters(mut builder_state TreeBuilderState, abstract_element dom.AbstractElement, computed &css.ComputedProperties) {
	if builder_state.counter_sets.len == 0 {
		values := unsafe { &css.ComputedValues(computed) }
		if !computed.display().is_list_item() && values.counter_reset().len == 0
			&& values.counter_increment().len == 0 && values.counter_set().len == 0 {
			// Before any counter exists, empty parent/sibling history cannot
			// affect a later creator. Keep its order and previous-element key,
			// but avoid allocating parent keys and empty history entries.
			abstract_element.set_counters_set(none)
			builder_state.counter_tree_order_index++
			builder_state.last_processed_key = abstract_element_counter_key(abstract_element)
			return
		}
	}
	parent := abstract_element_counter_parent(abstract_element)
	parent_key := if parent_element := parent {
		abstract_element_counter_key(parent_element)
	} else {
		i64(-1)
	}
	parent_counters := if parent_key >= 0 {
		builder_state.counter_sets[parent_key]
	} else {
		none
	}
	previous_sibling_counters := if previous_sibling_key := builder_state.last_child_by_parent[parent_key] {
		builder_state.counter_sets[previous_sibling_key]
	} else {
		none
	}
	previous_element_counters := if builder_state.last_processed_key >= 0 {
		builder_state.counter_sets[builder_state.last_processed_key]
	} else {
		none
	}
	builder_state.counter_tree_order_index++
	origin := css.CounterOriginatingElement{
		id: abstract_element_counter_id(abstract_element)
		parent_id: if parent_element := parent {
			abstract_element_counter_id(parent_element)
		} else {
			none
		}
		tree_order_index: builder_state.counter_tree_order_index
		debug_description: counter_origin_description(abstract_element, computed)
	}
	mut mutable_abstract_element := abstract_element
	resolved := css.resolve_counters_for_layout(mut mutable_abstract_element, computed, origin, parent != none, parent_counters, previous_sibling_counters, previous_element_counters)
	key := abstract_element_counter_key(abstract_element)
	builder_state.remember_counters(key, resolved, parent_key)
	builder_state.last_processed_key = key
}

fn resolve_marker_layout_counters(mut builder_state TreeBuilderState, abstract_element dom.AbstractElement, computed &css.ComputedProperties) {
	host := dom.AbstractElement.new(abstract_element.element(), none)
	host_key := abstract_element_counter_key(host)
	host_counters := builder_state.counter_sets[host_key]
	builder_state.counter_tree_order_index++
	origin := css.CounterOriginatingElement{
		id: abstract_element_counter_id(abstract_element)
		parent_id: abstract_element_counter_id(host)
		tree_order_index: builder_state.counter_tree_order_index
		debug_description: counter_origin_description(abstract_element, computed)
	}
	mut mutable_abstract_element := abstract_element
	resolved := css.resolve_counters_for_layout(mut mutable_abstract_element, computed, origin, true, host_counters, none, host_counters)
	key := abstract_element_counter_key(abstract_element)
	builder_state.remember_counters(key, resolved, -1)
}

// Layout::TreeBuilder::build(): compute style, construct the typed layout-node
// hierarchy (including text, generated content, special/replaced boxes and
// SVG), then perform anonymous-inline and table fixups before
// assigning containing blocks and layout indexes.
pub fn build_layout_tree(document &dom.Document) ?&Node {
	mut timing_checkpoint := time.sys_mono_now()
	document.document_element() or { return none }
	mut mutable_document := unsafe { &dom.Document(document) }
	if mutable_document.get_browsing_context() == none {
		mutable_document.set_browsing_context(&dom.BrowsingContext{
			active_document_: document
		})
	}
	if mutable_document.navigable() == none {
		mutable_document.set_cached_navigable(&dom.Navigable{
			active_document_: document
		})
	}
	css.begin_selector_parse_cache()
	defer {
		css.end_selector_parse_cache()
	}
	prepare_document_for_layout(document)
	timing_checkpoint = layout_timing_checkpoint('    materialize', timing_checkpoint)
	css.sync_document_style_elements(document)
	timing_checkpoint = layout_timing_checkpoint('    sync_styles', timing_checkpoint)
	mut style_computer := css.css_style_computer_for(document)
	css.begin_style_profile()
	mutable_document.set_needs_full_style_update(true)
	mutable_document.update_style()
	css.end_style_profile()
	timing_checkpoint = layout_timing_checkpoint('    style', timing_checkpoint)
	return build_layout_tree_from_computed_styles(document, mut style_computer, timing_checkpoint)
}

// Layout::TreeBuilder::build() consumes already-computed style. Keeping style
// calculation outside this helper lets Document::update_layout() follow the
// upstream order (update_style, then optionally rebuild the layout tree)
// without recascading inside TreeBuilder.
fn build_layout_tree_from_computed_styles(document &dom.Document, mut style_computer css.StyleComputer, initial_checkpoint u64) ?&Node {
	mut timing_checkpoint := initial_checkpoint
	root_element := document.document_element() or { return none }
	// A rebuilt tree can add or remove list-item boxes without a DOM child-list
	// mutation (for example through the reflected `hidden` property). Discard
	// ordinals cached by the previous tree so the first surviving marker derives
	// the list-item counter from the boxes in this tree.
	document_node := unsafe { &dom.Node(document) }
	document_node.for_each_in_inclusive_subtree(fn (node &dom.Node) dom.TraversalDecision {
		if element := node.as_element() {
			mut mutable_element := unsafe { &dom.Element(element) }
			mutable_element.ordinal_value_ = none
		}
		return .@continue
	})
	// The layout tree's root is the Viewport (whose DOM node is the Document itself); the root element's box
	// is its child. This is faithful to TreeBuilder recursing from the Document node, where
	// `is<DOM::Document>` allocates a Layout::Viewport with the document style.
	document_style := style_computer.create_document_style()
	mut viewport := unsafe { &Node(Viewport.new(document, document_style)) }
	mut builder_state := new_tree_builder_state()
	defer { builder_state.finish() }
	builder_state.allow_subtree_reuse = !document.needs_full_layout_tree_update() && document_layout_result(document) != none
	if root_element_box := build_layout_box_for_element(document, root_element, style_computer, mut builder_state) {
		propagate_root_styles_to_viewport(root_element_box, mut viewport)
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
	fixup_table_tree(mut viewport, document)
	recompute_containing_blocks(viewport)
	assign_layout_indexes(viewport)
	layout_timing_checkpoint('    tree_fixups', timing_checkpoint)
	return viewport
}

fn prepare_document_for_layout(document &dom.Document) {
	materialize_focused_text_control_models(document)
	materialize_svg_use_shadow_trees(document)
	materialize_media_controls_shadow_trees(document)
}

// Selection and caret painting read these native owners. Create their rendering
// state before style and layout, so the first display list cannot insert an
// input shadow tree into an already committed document.
fn materialize_focused_text_control_models(document &dom.Document) {
	mut focused_identity := voidptr(0)
	if focused := document.focused_area() {
		if element := focused.as_element() {
			materialize_text_control_model(document, element)
			focused_identity = voidptr(element)
		}
	}
	if active := document.active_element() {
		if voidptr(active) != focused_identity {
			materialize_text_control_model(document, active)
		}
	}
}

fn materialize_text_control_model(document &dom.Document, element &dom.Element) {
	if voidptr(element.document()) != voidptr(document) || !element.is_html_element() { return }
	if element.local_name() == 'input' {
		_ = html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
	} else if element.local_name() == 'textarea' {
		_ = html.html_text_area_element_model_for_dom_element(unsafe { &dom.HTMLTextAreaElement(element) })
	}
}

fn layout_timing_checkpoint(label string, previous u64) u64 {
	processmetrics.instruction_checkpoint(label)
	now := time.sys_mono_now()
	if os.getenv('LADYBIRD_DEBUG_TIMING') != '' {
		eprintln('Ladybird V timing: ${label} ${(now - previous) / 1_000_000} ms')
	}
	return now
}

fn materialize_media_controls_shadow_trees(document &dom.Document) {
	root := unsafe { &dom.Node(document) }
	for element in css.query_selector_all(root, 'audio, video') {
		// Materialize the actual owner before style/layout. An independently
		// attached shadow root belongs to its existing owner.
		if !element.is_html_element() || !element.has_attribute_ns(none, 'controls')
			|| element.shadow_root() != none {
			continue
		}
		mut media := html.html_media_element_for_dom_element(element) or { continue }
		media.create_controls()
	}
}

// Body style facts exist independently of generated layout boxes.
fn viewport_first_body_element(root &Node) ?&dom.Element {
	root_dom := root.dom_node() or { return none }
	for child := root_dom.first_child(); child != none; {
		current := child or { break }
		if current.is_html_body_element() { return current.as_element() }
		child = current.next_sibling()
	}
	return none
}

fn viewport_box_for_dom_node(root &Node, target &dom.Node) ?&Node {
	if node := root.dom_node() {
		if voidptr(node) == voidptr(target) { return root }
	}
	for child in root.children() {
		if node := child.dom_node() {
			if voidptr(node) == voidptr(target) { return child }
		}
	}
	// Table and mixed-inline fixup can insert anonymous boxes around either
	// the document element or its body. Keep identity tied to the DOM owner.
	for child in root.children() {
		if box := viewport_box_for_dom_node(child, target) { return box }
	}
	return none
}

fn viewport_document_element_box(viewport &Node) ?&Node {
	element := viewport.document().document_element() or { return none }
	return viewport_box_for_dom_node(viewport, element.as_node())
}

fn viewport_body_box(root &Node, element &dom.Element) ?&Node {
	return viewport_box_for_dom_node(root, element.as_node())
}

fn document_layout_style_did_update(_target voidptr, document &dom.Document) {
	previous := document_layout_result(document) or { return }
	root_element := viewport_document_element_box(previous.root) or { return }
	viewport_style := previous.root.as_node_with_style() or { return }
	old_values := viewport_style.computed_values()
	old_overflow_x := old_values.overflow_x()
	old_overflow_y := old_values.overflow_y()
	old_writing_mode := old_values.writing_mode()
	old_direction := old_values.direction()
	old_scrollbar_width := old_values.scrollbar_width()
	mut viewport := unsafe { &Node(previous.root) }
	propagate_root_styles_to_viewport(root_element, mut viewport)
	new_values := viewport_style.computed_values()
	// A styled body can affect the principal mode without owning a box. Mark
	// geometry only when the effective viewport facts changed, not when a
	// paint-only root/body restyle merely replaced its used-value copy.
	if old_overflow_x != new_values.overflow_x() || old_overflow_y != new_values.overflow_y()
		|| old_writing_mode != new_values.writing_mode() || old_direction != new_values.direction()
		|| old_scrollbar_width != new_values.scrollbar_width() {
		if root_dom := root_element.dom_node() {
			mut mutable_root_dom := unsafe { &dom.Node(root_dom) }
			mutable_root_dom.set_needs_layout_update(.style_change)
		}
	}
}

// Apply the principal writing mode and viewport overflow to box values only.
// Read each element's own computed style again on retained layout passes, as
// LayoutRustBridge::viewport_propagation_facts() does upstream.
fn propagate_root_styles_to_viewport(root &Node, mut viewport Node) {
	root_styled := root.as_node_with_style() or { return }
	root_dom := root.dom_node() or { return }
	root_element := root_dom.as_element() or { return }
	root_computed := css.computed_properties_for_element(root_element) or { return }
	mut viewport_styled := viewport.as_node_with_style() or { return }
	mut body_styled := ?&NodeWithStyle(none)
	mut body_computed := root_computed
	mut has_styled_body := false
	if body_element := viewport_first_body_element(root) {
		if properties := css.computed_properties_for_element(body_element) {
			body_computed = properties
			has_styled_body = true
		}
		if !body_computed.display().is_none() && !body_computed.display().is_contents() {
			if body_node := viewport_body_box(root, body_element) {
				body_styled = body_node.as_node_with_style()
			}
		}
	}
	// A display:contents body still supplies the principal writing mode, but
	// its missing box cannot supply viewport overflow (CSS Overflow 3).
	body_is_rendered := has_styled_body && !body_computed.display().is_none()
	body_propagation_is_disabled := !root_computed.contain().is_empty()
		|| (has_styled_body && !body_computed.contain().is_empty())
	root_is_html := root_element.is_html_element() && root_element.local_name() == 'html'
	writing_mode_origin := if root_is_html && body_is_rendered && !body_propagation_is_disabled {
		body_computed
	} else {
		root_computed
	}
	writing_mode := writing_mode_origin.writing_mode()
	direction := writing_mode_origin.direction()
	use_body_overflow := root_is_html && body_is_rendered && body_styled != none
		&& !body_propagation_is_disabled && root_computed.overflow_x() == .visible
		&& root_computed.overflow_y() == .visible
	overflow_origin := if use_body_overflow { body_computed } else { root_computed }
	viewport_overflow_x := match overflow_origin.overflow_x() {
		.visible { css.Overflow.auto_ }
		.clip { css.Overflow.hidden }
		else { overflow_origin.overflow_x() }
	}

	viewport_overflow_y := match overflow_origin.overflow_y() {
		.visible { css.Overflow.auto_ }
		.clip { css.Overflow.hidden }
		else { overflow_origin.overflow_y() }
	}

	viewport_styled.computed_values_ = viewport_styled.computed_values().with_viewport_overrides(viewport_overflow_x,
		viewport_overflow_y, writing_mode, direction, root_computed.scrollbar_width())
	mut mutable_root_styled := unsafe { &NodeWithStyle(root_styled) }
	mutable_root_styled.computed_values_ = root_styled.computed_values().with_viewport_overrides(if use_body_overflow {
		root_computed.overflow_x()
	} else {
		css.Overflow.visible
	}, if use_body_overflow { root_computed.overflow_y() } else { css.Overflow.visible },
		writing_mode, direction, root_computed.scrollbar_width())
	if styled := body_styled {
		mut mutable_body_styled := unsafe { &NodeWithStyle(styled) }
		mutable_body_styled.computed_values_ = styled.computed_values().with_viewport_overrides(if use_body_overflow {
			css.Overflow.visible
		} else {
			body_computed.overflow_x()
		}, if use_body_overflow { css.Overflow.visible } else { body_computed.overflow_y() },
			body_computed.writing_mode(), body_computed.direction(),
			body_computed.scrollbar_width())
	}
}

// The result of laying out a document: the root layout box and the LayoutState holding every box's geometry.
pub struct DocumentLayoutResult {
pub:
	root     &Node = unsafe { nil }
	state    &LayoutState = unsafe { nil }
	document &dom.Document = unsafe { nil }
pub mut:
	paint_tree                        BlockBox
	display_list_commands             []PaintCommand
	display_list                      &dom.DisplayList = unsafe { nil }
	stacking_context                  &dom.StackingContext = unsafe { nil }
	needs_accumulated_visual_contexts bool = true
	needs_repaint                     bool = true
	stacking_context_tree_is_valid    bool
	hit_test_display_list_is_valid    bool
	scroll_state                      painting.ScrollState
	scroll_state_snapshot             painting.ScrollStateSnapshot
	visual_context_tree               painting.AccumulatedVisualContextTree = painting.new_accumulated_visual_context_tree()
mut:
	// ViewportPaintable::build_stacking_context_tree() retains this sorted tree
	// until stacking invalidation upstream. Painting and hit testing consume
	// retained phase plans from the same ordering; the hit plan alone keeps
	// opacity:0 contexts targetable.
	paint_order         []PaintOrderEntry
	paint_steps         []CompatibilityPaintStep
	hit_test_steps      []CompatibilityPaintStep
	hit_test_order      []&BlockBox
	chrome_widget_boxes map[u64]voidptr
	// PaintableBox owns an active ResizeHandle whose ElementResizeAction survives the
	// layout/style invalidations caused by each drag step. Compatibility paint
	// boxes are rebuilt on every layout pass, so retain that state by the stable
	// DOM node identity on the committed document result instead.
	resize_handle_states map[i64]CompatibilityResizeHandleState
	// PaintableBox retains one command vector per PaintPhase. These buckets are
	// independent of display-list and stacking traversal lifetimes.
	paint_phase_commands      [][]PaintCommand
	paint_phase_command_count int
	paint_phase_cache_valid   bool
	paint_phase_line_box_debug bool
	paint_phase_entry_valid   []bool
	// Each entry's cumulative opacity when its phase commands were recorded.
	paint_phase_entry_opacity []f64
	paint_recording_viewport_only bool
	paint_projection_interest ?LayoutRect
	paint_projection_incomplete bool
	// The caret is emitted by its containing block's retained foreground phase.
	// Remember the dynamic inputs which selected that command so cursor moves and
	// blink/focus changes only invalidate the old and new containing blocks.
	cursor_cache_layout_handle voidptr = unsafe { nil }
	cursor_cache_offset        int
	cursor_cache_visible       bool
	cursor_cache_initialized   bool
	// CSS can apply a paint-only style through Document::update_layout(),
	// without entering the embedder's explicit layout wrapper.
	paint_tree_needs_style_update bool
	paint_style_update_requires_full_refresh bool
	paint_style_update_handles HandleSet
	paint_style_update_compositor_handles HandleSet
	// The subset whose text may paint differently: all updates except
	// animated samples that changed only background colors.
	paint_style_update_text_handles HandleSet
	// Scratch for refresh_local_paint_styles, kept for its storage.
	paint_style_update_ordinary_handles HandleSet
	paint_style_update_line_handles     HandleSet
	// Layout handle -> retained paint box, including the Viewport's root-box
	// mapping. The paint tree is immutable between refreshes, so wheel
	// coordinates and visual-context rebuilds share one lazily built index.
	boxes_by_layout_cache       map[u64]&BlockBox
	boxes_by_layout_cache_valid bool
	// Private recording storage plus command vectors returned by the shell.
	record_scratch CompatibilityRecordScratch
	paintable_bindings []&dom.Paintable
	// Storage of the published display list, and the document's reusable
	// scene arenas (see display_list_scene.v).
	paint_tree_storage &PaintTreeStorage = unsafe { nil }
	paint_tree_pool &PaintTreeStoragePool = unsafe { nil }
	scene      &DisplayListScene      = unsafe { nil }
	scene_pool &DisplayListScenePool = unsafe { nil }
}

fn document_layout_update_callback_with_paint_tree(document &dom.Document, viewport_width f64,
	viewport_height f64, needs_layout_tree_rebuild bool, build_paint_tree bool) voidptr {
	resize_handle_states := if previous := document_layout_result(document) {
		previous.resize_handle_states.clone()
	} else {
		map[i64]CompatibilityResizeHandleState{}
	}
	mut previous_result := document_layout_result(document) or { unsafe { &DocumentLayoutResult(nil) } }
	mut result := run_document_layout_with_current_style(document, viewport_width, viewport_height, needs_layout_tree_rebuild) or {
		return unsafe { nil }
	}
	if previous_result != unsafe { nil } && previous_result.paint_recording_viewport_only {
		result.paint_projection_interest = viewport_paint_interest(document)
	}
	if previous_result != unsafe { nil } { result.paint_tree_pool = previous_result.paint_tree_pool }
	paint_tree := if build_paint_tree {
		renderer_box_from_document_layout_result(result, viewport_width, viewport_height)
	} else {
		BlockBox{}
	}
	result_ptr := &DocumentLayoutResult{
		root: result.root
		state: result.state
		document: document
		paint_projection_interest: result.paint_projection_interest
		paint_projection_incomplete: result.paint_projection_incomplete
		paint_tree: paint_tree
		paint_tree_storage: result.paint_tree_storage
		paint_tree_pool: result.paint_tree_pool
		resize_handle_states: resize_handle_states
		record_scratch: take_document_recording_scratch(document)
		paint_phase_commands: take_document_phase_command_storage(document)
		paintable_bindings: take_document_paintable_bindings(document)
		scene_pool: if previous_result != unsafe { nil } { previous_result.scene_pool } else { unsafe { &DisplayListScenePool(nil) } }
	}
	// The replaced result no longer publishes commands; the shell keeps any
	// scene it adopted until it adopts the next one.
	if previous_result != unsafe { nil } && voidptr(previous_result) != voidptr(result_ptr) {
		previous_result.retire_display_list_scene()
		previous_result.retire_paint_tree_storage()
	}
	if build_paint_tree {
		install_document_painting_bridge(document, result_ptr)
	}
	return voidptr(result_ptr)
}

fn document_layout_update_callback(target voidptr, document &dom.Document, viewport_width f64,
	viewport_height f64, needs_layout_tree_rebuild bool) voidptr {
	_ = target
	return document_layout_update_callback_with_paint_tree(document, viewport_width, viewport_height, needs_layout_tree_rebuild, true)
}

fn document_layout_tree_update_callback(target voidptr, document &dom.Document, viewport_width f64,
	viewport_height f64, needs_layout_tree_rebuild bool) voidptr {
	_ = target
	return document_layout_update_callback_with_paint_tree(document, viewport_width, viewport_height, needs_layout_tree_rebuild, false)
}

pub fn install_document_layout_hook(document &dom.Document) {
	install_document_layout_hook_with_callback(document, document_layout_update_callback)
}

fn install_document_layout_tree_hook(document &dom.Document) {
	install_document_layout_hook_with_callback(document, document_layout_tree_update_callback)
}

fn install_document_layout_hook_with_callback(document &dom.Document,
	callback dom.DocumentLayoutUpdateCallback) {
	// Document owns its StyleComputer before update_layout() can enter the
	// layout callback upstream. Establish that side of the module boundary here
	// as well, so the first update performs Document::update_style() rather than
	// constructing a tree from unstored fallback styles.
	css.css_style_computer_for(document)
	html.install_document_accessibility_role_hook(document)
	html.install_document_csp_hook(document)
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_layout_update_hook(dom.DocumentLayoutUpdateHook{
		callback: callback
		style_did_update: document_layout_style_did_update
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
	return run_document_layout_with_renderer_mode(document, viewport_width, viewport_height, true)
}

// The layout-tree command serializes the retained typed tree and never consumes
// the compatibility BlockBox paint transport. Avoid materializing that second
// tree solely to discard it after the dump.
pub fn run_document_layout_for_tree_dump(document &dom.Document, viewport_width f64,
	viewport_height f64) ?DocumentLayoutResult {
	return run_document_layout_with_renderer_mode(document, viewport_width, viewport_height, false)
}

fn run_document_layout_with_renderer_mode(document &dom.Document, viewport_width f64,
	viewport_height f64, build_paint_tree bool) ?DocumentLayoutResult {
	mut allocations := document.enter_native_storage()
	defer { allocations.finish() }
	phase_mark := platform.arena_phase_begin()
	defer {
		platform.arena_phase_end('layout', phase_mark)
	}
	mut mutable_document := unsafe { &dom.Document(document) }
	previous_layout_handle := mutable_document.layout_engine_handle()
	old_viewport := mutable_document.viewport_rect()
	// The viewport origin is its scroll offset. Re-entering layout at the same
	// size must preserve scrolling without turning a paint update into a resize.
	viewport_changed := old_viewport.width != viewport_width || old_viewport.height != viewport_height
	mutable_document.set_viewport_rect(dom.Rect{old_viewport.x, old_viewport.y, viewport_width, viewport_height})
	// Navigable identity and its process-wide registry outlive document payload
	// storage. Isolated SVGs can first reach this path inside their payload owner.
	identity_storage := platform.enter_persistent()
	if mutable_document.get_browsing_context() == none {
		mutable_document.set_browsing_context(&dom.BrowsingContext{
			active_document_: document
		})
	}
	if mutable_document.navigable() == none {
		mutable_document.set_cached_navigable(&dom.Navigable{
			active_document_: document
		})
	}
	platform.leave_persistent(identity_storage)
	css.begin_selector_parse_cache()
	defer {
		css.end_selector_parse_cache()
	}
	prepare_document_for_layout(document)
	css.sync_document_style_elements(document)
	if build_paint_tree {
		install_document_layout_hook(document)
	} else {
		install_document_layout_tree_hook(document)
	}
	if mutable_document.layout_engine_handle() == unsafe { nil } || viewport_changed {
		// Image preflight can already have styled this document at the final
		// viewport. Building its first layout tree does not invalidate that
		// cascade. update_layout() still calls update_style(), which processes
		// pending DOM/sheet changes and the shadow trees prepared above.
		if viewport_changed || !document_has_computed_style_for_viewport(document,
			viewport_width, viewport_height) {
			mutable_document.set_needs_full_style_update(true)
		}
		mutable_document.set_needs_full_layout_tree_update(true)
	}
	css.begin_style_profile()
	mutable_document.update_layout(.debugging)
	css.end_style_profile()
	mut result := document_layout_result(document) or { return none }
	// A transform/opacity/filter animation can invalidate only painting. The
	// typed layout tree then remains current, but the compatibility renderer
	// transport still has to observe the freshly applied computed values.
	if build_paint_tree && previous_layout_handle != unsafe { nil }
		&& mutable_document.layout_engine_handle() == previous_layout_handle && result.needs_repaint {
		refresh_document_paint_tree(document, mut result, viewport_width, viewport_height)
	}
	return DocumentLayoutResult{
		root: result.root
		state: result.state
		document: result.document
		paint_tree: result.paint_tree
	}
}

fn document_has_computed_style_for_viewport(document &dom.Document, width f64, height f64) bool {
	root := document.document_element() or { return false }
	computed := css.computed_properties_for_element(root) or { return false }
	// Use the viewport retained by the computed style, rather than the mutable
	// document rect: an embedder can install a new rect before entering layout.
	return computed.viewport_rect_.width_value() == css.CSSPixels.nearest_value_for(width).to_double()
		&& computed.viewport_rect_.height_value() == css.CSSPixels.nearest_value_for(height).to_double()
}

// Document::update_layout() has already run Document::update_style() before it
// enters the layout-module callback. This path therefore translates the C++
// pipeline directly and never repeats the cascade while building the tree.
fn run_document_layout_with_current_style(document &dom.Document, viewport_width f64, viewport_height f64, needs_layout_tree_rebuild bool) ?DocumentLayoutResult {
	mut timing_checkpoint := time.sys_mono_now()
	root := if !needs_layout_tree_rebuild {
		previous := document_layout_result(document) or { return none }
		previous.root
	} else {
		mut style_computer := css.css_style_computer_for(document)
		build_layout_tree_from_computed_styles(document, mut style_computer, timing_checkpoint) or {
			return none
		}
	}
	timing_checkpoint = layout_timing_checkpoint('    build_tree_total', timing_checkpoint)
	return finish_document_layout(document, root, viewport_width, viewport_height, timing_checkpoint)
}

struct SizeQueryContainerGeometry {
	container    &dom.Element
	has_geometry bool
	width        f64
	height       f64
}

fn snapshot_size_query_container_geometry(root &Node) map[u64]SizeQueryContainerGeometry {
	mut geometries := map[u64]SizeQueryContainerGeometry{}
	mut nodes := [root]
	for nodes.len > 0 {
		node := nodes.pop()
		nodes << node.children()
		dom_node := node.dom_node() or { continue }
		container := dom_node.as_element() or { continue }
		if !container.is_size_query_container() {
			continue
		}
		identity := u64(voidptr(container))
		if identity in geometries {
			continue
		}
		previous := dom_node.unsafe_layout_node() or {
			geometries[identity] = SizeQueryContainerGeometry{ container: container }
			continue
		}
		geometries[identity] = SizeQueryContainerGeometry{
			container:    container
			has_geometry: previous.has_geometry_
			width:        previous.content_width_
			height:       previous.content_height_
		}
	}
	return geometries
}

// LayoutRustBridge's commit sink invalidates query dependents when a container's
// relevant content size changes. Preserve the committed geometry before the
// temporary geometry-less DOM bridge replaces it during the native V pass.
fn invalidate_size_queries_after_geometry_commit(previous map[u64]SizeQueryContainerGeometry) {
	for _, old in previous {
		current := old.container.as_node().unsafe_layout_node() or { continue }
		if !current.has_geometry_ {
			continue
		}
		style := css.computed_properties_for_element(old.container) or { continue }
		type_ := style.container_type()
		changed := if !old.has_geometry {
			true
		} else if type_.is_size_container {
			old.width != current.content_width_ || old.height != current.content_height_
		} else if type_.is_inline_size_container {
			if style.writing_mode() == .horizontal_tb {
				old.width != current.content_width_
			} else {
				old.height != current.content_height_
			}
		} else {
			false
		}
		if changed {
			css.invalidate_descendant_styles_depending_on_size_container_query(old.container)
		}
	}
}

fn finish_document_layout(document &dom.Document, root &Node, viewport_width f64, viewport_height f64, initial_checkpoint u64) ?DocumentLayoutResult {
	mut timing_checkpoint := initial_checkpoint
	viewport := root.as_viewport() or { return none }
	// Restore current propagation facts on retained trees as well as new trees.
	if root_element := viewport_document_element_box(root) {
		mut mutable_viewport := unsafe { &Node(root) }
		propagate_root_styles_to_viewport(root_element, mut mutable_viewport)
	}
	// ImagePaintable::reset_for_relayout() refreshes image availability and alt
	// text before geometry consumes the replaced element's natural dimensions.
	root.for_each_in_inclusive_subtree(fn (node &Node) dom.TraversalDecision {
		if image_box := node.as_image_box() {
			mut mutable_image_box := unsafe { &ImageBox(image_box) }
			mutable_image_box.reset_for_relayout()
		}
		return .@continue
	})
	// TreeBuilder upstream associates each DOM node with its Layout::Node as it
	// is created. Install the opaque bridge before layout as well, so algorithms
	// which run during layout (notably list-item ordinal resolution) observe the
	// same complete layout tree. Geometry is refreshed after layout below.
	previous_query_container_geometry := snapshot_size_query_container_geometry(root)
	prepared_attachment := prepare_dom_layout_attachment(root)
	initial_root_placeholder := prepared_attachment.root
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_layout_viewport(&dom.LayoutViewport{
		root_node: initial_root_placeholder
	})
	mut state := LayoutState.new()
	if previous := document_layout_result(document) {
		unsafe {
			state.previous_inline_layouts_ = previous.state.inline_layouts_
			state.previous_block_layouts_ = previous.state.block_layouts_
		}
	}
	state.enable_measurement_chunk_pool()
	$if prealloc {
		state.measurement_chunk_pool_.scratch_enabled_ = document.native_storage() != unsafe { nil }
	}
	defer { state.release_measurement_chunk_pool() }
	mut geometry_scratch := begin_document_geometry_scratch(document)
	geometry_started := timing_checkpoint
	layout_viewport(mut state, viewport, viewport_width * document.layout_coordinate_scale(),
		viewport_height * document.layout_coordinate_scale())
	timing_checkpoint = layout_timing_checkpoint('      formatting_contexts', timing_checkpoint)
	layout_absolutely_positioned_descendants(mut state, root)
	timing_checkpoint = layout_timing_checkpoint('      absolute_descendants', timing_checkpoint)
	resolve_relative_insets(mut state, root)
	timing_checkpoint = layout_timing_checkpoint('      relative_insets', timing_checkpoint)
	// Offsets and relative insets are final. Overflow measurement and DOM
	// projection read this geometry without changing the containing-block chain.
	coordinates := begin_paint_coordinate_session(state)
	measure_document_scrollable_overflow(mut state, root)
	coordinates.finish()
	geometry_scratch.finish()
	// The new cache retains only contexts present in this committed pass. Drop
	// the lookup owner for removed or otherwise ineligible previous contexts.
	state.previous_inline_layouts_ = map[u64]&RetainedInlineLayout{}
	state.previous_block_layouts_ = map[u64]&RetainedBlockLayout{}
	timing_checkpoint = layout_timing_checkpoint('      scrollable_overflow', timing_checkpoint)
	if os.getenv('LADYBIRD_DEBUG_TIMING') != '' {
		eprintln('Ladybird V timing:     geometry ${(timing_checkpoint - geometry_started) / 1_000_000} ms')
	}
	root_placeholder := commit_dom_layout_attachment(root, state, prepared_attachment)
	mutable_document.set_layout_viewport(&dom.LayoutViewport{
		root_node: root_placeholder
	})
	invalidate_size_queries_after_geometry_commit(previous_query_container_geometry)
	root.for_each_in_inclusive_subtree(fn (node &Node) dom.TraversalDecision {
		mut mutable_node := unsafe { &Node(node) }
		mutable_node.reset_needs_layout_update()
		return .@continue
	})
	layout_timing_checkpoint('    attach_layout', timing_checkpoint)
	return DocumentLayoutResult{
		root: root
		state: state
		document: document
	}
}

pub fn document_layout_result(document &dom.Document) ?&DocumentLayoutResult {
	handle := document.layout_engine_handle()
	if handle == unsafe { nil } {
		return none
	}
	return unsafe { &DocumentLayoutResult(handle) }
}

fn build_layout_box_for_element(document &dom.Document, element &dom.Element, style_computer &css.StyleComputer, mut builder_state TreeBuilderState) ?&Node {
	if builder_state.allow_subtree_reuse {
		if retained := reusable_clean_flow_subtree(element, mut builder_state.nonreusable_flow_roots) {
			resolve_retained_flow_counters(retained, mut builder_state)
			return retained.root
		}
	}
	return build_layout_box_for_element_with_svg_resource_kind(document, element, style_computer, mut builder_state, none)
}

fn is_svg_resource_box(node &Node) bool {
	return node.is_svg_pattern_box() || node.is_svg_mask_box() || node.is_svg_clip_box()
}

fn layout_node_is_attached_to_dom_subtree(layout_node &Node, subtree_root &dom.Node) bool {
	mut ancestor := layout_node.parent()
	for ancestor != none {
		current := ancestor or { break }
		if dom_node := current.dom_node() {
			if dom_node.is_shadow_including_inclusive_descendant_of(subtree_root) {
				return true
			}
		}
		ancestor = current.parent()
	}
	return false
}

fn clear_stale_layout_and_paint_node(node &dom.Node, content_visibility_hidden_root ?&dom.Node) dom.TraversalDecision {
	mut mutable_node := unsafe { &dom.Node(node) }
	mutable_node.set_needs_layout_tree_update(false, .none)
	mutable_node.set_child_needs_layout_tree_update(false)

	if dom_layout_node := node.unsafe_layout_node() {
		if dom_layout_node.real_layout_handle() != unsafe { nil } {
			mut layout_node := unsafe { &Node(dom_layout_node.real_layout_handle()) }
			if is_svg_resource_box(layout_node) {
				if hidden_root := content_visibility_hidden_root {
					if !layout_node_is_attached_to_dom_subtree(layout_node, hidden_root) {
						return .skip_children_and_continue
					}
				} else {
					return .skip_children_and_continue
				}
			}
			if layout_node.parent() != none {
				layout_node.remove()
			}
		}
	}

	mutable_node.detach_layout_node()
	mutable_node.clear_paintable()
	if element := node.as_element() {
		mut mutable_element := unsafe { &dom.Element(element) }
		mutable_element.clear_pseudo_element_nodes()
	}
	return .@continue
}

fn adjusted_display_for_replaced_element(display css.Display) ?css.Display {
	if display.is_table_inside() {
		return css.Display.from_short(if display.is_block_outside() { .block } else { .inline_ })
	}
	if display.is_internal_table() || display.is_table_caption() {
		return css.Display.from_short(.inline_)
	}
	return none
}

fn build_layout_box_for_element_with_svg_resource_kind(document &dom.Document, element &dom.Element, style_computer &css.StyleComputer, mut builder_state TreeBuilderState, svg_resource_kind ?SVGReferencedResourceKind) ?&Node {
	// TreeBuilder destroys synthetic pseudo ownership with the replaced subtree.
	// This branch is being replaced, so clear the previous synthetic
	// first-letter before a possible new target is created below.
	mut mutable_first_letter_owner := unsafe { &dom.Element(element) }
	mutable_first_letter_owner.set_pseudo_element_node(int(dom.PseudoElement.first_letter), none)
	computed := css.computed_properties_for_element(element) or {
		style_computer.compute_style(dom.AbstractElement.new(element, none))
	}

	// `display: none` produces no box (and neither do its descendants).
	if computed.display().is_none() {
		element.as_node().for_each_shadow_including_inclusive_descendant(fn (node &dom.Node) dom.TraversalDecision {
			return clear_stale_layout_and_paint_node(node, none)
		})
		return none
	}
	mut content_replacement_source := ?css.ContentItem(none)
	if computed.property(.content, .yes) != none {
		abstract_element := dom.AbstractElement.new(element, none)
		if !computed.display().is_contents() {
			content_replacement_source = computed.content_replacement_image(&abstract_element)
		}
		registered_counter_styles := css.content_counter_styles_for_layout(computed, abstract_element)
		content := registered_counter_styles.resolve_content(computed, &abstract_element, builder_state.quote_nesting_level).content_data
		mut mutable_computed := unsafe { &css.MutableComputedValues(computed) }
		mutable_computed.set_content(content)
	}

	mut box_node := if source := content_replacement_source {
		mut replacement_style := computed
		if adjusted_display := adjusted_display_for_replaced_element(computed.display()) {
			replacement_style = computed.clone_for_anonymous_with_display(adjusted_display)
		}
		unsafe { &Node(ImageBox.new_content_replacement_for_item(document, element, replacement_style, source)) }
	} else if resource_kind := svg_resource_kind {
		match resource_kind {
			.mask {
				resource_box := SVGMaskBox.new(document, element, computed)
				unsafe { &Node(resource_box) }
			}
			.clip_path {
				resource_box := SVGClipBox.new(document, element, computed)
				unsafe { &Node(resource_box) }
			}
			.pattern {
				resource_box := SVGPatternBox.new(document, element, computed)
				unsafe { &Node(resource_box) }
			}
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
		hidden_root := element.as_node()
		hidden_root.visit_shadow_including_descendants(fn [hidden_root] (node &dom.Node) dom.TraversalDecision {
			return clear_stale_layout_and_paint_node(node, hidden_root)
		})
		// Assigned slottables are not DOM descendants of the slot, so the
		// descendant cleanup above cannot reach their stale layout state.
		if element.is_html_element() && element.local_name() == 'slot' {
			slot := unsafe { &dom.HTMLSlotElement(element) }
			for slottable_root in slot.assigned_nodes_internal() {
				slottable_root.visit_shadow_including_inclusive_descendants(fn [slottable_root] (node &dom.Node) dom.TraversalDecision {
					return clear_stale_layout_and_paint_node(node, slottable_root)
				})
			}
		}
		return box_node
	}

	// Collect generated ::before content, DOM children, then generated ::after
	// content in tree order.
	mut children := []&Node{}
	if before := build_generated_pseudo_element(document, element, .before, .before, mut builder_state) {
		children << before
	}
	child_snapshot := layout_tree_children_for_element(element)
	defer { child_snapshot.storage.finish() }
	for child_node in child_snapshot.children {
		// Textarea light-DOM text initializes its value; rendering traverses the
		// UA-internal shadow tree instead.
		if element.is_html_element() && element.local_name() in ['textarea', 'select', 'details']
			&& element.shadow_root() == none {
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
					insert_hoisted_pseudo_element_boxes(mut children, child_box, mut builder_state)
				}
			}
		} else if child_node.is_text() {
			if character_data := child_node.as_character_data() {
				text_node := unsafe { &Node(TextNode.new(document, child_node, character_data.data())) }
				// A display:contents style parent supplies inherited text style even
				// though it has no principal box. Preserve that style with the same
				// anonymous inline wrapper as upstream, except for collapsible ASCII
				// whitespace which cannot produce a fragment.
				needs_style_wrapper := computed.display().is_contents()
					&& (!string_is_ascii_whitespace(character_data.data())
					|| computed.white_space_collapse() != .collapse)
				if needs_style_wrapper {
					wrapper_style := computed.clone_for_anonymous_with_display(css.Display.from_short(.inline_))
					mut wrapper := unsafe { &Node(InlineNode.new(document, none, wrapper_style)) }
					wrapper.anonymous_ = true
					wrapper.set_children_are_inline(true)
					wrapper.append_child(text_node)
					children << wrapper
				} else {
					children << text_node
				}
			}
		}
	}
	if element.is_html_element() && element.local_name() == 'input'
		&& element.shadow_root() == none {
		mut internal_children := build_input_internal_layout_children(document, element, computed)
		for mut internal_child in internal_children {
			mark_ua_internal_layout_subtree(mut internal_child)
		}
		children << internal_children
	} else if element.is_html_element() && element.local_name() == 'textarea'
		&& element.shadow_root() == none {
		mut internal_children := build_textarea_internal_layout_children(document, element, computed)
		for mut internal_child in internal_children {
			mark_ua_internal_layout_subtree(mut internal_child)
		}
		children << internal_children
	} else if element.is_html_element() && element.local_name() == 'select'
		&& element.shadow_root() == none {
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
	} else if element.is_html_element() && element.local_name() == 'meter' {
		mut internal_children := build_meter_internal_layout_children(document, element, computed)
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
	if box_node.is_inline_node() && !computed.display().is_contents() {
		mut kept := []&Node{cap: children.len}
		mut hoisted := []&Node{}
		for child in children {
			if pseudo_element_box_climbs_out_of_inline(child) {
				hoisted << child
			} else {
				kept << child
			}
		}
		if hoisted.len > 0 {
			children = kept.clone()
			builder_state.hoisted_pseudo_element_boxes[u64(voidptr(box_node))] = hoisted
		}
	}
	if computed.display().is_contents() {
		// Keep a transient node only while recursively collecting this element's
		// children. The caller unboxes these children into the actual layout parent.
		for child in children {
			box_node.append_child(child)
		}
		return box_node
	}
	if element.is_html_element() && element.local_name() in ['audio', 'video']
		&& element.shadow_root() != none {
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
	if box_node.is_svg_box() || box_node.is_svg_svg_box() {
		for child in children {
			box_node.append_child(child)
			// SVGBox descendants take TreeBuilder.cpp's direct append path and do
			// not affect this invariant. Text, foreignObject, nested SVGSVGBox, and
			// other non-SVG children take the ordinary insertion path and do affect
			// the flag. A block child of an inline flow parent interrupts its IFC, so
			// it does not clear an inline flag established by surrounding text.
			if !child.is_svg_box() {
				if child.is_inline() {
					box_node.set_children_are_inline(true)
				} else if child.as_node_with_style() != none && child.is_in_flow() {
					if !box_node.display().is_inline_outside()
						|| !box_node.display().is_flow_inside() {
						box_node.set_children_are_inline(false)
					}
				}
			}
		}
	} else {
		attach_children_maintaining_inline_invariant(mut box_node, children, document, computed)
	}
	if element.is_html_element() && element.local_name() in ['audio', 'video']
		&& element.shadow_root() != none {
		box_node.set_children_are_inline(false)
	}
	// SVGBox children take TreeBuilder's direct-append path and therefore do not
	// switch an SVG viewport into inline-child mode by themselves.
	if box_node.is_svg_svg_box() && children.len > 0 && children.all(it.is_svg_box()) {
		box_node.set_children_are_inline(false)
	}
	if marker := list_item_marker {
		attach_list_item_marker(mut box_node, marker, document, computed)
	}
	if box_node.is_block_container() {
		if first_letter_style := css.computed_properties_for_pseudo_element(element, .first_letter) {
			if !first_letter_style.display().is_none() {
				if target := find_first_letter_in_block(box_node) {
					create_first_letter_boxes(document, element, target, first_letter_style)
				}
			}
		}
	}
	fixup_fieldset_content_box(mut box_node, document)
	fixup_button_layout_tree(mut box_node, document)
	return box_node
}

struct LayoutTreeChildSnapshot {
	children []&dom.Node
	storage platform.ThreadScratchScope
}

fn layout_tree_child_candidates(element &dom.Element) []&dom.Node {
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

fn layout_tree_children_for_element(element &dom.Element) LayoutTreeChildSnapshot {
	storage := platform.begin_thread_scratch('layout child snapshot')
	children := layout_tree_child_candidates(element)
	storage.leave()
	// Selection can detach old layout nodes and notify resource owners. Keep
	// those mutations outside the pointer-vector workspace.
	if element.shadow_root() != none || !element.as_node().is_svg_switch_element() {
		return LayoutTreeChildSnapshot{children:children, storage:storage}
	}

	// SVG <switch> processes only the first direct SVG element child. The
	// requiredExtensions/systemLanguage predicates are upstream FIXMEs too; for
	// now every SVG child satisfies the same provisional condition.
	mut selected_child := ?&dom.Node(none)
	for child in children {
		if selected_child == none && child.is_svg_element() {
			selected_child = child
			continue
		}
		// A previous layout may have selected this child. Detach its whole stale
		// subtree when the selected child changes between tree rebuilds.
		child.for_each_shadow_including_inclusive_descendant(fn (node &dom.Node) dom.TraversalDecision {
			return clear_stale_layout_and_paint_node(node, none)
		})
	}
	if selected := selected_child {
		return LayoutTreeChildSnapshot{children:[selected], storage:storage}
	}
	return LayoutTreeChildSnapshot{storage:storage}
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
				insert_hoisted_pseudo_element_boxes(mut children, summary_box, mut builder_state)
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
					insert_hoisted_pseudo_element_boxes(mut slot_children, child_box, mut builder_state)
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

fn svg_resource_fragment_for_property(computed &css.ComputedValues, property_id css.PropertyID) ?string {
	reference := match property_id {
		.mask_image {
			if mask := computed.mask() {
				?string(mask.url().url())
			} else if image := computed.mask_image() {
				?string(image.url_.url())
			} else {
				none
			}
		}
		.clip_path {
			if clip_path := computed.clip_path() {
				if clip_path.is_url() { ?string(clip_path.url().url()) } else { none }
			} else {
				none
			}
		}
		.fill {
			if paint := computed.fill() {
				if paint.is_url() { ?string(paint.as_url().url()) } else { none }
			} else {
				none
			}
		}
		.stroke {
			if paint := computed.stroke() {
				if paint.is_url() { ?string(paint.as_url().url()) } else { none }
			} else {
				none
			}
		}
		else { none }
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

fn svg_pattern_href(element &dom.Element) string {
	if element.has_attribute('href') {
		return element.get_attribute_value('href').trim_space()
	}
	return element.get_attribute_value('xlink:href').trim_space()
}

fn linked_svg_pattern(element &dom.Element, mut seen map[i64]bool) ?&dom.Element {
	identity := element.as_node().unique_id().value()
	if !seen[identity] {
		seen[identity] = true
	}
	link := svg_pattern_href(element)
	if link == '' {
		return none
	}
	parsed := element.document().encoding_parse_url(link) or { return none }
	fragment := parsed.fragment() or { return none }
	if fragment == '' {
		return none
	}
	linked := element.document().get_element_by_id(fragment) or { return none }
	if !linked.is_svg_element() || linked.local_name() != 'pattern'
		|| linked.as_node().unique_id() == element.as_node().unique_id() {
		return none
	}
	linked_identity := linked.as_node().unique_id().value()
	if seen[linked_identity] {
		return none
	}
	return linked
}

fn svg_pattern_has_element_children(element &dom.Element) bool {
	for child in element.as_node().children_as_vector() {
		if child.as_element() != none {
			return true
		}
	}
	return false
}

fn svg_pattern_content_element(element &dom.Element) ?&dom.Element {
	mut seen := map[i64]bool{}
	seen[element.as_node().unique_id().value()] = true
	mut current := element
	for {
		if svg_pattern_has_element_children(current) {
			return current
		}
		current = linked_svg_pattern(current, mut seen) or { return none }
	}
	return none
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
	owner_dom_node := owner.dom_node() or { return }
	referencing_element := owner_dom_node.as_element() or { return }
	mut mutable_target := unsafe { &dom.Element(target) }
	mutable_target.register_svg_resource_box_referencing_element(referencing_element)
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
			if !target.is_svg_element() || target.local_name() != 'pattern' {
				continue
			}
			content_element := svg_pattern_content_element(target) or { continue }
			content_id := content_element.as_node().unique_id().value()
			if !seen_patterns[content_id] && !layout_node_has_dom_ancestor(node, content_element) {
				if resource := build_layout_box_for_element_with_svg_resource_kind(document, content_element, style_computer, mut builder_state, .pattern) {
					node.append_child(resource)
					if owner_dom_node := node.dom_node() {
						if referencing_element := owner_dom_node.as_element() {
							mut mutable_content := unsafe { &dom.Element(content_element) }
							mutable_content.register_svg_resource_box_referencing_element(referencing_element)
							if voidptr(content_element) != voidptr(target) {
								mut mutable_pattern := unsafe { &dom.Element(target) }
								mutable_pattern.register_svg_resource_box_referencing_element(referencing_element)
							}
						}
					}
					seen_patterns[content_id] = true
				}
			}
		}
	}
	// Iterate the live list so newly appended resources are resolved recursively
	// without cloning every child array in the document.
	mut child_index := 0
	for child_index < node.children_.len {
		mut child := node.children_[child_index]
		attach_referenced_svg_resources_in_subtree(mut child, document, style_computer, mut builder_state)
		child_index++
	}
}

// SVGUseElement::process_the_url()/update_shadow_tree() normally populates the
// use element's closed shadow root in DOM. Resolve here as well before style so
// forward references and external decoded SVG documents are ready for the
// first layout pass.
fn materialize_svg_use_shadow_trees(document &dom.Document) {
	root := unsafe { &dom.Node(document) }
	for use_element in css.query_selector_all(root, 'use') {
		if !use_element.is_svg_element() || use_element.local_name() != 'use' {
			continue
		}
		mut destination := use_element.as_node()
		if shadow_root := use_element.shadow_root() {
			destination = unsafe { &dom.Node(shadow_root) }
		}
		mut already_materialized := false
		for child in destination.children_as_vector() {
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
		if voidptr(resolved_target) == voidptr(use_element) || !resolved_target.is_svg_element()
			|| !svg.valid_use_reference_tag(resolved_target.local_name())
			|| !use_element.is_valid_svg_use_reference_element(resolved_target) {
			continue
		}
		clone := resolved_target.as_node().clone_node(document, true, none) or { continue }
		if mut clone_element := clone.as_element() {
			if clone_element.local_name() in ['svg', 'symbol'] {
				if use_element.has_attribute('width') {
					clone_element.set_attribute_value('width', use_element.get_attribute_value('width'))
				}
				if use_element.has_attribute('height') {
					clone_element.set_attribute_value('height', use_element.get_attribute_value('height'))
				}
			}
		}
		mut destination_node := unsafe { &dom.Node(destination) }
		destination_node.append_child(clone) or { continue }
		if shadow_root := use_element.shadow_root() {
			mut mutable_shadow_root := unsafe { &dom.ShadowRoot(shadow_root) }
			mutable_shadow_root.set_uses_document_style_sheets(use_element.svg_use_references_same_document())
		}
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

fn inline_start_margin_property(values &css.ComputedProperties) css.PropertyID {
	if values.writing_mode() == .horizontal_tb {
		return if values.direction() == .ltr { .margin_left } else { .margin_right }
	}
	return if values.direction() == .ltr { .margin_top } else { .margin_bottom }
}

fn inline_end_margin_property(values &css.ComputedProperties) css.PropertyID {
	if values.writing_mode() == .horizontal_tb {
		return if values.direction() == .ltr { .margin_right } else { .margin_left }
	}
	return if values.direction() == .ltr { .margin_bottom } else { .margin_top }
}

fn inline_end_inset_property(values &css.ComputedProperties) css.PropertyID {
	if values.writing_mode() == .horizontal_tb {
		return if values.direction() == .ltr { .right } else { .left }
	}
	return if values.direction() == .ltr { .bottom } else { .top }
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

// HTMLMeterElement::create_shadow_tree_if_needed(). Its closed UA shadow root
// has the same ::slider-track / ::slider-fill shape as <progress>; the meter's
// Default.css rules give the track a 1px border and both children `display:
// block; height: 100%`. update_meter_value_element() supplies the fill's width.
fn build_meter_internal_layout_children(document &dom.Document, element &dom.Element, host_computed &css.ComputedProperties) []&Node {
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
	meter := unsafe { &dom.HTMLMeterElement(element) }
	minimum := html.html_meter_element_min(meter)
	maximum := html.html_meter_element_max(meter)
	if maximum != minimum {
		// update_meter_value_element(): width = (value - min) / (max - min) * 100%.
		// A degenerate range formats as `nan%`, which is not a valid declaration,
		// so the fill keeps its automatic width.
		position := (html.html_meter_element_value(meter) - minimum) / (maximum - minimum) * 100
		fill_overrides[css.PropertyID.width] = '${position}%'
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

// HTMLInputElement's UA-internal shadow-tree fallback. Normal element-model
// lifecycle materializes the closed shadow root; this constructs the same
// styled subtree for documents parsed without that lifecycle hook.
fn static_control_placeholder_style(document &dom.Document, element &dom.Element,
	host_computed &css.ComputedProperties) &css.ComputedProperties {
	if existing := css.computed_properties_for_pseudo_element(element, .placeholder) { return existing }
	computer := css.css_style_computer_for(document)
	return computer.compute_pseudo_element_style_if_needed(dom.AbstractElement.new(element, .placeholder)) or { host_computed }
}

fn build_input_internal_layout_children(document &dom.Document, element &dom.Element, host_computed &css.ComputedProperties) []&Node {
	type_ := element.get_attribute_value('type').trim_space().to_lower()
	type_state := html.html_input_element_parse_type_attribute(type_)
	if type_state in [.text, .search, .telephone, .url, .email, .password, .date,
		.month, .week, .time, .local_date_and_time, .number] {
		outer_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
			return []
		}
		outer_style := computed_style_with_overrides(host_computed, {
			css.PropertyID.display:              'flex'
			css.PropertyID.height:               '100%'
			css.PropertyID.align_items:          'center'
			css.PropertyID.white_space_collapse: 'preserve'
			css.PropertyID.text_wrap_mode:       'nowrap'
		})
		mut outer := unsafe { &Node(Box.new(document, outer_element.as_node(), outer_style)) }
		mut text_container := outer
		if type_ == 'number' {
			text_container_element := document.create_element_ns('http://www.w3.org/1999/xhtml',
				'div') or { return [] }
			text_container_style := computed_style_with_overrides(outer_style, {
				css.PropertyID.display:     'flex'
				css.PropertyID.align_items: 'center'
				css.PropertyID.flex_grow:   '1'
				css.PropertyID.flex_shrink: '1'
				css.PropertyID.flex_basis:  '0%'
				css.PropertyID.min_width:   '0'
			})
			text_container = unsafe {
				&Node(Box.new(document, text_container_element.as_node(), text_container_style))
			}
			outer.append_child(text_container)
		}
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
			css.PropertyID.display:              'block'
			css.PropertyID.width:                '100%'
			css.PropertyID.height:               inner_height
			css.PropertyID.line_height:          inner_line_height
			css.PropertyID.overflow_x:           'auto'
			css.PropertyID.overflow_y:           'auto'
			css.PropertyID.white_space_collapse: 'preserve'
			css.PropertyID.text_wrap_mode:       'nowrap'
		})
		mut inner := unsafe {
			&Node(BlockContainer.new(document, inner_element.as_node(), inner_style))
		}
		text := document.create_text_node(value)
		mut text_layout_node := TextNode.new(document, text.as_node(), value)
		text_layout_node.is_empty_editable_ = true
		text_layout_node.update_produces_line_box_fragment_when_empty_flag()
		inner.append_child(unsafe { &Node(text_layout_node) })
		inner.set_children_are_inline(true)
		text_container.append_child(inner)
		if placeholder_is_visible {
			placeholder_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
				return []
			}
			placeholder_base := static_control_placeholder_style(document, element, host_computed)
			// Keep the pseudo-element line height; Chromium input placeholders reset
			// the host's author line height to normal in the UA style.
			mut placeholder_overrides := {
				css.PropertyID.display:              'block'
				css.PropertyID.width:                '100%'
				css.PropertyID.height:               inner_height
				css.PropertyID.overflow_x:           'hidden'
				css.PropertyID.overflow_y:           'hidden'
				css.PropertyID.white_space_collapse: 'collapse'
				css.PropertyID.text_wrap_mode:       'nowrap'
				css.PropertyID.pointer_events:       'none'
				css.PropertyID.user_select:          'none'
			}
			placeholder_overrides[inline_start_margin_property(placeholder_base)] = '-100%'
			placeholder_style := computed_style_with_overrides(placeholder_base, placeholder_overrides)
			mut placeholder_box := unsafe {
				&Node(BlockContainer.new(document, placeholder_element.as_node(), placeholder_style))
			}
			placeholder_text := document.create_text_node(placeholder)
			placeholder_box.append_child(unsafe {
				&Node(TextNode.new(document, placeholder_text.as_node(), placeholder))
			})
			placeholder_box.set_children_are_inline(true)
			text_container.append_child(placeholder_box)
		}
		if type_ == 'number' && host_computed.appearance() != .textfield {
			up_button := build_number_input_stepper_button(document, host_computed, 'M7.41,15.41L12,10.83L16.59,15.41L18,14L12,8L6,14L7.41,15.41Z') or { return [] }
			down_button := build_number_input_stepper_button(document, host_computed, 'M7.41,8.58L12,13.17L16.59,8.58L18,10L12,16L6,10L7.41,8.58Z') or { return [] }
			outer.append_child(up_button)
			outer.append_child(down_button)
		}
		text_container.set_children_are_inline(false)
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
		label := element.get_attribute('value') or {
			if type_ == 'submit' {
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
		text_layout_node.update_produces_line_box_fragment_when_empty_flag()
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
		css.PropertyID.d:       'path("${path_data}")'
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
	// Parser insertion normally runs selectedness before the UA shadow tree is
	// constructed. The compact layout-tree path has no persistent shadow tree,
	// so perform that lifecycle checkpoint before cloning the selected label.
	html.html_select_element_update_selectedness(unsafe { &dom.HTMLSelectElement(element) })
	options := css.query_selector_all(element.as_node(), 'option')
	mut selected_text := ''
	for option in options {
		if html.html_option_element_selected(unsafe { &dom.HTMLOptionElement(option) }) {
			selected_text = html.html_option_element_label(unsafe {
				&dom.HTMLOptionElement(option)
			})
			break
		}
	}
	outer_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		return []
	}
	outer_style := computed_style_with_overrides(host_computed, {
		css.PropertyID.display:     'flex'
		css.PropertyID.align_items: 'center'
		css.PropertyID.height:      '100%'
		css.PropertyID.position:    'relative'
	})
	mut outer := unsafe { &Node(Box.new(document, outer_element.as_node(), outer_style)) }
	text_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		return []
	}
	mut text_overrides := {
		css.PropertyID.display:     'block'
		css.PropertyID.flex_grow:   '1'
		css.PropertyID.flex_shrink: '1'
		css.PropertyID.flex_basis:  '0%'
		css.PropertyID.min_width:   '0'
	}
	text_overrides[inline_end_margin_property(host_computed)] = if host_computed.appearance() == .none_ {
		'0'
	} else {
		'20px'
	}
	text_style := computed_style_with_overrides(host_computed, text_overrides)
	mut text_box := unsafe {
		&Node(BlockContainer.new(document, text_element.as_node(), text_style))
	}
	text := document.create_text_node(selected_text)
	text_box.append_child(unsafe { &Node(TextNode.new(document, text.as_node(), selected_text)) })
	text_box.set_children_are_inline(true)
	outer.append_child(text_box)
	if host_computed.appearance() == .none_ {
		outer.set_children_are_inline(false)
		return [outer]
	}

	arrow_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		return []
	}
	mut arrow_overrides := {
		css.PropertyID.display:  'block'
		css.PropertyID.position: 'absolute'
		css.PropertyID.top:      'calc(50% - 8px)'
		css.PropertyID.width:    '16px'
		css.PropertyID.height:   '16px'
	}
	arrow_overrides[inline_end_inset_property(host_computed)] = '0'
	arrow_style := computed_style_with_overrides(host_computed, arrow_overrides)
	mut arrow := unsafe {
		&Node(BlockContainer.new(document, arrow_element.as_node(), arrow_style))
	}
	mut svg_element := document.create_element_ns('http://www.w3.org/2000/svg', 'svg') or {
		return []
	}
	svg_element.set_attribute_value('viewBox', '0 0 24 24')
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
	path_element.set_attribute_value('fill', 'currentcolor')
	path_data := 'M7.41,8.58L12,13.17L16.59,8.58L18,10L12,16L6,10L7.41,8.58Z'
	path_element.set_attribute_value('d', path_data)
	path_style := computed_style_with_overrides(host_computed, {
		css.PropertyID.display: 'inline'
		css.PropertyID.d:       'path("${path_data}")'
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
		css.PropertyID.display: 'flex'
	})
	mut outer := unsafe {
		&Node(Box.new(document, outer_element.as_node(), outer_style))
	}
	inner_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		return []
	}
	inner_style := computed_style_with_overrides(outer_style, {
		css.PropertyID.display: 'block'
		css.PropertyID.width:   '100%'
	})
	mut inner := unsafe { &Node(BlockContainer.new(document, inner_element.as_node(), inner_style)) }
	text := document.create_text_node(value)
	mut text_layout_node := TextNode.new(document, text.as_node(), value)
	text_layout_node.is_empty_editable_ = true
	text_layout_node.update_produces_line_box_fragment_when_empty_flag()
	inner.append_child(unsafe { &Node(text_layout_node) })
	inner.set_children_are_inline(true)
	outer.append_child(inner)
	if placeholder_is_visible {
		placeholder_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
			return []
		}
		placeholder_base := static_control_placeholder_style(document, element, host_computed)
		mut placeholder_overrides := {
			css.PropertyID.display:    'block'
			css.PropertyID.width:      '100%'
			css.PropertyID.overflow_x: 'hidden'
			css.PropertyID.overflow_y: 'hidden'
			css.PropertyID.pointer_events: 'none'
			css.PropertyID.user_select:    'none'
		}
		placeholder_overrides[inline_start_margin_property(placeholder_base)] = '-100%'
		placeholder_style := computed_style_with_overrides(placeholder_base, placeholder_overrides)
		mut placeholder_node := unsafe {
			&Node(BlockContainer.new(document, placeholder_element.as_node(), placeholder_style))
		}
		placeholder_text := document.create_text_node(placeholder)
		placeholder_node.append_child(unsafe {
			&Node(TextNode.new(document, placeholder_text.as_node(), placeholder))
		})
		placeholder_node.set_children_are_inline(true)
		outer.append_child(placeholder_node)
	}
	outer.set_children_are_inline(false)
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
	content_style := parent_style.computed_values().clone_for_button_content_box(content_display)
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
	if !node.is_fieldset_box() {
		return
	}
	fieldset := unsafe { &FieldSetBox(node) }
	legend := fieldset.rendered_legend()
	mut fieldset_style := node.as_node_with_style() or { return }
	mut fieldset_computed := unsafe { &css.ComputedProperties(fieldset_style.computed_values_) }
	if legend == none && !fieldset_computed.display().is_flex_inside() {
		return
	}
	content_style := fieldset_computed.take_properties_for_fieldset_content_box()
	fieldset_style.computed_values_ = computed_values_in_layout_coordinates(fieldset_computed, document)
	mut wrapper := unsafe { &Node(BlockContainer.new(document, none, content_style)) }
	wrapper.anonymous_ = true
	mut non_legend_children := []&Node{}
	for child in node.children_.clone() {
		if rendered_legend := legend {
			if layout_nodes_same(child, unsafe { &Node(rendered_legend) }) {
				continue
			}
		}
		non_legend_children << child
	}
	for child in non_legend_children {
		wrapper.append_child(child)
	}
	wrapper.set_children_are_inline(non_legend_children.len > 0 && non_legend_children.all(it.is_inline()))
	if rendered_legend := legend {
		node.replace_children([unsafe { &Node(rendered_legend) }, wrapper])
	} else {
		node.replace_children([wrapper])
	}
	node.set_children_are_inline(false)
}

fn build_generated_pseudo_element(document &dom.Document, element &dom.Element, dom_pseudo dom.PseudoElement, layout_pseudo css.PseudoElement, mut builder_state TreeBuilderState) ?&Node {
	computed := css.computed_properties_for_pseudo_element(element, dom_pseudo) or { return none }
	if computed.display().is_none() {
		return none
	}
	computed_values_in_layout_coordinates(computed, document)
	abstract_element := dom.AbstractElement.new(element, dom_pseudo)
	registered_counter_styles := css.content_counter_styles_for_layout(computed, abstract_element)
	mut content_replacement_source := computed.content_replacement_image(&abstract_element)
	initial_quote_nesting_level := builder_state.quote_nesting_level
	initial_content_result := registered_counter_styles.resolve_content(computed, &abstract_element, initial_quote_nesting_level)
	builder_state.quote_nesting_level = initial_content_result.final_quote_nesting_level
	initial_content := initial_content_result.content_data
	if initial_content.type_ in [.normal, .none_] {
		return none
	}
	resolve_layout_counters(mut builder_state, abstract_element, computed)
	content := registered_counter_styles.resolve_content(computed, &abstract_element, initial_quote_nesting_level).content_data
	mut mutable_computed := unsafe { &css.MutableComputedValues(computed) }
	mutable_computed.set_content(content)
	if computed.display().is_list_item() || computed.display().is_contents() {
		content_replacement_source = none
	}
	mut generated_style := computed
	if content_replacement_source != none {
		if adjusted_display := adjusted_display_for_replaced_element(computed.display()) {
			generated_style = computed.clone_for_anonymous_with_display(adjusted_display)
		}
	} else if computed.display().is_contents() {
		// Generated contents remain as an inline grouping node so their content
		// participates in the host's inline formatting context.
		generated_style = computed.clone_for_anonymous_with_display(css.Display.from_short(.inline_))
	}
	mut node := if source := content_replacement_source {
		unsafe { &Node(ImageBox.new_generated_for_content_item(document, generated_style, source)) }
	} else {
		create_layout_node_for_generated_content(document, generated_style)
	}
	node.set_generated_for(layout_pseudo, element)
	node.initial_quote_nesting_level_ = initial_quote_nesting_level
	if content.type_ == .list && node.can_have_children() {
		mut generated_children := []&Node{}
		// An empty generated text node carries the inline fragment of an
		// ordinary inline pseudo-element. Other pseudo-element boxes exist
		// independently of their contents, so they get no zero-length child
		// that would make layout measure an otherwise empty box.
		keeps_empty_text := node.display().is_inline_outside() && node.display().is_flow_inside()
		if content.items.len > 0 {
			inline_image_style := computed.clone_for_anonymous_with_display(css.Display.from_short(.inline_))
			for item in content.items {
				if item.type_ != .image && item.value.len == 0 && !keeps_empty_text {
					continue
				}
				mut child := if item.type_ == .image {
					unsafe { &Node(ImageBox.new_generated_for_content_item(document, inline_image_style, item)) }
				} else {
					unsafe { &Node(TextNode.new_generated(document, item.value)) }
				}
				child.set_generated_for(layout_pseudo, element)
				generated_children << child
			}
		} else if content.text.len > 0 || keeps_empty_text {
			generated_text := TextNode.new_generated(document, content.text)
			// Quote controls and counters may leave the resolved content list empty.
			// Keep the layout-tree child used by upstream's tree dump, but only an
			// authored empty string contributes the degenerate inline fragment.
			if content.text.len == 0 {
				mut mutable_text := unsafe { &TextNode(generated_text) }
				mutable_text.retains_empty_generated_fragment_ = false
			}
			mut child := unsafe { &Node(generated_text) }
			child.set_generated_for(layout_pseudo, element)
			generated_children << child
		}
		attach_children_maintaining_inline_invariant(mut node, generated_children, document,
			generated_style)
	}
	if node.is_list_item_box() {
		if marker := build_list_item_marker(document, element, computed, mut builder_state) {
			mut list_item := unsafe { &ListItemBox(node) }
			list_item.set_marker(marker)
			attach_list_item_marker(mut node, marker, document, computed)
		}
	}
	return node
}

fn build_backdrop_pseudo_element(document &dom.Document, element &dom.Element, mut builder_state TreeBuilderState) ?&Node {
	computed := css.computed_properties_for_pseudo_element(element, .backdrop) or { return none }
	if computed.display().is_none() {
		return none
	}
	computed_values_in_layout_coordinates(computed, document)
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
	computed_values_in_layout_coordinates(marker_computed, document)
	abstract_element := dom.AbstractElement.new(element, .marker)
	registered_counter_styles := css.content_counter_styles_for_layout(marker_computed, abstract_element)
	initial_content := registered_counter_styles.resolve_content(marker_computed, &abstract_element, 0).content_data
	if initial_content.type_ == .none_ {
		return none
	}
	list_style_type := list_item_computed.list_style_type_for_scope(css.style_scope_for_abstract_element(dom.AbstractElement.new(element, none)))
	mut mutable_list_item_computed := unsafe { &css.MutableComputedValues(list_item_computed) }
	mutable_list_item_computed.set_list_style_type(list_style_type)
	if initial_content.type_ == .list {
		resolve_marker_layout_counters(mut builder_state, abstract_element, marker_computed)
		content := registered_counter_styles.resolve_content(marker_computed, &abstract_element, 0).content_data
		mut mutable_marker_computed := unsafe { &css.MutableComputedValues(marker_computed) }
		mutable_marker_computed.set_content(content)
		marker_box := ListItemMarkerBox.new(document, list_style_type, list_item_computed.list_style_position(), element, marker_computed)
		mut marker := unsafe { &Node(marker_box) }
		marker.set_generated_for(.marker, element)
		inline_image_style := marker_computed.clone_for_anonymous_with_display(css.Display.from_short(.inline_))
		for item in content.items {
			mut child := if item.type_ == .image {
				unsafe { &Node(ImageBox.new_generated_for_content_item(document, inline_image_style, item)) }
			} else {
				unsafe { &Node(TextNode.new_generated(document, item.value)) }
			}
			child.set_generated_for(.marker, element)
			marker.append_child(child)
		}
		marker.set_children_are_inline(content.items.len > 0)
		return marker
	}
	mut mutable_marker_computed := unsafe { &css.MutableComputedValues(marker_computed) }
	mutable_marker_computed.set_content(initial_content)
	list_style_image := list_item_computed.typed_property_value(.list_style_image)
	has_list_style_image := if image := list_style_image {
		image.is_abstract_image()
	} else {
		false
	}
	if list_style_type.kind == .none_ && !has_list_style_image {
		return none
	}
	marker := ListItemMarkerBox.new(document, list_style_type, list_item_computed.list_style_position(), element, marker_computed)
	mut marker_node := unsafe { &Node(marker) }
	marker_node.set_generated_for(.marker, element)
	marker_node.set_children_are_inline(true)
	if has_list_style_image {
		image_value := list_style_image or { return marker_node }
		if item := css.content_item_for_abstract_image(image_value, document.device_pixels_per_css_pixel()) {
			inline_image_style := marker_computed.clone_for_anonymous_with_display(css.Display.from_short(.inline_))
			mut image := unsafe { &Node(ImageBox.new_generated_for_content_item(document, inline_image_style, item)) }
			image.set_generated_for(.marker, element)
			marker_node.append_child(image)
		}
	} else {
		mut text_node := unsafe { &Node(TextNode.new_generated(document, '')) }
		text_node.set_generated_for(.marker, element)
		marker_node.append_child(text_node)
	}
	return marker_node
}

// Outside markers remain direct, out-of-flow children of the list item. An
// inside marker participates in the principal inline run; if block children
// already selected block-child mode, put the marker in the trailing anonymous
// inline wrapper created by tree fixup.
fn attach_list_item_marker(mut list_item Node, marker &Node, document &dom.Document, list_item_computed &css.ComputedProperties) {
	marker_box := marker.as_list_item_marker_box() or {
		list_item.prepend_child(marker)
		return
	}
	if marker_box.list_style_position() != .inside {
		list_item.prepend_child(marker)
		return
	}
	if list_item.children_are_inline() || !list_item.has_children() {
		list_item.set_children_are_inline(true)
		list_item.prepend_child(marker)
		return
	}
	mut wrapper := last_anonymous_inline_wrapper_or_new(mut list_item, document, list_item_computed,
		false)
	wrapper.append_child(marker)
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

fn create_layout_node_for_display_type(document &dom.Document, element &dom.Element, computed &css.ComputedProperties) &Node {
	display := computed.display()
	if display.is_table_inside() || display.is_table_row_group() || display.is_table_header_group()
		|| display.is_table_footer_group() || display.is_table_row() {
		return unsafe { &Node(Box.new(document, element.as_node(), computed)) }
	}
	if display.is_list_item() {
		return unsafe { &Node(ListItemBox.new(document, element.as_node(), computed)) }
	}
	if display.is_table_cell() || display.is_table_column() || display.is_table_column_group()
		|| display.is_table_caption() || display.is_math_inside() {
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
	if display.is_flow_inside() || display.is_flow_root_inside() || display.is_contents()
		|| display.is_ruby_inside() {
		return unsafe { &Node(BlockContainer.new(document, element.as_node(), computed)) }
	}
	return unsafe { &Node(InlineNode.new(document, element.as_node(), computed)) }
}

struct HTMLInputElementLayoutNodeResult {
	handled bool
	node    ?&Node
}

// HTMLInputElement::create_layout_node(). A result wrapper distinguishes the
// hidden-state null result from the generic display-type fallback.
fn html_input_element_create_layout_node(document &dom.Document, element &dom.Element, computed &css.ComputedProperties) HTMLInputElementLayoutNodeResult {
	type_ := element.get_attribute_value('type').trim_space().to_lower()
	type_state := html.html_input_element_parse_type_attribute(type_)
	if type_state == .hidden {
		return HTMLInputElementLayoutNodeResult{ handled: true }
	}
	if type_state == .image_button {
		model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
		if model.renders_as_alt_text() && element.get_attribute_value('alt') != '' {
			return HTMLInputElementLayoutNodeResult{
				handled: true
				node: create_layout_node_for_display_type(document, element, computed)
			}
		}
		return HTMLInputElementLayoutNodeResult{
			handled: true
			node: unsafe { &Node(ImageBox.new(document, element, computed)) }
		}
	}
	if computed.appearance() == .none_ {
		// Blink retains text-control sizing when authors suppress the theme.
		// A generic box loses the definite clamped height supplied to the editor
		// and its percentage-sized placeholder wrapper.
		if document.font_rendering_policy() == .chromium
			&& type_state in [.text, .search, .telephone, .url, .email, .password, .date,
				.month, .week, .time, .local_date_and_time, .number] {
			return HTMLInputElementLayoutNodeResult{
				handled: true
				node: unsafe { &Node(TextInputBox.new(document, element, computed)) }
			}
		}
		return HTMLInputElementLayoutNodeResult{}
	}
	if type_state == .checkbox {
		return HTMLInputElementLayoutNodeResult{
			handled: true
			node: unsafe { &Node(CheckBox.new(document, element, computed)) }
		}
	}
	if type_state == .radio_button {
		return HTMLInputElementLayoutNodeResult{
			handled: true
			node: unsafe { &Node(RadioButton.new(document, element, computed)) }
		}
	}
	if type_state == .range {
		return HTMLInputElementLayoutNodeResult{
			handled: true
			node: unsafe { &Node(RangeInputBox.new(document, element, computed)) }
		}
	}
	if type_state in [.submit_button, .button, .reset_button] {
		return HTMLInputElementLayoutNodeResult{
			handled: true
			node: unsafe { &Node(BlockContainer.new(document, element.as_node(), computed)) }
		}
	}
	if type_state in [.color, .file_upload] {
		return HTMLInputElementLayoutNodeResult{}
	}
	return HTMLInputElementLayoutNodeResult{
		handled: true
		node: unsafe { &Node(TextInputBox.new(document, element, computed)) }
	}
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
	model := html.html_image_element_model_for_dom_element(element)
	if model.renders_as_alt_text() && dom_element.get_attribute_value('alt') != '' {
		return create_layout_node_for_display_type(document, dom_element, computed)
	}
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

// SVG graphics require an enclosing SVG viewport. foreignObject switches its
// descendants to the CSS box model, so SVG-namespace children below that
// boundary stay suppressed until a nested <svg> establishes a new viewport.
fn svg_element_has_rendering_context(element &dom.Element) bool {
	if element.local_name() == 'svg' {
		return true
	}
	mut ancestor := element.as_node().parent_or_shadow_host()
	for ancestor != none {
		current := ancestor or { break }
		if candidate := current.as_element() {
			if candidate.is_svg_element() && candidate.local_name() == 'foreignObject' {
				return false
			}
			if candidate.is_svg_element() && candidate.local_name() == 'svg' {
				return true
			}
		}
		ancestor = current.parent_or_shadow_host()
	}
	return false
}

fn create_layout_node_for_element(document &dom.Document, element &dom.Element, computed &css.ComputedProperties) ?&Node {
	display := computed.display()
	if display.is_none() {
		return none
	}
	if element.is_svg_element() {
		if !svg_element_has_rendering_context(element) {
			return none
		}
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
	return create_layout_node_for_display_type(document, element, computed)
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
	if tag_name in ['g', 'a', 'use', 'switch'] {
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
	// SVG animation elements inherit SVGElement::create_layout_node(), which
	// returns no box. Their text stays in the DOM but is never rendered.
	if tag_name in ['animate', 'animateMotion', 'animateTransform', 'set'] {
		return none
	}
	if tag_name == 'symbol' {
		if element.is_direct_child_of_svg_use_shadow_tree() {
			return unsafe { &Node(SVGGraphicsBox.new(document, element, computed)) }
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
			// Out-of-flow children do not select the parent's inline/block mode.
			continue
		}
		if child_is_inline_level(child) {
			any_inline = true
		} else {
			any_block = true
		}
	}
	force_inline_wrappers := parent.is_fieldset_box() || parent.is_svg_foreign_object_box() || parent.display().is_flex_inside() || parent.display().is_grid_inside()
	// Inline flow boxes retain their in-flow block children. Their inline
	// formatting context force-breaks around those interrupting blocks.
	if parent.is_inline_node() && parent.display().is_inline_outside() && parent.display().is_flow_inside() {
		parent.set_children_are_inline(true)
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
			mut wrapper := last_anonymous_inline_wrapper_or_new(mut parent, document, parent_computed,
				force_inline_wrappers)
			wrapper.append_child(child)
		} else if child.is_out_of_flow() && !parent.display().is_flex_inside() && !parent.display().is_grid_inside() {
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
				mut wrapper := last_anonymous_inline_wrapper_or_new(mut parent, document, parent_computed,
					force_inline_wrappers)
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
fn last_anonymous_inline_wrapper_or_new(mut parent Node, document &dom.Document, parent_computed &css.ComputedProperties, wraps_every_inline_run bool) &Node {
	if last := parent.last_child() {
		if last.is_anonymous() && last.children_are_inline() {
			return last
		}
	}
	// NodeWithStyle::create_anonymous_wrapper(): CSS 2.2 9.2.1.1 creates an
	// anonymous block box, but an inline-block establishes a BFC (9.4.1). The
	// first wrapper of a childless inline-block is itself an inline-block so it
	// participates correctly in that inline-block's inline formatting context.
	// Upstream creates a wrapper around a childless parent only on the paths
	// that wrap every inline run (fieldsets, foreignObject, flex and grid); an
	// ordinary mixed-content wrapper is created once a block child arrives.
	wraps_inline_block := wraps_every_inline_run && parent.display().is_inline_block()
		&& parent.first_child() == none
	mut wrapper := create_anonymous_block_wrapper(document, parent_computed)
	if wraps_inline_block {
		if styled := wrapper.as_node_with_style() {
			mut values := unsafe { &css.MutableComputedValues(styled.computed_values_) }
			values.set_display(css.Display.from_short(.inline_block))
		}
	}
	parent.append_child(wrapper)
	return wrapper
}

// NodeWithStyle::create_anonymous_wrapper — an anonymous block box with the
// parent's inherited values and initial non-inherited values.
fn create_anonymous_block_wrapper(document &dom.Document, parent_computed &css.ComputedProperties) &Node {
	// Mixed-content insertion receives the element's CSS-pixel style, while
	// its real block children already use layout coordinates. Inherit from
	// that same projection so an unwrapped text run keeps the physical font.
	parent_values := computed_values_in_layout_coordinates(parent_computed, document)
	anonymous_values := css.resolve_anonymous_block_values_for_document(parent_values, document)
	mut wrapper := BlockContainer.with_resolved_values(document, none, anonymous_values)
	wrapper.anonymous_ = true
	wrapper.children_are_inline_ = true
	return unsafe { &Node(wrapper) }
}
