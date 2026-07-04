module css

// A minimal media-query evaluator for the cascade: it resolves width-based `@media` conditions
// against a known viewport width so the matching rules can be flattened into the rule list the
// cascade consumes. This sidesteps the full CSSOM media-evaluation path (which needs a live document
// / window) for the layout pipeline, where the viewport width is a known input.
//
// FIXME: only the `width` media features (min-width/max-width/width) and the `screen`/`all` media
// types are modeled; `not`/`only` logic beyond the leading `only` keyword, `or` conditions, ranges
// (`width >= 600px`), height/orientation/resolution/prefers-* features, and non-px units are not.

// Whether `condition` (a media rule's condition text, e.g. `(min-width: 600px)` or
// `screen and (max-width: 400px)`) matches a viewport `viewport_width` px wide. An empty condition or
// a bare `all`/`screen` matches; unknown features or media types do not.
pub fn media_condition_matches(condition string, viewport_width f64) bool {
	cond := condition.to_lower().trim_space()
	if cond == '' || cond == 'all' || cond == 'screen' {
		return true
	}
	// All `and`-joined parts must match. (Media features never contain ` and `, so a plain split is
	// safe.)
	for raw_part in cond.split(' and ') {
		part := raw_part.trim_space().trim_string_left('only ').trim_space()
		if part == '' {
			continue
		}
		if part == 'screen' || part == 'all' {
			continue // a matching media type
		}
		if part.starts_with('(') && part.ends_with(')') {
			if !media_feature_matches(part[1..part.len - 1], viewport_width) {
				return false
			}
			continue
		}
		return false // a non-matching media type (print/speech/...) or an unparseable part
	}
	return true
}

// Whether a single media feature (the text inside the parentheses, e.g. `min-width: 600px`) matches.
fn media_feature_matches(feature string, viewport_width f64) bool {
	parts := feature.split(':')
	if parts.len != 2 {
		return false // boolean features like `(hover)` aren't modeled
	}
	value := parse_media_length(parts[1].trim_space())
	return match parts[0].trim_space() {
		'min-width' { viewport_width >= value }
		'max-width' { viewport_width <= value }
		'width' { viewport_width == value }
		else { false } // FIXME: only width features are modeled
	}
}

// Parse a media-feature length like `600px` (or a bare number) to px.
fn parse_media_length(s string) f64 {
	if s.ends_with('px') {
		return s#[..-2].f64()
	}
	return s.f64()
}

// Flatten `@media` rules in `rules` against `viewport_width`: a media rule whose condition matches is
// replaced by its (recursively flattened) child rules; a non-matching media rule is dropped; other
// rules pass through unchanged. The result is a flat rule list the minimal cascade can consume.
pub fn flatten_media_rules(rules []&CSSRule, viewport_width f64) []&CSSRule {
	mut result := []&CSSRule{}
	for rule in rules {
		if rule.type_ == .media {
			if media_condition_matches(rule.condition_text(), viewport_width) {
				if child_list := rule.css_rules() {
					result << flatten_media_rules(child_list.rules, viewport_width)
				}
			}
			continue
		}
		result << rule
	}
	return result
}
