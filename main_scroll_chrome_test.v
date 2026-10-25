module main

fn test_scrolling_hidden_diagnostics_does_not_update_native_chrome() {
	before := BrowserChromeState{
		width:      1024
		height:     852
		address:    'https://old.reddit.com/'
		status:     'scroll y=0'
		tab_titles: ['reddit']
	}
	after := BrowserChromeState{ ...before, status: 'scroll y=42' }
	assert !browser_chrome_requires_update(before, after)
	assert browser_chrome_requires_update(BrowserChromeState{ ...before, debug: true },
		BrowserChromeState{ ...after, debug: true })
	for changed in [
		BrowserChromeState{ ...after, debug: true },
		BrowserChromeState{ ...after, width: 800 },
		BrowserChromeState{ ...after, height: 700 },
		BrowserChromeState{ ...after, address: 'about:home' },
		BrowserChromeState{ ...after, footer: 'https://example.test/' },
		BrowserChromeState{ ...after, back: true },
		BrowserChromeState{ ...after, forward: true },
		BrowserChromeState{ ...after, reload: true },
		BrowserChromeState{ ...after, tab_titles: ['another title'] },
		BrowserChromeState{ ...after, selected_tab: 1 },
	] {
		assert browser_chrome_requires_update(before, changed)
	}
	assert !browser_chrome_requires_update(before, before)
}
