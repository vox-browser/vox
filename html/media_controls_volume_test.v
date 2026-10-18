module html

import css
import dom

@[heap]
struct VolumeControlsProbe {
mut:
	class_mutations int
}

fn volume_controls_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('Missing volume controls task') }
		assert task.source() == .media_element && task.document() == media.document()
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn volume_controls_owner(kind string, with_audio bool) !(&dom.Document, &HTMLMediaElement, &MediaControls) {
	url := dom.URL{value: 'https://volume-controls.example/'}
	mut document := parse_navigation_document('<!doctype html><${kind} id="player" preload="none"></${kind}>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('Missing volume owner') }
	mut media := html_media_element_for_dom_element(element) or { return error('Missing volume model') }
	media.set_volume(0.5)!
	if with_audio { media.on_audio_track_added(MediaTrackMetadata{identifier: 1}) }
	controls := MediaControls.create(media)
	volume_controls_drain(media)
	return document, media, controls
}

fn volume_controls_assert(controls &MediaControls, width string, low bool, high bool, muted bool) {
	fill := controls.dom_.volume_fill or { panic('Missing volume fill') }
	mut button := controls.dom_.mute_button or { panic('Missing mute button') }
	classes := button.class_list()
	assert css.element_style(fill).get_property_value('width') == width
	assert classes.contains('low') == low && classes.contains('high') == high
	assert classes.contains('muted') == muted && controls.was_muted == muted
}

fn test_volume_controls_preserve_styles_and_classes_across_icon_thresholds() {
	for kind in ['video', 'audio'] {
		mut document, mut media, mut controls := volume_controls_owner(kind, true)!
		defer { controls.remove_event_listeners(); document.finalize() }
		fill := controls.dom_.volume_fill or { panic('Missing volume fill') }
		mut button := controls.dom_.mute_button or { panic('Missing mute button') }
		mut style := css.element_style(fill)
		style.set_property('height', '3px', 'important')!
		mut classes := button.class_list()
		classes.add(['custom-icon', 'retained'])!
		for i, volume in [1.0, 0.75, 0.5, 0.25, 0.0, 0.125] {
			media.set_volume(volume)!
			volume_controls_drain(media)
			volume_controls_assert(controls, ['100%', '75%', '50%', '25%', '0%', '12.5%'][i], volume > 0 && volume <= 0.5, volume > 0.5, false)
			assert controls.volume_percentage == volume * 100 && controls.had_audio
			assert classes.contains('mute-button') && classes.contains('custom-icon') && classes.contains('retained')
			assert style.get_property_value('height') == '3px' && style.get_property_priority('height') == 'important'
		}
		assert media.current_src() == '' && media.paused() && !document.anything_is_delaying_the_load_event()
	}
}

fn test_volume_controls_follow_audio_presence_and_deferred_muting_without_losing_the_volume_icon() {
	mut document, mut media, mut controls := volume_controls_owner('video', false)!
	defer { controls.remove_event_listeners(); document.finalize() }
	volume_controls_assert(controls, '0px', true, false, true)
	assert !controls.had_audio && !media.muted() && controls.volume_percentage == 0
	media.set_fetch_hook(fn (_ dom.URL, _ u64) !MediaResourceResponse {
		return MediaResourceResponse{mime_type: 'audio/mpeg', duration: 60, buffered_end: 60,
			audio_tracks: [MediaTrackMetadata{identifier: 2, name: 'main'}]}
	})
	media.set_source('/audio.mp3')
	media.load()!
	volume_controls_assert(controls, '50%', true, false, false)
	assert controls.had_audio && controls.volume_percentage == 50
	volume_controls_drain(media)
	mut track := media.audio_tracks().item(0)?
	track.set_enabled(false)
	volume_controls_drain(media)
	assert controls.had_audio && !controls.was_muted // Presence, not enabledness, controls the indicator.
	before := media.event_count('volumechange')
	media.set_muted(true)
	volume_controls_assert(controls, '50%', true, false, false)
	assert media.event_count('volumechange') == before
	volume_controls_drain(media)
	volume_controls_assert(controls, '0px', true, false, true)
	assert media.event_count('volumechange') == before + 1 && controls.volume_percentage == 0
	media.set_volume(0.75)!
	volume_controls_drain(media)
	volume_controls_assert(controls, '0px', false, true, true)
	media.set_muted(false)
	volume_controls_drain(media)
	volume_controls_assert(controls, '75%', false, true, false)
	media.set_source(none)
	media.load()!
	assert media.audio_tracks().length() == 0 && controls.had_audio
	volume_controls_drain(media)
	volume_controls_assert(controls, '0px', false, true, true)
	assert !controls.had_audio && !media.muted() && controls.volume_percentage == 0
}

fn test_volume_controls_only_mutate_mute_button_classes_when_the_state_changes() {
	mut document, mut media, mut controls := volume_controls_owner('audio', true)!
	defer { controls.remove_event_listeners(); document.finalize() }
	mut button := controls.dom_.mute_button or { panic('Missing mute button') }
	mut classes := button.class_list()
	classes.add(['custom-icon'])!
	probe := &VolumeControlsProbe{}
	mut observer := dom.MutationObserver.construct_impl(&dom.CallbackType{
		mutation_callback: fn [probe, button] (records []&dom.MutationRecord, _ &dom.MutationObserver) {
			mut seen := unsafe { &VolumeControlsProbe(probe) }
			for record in records {
				assert record.target_() == button.as_node() && (record.attribute_name_() or { panic('Missing attribute name') }) == 'class'
				seen.class_mutations++
			}
		}
	})!
	defer { observer.disconnect() }
	mut options := dom.MutationObserverOptions{attributes: true, attribute_filter: ['class']}
	observer.observe(button.as_node(), mut options)!
	controls.update_volume_and_mute_indicator()
	media.set_volume(0.25)!
	volume_controls_drain(media)
	assert probe.class_mutations == 0
	volume_controls_assert(controls, '25%', true, false, false)
	media.set_volume(0.75)!
	volume_controls_drain(media)
	assert probe.class_mutations == 2 // Remove low, then add high.
	media.set_muted(true)
	volume_controls_drain(media)
	assert probe.class_mutations == 3
	controls.update_volume_and_mute_indicator()
	assert probe.class_mutations == 3 && classes.contains('custom-icon')
	media.set_volume(0)!
	volume_controls_drain(media)
	assert probe.class_mutations == 4 // Empty icon has no class token.
	volume_controls_assert(controls, '0px', false, false, true)
	controls.remove_event_listeners()
	media.set_muted(false)
	volume_controls_drain(media)
	assert probe.class_mutations == 4 && controls.was_muted
	controls.update_volume_and_mute_indicator()
	assert probe.class_mutations == 5
	volume_controls_assert(controls, '0%', false, false, false)
}

fn test_volume_controls_keep_numeric_icon_and_mute_state_without_dom_widgets() {
	mut media := HTMLMediaElement.create(none, dom.URL{value: 'https://ownerless-volume.example/'})
	mut controls := MediaControls.create(media)
	defer { controls.remove_event_listeners() }
	assert controls.dom_.volume_fill == none && controls.dom_.mute_button == none
	assert controls.mute_icon == .high && controls.was_muted && controls.volume_percentage == 0
	media.on_audio_track_added(MediaTrackMetadata{identifier: 3})
	assert controls.mute_icon == .high && !controls.was_muted && controls.volume_percentage == 100
	media.set_volume(0.5)!
	volume_controls_drain(media)
	assert controls.mute_icon == .low && controls.volume_percentage == 50
	media.set_muted(true)
	volume_controls_drain(media)
	assert controls.mute_icon == .low && controls.was_muted && controls.volume_percentage == 0
	media.set_volume(0)!
	volume_controls_drain(media)
	assert controls.mute_icon == .empty && controls.was_muted && controls.volume_percentage == 0
}
