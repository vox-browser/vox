module css

// The user-agent (default) stylesheet, embedded verbatim from Ladybird's CSS/Default.css. It is
// parsed once at program start into the rules that make up the lowest-priority (UA) cascade origin,
// so unstyled elements get their default styles (div { display: block }, head { display: none }, ...).
const user_agent_stylesheet_source = $embed_file('ua_default.css').to_string()
const user_agent_quirks_mode_stylesheet_source = $embed_file('ua_quirks_mode.css').to_string()
const user_agent_mathml_stylesheet_source = $embed_file('ua_mathml_default.css').to_string()
const user_agent_svg_stylesheet_source = $embed_file('ua_svg_default.css').to_string()

const user_agent_stylesheet_rules = parse_css_stylesheet_contents_with_parser(user_agent_stylesheet_source,
	map[string]bool{})

// The parsed user-agent stylesheet rules (cached).
pub fn user_agent_rules() []&CSSRule {
	return user_agent_stylesheet_rules
}

// The parsed user-agent CSSStyleSheet, built once at startup and shared by every StyleScope's UA rule
// cache (the sheet is identical for all documents), so documents don't each re-parse Default.css.
const user_agent_default_stylesheet = parse_css_stylesheet_with_parser(user_agent_stylesheet_source,
	none)
const user_agent_quirks_mode_stylesheet = parse_css_stylesheet_with_parser(user_agent_quirks_mode_stylesheet_source,
	none)
const user_agent_mathml_stylesheet = parse_css_stylesheet_with_parser(user_agent_mathml_stylesheet_source,
	none)
const user_agent_svg_stylesheet = parse_css_stylesheet_with_parser(user_agent_svg_stylesheet_source,
	none)

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
