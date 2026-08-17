module mimesniff

fn test_image_signatures() {
	assert match_an_image_type_pattern('\x89\x50\x4E\x47\x0D\x0A\x1A\x0A'.bytes())?.essence() == 'image/png'
	assert match_an_image_type_pattern('GIF89a'.bytes())?.essence() == 'image/gif'
	assert match_an_image_type_pattern('GIF87a'.bytes())?.essence() == 'image/gif'
	assert match_an_image_type_pattern('\xFF\xD8\xFF\xE0'.bytes())?.essence() == 'image/jpeg'
	assert match_an_image_type_pattern('BM....'.bytes())?.essence() == 'image/bmp'
	assert match_an_image_type_pattern('\x00\x00\x01\x00'.bytes())?.essence() == 'image/x-icon'
	// RIFF????WEBPVP (the four bytes after RIFF are masked out).
	assert match_an_image_type_pattern('RIFF\x01\x02\x03\x04WEBPVP'.bytes())?.essence() == 'image/webp'
	// A non-image is undefined.
	assert match_an_image_type_pattern('not an image'.bytes()) == none
}

fn test_audio_video_signatures() {
	assert match_an_audio_or_video_type_pattern('OggS\x00'.bytes())?.essence() == 'application/ogg'
	assert match_an_audio_or_video_type_pattern('ID3xx'.bytes())?.essence() == 'audio/mpeg'
	assert match_an_audio_or_video_type_pattern('RIFF\x01\x02\x03\x04WAVE'.bytes())?.essence() == 'audio/wave'
	// MP4: box-size 12 (big-endian), "ftyp", then "mp4".
	assert match_an_audio_or_video_type_pattern('\x00\x00\x00\x0Cftypmp42'.bytes())?.essence() == 'video/mp4'
	assert match_an_audio_or_video_type_pattern('audio'.bytes()) == none
}

fn test_font_signatures() {
	assert match_a_font_type_pattern('OTTO'.bytes())?.essence() == 'font/otf'
	assert match_a_font_type_pattern('wOFF'.bytes())?.essence() == 'font/woff'
	assert match_a_font_type_pattern('wOF2'.bytes())?.essence() == 'font/woff2'
	assert match_a_font_type_pattern('ttcf'.bytes())?.essence() == 'font/collection'
	assert match_a_font_type_pattern('\x00\x01\x00\x00'.bytes())?.essence() == 'font/ttf'
	assert match_a_font_type_pattern('nope'.bytes()) == none
}

fn test_archive_signatures() {
	assert match_an_archive_type_pattern('\x1F\x8B\x08'.bytes())?.essence() == 'application/x-gzip'
	assert match_an_archive_type_pattern('PK\x03\x04'.bytes())?.essence() == 'application/zip'
	assert match_an_archive_type_pattern('Rar!\x1A\x07\x00'.bytes())?.essence() == 'application/x-rar-compressed'
	assert match_an_archive_type_pattern('plain'.bytes()) == none
}

fn test_pattern_matching_ignores_leading_bytes() {
	// With whitespace in the ignored set, leading whitespace is skipped before matching.
	assert pattern_matching_algorithm('\x20\x20BM'.bytes(), 'BM'.bytes(), '\xFF\xFF'.bytes(), [
		u8(0x20),
	], false) == true
	// Without the byte in the ignored set, the same input does not match at offset 0.
	assert pattern_matching_algorithm('\x20\x20BM'.bytes(), 'BM'.bytes(), '\xFF\xFF'.bytes(),
		[]u8{}, false) == false
}

fn test_is_binary_data_byte() {
	assert is_binary_data_byte(0x00) == true
	assert is_binary_data_byte(0x0B) == true
	assert is_binary_data_byte(0x1F) == true
	// Tab, LF, CR, and printable ASCII are not binary.
	assert is_binary_data_byte(0x09) == false
	assert is_binary_data_byte(0x0A) == false
	assert is_binary_data_byte(0x41) == false
}

fn test_rules_scriptable_html() {
	// A tag-terminated HTML tag with sniff-scriptable set → text/html.
	assert rules_for_identifying_an_unknown_mime_type('<html>hello'.bytes(), true).essence() == 'text/html'
	assert rules_for_identifying_an_unknown_mime_type('  <!DOCTYPE HTML>'.bytes(), true).essence() == 'text/html'
	assert rules_for_identifying_an_unknown_mime_type('<?xml version="1.0"?>'.bytes(), true).essence() == 'text/xml'
	assert rules_for_identifying_an_unknown_mime_type('%PDF-1.7'.bytes(), true).essence() == 'application/pdf'
	// Without sniff-scriptable, HTML markup is not detected as text/html.
	assert rules_for_identifying_an_unknown_mime_type('<html>hello'.bytes(), false).essence() == 'text/plain'
}

fn test_rules_text_vs_binary_fallback() {
	// Plain ASCII with no signature and no binary bytes → text/plain.
	assert rules_for_identifying_an_unknown_mime_type('just some text'.bytes(), false).essence() == 'text/plain'
	// Data containing a binary byte and no signature → application/octet-stream.
	assert rules_for_identifying_an_unknown_mime_type('\x00abc'.bytes(), false).essence() == 'application/octet-stream'
}

fn test_rules_prefers_image_signature() {
	// A PNG header is detected even without sniff-scriptable.
	assert rules_for_identifying_an_unknown_mime_type('\x89\x50\x4E\x47\x0D\x0A\x1A\x0A'.bytes(),
		false).essence() == 'image/png'
	assert rules_for_identifying_an_unknown_mime_type('\x1F\x8B\x08'.bytes(), false).essence() == 'application/x-gzip'
}

fn test_resource_reads_at_most_1445_bytes() {
	resource := Resource.create([]u8{len: 2000, init: u8(1)}, SniffingConfiguration{})
	assert resource.resource_header().len == 1445
}

fn test_resource_unknown_and_no_sniff_behavior() {
	unknown := MimeType.parse('application/unknown')?
	assert Resource.sniff('<html>hello'.bytes(), SniffingConfiguration{
		scheme:        'https'
		supplied_type: unknown
	}).essence() == 'text/html'
	plained := MimeType.parse('text/plain')?
	assert Resource.sniff('\x89PNG\r\n\x1a\n'.bytes(), SniffingConfiguration{
		scheme:        'https'
		supplied_type: plained
		no_sniff:      true
	}).essence() == 'text/plain'
}

fn test_resource_context_specific_sniffing() {
	png := Resource.sniff('\x89PNG\r\n\x1a\n'.bytes(), SniffingConfiguration{
		sniffing_context: .image
	})
	assert png.essence() == 'image/png'
	font := Resource.sniff('wOFFmore'.bytes(), SniffingConfiguration{
		sniffing_context: .font
	})
	assert font.essence() == 'font/woff'
}

fn test_apache_bug_text_binary_rules() {
	plain := MimeType.parse('text/plain;charset=UTF-8')?
	assert Resource.sniff([u8(0), 1, 2], SniffingConfiguration{
		scheme:        'http'
		supplied_type: plain
	}).essence() == 'application/octet-stream'
	assert Resource.sniff('ordinary text'.bytes(), SniffingConfiguration{
		scheme:        'http'
		supplied_type: plain
	}).essence() == 'text/plain'
}
