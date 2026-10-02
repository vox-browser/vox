module xhr

import fileapi

fn test_blob_request_uses_native_blob_bytes_and_preserves_its_content_type() {
	blob := fileapi.Blob.create([u8(0), 128, 255], 'application/custom;charset=windows-1252')
	mut request := XMLHttpRequest.construct(.window, 'https://example.test/')
	request.open('POST', '/blob', true, none, none)!
	request.send_blob(blob)!
	assert request.request_body == blob.raw_bytes()
	assert request.author_request_headers[0].value == 'application/custom;charset=windows-1252'
	mut empty_type := XMLHttpRequest.construct(.window, 'https://example.test/')
	empty_type.open('POST', '/blob', true, none, none)!
	empty_type.send_blob(fileapi.Blob.create([u8(1)], ''))!
	assert empty_type.request_body == [u8(1)]
	assert empty_type.author_request_headers.len == 0
}
