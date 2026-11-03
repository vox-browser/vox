module main

import html
import dom
import os
import platform

const disable_tokenized_navigation_preloads = os.getenv('VOX_DISABLE_TOKENIZED_NAVIGATION_PRELOADS') != ''

struct TokenizedNavigationPreloads {
	urls []string
	types map[string]string
}

// Only the scripting-enabled path discards discovery without computed styles.
// Preserve the full parser for foreign/template/selection contexts, bases,
// preferred stylesheet sets and document policy/encoding changes.
fn tokenized_navigation_preloads(loaded LoadedPage) ?TokenizedNavigationPreloads {
	mut work := platform.begin_thread_scratch('tokenized navigation preloads')
	markup, _ := loaded_browser_navigation_input(loaded)
	address := dom.dom_url_parse(loaded.url, dom.url_about_blank(), 'UTF-8') or {
		work.finish()
		return none
	}
	result := collect_tokenized_navigation_preloads(markup, address.serialize()) or {
		work.finish()
		return none
	}
	work.leave()
	mut urls := []string{cap:result.urls.len}
	mut types := map[string]string{}
	for resource_address in result.urls { urls << resource_address.clone() }
	for resource_address, kind in result.types { types[resource_address.clone()] = kind.clone() }
	work.finish()
	return TokenizedNavigationPreloads{urls:urls, types:types}
}

fn collect_tokenized_navigation_preloads(markup string, base_url string) ?TokenizedNavigationPreloads {
	mut tokenizer := html.HTMLTokenizer.new(markup)
	mut styles := []string{}
	mut scripts := []string{}
	mut script_type_urls := []string{}
	mut images := []string{}
	mut saw_html := false
	mut saw_head := false
	mut saw_body := false
	mut steps := 0
	for {
		steps++
		if steps % 128 == 0 { platform.cooperative_work_checkpoint() }
		if tokenizer.skip_resource_discovery_text_run() { continue }
		token := tokenizer.next_token() or { break }
		if token.is_end_of_file() { break }
		if !token.is_start_tag() { continue }
		name := token.tag_name
		if token.had_duplicate_attribute() || name in ['base','noscript','template','svg','math',
			'select','frameset','frame','iframe','object','plaintext','image','feimage'] { return none }
		if name == 'html' { saw_html = true }
		if name == 'head' {
			if !saw_html || saw_body { return none }
			saw_head = true
		}
		if name == 'body' {
			if !saw_html || !saw_head { return none }
			saw_body = true
		}
		if name == 'meta' && token.attribute('http-equiv') != none { return none }
		if name == 'style' && (token.attribute('title') or { '' }) != '' { return none }
		if name == 'link' {
			relations := (token.attribute('rel') or { '' }).to_lower().fields()
			stylesheet := 'stylesheet' in relations
			preload := 'preload' in relations && (token.attribute('as') or { '' }).to_lower() == 'style'
			if stylesheet && (token.has_attribute('disabled')
				|| (token.attribute('title') or { '' }) != '') { return none }
			if 'alternate' in relations && stylesheet { return none }
			valid_preload := preload && (token.attribute('type') or { '' }).split(';')[0].trim_space().to_lower() in ['', 'text/css']
			if (stylesheet || valid_preload) && token.has_attribute('href') {
				styles << resolve_document_reference(token.attribute('href') or { '' }, base_url)
			}
		} else if name == 'script' {
			type_ := (token.attribute('type') or { '' }).trim_space().to_lower()
			if token.has_attribute('src') {
				resource := resolve_document_reference(token.attribute('src') or { '' }, base_url)
				script_type_urls << resource
				if type_ in ['', 'text/javascript', 'application/javascript', 'module'] { scripts << resource }
			}
		} else if name == 'img' && !base_url.starts_with('file://') && token.has_attribute('src') {
			images << resolve_document_reference(token.attribute('src') or { '' }, base_url)
		}
		match name {
			'script' { tokenizer.switch_to(.script_data) }
			'style', 'xmp', 'noembed', 'noframes' { tokenizer.switch_to(.rawtext) }
			'title', 'textarea' { tokenizer.switch_to(.rcdata) }
			else {}
		}
	}
	if !saw_html || !saw_head || !saw_body { return none }
	mut urls := []string{}
	mut seen := map[string]bool{}
	mut types := map[string]string{}
	// Match the full discovery classifier even when a URL also occurs in a
	// non-JavaScript script element and is selected by an image elsewhere.
	for address in styles { types[address] = 'stylesheet' }
	for address in script_type_urls {
		if address !in types { types[address] = 'script' }
	}
	for group in [styles, scripts, images] {
		for address in group {
			if !address.starts_with('http://') && !address.starts_with('https://') { continue }
			if address in seen { continue }
			seen[address] = true
			urls << address
			if urls.len == max_preloaded_resources { return TokenizedNavigationPreloads{urls:urls, types:types} }
		}
	}
	return TokenizedNavigationPreloads{urls:urls, types:types}
}

fn (mut app BrowserApp) start_tokenized_page_preload(loaded LoadedPage, add_history bool,
	discovery TokenizedNavigationPreloads) {
	if discovery.urls.len == 0 {
		app.commit_preloaded_page(loaded, add_history)
		return
	}
	mut pending := PendingPagePreload{
		loaded:loaded, add_history:add_history, generation:app.navigation_generation,
		results:chan PreloadedResource{cap:discovery.urls.len}
	}
	initial_urls := discovery.urls.filter((discovery.types[it] or { 'image' }) != 'image')
	queue_navigation_preloads(mut pending, initial_urls, discovery.types, app.resource_cache)
	app.pending_page_preload = pending
	if pending.remaining == 0 { request_browser_frame() }
}
