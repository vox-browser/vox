// FontFace.cpp / FontFaceSet.cpp: the owning HTML font-loading task source.
@[has_globals]
module css

import dom
import platform
import webidl

pub type FontLoadingTaskProvider = fn (&dom.Document, bool, fn ()) bool

__global font_loading_task_provider_ ?FontLoadingTaskProvider = ?FontLoadingTaskProvider(none)

pub type FontLoadingPromiseContextProvider = fn (&dom.Document) webidl.PromiseContext

__global font_loading_promise_context_provider_ ?FontLoadingPromiseContextProvider = ?FontLoadingPromiseContextProvider(none)

pub type FontLoadingEventTimeStampProvider = fn (&dom.Document) f64

__global font_loading_event_time_stamp_provider_ ?FontLoadingEventTimeStampProvider = ?FontLoadingEventTimeStampProvider(none)

pub fn install_font_loading_event_time_stamp_provider(provider FontLoadingEventTimeStampProvider) {
	font_loading_event_time_stamp_provider_ = provider
}

fn font_loading_event_time_stamp(computer ?&FontComputer) f64 {
	if owner := computer {
		if document := owner.document_ {
			if provider := font_loading_event_time_stamp_provider_ { return provider(document) }
		}
	}
	return dom.current_event_timestamp()
}

pub fn install_font_loading_promise_context_provider(provider FontLoadingPromiseContextProvider) {
	font_loading_promise_context_provider_ = provider
}

fn font_loading_promise_context(computer ?&FontComputer) webidl.PromiseContext {
	if owner := computer {
		if document := owner.document_ {
			if provider := font_loading_promise_context_provider_ {
				return provider(document)
			}
		}
	}
	return webidl.PromiseContext{}
}

fn defer_font_loading_steps(computer ?&FontComputer, steps fn ()) {
	if owner := computer {
		if owner.document_ != none && platform.EventLoopPlugin.is_installed() {
			mut plugin := platform.EventLoopPlugin.the()
			plugin.deferred_invoke(steps)
			return
		}
	}
	// Standalone CSS callers have no installed platform event loop or global.
	steps()
}

pub fn install_font_loading_task_provider(provider FontLoadingTaskProvider) {
	font_loading_task_provider_ = provider
}

fn queue_font_loading_task(computer ?&FontComputer, associate_document bool, steps fn ()) {
	if owner := computer {
		if document := owner.document_ {
			if provider := font_loading_task_provider_ {
				if provider(document, associate_document, steps) { return }
			}
		}
	}
	// Standalone CSS callers have no relevant global. Retain their existing
	// direct adapter; HTML document callers use their real owning task queue.
	steps()
}
