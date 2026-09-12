@[has_globals]
module loader

import dom
import os

fn test_error_page_escapes_inserted_values() {
	error_page := load_error_page(dom.URL{'https://example.test/?x=<tag>'}, '<boom> & "bad"')
	// URL serialization percent-encodes forbidden query code points before the
	// generated page applies HTML escaping.
	assert error_page.contains('x=%3Ctag%3E')
	assert error_page.contains('&lt;boom&gt; &amp; &quot;bad&quot;')
	assert !error_page.contains('<boom>')
}

fn test_directory_page_sorts_entries_marks_kinds_and_escapes_names() {
	directory := os.join_path(os.temp_dir(), 'libweb_v_loader_${os.getpid()}')
	if os.exists(directory) {
		os.rmdir_all(directory) or { panic(err) }
	}
	os.mkdir_all(os.join_path(directory, 'b-dir')) or { panic(err) }
	os.write_file(os.join_path(directory, 'a<&>.txt'), 'hello') or { panic(err) }
	defer {
		os.rmdir_all(directory) or {}
	}
	page := load_file_directory_page(dom.URL{'file://${directory}'}) or { panic(err) }
	assert page.index('a&lt;&amp;&gt;.txt') or { -1 } < page.index('b-dir') or { -1 }
	assert page.contains('class="file"')
	assert page.contains('class="folder"')
	assert page.contains('5 B')
}
