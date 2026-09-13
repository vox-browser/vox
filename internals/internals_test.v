module internals

import animations
import bindings
import compositor
import css
import dom
import gamepad
import html
import loader
import painting
import xhr

fn test_metadata_settings_and_platform_facade() {
	mut platform := &PlatformState{
		headless_: true
		current_cursor_: 'pointer'
		echo_server_port: 8000
		visual_context_incremental_update_count: 4
		visual_context_pending_dirty_box_count: 2
		layout_tree_pre_order_label_violation_count: 3
		layout_tree_pre_order_relabel_count: 5
		visual_context_tree_node_count: 8
		visual_context_tree_dead_node_count: 1
		visual_context_tree_structural_epoch: 9
		visual_context_tree_node_capacity: 12
		partial_layout_count_: 6
		full_layout_count_: 7
		layout_run_cache_hit_count_: 10
		table_cell_measurement_cache_miss_count_: 11
		intrinsic_measurement_count_: 13
		accumulated_visual_context_tree_build_count_: 14
		recorded_display_list_blocks_wheel: true
		needs_repaint_: true
		needs_display_list_record_: true
		screen_wake_lock_active_: true
		stacking_context_verification_report: 'verified'
	}
	navigator := gamepad.NavigatorGamepadPartial.new()
	mut api := Internals.create(platform, navigator)
	api.load_reference_test_metadata(DocumentMetadata{
		references: [ReferenceLink{'match', 'a.html'}, ReferenceLink{'mismatch', 'b.html'}]
		fuzzy: [FuzzyMetadata{'a.html', '0-1;0-2'}]
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
	api.force_incompatible_visual_context_tree_rebuild()
	api.set_force_dark_enabled(true)
	api.set_show_line_box_borders(true)
	api.set_force_dark_thresholds(31, 47)
	api.send_mismatched_visual_context_tree_update_to_compositor()
	assert platform.visual_context_force_rebuilds == 1
	assert platform.force_dark_enabled && platform.show_line_box_borders
	assert platform.force_dark_foreground == 31 && platform.force_dark_background == 47
	assert platform.mismatched_visual_context_updates == 1
	assert api.accumulated_visual_context_incremental_update_count() == 4
	assert api.visual_context_pending_dirty_box_count() == 2
	assert api.layout_tree_pre_order_label_violation_count() == 3
	assert api.layout_tree_pre_order_relabel_count() == 5
	assert api.visual_context_tree_node_count() == 8
	assert api.visual_context_tree_dead_node_count() == 1
	assert api.visual_context_tree_structural_epoch() == 9
	assert api.visual_context_tree_node_capacity() == 12
	assert api.partial_layout_count() == 6 && api.full_layout_count() == 7
	assert api.layout_run_cache_hit_count() == 10
	assert api.table_cell_measurement_cache_miss_count() == 11
	assert api.intrinsic_measurement_count() == 13
	assert api.accumulated_visual_context_tree_build_count() == 14
	api.begin_display_list_trace()
	platform.display_list_trace = 'box:background\n'
	assert api.take_display_list_trace() == 'box:background\n'
	assert !platform.display_list_trace_active
	assert api.recorded_display_list_blocks_wheel_event_at(1, 2)
	api.record_display_list_for_testing(true, true)
	assert platform.record_display_list_requests == 1
	assert platform.last_record_display_list_paint_overlay
	assert platform.last_record_display_list_cold
	assert api.needs_repaint() && api.needs_display_list_record()
	assert api.screen_wake_lock_active()
	assert api.stacking_context_structure_verification_report() == 'verified'
	assert api.get_echo_server_port() == 8000
	api.set_echo_server_port(9000)
	assert api.get_echo_server_port() == 9000
	api.set_browser_zoom(1.25)
	api.set_device_pixel_ratio(2)
	assert platform.browser_zoom == 1.25
	assert platform.device_pixel_ratio == 2
	assert api.set_http_memory_cache_enabled(false)
	assert !platform.http_memory_cache_enabled
	api.simulate_request_server_connection_loss()
	api.simulate_worker_request_server_connection_loss()
	assert platform.request_server_connection_losses == 1
	assert platform.worker_request_server_connection_losses == 1
	api.expire_cookies_with_time_offset(60)
	assert platform.cookie_expiry_offset == 60
	platform.cookies << PlatformCookie{
		url: dom.URL{'https://example.test/account'}
		name: 'session'
		value: 'abc'
		path: '/account'
		secure: true
	}
	assert api.has_cookie_for_url('https://example.test/account/settings', 'session', 'abc')!
	assert !api.has_cookie_for_url('http://example.test/account/settings', 'session', 'abc')!
	assert !api.has_cookie_for_url('https://sub.example.test/account/settings', 'session', 'abc')!
	promise := api.delete_all_cookies()
	assert promise.state() == .fulfilled
	assert platform.cookies.len == 0
	if _ := api.has_cookie_for_url('relative/path', 'session', 'abc') {
		assert false
	}
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

fn test_runtime_gc_paint_wrapper_and_activity_diagnostics() {
	mut platform := &PlatformState{
		has_completed_initial_paint_: true
		initial_paint_had_pending_fonts_: true
	}
	navigator := gamepad.NavigatorGamepadPartial.new()
	mut api := Internals.create(platform, navigator)
	promise := dom.Promise.create()
	api.gc_async(promise)
	assert platform.garbage_collections == 0
	mut event_loop := html.main_thread_event_loop()
	event_loop.spin_until(fn [promise] () bool {
		return promise.state() != .pending
	})
	assert promise.state() == .fulfilled
	assert platform.garbage_collections == 1
	assert api.has_completed_initial_paint()
	assert api.initial_paint_had_pending_fonts()

	request := xhr.XMLHttpRequest.construct(.window, 'https://example.test/')
	platform.javascript_bindings['request'] = dom.js_object(voidptr(request))
	api.mark_as_garbage('request')!
	assert 'request' !in platform.javascript_bindings
	assert platform.garbage_binding_names == ['request']
	platform.javascript_bindings['number'] = dom.js_number(1)
	if _ := api.mark_as_garbage('number') {
		assert false
	}
	if _ := api.mark_as_garbage('missing') {
		assert false
	}

	face := css.FontFaceObject.construct_impl('InternalsFace', css.FontFaceSource.from_string('local(InternalsFace)'), css.FontFaceDescriptors{})
	api.set_font_display_time(face, 250)
	assert face.font_display_time_for_testing()? == 250

	realm := &html.ScriptingRealm{}
	mut world := bindings.WrapperWorld.create(.main)
	bindings.register_wrapper_world_for_realm(realm, world)
	mut implementation := bindings.Wrappable.create('Element', ['Node'])
	wrapper := bindings.wrap(mut world, realm, mut implementation)
	assert !api.wrapper_is_preserved(wrapper)
	bindings.preserve_wrapper(mut implementation, wrapper)
	assert api.wrapper_is_preserved(wrapper)

	mut activity_request := xhr.XMLHttpRequest.construct(.window, 'https://activity.test/')
	activity_request.activity_root_ = true
	assert api.has_activity_root(activity_request)
	activity_request.activity_root_ = false
	assert !api.has_activity_root(activity_request)
	mut document := dom.Document.create(dom.URL{'https://xhr-document.test/path'})
	document_request := api.create_xml_http_request_for_document(document)
	assert document_request.global_kind == .window
	assert document_request.base_url == 'https://xhr-document.test/path'
}

fn test_session_history_dumps_and_embedder_operations() {
	history := '{"entries":[{"step":8,"url":"https://example.test/first.html"},{"step":9,"url":"https://example.test/second.html?q=1#target"}],"usedSteps":[{"step":8,"current":false},{"step":9,"current":true}]}'
	mut platform := &PlatformState{
		accessibility_tree_dump: '{"role":"document"}'
		ui_process_session_history: history
		session_store_tab_state: '{"index":1}'
		site_isolation_process_tree: 'root\n  child\n'
	}
	navigator := gamepad.NavigatorGamepadPartial.new()
	mut api := Internals.create(platform, navigator)
	assert api.parser_non_append_insertions() == html.parser_non_append_insertions()
	assert api.dump_accessibility_tree() == '{"role":"document"}'
	assert api.dump_session_history() == '  step 0 first.html\n  step 1 second.html?q=1#target (current)\n'
	assert api.dump_ui_process_session_history() == history
	assert api.dump_ui_process_session_history_without_update() == history
	assert api.capture_session_history_snapshot()
	platform.ui_process_session_history = '{"entries":[],"usedSteps":[]}'
	assert api.restore_captured_session_history_snapshot()
	assert platform.ui_process_session_history == history
	assert api.register_session_store_tab()
	assert api.dump_session_store_tab_state() == '{"index":1}'
	assert api.dump_site_isolation_process_tree() == 'root\n  child\n'
	api.crash_remote_frame_processes()
	assert platform.remote_frame_process_crashes == 1
	promise := api.flush_session_history_traversal_queue()
	assert promise.state() == .fulfilled
	assert platform.session_history_traversal_queue_flushes == 1

	platform.ui_process_session_history = 'invalid'
	assert api.dump_session_history() == '(invalid UI process session history)'
	platform.ui_process_session_history = ''
	assert api.dump_session_history() == '(no navigable)'
}

fn test_media_element_state_controls_use_live_media_model() {
	mut platform := &PlatformState{}
	navigator := gamepad.NavigatorGamepadPartial.new()
	mut api := Internals.create(platform, navigator)
	media := html.HTMLMediaElement.create(none, dom.URL{'https://media.test/'})
	platform.page_media_elements << media
	mut mutable_media := unsafe { &html.HTMLMediaElement(media) }
	mutable_media.process_media_data(.ongoing)
	assert api.media_element_is_fetching(media)
	mutable_media.on_audio_track_added(html.MediaTrackMetadata{ identifier: 1 })
	api.set_media_element_ready_state(media, u16(html.MediaReadyState.have_future_data))
	assert media.ready_state() == .have_future_data
	api.set_media_element_ready_state(media, 99)
	assert media.ready_state() == .have_future_data
	api.set_media_element_paused(media, false)
	assert !media.paused()
	assert api.media_element_is_playing_audio(media)
	api.set_media_element_seeking(media, true)
	assert media.seeking()
	assert api.media_element_video_sink_is_ticking(media)
	api.set_page_muted(true)
	assert platform.page_muted
	assert !api.media_element_is_playing_audio(media)
	mutable_media.process_media_data(.complete)
	assert !api.media_element_is_fetching(media)
	api.set_geolocation_emulated_position(51.5, -0.12, 4.25)
	assert platform.geolocation_emulated_position.latitude == 51.5
	assert platform.geolocation_emulated_position.longitude == -0.12
	assert platform.geolocation_emulated_position.accuracy == 4.25
}

fn test_rendering_and_compositor_test_controls() {
	mut platform := &PlatformState{
		empty_animation_style_update_result: true
	}
	navigator := gamepad.NavigatorGamepadPartial.new()
	mut api := Internals.create(platform, navigator)
	api.reset_rendering_scheduler_counters()
	api.set_manual_rendering_opportunities(true)
	api.inject_rendering_opportunity(123.5)
	assert platform.manual_rendering_opportunities
	assert platform.last_injected_rendering_opportunity_ms == 123.5
	assert api.get_rendering_scheduler_counters().opportunities_received == 1
	api.update_compositor_animations()
	assert platform.compositor_animation_updates == 1
	assert api.run_empty_animation_style_update_for_testing()
	api.arm_compositor_animation_timers_for_testing()
	api.fire_compositor_animation_wakeup_for_testing(125)
	api.force_visual_context_tree_rebuild_on_next_compositor_animation_update_for_testing()
	mut document := dom.Document.create_for_fragment_parsing()
	node := document.create_element('div')!.as_node()
	api.request_reentrant_animation_style_flush_for_testing(node)
	assert platform.compositor_animation_timer_arms == 1
	assert platform.compositor_animation_wakeup_frame_time_ms == 125
	assert platform.force_visual_context_rebuild_on_animation
	assert platform.reentrant_animation_style_flush_node? == node
}

fn test_layout_and_style_engine_diagnostics_use_live_identities() {
	mut document := dom.Document.create_for_fragment_parsing()
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'main')!
	mut child := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	document.append_child(root)
	root.append_child(child)
	style := &dom.CSSComputedProperties_{}
	root.set_computed_properties(none, style)
	child.set_computed_properties(none, style)
	root_layout := &dom.LayoutNode{
		dom_node_: root.as_node()
		children_: [&dom.LayoutNode{}, &dom.LayoutNode{ dom_node_: child.as_node() }]
	}
	mut root_node := root.as_node()
	root_node.set_layout_node(root_layout)
	mut child_node := child.as_node()
	child_node.set_layout_node(root_layout.children_[1])
	document.set_layout_viewport(&dom.LayoutViewport{ root_node: root_layout })
	mut platform := &PlatformState{
		associated_document: document
		layout_tree_build_stats_: LayoutTreeBuildStats{3, 2, 1}
		incremental_layout_tree_dump: 'incremental'
		full_rebuild_layout_tree_dump: 'full'
		style_ffi_counters_: {
			'parse': u64(4)
		}
		style_engine_counters_: {
			'match': u64(7)
		}
		style_engine_transaction_reactions_: StyleEngineTransactionReactions{
			whole_document: false
			elements: ['main', 'span']
		}
		style_engine_document_match_count: 2
		style_engine_matched_rules_dump: 'main: .root\n'
	}
	navigator := gamepad.NavigatorGamepadPartial.new()
	mut api := Internals.create(platform, navigator)
	assert api.layout_tree_build_stats().builds == 3
	comparison := api.compare_layout_tree_with_full_rebuild()
	assert !comparison.matches
	assert comparison.incremental == 'incremental' && comparison.full == 'full'
	assert api.style_ffi_counters()['parse'] == 4
	assert api.style_engine_counters()['match'] == 7
	assert api.style_record_identity(root) == u64(voidptr(style))
	assert api.layout_style_record_identity(root) == api.style_record_identity(root)
	assert api.layout_node_identity(root.as_node()) == u64(voidptr(root_layout))
	assert api.layout_arena_live_slot_count() == 3
	assert api.layout_arena_shell_count() == 1
	assert !api.style_engine_transaction_reactions().whole_document
	assert api.style_engine_match_document() == 2
	assert api.style_engine_matched_rules() == 'main: .root\n'
	sharing := api.style_group_sharing_info(child)
	assert sharing['computedValues'].shared_with_parent
	before_stats := api.computed_values_stats()
	_ = css.ComputedProperties.new()
	after_stats := api.computed_values_stats()
	assert after_stats.total_instances_created == before_stats.total_instances_created + 1
	mut names := map[u64]string{}
	rule := &css.CSSRule{ type_: .font_face }
	collect_style_engine_rule_names([rule], mut names)
	assert names[u64(voidptr(rule))].starts_with('<rule ')
	api.reset_style_ffi_counters()
	assert platform.style_ffi_counters_enabled
	assert api.style_ffi_counters().len == 0
	api.update_style()
	assert platform.style_update_requests == 1
}

fn test_page_appearance_visibility_and_timer_controls() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/page' })
	mut platform := &PlatformState{
		associated_document: document
	}
	navigator := gamepad.NavigatorGamepadPartial.new()
	mut api := Internals.create(platform, navigator)

	api.set_user_style('body { color: green; }')
	assert platform.user_style_source == 'body { color: green; }'
	assert platform.user_style_invalidations == 1
	assert document.needs_full_style_update()

	api.set_preferred_color_scheme('dark')
	assert platform.preferred_color_scheme_override? == 'dark'
	assert api.canvas_color_scheme() == 'dark'
	assert platform.user_style_invalidations == 2
	api.set_preferred_color_scheme('auto')
	assert platform.preferred_color_scheme_override == none
	assert api.canvas_color_scheme() == 'light'

	api.set_page_focus(true)
	assert platform.page_has_focus
	api.set_system_visibility_state('hidden')
	assert platform.system_visibility_state == .hidden
	assert document.hidden()
	api.set_system_visibility_state('anything-else')
	assert platform.system_visibility_state == .visible
	assert !document.hidden()

	api.set_hidden_document_timer_wake_up_interval(250)
	api.set_hidden_document_intensive_timer_throttling(1000, 5000, 7000)
	assert platform.hidden_document_timer_wake_up_interval_ms == 250
	assert platform.hidden_document_intensive_wake_up_interval_ms == 1000
	assert platform.hidden_document_intensive_grace_period_once_loaded_ms == 5000
	assert platform.hidden_document_intensive_grace_period_while_loading_ms == 7000
}

fn test_image_animation_state_for_url_uses_shared_decoded_data() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/page' })
	mut platform := &PlatformState{
		associated_document: document
	}
	navigator := gamepad.NavigatorGamepadPartial.new()
	api := Internals.create(platform, navigator)
	url := document.encoding_parse_url('/animated.png') or { panic('failed to parse URL') }
	mut request := html.SharedResourceRequest.get_or_create(document, url)
	bitmap := &dom.Bitmap_{ width: 2, height: 1 }
	mut data := html.AnimatedDecodedImageData.create(91, 2, 4, 2, 1, .srgb, [u32(10), 20], [
		bitmap,
		bitmap,
	], none, none)
	data.register_client(3, fn () {})
	request.handle_successful_resource_load(data)

	state := api.image_animation_state_for_url('/animated.png')!
	assert state.timer_active
	assert state.session_id == 91
	assert state.frame_index == 0
	assert state.frame_count == 2
	assert state.loops_completed == 0
	assert state.loop_count == 4
	assert state.client_count == 1

	if _ := api.image_animation_state_for_url('http://[') {
		assert false
	} else {
		assert err.msg().contains('Invalid URL')
	}
	if _ := api.image_animation_state_for_url('/missing.png') {
		assert false
	} else {
		assert err.msg().contains('does not have any associated shared resource requests')
	}
	request.finalize()
	data.finalize()
}

