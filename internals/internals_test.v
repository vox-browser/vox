module internals

import animations
import dom
import gamepad

fn test_metadata_settings_and_platform_facade() {
	mut platform := &PlatformState{
		headless_:        true
		current_cursor_:  'pointer'
		echo_server_port: 8000
	}
	navigator := gamepad.NavigatorGamepadPartial.new()
	mut api := Internals.create(platform, navigator)
	api.load_reference_test_metadata(DocumentMetadata{
		references: [ReferenceLink{'match', 'a.html'}, ReferenceLink{'mismatch', 'b.html'}]
		fuzzy:      [FuzzyMetadata{'a.html', '0-1;0-2'}]
	})
	assert platform.ref_metadata_json.contains('match_references')
	assert platform.ref_metadata_json.contains('a.html')
	api.load_test_variants(DocumentMetadata{ variants: ['?one', '?two'] })
	assert platform.test_variants_json == '["?one","?two"]'
	assert api.set_time_zone('Europe/Moscow')! == 'UTC'
	assert platform.time_zone == 'Europe/Moscow'
	api.set_test_timeout(2500)
	api.gc()
	assert platform.test_timeout_ms == 2500
	assert platform.garbage_collections == 1
	assert api.current_cursor() == 'pointer'
	assert api.headless()
	assert api.get_echo_server_port() == 8000
	api.set_echo_server_port(9000)
	assert api.get_echo_server_port() == 9000
	api.set_browser_zoom(1.25)
	api.set_device_pixel_ratio(2)
	assert platform.browser_zoom == 1.25
	assert platform.device_pixel_ratio == 2
	assert api.set_http_memory_cache_enabled(false)
	assert !platform.http_memory_cache_enabled
	api.expire_cookies_with_time_offset(60)
	assert platform.cookie_expiry_offset == 60
	api.spoof_current_url('https://example.test/a')!
	api.set_environments_top_level_url('https://example.test/')!
	assert platform.current_url.ends_with('/a')
	assert platform.top_level_url == 'https://example.test/'
	api.spoof_current_url('about:blank')!
	api.set_environments_top_level_url('about:blank')!
	assert platform.current_url == 'about:blank'
	assert platform.top_level_url == 'about:blank'
	if _ := api.spoof_current_url('relative/path') {
		assert false
	}
}

fn test_input_methods_record_exact_actions() {
	mut platform := &PlatformState{}
	navigator := gamepad.NavigatorGamepadPartial.new()
	mut api := Internals.create(platform, navigator)
	mut document := dom.Document.create_for_fragment_parsing()
	target := document.create_element('input')!
	api.send_text(target, 'A' + rune(0xe004).str(), mod_ctrl)
	api.send_key(target, 'Escape', mod_alt)
	api.paste(target, 'hello')
	api.commit_text()
	api.click(1, 2, 2, button_right, mod_shift)
	api.click_and_hold(3, 4, 1, button_left, 0)
	api.mouse_move(5, 6, mod_super)
	api.wheel(7, 8, -2, 3)
	api.pinch(9, 10, 1.5)
	api.simulate_drag_start(1, 1, 'text/plain', 'x')
	api.simulate_drag_move(2, 2)
	api.simulate_drop(3, 3)
	assert platform.input_actions[0].key == 'A'
	assert platform.input_actions[1].key == 'Tab'
	assert platform.input_actions[1].modifiers == mod_ctrl
	assert platform.input_actions[4].kind == .commit_text
	assert platform.input_actions[5].kind == .mouse_down
	assert platform.input_actions[6].kind == .mouse_up
	assert platform.input_actions.last().kind == .drop
	api.mouse_down(0, 0, 1, 99, 0)
	assert platform.input_actions.last().button == button_left
	assert api.button_from_unsigned_short(button_middle) == button_middle
}

