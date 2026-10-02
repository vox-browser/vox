// Owning-Realm ABI shared by source DOM algorithms that create Promises.
module dom

import webidl

// Window already installs this actual realm/job record for ViewTransition.
// Reuse that same owner rather than allocating another realm or promise state.
pub fn (document &Document) relevant_realm_promise_context() webidl.PromiseContext {
	return document.view_transition_promise_context_
}

pub fn (mut document Document) set_relevant_realm_promise_context(context webidl.PromiseContext) {
	document.view_transition_promise_context_ = context
	if document.view_transition_document_ != unsafe { nil } {
		mut transition_document := document.view_transition_document_
		transition_document.promise_context = context
	}
}
