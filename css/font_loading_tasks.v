// FontFace.cpp / FontFaceSet.cpp: the owning HTML font-loading task source.
@[has_globals]
module css

import dom

pub type FontLoadingTaskProvider = fn (&dom.Document, bool, fn ()) bool

__global font_loading_task_provider_ ?FontLoadingTaskProvider

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
