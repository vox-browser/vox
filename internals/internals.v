// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Internals.cpp/.h. PageClient operations become observable
// PlatformState changes and typed input actions at the embedder boundary.
module internals

import aria
import bindings
import compositor
import css
import dom
import dump as tree_dump
import gamepad
import html
import loader
import layout
import page
import painting
import xhr
import x.json2

pub const mod_none = u16(0)
pub const mod_alt = u16(1)
pub const mod_ctrl = u16(2)
pub const mod_shift = u16(4)
pub const mod_super = u16(8)
pub const mod_platform_ctrl = mod_ctrl | mod_super
pub const mod_keypad = u16(16)
pub const button_left = u16(0)
pub const button_middle = u16(1)
pub const button_right = u16(2)

pub fn wheel_delta_precision_from(precise bool) WheelDeltaPrecision {
	return if precise { .precise } else { .coarse }
}

pub fn scroll_gesture_phase_from(phase ScrollGesturePhase) ScrollGesturePhase {
	return phase
}

pub struct ReferenceLink {
pub:
	relation string
	href     string
}

pub struct FuzzyMetadata {
pub:
	reference string
	content   string
}

pub struct DocumentMetadata {
pub:
	references []ReferenceLink
	fuzzy      []FuzzyMetadata
	variants   []string
}

pub struct HitTestObject {
pub:
	node          ?&dom.Node
	index_in_node int
}

pub struct ContextMenuRequestObject {
pub:
	kind   string
	target &dom.Node = unsafe { nil }
}

@[heap]
pub struct Internals {
	InternalsBase
pub:
	navigator &gamepad.NavigatorGamepadPartial
pub mut:
	gamepads_        []&InternalGamepad
	next_gamepad_id_ int = 1
}

pub fn Internals.create(platform &PlatformState, navigator &gamepad.NavigatorGamepadPartial) &Internals {
	return &Internals{
		InternalsBase: InternalsBase.new(platform)
		navigator: navigator
	}
}

pub fn (mut api Internals) signal_test_is_done(text string) {
	api.perform_per_test_cleanup()
	api.platform.test_done_text = text
}

pub fn (mut api Internals) set_test_timeout(milliseconds f64) {
	api.platform.test_timeout_ms = milliseconds
}

pub fn (mut api Internals) force_incompatible_visual_context_tree_rebuild() {
	api.platform.visual_context_force_rebuilds++
}

pub fn (api &Internals) accumulated_visual_context_incremental_update_count() u64 {
	return api.platform.visual_context_incremental_update_count
}

pub fn (api &Internals) visual_context_pending_dirty_box_count() u64 {
	return api.platform.visual_context_pending_dirty_box_count
}

pub fn (api &Internals) layout_tree_pre_order_label_violation_count() u64 {
	return api.platform.layout_tree_pre_order_label_violation_count
}

pub fn (api &Internals) layout_tree_pre_order_relabel_count() u64 {
	return api.platform.layout_tree_pre_order_relabel_count
}

pub fn (api &Internals) visual_context_tree_node_count() u64 {
	return api.platform.visual_context_tree_node_count
}

pub fn (api &Internals) visual_context_tree_dead_node_count() u64 {
	return api.platform.visual_context_tree_dead_node_count
}

pub fn (api &Internals) visual_context_tree_structural_epoch() u64 {
	return api.platform.visual_context_tree_structural_epoch
}

pub fn (api &Internals) visual_context_tree_node_capacity() u64 {
	return api.platform.visual_context_tree_node_capacity
}

pub fn (api &Internals) visual_context_node_indices(element &dom.Element) VisualContextNodeIndices {
	return api.platform.visual_context_node_indices_[element.as_node().unique_id().value()] or {
		VisualContextNodeIndices{}
	}
}

pub fn (mut api Internals) set_force_dark_enabled(enabled bool) {
	api.platform.force_dark_enabled = enabled
}

pub fn (mut api Internals) set_show_line_box_borders(enabled bool) {
	api.platform.show_line_box_borders = enabled
}

pub fn (mut api Internals) set_force_dark_thresholds(foreground i32, background i32) {
	api.platform.force_dark_foreground = foreground
	api.platform.force_dark_background = background
}

pub fn (mut api Internals) send_mismatched_visual_context_tree_update_to_compositor() {
	api.platform.mismatched_visual_context_updates++
}

fn json_escape(value string) string {
	return value.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n')
}

pub fn (mut api Internals) load_reference_test_metadata(metadata DocumentMetadata) {
	mut matches := []string{}
	mut mismatches := []string{}
	for reference in metadata.references {
		encoded := '"${json_escape(reference.href)}"'
		if reference.relation == 'match' { matches << encoded }
		if reference.relation == 'mismatch' { mismatches << encoded }
	}
	mut fuzzy := []string{}
	for value in metadata.fuzzy {
		prefix := if value.reference.len > 0 {
			'"reference":"${json_escape(value.reference)}",'
		} else {
			''
		}
		fuzzy << '{${prefix}"content":"${json_escape(value.content)}"}'
	}
	api.platform.ref_metadata_json = '{"match_references":[${matches.join(',')}],"mismatch_references":[${mismatches.join(',')}],"fuzzy":[${fuzzy.join(',')}]}'
}

pub fn (mut api Internals) load_test_variants(metadata DocumentMetadata) {
	values := metadata.variants.map('"${json_escape(it)}"')
	api.platform.test_variants_json = '[${values.join(',')}]'
}

pub fn (mut api Internals) set_time_zone(time_zone string) !string {
	if time_zone.len == 0 {
		return error('Could not set time zone: empty identifier')
	}
	previous := api.platform.time_zone
	api.platform.time_zone = time_zone
	return previous
}

pub fn (mut api Internals) gc() {
	api.platform.garbage_collections++
}

pub fn (api &Internals) gc_async(promise &dom.Promise) {
	platform_pointer := api.platform
	promise_pointer := promise
	html.queue_a_task(.unspecified, html.main_thread_event_loop(), none, fn [platform_pointer, promise_pointer] () {
		mut platform := unsafe { &PlatformState(platform_pointer) }
		platform.garbage_collections++
		mut mutable_promise := unsafe { &dom.Promise(promise_pointer) }
		mutable_promise.resolve(dom.js_undefined())
	})
}

pub fn (mut api Internals) mark_as_garbage(variable_name string) ! {
	value := api.platform.javascript_bindings[variable_name] or {
		return error('ReferenceError: unknown identifier ${variable_name}')
	}
	if value.kind != .object {
		return error('TypeError: value cannot be held weakly')
	}
	api.platform.javascript_bindings.delete(variable_name)
	api.platform.garbage_binding_names << variable_name
}

pub fn (api &Internals) has_completed_initial_paint() bool {
	if document := api.platform.associated_document {
		return css.css_style_computer_for(document).font_computer().has_completed_initial_paint()
	}
	return api.platform.has_completed_initial_paint_
}

pub fn (api &Internals) initial_paint_had_pending_fonts() bool {
	if document := api.platform.associated_document {
		return css.css_style_computer_for(document).font_computer().initial_paint_had_pending_fonts()
	}
	return api.platform.initial_paint_had_pending_fonts_
}

pub fn (api &Internals) set_font_display_time(font_face &css.FontFaceObject, milliseconds u32) {
	mut mutable_font_face := unsafe { &css.FontFaceObject(font_face) }
	mutable_font_face.set_font_display_time_for_testing(milliseconds)
}

pub fn (api &Internals) wrapper_is_preserved(object &bindings.PlatformObject) bool {
	return bindings.wrapper_is_preserved(object)
}

pub interface ActivityRootObject {
	has_activity_root() bool
}

