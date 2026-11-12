module main

import encoding
import html
import platform

fn test_navigation_decoding_workspace_preserves_sniffing_boms_and_replacement() {
	for sample in [
		['<meta charset="utf-8"><p>日本語😀</p>', 'text/html'],
		['<p>plain</p>', 'text/html; charset=utf-8'],
		[[u8(0xef), 0xbb, 0xbf].bytestr() + '<p>BOM</p>', 'text/html; charset=windows-1252'],
		[[u8(0xff), 0xfe, 0x41, 0, 0x3d, 0xd8, 0, 0xde].bytestr(), 'text/html; charset=utf-8'],
		[[u8(0xfe), 0xff, 0, 0x41].bytestr(), 'text/html'],
		['<meta charset="windows-1252">' + [u8(0x80), 0xe9].bytestr(), 'text/html'],
		[[u8(0x61), 0xc0, 0xaf, 0xff, 0x62].bytestr(), 'text/html; charset=utf-8'],
		['', 'text/html'],
	] {
		transport := if sample[1].contains('charset=') { ?string(sample[1].all_after('charset=')) } else { none }
		expected_encoding := html.run_html_encoding_sniffing_algorithm(sample[0].bytes(), transport)
		decoder := encoding.TextDecoder.construct(expected_encoding, encoding.TextDecoderOptions{})!
		expected := decoder.decode(sample[0].bytes(), encoding.TextDecodeOptions{})!
		actual, encoding_name := decode_browser_navigation_response(sample[0], sample[1])
		mut reuse := platform.begin_thread_scratch('reuse decoded text workspace')
		_ = []u8{len: 65536, init: 0xa5}
		reuse.finish()
		assert actual == expected
		assert encoding_name == expected_encoding
	}
}

fn test_navigation_text_keeps_only_owned_output_after_utf16_decoder_work() {
	body := '<meta charset="utf-8">' + '<p>日本語😀 retained text</p>'.repeat(4096)
	before := platform.thread_arena_usage().used
	markup, encoding_name := decode_browser_navigation_response(body, 'text/html')
	after := platform.thread_arena_usage().used
	assert markup == body
	assert encoding_name.to_lower() == 'utf-8'
	$if prealloc { assert after - before < markup.len + 4096 }
}

// Keep the optional encoding wrapped across the tuple return. FastC otherwise
// exposes string bytes as an option, which crashes HTTP resource preloading.
fn test_navigation_input_keeps_the_optional_response_encoding() {
    for url in ['http://example.test/', 'https://example.test/'] {
        markup, charset := loaded_browser_navigation_input(LoadedPage{
            url: url
            markup: '<p>decoded</p>'
            content_type: 'text/html; charset=utf-8'
        })
        assert markup == '<p>decoded</p>'
        assert charset or { panic('missing HTTP encoding') } == 'UTF-8'
    }
    markup, charset := loaded_browser_navigation_input(LoadedPage{
        url: 'file:///input.html'
        markup: '<p>local</p>'
    })
    assert markup == '<p>local</p>'
    assert charset == none
}
