module html

import dom

@[heap]
struct LazyVideoTrackProbe {
mut:
	events []string
	backend []string
}

fn lazy_video_track_document() !&dom.Document {
	url := dom.URL{value: 'https://lazy-video.example/base/page.html'}
	return parse_navigation_document('<!doctype html><video id="lazy" poster="cover.png" preload="none"></video><audio id="audio"></audio>', url, url.origin(), none)
}

fn lazy_video_track_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for _ in 0 .. 30 {
		if media.queued_media_task_ids_.len == 0 { return }
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('Missing lazy video task') }
		assert task.source() == .media_element
		assert task.document() == media.document()
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn test_first_selected_track_materializes_parsed_and_qualified_video_before_addtrack_and_backend() {
	for qualified in [false, true] {
		mut document := lazy_video_track_document()!
		defer { document.finalize() }
		element := if qualified {
			document.create_element_ns('http://www.w3.org/1999/xhtml', 'h:video')!
		} else {
			document.get_element_by_id('lazy') or { panic('Missing parsed video') }
		}
		owner := unsafe { &dom.HTMLVideoElement(element) }
		mut media := html_media_element_for_dom_element(element) or { panic('Missing lazy media') }
		assert owner.video_element_model_ == unsafe { nil } && media.video_element_model_ == none
		media.set_ready_state(.have_metadata)
		list := media.video_tracks()
		probe := &LazyVideoTrackProbe{}
		for name in ['addtrack', 'change'] {
			list.add_event_listener_without_options(name, dom.IDLEventListener.create(&dom.CallbackType{
				handle_event: fn [probe, media, owner, list] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
					assert voidptr(event.target() or { panic('Missing list target') }) == voidptr(&list.EventTarget)
					assert voidptr(current or { panic('Missing list callback target') }) == voidptr(&list.EventTarget)
					assert event.is_trusted() == (event.type_name() == 'change')
					video := media.video_element_model_ or { panic('Video must exist before addtrack') }
					assert voidptr(video) == owner.video_element_model_ && voidptr(video.media) == voidptr(media)
					assert video.video_width() == 320 && video.video_height() == 180
					assert (video.natural_media_size() or { panic('Missing intrinsic size') }) == VideoDimensions{320, 180}
					mut seen := unsafe { &LazyVideoTrackProbe(probe) }
					seen.events << event.type_name()
					return dom.js_undefined()
				}
			}))
		}
		media.set_on_event('resize', &dom.CallbackType{
			handle_event: fn [probe, media] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
				assert event.is_trusted()
				assert voidptr(event.target() or { panic('Missing resize target') }) == voidptr(media.event_target_)
				assert voidptr(current or { panic('Missing resize callback target') }) == voidptr(media.event_target_)
				assert media.event_count('resize') == 1
				mut seen := unsafe { &LazyVideoTrackProbe(probe) }
				seen.events << event.type_name()
				return dom.js_undefined()
			}
		})
		media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
			set_video_track: fn [media, probe] (track ?&VideoTrack) {
				selected := track or { panic('Missing first selected video') }
				video := media.video_element_model_ or { panic('Missing model before backend') }
				assert video.video_width() == 320
				assert voidptr(media.selected_video_track_sink() or { panic('Missing selected sink') }) == voidptr(selected)
				assert media.queued_media_task_ids_.len == 2
				mut seen := unsafe { &LazyVideoTrackProbe(probe) }
				seen.backend << selected.base.id
			}
		})
		mut first := media.on_video_track_added(MediaTrackMetadata{identifier: 1, pixel_width: 320, pixel_height: 180})
		video := media.video_element_model_ or { panic('Missing materialized video') }
		assert probe.events == ['addtrack'] && probe.backend == ['1']
		assert media.queued_media_task_ids_.len == 2 && media.event_count('resize') == 0
		assert video.poster_frame() == none && video.poster_fetch_generation_ == 0
		assert !document.anything_is_delaying_the_load_event() && media.network_state() == .empty && media.paused()
		assert voidptr(html_video_element_model_for_dom_element(owner)) == voidptr(video)
		first.set_selected(true)
		assert media.queued_media_task_ids_.len == 2
		lazy_video_track_drain(media)
		assert probe.events == ['addtrack', 'change', 'resize'] && media.queued_media_task_ids_.len == 0
		if qualified { assert video.poster_ == none } else { assert video.poster_? == 'cover.png' }
	}
}

fn test_lazy_first_selection_before_metadata_preserves_size_transitions_and_no_op_writes() {
	mut document := lazy_video_track_document()!
	defer { document.finalize() }
	owner := unsafe { &dom.HTMLVideoElement(document.get_element_by_id('lazy')?) }
	mut media := html_media_element_for_dom_element(unsafe { &dom.Element(owner) })?
	assert owner.video_element_model_ == unsafe { nil }
	mut first := media.on_video_track_added(MediaTrackMetadata{identifier: 1, pixel_width: 320, pixel_height: 180})
	mut second := media.on_video_track_added(MediaTrackMetadata{identifier: 2, pixel_width: 320, pixel_height: 180})
	mut third := media.on_video_track_added(MediaTrackMetadata{identifier: 3, pixel_width: 640, pixel_height: 360})
	video := media.video_element_model_ or { panic('Missing first video model') }
	assert video.video_width() == 0 && video.video_height() == 0
	assert video.natural_media_size()? == VideoDimensions{320, 180}
	assert media.queued_media_task_ids_.len == 2
	lazy_video_track_drain(media)
	assert media.event_count('resize') == 1
	media.set_ready_state(.have_metadata)
	assert video.video_width() == 320 && video.video_height() == 180 && media.queued_media_task_ids_.len == 0
	first.set_selected(true)
	second.set_selected(true)
	assert media.queued_media_task_ids_.len == 1
	lazy_video_track_drain(media)
	assert media.event_count('resize') == 1
	third.set_selected(true)
	assert media.queued_media_task_ids_.len == 2 && video.video_width() == 640 && video.video_height() == 360
	lazy_video_track_drain(media)
	assert media.event_count('resize') == 2
	third.set_selected(false)
	assert media.queued_media_task_ids_.len == 1 && video.natural_media_size() == none
	assert video.video_width() == 0 && video.video_height() == 0
	lazy_video_track_drain(media)
	assert media.event_count('resize') == 2 && voidptr(video) == owner.video_element_model_
}

fn test_audio_and_ownerless_video_tracks_do_not_acquire_a_dom_video_model() {
	mut document := lazy_video_track_document()!
	defer { document.finalize() }
	audio := html_media_element_for_dom_element(document.get_element_by_id('audio')?)?
	standalone := HTMLMediaElement.create(none, document.base_url())
	for owner in [audio, standalone] {
		mut media := unsafe { &HTMLMediaElement(owner) }
		defer { media.finalize() }
		mut track := media.on_video_track_added(MediaTrackMetadata{identifier: 7, pixel_width: 320, pixel_height: 180})
		assert track.selected && media.selected_video_track_sink()? == track
		assert media.video_element_model_ == none && media.queued_media_task_ids_.len == 1
		lazy_video_track_drain(media)
		track.set_selected(false)
		lazy_video_track_drain(media)
		assert media.video_element_model_ == none && media.event_count('resize') == 0
	}
	foreign := document.create_element_ns('http://www.w3.org/2000/svg', 'video')!
	assert html_media_element_for_dom_element(foreign) == none
}
