module css

import dom

// Compatibility adapter for callers which only provide a viewport width. Parsing and
// evaluation are performed by the translated MediaQuery algorithms in media_queries.v;
// this file does not maintain a second media-query grammar or evaluator.
pub fn media_condition_matches(condition string, viewport_width f64) bool {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_viewport_rect(dom.Rect{
		width: viewport_width
		height: 600
	})
	return media_condition_matches_document(condition, document)
}

fn media_condition_matches_document(condition string, document &dom.Document) bool {
	query := parse_media_query_from_text(condition) or { return false }
	return query.evaluate(document)
}

// Flatten @media rules for the compatibility rule-list API. The production
// StyleComputer keeps the nested rules and calls CSSMediaRule::evaluate_media().
pub fn flatten_media_rules(rules []&CSSRule, viewport_width f64) []&CSSRule {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_viewport_rect(dom.Rect{
		width: viewport_width
		height: 600
	})
	return flatten_media_rules_for_document(rules, document)
}

fn flatten_media_rules_for_document(rules []&CSSRule, document &dom.Document) []&CSSRule {
	mut result := []&CSSRule{}
	for rule in rules {
		if rule.type_ == .media {
			if media_condition_matches_document(rule.condition_text(), document) {
				if child_list := rule.css_rules() {
					result << flatten_media_rules_for_document(child_list.rules, document)
				}
			}
			continue
		}
		result << rule
	}
	return result
}
