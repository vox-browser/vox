module optimizedsites

import encoding.base64

fn test_default_favicons_are_distinct_embedded_originals_and_do_not_match_unrelated_hosts() {
	mut icons := []string{}
	for site in sites {
		icon := favicon_data_url(site.address)
		assert icon.starts_with('data:image/') && icon.contains(';base64,')
		assert base64.decode(icon.all_after(';base64,')).len > 100
		assert icon !in icons
		icons << icon
	}
	assert favicon_data_url('https://en.wikipedia.org/wiki/V') == icons[0]
	assert favicon_data_url('https://en.wikipedia.org/wiki/Main_Page') == icons[0]
	assert favicon_data_url('https://old.reddit.com/r/programming/') == icons[1]
	for address in ['https://notvlang.io/', 'https://vlang.io.evil.test/',
		'https://wikipedia.org@evil.test/', 'file:///wikipedia.org', 'javascript:void(0)'] {
		assert favicon_data_url(address) == ''
	}
}
