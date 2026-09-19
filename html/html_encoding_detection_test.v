module html

fn test_extract_character_encoding_from_meta_element() {
	assert extract_character_encoding_from_meta_element('text/html; charset=UTF-8') or { '' } == 'UTF-8'
	assert extract_character_encoding_from_meta_element('CHARSET = "iso-8859-1"') or { '' } == 'windows-1252'
	assert extract_character_encoding_from_meta_element("x charset='shift_jis'") or { '' } == 'Shift_JIS'
	assert extract_character_encoding_from_meta_element('charset nope; charset=gbk') or { '' } == 'GBK'
	assert extract_character_encoding_from_meta_element('charset=not-an-encoding') == none
}

fn test_prescan_byte_stream_finds_meta_encodings() {
	assert run_prescan_byte_stream_algorithm('<meta charset="utf-8">'.bytes()) or { '' } == 'UTF-8'
	assert run_prescan_byte_stream_algorithm('<META HTTP-EQUIV=content-type CONTENT="text/html; charset=latin1">'.bytes()) or {
		''
	} == 'windows-1252'
	assert run_prescan_byte_stream_algorithm('<meta content="text/html; charset=utf-8">'.bytes()) == none
	assert run_prescan_byte_stream_algorithm('<!-- <meta charset=shift_jis> --><meta charset=gbk>'.bytes()) or {
		''
	} == 'GBK'
	assert run_prescan_byte_stream_algorithm('<meta charset=utf-16le>'.bytes()) or { '' } == 'UTF-8'
	assert run_prescan_byte_stream_algorithm('<meta charset=x-user-defined>'.bytes()) or { '' } == 'windows-1252'
}

fn test_prescan_byte_stream_limits_and_utf16_xml_prefix() {
	assert run_prescan_byte_stream_algorithm([u8(0x3c), 0, 0x3f, 0, 0x78, 0]) or { '' } == 'utf-16le'
	assert run_prescan_byte_stream_algorithm([u8(0), 0x3c, 0, 0x3f, 0, 0x78]) or { '' } == 'utf-16be'
	input := (' '.repeat(1024) + '<meta charset=utf-8>').bytes()
	assert run_prescan_byte_stream_algorithm(input) == none
}

fn test_html_encoding_sniffing_precedence_and_fallback() {
	assert run_html_encoding_sniffing_algorithm([u8(0xef), 0xbb, 0xbf, 0xff], 'shift_jis') == 'UTF-8'
	assert run_html_encoding_sniffing_algorithm('<meta charset=gbk>'.bytes(), 'shift_jis') == 'Shift_JIS'
	assert run_html_encoding_sniffing_algorithm('<meta charset=gbk>'.bytes(), none) == 'GBK'
	assert run_html_encoding_sniffing_algorithm([u8(0x41), 0xff], none) == 'windows-1252'
	assert run_html_encoding_sniffing_algorithm('valid UTF-8 ✓'.bytes(), none) == 'UTF-8'
}

fn test_html_encoding_sniffing_reports_confidence() {
	bom := run_html_encoding_sniffing_algorithm_with_confidence([u8(0xef), 0xbb, 0xbf], none)
	assert bom.encoding == 'UTF-8'
	assert bom.confidence == .certain

	transport := run_html_encoding_sniffing_algorithm_with_confidence('plain'.bytes(), 'windows-1251')
	assert transport.encoding == 'windows-1251'
	assert transport.confidence == .certain

	meta := run_html_encoding_sniffing_algorithm_with_confidence('<meta charset=gbk>'.bytes(), none)
	assert meta.encoding == 'GBK'
	assert meta.confidence == .tentative

	fallback := run_html_encoding_sniffing_algorithm_with_confidence('plain'.bytes(), none)
	assert fallback.encoding == 'UTF-8'
	assert fallback.confidence == .tentative
}
