module xhr

@[heap]
struct XHRProgressClock {
mut:
	now i64
}

fn xhr_progress_request(clock &XHRProgressClock) &XMLHttpRequest {
	return XMLHttpRequest.create(&XMLHttpRequestGlobal{
		kind:          .window
		base_url:      'https://example.test/'
		monotonic_now: fn [clock] () i64 {
			return clock.now
		}
	})
}

fn test_download_progress_throttle_keeps_bytes_and_final_progress() {
	mut clock := &XHRProgressClock{
		now: 1_000_000
	}
	mut request := xhr_progress_request(clock)
	request.open('GET', '/download', true, none, none)!
	request.send()!
	request.receive_headers(MockResponse{
		status:  200
		headers: [ResponseHeader{ name: 'Content-Length', value: '4' }]
	})!
	request.receive_chunk('a'.bytes())
	assert request.state == .loading
	assert request.events.map(it.type_) == ['readystatechange', 'loadstart', 'readystatechange',
		'readystatechange', 'progress']
	clock.now += 49_999_999
	request.receive_chunk('b'.bytes())
	assert request.events.len == 5
	assert request.response_text()! == 'ab'
	clock.now++
	request.receive_chunk('c'.bytes())
	assert request.events.len == 7
	assert request.events.last().loaded() == 3
	request.receive_chunk('d'.bytes())
	assert request.events.len == 7
	request.complete_response()!
	assert request.events.map(it.type_)[7..] == ['progress', 'readystatechange', 'load', 'loadend']
	assert request.events.last().loaded() == 4
	assert request.events.last().total() == 4
}

fn test_upload_progress_throttle_accumulates_and_resets_per_send() {
	mut clock := &XHRProgressClock{}
	mut request := xhr_progress_request(clock)
	request.upload_object.listeners['progress'] = true
	request.open('POST', '/upload', true, none, none)!
	request.send_text('abcd')!
	request.receive_upload_chunk_length(1)
	clock.now = 49_999_999
	request.receive_upload_chunk_length(1)
	assert request.upload_object.events.map(it.type_) == ['loadstart', 'progress']
	assert request.request_body_transmitted == 2
	clock.now = 50_000_000
	request.receive_upload_chunk_length(1)
	assert request.upload_object.events.last().loaded() == 3
	request.receive_upload_chunk_length(1)
	request.complete_upload()
	assert request.upload_object.events.map(it.type_) == ['loadstart', 'progress', 'progress',
		'progress', 'load', 'loadend']
	assert request.upload_object.events.last().loaded() == 4
	request.abort()
	request.open('POST', '/again', true, none, none)!
	request.send_text('a')!
	request.receive_upload_chunk_length(1)
	assert request.upload_object.events.last().type_ == 'progress'
	assert request.upload_object.events.last().loaded() == 1
}
