module html

import dom
import webidl

@[heap]
struct MediaPlayPromiseObservation {
mut:
	schedule_depths []uint
	reaction_depths []uint
	reasons         []webidl.Value
	events          []string
}

fn media_play_promise_owner(address string) !&HTMLMediaElement {
	url := dom.URL{
		value: address
	}
	document := parse_navigation_document('<video id="player"></video>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('missing player') }
	return html_media_element_for_dom_element(element) or { return error('missing media owner') }
}

fn media_play_promise_take(media &HTMLMediaElement) &Task {
	mut queue := main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [media] (task &Task) bool {
		return task.id() in media.queued_media_task_ids_
	}) or { panic('missing media play promise task') }
}

fn media_play_promise_drain(media &HTMLMediaElement) {
	for media.queued_media_task_ids_.len > 0 {
		media_play_promise_take(media).execute()
	}
}

fn media_play_promise_watched_batch(media &HTMLMediaElement, state &MediaPlayPromiseObservation) []&dom.Promise {
	settings := unsafe {
		&EnvironmentSettingsObject(media.document() or { panic('missing document') }.relevant_settings_object())
	}
	canonical := settings.stream_promise_context()
	mut promises := []&dom.Promise{}
	for _ in 0 .. 2 {
		mut native := webidl.create_promise_for(webidl.PromiseContext{
			...canonical
			job_scheduler: fn [canonical, settings, state] (job fn ()) {
				mut observation := unsafe { &MediaPlayPromiseObservation(state) }
				observation.schedule_depths << settings.realm().script_execution_depth
				schedule := canonical.job_scheduler or { panic('missing promise scheduler') }
				schedule(job)
			}
		})
		webidl.react_to_promise(mut native, fn (_ webidl.Value) !webidl.Value {
			return error('media failure fulfilled a pending play promise')
		}, fn [settings, state] (reason webidl.Value) !webidl.Value {
			mut observation := unsafe { &MediaPlayPromiseObservation(state) }
			observation.reaction_depths << settings.realm().script_execution_depth
			observation.reaction_depths << settings.realm().callback_execution_depth
			observation.reasons << reason
			return webidl.undefined_value()
		})
		promises << dom.Promise.from_webidl(native)
	}
	return promises
}

fn media_play_promise_assert_rejected_batch(promises []&dom.Promise, name string, code u16, message string) {
	assert promises.len == 2
	first := promises[0].result().as_webidl_value() or { panic(err) }
	first_exception := first.dom_exception_ or { panic('missing typed media rejection') }
	for promise in promises {
		assert promise.state() == .rejected
		native := promise.webidl_promise() or { panic('missing actual promise capability') }
		assert native.state == .rejected
		exception := promise.result().as_webidl_value() or { panic(err) }.dom_exception_ or {
			panic('missing typed media rejection')
		}

		assert exception.name() == name && exception.code() == code
			&& exception.message() == message
		assert voidptr(exception) == voidptr(first_exception)
		assert voidptr(native.result.dom_exception_ or { panic('missing native rejection') }) == voidptr(exception)
	}
}

fn media_play_promise_assert_owner_jobs(media &HTMLMediaElement, state &MediaPlayPromiseObservation, promises []&dom.Promise) {
	assert state.schedule_depths == [uint(1), 1]
	assert state.reaction_depths == [uint(1), 1, 1, 1]
	assert state.reasons.len == 2
	for index, reason in state.reasons {
		assert voidptr(reason.dom_exception_ or { panic('missing reaction exception') }) == voidptr(promises[index].result().as_webidl_value() or {
			panic(err)
		}.dom_exception_ or { panic('missing result exception') })
	}
	settings := unsafe {
		&EnvironmentSettingsObject(media.document() or { panic('missing document') }.relevant_settings_object())
	}
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
}

