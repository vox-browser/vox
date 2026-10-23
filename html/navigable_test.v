@[has_globals]
module html

import css
import dom
import fetch
import highresolutiontime
import http
import page
import painting

__global (
	navigable_test_observer_completions = 0
	navigable_test_observer_changes     = 0
	navigable_test_pastes               = []string{}
	navigable_test_paints               = 0
	navigable_test_screenshots          = 0
	navigable_test_fetches              = 0
	navigable_test_referrer_policies    = []string{}
	navigable_test_destroy_during_fetch = &NavigableModel(unsafe { nil })
)

@[heap]
struct NavigableHistoryStepObservation {
mut:
	completed bool
	result    HistoryStepResult
}

fn (mut observation NavigableHistoryStepObservation) complete(result HistoryStepResult) {
	observation.completed = true
	observation.result = result
}

fn navigable_test_complete() {
	navigable_test_observer_completions++
}

fn navigable_test_changed() {
	navigable_test_observer_changes++
}

fn navigable_test_paste(text string) {
	navigable_test_pastes << text
}

fn navigable_test_paint() {
	navigable_test_paints++
}

fn navigable_test_screenshot(_ dom.Rect) {
	navigable_test_screenshots++
}

fn navigable_test_javascript_url(source string, _ &dom.Document) ?string {
	if source == "'generated'" {
		return '<!doctype html><html><body>generated</body></html>'
	}
	return none
}

fn navigable_test_fetch(request &fetch.Request) !&fetch.Response {
	navigable_test_fetches++
	navigable_test_referrer_policies << request.referrer_policy
	mut response := fetch.Response.create()
	response.url_list = request.url_list.clone()
	if request.current_url().serialize() == 'https://example.test/redirect' {
		response.status = 302
		response.header_list.append(http.Header{
			name: 'Location'
			value: '/fetched'
		})
		return response
	}
	response.set_body_bytes('<!doctype html><html><body>fetched response</body></html>'.bytes())
	response.header_list.append(http.Header{
		name: 'Content-Type'
		value: 'text/html'
	})
	response.header_list.append(http.Header{
		name: 'Content-Security-Policy'
		value: "sandbox allow-scripts; default-src 'self'"
	})
	return response
}

fn navigable_test_fetch_and_destroy(request &fetch.Request) !&fetch.Response {
	mut model := navigable_test_destroy_during_fetch
	model.set_has_been_destroyed()
	return navigable_test_fetch(request)
}

fn navigable_test_top_level(url string, target_name string) !(&dom.Document, &WindowModel, &NavigableModel) {
	mut document := dom.Document.create(dom.URL{value: url})
	document.set_origin(document.url.origin())
	document.populate_with_html_head_and_body()!
	window := WindowModel.create_top_level(document, none, target_name)!
	host := document.navigable() or { return error('missing host navigable') }
	model := navigable_model_for_host(host) or { return error('missing navigable model') }
	return document, window, model
}

fn test_navigable_initialization_hierarchy_and_target_choice() {
	mut parent_document, mut parent_window, parent_model := navigable_test_top_level('https://example.test/', 'top')!
	assert parent_model.id() != ''
	assert parent_model.active_document()? == parent_document
	assert parent_model.target_name() == 'top'
	assert parent_model.is_top_level_traversable()
	assert parent_model.is_script_closable()
	assert !parent_model.host_navigable().is_focused()
	mut focused_parent_model := unsafe { &NavigableModel(parent_model) }
	focused_parent_model.set_focused(true)
	assert parent_model.host_navigable().is_focused()

	mut child_document := dom.Document.create(dom.URL{value: 'https://example.test/frame'})
	child_document.set_origin(child_document.url.origin())
	child_context := BrowsingContextModel.create(child_document, parent_window.browsing_context(), 'frame')
	mut container := parent_document.create_element_ns('http://www.w3.org/1999/xhtml', 'iframe')!
	mut parent_body := parent_document.body() or { panic('missing parent body') }
	mut parent_body_node := parent_body.as_node()
	parent_body_node.append_child(container.as_node())!
	mut mutable_child_context := unsafe { &BrowsingContextModel(child_context) }
	mutable_child_context.set_container(container)
	_ = WindowModel.create(child_document, child_context)!
	child_host := child_document.navigable() or { panic('missing child host') }
	mut child_model := navigable_model_for_host(child_host) or { panic('missing child model') }
	assert child_model.parent()? == parent_model
	assert parent_model.is_ancestor_of(child_model)
	assert child_model.traversable_navigable() == parent_model
	assert child_host.container()? == container.as_node()
	assert child_host.container_document()? == parent_document
	mut iframe_model := html_iframe_element_model_for_dom_element(unsafe { &dom.HTMLIFrameElement(container) })
	iframe_model.set_sandbox('allow-scripts allow-forms')
	parent_document.set_active_sandboxing_flag_set(dom.SandboxingFlagSet{
		sandboxed_document_domain: true
	})
	child_snapshot := child_model.snapshot_target_snapshot_params()
	assert child_snapshot.sandboxing_flags.contains(.sandboxed_navigation)
	assert child_snapshot.sandboxing_flags.contains(.sandboxed_document_domain)
	assert !child_snapshot.sandboxing_flags.contains(.sandboxed_scripts)
	assert !child_snapshot.sandboxing_flags.contains(.sandboxed_forms)
	child_document.set_navigable(none)
	assert child_document.as_node().navigable() == none
	child_document.set_navigable(child_host)
	assert child_document.as_node().navigable()? == child_host
	assert parent_document.document_tree_child_navigables() == [child_host]
	assert parent_model.child_navigables().len == 0
	child_model.set_has_session_history_entry_and_ready_for_navigation()
	assert parent_model.child_navigables() == [child_model]

	mut mutable_parent_model := unsafe { &NavigableModel(parent_window.navigable_model()) }
	self_choice := mutable_parent_model.choose_a_navigable('_self', false)!
	assert self_choice.navigable? == parent_model
	assert self_choice.window_type == .existing_or_none
	frame_choice := mutable_parent_model.choose_a_navigable('frame', false)!
	assert frame_choice.navigable? == child_model
	blank_choice := mutable_parent_model.choose_a_navigable('_blank', true)!
	assert blank_choice.navigable != none
	assert blank_choice.window_type == .new_with_no_opener
}