pub fn (api &Internals) has_activity_root(object ActivityRootObject) bool {
	return object.has_activity_root()
}

pub fn (api &Internals) create_xml_http_request_for_document(document &dom.Document) &xhr.XMLHttpRequest {
	return xhr.XMLHttpRequest.create(&xhr.XMLHttpRequestGlobal{
		kind: .window
		base_url: document.base_url().serialize()
		origin: document.origin()
		associated_document: document
	})
}

pub fn dump_string_to_utf16(value string) string {
	// V strings retain the UTF-8 scalar sequence; WebIDL performs the UTF-16
	// conversion when the value crosses the binding boundary.
	return value
}

pub fn (api &Internals) dump_accessibility_tree() string {
	return dump_string_to_utf16(api.platform.accessibility_tree_dump)
}

fn session_history_json_int(object map[string]json2.Any, name string) ?int {
	value := object[name] or { return none }
	return match value {
		int { value }
		i64 { int(value) }
		i32 { int(value) }
		u64 { int(value) }
		u32 { int(value) }
		f64 { int(value) }
		f32 { int(value) }
		else { none }
	}
}

fn session_history_json_array(object map[string]json2.Any, name string) ?[]json2.Any {
	value := object[name] or { return none }
	if value is []json2.Any {
		return value
	}
	return none
}

fn find_session_history_entries(entries []json2.Any, navigable_id string) ?[]json2.Any {
	for value in entries {
		if value !is map[string]json2.Any {
			continue
		}
		entry := value as map[string]json2.Any
		nested_histories := session_history_json_array(entry, 'nestedHistories') or { continue }
		for nested_value in nested_histories {
			if nested_value !is map[string]json2.Any {
				continue
			}
			nested := nested_value as map[string]json2.Any
			nested_entries := session_history_json_array(nested, 'entries') or { continue }
			if id_value := nested['id'] {
				if id_value is string && id_value == navigable_id {
					return nested_entries
				}
			}
			if result := find_session_history_entries(nested_entries, navigable_id) {
				return result
			}
		}
	}
	return none
}

pub fn (api &Internals) dump_session_history() string {
	if api.platform.ui_process_session_history == '' {
		return '(no navigable)'
	}
	parsed := json2.decode[json2.Any](api.platform.ui_process_session_history) or {
		return '(invalid UI process session history)'
	}
	if parsed !is map[string]json2.Any {
		return '(invalid UI process session history)'
	}
	history := parsed as map[string]json2.Any
	top_level_entries := session_history_json_array(history, 'entries') or {
		return '(invalid UI process session history)'
	}
	used_steps := session_history_json_array(history, 'usedSteps') or {
		return '(invalid UI process session history)'
	}
	mut current_step := ?int(none)
	for value in used_steps {
		if value is map[string]json2.Any {
			step := value as map[string]json2.Any
			current_value := step['current'] or { continue }
			if current_value is bool && current_value {
				current_step = session_history_json_int(step, 'step')
				break
			}
		}
	}
	entries := if api.platform.session_history_navigable_id == '' {
		top_level_entries
	} else {
		find_session_history_entries(top_level_entries, api.platform.session_history_navigable_id) or {
			return '(no canonical session history entries)'
		}
	}
	mut minimum_step := ?int(none)
	for value in entries {
		if value is map[string]json2.Any {
			if step := session_history_json_int(value as map[string]json2.Any, 'step') {
				if minimum := minimum_step {
					if step < minimum {
						minimum_step = step
					}
				} else {
					minimum_step = step
				}
			}
		}
	}
	mut lines := []string{}
	for value in entries {
		if value !is map[string]json2.Any {
			continue
		}
		entry := value as map[string]json2.Any
		step := session_history_json_int(entry, 'step') or { continue }
		url_value := entry['url'] or { continue }
		if url_value !is string {
			continue
		}
		serialized_url := url_value as string
		url := parse_absolute_url(serialized_url) or { continue }
		mut display := url.basename()
		if query := url.query() {
			display += '?${query}'
		}
		if fragment := url.fragment() {
			display += '#${fragment}'
		}
		relative_step := if minimum := minimum_step { '${step - minimum}' } else { 'pending' }
		current_suffix := if current := current_step {
			if current == step { ' (current)' } else { '' }
		} else {
			''
		}
		lines << '  step ${relative_step} ${display}${current_suffix}\n'
	}
	return dump_string_to_utf16(lines.join(''))
}

pub fn (api &Internals) dump_ui_process_session_history() string {
	return dump_string_to_utf16(api.platform.ui_process_session_history)
}

pub fn (api &Internals) dump_ui_process_session_history_without_update() string {
	return dump_string_to_utf16(api.platform.ui_process_session_history)
}

pub fn (mut api Internals) capture_session_history_snapshot() bool {
	if api.platform.capture_session_history_snapshot_result {
		api.platform.captured_session_history = api.platform.ui_process_session_history
	}
	return api.platform.capture_session_history_snapshot_result
}

pub fn (mut api Internals) restore_captured_session_history_snapshot() bool {
	if api.platform.restore_session_history_snapshot_result
		&& api.platform.captured_session_history != '' {
		api.platform.ui_process_session_history = api.platform.captured_session_history
	}
	return api.platform.restore_session_history_snapshot_result
}

pub fn (api &Internals) register_session_store_tab() bool {
	return api.platform.register_session_store_tab_result
}

pub fn (api &Internals) dump_session_store_tab_state() string {
	return dump_string_to_utf16(api.platform.session_store_tab_state)
}

pub fn (api &Internals) dump_site_isolation_process_tree() string {
	return dump_string_to_utf16(api.platform.site_isolation_process_tree)
}

pub fn (mut api Internals) crash_remote_frame_processes() {
	api.platform.remote_frame_process_crashes++
}

pub fn (mut api Internals) flush_session_history_traversal_queue() &dom.Promise {
	api.platform.session_history_traversal_queue_flushes++
	return dom.Promise.resolved(dom.js_undefined())
}

pub fn (api &Internals) parser_non_append_insertions() u64 {
	return html.parser_non_append_insertions()
}

pub fn (api &Internals) media_element_is_fetching(element &html.HTMLMediaElement) bool {
	return element.is_fetching()
}

pub fn (api &Internals) media_element_is_playing_audio(element &html.HTMLMediaElement) bool {
	return element.is_playing_audio()
}

pub fn (api &Internals) media_element_video_sink_is_ticking(element &html.HTMLMediaElement) bool {
	return element.video_sink_is_ticking()
}

pub fn (api &Internals) set_media_element_ready_state(element &html.HTMLMediaElement, ready_state u16) {
	if ready_state > u16(html.MediaReadyState.have_enough_data) {
		return
	}
	mut mutable_element := unsafe { &html.HTMLMediaElement(element) }
	state := unsafe { html.MediaReadyState(ready_state) }
	mutable_element.set_ready_state(state)
}

pub fn (api &Internals) set_media_element_paused(element &html.HTMLMediaElement, paused bool) {
	mut mutable_element := unsafe { &html.HTMLMediaElement(element) }
	mutable_element.set_paused(paused)
}

pub fn (api &Internals) set_media_element_seeking(element &html.HTMLMediaElement, seeking bool) {
	mut mutable_element := unsafe { &html.HTMLMediaElement(element) }
	mutable_element.set_seeking(seeking)
}

pub fn (mut api Internals) set_page_muted(muted bool) {
	api.platform.page_muted = muted
	for element in api.platform.page_media_elements {
		mut mutable_element := unsafe { &html.HTMLMediaElement(element) }
		mutable_element.set_page_muted(muted)
	}
}

