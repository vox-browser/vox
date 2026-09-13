module fetch

import mimesniff
import streams

fn ignore_body_chunk(_ []u8) {}

fn ignore_body_end() {}

fn ignore_body_error(_ string) {}

@[heap]
struct IncrementalReadRecorder {
mut:
	chunks []string
	ended  bool
	error_ string
}

fn test_extract_body_types_and_keepalive_stream_rejection() {
	string_body := extract_body(BodyInit{ kind: .string_, text: 'hello' }, false)!
	assert string_body.body.bytes() == 'hello'.bytes()
	assert string_body.type_? == 'text/plain;charset=UTF-8'
	params := extract_body(BodyInit{ kind: .url_search_params, text: 'a=1&b=2' }, false)!
	assert params.type_? == 'application/x-www-form-urlencoded;charset=UTF-8'
	if _ := extract_body(BodyInit{ kind: .readable_stream }, true) {
		assert false
	}
}

fn test_body_consumption_clone_and_sniff_bytes() {
	mut body := Body.from_bytes('abcdef'.bytes(), .bytes)
	assert body.sniff_bytes_if_available()? == 'abcdef'.bytes()
	clone := body.clone()
	assert clone.bytes() == body.bytes()
	assert body.fully_read()! == 'abcdef'.bytes()
	assert body.disturbed()
	if _ := body.fully_read() {
		assert false
	}
}

fn test_streaming_sniff_callback_and_limit() {
	mut body := Body.streaming()
	body.append_sniff_bytes([]u8{len: 1600, init: u8(7)})
	assert body.sniff_bytes_if_available()?.len == 1445
}

fn test_body_source_replacement_and_incremental_read_cancellation() {
	mut sourced_body := Body.streaming()
	sourced_body.set_source('immutable source'.bytes(), 16)
	assert sourced_body.body_source() == .bytes
	assert sourced_body.body_length()? == 16
	assert sourced_body.bytes() == 'immutable source'.bytes()
	assert sourced_body.sniff_bytes_if_available()? == 'immutable source'.bytes()

	mut streaming_body := Body.streaming()
	mut reader := streaming_body.incrementally_read(ignore_body_chunk, ignore_body_end, ignore_body_error)
	assert streaming_body.stream_locked()
	cancel_incremental_read(mut reader)
	assert streaming_body.disturbed()
	assert streaming_body.stream().state() == .closed
}

fn test_incremental_read_waits_for_future_stream_chunks() {
	mut body := Body.streaming()
	mut recorder := &IncrementalReadRecorder{}
	mut reader := body.incrementally_read(fn [mut recorder] (chunk []u8) {
		recorder.chunks << chunk.bytestr()
	}, fn [mut recorder] () {
		recorder.ended = true
	}, fn [mut recorder] (reason string) {
		recorder.error_ = reason
	})
	assert recorder.chunks.len == 0
	assert !recorder.ended
	assert recorder.error_ == ''

	mut stream := body.stream()
	stream.enqueue(streams.bytes_value('first'.bytes()))!
	stream.enqueue(streams.bytes_value('second'.bytes()))!
	assert recorder.chunks == ['first', 'second']
	assert !recorder.ended

	stream.close()
	assert recorder.ended
	assert recorder.error_ == ''
	reader.release_lock()!
}

fn test_multipart_form_data_parser() {
	mime := mimesniff.MimeType.parse('multipart/form-data;boundary=abc')?
	input := '--abc\r\nContent-Disposition: form-data; name="field"\r\n\r\nvalue\r\n--abc\r\nContent-Disposition: form-data; name="file"; filename="a.txt"\r\nContent-Type: text/plain\r\n\r\ntext\r\n--abc--\r\n'
	entries := parse_multipart_form_data(input, mime)!
	assert entries.len == 2
	assert entries[0].name == 'field' && entries[0].value == 'value'
	assert entries[1].filename? == 'a.txt'
	assert entries[1].content_type? == 'text/plain'
}

fn test_multipart_parser_preserves_upstream_lexer_constraints() {
	mime := mimesniff.MimeType.parse('multipart/form-data;boundary=abc')?
	missing_initial_boundary := 'preamble\r\n--abc--'
	if _ := parse_multipart_form_data(missing_initial_boundary, mime) {
		assert false
	}
	malformed_newline := '--abc\nContent-Disposition: form-data; name="field"\n\nvalue\n--abc--'
	if _ := parse_multipart_form_data(malformed_newline, mime) {
		assert false
	}

	filename_without_type := '--abc\r\nContent-Disposition: form-data; name="file"; filename="a.txt"\r\n\r\ntext\r\n--abc--trailing data is ignored'
	entries := parse_multipart_form_data(filename_without_type, mime)!
	assert entries.len == 1
	assert entries[0].content_type? == 'text/plain'
}

fn test_body_mixin_consumers_and_unusable_state() {
	body := Body.from_bytes('{"ok":true}'.bytes(), .bytes)
	mixin := BodyMixin{
		body: body
		mime_type: mimesniff.MimeType.parse('application/json')
	}
	assert mixin.json()! == '{"ok":true}'
	assert mixin.body_used()
	assert mixin.is_unusable()
}

fn test_body_text_json_and_url_encoded_follow_fetch_decoding_rules() {
	text_mixin := BodyMixin{
		body: Body.from_bytes([u8(0xef), 0xbb, 0xbf, `o`, `k`, 0xff], .bytes)
	}
	assert text_mixin.text()! == 'ok�'
	assert BodyMixin{
		body: Body.from_bytes('42'.bytes(), .bytes)
	}.json()! == '42'
	assert BodyMixin{
		body: Body.from_bytes('"value"'.bytes(), .bytes)
	}.json()! == '"value"'
	if _ := BodyMixin{
		body: Body.from_bytes('{bad}'.bytes(), .bytes)
	}.json() {
		assert false
	}
	mime := mimesniff.MimeType.parse('application/x-www-form-urlencoded') or {
		panic('expected MIME type')
	}
	entries := BodyMixin{
		body: Body.from_bytes('first+name=Alex%20Smith&&check=%E2%9C%93'.bytes(), .bytes)
		mime_type: mime
	}.form_data()!
	assert entries.len == 2
	assert entries[0].name == 'first name'
	assert entries[0].value == 'Alex Smith'
	assert entries[1].value == '✓'
	empty_entries := BodyMixin{
		body: Body.from_bytes([]u8{}, .bytes)
		mime_type: mime
	}.form_data()!
	assert empty_entries.len == 0
}