fn test_line_box_border_debug_setting_is_inherited_and_propagated() {
	_, parent_window, parent_model := navigable_test_top_level('https://example.test/', 'top')!
	mut mutable_parent := unsafe { &NavigableModel(parent_model) }
	mutable_parent.set_should_show_line_box_borders(true)

	mut child_document := dom.Document.create(dom.URL{value: 'https://example.test/frame'})
	child_document.set_origin(child_document.url.origin())
	child_context := BrowsingContextModel.create(child_document, parent_window.browsing_context(),
		'frame')
	child_window := WindowModel.create(child_document, child_context)!
	child_model := child_window.navigable_model()
	assert child_model.should_show_line_box_borders_
	mut mutable_child := unsafe { &NavigableModel(child_model) }
	mutable_child.set_has_session_history_entry_and_ready_for_navigation()

	mut grandchild_document := dom.Document.create(dom.URL{value: 'https://example.test/nested-frame'})
	grandchild_document.set_origin(grandchild_document.url.origin())
	grandchild_context := BrowsingContextModel.create(grandchild_document,
		child_window.browsing_context(), 'nested-frame')
	grandchild_window := WindowModel.create(grandchild_document, grandchild_context)!
	grandchild_model := grandchild_window.navigable_model()
	assert grandchild_model.should_show_line_box_borders_
	mut mutable_grandchild := unsafe { &NavigableModel(grandchild_model) }
	mutable_grandchild.set_has_session_history_entry_and_ready_for_navigation()

	mutable_parent.needs_repaint_ = false
	mutable_child.needs_repaint_ = false
	mutable_grandchild.needs_repaint_ = false
	mutable_parent.set_should_show_line_box_borders(false)

	assert !parent_model.should_show_line_box_borders_
	assert !child_model.should_show_line_box_borders_
	assert !grandchild_model.should_show_line_box_borders_
	assert parent_model.needs_repaint()
	assert child_model.needs_repaint()
	assert grandchild_model.needs_repaint()
}

