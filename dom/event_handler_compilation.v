// DOM/EventTarget.cpp::get_current_value_of_event_handler(). The actual owner
// supplies its engine compiler across the DOM/HTML/runtime module boundary.
module dom

pub type InlineEventHandlerSupport = fn (&EventTarget, string) bool

pub struct InlineEventHandlerCompiler {
pub:
	supports_handler ?InlineEventHandlerSupport
	@[required]
	can_compile fn (&EventTarget) bool
	// Optional owner availability for this exact raw slot, after environment checks.
	can_compile_handler ?InlineEventHandlerSupport
	@[required]
	compile     fn (&EventTarget, string, string, string) ?&CallbackType
}

pub fn (mut document Document) set_inline_event_handler_compiler(compiler InlineEventHandlerCompiler) {
	document.inline_event_handler_compiler_ = compiler
}

pub fn (mut document Document) set_event_callback_exception_reporter(reporter EventCallbackExceptionReporter) {
	document.event_callback_exception_reporter_ = reporter
}

pub fn (document &Document) report_event_callback_exception(exception IError) {
	if reporter := document.event_callback_exception_reporter_ { reporter(exception) }
}
