// Copyright (c) 2020, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/AbstractWorker.cpp.
// AbstractWorker is a C++ mixin whose only state is delegated to the concrete worker's event
// target (this_event_target()); the two IDL attributes become free functions over that target.
// https://html.spec.whatwg.org/multipage/workers.html#abstractworker
module html

import dom

// https://html.spec.whatwg.org/multipage/workers.html#handler-abstractworker-onerror
pub fn abstract_worker_onerror(event_target &dom.EventTarget) ?&dom.CallbackType {
	return event_target.event_handler_attribute(event_error)
}

// https://html.spec.whatwg.org/multipage/workers.html#handler-abstractworker-onerror
pub fn set_abstract_worker_onerror(event_target &dom.EventTarget, event_handler ?&dom.CallbackType) {
	event_target.set_event_handler_attribute(event_error, event_handler)
}
