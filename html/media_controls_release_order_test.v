module html

import css
import dom
import page
import platform

@[heap]
struct ReleaseOrderProbe {
mut:
	controls ?&MediaControls
	timer ?&platform.Timer
	armed bool
	flushes int
	cleared_at_flush bool
	timer_stopped_at_flush bool
	seeks_at_flush []f64
	seeks []f64
	plays int
	check_final_seek bool
}

fn release_order_style_finished(target voidptr, document &dom.Document) {
	mut probe := unsafe { &ReleaseOrderProbe(target) }
	if !probe.armed { return }
	probe.armed = false
	probe.flushes++
	controls := probe.controls or { panic('Missing release controls') }
	assert (controls.media.document() or { panic('Missing flush document') }) == document
	probe.cleared_at_flush = controls.scrubbing_timeline == .no
		&& controls.pending_scrub_seek_time_ == none && controls.scrub_seek_preemption_timer_ == none
	mut timer := probe.timer or { panic('Missing old release timer') }
	probe.timer_stopped_at_flush = !timer.is_active() && !timer.has_activity_root()
	// A nested native callback at the geometry flush must not submit the old pending target.
	timer.fire()
	probe.seeks_at_flush = probe.seeks.clone()
}

fn release_order_owner(kind string, playing bool) !(&dom.Document, &HTMLMediaElement, &MediaControls, &ReleaseOrderProbe) {
	owner := page.Page.create(1)!
	url := dom.URL{value: 'https://release-order.example/player/'}
	mut document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	parse_html_from_a_string(document, '<!doctype html><${kind} id="player" preload="none"></${kind}>')
	navigable := document.navigable() or { return error('Missing actual release navigable') }
	assert (navigable.active_document() or { return error('Missing actual active document') }) == document
	assert document.get_window() != none && document.get_browsing_context() != none
	css.install_document_style_hook(document)
	css.css_style_computer_for(document)
	element := document.get_element_by_id('player') or { return error('Missing release owner') }
	mut media := html_media_element_for_dom_element(element) or { return error('Missing release media') }
	media.set_duration(100)
	media.set_ready_state(.have_enough_data)
	media.network_state_ = .idle
	media.seekable_.add_range(0, 100)
	media.set_paused(!playing)
	media.set_show_poster(false)
	probe := &ReleaseOrderProbe{}
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		current_time: fn () f64 { return 0 }
		seek: fn [probe] (time f64, mode MediaPlaybackSeekMode) {
			mut state := unsafe { &ReleaseOrderProbe(probe) }
			assert mode == .accurate
			if state.check_final_seek {
				controls := state.controls or { panic('Missing final-seek controls') }
				assert controls.scrubbing_timeline == .no && controls.pending_scrub_seek_time_ == none
				assert controls.scrub_seek_preemption_timer_ == none
				assert !(state.timer or { panic('Missing final-seek timer') }).is_active()
			}
			state.seeks << time
		}
		play: fn [probe] () {
			mut state := unsafe { &ReleaseOrderProbe(probe) }
			state.plays++
		}
	})
	media.create_controls()
	controls := media.controls_ or { return error('Missing release controls') }
	mut state := unsafe { &ReleaseOrderProbe(probe) }
	state.controls = controls
	document.update_style()
	timeline := controls.dom_.timeline_element or { return error('Missing release timeline') }
	mut node := timeline.as_node()
	node.set_layout_node(&dom.LayoutNode{dom_node_: node, has_geometry_: true, border_box_: dom.Rect{0, 0, 100, 10}})
	document.set_layout_update_hook(dom.DocumentLayoutUpdateHook{target: probe, style_did_update: release_order_style_finished})
	return document, media, controls, probe
}

fn release_order_mouse(target &dom.EventTarget, name string, x f64, handled bool) {
	event := dom.MouseEvent.construct_impl(name, dom.MouseEventInit{client_x: x, bubbles: true, cancelable: true}) or { panic(err) }
	assert target.dispatch_event(unsafe { &dom.Event(event) }) == !handled
	assert event.default_prevented() == handled
}

fn release_order_begin(controls &MediaControls, probe &ReleaseOrderProbe) &dom.EventTarget {
	timeline := controls.dom_.timeline_element or { panic('Missing begin timeline') }
	document := controls.media.document() or { panic('Missing begin document') }
	window := document.get_window() or { panic('Missing begin Window') }
	target := unsafe { &dom.EventTarget(window) }
	release_order_mouse(unsafe { &dom.EventTarget(timeline.as_node()) }, 'mousedown', 25, true)
	release_order_mouse(target, 'mousemove', 70, true)
	assert probe.seeks == [25.0] && (controls.pending_scrub_seek_time_ or { panic('Missing pending target') }) == 70
	mut state := unsafe { &ReleaseOrderProbe(probe) }
	timer := controls.scrub_seek_preemption_timer_ or { panic('Missing active scrub timer') }
	state.timer = timer
	assert timer.is_active() && timer.has_activity_root()
	return target
}

fn test_timeline_release_clears_drag_and_timer_before_the_real_geometry_style_flush() {
	for kind in ['audio', 'video'] {
		for playing in [false, true] {
			mut document, mut media, controls, mut probe := release_order_owner(kind, playing)!
			defer { document.set_layout_update_hook(dom.DocumentLayoutUpdateHook{}); media.finalize(); document.finalize() }
			window := release_order_begin(controls, probe)
			probe.armed = true
			document.set_needs_full_style_update(true)
			release_order_mouse(window, 'mouseup', 90, true)
			assert probe.flushes == 1 && probe.cleared_at_flush && probe.timer_stopped_at_flush
			assert probe.seeks_at_flush == [25.0] && probe.seeks == [25.0, 90.0]
			assert controls.scrubbing_timeline == .no && controls.pending_scrub_seek_time_ == none
			assert controls.scrub_seek_preemption_timer_ == none && media.paused() == !playing
			assert probe.plays == if playing { 1 } else { 0 }
			release_order_mouse(window, 'mousemove', 10, false)
			assert probe.seeks == [25.0, 90.0]
		}
	}
}

fn test_timeline_release_without_a_range_still_clears_state_and_skips_geometry() {
	for playing in [false, true] {
		mut document, mut media, controls, mut probe := release_order_owner('audio', playing)!
		defer { document.set_layout_update_hook(dom.DocumentLayoutUpdateHook{}); media.finalize(); document.finalize() }
		window := release_order_begin(controls, probe)
		media.seekable_.clear()
		probe.armed = true
		document.set_needs_full_style_update(true)
		release_order_mouse(window, 'mouseup', 90, true)
		assert probe.flushes == 0 && probe.seeks == [25.0]
		assert controls.scrubbing_timeline == .no && controls.pending_scrub_seek_time_ == none
		assert controls.scrub_seek_preemption_timer_ == none && !probe.timer?.is_active()
		assert media.paused() == !playing && probe.plays == if playing { 1 } else { 0 }
	}
}

fn test_explicit_end_scrubbing_adapter_clears_state_before_its_final_backend_seek() {
	mut document, mut media, mut controls, mut probe := release_order_owner('audio', false)!
	defer { document.set_layout_update_hook(dom.DocumentLayoutUpdateHook{}); media.finalize(); document.finalize() }
	release_order_begin(controls, probe)
	probe.check_final_seek = true
	controls.end_timeline_scrubbing(90)
	assert probe.seeks == [25.0, 90.0] && probe.flushes == 0
	assert controls.scrubbing_timeline == .no && controls.pending_scrub_seek_time_ == none
	assert controls.scrub_seek_preemption_timer_ == none && !probe.timer?.is_active()
}