pub fn (mut api Internals) set_geolocation_emulated_position(latitude f64, longitude f64, accuracy f64) {
	api.platform.geolocation_emulated_position = html.EmulatedPositionData{
		latitude: latitude
		longitude: longitude
		accuracy: accuracy
	}
}

pub fn (api &Internals) get_rendering_scheduler_counters() html.RenderingSchedulerCounters {
	return html.main_thread_event_loop().rendering_scheduler_counters()
}

pub fn (api &Internals) reset_rendering_scheduler_counters() {
	mut event_loop := html.main_thread_event_loop()
	event_loop.reset_rendering_scheduler_counters()
}

pub fn (mut api Internals) set_manual_rendering_opportunities(enabled bool) {
	api.platform.manual_rendering_opportunities = enabled
}

pub fn (mut api Internals) inject_rendering_opportunity(frame_time_ms f64) {
	api.platform.last_injected_rendering_opportunity_ms = frame_time_ms
	mut event_loop := html.main_thread_event_loop()
	event_loop.rendering_opportunity(frame_time_ms, false)
}

pub fn (mut api Internals) update_compositor_animations() {
	api.platform.compositor_animation_updates++
}

pub fn (api &Internals) run_empty_animation_style_update_for_testing() bool {
	return api.platform.empty_animation_style_update_result
}

pub fn (mut api Internals) arm_compositor_animation_timers_for_testing() {
	api.platform.compositor_animation_timer_arms++
}

pub fn (mut api Internals) fire_compositor_animation_wakeup_for_testing(frame_time_ms f64) {
	api.platform.compositor_animation_wakeup_frame_time_ms = frame_time_ms
}

pub fn (mut api Internals) force_visual_context_tree_rebuild_on_next_compositor_animation_update_for_testing() {
	api.platform.force_visual_context_rebuild_on_animation = true
}

pub fn (mut api Internals) request_reentrant_animation_style_flush_for_testing(node &dom.Node) {
	api.platform.reentrant_animation_style_flush_node = node
}

pub fn (api &Internals) layout_tree_build_stats() LayoutTreeBuildStats {
	return api.platform.layout_tree_build_stats_
}

pub fn (api &Internals) compare_layout_tree_with_full_rebuild() LayoutTreeComparison {
	incremental := api.platform.incremental_layout_tree_dump
	full := api.platform.full_rebuild_layout_tree_dump
	return LayoutTreeComparison{
		matches: incremental == full
		incremental: if incremental == full { '' } else { incremental }
		full: if incremental == full { '' } else { full }
	}
}

pub fn (api &Internals) style_ffi_counters() map[string]u64 {
	return api.platform.style_ffi_counters_.clone()
}

pub fn (api &Internals) style_engine_counters() map[string]u64 {
	return api.platform.style_engine_counters_.clone()
}

fn computed_style_record_identity(style &dom.CSSComputedProperties_) u64 {
	if style.css_handle != unsafe { nil } {
		return u64(style.css_handle)
	}
	return u64(voidptr(style))
}

pub fn (api &Internals) style_record_identity(element &dom.Element) u64 {
	style := element.el_computed_properties() or { return 0 }
	return computed_style_record_identity(style)
}

pub fn (api &Internals) layout_style_record_identity(element &dom.Element) u64 {
	layout_node := element.el_layout_node() or { return 0 }
	style := layout_node.applied_properties_ or { return 0 }
	return computed_style_record_identity(style)
}

pub fn (api &Internals) before_style_record_identity(element &dom.Element) u64 {
	style := element.computed_properties_for_pseudo(int(dom.PseudoElement.before)) or { return 0 }
	return computed_style_record_identity(style)
}

pub fn (api &Internals) before_layout_style_record_identity(element &dom.Element) u64 {
	layout_node := element.get_pseudo_element_node(int(dom.PseudoElement.before)) or { return 0 }
	style := layout_node.applied_properties_ or { return 0 }
	return computed_style_record_identity(style)
}

pub fn (api &Internals) paint_style_record_identity(element &dom.Element) u64 {
	if element.paintable_box() == none {
		return 0
	}
	return api.layout_style_record_identity(element)
}

pub fn (api &Internals) layout_node_identity(node &dom.Node) u64 {
	layout_node := node.layout_node() or { return 0 }
	return u64(voidptr(layout_node))
}

fn count_layout_arena_nodes(node &dom.LayoutNode) (u64, u64) {
	mut live := u64(1)
	mut shells := if node.dom_node_ == none { u64(1) } else { u64(0) }
	for child in node.children_ {
		child_live, child_shells := count_layout_arena_nodes(child)
		live += child_live
		shells += child_shells
	}
	return live, shells
}

fn layout_arena_counts(document &dom.Document) (u64, u64) {
	viewport := document.layout_node() or { return u64(0), u64(0) }
	root := viewport.root_layout_node() or { return u64(0), u64(0) }
	return count_layout_arena_nodes(root)
}

pub fn (api &Internals) layout_arena_live_slot_count() u64 {
	document := api.platform.associated_document or { return 0 }
	live, _ := layout_arena_counts(document)
	return live
}

pub fn (api &Internals) layout_arena_shell_count() u64 {
	document := api.platform.associated_document or { return 0 }
	_, shells := layout_arena_counts(document)
	return shells
}

pub fn (api &Internals) style_engine_transaction_reactions() StyleEngineTransactionReactions {
	return api.platform.style_engine_transaction_reactions_
}

pub fn (api &Internals) style_engine_match_document() f64 {
	return api.platform.style_engine_document_match_count
}

pub fn collect_style_engine_rule_names(rules []&css.CSSRule, mut names map[u64]string) {
	for rule in rules {
		identity := u64(voidptr(rule))
		names[identity] = if rule.type_ == .style {
			rule.selector_text()
		} else {
			'<rule ${identity}>'
		}
		if nested := rule.css_rules() {
			collect_style_engine_rule_names(nested.rules, mut names)
		}
		if imported := rule.loaded_style_sheet_for_bindings() {
			collect_style_engine_rule_names(imported.css_rules().rules, mut names)
		}
	}
}

pub fn (api &Internals) style_engine_matched_rules() string {
	return api.platform.style_engine_matched_rules_dump
}

pub fn (mut api Internals) reset_style_ffi_counters() {
	api.platform.style_ffi_counters_enabled = true
	api.platform.style_ffi_counters_.clear()
}

pub fn (api &Internals) style_group_sharing_info(element &dom.Element) map[string]StyleGroupSharingState {
	style := element.el_computed_properties() or { return map[string]StyleGroupSharingState{} }
	mut parent_style := ?&dom.CSSComputedProperties_(none)
	if parent := element.parent_element() {
		parent_style = parent.el_computed_properties()
	}
	return {
		'computedValues': StyleGroupSharingState{
			shared_with_parent: if parent := parent_style {
				computed_style_record_identity(parent) == computed_style_record_identity(style)
			} else {
				false
			}
			is_default: style.css_handle == unsafe { nil }
		}
	}
}

pub fn (api &Internals) computed_values_stats() css.ComputedValuesStatistics {
	return css.computed_values_statistics()
}

pub fn (mut api Internals) update_style() {
	if document := api.platform.associated_document {
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.update_style()
	}
	api.platform.style_update_requests++
}

fn create_hit_testing_result(result dom.HitTestResult) HitTestObject {
	return HitTestObject{
		node: result.node
		index_in_node: result.index_in_node
	}
}

pub fn (api &Internals) hit_test(x f64, y f64) ?HitTestObject {
	if document := api.platform.associated_document {
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.update_layout(.internals_hit_test)
		if paintable := document.paintable_box() {
			if result := paintable.hit_test(x, y, .exact) {
				return create_hit_testing_result(result)
			}
		}
	}
	result := api.platform.hit_test_result or { return none }
	return HitTestObject{
		node: result.node
		index_in_node: result.index_in_node
	}
}

