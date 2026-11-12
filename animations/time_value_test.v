module animations

import dom
import html

fn test_time_value_units_and_arithmetic() {
	time := TimeValue.milliseconds(250)
	assert time.str() == '250.0ms'
	assert time.add(TimeValue.milliseconds(50))!.value == 300
	assert time.multiply(2).value == 500
	assert time.ratio(TimeValue.milliseconds(125))! == 2
	if _ := time.add(TimeValue.percentage(10)) {
		assert false
	} else {
		assert err.msg().contains('different units')
	}
}

fn test_document_and_scroll_timeline_time_values() {
	mut document_timeline := new_document_timeline(none, 25, 100)
	document_timeline.set_document_active(true)
	assert (document_timeline.current_time() or { panic('missing value') }).value == 75
	document_timeline.update_current_time(125)
	assert (document_timeline.current_time() or { panic('missing value') }).value == 100
	origin_time := document_timeline.convert_to_origin_relative_time(TimeValue.milliseconds(10)) or {
		assert false
		return
	}
	assert origin_time == 35

	mut scroll := new_scroll_timeline(.y)
	scroll.update_from_scroll_metrics(.y, ScrollMetrics{
		is_scroll_container: true
		has_overflow:        true
		scroll_y:            250
		overflow_height:     1000
		container_height:    500
	})
	assert (scroll.current_time() or { panic('missing value') }).type_ == .percentage
	assert (scroll.current_time() or { panic('missing value') }).value == 50
}

fn test_document_updates_every_associated_timeline_and_honors_disassociation() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	document.set_browsing_context(&dom.BrowsingContext{
		active_document_: document
	})
	mut first := new_document_timeline(document, 10, 100)
	mut second := new_document_timeline(document, 20, 100)

	document.update_animations_and_send_events(150)
	assert (first.current_time() or { panic('missing value') }).value == 140
	assert (second.current_time() or { panic('missing value') }).value == 130

	second.set_associated_document(none)
	document.update_animations_and_send_events(200)
	assert (first.current_time() or { panic('missing value') }).value == 190
	assert (second.current_time() or { panic('missing value') }).value == 130
}

fn test_timeline_style_sampling_override_preserves_underlying_time() {
	mut timeline := AnimationTimeline.new()
	timeline.set_current_time(TimeValue.milliseconds(25))
	assert (timeline.effective_current_time() or { panic('missing value') }).value == 25

	timeline.set_current_time_override_for_style_sampling(TimeValue.milliseconds(80))
	assert (timeline.current_time() or { panic('missing value') }).value == 80
	timeline.set_current_time_override_for_style_sampling(none)
	assert timeline.is_inactive()
	timeline.clear_current_time_override_for_style_sampling()
	assert (timeline.current_time() or { panic('missing value') }).value == 25
}

fn test_timeline_current_time_observation_is_stable_within_a_task() {
	mut timeline := new_document_timeline(none, 25, 100)
	timeline.set_document_active(true)
	mut effect := KeyframeEffect.create()
	_ = Animation.create(effect.as_animation_effect(), timeline)
	effect.set_is_compositor_driven(true)

	mut event_loop := html.main_thread_event_loop()
	event_loop.process()
	first := timeline.current_time_for_observation() or {
		assert false
		return
	}
	timeline.monotonic_timestamp_offset_ -= 1000
	second := timeline.current_time_for_observation() or {
		assert false
		return
	}
	assert second == first

	event_loop.process()
	third := timeline.current_time_for_observation() or {
		assert false
		return
	}
	assert third.value > first.value + 900
}

fn test_timeline_time_update_updates_associated_animations() {
	mut timeline := AnimationTimeline.new()
	timeline.set_current_time(TimeValue.milliseconds(100))
	timeline.monotonic_ = true
	mut effect := AnimationEffect.new()
	effect.update_timing(OptionalEffectTiming{
		fill: .both
		duration: IterationDuration(1000.0)
	})!
	mut animation := Animation.create(effect, timeline)
	animation.play()!
	assert animation.pending()

	timeline.set_current_time(TimeValue.milliseconds(200))
	assert !animation.pending()
	assert animation.play_state() == .running
}

fn test_document_timeline_constructor_uses_the_latest_animation_frame() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{
		active_document_: document
	})
	document.update_animations_and_send_events(250)
	timeline := DocumentTimeline.create_for_constructor(document, DocumentTimelineOptions{
		origin_time: 25
	})
	assert (timeline.current_time() or { panic('missing value') }).value == 225
	assert timeline.is_monotonically_increasing()
}

fn test_scroll_timeline_constructor_metrics_and_staleness() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut root := document.create_element('html')!
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node())!
	metrics := ScrollMetrics{
		is_scroll_container: true
		has_overflow: true
		scroll_x: 100
		overflow_width: 600
		container_width: 200
		writing_mode: .horizontal_tb
		direction: .ltr
	}
	mut timeline := ScrollTimeline.create_for_constructor(document, ScrollTimelineOptions{
		axis: .x
	}, metrics)
	assert (timeline.source() or { panic('missing default source') }) == root
	assert (timeline.current_time() or { panic('missing value') }).value == 25
	assert !timeline.is_stale()
	assert scroll_axis_from_css_axis(.inline_) == .inline_

	offset_data := compute_scroll_offset_data(metrics, .x) or { panic('missing offsets') }
	assert offset_data.scroll_offset == 100
	assert offset_data.max_scroll_offset == 400
	timeline.scroll_metrics_ = ScrollMetrics{
		...metrics
		overflow_width: 1000
	}
	assert timeline.is_stale()
	timeline.update_current_time(0)
	assert !timeline.is_stale()
	assert (timeline.current_time() or { panic('missing value') }).value == 12.5

	explicit_null := ScrollTimeline.create_for_constructor(document, ScrollTimelineOptions{
		source_is_present: true
		source: none
	}, metrics)
	assert explicit_null.source() == none
}
