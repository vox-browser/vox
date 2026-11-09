module css

// Stretch is an extrinsic sizing keyword, with no length/percentage payload.
// Layout resolves it against available space before applying box sizing.
pub fn Size.make_stretch() Size { return Size.new(.stretch, none) }

pub fn (size Size) is_stretch() bool { return size.type_ == .stretch }

fn parse_stretch_sizing_keyword(mut tokens ComponentValueStream) ?StyleValue {
	mut attempt := tokens.clone()
	attempt.consume_whitespace()
	value := attempt.consume() or { return none }
	if !value.is(.ident) { return none }
	name := to_ascii_lowercase(value.token().ident())
	if name !in ['stretch', '-webkit-fill-available'] { return none }
	tokens = attempt
	return StyleValue(KeywordStyleValue.create(.stretch))
}