fn test_async_scrolling_diagnostics_use_compositor_admission_logic() {
	mut document := dom.Document.create_for_fragment_parsing()
	context := compositor.ContextRef{1}
	list := &compositor.CompositorDisplayList{
		metadata: compositor.AsyncScrollingMetadata{
			viewport_rect: painting.IntRect{0, 0, 100, 100}
			wheel_event_listener_state_generation: 8
			has_blocking_wheel_event_listeners: true
		}
		commands: [compositor.CompositorDisplayListCommand(compositor.CompositorScrollNodeCommand{
			context: context
			document_id: 10
			scroll_node_index: 1
			scrollable_node_id: 20
			scrollport_rect: painting.IntRect{0, 0, 100, 100}
			max_scroll_offset: painting.Point{0, 100}
			is_viewport: true
			can_be_wheel_scrolled_vertically: true
		}), compositor.CompositorDisplayListCommand(compositor.CompositorWheelHitTestTargetCommand{
			context: context
			document_id: 10
			target_scroll_node_index: 1
			rect: painting.Rect{0, 0, 100, 100}
		}), compositor.CompositorDisplayListCommand(compositor.CompositorMainThreadWheelEventRegionCommand{
			context: context
			rect: painting.Rect{0, 0, 20, 20}
		}), compositor.CompositorDisplayListCommand(compositor.CompositorBlockingWheelEventRegionCommand{
			context: context
			rect: painting.Rect{30, 0, 20, 20}
		})]
		structural_epoch: 7
	}
	tree := &compositor.VisualContextTree{
		structural_epoch: 7
		valid_contexts: {
			1: true
		}
	}
	mut platform := &PlatformState{
		associated_document: document
		async_scrolling_display_list: list
		async_scrolling_visual_context_tree: tree
		async_scrolling_scroll_state_snapshot: compositor.CompositorScrollStateSnapshot{
			device_offsets: [painting.Point{}, painting.Point{}]
		}
		recorded_async_scrolling_display_list: list
	}
	navigator := gamepad.NavigatorGamepadPartial.new()
	api := Internals.create(platform, navigator)

	assert api.async_scrolling_state().scroll_nodes.len == 1
	assert api.async_scrolling_state_wheel_routing_admission() == 'accepted'
	assert api.async_scrolling_state_blocks_wheel_event_at(35, 5)
	assert api.async_scrolling_state_wheel_target_at(5, 5, 0, 10, true, .ongoing) == 'main-thread'
	assert api.async_scrolling_state_wheel_target_at(60, 5, 0, 10, true, .ongoing) == 'viewport'
	assert api.async_scrolling_state_can_wheel_scroll_at(60, 5, 0, 10, true, false)
	assert api.async_scrolling_state_wheel_scroll_admission_at(35, 5, 0, 10, true, false) == 'blocked-by-wheel-event-region'
	assert api.async_scrolling_state_wheel_scroll_admission_at(60, 5, 0, 10, true, true) == 'stale-blocking-wheel-event-regions'
	object := api.async_scrolling_state_object()
	assert object.scroll_node_count == 1
	assert object.scroll_nodes[0].is_viewport
	assert object.blocking_wheel_event_region_count == 1
	assert object.main_thread_wheel_event_region_count == 1
	assert object.wheel_event_listener_state_generation == 8
	assert api.recorded_async_scrolling_state_object().scroll_node_count == 1
}