fn test_force_dark_settings_inherit_propagate_and_honor_document_opt_outs() {
	mut parent_document, parent_window, parent_model := navigable_test_top_level('https://example.test/',
		'top')!
	mut mutable_parent := unsafe { &NavigableModel(parent_model) }
	mutable_parent.set_force_dark_enabled(true)
	mutable_parent.set_force_dark_thresholds(31, 47)
	assert parent_model.force_dark_enabled()
	assert parent_model.force_dark_foreground_threshold() == 31
	assert parent_model.force_dark_background_threshold() == 47
	assert parent_document.preferred_color_scheme() == 'dark'
	assert parent_model.force_dark_applies_to_active_document()

	parent_document.set_supported_color_schemes(['dark'], false)
	assert parent_model.active_document_opts_out_of_force_dark()
	assert !parent_model.force_dark_applies_to_active_document()
	parent_document.set_supported_color_schemes(['light'], true)
	assert parent_model.active_document_opts_out_of_force_dark()
	parent_document.set_supported_color_schemes(['light'], false)
	assert parent_model.force_dark_applies_to_active_document()

	mut root := parent_document.document_element() or { panic('missing root') }
	mut dark_properties := &dom.CSSComputedProperties_{}
	dark_properties.set_rare_properties(dom.CSSComputedPropertiesRareData{ color_schemes: ['dark'] })
	root.set_computed_properties(none, dark_properties)
	mut root_node := root.as_node()
	root_node.set_layout_node(&dom.LayoutNode{
		dom_node_: root_node
	})
	assert parent_model.active_document_opts_out_of_force_dark()
	mut light_properties := &dom.CSSComputedProperties_{ color_scheme_only_: true }
	light_properties.set_rare_properties(dom.CSSComputedPropertiesRareData{ color_schemes: ['light'] })
	root.set_computed_properties(none, light_properties)
	assert parent_model.active_document_opts_out_of_force_dark()

	mut child_document := dom.Document.create(dom.URL{value: 'https://example.test/frame'})
	child_document.set_origin(child_document.url.origin())
	child_context := BrowsingContextModel.create(child_document, parent_window.browsing_context(),
		'frame')
	child_window := WindowModel.create(child_document, child_context)!
	child_model := child_window.navigable_model()
	assert child_model.force_dark_enabled()
	assert child_model.force_dark_foreground_threshold() == 31
	assert child_model.force_dark_background_threshold() == 47
	mut mutable_child := unsafe { &NavigableModel(child_model) }
	mutable_child.set_has_session_history_entry_and_ready_for_navigation()

	mutable_parent.set_force_dark_enabled(false)
	mutable_parent.set_force_dark_thresholds(150, 205)
	assert !child_model.force_dark_enabled()
	assert child_model.force_dark_foreground_threshold() == 150
	assert child_model.force_dark_background_threshold() == 205
}

fn test_navigable_host_answers_readiness_and_load_delay_from_its_model() {
	mut parent_document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	mut parent_host := &dom.Navigable{
		is_top_level_traversable_: true
	}
	parent_host.set_active_document(parent_document)
	_ = NavigableModel.create(parent_host, none) or { panic(err) }

	mut child_document := dom.Document.create(dom.URL{ value: 'https://example.test/frame' })
	mut child_host := &dom.Navigable{
		parent_: parent_host
		container_document_: parent_document
	}
	child_host.set_active_document(child_document)
	mut child_model := NavigableModel.create(child_host, none) or { panic(err) }

	assert !child_host.has_session_history_entry_and_ready_for_navigation()
	child_model.set_has_session_history_entry_and_ready_for_navigation()
	assert child_host.has_session_history_entry_and_ready_for_navigation()

	assert child_host.delays_the_load_event_of_its_container()
	child_document.set_ready_for_post_load_tasks(true)
	assert !child_host.delays_the_load_event_of_its_container()
	child_model.set_delaying_load_events(true)
	assert child_host.delays_the_load_event_of_its_container()
	child_model.set_delaying_load_events(false)
	assert !child_host.delays_the_load_event_of_its_container()
}

fn test_local_navigable_root_preserves_a_logical_remote_parent() {
	remote_parent_document := dom.Document.create(dom.URL{ value: 'https://parent.test/' })
	mut remote_parent := &dom.Navigable{}
	remote_parent.set_active_document(remote_parent_document)

	mut child_document := dom.Document.create(dom.URL{ value: 'https://child.test/' })
	child_document.set_ready_for_post_load_tasks(true)
	mut child_host := &dom.Navigable{
		parent_: remote_parent
	}
	child_host.set_active_document(child_document)
	child_model := NavigableModel.create(child_host, none) or { panic(err) }

	assert child_host.parent()? == remote_parent
	assert child_model.parent() == none
	assert !child_model.is_top_level_traversable()
	assert !child_host.has_session_history_entry_and_ready_for_navigation()
	assert !child_host.delays_the_load_event_of_its_container()
	mut mutable_child_model := unsafe { &NavigableModel(child_model) }
	mutable_child_model.set_delaying_load_events(true)
	assert mutable_child_model.is_delaying_load_events()
	assert child_host.delays_the_load_event_of_its_container()
}