fn test_play_keeps_one_native_capability_and_selects_the_current_document_realm_after_adoption() {
	mut policy := AutoplaySettings.the()
	previous_policy := policy.policy_
	previous_allowlist := policy.allowlist_.clone()
	defer {
		policy.policy_ = previous_policy
		policy.allowlist_ = previous_allowlist
	}
	policy.set_policy(.block_audio_and_video, [])
	mut media := media_play_promise_owner('https://original-play-promise.example.test/')!
	original_document := media.document()?
	original_settings := unsafe { &EnvironmentSettingsObject(original_document.relevant_settings_object()) }
	first := media.play()
	second := media.play()
	original := first.webidl_promise()?
	assert voidptr(original) == voidptr(first.webidl_promise()?)
	assert voidptr(original) != voidptr(second.webidl_promise()?)
	assert webidl.promise_realm(original) == u64(voidptr(original_settings.realm()))
	assert original.state == .rejected && first.state() == .rejected
	assert voidptr(original.result.dom_exception_?) == voidptr(first.result().as_webidl_value()!.dom_exception_?)
	url := dom.URL{
		value: 'https://adopted-play-promise.example.test/'
	}
	mut adopted := parse_navigation_document('<body></body>', url, url.origin(), none)!
	adopted.adopt_node(original_document.get_element_by_id('player')?.as_node())
	assert voidptr(media.document()?) == voidptr(adopted)
	adopted_settings := unsafe { &EnvironmentSettingsObject(adopted.relevant_settings_object()) }
	after_adoption := media.play().webidl_promise()?
	assert webidl.promise_realm(after_adoption) == u64(voidptr(adopted_settings.realm()))
	assert webidl.promise_realm(after_adoption) != webidl.promise_realm(original)
	assert webidl.promise_realm(original) == u64(voidptr(original_settings.realm()))
	policy.set_policy(.allow_audio_and_video, [])
	media.network_state_ = .idle
	media.ready_state_ = .have_metadata
	pending := media.play()
	native := pending.webidl_promise()?
	assert pending.state() == .pending && native.state == .pending
	assert voidptr(media.pending_play_promises_[0]) == voidptr(pending)
	assert voidptr(media.pending_play_promises_[0].webidl_promise()?) == voidptr(native)
	media_play_promise_drain(media)
	media.pause()
	media_play_promise_drain(media)
	assert native.state == .rejected && pending.state() == .rejected
	assert native.result.dom_exception_?.name() == 'AbortError'
	assert voidptr(native.result.dom_exception_?) == voidptr(pending.result().as_webidl_value()!.dom_exception_?)
}

fn test_play_without_a_document_or_settings_retains_the_standalone_capability_adapter() {
	mut policy := AutoplaySettings.the()
	previous_policy := policy.policy_
	previous_allowlist := policy.allowlist_.clone()
	defer {
		policy.policy_ = previous_policy
		policy.allowlist_ = previous_allowlist
	}
	policy.set_policy(.allow_audio_and_video, [])
	mut document := dom.Document.create(dom.URL{ value: 'https://no-play-settings.example.test/' })
	element := document.create_element_ns(dom.namespace_html_uri, 'audio')!
	assert document.relevant_settings_object() == unsafe { nil }
	standalone := HTMLMediaElement.create(none, dom.url_about_blank())
	attached := html_media_element_for_dom_element(element)?
	for owner in [standalone, attached] {
		mut media := unsafe { &HTMLMediaElement(owner) }
		media.error_ = &MediaError{
			code:    .src_not_supported
			message: 'Standalone decoder failure'
		}
		promise := media.play()
		mut native := promise.webidl_promise()?
		assert webidl.promise_realm(native) == 0
		context := webidl.promise_context(native)
		if _ := context.job_scheduler {
			assert false, 'a standalone play capability must not retain an HTML job scheduler'
		}
		assert native.state == .rejected && promise.state() == .rejected
		assert native.result.dom_exception_?.name() == 'NotSupportedError'
		assert voidptr(native.result.dom_exception_?) == voidptr(promise.result().as_webidl_value()!.dom_exception_?)
		native.resolve(webidl.undefined_value())
		assert native.state == .rejected && promise.state() == .rejected
		assert media.queued_media_task_ids_.len == 0
	}
	mut media := unsafe { &HTMLMediaElement(standalone) }
	media.error_ = none
	media.network_state_ = .no_source
	media.ready_state_ = .have_metadata
	promise := media.play()
	mut native := promise.webidl_promise()?
	assert native.state == .pending && promise.state() == .pending
	native.resolve(webidl.undefined_value())
	assert promise.state() == .fulfilled && promise.result().is_undefined()
	media_play_promise_drain(media)
	media.pause()
	media_play_promise_drain(media)
	assert native.state == .fulfilled && promise.state() == .fulfilled
}