fn test_content_and_site_compatibility_controls_update_runtime_services() {
	mut platform := &PlatformState{}
	navigator := gamepad.NavigatorGamepadPartial.new()
	mut api := Internals.create(platform, navigator)
	api.set_content_blockers('||ads.example^\r\n\nexample.com##.advert\r\n')!
	blocker := loader.ContentBlocker.the()
	assert blocker.has_rules()
	assert blocker.has_cosmetic_rules()
	assert platform.content_blockers_source == '||ads.example^\nexample.com##.advert\n'
	assert platform.user_style_invalidations == 1
	api.set_content_blocking_enabled(false)
	assert !blocker.filtering_enabled()
	assert !platform.content_blocking_enabled
	assert platform.user_style_invalidations == 2
	api.set_content_blocking_enabled(false)
	assert platform.user_style_invalidations == 2

	compatibility := '[{"matches":["https://example.test/*"],"user_agent":["hide_Ladybird"],"expose_experimental_interfaces":["PressureObserver"]}]'
	api.set_site_compatibility_data(compatibility)!
	resource_loader := loader.ResourceLoader.the()
	url := dom.URL{'https://example.test/page'}
	assert !resource_loader.user_agent_for_url(url).contains('Ladybird/')
	assert resource_loader.site_compatibility_exposes_experimental_interface(url, 'PressureObserver')
	assert platform.site_compatibility_source == compatibility
	if _ := api.set_site_compatibility_data('{broken') {
		assert false
	}

	api.set_experimental_interfaces_exposed(true)
	assert html.expose_experimental_interfaces()
	assert platform.experimental_interfaces_exposed
	api.set_autoplay_policy('block-audio-and-video')
	assert html.AutoplaySettings.the().policy() == .block_audio_and_video
	assert platform.autoplay_policy == 'block-audio-and-video'
	api.set_autoplay_policy('invalid')
	assert platform.autoplay_policy == 'block-audio-and-video'

	// Restore process-global test services for any later cases in this binary.
	api.set_content_blockers('')!
	api.set_content_blocking_enabled(true)
	api.set_experimental_interfaces_exposed(false)
	api.set_autoplay_policy('block-audio')
}

