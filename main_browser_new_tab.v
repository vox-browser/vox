module main

import browserhistory
import css
import dom
import html
import platform

const browser_new_tab_url = 'vox://newtab'

fn is_browser_new_tab_url(address string) bool {
	return address.trim_right('/') in [browser_new_tab_url, 'about:newtab', 'chrome://newtab']
}

fn browser_new_tab_allows_favicon_url(address dom.URL) bool {
	return (address.scheme() in ['http', 'https'] && address.username() == '' && address.password() == '')
		|| (address.scheme() == 'data' && address.serialize().to_lower().starts_with('data:image/'))
}

fn browser_new_tab_favicon_url(site browserhistory.MostVisitedSite) string {
	if site.favicon_url != '' {
		if address := dom.dom_url_parse(site.favicon_url, dom.url_about_blank(), 'UTF-8') {
			if browser_new_tab_allows_favicon_url(address) { return address.serialize() }
		}
	}
	page_url := dom.dom_url_parse(site.url, dom.url_about_blank(), 'UTF-8') or { return '' }
	return (dom.dom_url_parse('/favicon.ico', page_url, 'UTF-8') or { return '' }).serialize()
}

fn (app &BrowserApp) browser_new_tab_sites() string {
	mut tiles := []string{}
	if app.browsing_history != unsafe { nil } {
		for site in app.browsing_history.most_visited(8, browserhistory.now()) {
			title := if site.title.trim_space() != '' { site.title } else { site.host }
			initial := site.host.runes()[0].str().to_upper()
			favicon := browser_new_tab_favicon_url(site)
			tiles << '<a class="site-tile" href="${browser_history_escape(site.url)}" title="${browser_history_escape(title)}"><span class="site-icon" aria-hidden="true"><img class="site-favicon" src="${browser_history_escape(favicon)}" alt="${browser_history_escape(initial)}" width="32" height="32" referrerpolicy="no-referrer"></span><span class="site-title" dir="auto">${browser_history_escape(title)}</span></a>'
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
	return '<!doctype html><html><head><meta charset="utf-8"><meta name="color-scheme" content="light dark"><title>New Tab</title><style>${browser_new_tab_css}</style></head><body><main><div id="new-tab-sites">${app.browser_new_tab_sites()}</div></main></body></html>'
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
		app.install_browser_new_tab_image_fetch_hooks()
		app.new_tab_history_version = app.browsing_history.version
		request_browser_frame()
	}
}

fn (mut app BrowserApp) install_browser_new_tab_image_fetch_hooks() {
	if app.document == unsafe { nil } || !is_browser_new_tab_url(app.document.url_string()) { return }
	mut loader := app.image_request_loader or { return }
	initial_resources := loader.resources
	loader.resources = initial_resources.clone()
	defer { loader.resources = initial_resources }
	for address, resource in app.resource_cache { loader.resources[address] = resource }
	for image in css.query_selector_all(app.document.as_node(), 'img.site-favicon') {
		mut model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(image) })
		if model.has_fetch_hook() { continue }
		model.set_model_async_fetch_hook(fn [loader] (model &html.HTMLImageElementModel, address dom.URL,
			complete html.HTMLImageFetchCompletion) {
			image := model.image_element() or { finish_browser_image_request(complete, none); return }
			mut mutable_loader := unsafe { &BrowserImageRequestLoader(loader) }
			mutable_loader.request(image, model, address, complete)
		})
		model.update_the_image_data(false, false)
	}
}

const browser_new_tab_css = '
* { box-sizing: border-box; }
html { color-scheme: light dark; }
body { margin: 0; background: #fff; color: #202124; font-family: Arial, sans-serif; }
main { min-height: 100vh; display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 40px 24px; }
#new-tab-sites { width: 100%; max-width: 664px; }
.sites { display: flex; flex-wrap: wrap; justify-content: center; gap: 8px; }
.site-tile { display: flex; flex-direction: column; align-items: center; gap: 12px; width: 160px; max-width: 100%; padding: 16px 8px; border-radius: 8px; text-decoration: none; color: inherit; }
.site-tile:hover { background: #f1f3f4; }
.site-tile:focus-visible { outline: 2px solid #1a73e8; outline-offset: 2px; }
.site-icon { display: flex; align-items: center; justify-content: center; width: 48px; height: 48px; flex-shrink: 0; border-radius: 50%; background: #f1f3f4; color: #3c4043; font-size: 20px; font-weight: 500; }
.site-favicon { width: 32px; height: 32px; object-fit: contain; text-align: center; line-height: 32px; }
.site-title { display: block; width: 100%; overflow: hidden; overflow-wrap: anywhere; line-clamp: 3; text-align: center; font-size: 13px; line-height: 20px; }
.empty { color: #5f6368; font-size: 14px; line-height: 22px; text-align: center; margin: 0; }
@media (prefers-color-scheme: dark) {
body { background: #202124; color: #e8eaed; }
.empty { color: #bdc1c6; }
.site-icon { background: #303134; color: #e8eaed; }
.site-tile:hover { background: #303134; }
.site-tile:focus-visible { outline-color: #8ab4f8; }
}
'
