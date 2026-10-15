module html

import dom
import webidl

@[heap]
struct FatalLoadDelayObservation {
mut:
	calls int
}

fn fatal_load_delay_owner(kind string, loaded bool) !&HTMLMediaElement {
	url := dom.URL{ value: 'https://fatal-load-delay.example.test/' }
	document := parse_navigation_document('<${kind} id="player"></${kind}>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('missing fatal-delay player') }
	mut media := html_media_element_for_dom_element(element) or { return error('missing fatal-delay owner') }
	media.set_fetch_hook(fn (_ dom.URL, _ u64) !MediaResourceResponse {
		return MediaResourceResponse{ mime_type: 'video/mp4', duration: 20 }
	})
	if loaded {
		media.set_source('/metadata.mp4')
		media.load()!
		fatal_load_delay_drain(media)
		assert media.ready_state() == .have_metadata && media.network_state() == .idle
	}
	return media
}

fn fatal_load_delay_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for media.queued_media_task_ids_.len > 0 {
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('missing fatal-delay owner task') }
		assert task.source() == media.media_element_event_task_source()
		task.execute()
	}
}

fn fatal_load_delay_pending_batch(media &HTMLMediaElement) []&dom.Promise {
	document := media.document() or { panic('missing fatal-delay document') }
	settings := unsafe { &EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut promises := []&dom.Promise{}
	for _ in 0 .. 2 {
		mut native := webidl.create_promise_for(settings.stream_promise_context())
		native.mark_as_handled()
		promises << dom.Promise.from_webidl(native)
	}
	return promises
}

fn test_decoder_failure_releases_its_load_delay_before_error_and_duplicate_errors_preserve_a_later_delay() {
	for kind in ['audio', 'video'] {
		mut media := fatal_load_delay_owner(kind, true)!
		mut document := media.document()?
		mut independent := dom.DocumentLoadEventDelayer.new(mut document)
		defer {
			media.remove_queued_media_element_tasks()
			media.finish_delaying_load_event()
			independent.finish()
			media.finalize()
		}
		media.begin_delaying_load_event()
		seen := &FatalLoadDelayObservation{}
		media.set_on_event('error', &dom.CallbackType{
			handle_event: fn [media, document, seen] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
				mut observation := unsafe { &FatalLoadDelayObservation(seen) }
				observation.calls++
				assert media.delaying_load_event_ == none && document.anything_is_delaying_the_load_event()
				failure := media.error() or { panic('missing fatal decode error') }
				assert failure.code == .decode && failure.message == 'corrupt decoded frame'
				assert media.network_state() == .idle && media.ready_state() == .have_metadata
				assert voidptr(event.target() or { panic('missing error target') }) == voidptr(media.event_target())
				assert voidptr(current or { panic('missing error current target') }) == voidptr(media.event_target())
				assert event.is_trusted() && !event.bubbles() && !event.cancelable()
				return dom.js_undefined()
			}
		})
		generation := media.fetch_generation_
		media.set_decoder_error('corrupt decoded frame')
		assert seen.calls == 1 && media.event_count('error') == 1
		assert media.fetch_generation_ == generation + 1 && media.delaying_load_event_ == none
		media.begin_delaying_load_event()
		media.set_decoder_error('a later duplicate')
		assert seen.calls == 1 && media.error()?.message == 'corrupt decoded frame'
		assert media.fetch_generation_ == generation + 1 && media.delaying_load_event_ != none
		media.finish_delaying_load_event()
		assert document.anything_is_delaying_the_load_event()
		independent.finish()
		assert !document.anything_is_delaying_the_load_event()
	}
}

fn test_interrupted_download_releases_its_metadata_delay_before_error_but_has_nothing_is_unchanged() {
	for kind in ['audio', 'video'] {
		mut fresh := fatal_load_delay_owner(kind, false)!
		defer {
			fresh.remove_queued_media_element_tasks()
			fresh.finish_delaying_load_event()
			fresh.finalize()
		}
		fresh.begin_delaying_load_event()
		generation := fresh.fetch_generation_
		fresh.process_media_data(.interrupted)
		assert fresh.ready_state() == .have_nothing && fresh.network_state() == .empty
		assert fresh.error() == none && fresh.event_count('error') == 0
		assert fresh.fetch_generation_ == generation && fresh.delaying_load_event_ != none
		assert fresh.document()?.anything_is_delaying_the_load_event()
		fresh.finish_delaying_load_event()
		assert !fresh.document()?.anything_is_delaying_the_load_event()
		mut media := fatal_load_delay_owner(kind, true)!
		mut document := media.document()?
		mut independent := dom.DocumentLoadEventDelayer.new(mut document)
		defer {
			media.remove_queued_media_element_tasks()
			media.finish_delaying_load_event()
			independent.finish()
			media.finalize()
		}
		media.begin_delaying_load_event()
		seen := &FatalLoadDelayObservation{}
		media.set_on_event('error', &dom.CallbackType{
			handle_event: fn [media, document, seen] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
				mut observation := unsafe { &FatalLoadDelayObservation(seen) }
				observation.calls++
				assert media.delaying_load_event_ == none && document.anything_is_delaying_the_load_event()
				failure := media.error() or { panic('missing fatal network error') }
				assert failure.code == .network && failure.message == 'Connection interrupted'
				assert media.network_state() == .idle && media.ready_state() == .have_metadata
				return dom.js_undefined()
			}
		})
		media.process_media_data(.interrupted)
		assert seen.calls == 1 && media.event_count('error') == 1
		assert media.delaying_load_event_ == none && document.anything_is_delaying_the_load_event()
		independent.finish()
		assert !document.anything_is_delaying_the_load_event()
	}
}