fn test_nested_navigable_uses_the_top_level_traversable_visibility_state() {
	_, parent_window, _ := navigable_test_top_level('https://example.test/', 'top')!
	mut traversable := TraversableNavigable.create_a_new_top_level_traversable('')!
	mut parent_context := unsafe { &BrowsingContextModel(parent_window.browsing_context()) }
	parent_context.set_top_level_traversable(traversable)

	mut child_document := dom.Document.create(dom.URL{ value: 'https://example.test/frame' })
	child_document.set_origin(child_document.url.origin())
	child_context := BrowsingContextModel.create(child_document, parent_window.browsing_context(), 'frame')
	_ = WindowModel.create(child_document, child_context)!
	assert child_document.visibility_state_value() == .hidden

	traversable.set_system_visibility_state(.visible)
	mut activated_document := dom.Document.create(dom.URL{ value: 'https://example.test/next' })
	activated_document.set_origin(activated_document.url.origin())
	entry := &SessionHistoryEntry{
		url: activated_document.url
		document_state: &DocumentState{
			document_id_: activated_document.unique_id()
		}
	}
	child_host := child_document.navigable() or { panic('missing child navigable') }
	mut child_model := navigable_model_for_host(child_host) or { panic('missing child model') }
	child_model.activate_history_entry(entry, activated_document)
	assert activated_document.visibility_state_value() == .visible
}

fn test_top_level_target_snapshot_uses_popup_sandboxing_flags() {
	_, window, model := navigable_test_top_level('https://example.test/', 'top')!
	mut context := unsafe { &BrowsingContextModel(window.browsing_context()) }
	context.set_popup_sandboxing_flag_set(SandboxingFlagSet{
		bits: u32(SandboxingFlag.sandboxed_scripts) | u32(SandboxingFlag.sandboxed_forms)
	})

	snapshot := model.snapshot_target_snapshot_params()
	assert snapshot.sandboxing_flags.contains(.sandboxed_scripts)
	assert snapshot.sandboxing_flags.contains(.sandboxed_forms)
	assert !snapshot.sandboxing_flags.contains(.sandboxed_origin)
}

fn test_navigable_history_cross_document_fragment_reload_and_javascript_url() {
	mut original_document, _, model_pointer := navigable_test_top_level('https://example.test/start', 'top')!
	mut model := unsafe { &NavigableModel(model_pointer) }
	assert model.backing_store_manager() != unsafe { nil }
	assert model.event_handler() != unsafe { nil }
	assert model.rendering_thread() != unsafe { nil }
	assert !model.is_svg_page()
	model.navigate(NavigableNavigateParams{
		url: dom.URL{value: 'https://example.test/next'}
		source_document: original_document
		document_resource: '<!doctype html><html><body>next</body></html>'
	})!
	assert model.get_session_history_entries().len == 2
	next_document := model.active_document() or { panic('missing navigated document') }
	assert next_document.url.serialize() == 'https://example.test/next'
	assert next_document.body() != none
	assert model.ongoing_navigation().kind == .empty
	assert model.get_the_target_history_entry(0)? == model.get_session_history_entries()[0]
	assert model.get_the_target_history_entry(1)? == model.current_session_history_entry()?

	model.navigate(NavigableNavigateParams{
		url: dom.URL{value: 'https://example.test/next#section'}
		source_document: next_document
	})!
	assert model.get_session_history_entries().len == 3
	assert model.active_document()?.url.fragment()? == 'section'
	model.reload(none, .none)
	assert model.get_session_history_entries().len == 3
	assert model.active_document()?.url.fragment()? == 'section'
	assert !model.current_session_history_entry()?.document_state?.reload_pending

	model.set_javascript_url_hook(navigable_test_javascript_url)
	current_document := model.active_document() or { panic('missing current document') }
	model.navigate(NavigableNavigateParams{
		url: dom.URL{value: "javascript:'generated'"}
		source_document: current_document
		history_handling: .replace
	})!
	assert model.active_document()?.body() != none
	assert model.get_session_history_entries().len == 3
}

fn test_reload_rebuilds_child_session_history_from_the_replacement_document() {
	mut document, _, model_pointer := navigable_test_top_level('https://example.test/editor', 'top')!
	mut model := unsafe { &NavigableModel(model_pointer) }
	original_entry := model.current_session_history_entry() or { panic('missing original entry') }
	mut original_state := unsafe { &DocumentState(original_entry.document_state?) }
	original_state.nested_histories = [NestedHistory{
		id: 'old-editor-frame'
		entries: [&SessionHistoryEntry{
			step: 0
			url: dom.URL{value: 'https://example.test/stale-frame'}
			document_state: &DocumentState{
				document: document
			}
		}]
	}]

	model.reload(none, .none)
	reloaded_entry := model.current_session_history_entry() or { panic('missing reloaded entry') }
	assert voidptr(reloaded_entry) != voidptr(original_entry)
	assert reloaded_entry.document_state?.nested_histories.len == 0
	assert original_entry.document_state?.nested_histories.len == 1

	mut reloaded_state := unsafe { &DocumentState(reloaded_entry.document_state?) }
	reloaded_state.nested_histories = [NestedHistory{
		id: 'new-editor-frame'
		entries: []
	}]
	model.reload(none, .none)
	assert model.current_session_history_entry()?.document_state?.nested_histories.len == 0
}

