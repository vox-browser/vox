module css

import platform

// The user-agent (default) stylesheet, embedded verbatim from Ladybird's CSS/Default.css.
const user_agent_stylesheet_source = platform.embedded_text($embed_file('ua_default.css'))
const user_agent_quirks_mode_stylesheet_source = platform.embedded_text($embed_file('ua_quirks_mode.css'))
const user_agent_mathml_stylesheet_source = platform.embedded_text($embed_file('ua_mathml_default.css'))
const user_agent_svg_stylesheet_source = platform.embedded_text($embed_file('ua_svg_default.css'))
const user_agent_counter_styles_marker = '/* https://w3c.github.io/predefined-counter-styles/ */'
const user_agent_cascade_stylesheet_source = user_agent_stylesheet_source.all_before(user_agent_counter_styles_marker)
const user_agent_counter_stylesheet_source = user_agent_stylesheet_source.all_after(user_agent_counter_styles_marker)

// The parsed user-agent CSSStyleSheet, built once at startup and shared by every StyleScope's UA rule
// cache (the sheet is identical for all documents), so documents don't each re-parse Default.css.
const user_agent_default_stylesheet = parse_shared_user_agent_stylesheet(user_agent_cascade_stylesheet_source)
const user_agent_quirks_mode_stylesheet = parse_shared_user_agent_stylesheet(user_agent_quirks_mode_stylesheet_source)
const user_agent_mathml_stylesheet = parse_shared_user_agent_stylesheet(user_agent_mathml_stylesheet_source)
const user_agent_svg_stylesheet = parse_shared_user_agent_stylesheet(user_agent_svg_stylesheet_source)

__global user_agent_counter_stylesheet &CSSStyleSheet

// The predefined counter styles occupy most of Default.css, but do not
// participate in selector matching. Parse them only when a document actually
// needs a non-trivial list marker or generated counter.
fn user_agent_counter_style_sheet() &CSSStyleSheet {
	if user_agent_counter_stylesheet == unsafe { nil } {
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		user_agent_counter_stylesheet = parse_shared_user_agent_stylesheet(user_agent_counter_stylesheet_source)
	}
	return user_agent_counter_stylesheet
}

// Predefined @counter-style rules are split out of the selector-bearing UA
// sheet so normal cascade startup stays cheap. Marker generation still needs
// that second sheet rather than the selector-only user_agent_rules() list.
pub fn user_agent_counter_style_rules() []&CSSRule {
	return user_agent_counter_style_sheet().css_rules().rules
}

// Compatibility callers need the same default-UA rules as StyleScope. Reuse
// the sheet's list instead of parsing the 90 KiB Default.css source a second
// time during every process startup.
pub fn user_agent_rules() []&CSSRule {
	return user_agent_default_stylesheet.css_rules().rules
}

// The shared parsed user-agent stylesheet for `url`, or none if that sheet isn't embedded.
pub fn user_agent_default_style_sheet(url string) ?&CSSStyleSheet {
	if url == 'CSS/Default.css' {
		return user_agent_default_stylesheet
	}
	if url == 'CSS/QuirksMode.css' {
		return user_agent_quirks_mode_stylesheet
	}
	if url == 'MathML/Default.css' {
		return user_agent_mathml_stylesheet
	}
	if url == 'SVG/Default.css' {
		return user_agent_svg_stylesheet
	}
	return none
}

fn parse_shared_user_agent_stylesheet(source string) &CSSStyleSheet {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut sheet := parse_css_stylesheet_with_params(ParsingParams{is_ua_style_sheet: .yes}, source, none)
	sheet.process_lifetime = true
	return sheet
}
