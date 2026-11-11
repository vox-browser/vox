module css

import dom

fn test_highlight_pseudos_are_terminal_except_search_current_state() {
	for pseudo in ['::selection', '::target-text', '::spelling-error', '::grammar-error', '::highlight(foo)',
		'::search-text', '::search-text:current', '::search-text:not(:current)'] {
		for source in [pseudo, '.a${pseudo}', 'div ${pseudo}', '::part(my-part)${pseudo}'] {
			assert parse_query_selector_list(source) != none, source
		}
		for source in ['${pseudo}.a', '${pseudo} div', '${pseudo}::after', '${pseudo}:hover',
			'${pseudo}:current(*)', '${pseudo}:past', '${pseudo}:future', ':not(${pseudo})', '::before${pseudo}'] {
			assert parse_query_selector_list(source) == none, source
		}
	}
	assert int(PseudoElement.target_text) == int(dom.PseudoElement.target_text)
	assert int(PseudoElement.search_text) == int(dom.PseudoElement.search_text)
}
