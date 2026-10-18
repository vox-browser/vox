module html

import css
import dom

@[heap]
struct VolumeAreaMutationProbe {
mut:
	classes int
	styles int
}

fn volume_area_owner(kind string, with_audio bool) !(&dom.Document, &HTMLMediaElement, &MediaControls) {
	url := dom.URL{value: 'https://volume-area.example/player/'}
	document := parse_navigation_document('<!doctype html><${kind} id="player" preload="none"></${kind}>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('Missing volume-area owner') }
	mut media := html_media_element_for_dom_element(element) or { return error('Missing volume-area media') }
	if with_audio { media.on_audio_track_added(MediaTrackMetadata{identifier: 1}) }
	media.create_controls()
	return document, media, media.controls_ or { return error('Missing volume-area controls') }
}

fn volume_area_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('Missing volume-area task') }
		assert task.source() == .media_element && task.document() == media.document()
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn test_volume_area_initial_visibility_uses_the_embedded_hidden_class_rule() {
	for kind in ['audio', 'video'] {
		for with_audio in [false, true] {
			mut document, mut media, controls := volume_area_owner(kind, with_audio)!
			defer { media.finalize(); document.finalize() }
			mut area := controls.dom_.volume_area?
			assert area.class_list().contains('volume-area')
			assert area.class_list().contains('hidden') == !with_audio
			assert controls.had_audio == with_audio
			assert area.get_attribute('style') == none
			assert css.computed_value_for(area, .display)? == if with_audio { 'block' } else { 'none' }
			assert (controls.owned_shadow_root_?).host()? == document.get_element_by_id('player')?
		}
	}
}

fn test_volume_area_preserves_inline_declarations_and_identity_through_track_and_load_changes() {
	for kind in ['audio', 'video'] {
		mut document, mut media, controls := volume_area_owner(kind, false)!
		defer { media.finalize(); document.finalize() }
		mut area := controls.dom_.volume_area?
		mut classes := area.class_list()
		classes.add(['retained', 'custom-volume-area'])!
		mut style := css.element_style(area)
		style.set_property('max-width', '44px', 'important')!
		style.set_property('color', 'rgb(1, 2, 3)', '')!
		attribute := area.get_attribute_node('style')?
		raw := attribute.value()
		media.set_fetch_hook(fn (_ dom.URL, _ u64) !MediaResourceResponse {
			return MediaResourceResponse{mime_type: 'audio/mpeg', duration: 60, buffered_end: 60,
				audio_tracks: [MediaTrackMetadata{identifier: 2}]}
		})
		media.set_source('/track.mp3')
		media.load()!
		volume_area_drain(media)
		assert controls.had_audio && !classes.contains('hidden')
		assert css.computed_value_for(area, .display)? == 'block'
		mut track := media.audio_tracks().item(0)?
		track.set_enabled(false)
		media.set_muted(true)
		media.set_volume(0)!
		volume_area_drain(media)
		assert controls.had_audio && !classes.contains('hidden')
		// Actual load reset empties the list; its queued emptied event hides the area.
		media.set_source(none)
		media.load()!
		assert media.audio_tracks().length() == 0 && controls.had_audio
		volume_area_drain(media)
		assert !controls.had_audio && classes.contains('hidden')
		assert css.computed_value_for(area, .display)? == 'none'
		media.on_audio_track_added(MediaTrackMetadata{identifier: 3})
		volume_area_drain(media)
		assert controls.had_audio && !classes.contains('hidden')
		assert controls.dom_.volume_area? == area
		assert area.get_attribute_node('style')? == attribute && attribute.value() == raw
		assert style.get_property_value('max-width') == '44px' && style.get_property_priority('max-width') == 'important'
		assert style.get_property_value('color') == 'rgb(1, 2, 3)'
		assert classes.contains('retained') && classes.contains('custom-volume-area')
	}
}

fn test_volume_area_only_mutates_classes_when_audio_presence_changes() {
	mut document, mut media, mut controls := volume_area_owner('audio', true)!
	defer { media.finalize(); document.finalize() }
	volume_area_drain(media)
	mut area := controls.dom_.volume_area?
	probe := &VolumeAreaMutationProbe{}
	mut observer := dom.MutationObserver.construct_impl(&dom.CallbackType{
		mutation_callback: fn [probe, area] (records []&dom.MutationRecord, _ &dom.MutationObserver) {
			mut observed := unsafe { &VolumeAreaMutationProbe(probe) }
			for record in records {
				assert record.target_() == area.as_node()
				match record.attribute_name_() or { panic('Missing area attribute name') } {
					'class' { observed.classes++ }
					'style' { observed.styles++ }
					else { panic('Unexpected area mutation') }
				}
			}
		}
	})!
	defer { observer.disconnect() }
	mut options := dom.MutationObserverOptions{attributes: true, attribute_filter: ['class', 'style']}
	observer.observe(area.as_node(), mut options)!
	for _ in 0 .. 3 { controls.update_volume_and_mute_indicator() }
	document.notify_mutation_observers()
	assert probe.classes == 0 && probe.styles == 0
	mut tracks := media.audio_tracks()
	tracks.remove_all_tracks()
	media.fire_event('volumechange')
	document.notify_mutation_observers()
	assert probe.classes == 1 && probe.styles == 0 && !controls.had_audio
	for _ in 0 .. 3 { controls.update_volume_and_mute_indicator() }
	document.notify_mutation_observers()
	assert probe.classes == 1 && probe.styles == 0
	media.on_audio_track_added(MediaTrackMetadata{identifier: 4})
	volume_area_drain(media)
	document.notify_mutation_observers()
	assert probe.classes == 2 && probe.styles == 0 && controls.had_audio
	// Source caches presence: unrelated refreshes do not repair an externally changed token.
	mut classes := area.class_list()
	classes.add(['hidden', 'retained'])!
	document.notify_mutation_observers()
	before := probe.classes
	controls.update_volume_and_mute_indicator()
	document.notify_mutation_observers()
	assert probe.classes == before && probe.styles == 0
	assert classes.contains('hidden') && classes.contains('retained')
}
