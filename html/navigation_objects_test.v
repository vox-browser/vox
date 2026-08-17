module html

import dom

fn test_navigation_history_entry_and_destination() {
	mut document := &dom.Document{}
	mut state := &DocumentState{
		document: document
	}
	mut first := &SessionHistoryEntry{
		url:                  dom.URL{
			value: 'https://example.test/one'
		}
		document_state:       state
		navigation_api_key:   'key-1'
		navigation_api_id:    'id-1'
		navigation_api_state: SerializationRecord{
			data: [u8(StructuredSerializeValueTag.null_primitive)]
		}
	}
	mut second := &SessionHistoryEntry{
		url:                dom.URL{
			value: 'https://example.test/two'
		}
		document_state:     state
		navigation_api_key: 'key-2'
		navigation_api_id:  'id-2'
	}
	mut entry := NavigationHistoryEntry.create(first, document)
	entry.set_fully_active_override(true)
	entry.set_navigation_entries([first, second])
	assert entry.url()? == first.url.value
	assert entry.key() == 'key-1'
	assert entry.id() == 'id-1'
	assert entry.index() == 0
	assert entry.same_document()
	assert entry.get_state()!.is_nullish()

	mut destination := NavigationDestination.create()
	destination.set_url(second.url)
	destination.set_entry(entry)
	destination.set_state(SerializationRecord{
		data: [
			u8(StructuredSerializeValueTag.undefined_primitive),
		]
	})
	destination.set_is_same_document(true)
	assert destination.url() == second.url.value
	assert destination.key() == 'key-1'
	assert destination.index() == 0
	assert destination.same_document()
	assert destination.get_state()!.is_undefined()
}

fn test_navigation_history_entry_inactive_and_referrer_protection() {
	document := &dom.Document{}
	other_document := &dom.Document{}
	state := &DocumentState{
		document:                other_document
		request_referrer_policy: .no_referrer
	}
	history := &SessionHistoryEntry{
		url:                dom.URL{
			value: 'https://other.test/secret'
		}
		document_state:     state
		navigation_api_key: 'secret-key'
	}
	mut entry := NavigationHistoryEntry.create(history, document)
	assert entry.url()? == ''
	assert entry.key() == ''
	assert entry.index() == -1
	assert !entry.same_document()
	entry.set_fully_active_override(true)
	assert entry.url() == none
}

fn test_navigation_transition_and_current_entry_change_event() {
	document := &dom.Document{}
	history := &SessionHistoryEntry{
		document_state: &DocumentState{
			document: document
		}
	}
	entry := NavigationHistoryEntry.create(history, document)
	destination := NavigationDestination.create()
	committed := &dom.Promise{}
	finished := &dom.Promise{}
	transition := NavigationTransition.create(.replace, entry, destination, committed, finished)
	assert transition.navigation_type() == .replace
	assert transition.from() == entry
	assert transition.to() == destination
	assert transition.committed() == committed
	assert transition.finished() == finished

	event := NavigationCurrentEntryChangeEvent.construct_impl('currententrychange', NavigationCurrentEntryChangeEventInit{
		navigation_type: .traverse
		from:            entry
	})!
	assert event.interface_ == .navigation_current_entry_change_event
	assert event.type_ == 'currententrychange'
	assert event.navigation_type()? == .traverse
	assert event.from() == entry
}
