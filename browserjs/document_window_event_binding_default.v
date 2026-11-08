module browserjs

import dom as _

$if !darwin && !linux && !windows {
	pub fn (mut runtime Runtime) install_document_event_target_resolver(_ DocumentEventTargetResolver) ! {
		return error('Document event target bindings require JavaScriptCore')
	}

	pub fn (mut runtime Runtime) install_document_window_event_binding(_ &dom.Document, _ voidptr) ! {
		return error('Document/Window JavaScriptCore event bindings are available on macOS only')
	}

	pub fn (runtime &Runtime) dispatch_document_readiness_event(_ string) ! {
		return error('Document/Window JavaScriptCore event bindings are available on macOS only')
	}
}
