module main

import dom
import html

// BrowsingContext.cpp::determine_the_origin and navigation document creation.
// Compact top-level navigation has no inherited creation sandbox flags.
fn parse_browser_navigation_document(markup string, document_url dom.URL, initiator_origin ?dom.Origin) &dom.Document {
	origin := html.determine_the_origin(document_url, html.SandboxingFlagSet{}, initiator_origin)
	return html.parse_document_with_url_and_origin(markup, document_url, origin)
}
