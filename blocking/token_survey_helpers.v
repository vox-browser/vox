module main

import css
import dom

$if test {
	// Shared by focused token-survey and cache tests. Production does not
	// compile this independent selector-based oracle.
	fn selector_adblock_token_survey(document &dom.Document) []string {
		mut tokens := map[string]bool{}
		for element in css.query_selector_all(document.as_node(), '[id], [class]') {
			id := element.get_attribute_value('id')
			if id != '' { tokens['#${id}'] = true }
			for name in element.get_attribute_value('class').fields() {
				tokens['.${name}'] = true
			}
		}
		mut result := tokens.keys()
		result.sort()
		return result
	}
}
