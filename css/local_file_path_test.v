module css

fn test_stylesheet_file_paths_decode_the_path_without_url_metadata() {
	assert local_path_for_stylesheet_url('file:///tmp/a%20b%23c.css?v=1#rules')? == '/tmp/a b#c.css'
	assert local_path_for_stylesheet_url('https://example.com/a.css') == none
	assert local_path_for_stylesheet_url('file:///tmp/a%00b.css') == none
	$if windows {
		assert local_path_for_stylesheet_url('file:///C:/a%20b.css?v=1#rules')? == 'C:/a b.css'
	}
}
