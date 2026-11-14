module url

fn test_file_urls_preserve_windows_drives_and_decode_only_the_path() {
	for source, expected in {
		'file:///C:/vox/keyboard.html':                 'C:/vox/keyboard.html'
		'file:///d:/a%20b/%23%3F.txt?version=1#anchor': 'd:/a b/#?.txt'
		'file://localhost/C:/a.txt':                    'C:/a.txt'
		'file:///C|/a.txt':                             'C:/a.txt'
		'file:///C:/':                                  'C:/'
		'file://server/share/a%20b.txt':                '//server/share/a b.txt'
	} {
		record := parse(source) or { panic(source) }
		assert record.file_path_for_platform(true)? == expected
	}
}

fn test_file_url_conversion_keeps_unix_paths_and_rejects_invalid_sources() {
	for source in ['file:///tmp/a%20b.html?version=1#anchor', 'file://localhost/tmp/a%20b.html'] {
		record := parse(source) or { panic(source) }
		assert record.file_path_for_platform(false)? == '/tmp/a b.html'
	}
	windows_path := parse('file:///C:/a.txt')?
	assert windows_path.file_path_for_platform(false)? == '/C:/a.txt'
	for source in ['https://example.com/a', 'file:///tmp/a%00b'] {
		record := parse(source)?
		assert record.file_path_for_platform(false) == none
		assert record.file_path_for_platform(true) == none
	}
	remote := parse('file://server/share/a.txt')?
	assert remote.file_path_for_platform(false) == none
}
