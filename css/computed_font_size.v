module css

import dom

// Computed-value resolution for font-size — the first real "specified value -> computed value" step,
// and the canonical one (it drives em resolution for every other property). Given the minimal
// cascade (inline + author + UA + inheritance), this resolves an element's font-size to absolute px:
// absolute lengths convert directly; em/% resolve against the parent's computed font-size; rem
// against the root element's; the absolute-size keywords use the CSS font-size scale.
//
// FIXME: no caching (ancestor font-sizes are recomputed), and viewport units (vw/vh/...) and calc()
// are not resolved (they fall back to the parent's font-size).

const default_font_size_px = 16.0 // the initial value of font-size ('medium')

// The absolute-size keyword scale, relative to medium = 16px (CSS Fonts 'absolute-size').
fn font_size_keyword_px(keyword Keyword, parent_px f64) f64 {
	return match keyword {
		.xx_small { default_font_size_px * 3.0 / 5.0 }
		.x_small { default_font_size_px * 3.0 / 4.0 }
		.small { default_font_size_px * 8.0 / 9.0 }
		.medium { default_font_size_px }
		.large { default_font_size_px * 6.0 / 5.0 }
		.x_large { default_font_size_px * 3.0 / 2.0 }
		.xx_large { default_font_size_px * 2.0 }
		.xxx_large { default_font_size_px * 3.0 }
		.larger { parent_px * 1.2 }
		.smaller { parent_px / 1.2 }
		else { parent_px }
	}
}

// Resolve a specified font-size string to computed px, given the parent's and root's computed px.
fn resolve_font_size_px(specified string, parent_px f64, root_px f64) f64 {
	value := parse_css_value_logic(.font_size, specified) or { return parent_px }
	if value.is_length() {
		length := value.as_length().length()
		if length.is_absolute() {
			return length.absolute_length_to_px().to_double()
		}
		raw := length.raw_value()
		return match length.unit_name() {
			'em' { raw * parent_px }
			'rem' { raw * root_px }
			'ex' { raw * parent_px * 0.5 } // approximation: 1ex ~= 0.5em
			'ch' { raw * parent_px * 0.5 } // approximation: 1ch ~= 0.5em
			else { parent_px } // FIXME: viewport units need the viewport size
		}
	}
	if value.is_percentage() {
		return parent_px * value.as_percentage().percentage().value() / 100.0
	}
	if value.type_() == .keyword {
		return font_size_keyword_px(value.to_keyword(), parent_px)
	}
	return parent_px // e.g. calc()/unresolved -> inherit (FIXME)
}

// The element's own specified font-size (inline + author + UA, NOT inherited), if any.
fn own_font_size(element &dom.Element, author_rules []&CSSRule) ?string {
	return specified_value_on(element, 'font-size', author_rules, user_agent_rules())
}

// The document root element's computed font-size (px), used to resolve rem. The root's reference is
// the initial 16px (it has no parent element).
pub fn root_font_size_px(element &dom.Element, author_rules []&CSSRule) f64 {
	mut root := element
	for {
		parent := root.as_node().parent_element() or { break }
		root = parent
	}
	own := own_font_size(root, author_rules) or { return default_font_size_px }
	return resolve_font_size_px(own, default_font_size_px, default_font_size_px)
}

// https://drafts.csswg.org/css-fonts/#font-size-prop
// The computed font-size (px) of `element`: resolve its own specified font-size against its parent's
// computed font-size; if the element has no own font-size, it inherits the parent's computed value.
pub fn computed_font_size_px(element &dom.Element, author_rules []&CSSRule) f64 {
	parent_px := if parent := element.as_node().parent_element() {
		computed_font_size_px(parent, author_rules)
	} else {
		default_font_size_px
	}
	own := own_font_size(element, author_rules) or {
		// No own declaration: font-size inherits, so the computed value is the parent's.
		return parent_px
	}
	root_px := if own.contains('rem') {
		root_font_size_px(element, author_rules)
	} else {
		parent_px
	}
	return resolve_font_size_px(own, parent_px, root_px)
}
