module html

import dom

fn document_script_element_post_connection(_ voidptr, element &dom.Element) {
	pointer := element.document().relevant_settings_object()
	if pointer == unsafe { nil } { return }
	settings := unsafe { &EnvironmentSettingsObject(pointer) }
	if settings.realm().evaluate_script_element_ == none { return }
	if element.is_html_element() {
		// The browser owns external fetching; an empty src still takes that path.
		if element.has_attribute_ns(none, 'src') { return }
		html_script_element_post_connection(unsafe { &dom.HTMLScriptElement(element) })
	} else if element.is_svg_element() && !element.has_attribute('href') {
		mut model := svg_script_element_model_for_dom_element(unsafe { &dom.SVGScriptElement(element) })
		if !model.is_parser_inserted() { model.process_the_script_element() }
	}
}

fn execute_bound_script_element(document &dom.Document, kind ScriptElementType, source string, line int, element ?&dom.Element) !bool {
	pointer := document.relevant_settings_object()
	if pointer == unsafe { nil } { return false }
	settings := unsafe { &EnvironmentSettingsObject(pointer) }
	evaluator := settings.realm().evaluate_script_element_ or { return false }
	mut owner := unsafe { &dom.Document(document) }
	previous := owner.current_script()
	defer { owner.set_current_script(previous) }
	owner.set_current_script(none)
	if kind == .classic {
		if script := element {
			if (script.is_html_element() || script.is_svg_element()) && !script.as_node().root().is_shadow_root() { owner.set_current_script(script) }
		}
	}
	evaluator(kind,source,document.url.serialize(),line,element)!
	return true
}
