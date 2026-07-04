module html

import dom

// https://html.spec.whatwg.org/multipage/parsing.html#html-fragment-parsing-algorithm
// The engine behind Element.innerHTML / Element.setHTMLUnsafe / the fragment parsing steps.
// Parses `markup` as if it were the contents of `context_element`, returning the parsed nodes (in
// tree order) which the caller inserts into the real tree.
pub fn parse_html_fragment(context_element &dom.Element, markup string) []&dom.Node {
	// 1. Let document be a Document node whose type is "html".
	mut temp_document := dom.Document.create_for_fragment_parsing()
	temp_document.set_document_type(.html)

	// 2/3. Inherit quirks mode from the context's node document.
	context_document := context_element.document()
	if context_document.in_quirks_mode() {
		temp_document.set_quirks_mode(.yes)
	} else if context_document.in_limited_quirks_mode() {
		temp_document.set_quirks_mode(.limited)
	}

	// 5. Create the parser and associate it with the temporary document.
	mut parser := HTMLParser.create(temp_document, markup)
	parser.context_element = context_element
	parser.parsing_fragment = true

	// 6. Set the tokenizer state based on the context element.
	context_name := context_element.local_name()
	if context_name in ['title', 'textarea'] {
		parser.tokenizer.switch_to(.rcdata)
	} else if context_name in ['style', 'xmp', 'iframe', 'noembed', 'noframes'] {
		parser.tokenizer.switch_to(.rawtext)
	} else if context_name == 'script' {
		parser.tokenizer.switch_to(.script_data)
	} else if context_name == 'noscript' {
		// Scripting is disabled in this port, so leave the tokenizer in the data state.
	} else if context_name == 'plaintext' {
		parser.tokenizer.switch_to(.plaintext)
	}

	// 7/8. Create the root <html> element and append it to the temporary document.
	root := dom.create_element(temp_document, 'html', ns_html, none, none, false) or {
		panic('fragment root: ${err}')
	}
	mut temp_document_node := unsafe { &dom.Node(temp_document) }
	temp_document_node.append_child(root.as_node()) or {}

	// 9. The stack of open elements contains just root.
	parser.stack_of_open_elements.push(root)

	// 10. If the context is a template element, push "in template".
	if context_name == 'template' && element_in_namespace(context_element, ns_html) {
		parser.stack_of_template_insertion_modes << InsertionMode.in_template
	}

	// 12. Reset the insertion mode appropriately (this reads the context element in the fragment case).
	parser.reset_the_insertion_mode_appropriately()

	// 13. Set the form element pointer to the nearest form ancestor (inclusive).
	mut ancestor := ?&dom.Element(context_element)
	for {
		candidate := ancestor or { break }
		if element_in_namespace(candidate, ns_html) && candidate.local_name() == 'form' {
			parser.form_element = candidate
			break
		}
		ancestor = candidate.as_node().parent_element()
	}

	// 14/15. Run the parser to completion.
	parser.run()

	// 16. Return root's children (in tree order), adopting each into the context's document.
	mut children := []&dom.Node{}
	mut root_node := root.as_node()
	for {
		child := root_node.first_child() or { break }
		removed := root_node.remove_child(child) or { break }
		mut destination_document := context_element.document()
		destination_document.adopt_node(removed)
		children << removed
	}
	return children
}
