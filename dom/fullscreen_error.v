// Copyright (c) 2026-present, the Ladybird developers.
//
// SPDX-License-Identifier: BSD-2-Clause
//
// Translation of Libraries/LibWeb/DOM/RequestFullscreenError.h.
module dom

pub fn request_fullscreen_error_to_string(error_ RequestFullscreenError) string {
	return match error_ {
		.false_ { '' }
		.element_ready_check_failed { 'Element ready check failed' }
		.unsupported_element { 'Not supported element' }
		.no_transient_user_activation { 'No transient user activation available to consume' }
		.element_node_doc_is_not_pending_doc { "Element's node document is not pending doc" }
	}
}
