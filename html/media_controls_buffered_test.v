module html

import css
import dom
import math

@[heap]
struct BufferedControlsProbe {
mut:
	ranges []MediaBufferedRange = [MediaBufferedRange{0, 20}, MediaBufferedRange{100, 125}]
	reads int
	progress int
	mutations int
}

fn buffered_controls_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('Missing buffered controls task') }
		assert task.source() == .media_element && task.document() == media.document()
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn buffered_controls_owner(kind string) !(&dom.Document, &HTMLMediaElement, &MediaControls, &BufferedControlsProbe) {
	url := dom.URL{value: 'https://buffered-controls.example/'}
	mut document := parse_navigation_document('<!doctype html><${kind} id="player" preload="none"></${kind}>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('Missing buffered controls owner') }
	mut media := html_media_element_for_dom_element(element) or { return error('Missing buffered media model') }
	media.set_duration(200)
	media.set_ready_state(.have_enough_data)
	media.seekable_.add_range(0, 20)
	media.seekable_.add_range(100, 200)
	media.set_current_playback_position(125)
	media.set_official_playback_position(125)
	probe := &BufferedControlsProbe{}
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		buffered_ranges: fn [probe] () []MediaBufferedRange {
			mut seen := unsafe { &BufferedControlsProbe(probe) }
			seen.reads++
			return seen.ranges
		}
	})
	controls := MediaControls.create(media)
	buffered_controls_drain(media)
	return document, media, controls, probe
}

fn buffered_controls_assert_segment(element &dom.Element, track &dom.Element, left string, width string) {
	assert element.local_name() == 'div' && element.is_html_element()
	assert element.get_attribute_value('class') == 'timeline-buffered'
	assert (element.as_node().parent() or { panic('Missing buffered segment parent') }) == track.as_node()
	style := css.element_style(element)
	assert style.get_property_value('display') == 'block'
	assert style.get_property_value('left') == left && style.get_property_value('width') == width
}

fn test_buffered_controls_project_live_ranges_reuse_nodes_and_remove_only_stale_segments() {
	for kind in ['video', 'audio'] {
		mut document, media, mut controls, mut probe := buffered_controls_owner(kind)!
		defer { controls.remove_event_listeners(); document.finalize() }
		track := controls.dom_.timeline_track or { panic('Missing timeline track') }
		fill := controls.dom_.timeline_fill or { panic('Missing timeline fill') }
		assert (fill.as_node().parent() or { panic('Missing playback fill parent') }) == track.as_node() && controls.timeline_percentage == 25
		first := controls.buffered_ranges_[0].element
		second := controls.buffered_ranges_[1].element
		assert track.as_node().children_as_vector() == [fill.as_node(), first.as_node(), second.as_node()]
		buffered_controls_assert_segment(first, track, '-100%', '20%')
		buffered_controls_assert_segment(second, track, '0%', '25%')
		mut style := css.element_style(first)
		style.set_property('height', '3px', '')!
		mut observer := dom.MutationObserver.construct_impl(&dom.CallbackType{
			mutation_callback: fn [probe] (records []&dom.MutationRecord, _ &dom.MutationObserver) {
				mut seen := unsafe { &BufferedControlsProbe(probe) }
				seen.mutations += records.len
			}
		})!
		defer { observer.disconnect() }
		mut options := dom.MutationObserverOptions{attributes: true, child_list: true, subtree: true}
		observer.observe(track.as_node(), mut options)!
		reads := probe.reads
		controls.update_timeline()
		assert probe.reads == reads + 1 && probe.mutations == 0
		probe.ranges = [MediaBufferedRange{0, 30}, MediaBufferedRange{120, 170}, MediaBufferedRange{180, 190}]
		controls.update_timeline()
		third := controls.buffered_ranges_[2].element
		assert controls.buffered_ranges_[0].element == first && controls.buffered_ranges_[1].element == second
		buffered_controls_assert_segment(first, track, '-100%', '30%')
		buffered_controls_assert_segment(second, track, '20%', '50%')
		buffered_controls_assert_segment(third, track, '80%', '10%')
		assert style.get_property_value('height') == '3px' && probe.mutations > 0
		probe.ranges = [MediaBufferedRange{110, 160}]
		controls.update_timeline()
		assert controls.buffered_ranges_.len == 1 && controls.buffered_ranges_[0].element == first
		assert second.as_node().parent() == none && third.as_node().parent() == none
		assert track.as_node().children_as_vector() == [fill.as_node(), first.as_node()]
		buffered_controls_assert_segment(first, track, '10%', '50%')
		probe.ranges.clear()
		controls.update_timeline()
		assert first.as_node().parent() == none && controls.buffered_ranges_.len == 0
		assert track.as_node().children_as_vector() == [fill.as_node()] && controls.timeline_percentage == 25
		assert media.current_src() == '' && media.paused() && !document.anything_is_delaying_the_load_event()
	}
}