pub fn (api &Internals) hit_test_result(x f64, y f64) ?HitTestObject {
	return api.hit_test(x, y)
}

fn context_menu_kind_to_string(kind page.ContextMenuRequestKind) string {
	return match kind {
		.page { 'page' }
		.image { 'image' }
		.link { 'link' }
		.media { 'media' }
	}
}

pub fn (api &Internals) take_context_menu_request() ?ContextMenuRequestObject {
	document := api.platform.associated_document or { return none }
	dom_page := document.page()
	if dom_page == unsafe { nil } || dom_page.target == unsafe { nil } {
		return none
	}
	mut page_model := unsafe { &page.Page(dom_page.target) }
	request := page_model.take_context_menu_request() or { return none }
	return ContextMenuRequestObject{
		kind: context_menu_kind_to_string(request.kind)
		target: request.target
	}
}

struct WebDriverKeyData {
	key        string
	modifiers  u16
	code_point u32
}

fn webdriver_key_to_key_code(code_point u32) ?WebDriverKeyData {
	return match code_point {
		0xe003 { WebDriverKeyData{'Backspace', 0, 8} }
		0xe004 { WebDriverKeyData{'Tab', 0, 9} }
		0xe006 { WebDriverKeyData{'Return', 0, 10} }
		0xe007 { WebDriverKeyData{'Return', mod_keypad, 10} }
		0xe008 { WebDriverKeyData{'Shift', mod_shift, 0} }
		0xe009 { WebDriverKeyData{'Control', mod_ctrl, 0} }
		0xe00a { WebDriverKeyData{'Alt', mod_alt, 0} }
		0xe00d { WebDriverKeyData{'Space', 0, 32} }
		0xe010 { WebDriverKeyData{'End', 0, 0} }
		0xe011 { WebDriverKeyData{'Home', 0, 0} }
		0xe012 { WebDriverKeyData{'ArrowLeft', 0, 0} }
		0xe013 { WebDriverKeyData{'ArrowUp', 0, 0} }
		0xe014 { WebDriverKeyData{'ArrowRight', 0, 0} }
		0xe015 { WebDriverKeyData{'ArrowDown', 0, 0} }
		0xe017 { WebDriverKeyData{'Delete', 0, 0} }
		0xe03d { WebDriverKeyData{'Meta', mod_super, 0} }
		else { none }
	}
}

pub fn (mut api Internals) send_text(target &dom.Element, value string, modifiers u16) {
	html.HTMLOrSVGElement.create(target).focus()
	for character in value.runes() {
		code_point := u32(character)
		if data := webdriver_key_to_key_code(code_point) {
			api.platform.input_actions << InputAction{
				kind: .key_down
				key: data.key
				modifiers: modifiers | data.modifiers
				code_point: data.code_point
			}
			api.platform.input_actions << InputAction{
				kind: .key_up
				key: data.key
				modifiers: modifiers | data.modifiers
				code_point: data.code_point
			}
		} else {
			api.platform.input_actions << InputAction{
				kind: .key_down
				key: character.str()
				modifiers: modifiers
				code_point: code_point
			}
			api.platform.input_actions << InputAction{
				kind: .key_up
				key: character.str()
				modifiers: modifiers
				code_point: code_point
			}
		}
	}
}

pub fn (mut api Internals) send_key(target &dom.Element, key_name string, modifiers u16, repeat_count u32) {
	if repeat_count == 0 {
		return
	}
	html.HTMLOrSVGElement.create(target).focus()
	for _ in 0 .. repeat_count {
		api.platform.input_actions << InputAction{
			kind: .key_down
			key: key_name
			modifiers: modifiers
		}
	}
	api.platform.input_actions << InputAction{
		kind: .key_up
		key: key_name
		modifiers: modifiers
	}
}

pub fn (mut api Internals) paste(target &dom.Element, text string) {
	html.HTMLOrSVGElement.create(target).focus()
	api.platform.input_actions << InputAction{
		kind: .paste
		text: text
	}
}

pub fn (mut api Internals) paste_from_clipboard() {
	api.platform.input_actions << InputAction{ kind: .paste_from_clipboard }
}

pub fn (mut api Internals) commit_text() {
	api.platform.input_actions << InputAction{
		kind: .commit_text
		code_point: 13
	}
}

pub fn (mut api Internals) mouse_down(x f64, y f64, click_count u16, button u16, modifiers u16) {
	api.platform.input_actions << InputAction{
		kind: .mouse_down
		x: x
		y: y
		click_count: click_count
		button: api.button_from_unsigned_short(button)
		modifiers: modifiers
	}
}

pub fn (mut api Internals) mouse_up(x f64, y f64, button u16, modifiers u16) {
	api.platform.input_actions << InputAction{
		kind: .mouse_up
		x: x
		y: y
		button: api.button_from_unsigned_short(button)
		modifiers: modifiers
	}
}

pub fn (_ &Internals) button_from_unsigned_short(button u16) u16 {
	return match button {
		button_middle { button_middle }
		button_right { button_right }
		else { button_left }
	}
}

pub fn (mut api Internals) mouse_move(x f64, y f64, modifiers u16) {
	api.platform.input_actions << InputAction{
		kind: .mouse_move
		x: x
		y: y
		modifiers: modifiers
	}
}

pub fn (mut api Internals) mouse_leave() {
	api.platform.input_actions << InputAction{ kind: .mouse_leave }
}

pub fn (mut api Internals) click(x f64, y f64, click_count u16, button u16, modifiers u16) {
	api.mouse_down(x, y, click_count, button, modifiers)
	api.mouse_up(x, y, button, modifiers)
}

pub fn (mut api Internals) click_and_hold(x f64, y f64, click_count u16, button u16, modifiers u16) {
	api.mouse_down(x, y, click_count, button, modifiers)
}

pub fn (mut api Internals) wheel(x f64, y f64, delta_x f64, delta_y f64, precise bool, phase ScrollGesturePhase) {
	api.platform.input_actions << InputAction{
		kind: .wheel
		x: x
		y: y
		delta_x: delta_x
		delta_y: delta_y
		precise: wheel_delta_precision_from(precise) == .precise
		gesture: scroll_gesture_phase_from(phase)
	}
}

pub fn (mut api Internals) pinch(x f64, y f64, scale f64, modifiers u16) {
	api.platform.input_actions << InputAction{
		kind: .pinch
		x: x
		y: y
		scale: scale
		modifiers: modifiers
	}
}

pub fn (mut api Internals) reset_zoom() {
	api.platform.browser_zoom = 1
}

pub fn (api &Internals) selected_text_for_clipboard() string {
	return api.platform.selected_text_for_clipboard_
}

pub fn (mut api Internals) set_clipboard_file(name string, mime_type string, data string) {
	api.platform.clipboard_file = ClipboardFile{name, mime_type, data}
}

pub fn (mut api Internals) set_marked_text_from_input_method(text string) {
	api.platform.input_actions << InputAction{ kind: .set_marked_text, text: text }
}

pub fn (mut api Internals) commit_text_from_input_method(text string, replacement_start i32, replacement_length i32) {
	api.platform.input_actions << InputAction{
		kind: .commit_input_method_text
		text: text
		replacement_start: replacement_start
		replacement_length: replacement_length
	}
}

pub fn (mut api Internals) unmark_text_from_input_method() {
	api.platform.input_actions << InputAction{ kind: .unmark_text }
}

pub fn (api &Internals) current_caret_rect() ?dom.Rect {
	return api.platform.current_caret_rect_
}