fn test_cross_document_navigation_completion_runs_for_destroyed_navigables() {
	document, _, model_pointer := navigable_test_top_level('https://example.test/start', 'top')!
	mut model := unsafe { &NavigableModel(model_pointer) }
	model.set_has_been_destroyed()
	entry := &SessionHistoryEntry{
		url: document.url
		document_state: &DocumentState{
			document: document
		}
	}
	mut observation := &NavigableHistoryStepObservation{}
	finalize_a_cross_document_navigation(model, .replace, .none, entry, document, fn [mut observation] (result HistoryStepResult) {
		observation.complete(result)
	})
	assert observation.completed
	assert observation.result == .applied
}

fn test_activating_an_entry_replays_deferred_complete_loading() {
	_, _, model_pointer := navigable_test_top_level('https://example.test/start', 'top')!
	mut model := unsafe { &NavigableModel(model_pointer) }
	mut deferred_document := dom.Document.create(dom.URL{ value: 'https://example.test/next' })
	deferred_document.set_origin(deferred_document.url.origin())
	deferred_document.completely_finish_loading()
	assert deferred_document.document_completely_loaded_deferred()
	entry := &SessionHistoryEntry{
		url: deferred_document.url
		document_state: &DocumentState{
			document_id_: deferred_document.unique_id()
		}
	}

	model.activate_history_entry(entry, deferred_document)
	assert model.active_document()? == deferred_document
	assert entry.document() == none
	assert entry.document_state()?.document_id()? == deferred_document.unique_id()
	assert !deferred_document.document_completely_loaded_deferred()
	model.set_active_document(none)
	assert model.active_document() == none
	assert entry.document_state()?.document_id() == none
	assert deferred_document.navigable() == none
}

fn test_navigable_sandbox_viewport_selection_observers_and_rendering() {
	mut document, _, model_pointer := navigable_test_top_level('https://example.test/', 'top')!
	mut model := unsafe { &NavigableModel(model_pointer) }
	assert model.allowed_by_sandboxing_to_navigate(model, SourceSnapshotParams{
		sandboxing_flags: SandboxingFlagSet{ bits: u32(SandboxingFlag.sandboxed_navigation) }
	})

	document.set_viewport_rect(dom.Rect{0, 0, 320, 200})
	model.set_viewport_size(css.CSSPixelSize.from_values(640, 480))
	assert model.viewport_size().width().to_double() == 640
	assert model.viewport_size().height().to_double() == 480
	// This model fixture has no layout host. Install the committed viewport
	// mirror used by the source scroll operation before exercising its bounds.
	mut document_node := document.as_node()
	viewport_paintable := &dom.PaintableBox{
		is_box: true
		dom_node_: document_node
		padding_box_width_: 640
		padding_box_height_: 480
		scrollable_overflow_rect_: dom.CSSPixelRect_{width_: 1000, height_: 1000}
	}
	document_node.set_paintable(unsafe { &dom.Paintable(viewport_paintable) })
	model.perform_scroll_of_viewport_scrolling_box(css.CSSPixelPoint.from_values(12, 18))
	assert model.viewport_scroll_offset().to_double_pair() == [12.0, 18.0]!
	assert model.snapshot_containing_block().left_value() == 12
	document.scroll_to_the_beginning_of_the_document()
	assert model.viewport_scroll_offset().to_double_pair() == [0.0, 0.0]!
	model.perform_scroll_of_viewport_scrolling_box(css.CSSPixelPoint.from_values(12, 18))
	assert model.scroll_viewport_by_delta(css.CSSPixelPoint.from_values(-12, -18)).state() == .fulfilled
	assert model.viewport_scroll_offset().to_double_pair() == [0.0, 0.0]!

	body := document.body() or { panic('missing body') }
	mut body_node := unsafe { &dom.Node(body) }
	mut visible_text_node := document.create_text_node('selected value').as_node()
	visible_text_node.set_layout_node(&dom.LayoutNode{
		visual_lines_data_: &dom.LayoutVisualLines{ values: [dom.VisualLine{
			start_offset: 0
			end_offset: 14
			end_offset_with_trailing_whitespace: 14
			has_fragments: true
		}] }
	})
	body_node.append_child(visible_text_node)!
	model.select_all()
	assert model.selected_text() == 'selected value'
	assert model.selected_html_for_clipboard() == 'selected value'
	navigable_test_pastes = []
	model.set_paste_hook(navigable_test_paste)
	model.paste('clipboard')
	assert model.last_pasted_text() == 'clipboard'
	assert navigable_test_pastes == ['clipboard']

	navigable_test_observer_completions = 0
	navigable_test_observer_changes = 0
	mut observer := NavigationObserver.create(model.host_navigable())
	observer.set_navigation_complete(navigable_test_complete)
	observer.set_ongoing_navigation_changed(navigable_test_changed)
	model.register_navigation_observer(observer)
	model.set_ongoing_navigation(NavigableOngoingNavigation{ kind: .navigation, id: 'test' })
	model.set_ongoing_navigation(NavigableOngoingNavigation{})
	assert navigable_test_observer_changes == 2
	notify_navigation_complete(model.host_navigable())
	assert navigable_test_observer_completions == 1
	model.unregister_navigation_observer(observer)
	notify_navigation_complete(model.host_navigable())
	assert navigable_test_observer_completions == 1

	navigable_test_paints = 0
	navigable_test_screenshots = 0
	model.set_paint_hook(navigable_test_paint)
	model.set_screenshot_hook(navigable_test_screenshot)
	model.ready_to_paint()
	model.paint_next_frame()
	model.render_screenshot(dom.PaintConfig{})
	assert model.paint_count() == 2
	assert model.screenshot_count() == 1
	assert navigable_test_paints == 2
	assert navigable_test_screenshots == 1
	assert !model.has_a_rendering_opportunity()
	mut rendering_page := page.Page.create(1)!
	mut rendering_document := model.active_document() or { panic('missing document') }
	rendering_document.set_page(unsafe { &dom.Page(rendering_page) })
	rendering_page.set_local_root_navigable(model.host_navigable())!
	assert model.has_a_rendering_opportunity()
}