fn test_source_failure_holds_the_adopted_delay_through_error_then_rejects_and_releases_only_its_blocker() {
	for kind in ['audio', 'video'] {
		mut media := fatal_load_delay_owner(kind, true)!
		mut old_document := media.document()?
		mut old_independent := dom.DocumentLoadEventDelayer.new(mut old_document)
		media.begin_delaying_load_event()
		url := dom.URL{ value: 'https://adopted-fatal-load-delay.example.test/' }
		mut document := parse_navigation_document('<body></body>', url, url.origin(), none)!
		mut independent := dom.DocumentLoadEventDelayer.new(mut document)
		defer {
			media.remove_queued_media_element_tasks()
			media.finish_delaying_load_event()
			independent.finish()
			old_independent.finish()
			media.finalize()
		}
		document.adopt_node(old_document.get_element_by_id('player')?.as_node())
		assert voidptr(media.document()?) == voidptr(document)
		assert old_document.anything_is_delaying_the_load_event() && document.anything_is_delaying_the_load_event()
		promises := fatal_load_delay_pending_batch(media)
		seen := &FatalLoadDelayObservation{}
		media.set_on_event('error', &dom.CallbackType{
			handle_event: fn [media, document, promises, seen] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
				mut observation := unsafe { &FatalLoadDelayObservation(seen) }
				observation.calls++
				assert media.delaying_load_event_ != none && document.anything_is_delaying_the_load_event()
				failure := media.error() or { panic('missing fatal source error') }
				assert failure.code == .src_not_supported && media.network_state() == .no_source
				assert media.show_poster()
				assert promises[0].state() == .pending && promises[1].state() == .pending
				return dom.js_undefined()
			}
		})
		media.handle_media_source_failure(promises, 'unsupported media source')
		assert seen.calls == 1 && media.event_count('error') == 1 && media.delaying_load_event_ == none
		for promise in promises {
			assert promise.state() == .rejected && promise.webidl_promise()?.state == .rejected
			exception := promise.result().as_webidl_value()!.dom_exception_?
			assert exception.name() == 'NotSupportedError' && exception.code() == 9
			assert exception.message() == 'Media is not supported'
		}
		assert document.anything_is_delaying_the_load_event() && old_document.anything_is_delaying_the_load_event()
		independent.finish()
		assert !document.anything_is_delaying_the_load_event() && old_document.anything_is_delaying_the_load_event()
		old_independent.finish()
		assert !old_document.anything_is_delaying_the_load_event()
	}
}

fn test_reentrant_source_error_load_keeps_its_new_inactive_document_delay_and_captured_promises() {
	for kind in ['audio', 'video'] {
		mut media := fatal_load_delay_owner(kind, true)!
		document := media.document()?
		mut navigable := document.navigable()?
		defer {
			navigable.set_active_document(document)
			media.remove_queued_media_element_tasks()
			media.finish_delaying_load_event()
			media.finalize()
		}
		media.begin_delaying_load_event()
		promises := fatal_load_delay_pending_batch(media)
		seen := &FatalLoadDelayObservation{}
		media.set_on_event('error', &dom.CallbackType{
			handle_event: fn [media, document, navigable, promises, seen] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
				mut observation := unsafe { &FatalLoadDelayObservation(seen) }
				observation.calls++
				failure := media.error() or { panic('missing reentrant source error') }
				assert failure.code == .src_not_supported && media.delaying_load_event_ != none
				assert promises[0].state() == .pending && promises[1].state() == .pending
				mut navigation := unsafe { &dom.Navigable(navigable) }
				navigation.set_active_document(none)
				mut owner := unsafe { &HTMLMediaElement(media) }
				owner.load() or { panic(err) }
				assert !document.is_fully_active() && owner.error() == none
				assert owner.resource_selection_pending_ && owner.delaying_load_event_ != none
				return dom.js_undefined()
			}
		})
		media.handle_media_source_failure(promises, 'source failed before reentrant load')
		assert seen.calls == 1 && media.event_count('error') == 1
		assert media.error() == none && media.network_state() == .empty && media.ready_state() == .have_nothing
		assert media.resource_selection_pending_ && !media.resource_fetch_started_
		assert media.delaying_load_event_ != none && document.anything_is_delaying_the_load_event()
		assert promises[0].state() == .pending && promises[1].state() == .pending
		assert promises[0].webidl_promise()?.state == .pending && promises[1].webidl_promise()?.state == .pending
	}
}