pub fn (api &Internals) current_cursor() string {
	return api.platform.current_cursor_
}

pub fn (api &Internals) dispatch_user_activated_event(target &dom.EventTarget, event &dom.Event) !bool {
	mut mutable_event := unsafe { &dom.Event(event) }
	mutable_event.set_is_trusted(true)
	return target.dispatch_event(event)
}

fn parse_absolute_url(url string) ?dom.URL {
	colon := url.index_u8(`:`)
	if colon <= 0 || !url[0].is_letter() {
		return none
	}
	for byte in url[1..colon] {
		if !byte.is_alnum() && byte !in [`+`, `-`, `.`] {
			return none
		}
	}
	return dom.dom_url_parse(url, dom.url_about_blank(), 'UTF-8')
}

pub fn (mut api Internals) spoof_current_url(url string) ! {
	parsed := parse_absolute_url(url) or { return error('invalid absolute URL') }
	api.platform.current_url = parsed.serialize()
}

pub fn (mut api Internals) load_url(url string) ! {
	parsed := parse_absolute_url(url) or { return error('Invalid URL') }
	serialized := parsed.serialize()
	api.platform.loaded_urls << serialized
	api.platform.current_url = serialized
}

pub fn (api &Internals) create_internal_animation_timeline() &InternalAnimationTimeline {
	return InternalAnimationTimeline.create()
}

pub fn (mut api Internals) simulate_drag_start(x f64, y f64, mime_type string, contents string) {
	api.platform.input_actions << InputAction{
		kind: .drag_start
		x: x
		y: y
		mime_type: mime_type
		text: contents
	}
}

pub fn (mut api Internals) simulate_drag_move(x f64, y f64) {
	api.platform.input_actions << InputAction{
		kind: .drag_move
		x: x
		y: y
	}
}

pub fn (mut api Internals) simulate_drop(x f64, y f64) {
	api.platform.input_actions << InputAction{
		kind: .drop
		x: x
		y: y
	}
}

pub fn (mut api Internals) expire_cookies_with_time_offset(seconds i64) {
	api.platform.cookie_expiry_offset = seconds
}

pub fn (mut api Internals) delete_all_cookies() &dom.Promise {
	api.platform.cookies.clear()
	return dom.Promise.resolved(dom.js_undefined())
}

fn cookie_domain_matches(cookie PlatformCookie, url dom.URL) bool {
	host := url.serialized_host().trim_right('.').to_lower()
	mut domain := cookie.domain.trim_left('.').trim_right('.').to_lower()
	if domain == '' {
		domain = cookie.url.serialized_host().trim_right('.').to_lower()
	}
	if host == '' || domain == '' {
		return cookie.url.serialize() == url.serialize()
	}
	if cookie.host_only {
		return host == domain
	}
	return host == domain || host.ends_with('.${domain}')
}

fn cookie_path_matches(cookie_path string, request_path string) bool {
	path := if cookie_path.starts_with('/') { cookie_path } else { '/' }
	if request_path == path {
		return true
	}
	if !request_path.starts_with(path) {
		return false
	}
	return path.ends_with('/') || (request_path.len > path.len && request_path[path.len] == `/`)
}

pub fn (api &Internals) has_cookie_for_url(url string, name string, value string) !bool {
	parsed := parse_absolute_url(url) or { return error('Invalid URL: ${url}') }
	for cookie in api.platform.cookies {
		if cookie.name != name || cookie.value != value {
			continue
		}
		if cookie.secure && parsed.scheme() != 'https' {
			continue
		}
		if !cookie_domain_matches(cookie, parsed) {
			continue
		}
		if !cookie_path_matches(cookie.path, parsed.serialize_path()) {
			continue
		}
		return true
	}
	return false
}

pub fn (mut api Internals) set_http_memory_cache_enabled(enabled bool) bool {
	previous := api.platform.http_memory_cache_enabled
	api.platform.http_memory_cache_enabled = enabled
	return previous
}

pub fn (mut api Internals) simulate_request_server_connection_loss() {
	// ResourceLoader's request client is an embedder-owned IPC endpoint. The
	// translated host observes the loss and synchronously installs its replacement.
	api.platform.request_server_connection_losses++
}

pub fn (mut api Internals) simulate_worker_request_server_connection_loss() {
	api.platform.worker_request_server_connection_losses++
}

pub fn (mut api Internals) set_content_blockers(patterns_source string) ! {
	mut lines := []string{}
	for raw_line in patterns_source.split_into_lines() {
		line := raw_line.trim_right('\r')
		if line != '' {
			lines << line
		}
	}
	mut normalized := lines.join('\n')
	if normalized != '' {
		normalized += '\n'
	}
	mut blocker := loader.ContentBlocker.the()
	had_cosmetic_rules := blocker.has_cosmetic_rules()
	blocker.set_rules_from_bytes(normalized.bytes()) or {
		return error('Could not set content blockers: ${err}')
	}
	api.platform.content_blockers_source = normalized
	if had_cosmetic_rules || blocker.has_cosmetic_rules() {
		api.platform.user_style_invalidations++
	}
}

fn internals_resource_loader() &loader.ResourceLoader {
	if !loader.is_initialized() {
		return loader.initialize()
	}
	return loader.ResourceLoader.the()
}

pub fn (mut api Internals) set_site_compatibility_data(source string) ! {
	json := json2.decode[json2.Any](source) or {
		return error('Could not parse site compatibility data')
	}
	data := loader.SiteCompatibilityData.from_json(json) or {
		return error('Could not set site compatibility data: ${err}')
	}
	mut resource_loader := internals_resource_loader()
	resource_loader.set_site_compatibility_data(data)
	api.platform.site_compatibility_source = source
}

pub fn (mut api Internals) set_experimental_interfaces_exposed(exposed bool) {
	html.set_experimental_interfaces_exposed(exposed)
	api.platform.experimental_interfaces_exposed = exposed
}

pub fn (mut api Internals) set_content_blocking_enabled(enabled bool) {
	mut blocker := loader.ContentBlocker.the()
	if blocker.filtering_enabled() == enabled {
		api.platform.content_blocking_enabled = enabled
		return
	}
	has_cosmetic_rules := blocker.has_cosmetic_rules()
	blocker.set_filtering_enabled(enabled)
	api.platform.content_blocking_enabled = enabled
	if has_cosmetic_rules {
		api.platform.user_style_invalidations++
	}
}

pub fn (mut api Internals) set_autoplay_policy(policy string) {
	parsed := html.autoplay_policy_from_string(policy) or { return }
	mut settings := html.AutoplaySettings.the()
	settings.set_policy(parsed, [])
	api.platform.autoplay_policy = policy
}

pub fn (mut api Internals) set_hsts_policy(domain string, max_age u64, include_sub_domains bool) ! {
	url := parse_absolute_url('https://${domain}/') or { return }
	clamped_max_age := if max_age > u64(9223372036854775807) {
		u64(9223372036854775807)
	} else {
		max_age
	}
	mut header := 'max-age=${clamped_max_age}'
	if include_sub_domains {
		header += '; includeSubDomains'
	}
	mut resource_loader := internals_resource_loader()
	resource_loader.try_store_hsts_policy_for_url(url, header)
}

pub fn (mut api Internals) ingest_hsts_header(url string, header_value string) ! {
	parsed := parse_absolute_url(url) or { return }
	mut resource_loader := internals_resource_loader()
	resource_loader.try_store_hsts_policy_for_url(parsed, header_value)
}

pub fn (api &Internals) is_known_hsts_host(domain string) !bool {
	return internals_resource_loader().is_known_hsts_host(domain)
}