fn test_resource_selection_rejects_one_native_batch_with_the_exact_typed_decoder_failure() {
	mut media := media_play_promise_owner('https://select-play-promise.example.test/')!
	state := &MediaPlayPromiseObservation{}
	promises := media_play_promise_watched_batch(media, state)
	media.pending_play_promises_ << promises
	media.set_source('/unsupported.mp4')
	media.set_fetch_hook(fn (_ dom.URL, _ u64) !MediaResourceResponse {
		return error('Decoder \x00 🎬 failed\r\n')
	})
	mut failed := false
	media.select_resource() or { failed = true }
	assert failed && media.network_state() == .no_source
	assert media.error()?.message == 'Decoder \x00 🎬 failed\r\n'
	assert media.pending_play_promises_.len == 0 && media.event_count('error') == 1
	media_play_promise_assert_rejected_batch(promises, 'NotSupportedError', 9,
		'Decoder \x00 🎬 failed\r\n')
	media_play_promise_assert_owner_jobs(media, state, promises)
}

fn test_media_source_failure_dispatches_error_then_rejects_the_captured_native_batch_with_one_exception() {
	mut media := media_play_promise_owner('https://source-play-promise.example.test/')!
	state := &MediaPlayPromiseObservation{}
	promises := media_play_promise_watched_batch(media, state)
	media.set_on_event('error', &dom.CallbackType{
		handle_event: fn [promises, state] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert promises[0].state() == .pending && promises[1].state() == .pending
			assert state.schedule_depths == []
			assert state.reaction_depths == []
			mut observation := unsafe { &MediaPlayPromiseObservation(state) }
			observation.events << 'error'
			return dom.js_undefined()
		}
	})
	media.handle_media_source_failure(promises, 'MediaStream decoder unavailable')
	assert media.error()?.message == 'MediaStream decoder unavailable'
	assert media.network_state() == .no_source && media.show_poster()
	assert state.events == ['error']
	media_play_promise_assert_rejected_batch(promises, 'NotSupportedError', 9,
		'Media is not supported')
	media_play_promise_assert_owner_jobs(media, state, promises)
}

fn test_media_end_rejects_the_native_batch_between_pause_and_ended_in_the_owning_context() {
	mut media := media_play_promise_owner('https://ended-play-promise.example.test/')!
	media.ready_state_ = .have_metadata
	media.duration_ = 10
	media.set_current_playback_position(10)
	media.set_paused(false)
	state := &MediaPlayPromiseObservation{}
	promises := media_play_promise_watched_batch(media, state)
	media.pending_play_promises_ << promises
	for name in ['timeupdate', 'pause', 'ended'] {
		media.set_on_event(name, &dom.CallbackType{
			handle_event: fn [name, promises, state] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
				assert promises[0].state() == if name == 'ended' {
					dom.PromiseState.rejected
				} else {
					dom.PromiseState.pending
				}
				assert promises[1].state() == promises[0].state()
				mut observation := unsafe { &MediaPlayPromiseObservation(state) }
				observation.events << name
				return dom.js_undefined()
			}
		})
	}
	media.reached_end_of_media_playback()
	assert promises[0].state() == .pending && state.events == []
	media_play_promise_take(media).execute()
	assert state.events == ['timeupdate', 'pause', 'ended']
	assert media.paused() && media.pending_play_promises_.len == 0
	media_play_promise_assert_rejected_batch(promises, 'AbortError', 20, 'Media playback has ended')
	media_play_promise_assert_owner_jobs(media, state, promises)
}
