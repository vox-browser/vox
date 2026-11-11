module html

import dom
import platform

// The shared-request map is process-wide, while image requests are often made
// with a document's native storage entered (the New Tab page's icons). The map
// must not grow into that arena, and the document's entries leave it with the
// document's storage, before later navigations insert into the same map.
fn test_native_document_requests_leave_the_process_wide_map_with_their_storage() {
	base := 'https://shared-request-storage.example/'
	mut document := dom.Document.create(dom.URL{ value: base })
	document.enable_native_storage()
	storage := document.native_storage()
	mut scope := document.enter_native_storage()
	for index in 0 .. 96 {
		_ = SharedResourceRequest.get_or_create(document, dom.URL{ value: '${base}${index}.png' })
	}
	scope.finish()
	first_url := dom.URL{ value: '${base}0.png' }
	assert shared_resource_request_for_document_and_url(document, first_url) != none
	document.release_native_storage()
	assert shared_resource_request_for_document_and_url(document, first_url) == none
	for _ in 0 .. 4 {
		work := platform.begin_thread_scratch('shared request overwrite')
		_ = []u8{len: 256 * 1024, init: u8(0xa5)}
		work.finish()
	}
	other_base := 'https://shared-request-next.example/'
	mut other := dom.Document.create(dom.URL{ value: other_base })
	for index in 0 .. 192 {
		_ = SharedResourceRequest.get_or_create(other, dom.URL{ value: '${other_base}${index}.png' })
	}
	for index in [0, 95, 191] {
		assert shared_resource_request_for_document_and_url(other, dom.URL{ value: '${other_base}${index}.png' }) != none
	}
	for key, _ in html_shared_resource_requests {
		assert !key.starts_with('${u64(voidptr(document))}\x00')
	}
	$if prealloc { assert storage.arena.usage().used == 0 }
}