fn test_buffered_controls_clear_invalid_last_seekable_ranges_and_recreate_segments_when_valid() {
	mut document, mut media, mut controls, _ := buffered_controls_owner('video')!
	defer { controls.remove_event_listeners(); document.finalize() }
	track := controls.dom_.timeline_track or { panic('Missing invalid-range track') }
	fill := controls.dom_.timeline_fill or { panic('Missing invalid-range fill') }
	for bad in ['missing', 'zero', 'reversed', 'nan', 'infinite'] {
		old := controls.buffered_ranges_.map(it.element)
		media.seekable_.clear()
		if bad != 'missing' {
			range_ := match bad {
				'zero' { MediaBufferedRange{1, 1} }
				'reversed' { MediaBufferedRange{3, 2} }
				'nan' { MediaBufferedRange{math.nan(), 2} }
				else { MediaBufferedRange{0, math.inf(1)} }
			}
			media.seekable_.add_range(range_.start, range_.end)
		}
		controls.update_timeline()
		assert controls.buffered_ranges_.len == 0 && controls.timeline_percentage == 0
		assert old.all(it.as_node().parent() == none)
		assert track.as_node().children_as_vector() == [fill.as_node()]
		media.seekable_.add_range(100, 200)
		controls.update_timeline()
		assert controls.buffered_ranges_.len == 2 && controls.timeline_percentage == 25
		assert controls.buffered_ranges_[0].element != old[0]
		buffered_controls_assert_segment(controls.buffered_ranges_[1].element, track, '0%', '25%')
	}
}

fn test_buffered_controls_follow_actual_media_source_progress_during_scrubbing_and_remove_the_listener() {
	for phase in [MediaControlsScrubbing.while_paused, .while_playing] {
		mut document, mut media, mut controls, probe := buffered_controls_owner('video')!
		defer { controls.remove_event_listeners(); document.finalize() }
		track := controls.dom_.timeline_track or { panic('Missing progress track') }
		fill := controls.dom_.timeline_fill or { panic('Missing progress fill') }
		media.set_current_playback_position(180)
		media.set_official_playback_position(180)
		controls.update_timeline()
		assert controls.timeline_percentage == 80
		controls.scrubbing_timeline = phase
		media.set_current_playback_position(125)
		media.set_official_playback_position(125)
		media.set_playback_manager_hooks(MediaPlaybackManagerHooks{})
		media.set_on_event('progress', &dom.CallbackType{
			handle_event: fn [media, controls, probe] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
				assert event.is_trusted() && !event.bubbles() && !event.cancelable()
				assert (event.target() or { panic('Missing progress target') }) == media.event_target()
				assert (current or { panic('Missing progress current target') }) == media.event_target() && controls.buffered_ranges_.len == 1
				mut seen := unsafe { &BufferedControlsProbe(probe) }
				seen.progress++
				return dom.js_undefined()
			}
		})
		media.media_source_update_buffered_ranges([MediaBufferedRange{100, 175}])
		assert probe.progress == 0 && controls.buffered_ranges_.len == 2
		buffered_controls_drain(media)
		assert probe.progress == 1 && media.event_count('progress') == 1
		assert controls.timeline_percentage == 80 && css.element_style(fill).get_property_value('width') == '80%'
		buffered_controls_assert_segment(controls.buffered_ranges_[0].element, track, '0%', '75%')
		controls.scrubbing_timeline = .no
		controls.update_timeline()
		assert controls.timeline_percentage == 25
		media.set_on_event('progress', none)
		controls.remove_event_listeners()
		assert controls.registered_event_listeners_.len == 0
		media.media_source_update_buffered_ranges_after_removal([MediaBufferedRange{100, 190}])
		media.process_media_data(.complete)
		assert media.event_count('progress') == 2
		buffered_controls_assert_segment(controls.buffered_ranges_[0].element, track, '0%', '75%')
	}
}

fn test_buffered_controls_keep_ownerless_numeric_controls_without_creating_dom_segments() {
	mut media := HTMLMediaElement.create(none, dom.url_about_blank())
	defer { media.finalize() }
	media.set_ready_state(.have_enough_data)
	media.seekable_.add_range(0, 100)
	media.buffered_.add_range(0, 50)
	media.set_current_playback_position(25)
	media.set_official_playback_position(25)
	mut controls := MediaControls.create(media)
	defer { controls.remove_event_listeners() }
	assert controls.timeline_percentage == 25 && controls.dom_.timeline_track == none
	assert controls.buffered_ranges_.len == 0
	controls.scrubbing_timeline = .while_paused
	media.seekable_.clear()
	controls.update_timeline()
	assert controls.timeline_percentage == 25 && controls.buffered_ranges_.len == 0
}
