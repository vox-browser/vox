module main

import dom
import encoding
import html
import highresolutiontime
import mimesniff

// BrowsingContext.cpp::determine_the_origin and navigation document creation.
// Compact top-level navigation has no inherited creation sandbox flags.
fn parse_browser_navigation_document(markup string, document_url dom.URL, initiator_origin ?dom.Origin) &dom.Document {
	origin := html.determine_the_origin(document_url, html.SandboxingFlagSet{}, initiator_origin)
	return html.parse_navigation_document(markup, document_url, origin, none) or { panic(err) }
}

// The source navigation reuse decision requires the actual prior Document,
// independently of the initiator origin used by determine_the_origin().
fn parse_browser_navigation_document_with_previous(markup string, document_url dom.URL, initiator_origin ?dom.Origin, previous ?&dom.Document) &dom.Document {
	origin := html.determine_the_origin(document_url, html.SandboxingFlagSet{}, initiator_origin)
	return html.parse_navigation_document(markup, document_url, origin, previous) or { panic(err) }
}

// Document.cpp: responses made outside Fetch use their real monotonic creation
// time. The compact loader has no Fetch timing object; do not fabricate one.
fn parse_browser_navigation_document_with_response_time(markup string, document_url dom.URL, initiator_origin ?dom.Origin, previous ?&dom.Document, response_time_ns i64) &dom.Document {
	return parse_browser_navigation_document_with_optional_page_and_response_time(markup,
		document_url, initiator_origin, previous, none, response_time_ns)
}

fn parse_browser_navigation_document_for_page_with_response_time(markup string, document_url dom.URL, initiator_origin ?dom.Origin, previous ?&dom.Document, page &dom.Page, response_time_ns i64) &dom.Document {
	return parse_browser_navigation_document_with_optional_page_and_response_time(markup,
		document_url, initiator_origin, previous, page, response_time_ns)
}

fn create_browser_navigation_document(document_url dom.URL, origin dom.Origin, previous ?&dom.Document, page ?&dom.Page) !&dom.Document {
	if owner := page {
		return html.create_navigation_document_for_page(document_url, origin, previous, owner)
	}
	return html.create_navigation_document(document_url, origin, previous)
}

fn parse_browser_navigation_document_with_optional_page_and_response_time(markup string, document_url dom.URL, initiator_origin ?dom.Origin, previous ?&dom.Document, page ?&dom.Page, response_time_ns i64) &dom.Document {
	return parse_browser_navigation_document_with_scripting(markup, document_url, initiator_origin,
		previous, page, response_time_ns, true)
}

fn parse_browser_navigation_document_with_scripting(markup string, document_url dom.URL, initiator_origin ?dom.Origin, previous ?&dom.Document, page ?&dom.Page, response_time_ns i64, scripting_enabled bool) &dom.Document {
	return parse_browser_navigation_document_input(markup, none, document_url, initiator_origin,
		previous, page, response_time_ns, scripting_enabled)
}

// HTTP bodies are bytes, unlike the Unicode input accepted by the string
// parsing entry points above. Use the translated HTML encoding sniffing rules
// before the tokenizer consumes them: a BOM wins over the transport charset,
// which wins over a meta declaration.
fn decode_browser_navigation_response(body string, content_type string) (string, string) {
	transport_encoding := if mime := mimesniff.MimeType.parse(content_type) {
		mime.parameters()['charset']
	} else {
		none
	}
	encoding_name := html.run_html_encoding_sniffing_algorithm(body.bytes(), transport_encoding)
	decoder := encoding.TextDecoder.construct(encoding_name, encoding.TextDecoderOptions{}) or {
		panic(err)
	}
	markup := decoder.decode(body.bytes(), encoding.TextDecodeOptions{}) or { panic(err) }
	return markup, encoding_name
}

fn loaded_browser_navigation_input(loaded LoadedPage) (string, ?string) {
	if loaded.javascript_url_source != none { return loaded.markup, 'UTF-8' }
	if loaded.url.starts_with('http://') || loaded.url.starts_with('https://') {
		markup, encoding_name := decode_browser_navigation_response(loaded.markup,
			loaded.content_type)
		return markup, encoding_name
	}
	return loaded.markup, none
}

fn parse_loaded_browser_navigation_document(loaded LoadedPage, document_url dom.URL, initiator_origin ?dom.Origin, previous ?&dom.Document, page ?&dom.Page, scripting_enabled bool) &dom.Document {
	markup, encoding_name := loaded_browser_navigation_input(loaded)
	mut document := parse_browser_navigation_document_input_with_source(markup, encoding_name, document_url,
		initiator_origin, previous, page, loaded.monotonic_response_time_ns, scripting_enabled,
		loaded.javascript_url_source)
	// Also honor the policy in saved copies whose explicit base URL identifies
	// the site.
	if browser_host_uses_chromium_rendering(document.base_url().serialized_host()) {
		document.set_font_size_keyword_policy(.chromium)
		document.set_font_rendering_policy(.chromium)
	}
	return document
}

// Sites compared pixel for pixel against Chromium use its font-size keywords,
// installed-font matching and inline geometry. Old Reddit's compact layout
// relies on the legacy 10px x-small mapping.
fn browser_host_uses_chromium_rendering(serialized_host string) bool {
	host := serialized_host.to_lower().trim_right('.')
	return host == 'old.reddit.com' || host == 'wikipedia.org' || host.ends_with('.wikipedia.org')
		|| host == 'cnn.com' || host.ends_with('.cnn.com') || host == '4chan.org'
		|| host.ends_with('.4chan.org')
		|| host == 'asgardpvp.com' || host.ends_with('.asgardpvp.com')
}

fn parse_browser_navigation_document_input(markup string, document_encoding ?string, document_url dom.URL, initiator_origin ?dom.Origin, previous ?&dom.Document, page ?&dom.Page, response_time_ns i64, scripting_enabled bool) &dom.Document {
	return parse_browser_navigation_document_input_with_source(markup, document_encoding, document_url,
		initiator_origin, previous, page, response_time_ns, scripting_enabled, none)
}

fn parse_browser_navigation_document_input_with_source(markup string, document_encoding ?string, document_url dom.URL, initiator_origin ?dom.Origin, previous ?&dom.Document, page ?&dom.Page, response_time_ns i64, scripting_enabled bool, javascript_url_source ?&dom.Document) &dom.Document {
	origin := html.determine_the_origin(document_url, html.SandboxingFlagSet{}, initiator_origin)
	mut document := create_browser_navigation_document(document_url, origin, previous, page) or {
		panic(err)
	}
	if source := javascript_url_source {
		document.set_origin(source.origin())
		policy := source.policy_container().clone()
		document.set_policy_container(&policy)
		document.set_active_sandboxing_flag_bits(source.active_sandboxing_flag_bits())
		document.set_opener_policy(source.opener_policy())
	}
	if encoding_name := document_encoding {
		document.set_encoding(encoding_name)
	}
	document.set_scripting_enabled_by_embedder(scripting_enabled)
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	document.load_timing_info.navigation_start_time = highresolutiontime.coarsen_time(f64(response_time_ns) / 1.0e6,
		settings.cross_origin_isolated_capability() == .yes)
	document.set_document_type(.html)
	document.set_allow_declarative_shadow_roots(true)
	// This compact embedder creates the active navigation document directly,
	// rather than committing it through session-history traversal. Grant the
	// source document's script readiness before parser-inserted import maps run.
	document.set_ready_to_run_scripts()
	html.parse_html_from_a_string(document, markup)
	return document
}