pub fn (api &Internals) message_port_pending_outgoing_message_count(port &html.MessagePort) u64 {
	return u64(port.pending_outgoing_message_count())
}

pub fn (api &Internals) html_collection_cache_generation(collection &dom.HTMLCollection) u64 {
	return collection.cache_generation_for_testing()
}

pub fn (api &Internals) fail_next_message_port_transfer(port &html.MessagePort) {
	mut mutable_port := unsafe { &html.MessagePort(port) }
	mutable_port.fail_next_transfer_for_testing()
}

pub fn (api &Internals) message_ports_are_directly_entangled(first &html.MessagePort, second &html.MessagePort) bool {
	first_remote := first.entangled_port() or { return false }
	second_remote := second.entangled_port() or { return false }
	return voidptr(first_remote) == voidptr(second) && voidptr(second_remote) == voidptr(first)
}

fn internals_default_role(element &dom.Element) ?aria.Role {
	if !element.is_html_element() {
		return none
	}
	return match element.local_name() {
		'button', 'summary' {
			aria.Role.button
		}
		'a', 'area' {
			if element.has_attribute('href') {
				aria.Role.link
			} else {
				none
			}
		}
		'h1', 'h2', 'h3', 'h4', 'h5', 'h6' {
			aria.Role.heading
		}
		'th' {
			aria.Role.columnheader
		}
		'td' {
			aria.Role.cell
		}
		'tr' {
			aria.Role.row
		}
		'option' {
			aria.Role.option
		}
		else {
			none
		}
	}
}

fn internals_role_resolver(element &dom.Element) ?aria.Role {
	if value := element.get_attribute('role') {
		for token in value.fields() {
			role := aria.role_from_string(token) or { continue }
			if aria.is_abstract_role(role) {
				continue
			}
			return match role {
				.directory { aria.Role.list }
				.img { aria.Role.image }
				.presentation { aria.Role.none_ }
				else { role }
			}
		}
	}
	return internals_default_role(element)
}

pub fn (api &Internals) get_computed_role(element &dom.Element) string {
	mixin := aria.ARIAMixin.create(element, internals_default_role(element), internals_role_resolver)
	role := mixin.role_or_default() or { return '' }
	return aria.role_name(role)
}

pub fn (api &Internals) get_computed_label(element &dom.Element) string {
	html.install_document_accessibility_role_hook(element.document())
	return element.as_node().accessible_name(element.document(), .yes) or { '' }
}

pub fn (api &Internals) get_computed_aria_level(element &dom.Element) string {
	mixin := aria.ARIAMixin.create(element, internals_default_role(element), internals_role_resolver)
	data := aria.AriaData.from_mixin(mixin)
	level := data.aria_level_or_default() or { return '' }
	return level.str()
}

pub fn (api &Internals) get_style_invalidation_counters() dom.StyleInvalidationCounters {
	document := api.platform.associated_document or { return dom.StyleInvalidationCounters{} }
	return document.style_invalidation_counters()
}

pub fn (mut api Internals) reset_style_invalidation_counters() {
	document := api.platform.associated_document or { return }
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.reset_style_invalidation_counters()
	css.reset_longhand_wrappers_minted()
}

pub struct StyleInvalidationCountersObject {
	dom.StyleInvalidationCounters
pub:
	style_environment_version                        u64
	associated_animations                            uint
	compositor_visual_animations                     uint
	compositor_visual_animation_local_time_at_anchor ?f64
	compositor_visual_animations_share_timing_anchor bool = true
	compositor_visual_animation_targets_are_valid    bool = true
	document_timeline_current_time                   ?f64
	compositor_animation_wakeup_timer_active         bool
	compositor_animation_observation_timer_active    bool
	longhand_wrappers_minted                         u64
}

pub fn (api &Internals) style_invalidation_counters_object() StyleInvalidationCountersObject {
	document := api.platform.associated_document or {
		return StyleInvalidationCountersObject{
			compositor_visual_animation_targets_are_valid: api.platform.compositor_visual_animation_targets_are_valid
		}
	}
	visual_animations := api.platform.compositor_visual_animations
	mut local_time_at_anchor := ?f64(none)
	mut share_timing_anchor := true
	if visual_animations.len > 0 {
		first := visual_animations[0]
		local_time_at_anchor = first.local_time_at_anchor_ms
		for animation in visual_animations[1..] {
			if animation.monotonic_time_at_anchor_ns != first.monotonic_time_at_anchor_ns
				|| animation.local_time_at_anchor_ms != first.local_time_at_anchor_ms {
				share_timing_anchor = false
				break
			}
		}
	}
	associated_animations := document.get_animations() or { []&dom.Animation{} }
	return StyleInvalidationCountersObject{
		StyleInvalidationCounters: document.style_invalidation_counters()
		style_environment_version: document.style_environment_version()
		associated_animations: uint(associated_animations.len)
		compositor_visual_animations: uint(visual_animations.len)
		compositor_visual_animation_local_time_at_anchor: local_time_at_anchor
		compositor_visual_animations_share_timing_anchor: share_timing_anchor
		compositor_visual_animation_targets_are_valid: api.platform.compositor_visual_animation_targets_are_valid
		document_timeline_current_time: api.platform.document_timeline_current_time
		compositor_animation_wakeup_timer_active: api.platform.compositor_animation_wakeup_timer_active
		compositor_animation_observation_timer_active: api.platform.compositor_animation_observation_timer_active
		longhand_wrappers_minted: css.longhand_wrappers_minted()
	}
}

pub fn (api &Internals) has_html_parser_end_state(document &dom.Document) bool {
	return document.has_html_parser_end_state()
}

pub fn (api &Internals) get_echo_server_port() u16 {
	return api.platform.echo_server_port
}

pub fn (mut api Internals) set_echo_server_port(port u16) {
	api.platform.echo_server_port = port
}

pub fn (mut api Internals) set_browser_zoom(factor f64) {
	api.platform.browser_zoom = factor
}

pub fn (mut api Internals) set_device_pixel_ratio(ratio f64) {
	api.platform.device_pixel_ratio = ratio
}

pub fn (api &Internals) headless() bool {
	return api.platform.headless_
}

pub fn (api &Internals) partial_layout_count() u64 {
	return api.platform.partial_layout_count_
}

pub fn (api &Internals) full_layout_count() u64 {
	return api.platform.full_layout_count_
}

pub fn (api &Internals) layout_run_cache_hit_count() u64 {
	return api.platform.layout_run_cache_hit_count_
}

pub fn (api &Internals) table_cell_measurement_cache_miss_count() u64 {
	return api.platform.table_cell_measurement_cache_miss_count_
}

pub fn (api &Internals) intrinsic_measurement_count() u64 {
	return api.platform.intrinsic_measurement_count_
}

pub fn (api &Internals) accumulated_visual_context_tree_build_count() u64 {
	return api.platform.accumulated_visual_context_tree_build_count_
}

pub fn (mut api Internals) begin_display_list_trace() {
	api.platform.display_list_trace = ''
	api.platform.display_list_trace_active = true
}

pub fn (mut api Internals) take_display_list_trace() string {
	api.platform.display_list_trace_active = false
	trace := api.platform.display_list_trace
	api.platform.display_list_trace = ''
	return trace
}

pub fn (api &Internals) recorded_display_list_blocks_wheel_event_at(_ f64, _ f64) bool {
	return api.platform.recorded_display_list_blocks_wheel
}

pub fn (mut api Internals) record_display_list_for_testing(paint_overlay bool, cold bool) {
	api.platform.record_display_list_requests++
	api.platform.last_record_display_list_paint_overlay = paint_overlay
	api.platform.last_record_display_list_cold = cold
}

