module html

import dom
import painting

@[heap]
struct LazyFrameProbe {
mut:
	frame ?&painting.MediaVideoFrame
	calls int
	resizes int
}

fn lazy_frame_document() !&dom.Document {
	url := dom.URL{value: 'https://lazy-frame.example/'}
	return parse_navigation_document('<!doctype html><video id="video" poster="cover.png" preload="none"></video><audio id="audio"></audio>', url, url.origin(), none)
}

fn lazy_frame_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for _ in 0 .. 20 {
		if media.queued_media_task_ids_.len == 0 { return }
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('Missing lazy frame task') }
		assert task.source() == .media_element && task.document() == media.document()
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn test_first_decoded_frame_materializes_the_actual_video_size_and_queues_one_resize() {
	for qualified in [false, true] {
		mut document := lazy_frame_document()!
		defer { document.finalize() }
		element := if qualified { document.create_element_ns('http://www.w3.org/1999/xhtml', 'h:video')! } else { document.get_element_by_id('video')? }
		owner := unsafe { &dom.HTMLVideoElement(element) }
		mut media := html_media_element_for_dom_element(element)?
		media.update_video_frame_and_timeline()
		assert owner.video_element_model_ == unsafe { nil } && media.video_frame_source_ == none
		mut probe := &LazyFrameProbe{}
		media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
			current_video_frame: fn [probe] () ?&painting.MediaVideoFrame {
				mut seen := unsafe { &LazyFrameProbe(probe) }
				seen.calls++
				return seen.frame
			}
		})
		media.set_on_event('resize', &dom.CallbackType{
			handle_event: fn [probe, media] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
				assert event.is_trusted() && !event.bubbles() && !event.cancelable()
				assert voidptr(event.target() or { panic('Missing resize target') }) == voidptr(media.event_target_)
				assert voidptr(current or { panic('Missing resize callback owner') }) == voidptr(media.event_target_)
				mut seen := unsafe { &LazyFrameProbe(probe) }
				seen.resizes++
				return dom.js_undefined()
			}
		})
		bitmap := &dom.Bitmap_{width: 2, height: 1, pitch: 8, data: [u8(255),0,0,255,0,255,0,255]}
		frame := painting.MediaVideoFrame.from_bitmap_with_color_space(bitmap, .display_p3)
		probe.frame = frame
		media.update_video_frame_and_timeline()
		video := media.video_element_model_ or { panic('Missing first frame video owner') }
		assert voidptr(video) == owner.video_element_model_ && voidptr(video.media) == voidptr(media)
		assert video.natural_media_size()? == VideoDimensions{2, 1}
		assert video.video_width() == 0 && video.video_height() == 0
		assert media.ensure_video_frame_source().current_frame()? == frame
		assert video.current_decoded_image_frame()?.bitmap() == bitmap
		assert video.current_decoded_image_frame()?.color_space() == .display_p3
		assert media.queued_media_task_ids_.len == 1 && probe.resizes == 0
		lazy_frame_drain(media)
		assert probe.resizes == 1 && probe.calls == 1
		media.set_ready_state(.have_metadata)
		assert video.video_width() == 2 && video.video_height() == 1
		media.update_video_frame_and_timeline()
		assert media.queued_media_task_ids_.len == 0 && probe.resizes == 1
		probe.frame = none
		media.update_video_frame_and_timeline()
		assert media.ensure_video_frame_source().current_frame() == none
		assert video.natural_media_size()? == VideoDimensions{2, 1}
		probe.frame = painting.MediaVideoFrame.from_bitmap(&dom.Bitmap_{width: 4, height: 2, pitch: 16, data: []u8{len: 32}})
		media.update_video_frame_and_timeline()
		assert video.video_width() == 4 && video.video_height() == 2 && media.queued_media_task_ids_.len == 1
		lazy_frame_drain(media)
		assert probe.resizes == 2 && probe.calls == 4
		assert voidptr(html_video_element_model_for_dom_element(owner)) == voidptr(video)
		assert video.poster_frame() == none && video.poster_fetch_generation_ == 0
		assert media.video_tracks().length() == 0 && media.selected_video_track_sink() == none
		assert media.paused() && media.network_state() == .empty && !document.anything_is_delaying_the_load_event()
	}
}

fn test_absent_frames_audio_and_ownerless_media_keep_their_existing_video_model_boundaries() {
	mut document := lazy_frame_document()!
	defer { document.finalize() }
	for kind in ['video', 'audio', 'ownerless'] {
		mut media := if kind == 'ownerless' { HTMLMediaElement.create(none, document.base_url()) } else { html_media_element_for_dom_element(document.get_element_by_id(kind)?)? }
		defer { media.finalize() }
		mut probe := &LazyFrameProbe{}
		media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
			current_video_frame: fn [probe] () ?&painting.MediaVideoFrame { return probe.frame }
		})
		media.update_video_frame_and_timeline()
		assert media.video_element_model_ == none && media.video_frame_source_ == none
		if kind == 'video' { continue }
		probe.frame = painting.MediaVideoFrame.from_bitmap(&dom.Bitmap_{width: 2, height: 1, pitch: 8, data: []u8{len: 8}})
		media.update_video_frame_and_timeline()
		assert media.ensure_video_frame_source().current_frame()? == probe.frame?
		assert media.video_element_model_ == none && media.queued_media_task_ids_.len == 0
		assert media.event_count('resize') == 0
	}
}
