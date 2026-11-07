module main

import css
import dom
import platform
import x.json2

struct CompactInitialStateText {
	text string
	workspace platform.ThreadScratchScope
}

// JavaScriptCore copies this JSON before author scripts execute. Native models
// and the selector cache remain document-owned; only the initial transport
// graph, bridge-key lookup, metadata vectors and encoder buffers are disposable.
fn compact_initial_state_text(document &dom.Document, current_url string, scripts []string,
	policy CompactInitialElementPolicy) CompactInitialStateText {
	$if prealloc {
		mut storage := document.native_storage()
		if storage != unsafe { nil } {
			mut owner := storage.enter_nested()
			defer { owner.finish() }
			// The selector parser can publish a document cache on a cold call.
			// Models can attach shadow trees and register viewport clients too.
			elements := css.query_selector_all(document.as_node(), '*')
			for element in elements {
				if policy == .roots_and_ids && !compact_initial_element_state_needed(element) { continue }
				prepare_compact_element_serialization(element)
			}
			work := platform.begin_thread_scratch('compact initial state serialization')
			state := javascript_initial_state_for_elements(document, current_url, scripts, policy, elements)
			encoded := json2.encode(state)
			work.leave()
			return CompactInitialStateText{text: encoded, workspace: work}
		}
	}
	// Standalone adapters without document storage keep their existing native
	// model lifetime. Only their encoded transport enters disposable storage.
	state := javascript_initial_state_with_policy(document, current_url, scripts, policy)
	work := platform.begin_thread_scratch('compact initial state JSON')
	encoded := json2.encode(state)
	work.leave()
	return CompactInitialStateText{text: encoded, workspace: work}
}
