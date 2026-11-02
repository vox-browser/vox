module css

// LibWeb aliases Mozilla control pseudos to its standard internal pseudos.
// Blink does not recognize those aliases. Validate them before publishing a
// rule, so an invalid member rejects its complete standard selector list.
fn chromium_selector_has_mozilla_alias(selector Selector) bool {
	for compound in selector.compound_selectors() {
		for simple in compound.simple_selectors {
			if simple.type_ == .pseudo_element {
				pseudo := simple.pseudo_element()
				if pseudo.name.starts_with('-moz-') { return true }
				if child := pseudo.compound_selector {
					if chromium_selector_has_mozilla_alias(child) { return true }
				}
			} else if simple.type_ == .pseudo_class {
				for child in simple.pseudo_class().argument_selector_list.selectors {
					if chromium_selector_has_mozilla_alias(child) { return true }
				}
			}
		}
	}
	return false
}

fn chromium_selector_without_mozilla_aliases(selector Selector) ?Selector {
	// Keep the original graph and all its cached metadata on the ordinary path.
	if !chromium_selector_has_mozilla_alias(selector) { return selector }
	mut compounds := []CompoundSelector{}
	for compound in selector.compound_selectors() {
		mut simples := []SimpleSelector{}
		for simple in compound.simple_selectors {
			mut replacement := simple
			if simple.type_ == .pseudo_element {
				mut pseudo := simple.pseudo_element()
				if pseudo.name.starts_with('-moz-') { return none }
				if child := pseudo.compound_selector {
					pseudo.compound_selector = chromium_selector_without_mozilla_aliases(child) or { return none }
					replacement = SimpleSelector.with_pseudo_element(simple.type_, pseudo)
				}
			} else if simple.type_ == .pseudo_class {
				mut pseudo := simple.pseudo_class()
				mut arguments := []Selector{}
				for child in pseudo.argument_selector_list.selectors {
					if supported := chromium_selector_without_mozilla_aliases(child) {
						arguments << supported
					} else if !pseudo.is_forgiving {
						return none
					}
				}
				pseudo.argument_selector_list = SelectorList{selectors: arguments}
				replacement = SimpleSelector.with_pseudo_class(simple.type_, pseudo)
			}
			simples << replacement
		}
		compounds << CompoundSelector{combinator: compound.combinator, simple_selectors: simples}
	}
	// Rebuild derived specificity, pseudo-element and invalidation metadata after
	// discarding invalid branches of a forgiving :is() or :where() argument.
	return selector_from_compound_selectors(compounds)
}

fn (parser RuleSelectorParser) uses_chromium_selector_policy() bool {
	return parser.document != unsafe { nil } && parser.document.font_rendering_policy() == .chromium
}

fn (parser RuleSelectorParser) parse_supported_rule_selector(text string, mode ParserSelectorType) ?Selector {
	selector := parser_parse_validated_selector(text, mode, parser.declared_namespaces) or { return none }
	if parser.uses_chromium_selector_policy() {
		return chromium_selector_without_mozilla_aliases(selector)
	}
	return selector
}
