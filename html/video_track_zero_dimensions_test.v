module html

import dom

@[heap]
struct ZeroVideoDimensionsProbe {
mut:
	events []string
}

fn zero_video_document() !&dom.Document {
	url := dom.URL{value: 'https://zero-video.example/'}
	return parse_navigation_document('<!doctype html><video id="video" preload="none"></video>', url, url.origin(), none)
}

fn zero_video_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for _ in 0 .. 30 {
		if media.queued_media_task_ids_.len == 0 { return }
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('Missing zero-size video task') }
		assert task.source() == .media_element && task.document() == media.document()
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn test_selected_tracks_keep_zero_axes_and_distinguish_present_zero_size_from_no_dimensions() {
	mut document := zero_video_document()!
	defer { document.finalize() }
	mut media := html_media_element_for_dom_element(document.get_element_by_id('video')?)?
	media.set_ready_state(.have_metadata)
	list := media.video_tracks()
	mut probe := &ZeroVideoDimensionsProbe{}
	for name in ['change', 'resize'] {
		target := if name == 'change' { &list.EventTarget } else { media.event_target_ }
		target.add_event_listener_without_options(name, dom.IDLEventListener.create(&dom.CallbackType{
			handle_event: fn [probe, target] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
				assert event.is_trusted() && !event.bubbles() && !event.cancelable()
				assert voidptr(event.target() or { panic('Missing zero-size target') }) == voidptr(target)
				assert voidptr(current or { panic('Missing zero-size callback target') }) == voidptr(target)
				mut seen := unsafe { &ZeroVideoDimensionsProbe(probe) }
				seen.events << event.type_name()
				return dom.js_undefined()
			}
		}))
	}
	dimensions := [VideoDimensions{320,180}, VideoDimensions{0,180}, VideoDimensions{640,0}, VideoDimensions{0,0}]
	mut tracks := []&VideoTrack{}
	for i, size in dimensions {
		tracks << media.on_video_track_added(MediaTrackMetadata{identifier: i64(i+1), pixel_width: size.width, pixel_height: size.height})
	}
	video := media.video_element_model_ or { panic('Missing actual zero-size model') }
	zero_video_drain(media)
	assert probe.events == ['change', 'resize']
	for i in 1 .. dimensions.len {
		probe.events.clear()
		mut track := tracks[i]
		track.set_selected(true)
		assert video.natural_media_size()? == dimensions[i] && video.natural_element_size()? == dimensions[i]
		assert video.video_width() == dimensions[i].width && video.video_height() == dimensions[i].height
		assert list.selected_index() == i32(i) && media.queued_media_task_ids_.len == 2
		zero_video_drain(media)
		assert probe.events == ['change', 'resize']
		track.set_selected(true)
		assert media.queued_media_task_ids_.len == 0
	}
	assert media.event_count('resize') == 4
	mut same_zero := media.on_video_track_added(MediaTrackMetadata{identifier: 5})
	probe.events.clear()
	same_zero.set_selected(true)
	assert media.queued_media_task_ids_.len == 1 && video.natural_media_size()? == VideoDimensions{0,0}
	zero_video_drain(media)
	assert probe.events == ['change'] && media.event_count('resize') == 4
	same_zero.set_selected(false)
	assert video.natural_media_size() == none && video.natural_element_size() == none
	zero_video_drain(media)
	assert media.event_count('resize') == 4
	mut zero := tracks[3]
	zero.set_selected(true)
	assert video.natural_media_size()? == VideoDimensions{0,0} && media.queued_media_task_ids_.len == 2
	zero_video_drain(media)
	assert media.event_count('resize') == 5 && media.video_tracks().length() == 5
	assert media.paused() && media.network_state() == .empty && !document.anything_is_delaying_the_load_event()
}

fn test_first_zero_axis_selection_and_model_seed_preserve_known_size_without_extra_notifications() {
	for size in [VideoDimensions{0,180}, VideoDimensions{640,0}, VideoDimensions{0,0}] {
		mut document := zero_video_document()!
		defer { document.finalize() }
		owner := unsafe { &dom.HTMLVideoElement(document.get_element_by_id('video')?) }
		mut media := html_media_element_for_dom_element(unsafe { &dom.Element(owner) })?
		assert owner.video_element_model_ == unsafe { nil }
		media.on_video_track_added(MediaTrackMetadata{identifier: 1, pixel_width: size.width, pixel_height: size.height})
		video := media.video_element_model_ or { panic('Missing initial zero-size owner') }
		assert video.natural_media_size()? == size && video.video_width() == 0 && video.video_height() == 0
		assert media.queued_media_task_ids_.len == 2
		zero_video_drain(media)
		media.set_ready_state(.have_metadata)
		assert video.video_width() == size.width && video.video_height() == size.height
		assert media.event_count('resize') == 1 && media.queued_media_task_ids_.len == 0
		mut standalone := HTMLMediaElement.create(none, document.base_url())
		defer { standalone.finalize() }
		standalone.on_video_track_added(MediaTrackMetadata{identifier: 2, pixel_width: size.width, pixel_height: size.height})
		zero_video_drain(standalone)
		seeded := HTMLVideoElementModel.create(standalone, document.base_url())
		assert seeded.natural_media_size()? == size && seeded.natural_element_size()? == size
		standalone.set_ready_state(.have_metadata)
		assert seeded.video_width() == size.width && seeded.video_height() == size.height
		assert standalone.queued_media_task_ids_.len == 0 && standalone.event_count('resize') == 0
	}
}