fn test_navigable_cut_returns_and_deletes_focused_text_control_selection() {
	mut document, _, model_pointer := navigable_test_top_level('https://example.test/', 'top')!
	mut model := unsafe { &NavigableModel(model_pointer) }
	mut textarea_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'textarea')!
	body := document.body() or { panic('missing body') }
	mut body_node := unsafe { &dom.Node(body) }
	body_node.append_child(textarea_element.as_node())!
	mut textarea := HTMLTextAreaElementModel.create(unsafe {
		&dom.HTMLTextAreaElement(textarea_element)
	})
	textarea.create_shadow_tree_if_needed()
	textarea.set_value('Ladybird')
	textarea.text.set_selection_range(1, 5, 'forward')!
	document.set_focused_area(textarea_element.as_node())
	assert model.selected_text() == 'adyb'
	model.select_all()
	assert textarea.text.selection_start() == 0
	assert textarea.text.selection_end() == 8
	assert model.selected_text() == 'Ladybird'
	textarea.text.set_selection_range(1, 5, 'forward')!
	assert model.cut_selected_text() == 'adyb'
	assert textarea.value() == 'Lird'
	assert textarea.text.selection_start() == 1
	assert textarea.text.selection_end() == 1
	assert model.cut_selected_text() == ''
	assert textarea.value() == 'Lird'
	assert dom.input_type_delete_by_cut == 'deleteByCut'
}

fn test_navigable_viewport_resize_grows_then_shrinks_device_backing_stores() {
	mut document := dom.Document.create(dom.URL{value: 'https://example.test/'})
	document.set_origin(document.url.origin())
	document.populate_with_html_head_and_body()!
	page_model := page.Page.create(2.0)!
	document.set_page(unsafe { &dom.Page(page_model) })
	window := WindowModel.create_top_level(document, none, 'backing-store')!
	mut model := unsafe { &NavigableModel(window.navigable_model()) }
	document.set_viewport_rect(dom.Rect{0, 0, 320, 200})
	mut renderer := model.rendering_thread()
	renderer.set_player(fn (_ &RenderingDisplayList, _ RenderingScrollStateSnapshot, _ &RenderingSurface) {})
	renderer.start()!

	model.set_viewport_size(css.CSSPixelSize.from_values(640, 480))
	mut manager := model.backing_store_manager()
	assert manager.allocated_size == painting.IntSize{1536, 1216}
	assert manager.front_bitmap_id == 1
	assert manager.back_bitmap_id == 2
	assert manager.resize_timer_is_active()
	assert manager.resize_timer_interval() == 3000
	assert model.rendering_thread().pending_command_count() == 1
	assert page_model.client().events.filter(it.name == 'allocate-backing-stores').len == 0
	renderer.process()
	assert page_model.client().events.last().name == 'allocate-backing-stores'
	assert page_model.client().events.last().text == '1:2'

	manager.fire_resize_timer()
	assert !manager.resize_timer_is_active()
	assert manager.allocated_size == painting.IntSize{1280, 960}
	assert manager.front_bitmap_id == 3
	assert manager.back_bitmap_id == 4
	assert model.rendering_thread().pending_command_count() == 1
	assert page_model.client().events.last().text == '1:2'
	renderer.process()
	assert page_model.client().events.last().text == '3:4'

	// An unchanged viewport is the source's early-return path: it neither grows
	// the stores nor restarts a timer that has already fired.
	model.set_viewport_size(css.CSSPixelSize.from_values(640, 480))
	assert !manager.resize_timer_is_active()
	assert model.rendering_thread().pending_command_count() == 0
}