fn test_hsts_controls_use_resource_loader_policy_storage() {
	mut platform := &PlatformState{}
	navigator := gamepad.NavigatorGamepadPartial.new()
	mut api := Internals.create(platform, navigator)
	api.set_hsts_policy('internals-hsts.test', 120, true)!
	assert api.is_known_hsts_host('internals-hsts.test')!
	assert api.is_known_hsts_host('asset.internals-hsts.test')!
	policy := loader.ResourceLoader.the().hsts_policy_for_host('internals-hsts.test') or {
		panic('missing HSTS policy')
	}
	assert policy.max_age_seconds == 120
	assert policy.include_sub_domains
	api.set_hsts_policy('internals-hsts.test', 0, false)!
	assert !api.is_known_hsts_host('internals-hsts.test')!

	api.ingest_hsts_header('https://header-hsts.test/', 'max-age=45')!
	assert api.is_known_hsts_host('header-hsts.test')!
	assert !api.is_known_hsts_host('child.header-hsts.test')!
	api.ingest_hsts_header('not a URL', 'max-age=99')!
	api.ingest_hsts_header('https://header-hsts.test/', 'max-age=0')!
	assert !api.is_known_hsts_host('header-hsts.test')!
}

fn test_message_port_and_collection_diagnostics_use_live_objects() {
	mut platform := &PlatformState{}
	navigator := gamepad.NavigatorGamepadPartial.new()
	mut api := Internals.create(platform, navigator)
	mut channel := html.MessageChannel.construct_impl()!
	port1 := channel.port1()
	port2 := channel.port2()
	assert api.message_ports_are_directly_entangled(port1, port2)
	assert api.message_port_pending_outgoing_message_count(port1) == 0
	api.fail_next_message_port_transfer(port1)
	mut mutable_port := unsafe { &html.MessagePort(port1) }
	mutable_port.transfer_steps() or {
		assert err.msg().contains('Forced MessagePort transfer failure')
		assert api.message_ports_are_directly_entangled(port1, port2)
	}

	mut document := dom.Document.create_for_fragment_parsing()
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'main')!
	document.append_child(root)
	collection := document.get_elements_by_tag_name('*')
	initial_generation := api.html_collection_cache_generation(collection)
	assert initial_generation > 0
	root.append_child(document.create_element('span')!)
	assert collection.length() == 2
	assert api.html_collection_cache_generation(collection) == initial_generation + 1
	assert !api.has_shadow_root(root)
	shadow_root := root.attach_shadow(dom.ShadowRootInit{ mode: .open })!
	assert api.has_shadow_root(root)
	assert api.get_shadow_root(root)? == shadow_root
}

