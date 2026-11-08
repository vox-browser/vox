module fetch

import crypto.sha256
import dom
import encoding.base64

fn test_embedded_font_sized_data_urls_decode_without_quadratic_temporary_storage() {
	payload := []u8{len: 256 * 1024, init: u8(index % 251)}
	encoded := base64.encode(payload)
	result := process_data_url(dom.URL{ value: 'data:font/ttf;base64,${encoded}' })!
	assert result.mime_type.essence() == 'font/ttf'
	assert result.body.len == payload.len
	assert sha256.sum(result.body) == sha256.sum(payload)
}

fn test_forgiving_base64_keeps_ascii_whitespace_and_invalid_length_behavior() {
	assert forgiving_base64_decode(' \tSGVs\nbG8=\r\x0c ')!.bytestr() == 'Hello'
	assert forgiving_base64_decode('')!.len == 0
	if _ := forgiving_base64_decode(' A\n') {
		assert false, 'A single base64 character must fail'
	}
}

fn test_embedded_font_data_decodes_percent_escapes_before_base64_and_omits_fragment() {
	result := process_data_url(dom.URL{ value: 'data:font/ttf;base64,SG%20Vs%0AbG8=#font' })!
	assert result.body.bytestr() == 'Hello'
}
