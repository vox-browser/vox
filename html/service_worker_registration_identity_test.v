// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause

module html

import dom

// Ladybird 0eb5f96267a711f73cb8be9101c72a87878fb485: a new registration
// at an old scope must not inherit the removed registration's wrapper.
fn test_environment_registration_wrappers_follow_registration_identity() {
	mut document := dom.Document.create(dom.URL{value: 'https://example.test/'})
	defer { document.finalize() }
	window := WindowModel.create_top_level(document, none, 'registration')!
	mut settings := window.environment_settings_.settings
	first := &ServiceWorkerRegistrationRecordModel{
		storage_key: 'partition'
		scope_url: dom.URL{value: 'https://example.test/app/'}
		active: &ServiceWorkerRecordModel{id: 'old-worker', state: 'activated'}
	}
	old_object := settings.get_service_worker_registration_object(first)
	assert voidptr(old_object) == voidptr(settings.get_service_worker_registration_object(first))
	replacement := &ServiceWorkerRegistrationRecordModel{
		storage_key: first.storage_key
		scope_url: first.scope_url
	}
	new_object := settings.get_service_worker_registration_object(replacement)
	assert voidptr(new_object) != voidptr(old_object)
	assert new_object.active == none
	assert old_object.active or { panic('old worker was lost') }.record_id == 'old-worker'
	assert old_object.scope_url.serialize() == 'https://example.test/app/'
	assert voidptr(old_object.registration_) == voidptr(first)
	assert voidptr(new_object.registration_) == voidptr(replacement)
}
