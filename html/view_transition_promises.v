// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// ViewTransition.cpp creates promises in the document's relevant Realm. DOM
// cannot import HTML, so Window installs that promise job boundary here.
module html

import dom
import webidl

fn install_view_transition_promise_context(document &dom.Document, window &WindowModel) {
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_view_transition_promise_context(webidl.PromiseContext{
		realm_id:      u64(voidptr(window.scripting_realm_))
		job_scheduler: fn [document] (job fn ()) {
			queue_a_microtask(document, job)
		}
	})
}
