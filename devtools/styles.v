module devtools

import strings

pub enum SidebarTab {
	styles
	computed
	attributes
}

pub enum StyleOrigin {
	inline
	author
	user
	user_agent
}

pub struct StyleDeclaration {
pub:
	name      string
	value     string
	important bool
pub mut:
	overridden bool
}

// value_text is the editable form of a value, keeping its priority.
pub fn (declaration StyleDeclaration) value_text() string {
	return if declaration.important { declaration.value + ' !important' } else { declaration.value }
}

pub struct StyleRule {
pub:
	selector string
	source   string
	origin   StyleOrigin
	// The engine rule that edits apply to; nil for the inline style.
	handle voidptr
pub mut:
	declarations []StyleDeclaration
}

pub fn (rule StyleRule) editable() bool {
	return rule.origin in [.inline, .author]
}

// BoxModel lists top, right, bottom and left edges in CSS pixels.
pub struct BoxModel {
pub:
	margin  []f64
	border  []f64
	padding []f64
	width   f64
	height  f64
}

pub struct ComputedProperty {
pub:
	name  string
	value string
}

// StyleSnapshot is what the Styles and Computed tabs show for one element.
// `rules` starts with the inline style, then lists rules from the highest
// cascade precedence down, as Chrome does.
pub struct StyleSnapshot {
pub mut:
	node     i64
	key      u64
	rules    []StyleRule
	computed []ComputedProperty
	box      ?BoxModel
}

// split_top_level splits at `separator` outside quotes, parentheses and brackets.
fn split_top_level(text string, separator u8) []string {
	mut parts := []string{}
	mut depth := 0
	mut quote := u8(0)
	mut start := 0
	for index := 0; index < text.len; index++ {
		c := text[index]
		if quote != 0 {
			if c == `\\` {
				index++
			} else if c == quote {
				quote = 0
			}
			continue
		}
		match c {
			`"`, `'` { quote = c }
			`(`, `[`, `{` { depth++ }
			`)`, `]`, `}` { depth = if depth > 0 { depth - 1 } else { 0 } }
			else {
				if c == separator && depth == 0 {
					parts << text[start..index]
					start = index + 1
				}
			}
		}
	}
	parts << text[start..]
	return parts
}

// parse_value separates a trailing `!important` from a value.
pub fn parse_value(text string) (string, bool) {
	value := text.trim_space()
	lower := value.to_lower()
	if lower.ends_with('!important') {
		stripped := value[..value.len - '!important'.len].trim_space()
		return stripped, true
	}
	return value, false
}

// parse_declarations reads a declaration block such as a style attribute or
// the CSSOM serialization of a rule: `color: red; margin: 0 !important`.
pub fn parse_declarations(text string) []StyleDeclaration {
	mut declarations := []StyleDeclaration{}
	for part in split_top_level(text, `;`) {
		colon := split_top_level(part, `:`)
		if colon.len < 2 {
			continue
		}
		name := colon[0].trim_space()
		if name == '' {
			continue
		}
		value, important := parse_value(part[colon[0].len + 1..])
		declarations << StyleDeclaration{
			name:      if name.starts_with('--') { name } else { name.to_lower() }
			value:     value
			important: important
		}
	}
	return declarations
}

pub fn serialize_declarations(declarations []StyleDeclaration) string {
	mut builder := strings.new_builder(64)
	for index, declaration in declarations {
		if index > 0 {
			builder.write_string(' ')
		}
		builder.write_string('${declaration.name}: ${declaration.value_text()};')
	}
	return builder.str()
}

// with_declaration sets `name` to `value` (which may end in !important),
// appending it when absent. An empty value removes the declaration.
pub fn with_declaration(declarations []StyleDeclaration, name string, value string) []StyleDeclaration {
	property := if name.trim_space().starts_with('--') {
		name.trim_space()
	} else {
		name.trim_space().to_lower()
	}
	parsed, important := parse_value(value)
	mut result := []StyleDeclaration{cap: declarations.len + 1}
	mut found := false
	for declaration in declarations {
		if declaration.name != property {
			result << declaration
			continue
		}
		if !found && parsed != '' {
			result << StyleDeclaration{
				name:      property
				value:     parsed
				important: important
			}
		}
		found = true
	}
	if !found && parsed != '' {
		result << StyleDeclaration{
			name:      property
			value:     parsed
			important: important
		}
	}
	return result
}

// covers reports whether a winning declaration for `winner` decides `name`:
// the same property, or a longhand of the shorthand (`margin` covers
// `margin-top`).
fn covers(winner string, name string) bool {
	return winner == name || (!name.starts_with('--') && name.starts_with(winner + '-'))
}

// mark_overridden strikes declarations that lose the cascade to an earlier
// rule. Important declarations win over normal ones regardless of order.
pub fn mark_overridden(mut rules []StyleRule) {
	mut winners := []string{}
	for important in [true, false] {
		for mut rule in rules {
			for mut declaration in rule.declarations {
				if declaration.important != important {
					continue
				}
				declaration.overridden = winners.any(covers(it, declaration.name))
				if !declaration.overridden {
					winners << declaration.name
				}
			}
		}
	}
}

// css_pixels reads a resolved length such as `12px`; other values are zero.
pub fn css_pixels(value string) f64 {
	trimmed := value.trim_space()
	if !trimmed.ends_with('px') {
		return 0
	}
	return trimmed[..trimmed.len - 2].f64()
}

// box_edge formats a box-model edge as Chrome does: `-` for zero.
pub fn box_edge(value f64) string {
	if value == 0 {
		return '-'
	}
	rounded := f64(i64(value * 100 + if value > 0 { 0.5 } else { -0.5 })) / 100
	return if rounded == f64(i64(rounded)) { i64(rounded).str() } else { rounded.str() }
}

pub fn (snapshot StyleSnapshot) filtered_computed(filter string) []ComputedProperty {
	needle := filter.trim_space().to_lower()
	if needle == '' {
		return snapshot.computed
	}
	return snapshot.computed.filter(it.name.contains(needle) || it.value.to_lower().contains(needle))
}
