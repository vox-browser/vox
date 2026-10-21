module css

import dom
import platform

// Resource discovery is conservative: quoted strings include image-set() URLs
// as well as strings that may not ultimately be used as an image.
pub struct ResourceURLCandidate {
pub:
	url      string
	base_url string
}

// Inspect retained values without CSSOM serialization or materializing deferred
// declarations. Callers can discover resources in unmatched rules while leaving
// their property conversion deferred until matching actually needs it.
pub fn (properties &CSSStyleProperties) resource_url_candidates(fallback_base string) []ResourceURLCandidate {
	mut candidates := []ResourceURLCandidate{}
	if deferred := properties.deferred_declarations_ {
		base_url := if deferred.base_url != '' { deferred.base_url } else { fallback_base }
		for declaration in deferred.declarations {
			append_component_resource_urls(declaration.value, base_url, mut candidates)
		}
		return candidates
	}
	for property in properties.properties {
		if value := property.style_value {
			append_dom_value_resource_urls(value, fallback_base, mut candidates)
		} else {
			append_text_resource_urls(property.value, fallback_base, mut candidates)
		}
	}
	for _, property in properties.custom_properties {
		append_dom_value_resource_urls(property.value, fallback_base, mut candidates)
	}
	return candidates
}

fn append_component_resource_urls(values []ComponentValue, base_url string,
	mut candidates []ResourceURLCandidate) {
	for component in values {
		match component.value {
			Token {
				if component.value.is(.url) || component.value.is(.string) {
					candidates << ResourceURLCandidate{url: component.value.value, base_url: base_url}
				}
			}
			Function {
				append_component_resource_urls(component.value.value, base_url, mut candidates)
			}
			SimpleBlock {
				append_component_resource_urls(component.value.value, base_url, mut candidates)
			}
			RawComponentValue {
				append_text_resource_urls(component.value.text, base_url, mut candidates)
			}
			GuaranteedInvalidValue {}
		}
	}
}

fn append_dom_value_resource_urls(value &dom.StyleValue, fallback_base string,
	mut candidates []ResourceURLCandidate) {
	if !text_may_contain_resource_url(value.css_text) { return }
	base_url := value.base_url or { fallback_base }
	if typed := typed_style_value_logic_from_dom(value) {
		// path() stores geometry in a quoted string. It cannot reference a
		// resource, and reparsing a long SVG path would manufacture a URL
		// candidate containing every coordinate in the path.
		if typed is BasicShapeStyleValue { return }
		if typed is UnresolvedStyleValue {
			append_component_resource_urls(typed.tokens, base_url, mut candidates)
			return
		}
		if typed is PendingSubstitutionStyleValue {
			original := typed.original_shorthand_value
			if original is UnresolvedStyleValue {
				append_component_resource_urls(original.tokens, base_url, mut candidates)
				return
			}
		}
	}
	append_text_resource_urls(value.css_text, base_url, mut candidates)
}

fn text_may_contain_resource_url(source string) bool {
	// URL functions contain a parenthesis, escaped tokens contain a backslash,
	// and image-set string URLs contain a quote. Ordinary lengths/keywords need
	// no new token graph merely to establish that they contain no URL.
	return source.contains('(') || source.contains('\\') || source.contains('"')
		|| source.contains("'")
}

fn append_text_resource_urls(source string, base_url string, mut candidates []ResourceURLCandidate) {
	if !text_may_contain_resource_url(source) { return }
	// Resource discovery keeps only URL strings. The tokenizer's vectors and
	// decoded token values have no readers after this scan.
	scratch := platform.begin_thread_scratch('resource URL tokens')
	tokens := tokenize_css(source, 'utf-8')
	scratch.leave()
	defer { scratch.finish() }
	for token in tokens {
		if token.is(.url) || token.is(.string) {
			candidates << ResourceURLCandidate{url: token.value.clone(), base_url: base_url}
		}
	}
}