fn test_dom_helpers_dumps_hit_testing_and_timeline() {
	mut platform := &PlatformState{
		display_list_dump:     'display'
		stacking_context_dump: 'stack'
		gc_graph_dump:         'graph'
		hit_test_result:       HitTestResult{
			index_in_node: 3
		}
	}
	navigator := gamepad.NavigatorGamepadPartial.new()
	mut api := Internals.create(platform, navigator)
	assert api.hit_test(1, 2)?.index_in_node == 3
	assert api.dump_display_list() == 'display'
	assert api.dump_layout_tree(none) == '(no layout node)'
	assert api.dump_paintable_tree(none) == '(no paintable)'
	assert api.dump_stacking_context_tree() == 'stack'
	assert api.dump_gc_graph() == 'graph'
	timeline := api.create_internal_animation_timeline()
	mut mutable_timeline := unsafe { &InternalAnimationTimeline(timeline) }
	mutable_timeline.set_time(42.0)
	assert timeline.current_time()?.value == 42
	mutable_timeline.set_time(none)
	assert timeline.current_time() == none
	assert timeline.duration() == none
	assert !timeline.can_sample_current_time_at_timestamp()
	mutable_timeline.set_time_for_observation(81.5)
	assert timeline.can_sample_current_time_at_timestamp()
	assert timeline.current_time_at_timestamp(123)?.value == 81.5
	assert timeline.current_time_for_observation()?.value == 81.5
	assert timeline.convert_a_timeline_time_to_an_origin_relative_time(animations.TimeValue.milliseconds(4)) == none
	event := dom.Event.new('activation')
	target := dom.EventTarget.new()
	assert api.dispatch_user_activated_event(target, event)!
	assert event.is_trusted()
	api.handle_sdl_input_events()
	assert platform.sdl_input_event_pumps == 1
}

fn test_computed_accessibility_values_and_form_clear_algorithm() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'button')!
	element.set_attribute_value('role', 'unknown img')
	element.set_attribute_value('aria-level', '003')
	mut node := element.as_node()
	node.append_child(document.create_text_node('Save').as_node())!
	mut platform := &PlatformState{}
	navigator := gamepad.NavigatorGamepadPartial.new()
	mut api := Internals.create(platform, navigator)
	element.remove_attribute('role')
	assert api.get_computed_role(element) == 'button'
	element.set_attribute_value('role', 'unknown img')
	assert api.get_computed_role(element) == 'image'
	// The ARIA image role does not allow a name to be derived from child content.
	assert api.get_computed_label(element) == ''
	element.remove_attribute('role')
	element.set_attribute_value('aria-label', 'Save')
	assert api.get_computed_label(element) == 'Save'
	assert api.get_computed_aria_level(element) == '3'
	element.set_attribute_value('aria-level', 'not-an-integer')
	assert api.get_computed_aria_level(element) == ''
	api.clear_element(mut element)
	assert element.as_node().text_content() or { '' } == 'Save'
}

fn test_style_invalidation_counters_include_full_document_invalidations() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut platform := &PlatformState{
		associated_document: document
	}
	navigator := gamepad.NavigatorGamepadPartial.new()
	mut api := Internals.create(platform, navigator)
	mut document_node := unsafe { &dom.Node(document) }
	document_node.invalidate_style(.other)
	document_node.invalidate_style(.settings_change)

	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut element_node := element.as_node()
	element_node.set_needs_style_update_internal(false)
	element_node.set_needs_style_update(true)

	counters := api.get_style_invalidation_counters()
	assert counters.full_style_invalidations == 2
	assert counters.style_invalidations == 1
	assert counters.element_style_recomputations == 0
	assert counters.element_inherited_style_recomputations == 0
	api.reset_style_invalidation_counters()
	assert api.get_style_invalidation_counters() == dom.StyleInvalidationCounters{}
}

fn test_style_invalidation_counters_count_previous_sibling_walks() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut platform := &PlatformState{
		associated_document: document
	}
	navigator := gamepad.NavigatorGamepadPartial.new()
	api := Internals.create(platform, navigator)
	mut parent := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut first := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	mut second := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	mut third := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	mut parent_node := parent.as_node()
	parent_node.append_child(first.as_node())!
	parent_node.append_child(second.as_node())!
	parent_node.append_child(third.as_node())!
	first.set_affected_by_last_child_pseudo_class(true)
	parent_node.set_entire_subtree_needs_style_update(false)
	mut third_node := third.as_node()
	third_node.set_entire_subtree_needs_style_update(false)
	document.set_needs_full_style_update(false)
	document.reset_style_invalidation_counters()

	third_node.invalidate_style(.node_remove)
	assert api.get_style_invalidation_counters().previous_sibling_invalidation_walk_visits == 2
}

fn test_previous_sibling_walk_is_skipped_without_backward_structural_dependencies() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut platform := &PlatformState{
		associated_document: document
	}
	navigator := gamepad.NavigatorGamepadPartial.new()
	api := Internals.create(platform, navigator)
	mut parent := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut first := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	mut second := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	mut parent_node := parent.as_node()
	parent_node.append_child(first.as_node())!
	parent_node.append_child(second.as_node())!
	parent_node.set_entire_subtree_needs_style_update(false)
	mut second_node := second.as_node()
	second_node.set_entire_subtree_needs_style_update(false)
	document.set_needs_full_style_update(false)
	document.reset_style_invalidation_counters()

	second_node.invalidate_style(.node_remove)
	assert api.get_style_invalidation_counters().previous_sibling_invalidation_walk_visits == 0
}
