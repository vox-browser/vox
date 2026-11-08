module main

fn test_automatic_script_policy_matches_only_wikipedia_http_hosts() {
	for address in ['https://wikipedia.org', 'https://www.wikipedia.org/',
		'https://en.wikipedia.org/wiki/V', 'http://ru.m.wikipedia.org:8080/',
		'https://WWW.WIKIPEDIA.ORG./', 'https://user:password@en.wikipedia.org/'] {
		assert !browser_scripting_enabled(address, .automatic), address
		assert browser_scripting_enabled(address, .enabled), address
	}
	for address in ['https://chatgpt.com/', 'https://github.com/vlang/v',
		'https://notwikipedia.org/', 'https://wikipedia.org.example/',
		'https://wikipedia.org@other.example/', 'https://example.org/wikipedia.org',
		'https://example.org/?site=https://wikipedia.org', 'file:///wikipedia.org/page.html',
		'data:text/html,wikipedia.org', 'about:blank', 'https://[::1]/', 'invalid URL'] {
		assert browser_scripting_enabled(address, .automatic), address
		assert !browser_scripting_enabled(address, .disabled), address
	}
}