fn test_input_methods_record_exact_actions() {
	mut platform := &PlatformState{
		browser_zoom: 2
		selected_text_for_clipboard_: 'selected'
		current_caret_rect_: dom.Rect{1, 2, 3, 4}
	}
	navigator := gamepad.NavigatorGamepadPartial.new()
	mut api := Internals.create(platform, navigator)
	mut document := dom.Document.create_for_fragment_parsing()
	target := document.create_element('input')!
	api.send_text(target, 'A' + rune(0xe004).str(), mod_ctrl)
	api.send_key(target, 'Escape', mod_alt, 1)
	api.send_key(target, 'Repeat', mod_none, 2)
	api.paste(target, 'hello')
	api.paste_from_clipboard()
	api.commit_text()
	api.click(1, 2, 2, button_right, mod_shift)
	api.click_and_hold(3, 4, 1, button_left, 0)
	api.mouse_move(5, 6, mod_super)
	api.mouse_leave()
	api.wheel(7, 8, -2, 3, true, .momentum)
	api.pinch(9, 10, 1.5, mod_alt)
	api.set_marked_text_from_input_method('preedit')
	api.commit_text_from_input_method('done', -2, 1)
	api.unmark_text_from_input_method()
	api.simulate_drag_start(1, 1, 'text/plain', 'x')
	api.simulate_drag_move(2, 2)
	api.simulate_drop(3, 3)
	assert platform.input_actions[0].kind == .key_down
	assert platform.input_actions[0].key == 'A'
	assert platform.input_actions[1].kind == .key_up
	assert platform.input_actions[2].key == 'Tab'
	assert platform.input_actions[2].modifiers == mod_ctrl
	assert platform.input_actions.filter(it.kind == .key_down && it.key == 'Repeat').len == 2
	assert platform.input_actions.filter(it.kind == .key_up && it.key == 'Repeat').len == 1
	assert platform.input_actions.any(it.kind == .paste_from_clipboard)
	assert platform.input_actions.any(it.kind == .mouse_leave)
	wheel_action := platform.input_actions.filter(it.kind == .wheel)[0]
	assert wheel_action.precise && wheel_action.gesture == .momentum
	assert platform.input_actions.any(it.kind == .set_marked_text && it.text == 'preedit')
	assert platform.input_actions.any(it.kind == .commit_input_method_text && it.replacement_start == -2
		&& it.replacement_length == 1)
	assert platform.input_actions.any(it.kind == .unmark_text)
	assert platform.input_actions.last().kind == .drop
	assert api.selected_text_for_clipboard() == 'selected'
	api.set_clipboard_file('note.txt', 'text/plain', 'hello')
	assert platform.clipboard_file?.name == 'note.txt'
	assert api.current_caret_rect()? == dom.Rect{1, 2, 3, 4}
	api.reset_zoom()
	assert platform.browser_zoom == 1
	api.load_url('https://example.test/next')!
	assert platform.loaded_urls == ['https://example.test/next']
	api.mouse_down(0, 0, 1, 99, 0)
	assert platform.input_actions.last().button == button_left
	assert api.button_from_unsigned_short(button_middle) == button_middle
}

fn test_dom_helpers_dumps_hit_testing_and_timeline() {
	mut platform := &PlatformState{
		display_list_dump: 'display'
		stacking_context_dump: 'stack'
		gc_graph_dump: 'graph'
		hit_test_result: HitTestResult{
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
