// Element.cpp's typed scrollIntoView options/boolean and optional Promise path.
module dom

import webidl

pub fn (mut element Element) scroll_into_view_with_argument(argument ScrollIntoViewArgument) &Promise {
	if argument is bool {
		mut options := ScrollIntoViewOptions{}
		if !argument { options.block = .end_ }
		return element.scroll_into_view_with_options(options)
	}
	return element.scroll_into_view_with_options(argument as ScrollIntoViewOptions)
}

pub fn (mut element Element) scroll_into_view_with_argument_and_promise(argument ScrollIntoViewArgument,
	promise ?&webidl.Promise) {
	if argument is bool {
		mut options := ScrollIntoViewOptions{}
		if !argument { options.block = .end_ }
		element.scroll_into_view_with_options_and_promise(options, promise)
		return
	}
	element.scroll_into_view_with_options_and_promise(argument as ScrollIntoViewOptions, promise)
}

pub fn (mut element Element) scroll_into_view_with_options(options ScrollIntoViewOptions) &Promise {
	document := element.document()
	if document.relevant_settings_object() == unsafe { nil } {
		mut owner := unsafe { &Document(document) }
		owner.update_layout(.element_scroll_into_view)
		if element.as_node().layout_node() == none { return Promise.resolved(js_undefined()) }
		mut container := ?&Element(none)
		if options.container == .nearest { container = &element }
		return scroll_an_element_into_view_standalone(&element, options.behavior, options.block,
			options.inline_, container)
	}
	native := webidl.create_promise_for(document.relevant_realm_promise_context())
	element.scroll_into_view_with_options_and_promise(options, native)
	return Promise.from_webidl(native)
}

// This is the source method's nullable Promise argument, separate from a
// compact JavaScript binding. The supplied capability keeps its own realm.
pub fn (mut element Element) scroll_into_view_with_options_and_promise(options ScrollIntoViewOptions,
	promise ?&webidl.Promise) {
	mut document := unsafe { &Document(element.document()) }
	mut container := ?&Element(none)
	if options.container == .nearest { container = &element }
	document.update_layout(.element_scroll_into_view)
	context := document.begin_temporary_execution_context()
	defer { document.end_temporary_execution_context(context) }
	if element.as_node().layout_node() == none {
		if pointer := promise {
			mut caller := unsafe { &webidl.Promise(pointer) }
			caller.resolve(webidl.undefined_value())
		}
		return
	}
	scroll_an_element_into_view_with_promise(&element, options.behavior, options.block,
		options.inline_, container, promise)
	// FIXME: The pinned source has not implemented the optional attention step.
}
