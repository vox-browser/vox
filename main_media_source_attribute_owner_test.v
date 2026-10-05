module main

import dom
import fileapi
import html
import mediasourceextensions
import page
import time

fn assert_script_media_src_replay_updates_cached_model(kind string) ! {
	owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_for_page_with_response_time('<${kind} id="player"></${kind}>', dom.URL{
		value: 'https://script-media-attribute.example.test/page'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	defer {
		document.run_unloading_cleanup_steps()
		document.finalize()
	}
	assert document.is_fully_active()
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut element := document.get_element_by_id('player') or { return error('missing player') }
	// Materialize before mutation, so reading the new DOM attribute at first
	// construction cannot hide a stale cached media model.
	mut media := html.html_media_element_for_dom_element(element) or {
		return error('missing media')
	}
	first := mediasourceextensions.MediaSource.create_for_constructor(settings.global_object())
	second := mediasourceextensions.MediaSource.create_for_constructor(settings.global_object())
	first_url := fileapi.add_entry_to_blob_url_store(first.blob_url_object(''), settings)!
	second_url := fileapi.add_entry_to_blob_url_store(second.blob_url_object(''), settings)!
	apply_javascript_element_attribute(mut element, 'src', first_url)
	assert (element.get_attribute('src') or { return error('missing src') }) == first_url
	assert media.current_src() == first_url
	assert first.ready_state() == .open
	assert (first.media_element_assigned_to() or { return error('unassigned first source') }) == media
	apply_javascript_element_attribute(mut element, 'src', second_url)
	assert media.current_src() == second_url
	assert first.ready_state() == .closed
	assert first.media_element_assigned_to() == none
	assert second.ready_state() == .open
	assert (second.media_element_assigned_to() or { return error('unassigned replacement') }) == media
	apply_javascript_element_attribute(mut element, 'src', none)
	assert element.get_attribute('src') == none
	assert second.ready_state() == .open
	assert (second.media_element_assigned_to() or { return error('unexpected detachment') }) == media
	// Removal synchronizes the cached source without automatically loading.
	// The next explicit load must therefore detach rather than reuse the URL.
	media.load()!
	assert media.current_src() == ''
	assert second.ready_state() == .closed
	assert second.media_element_assigned_to() == none
}

fn test_script_video_src_replay_updates_actual_cached_media_owner() {
	$if !darwin { return }
	assert_script_media_src_replay_updates_cached_model('video')!
}

fn test_script_audio_src_replay_updates_actual_cached_media_owner() {
	$if !darwin { return }
	assert_script_media_src_replay_updates_cached_model('audio')!
}