pub fn (api &Internals) needs_repaint() bool {
	return api.platform.needs_repaint_
}

pub fn (api &Internals) needs_display_list_record() bool {
	return api.platform.needs_display_list_record_
}

pub fn (api &Internals) screen_wake_lock_active() bool {
	if document := api.platform.associated_document {
		dom_page := document.page()
		if dom_page != unsafe { nil } && dom_page.target != unsafe { nil } {
			page_model := unsafe { &page.Page(dom_page.target) }
			return page_model.is_screen_wake_lock_active()
		}
	}
	return api.platform.screen_wake_lock_active_
}

pub fn (api &Internals) dump_display_list() string {
	return api.platform.display_list_dump
}

pub fn (api &Internals) dump_layout_tree(node ?&dom.Node) string {
	target := node or { return '(no layout node)' }
	mut document := target.document()
	document.update_layout(.debugging)
	layout_node := target.layout_node() or { return '(no layout node)' }
	if layout_node.layout_handle == unsafe { nil } {
		return '(no layout node)'
	}
	return tree_dump.layout_tree(unsafe { &layout.Node(layout_node.layout_handle) })
}

pub fn (api &Internals) dump_paintable_tree(node ?&dom.Node) string {
	return if node == none { '(no paintable)' } else { '(paintable tree host boundary)' }
}

pub fn (api &Internals) dump_stacking_context_tree() string {
	return api.platform.stacking_context_dump
}

pub fn (api &Internals) stacking_context_structure_verification_report() string {
	return api.platform.stacking_context_verification_report
}

pub fn (api &Internals) dump_gc_graph() string {
	return api.platform.gc_graph_dump
}

pub fn (api &Internals) get_shadow_root(element &dom.Element) ?&dom.ShadowRoot {
	return element.shadow_root()
}

pub fn (api &Internals) has_shadow_root(element &dom.Element) bool {
	return element.shadow_root() != none
}

pub fn (mut api Internals) handle_sdl_input_events() {
	api.platform.sdl_input_event_pumps++
}

pub fn (mut api Internals) connect_virtual_gamepad() &InternalGamepad {
	internal_pad := InternalGamepad.create(api.next_gamepad_id_, api.navigator, api)
	api.next_gamepad_id_++
	api.gamepads_ << internal_pad
	return internal_pad
}

pub fn (mut api Internals) disconnect_virtual_gamepad(gamepad_to_remove &InternalGamepad) {
	for index, candidate in api.gamepads_ {
		if candidate == gamepad_to_remove {
			api.gamepads_.delete(index)
			return
		}
	}
}

pub fn (mut api Internals) perform_per_test_cleanup() {
	for api.gamepads_.len > 0 {
		pad_pointer := api.gamepads_[0]
		mut internal_pad := unsafe { &InternalGamepad(pad_pointer) }
		internal_pad.disconnect()
	}
	api.gamepads_.clear()
}

pub fn (mut api Internals) set_highlighted_node(node ?&dom.Node) {
	api.platform.highlighted_node = node
}

pub fn (mut api Internals) clear_element(mut element dom.Element) {
	mut control := html.FormAssociatedElement.create(element)
	control.clear_algorithm()
}

pub fn (mut api Internals) set_environments_top_level_url(url string) ! {
	parsed := parse_absolute_url(url) or { return error('invalid absolute URL') }
	api.platform.top_level_url = parsed.serialize()
}

// Page appearance and focus controls used by the layout test harness. The
// translated PlatformState is the PageClient boundary, while document-owned
// effects are applied to the live associated document as well.
pub fn (mut api Internals) set_user_style(source string) {
	api.platform.user_style_source = source
	api.platform.user_style_invalidations++
	if document := api.platform.associated_document {
		css.set_document_user_style_sheet(document, source)
		mut document_node := unsafe { &dom.Node(document) }
		document_node.invalidate_style(.settings_change)
	}
}

pub fn (mut api Internals) set_preferred_color_scheme(color_scheme string) {
	preferred := css.preferred_color_scheme_from_string(color_scheme)
	api.platform.preferred_color_scheme_override = match preferred {
		.auto_ { none }
		else { css.preferred_color_scheme_to_string(preferred) }
	}
	api.platform.user_style_invalidations++
	if document := api.platform.associated_document {
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.set_needs_media_query_evaluation()
		mut document_node := unsafe { &dom.Node(document) }
		document_node.invalidate_style(.settings_change)
	}
}

pub fn (mut api Internals) set_page_focus(has_focus bool) {
	api.platform.page_has_focus = has_focus
}

pub fn (mut api Internals) set_system_visibility_state(state string) {
	visibility_state := if state == 'hidden' {
		dom.VisibilityState.hidden
	} else {
		dom.VisibilityState.visible
	}
	api.platform.system_visibility_state = visibility_state
	if document := api.platform.associated_document {
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.update_the_visibility_state(visibility_state)
	}
}

pub fn (mut api Internals) set_hidden_document_timer_wake_up_interval(milliseconds f64) {
	api.platform.hidden_document_timer_wake_up_interval_ms = milliseconds
}

pub fn (mut api Internals) set_hidden_document_intensive_timer_throttling(wake_up_interval f64, grace_period_once_loaded f64, grace_period_while_loading f64) {
	api.platform.hidden_document_intensive_wake_up_interval_ms = wake_up_interval
	api.platform.hidden_document_intensive_grace_period_once_loaded_ms = grace_period_once_loaded
	api.platform.hidden_document_intensive_grace_period_while_loading_ms = grace_period_while_loading
}

pub fn (api &Internals) canvas_color_scheme() string {
	if override := api.platform.preferred_color_scheme_override {
		return override
	}
	document := api.platform.associated_document or { return 'light' }
	preferred := css.preferred_color_scheme_from_string(document.preferred_color_scheme())
	return if preferred == .dark { 'dark' } else { 'light' }
}

pub fn (api &Internals) image_animation_state_for_url(url string) !html.AnimatedImageDebugState {
	document := api.platform.associated_document or {
		return error("URL does not have an associated document: '${url}'")
	}
	parsed_url := document.encoding_parse_url(url) or {
		return error("Invalid URL: '${url}'")
	}

	if request := html.shared_resource_request_for_document_and_url(document, parsed_url) {
		image_data := request.image_data() or {
			return error("URL's shared resource request does not have any associated image data: '${url}'")
		}
		state := html.decoded_image_animation_state(image_data.data) or {
			return error("URL's associated image is not an animated bitmap: '${url}'")
		}
		return state
	}

	requests := document.shared_resource_requests()
	request := requests[parsed_url.to_string()] or {
		return error("URL does not have any associated shared resource requests: '${url}'")
	}
	image_data := request.image_data() or {
		return error("URL's shared resource request does not have any associated image data: '${url}'")
	}
	if image_data.data is html.AnimatedDecodedImageData {
		return image_data.data.debug_state()
	}
	return error("URL's associated image is not an animated bitmap: '${url}'")
}

pub struct AsyncScrollingStateSnapshot {
pub:
	state               compositor.AsyncScrollingState
	display_list        &compositor.CompositorDisplayList
	visual_context_tree &compositor.VisualContextTree
	scroll_state        compositor.CompositorScrollStateSnapshot
}

fn capture_async_scrolling_state(platform &PlatformState) ?AsyncScrollingStateSnapshot {
	document := platform.associated_document or { return none }
	mut mutable_document := unsafe { &dom.Document(document) }
	_ = mutable_document.record_display_list()
	display_list := platform.async_scrolling_display_list or { return none }
	visual_context_tree := platform.async_scrolling_visual_context_tree or { return none }
	return AsyncScrollingStateSnapshot{
		state: compositor.async_scrolling_state_from_display_list(*display_list)
		display_list: display_list
		visual_context_tree: visual_context_tree
		scroll_state: platform.async_scrolling_scroll_state_snapshot
	}
}

