module main

import dom
import html
import highresolutiontime

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
	return parse_browser_navigation_document_with_optional_page_and_response_time(markup, document_url, initiator_origin, previous, none, response_time_ns)
}

fn parse_browser_navigation_document_for_page_with_response_time(markup string, document_url dom.URL, initiator_origin ?dom.Origin, previous ?&dom.Document, page &dom.Page, response_time_ns i64) &dom.Document {
	return parse_browser_navigation_document_with_optional_page_and_response_time(markup, document_url, initiator_origin, previous, page, response_time_ns)
}

fn create_browser_navigation_document(document_url dom.URL, origin dom.Origin, previous ?&dom.Document, page ?&dom.Page) !&dom.Document {
	if owner := page {
		return html.create_navigation_document_for_page(document_url, origin, previous, owner)
	}
	return html.create_navigation_document(document_url, origin, previous)
}

fn parse_browser_navigation_document_with_optional_page_and_response_time(markup string, document_url dom.URL, initiator_origin ?dom.Origin, previous ?&dom.Document, page ?&dom.Page, response_time_ns i64) &dom.Document {
	origin := html.determine_the_origin(document_url, html.SandboxingFlagSet{}, initiator_origin)
	mut document := create_browser_navigation_document(document_url, origin, previous, page) or {
		panic(err)
	}
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	document.load_timing_info.navigation_start_time = highresolutiontime.coarsen_time(f64(response_time_ns) / 1.0e6,
		settings.cross_origin_isolated_capability() == .yes)
	document.set_document_type(.html)
	document.set_allow_declarative_shadow_roots(true)
	html.parse_html_from_a_string(document, markup)
	return document
}
