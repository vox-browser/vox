@[has_globals]
module loader

import dom
import fetch

fn content_blocker_url(input string) dom.URL {
	return dom.dom_url_parse(input, dom.url_about_blank(), 'UTF-8') or { panic('invalid URL') }
}

fn make_content_blocker(rules []string) &ContentBlocker {
	mut blocker := ContentBlocker.the()
	blocker.set_patterns(rules) or { panic(err) }
	blocker.set_filtering_enabled(true)
	return blocker
}

fn test_content_blocker_empty_pattern_list() {
	blocker := make_content_blocker([])
	assert !blocker.is_filtered(content_blocker_url('https://anything.com'))
	assert !blocker.is_filtered(content_blocker_url('data:text/plain,hi'))
}

fn test_content_blocker_basic_blocking_and_data_url_exemption() {
	blocker := make_content_blocker(['||ads.example.com^', '/banner.js', 'data:'])
	source_url := content_blocker_url('https://example.com/')
	assert blocker.is_filtered_for_resource(content_blocker_url('https://ads.example.com/script.js'), source_url,
		.script)
	assert blocker.is_filtered_for_resource(content_blocker_url('https://static.example.com/banner.js'), source_url,
		.script)
	assert !blocker.is_filtered_for_resource(content_blocker_url('https://example.com/page.html'), source_url,
		.document)
	assert !blocker.is_filtered(content_blocker_url('data:text/plain,hello'))
}

fn test_content_blocker_invalid_bytes_keep_rules_and_empty_rules_clear_them() {
	mut blocker := make_content_blocker(['||ads.example.com^'])
	source_url := content_blocker_url('https://example.com/')
	target := content_blocker_url('https://ads.example.com/script.js')
	assert blocker.has_rules()
	assert blocker.is_filtered_for_resource(target, source_url, .script)
	mut invalid_rejected := false
	blocker.set_rules_from_bytes([u8(0xff)]) or {
		invalid_rejected = true
	}
	assert invalid_rejected
	assert blocker.is_filtered_for_resource(target, source_url, .script)
	blocker.set_rules_from_bytes([])!
	assert !blocker.has_rules()
	assert !blocker.is_filtered_for_resource(target, source_url, .script)
}

fn test_content_blocker_disable_filtering() {
	mut blocker := make_content_blocker(['||example.com^', '##.ad'])
	blocker.set_filtering_enabled(false)
	url := content_blocker_url('https://example.com')
	assert !blocker.is_filtered(url)
	assert blocker.cosmetic_style_sheet_for_url(url, ['ad'], []) == ''
	blocker.set_filtering_enabled(true)
	assert blocker.is_filtered(url)
	assert blocker.cosmetic_style_sheet_for_url(url, ['ad'], []) != ''
}

fn test_content_blocker_fetch_metadata_maps_to_resource_type() {
	assert ContentBlocker.resource_type_from_fetch_metadata(fetch.Destination.document, none,
		.no_cors) == .document
	assert ContentBlocker.resource_type_from_fetch_metadata(fetch.Destination.font, fetch.InitiatorType.css,
		.no_cors) == .font
	assert ContentBlocker.resource_type_from_fetch_metadata(fetch.Destination.image, fetch.InitiatorType.css,
		.no_cors) == .image
	assert ContentBlocker.resource_type_from_fetch_metadata(fetch.Destination.style, none,
		.no_cors) == .stylesheet
	assert ContentBlocker.resource_type_from_fetch_metadata(fetch.Destination.iframe, none,
		.no_cors) == .subdocument
	assert ContentBlocker.resource_type_from_fetch_metadata(none, fetch.InitiatorType.fetch,
		.no_cors) == .xml_http_request
	assert ContentBlocker.resource_type_from_fetch_metadata(none, fetch.InitiatorType.ping,
		.no_cors) == .ping
	assert ContentBlocker.resource_type_from_fetch_metadata(none, none, .websocket) == .websocket
}

fn test_content_blocker_resource_type_options() {
	blocker := make_content_blocker([
		'||example.com/ad^$image',
		'||example.com/font^$font',
		'||example.com/document^$document',
		'||example.com/fetch^$xmlhttprequest',
	])
	source_url := content_blocker_url('https://example.com/')
	assert blocker.is_filtered_for_resource(content_blocker_url('https://example.com/ad'), source_url,
		.image)
	assert !blocker.is_filtered_for_resource(content_blocker_url('https://example.com/ad'), source_url,
		.script)
	assert blocker.is_filtered_with_metadata(content_blocker_url('https://example.com/ad'), source_url,
		fetch.Destination.image, fetch.InitiatorType.css, .no_cors)
	assert blocker.is_filtered_with_metadata(content_blocker_url('https://example.com/font'), source_url,
		fetch.Destination.font, fetch.InitiatorType.css, .no_cors)
	assert blocker.is_filtered_with_metadata(content_blocker_url('https://example.com/document'), source_url,
		fetch.Destination.document, none, .navigate)
	assert blocker.is_filtered_with_metadata(content_blocker_url('https://example.com/fetch'), source_url,
		none, fetch.InitiatorType.fetch, .cors)
}

