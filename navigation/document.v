module main

import platform
import dom
import encoding
import html
import highresolutiontime
import mimesniff
import processmetrics

// BrowsingContext.cpp::determine_the_origin and navigation document creation.
// Compact top-level navigation has no inherited creation sandbox flags.
$if test {
	fn parse_browser_navigation_document(markup string, document_url dom.URL, initiator_origin ?dom.Origin) &dom.Document {
		return parse_browser_navigation_document_with_previous(markup, document_url, initiator_origin,
			none)
	}
}

// The source navigation reuse decision requires the actual prior Document,
// independently of the initiator origin used by determine_the_origin().
fn parse_browser_navigation_document_with_previous(markup string, document_url dom.URL, initiator_origin ?dom.Origin, previous ?&dom.Document) &dom.Document {
	origin := html.determine_the_origin(document_url, html.SandboxingFlagSet{}, initiator_origin)
	mut document := create_browser_navigation_document(document_url, origin, previous, none) or {
		panic(err)
	}
	document.set_document_type(.html)
	document.set_allow_declarative_shadow_roots(true)
	html.parse_html_from_a_string(document, markup)
	return document
}

// Document.cpp: responses made outside Fetch use their real monotonic creation
// time. The compact loader has no Fetch timing object; do not fabricate one.
$if test {
	fn parse_browser_navigation_document_with_response_time(markup string, document_url dom.URL, initiator_origin ?dom.Origin, previous ?&dom.Document, response_time_ns i64) &dom.Document {
		return parse_browser_navigation_document_with_optional_page_and_response_time(markup,
			document_url, initiator_origin, previous, none, response_time_ns)
	}
}

$if test {
	fn parse_browser_navigation_document_for_page_with_response_time(markup string, document_url dom.URL, initiator_origin ?dom.Origin, previous ?&dom.Document, page &dom.Page, response_time_ns i64) &dom.Document {
		return parse_browser_navigation_document_with_optional_page_and_response_time(markup,
			document_url, initiator_origin, previous, page, response_time_ns)
	}
}

fn create_browser_navigation_document(document_url dom.URL, origin dom.Origin, previous ?&dom.Document, page ?&dom.Page) !&dom.Document {
	mut document := if owner := page {
		html.create_navigation_document_for_page(document_url, origin, previous, owner)!
	} else {
		html.create_navigation_document(document_url, origin, previous)!
	}
	// Install the embedder's font policies before parsing resolves any styles.
	// An explicit canonical test font selects LibWeb's fixture metrics.
	install_browser_document_font_policies(mut document)
	document.set_display_device_pixel_ratio(html.display_device_pixel_ratio())
	install_browser_document_cookie_client(mut document)
	return document
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
	mut workspace := platform.begin_thread_scratch('navigation text decoding')
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
	workspace.leave()
	owned_markup := markup.clone()
	owned_encoding := encoding_name.clone()
	workspace.finish()
	return owned_markup, owned_encoding
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
	load_instruction_stage := processmetrics.begin_instruction_stage('navigation_html_parsing')
	defer { load_instruction_stage.finish() }
	// The parser retains its own source in the document arena. Keep the decoded
	// response alive only until that publication, while constructing reusable
	// Document/Window identity in the caller's ordinary allocation owner.
	workspace := platform.begin_thread_scratch('navigation decoded input')
	markup, encoding_name := loaded_browser_navigation_input(loaded)
	workspace.leave()
	document := parse_browser_navigation_document_input_with_source(markup, encoding_name, document_url,
		initiator_origin, previous, page, loaded.monotonic_response_time_ns, scripting_enabled,
		loaded.javascript_url_source)
	workspace.finish()
	return document
}

fn parse_browser_navigation_document_input(markup string, document_encoding ?string, document_url dom.URL, initiator_origin ?dom.Origin, previous ?&dom.Document, page ?&dom.Page, response_time_ns i64, scripting_enabled bool) &dom.Document {
	return parse_browser_navigation_document_input_with_source(markup, document_encoding, document_url,
		initiator_origin, previous, page, response_time_ns, scripting_enabled, none)
}

// Navigation installs document-owned clients before consuming parser input.
struct PreparedBrowserNavigationDocument {
	document &dom.Document
	markup string
}

fn prepare_loaded_browser_navigation_document(loaded LoadedPage, document_url dom.URL, initiator_origin ?dom.Origin, previous ?&dom.Document, page ?&dom.Page, scripting_enabled bool) PreparedBrowserNavigationDocument {
	markup, encoding_name := loaded_browser_navigation_input(loaded)
	document := create_browser_navigation_document_input_with_source(encoding_name, document_url,
		initiator_origin, previous, page, loaded.monotonic_response_time_ns, scripting_enabled,
		loaded.javascript_url_source)
	return PreparedBrowserNavigationDocument{ document: document, markup: markup }
}

fn parse_prepared_browser_navigation_document(input PreparedBrowserNavigationDocument) {
	mut allocations := input.document.enter_native_storage()
	defer { allocations.finish() }
	html.parse_html_from_a_string(input.document, input.markup)
}

fn parse_browser_navigation_document_input_with_source(markup string, document_encoding ?string, document_url dom.URL, initiator_origin ?dom.Origin, previous ?&dom.Document, page ?&dom.Page, response_time_ns i64, scripting_enabled bool, javascript_url_source ?&dom.Document) &dom.Document {
	document := create_browser_navigation_document_input_with_source(document_encoding, document_url,
		initiator_origin, previous, page, response_time_ns, scripting_enabled, javascript_url_source)
	parse_prepared_browser_navigation_document(PreparedBrowserNavigationDocument{
		document: document
		markup: markup
	})
	return document
}

fn create_browser_navigation_document_input_with_source(document_encoding ?string, document_url dom.URL, initiator_origin ?dom.Origin, previous ?&dom.Document, page ?&dom.Page, response_time_ns i64, scripting_enabled bool, javascript_url_source ?&dom.Document) &dom.Document {
	phase_mark := platform.arena_phase_begin()
	defer {
		platform.arena_phase_end('html_parse', phase_mark)
	}
	origin := html.determine_the_origin(document_url, html.SandboxingFlagSet{}, initiator_origin)
	mut document := create_browser_navigation_document(document_url, origin, previous, page) or {
		panic(err)
	}
	// Construct context/realm identity before entering the payload arena. These
	// objects can be reused by a later navigation.
	document.enable_native_storage()
	mut allocations := document.enter_native_storage()
	defer { allocations.finish() }
	if source := javascript_url_source {
		// Policy containers preserve source identities across javascript: URL
		// replacement. Keep their source allocation owner until these aliases
		// acquire an explicit independent lifetime.
		mut source_storage := source.native_storage()
		if source_storage != unsafe { nil } { source_storage.pin() }
		document.set_origin(source.origin())
		policy := source.policy_container().clone()
		document.set_policy_container(&policy)
		document.set_active_sandboxing_flag_bits(source.active_sandboxing_flag_bits())
		document.set_opener_policy(source.opener_policy())
	}
	if encoding_name := document_encoding {
		document.set_encoding(encoding_name.clone())
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
	return document
}