pub fn (api &Internals) async_scrolling_state() compositor.AsyncScrollingState {
	snapshot := capture_async_scrolling_state(api.platform) or {
		return compositor.AsyncScrollingState{}
	}
	return snapshot.state
}

pub fn (api &Internals) async_scrolling_state_blocks_wheel_event_at(x f64, y f64) bool {
	snapshot := capture_async_scrolling_state(api.platform) or { return false }
	return compositor.blocks_wheel_event_at_position(snapshot.state, snapshot.display_list, snapshot.visual_context_tree, snapshot.scroll_state, painting.Point{x, y})
}

pub fn (api &Internals) async_scrolling_state_wheel_routing_admission() string {
	snapshot := capture_async_scrolling_state(api.platform) or {
		return compositor.wheel_routing_admission_to_utf16_view(.no_async_scrolling_state)
	}
	return compositor.wheel_routing_admission_to_utf16_view(compositor.wheel_routing_admission_for(snapshot.state))
}

fn internals_snap_container_handling(precise bool, phase ScrollGesturePhase) compositor.SnapContainerHandling {
	precision := if precise {
		compositor.WheelDeltaPrecision.precise
	} else {
		compositor.WheelDeltaPrecision.discrete
	}
	compositor_phase := match phase {
		.none_ { compositor.ScrollGesturePhase.none }
		.ongoing { compositor.ScrollGesturePhase.changed }
		.momentum { compositor.ScrollGesturePhase.momentum }
		.ended { compositor.ScrollGesturePhase.ended }
	}
	return compositor.snap_container_handling_for(precision, compositor_phase)
}

fn wheel_scroll_admission_at(platform &PlatformState, x f64, y f64, delta_x f64, delta_y f64, precise bool, force_stale_wheel_event_regions bool) compositor.WheelScrollAdmission {
	snapshot := capture_async_scrolling_state(platform) or {
		return .no_scrollable_target
	}
	return compositor.admit_wheel_scroll(snapshot.state, snapshot.display_list, snapshot.visual_context_tree, snapshot.scroll_state, painting.Point{x, y}, painting.Point{delta_x, delta_y}, internals_snap_container_handling(precise, .none_), snapshot.state.has_blocking_wheel_event_listeners && !force_stale_wheel_event_regions)
}

pub fn (api &Internals) async_scrolling_state_can_wheel_scroll_at(x f64, y f64, delta_x f64, delta_y f64, precise bool, force_stale_wheel_event_regions bool) bool {
	return wheel_scroll_admission_at(api.platform, x, y, delta_x, delta_y, precise, force_stale_wheel_event_regions) == .accepted
}

fn wheel_scroll_admission_to_string(admission compositor.WheelScrollAdmission) string {
	return match admission {
		.accepted { 'accepted' }
		.no_scrollable_target { 'no-scrollable-target' }
		.blocked_by_main_thread_region { 'blocked-by-main-thread-region' }
		.stale_blocking_wheel_event_regions { 'stale-blocking-wheel-event-regions' }
		.blocked_by_wheel_event_region { 'blocked-by-wheel-event-region' }
	}
}

pub fn (api &Internals) async_scrolling_state_wheel_scroll_admission_at(x f64, y f64, delta_x f64, delta_y f64, precise bool, force_stale_wheel_event_regions bool) string {
	return wheel_scroll_admission_to_string(wheel_scroll_admission_at(api.platform, x, y, delta_x, delta_y, precise, force_stale_wheel_event_regions))
}

pub fn (api &Internals) async_scrolling_state_wheel_target_at(x f64, y f64, delta_x f64, delta_y f64, precise bool, phase ScrollGesturePhase) string {
	snapshot := capture_async_scrolling_state(api.platform) or { return 'none' }
	mut scroll_tree := compositor.AsyncScrollTree{}
	scroll_tree.set_state(snapshot.state)
	scroll_tree.rebuild_wheel_hit_test_targets(snapshot.display_list, snapshot.visual_context_tree, snapshot.scroll_state)
	target := scroll_tree.hit_test_scroll_node_for_wheel(*snapshot.visual_context_tree, painting.Point{x, y}, painting.Point{delta_x, delta_y}, internals_snap_container_handling(precise, phase))
	if target.blocked_by_main_thread_region {
		return 'main-thread'
	}
	if target.blocked_by_wheel_event_region {
		return 'none'
	}
	node_id := target.node_id or { return 'none' }
	return if scroll_tree.scroll_node_is_viewport(node_id) { 'viewport' } else { 'non-viewport' }
}

pub struct AsyncScrollNodeObject {
pub:
	document_id              u64
	scroll_node_index        int
	parent_document_id       u64
	parent_scroll_node_index int
	is_viewport              bool
}

pub struct AsyncScrollingStateObject {
pub:
	scroll_node_count                                 uint
	scroll_nodes                                      []AsyncScrollNodeObject
	has_blocking_wheel_event_listeners                bool
	blocking_wheel_event_region_count                 uint
	main_thread_wheel_event_region_count              uint
	wheel_event_listener_state_generation             u64
	blocking_wheel_event_regions_are_current          bool
	has_blocking_wheel_event_region_covering_viewport bool
}

fn async_scrolling_state_to_object(state compositor.AsyncScrollingState) AsyncScrollingStateObject {
	mut scroll_nodes := []AsyncScrollNodeObject{cap: state.scroll_nodes.len}
	for node in state.scroll_nodes {
		parent := node.parent_node_id or { compositor.AsyncScrollNodeId{} }
		scroll_nodes << AsyncScrollNodeObject{
			document_id: node.node_id.document_id
			scroll_node_index: node.node_id.scroll_node_index
			parent_document_id: parent.document_id
			parent_scroll_node_index: parent.scroll_node_index
			is_viewport: node.is_viewport
		}
	}
	return AsyncScrollingStateObject{
		scroll_node_count: uint(state.scroll_nodes.len)
		scroll_nodes: scroll_nodes
		has_blocking_wheel_event_listeners: state.has_blocking_wheel_event_listeners
		blocking_wheel_event_region_count: uint(state.blocking_wheel_event_regions.len)
		main_thread_wheel_event_region_count: uint(state.main_thread_wheel_event_regions.len)
		wheel_event_listener_state_generation: state.wheel_event_listener_state_generation
		blocking_wheel_event_regions_are_current: state.has_blocking_wheel_event_listeners
		has_blocking_wheel_event_region_covering_viewport: state.has_blocking_wheel_event_region_covering_viewport
	}
}

pub fn (api &Internals) async_scrolling_state_object() AsyncScrollingStateObject {
	return async_scrolling_state_to_object(api.async_scrolling_state())
}

pub fn (api &Internals) recorded_async_scrolling_state_object() AsyncScrollingStateObject {
	display_list := api.platform.recorded_async_scrolling_display_list or {
		return async_scrolling_state_to_object(compositor.AsyncScrollingState{})
	}
	return async_scrolling_state_to_object(compositor.async_scrolling_state_from_display_list(*display_list))
}

pub fn (api &Internals) viewport_overflow_x() string {
	document := api.platform.associated_document or { return 'visible' }
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.update_layout(.debugging)
	viewport := document.unsafe_layout_node() or { return 'visible' }
	overflow := (viewport.root_layout_node() or { return 'visible' }).overflow_x()
	return match overflow {
		.auto_ { 'auto' }
		.clip { 'clip' }
		.hidden { 'hidden' }
		.scroll { 'scroll' }
		.visible { 'visible' }
	}
}
