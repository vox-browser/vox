module main

import browserhistory
import platform

const browser_new_tab_url = 'vox://newtab'

fn is_browser_new_tab_url(address string) bool {
	return address.trim_right('/') in [browser_new_tab_url, 'about:newtab', 'chrome://newtab']
}

fn (app &BrowserApp) browser_new_tab_sites() string {
	mut tiles := []string{}
	if app.browsing_history != unsafe { nil } {
		for site in app.browsing_history.most_visited(8, browserhistory.now()) {
			title := if site.title.trim_space() != '' { site.title } else { site.host }
			initial := site.host.runes()[0].str().to_upper()
			tiles << '<a class="site-tile" href="${browser_history_escape(site.url)}" title="${browser_history_escape(title)}"><span class="site-icon" aria-hidden="true">${browser_history_escape(initial)}</span><span class="site-title" dir="auto">${browser_history_escape(title)}</span></a>'
		}
	}
	if tiles.len == 0 {
		return '<p class="empty">Sites you visit most will appear here.</p>'
	}
	return '<nav class="sites" aria-label="Most visited sites">${tiles.join('')}</nav>'
}

fn (mut app BrowserApp) browser_new_tab_markup() string {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	app.new_tab_history_version = if app.browsing_history != unsafe { nil } {
		app.browsing_history.version
	} else { u64(0) }
	return '<!doctype html><html><head><meta charset="utf-8"><meta name="color-scheme" content="light dark"><title>New Tab</title><style>${browser_new_tab_css}</style></head><body><main><h1>Vox</h1><h2>Most visited</h2><div id="new-tab-sites">${app.browser_new_tab_sites()}</div></main></body></html>'
}

fn (mut app BrowserApp) poll_browser_new_tab_page() {
	if app.source_label != browser_new_tab_url || app.document == unsafe { nil }
		|| app.document.url_string() != browser_new_tab_url
		|| app.browsing_history == unsafe { nil }
		|| app.new_tab_history_version == app.browsing_history.version { return }
	mut allocations := app.browser_history_document_storage()
	defer { allocations.finish() }
	if mut sites := app.document.get_element_by_id('new-tab-sites') {
		sites.set_inner_html(app.browser_new_tab_sites()) or { return }
		app.new_tab_history_version = app.browsing_history.version
		request_browser_frame()
	}
}

const browser_new_tab_css = '
* { box-sizing: border-box; }
html { color-scheme: light dark; }
body { margin: 0; background: #fff; color: #202124; font-family: Arial, sans-serif; }
main { min-height: 100vh; display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 40px 24px; }
h1 { font-size: 64px; font-weight: 600; letter-spacing: -3px; margin: 0 0 28px; }
h2 { font-size: 14px; font-weight: 400; color: #5f6368; margin: 0 0 20px; }
#new-tab-sites { width: 100%; max-width: 472px; }
.sites { display: flex; flex-wrap: wrap; justify-content: center; gap: 8px; }
.site-tile { display: flex; flex-direction: column; align-items: center; gap: 12px; width: 112px; padding: 16px 8px; border-radius: 8px; text-decoration: none; color: inherit; }
.site-tile:hover { background: #f1f3f4; }
.site-tile:focus-visible { outline: 2px solid #1a73e8; outline-offset: 2px; }
.site-icon { display: flex; align-items: center; justify-content: center; width: 48px; height: 48px; border-radius: 50%; background: #f1f3f4; color: #3c4043; font-size: 20px; font-weight: 500; }
.site-title { display: block; width: 100%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; text-align: center; font-size: 13px; line-height: 20px; }
.empty { color: #5f6368; font-size: 14px; line-height: 22px; text-align: center; margin: 0; }
@media (prefers-color-scheme: dark) {
body { background: #202124; color: #e8eaed; }
h2, .empty { color: #bdc1c6; }
.site-icon { background: #303134; color: #e8eaed; }
.site-tile:hover { background: #303134; }
.site-tile:focus-visible { outline-color: #8ab4f8; }
}
'
