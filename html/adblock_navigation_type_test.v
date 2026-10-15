module html

import dom
import fetch

struct AdblockNavigationObservation {
mut:
	types               []string
	initiator_top_level []bool
}

fn test_adblock_navigation_type_follows_target_navigable_instead_of_initiator_window() {
	mut document := dom.Document.create(dom.URL{ value: 'https://www.theverge.com/article' })
	document.set_origin(document.url.origin())
	document.populate_with_html_head_and_body()!
	defer { document.finalize() }
	window := WindowModel.create_top_level(document, none, 'adblock-navigation')!
	parent := window.navigable_model()
	mut realm := &ScriptingRealm{}
	settings := WindowEnvironmentSettingsObject.setup(window, document.url, mut realm, none,
		document.url, document.origin()).settings
	mut child_document :=
		dom.Document.create(dom.URL{ value: 'https://frame.example.test/initial' })
	child_document.set_origin(child_document.url.origin())
	child_document.populate_with_html_head_and_body()!
	defer { child_document.finalize() }
	child_context := BrowsingContextModel.create(child_document, window.browsing_context(),
		'adblock-frame')
	child_window := WindowModel.create(child_document, child_context)!
	child := child_window.navigable_model()
	observation := &AdblockNavigationObservation{}
	hook := fn [observation] (request &fetch.Request) !&fetch.Response {
		mut seen := unsafe { &AdblockNavigationObservation(observation) }
		assert (request.destination or { panic('missing navigation destination') }) == .document
		assert request.clone().adblock_context().request_type == request.adblock_context().request_type
		seen.types << request.adblock_context().request_type
		seen.initiator_top_level << request.client_is_top_level_window
		return fetch.Response.network_error('classification captured')
	}
	for target in [parent, child] {
		entry := &SessionHistoryEntry{
			url:            dom.URL{
				value: 'https://frame.example.test/document'
			}
			document_state: &DocumentState{}
		}
		result := create_navigation_params_by_fetching(entry, target, SourceSnapshotParams{
			fetch_client: settings
		}, TargetSnapshotParams{}, .none, none, hook)!
		assert result.network_error? == 'classification captured'
	}
	assert observation.types == ['main_frame', 'sub_frame']
	assert observation.initiator_top_level == [true, true]
}
