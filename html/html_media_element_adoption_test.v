module html

import dom

struct MediaAdoptionFetchObservation {
mut:
	calls int
}

fn test_media_adoption_resumes_selection_and_retargets_document_lifecycle() {
	mut inactive_document := dom.Document.create(dom.URL{ value: 'https://old.example/' })
	mut active_document := dom.Document.create(dom.URL{ value: 'https://new.example/' })
	mut navigable := &dom.Navigable{
		active_document_: active_document
		is_top_level_traversable_: true
	}
	navigable.traversable_navigable_ = navigable
	active_document.set_cached_navigable(navigable)
	assert inactive_document.unique_id_ != active_document.unique_id_

	video_element := inactive_document.create_element_ns('http://www.w3.org/1999/xhtml', 'video')!
	mut media := html_media_element_for_dom_element(video_element) or { panic('missing media state') }
	observation := &MediaAdoptionFetchObservation{}
	media.set_fetch_hook(fn [observation] (_ dom.URL, _ u64) !MediaResourceResponse {
		mut result := unsafe { &MediaAdoptionFetchObservation(observation) }
		result.calls++
		return MediaResourceResponse{
			mime_type: 'video/mp4'
			duration: 1
			buffered_end: 1
		}
	})
	media.set_source('/movie.mp4')
	media.load()!
	assert observation.calls == 0
	assert media.resource_selection_pending_
	assert inactive_document.anything_is_delaying_the_load_event()

	active_document.adopt_node(video_element.as_node())
	assert video_element.document().url.serialize() == 'https://new.example/'
	assert media.document_observer_?.document()?.url.serialize() == 'https://new.example/'
	assert media.base_url_.serialize() == 'https://new.example/'
	assert !media.resource_selection_pending_
	assert observation.calls == 1
	assert !media.resource_selection_pending_
	assert media.current_src() == 'https://new.example/movie.mp4'
	assert !inactive_document.anything_is_delaying_the_load_event()
	assert !active_document.anything_is_delaying_the_load_event()

	media.set_paused(false)
	inactive_document.adopt_node(video_element.as_node())
	assert media.paused()
	assert media.document_observer_?.document()?.url.serialize() == 'https://old.example/'
}

fn test_media_adoption_retains_an_in_flight_load_event_delay() {
	mut old_document := dom.Document.create(dom.URL{ value: 'https://old.example/' })
	mut new_document := dom.Document.create(dom.URL{ value: 'https://new.example/' })
	video_element := old_document.create_element_ns(dom.namespace_html_uri, 'video')!
	mut media := html_media_element_for_dom_element(video_element) or { panic('missing media state') }
	media.resource_fetch_started_ = true
	media.begin_delaying_load_event()
	assert old_document.anything_is_delaying_the_load_event()

	new_document.adopt_node(video_element.as_node())
	assert !old_document.anything_is_delaying_the_load_event()
	assert new_document.anything_is_delaying_the_load_event()

	media.finish_delaying_load_event()
	assert !new_document.anything_is_delaying_the_load_event()
}
