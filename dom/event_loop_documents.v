// SPDX-License-Identifier: BSD-2-Clause
// The HTML main-thread event loop is the source of Page's document enumeration.
@[has_globals]
module dom

pub type MainThreadDocumentsProvider = fn () []&Document

__global (
	dom_main_thread_documents_provider MainThreadDocumentsProvider
)

pub fn install_main_thread_documents_provider(provider MainThreadDocumentsProvider) {
	dom_main_thread_documents_provider = provider
}

pub fn documents_in_main_thread_event_loop() []&Document {
	if dom_main_thread_documents_provider == unsafe { nil } { return []&Document{} }
	return dom_main_thread_documents_provider()
}
