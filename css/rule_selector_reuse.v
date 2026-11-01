module css

import os

const disable_rule_selector_reuse = os.getenv('VOX_DISABLE_RULE_SELECTOR_REUSE') != ''
const rule_selector_reuse_diagnostics = os.getenv('VOX_RULE_SELECTOR_REUSE_DIAGNOSTICS') != ''
const maximum_reused_rule_selectors = 4096
const maximum_reused_rule_selector_bytes = 524288

__global rule_selector_reuse_reported bool

// A parser's validated selector graphs have no rule owner. Each rule keeps its
// own selector vector, declarations and CSSOM identity. Namespace-bearing
// contexts stay on the ordinary path, and relative and standalone validation
// never share an entry. The bounded memo belongs to this parser, not a process
// cache, so its graph owner is the same as the completed stylesheet's owner.
fn (mut parser RuleSelectorParser) parse_memoized_rule_selector(text string, mode ParserSelectorType) ?Selector {
	if disable_rule_selector_reuse || parser.declared_namespaces.len > 0 {
		return parser_parse_validated_selector(text, mode, parser.declared_namespaces)
	}
	key := '${int(mode)}\x00${text}'
	if selector := parser.parsed_rule_selectors[key] {
		mut data := unsafe { &SelectorData(selector.data_) }
		data.repeated_rule_parse = true
		if rule_selector_reuse_diagnostics && !rule_selector_reuse_reported {
			rule_selector_reuse_reported = true
			eprintln('Vox rule selectors: reused validated selector graph')
		}
		return selector
	}
	selector := parser_parse_validated_selector(text, mode, parser.declared_namespaces) or { return none }
	if parser.parsed_rule_selectors.len < maximum_reused_rule_selectors
		&& parser.parsed_rule_selector_bytes + key.len <= maximum_reused_rule_selector_bytes {
		parser.parsed_rule_selectors[key] = selector
		parser.parsed_rule_selector_bytes += key.len
	}
	return selector
}