fn test_navigable_fetch_redirect_policy_and_url_history_algorithms() {
	mut original_document, _, model_pointer := navigable_test_top_level('https://example.test/start', 'top')!
	mut model := unsafe { &NavigableModel(model_pointer) }
	navigable_test_fetches = 0
	model.set_navigation_fetch_hook(navigable_test_fetch)
	before_navigation := highresolutiontime.coarsen_time(highresolutiontime.unsafe_shared_current_time(),
		false)
	model.navigate(NavigableNavigateParams{
		url: dom.URL{ value: 'https://example.test/redirect' }
		source_document: original_document
	})!
	assert navigable_test_fetches == 2
	mut fetched_document := model.active_document() or { panic('missing fetched document') }
	// The navigated document's time origin is the creation time of its navigation response.
	timing := fetched_document.document_load_timing_info()
	assert timing.navigation_start_time >= before_navigation
	assert timing.navigation_start_time <= highresolutiontime.unsafe_shared_current_time()
	assert timing.dom_loading_time >= 0
	assert fetched_document.url.serialize() == 'https://example.test/fetched'
	assert !fetched_document.was_created_via_cross_origin_redirects()
	assert fetched_document.body() or { panic('missing body') }.as_node().text_content()? == 'fetched response'
	assert model.current_session_history_entry()?.url.serialize() == 'https://example.test/fetched'
	assert navigation_must_be_a_replace(dom.URL{ value: 'javascript:1' }, fetched_document)
	assert !navigation_must_be_a_replace(dom.URL{ value: 'https://example.test/next' }, fetched_document)

	perform_url_and_history_update_steps(fetched_document, dom.URL{
		value: 'https://example.test/fetched?state=1'
	}, SerializationRecord{ data: [u8(42)] }, .push)!
	assert fetched_document.url.serialize() == 'https://example.test/fetched?state=1'
	assert model.get_session_history_entries().len == 3
	assert model.current_session_history_entry()?.classic_history_api_state.data == [
		u8(42),
	]
	assert fetched_document.history().index == 1
	assert fetched_document.history().length == 2

	response_container := &PolicyContainer{
		referrer_policy: .origin
	}
	initiator_container := &PolicyContainer{
		referrer_policy: .no_referrer
	}
	local_policy := determine_navigation_params_policy_container(dom.URL{
		value: 'data:text/html,hello'
	}, none, initiator_container, none, response_container)
	assert local_policy.referrer_policy == .no_referrer
	history_container := &PolicyContainer{
		referrer_policy: .same_origin
	}
	history_policy := determine_navigation_params_policy_container(dom.URL{
		value: 'https://example.test/'
	}, history_container, initiator_container, none, response_container)
	assert history_policy.referrer_policy == .same_origin

	srcdoc_state := &DocumentState{
		origin: fetched_document.origin()
		resource: '<p>srcdoc</p>'
	}
	srcdoc_entry := &SessionHistoryEntry{
		url: dom.URL{ value: 'about:srcdoc' }
		document_state: srcdoc_state
	}
	srcdoc_params := create_navigation_params_from_a_srcdoc_resource(srcdoc_entry, model, TargetSnapshotParams{}, .none, none)!
	assert srcdoc_params.response.fetch_response_body()?.bytes().bytestr() == '<p>srcdoc</p>'
	assert srcdoc_params.response.header_list.get('Content-Type')? == 'text/html'
}

fn test_session_history_saves_and_restores_viewport_scroll_position() {
	mut document, _, model_pointer := navigable_test_top_level('https://example.test/start', 'top')!
	mut model := unsafe { &NavigableModel(model_pointer) }
	outgoing := model.active_session_history_entry() or { panic('missing outgoing entry') }
	document.set_viewport_rect(dom.Rect{12, 18, 320, 200})
	automatic := &SessionHistoryEntry{
		url: document.url
		document_state: outgoing.document_state
		scroll_position_data: SessionHistoryEntryScrollPositionData{
			viewport_scroll_position: dom.CSSPixelPoint_{ x_: 44, y_: 55 }
		}
	}
	model.activate_history_entry(automatic, document)
	saved := outgoing.scroll_position_data().viewport_scroll_position or {
		panic('outgoing viewport position was not saved')
	}
	assert saved.x() == 12
	assert saved.y() == 18
	assert model.viewport_scroll_offset().to_double_pair() == [44.0, 55.0]!

	manual := &SessionHistoryEntry{
		url: document.url
		document_state: outgoing.document_state
		scroll_restoration_mode: .manual
		scroll_position_data: SessionHistoryEntryScrollPositionData{
			viewport_scroll_position: dom.CSSPixelPoint_{ x_: 70, y_: 80 }
		}
	}
	model.activate_history_entry(manual, document)
	assert model.viewport_scroll_offset().to_double_pair() == [44.0, 55.0]!
}

