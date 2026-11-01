module css

import dom

fn test_html_attribute_case_buckets_keep_enumerated_names_and_exact_boundaries() {
	previous := html_attribute_case_lookup_mode
	defer { html_attribute_case_lookup_mode = previous }
	for mode in [1, 2] {
		html_attribute_case_lookup_mode = mode
		for name in ['dir', 'type', 'color', 'method', 'charset', 'readonly', 'scrolling',
			'http-equiv', 'accept-charset'] {
			assert selector_html_attribute_is_case_insensitive(name)
			for other in [name.to_upper(), name + 'x', 'x' + name, name[..name.len - 1]] {
				assert !selector_html_attribute_is_case_insensitive(other), other
			}
		}
		for name in ['', 'id', 'class', 'role', 'data-testid', 'aria-label', 'scoPe', 'dír',
			'λ'.repeat(7), 'accept-charset\x00'] {
			assert !selector_html_attribute_is_case_insensitive(name), name
		}
	}
}

fn test_html_attribute_case_buckets_preserve_flags_and_namespace_rules() {
	previous := html_attribute_case_lookup_mode
	defer { html_attribute_case_lookup_mode = previous }
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.html)
	for namespace in [dom.namespace_html_uri, 'http://www.w3.org/2000/svg'] {
		mut element := document.create_element_ns(namespace, 'a')!
		element.set_attribute_value('type', 'TEXT')
		element.set_attribute_value('data-testid', 'Card')
		for mode in [1, 2] {
			html_attribute_case_lookup_mode = mode
			for expression, expected in {
				'[type=text]': namespace == dom.namespace_html_uri
				'[type=text i]': true
				'[type=text s]': false
				'[data-testid=card]': false
				'[data-testid=card i]': true
				'[data-testid=Card s]': true
			} {
				for suffix in ['', ':is(*)'] {
					list := parse_selector_with_parser(expression + suffix, {}) or { panic(expression) }
					mut context := MatchContext{subject: element}
					assert matches(list.selectors[0], element, none, mut context, none, none,
						.normal, none) == expected, expression + suffix
				}
			}
		}
	}
}