fn test_content_blocker_file_scheme_fallback_and_exception_rules() {
	blocker := make_content_blocker(['secret', '||ads.example.com^', '@@||ads.example.com/allowed.js'])
	assert blocker.is_filtered(content_blocker_url('file:///home/user/secret.txt'))
	assert !blocker.is_filtered(content_blocker_url('file:///home/user/public.txt'))
	source_url := content_blocker_url('https://example.com/')
	assert blocker.is_filtered_for_resource(content_blocker_url('https://ads.example.com/blocked.js'), source_url,
		.script)
	assert !blocker.is_filtered_for_resource(content_blocker_url('https://ads.example.com/allowed.js'), source_url,
		.script)
}

fn test_content_blocker_party_and_blob_source_options() {
	blocker := make_content_blocker([
		'||tracker.example/third-party.gif$third-party',
		'||tracker.example/first-party.gif$first-party',
		'||ads.example/domain.js$domain=www.tracker.example',
	])
	same_site_blob := content_blocker_url('blob:https://www.tracker.example/4dd3d7ea-8bd7-4fe0-a121-79c18e2be4b2')
	cross_site_blob := content_blocker_url('blob:https://site.example/4dd3d7ea-8bd7-4fe0-a121-79c18e2be4b2')
	third_party := content_blocker_url('https://tracker.example/third-party.gif')
	first_party := content_blocker_url('https://tracker.example/first-party.gif')
	domain_rule := content_blocker_url('https://ads.example/domain.js')
	assert !is_third_party(third_party, ContentBlocker.source_url_for_matching(same_site_blob))
	assert is_third_party(third_party, ContentBlocker.source_url_for_matching(cross_site_blob))
	assert !blocker.is_filtered_for_resource(third_party, same_site_blob, .image)
	assert blocker.is_filtered_for_resource(first_party, same_site_blob, .image)
	assert blocker.is_filtered_for_resource(third_party, cross_site_blob, .image)
	assert !blocker.is_filtered_for_resource(first_party, cross_site_blob, .image)
	assert blocker.is_filtered_for_resource(domain_rule, same_site_blob, .script)
	assert !blocker.is_filtered_for_resource(domain_rule, cross_site_blob, .script)
}

fn test_content_blocker_document_navigation_party_source() {
	blocker := make_content_blocker(['||localhost^$third-party,document'])
	target := content_blocker_url('http://localhost:1234/content-blocker-target')
	assert blocker.is_filtered_for_resource(target, content_blocker_url('https://source.example/'),
		.document)
	assert !blocker.is_filtered_for_resource(target, target, .document)
}

fn test_content_blocker_cosmetic_style_sheet() {
	blocker := make_content_blocker([
		'example.com##.ad-banner',
		'example.com###sponsor',
		'example.com##.styled-sponsor:style(visibility: hidden)',
		'##.generic-ad',
		'###generic-sponsor',
	])
	style_sheet := blocker.cosmetic_style_sheet_for_url(content_blocker_url('https://example.com/'),
		['generic-ad'], ['generic-sponsor'])
	assert style_sheet.contains('.ad-banner { display: none !important; }')
	assert style_sheet.contains('#sponsor { display: none !important; }')
	assert style_sheet.contains('.styled-sponsor { visibility: hidden; }')
	assert style_sheet.contains('.generic-ad { display: none !important; }')
	assert style_sheet.contains('#generic-sponsor { display: none !important; }')
}

fn test_content_blocker_generic_selector_lists_match_later_selectors() {
	blocker := make_content_blocker([
		'##.first-ad-class, .second-ad-class',
		'##.first-ad-id, #second-ad-id',
		'##.class-keyed-arm, [data-ad]',
		'##.class-keyed-arm, div.sponsor',
	])
	url := content_blocker_url('https://example.com/')
	style_sheet := blocker.cosmetic_style_sheet_for_url(url, ['second-ad-class'], ['second-ad-id'])
	without_hints := blocker.cosmetic_style_sheet_for_url(url, [], [])
	assert style_sheet.contains('.first-ad-class, .second-ad-class { display: none !important; }')
	assert style_sheet.contains('.first-ad-id, #second-ad-id { display: none !important; }')
	assert without_hints.contains('.class-keyed-arm, [data-ad] { display: none !important; }')
	assert without_hints.contains('.class-keyed-arm, div.sponsor { display: none !important; }')
}

fn test_content_blocker_cosmetic_rule_detection() {
	without_cosmetics := make_content_blocker(['||example.com/ad^'])
	assert !without_cosmetics.has_cosmetic_rules()
	assert without_cosmetics.cosmetic_style_sheet(content_blocker_url('https://example.com/')) == ''
	with_cosmetics := make_content_blocker(['example.com##.ad-banner'])
	assert with_cosmetics.has_cosmetic_rules()
}