fn test_navigation_does_not_install_response_after_navigable_destruction() {
	mut original_document, _, model_pointer := navigable_test_top_level('https://example.test/start', 'top')!
	mut model := unsafe { &NavigableModel(model_pointer) }
	navigable_test_destroy_during_fetch = model
	model.set_navigation_fetch_hook(navigable_test_fetch_and_destroy)
	model.navigate(NavigableNavigateParams{
		url: dom.URL{ value: 'https://example.test/fetched' }
		source_document: original_document
	})!
	navigable_test_destroy_during_fetch = unsafe { nil }

	assert model.has_been_destroyed()
	assert model.active_document()? == original_document
	assert model.get_session_history_entries().len == 1
}

fn test_non_fetch_scheme_navigation_hands_off_to_external_software_unless_sandboxed() {
	mut document := dom.Document.create(dom.URL{value: 'https://example.test/'})
	document.set_origin(document.url.origin())
	page_model := page.Page.create(1.0)!
	document.set_page(unsafe { &dom.Page(page_model) })
	mut parent_host := &dom.Navigable{
		is_top_level_traversable_: true
	}
	parent_host.set_active_document(document)
	parent_model := NavigableModel.create(parent_host, none)!
	assert attempt_to_create_a_non_fetch_scheme_document(&NonFetchSchemeNavigationParams{
		navigable: parent_model
		url: dom.URL{value: 'mailto:test@example.test'}
		initiator_origin: document.origin()
		source_has_transient_activation: true
	}) == none
	assert page_model.client().external_url_requests() == [
		page.ExternalURLRequest{
			url: 'mailto:test@example.test'
			initiator_origin: document.origin().value
			has_transient_activation: true
		},
	]

	mut child_document := dom.Document.create(dom.URL{value: 'https://example.test/frame'})
	child_document.set_page(unsafe { &dom.Page(page_model) })
	mut child_host := &dom.Navigable{
		parent_: parent_host
		container_document_: document
	}
	child_host.set_active_document(child_document)
	child_model := NavigableModel.create(child_host, none)!
	_ := attempt_to_create_a_non_fetch_scheme_document(&NonFetchSchemeNavigationParams{
		navigable: child_model
		url: dom.URL{value: 'mailto:frame@example.test'}
		target_snapshot_sandboxing_flags: SandboxingFlagSet{
			bits: u32(SandboxingFlag.sandboxed_custom_protocols)
		}
		initiator_origin: document.origin()
	})
	assert page_model.client().external_url_requests().len == 1
}

fn test_clicking_a_hyperlink_follows_it_in_its_navigable() {
	mut document, _, model_pointer := navigable_test_top_level('https://example.test/start', 'top')!
	mut model := unsafe { &NavigableModel(model_pointer) }
	model.set_navigation_fetch_hook(navigable_test_fetch)
	mut anchor := document.create_element_ns('http://www.w3.org/1999/xhtml', 'a')!
	anchor.set_attribute_value('href', '/fetched')
	anchor.set_attribute_value('referrerpolicy', 'no-referrer')
	navigable_test_referrer_policies = []string{}
	mut body := document.body() or { panic('missing body') }
	mut body_node := body.as_node()
	body_node.append_child(anchor.as_node())!

	html_element_click(unsafe { &dom.HTMLElement(anchor) })
	mut event_loop := main_thread_event_loop()
	for _ in 0 .. 8 {
		if active := model.active_document() {
			if active.url.serialize() == 'https://example.test/fetched' {
				break
			}
		}
		event_loop.process()
	}
	assert model.active_document()?.url.serialize() == 'https://example.test/fetched'
	// The navigation request carries the link's referrerpolicy attribute state.
	assert navigable_test_referrer_policies == ['no-referrer']
}

fn test_a_hyperlink_without_href_has_no_activation_behavior() {
	mut document, _, _ := navigable_test_top_level('https://example.test/start', 'top')!
	anchor := document.create_element_ns('http://www.w3.org/1999/xhtml', 'a')!
	assert !unsafe { &dom.EventTarget(anchor.as_node()) }.has_activation_behavior()
	area := document.create_element_ns('http://www.w3.org/1999/xhtml', 'area')!
	mut mutable_area := unsafe { &dom.Element(area) }
	mutable_area.set_attribute_value('href', '/map')
	assert unsafe { &dom.EventTarget(area.as_node()) }.has_activation_behavior()
}
