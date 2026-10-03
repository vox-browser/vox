module url

fn internal_test_url(value string) URL { return parse(value) or { panic('Invalid test URL') } }

fn test_source_webui_url_membership_is_exact_complete_url() {
	for name in ['bookmarks', 'downloads', 'history', 'newtab', 'processes', 'settings', 'version'] {
		assert is_webui_url(internal_test_url('about:' + name))
		assert !is_webui_url(internal_test_url('about:' + name + '#'))
		assert !is_webui_url(internal_test_url('about:' + name + '?'))
		assert !is_webui_url(internal_test_url('about:' + name.to_upper()))
	}
}

fn test_source_webui_url_uses_parsed_scheme_and_excludes_other_about_pages() {
	assert is_webui_url(internal_test_url('ABOUT:newtab'))
	for value in ['about:blank', 'about:srcdoc', 'about:newtab/path', 'https://example.test/settings',
		'about:%6eewtab'] {
		assert !is_webui_url(internal_test_url(value))
	}
}
