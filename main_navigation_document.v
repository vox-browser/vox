module main

import dom
import html

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
