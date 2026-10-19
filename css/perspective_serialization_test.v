module css

// https://drafts.css-houdini.org/css-typed-om-1/#serialize-a-cssperspective
fn test_perspective_serializes_its_numeric_or_keyword_length() {
	unit := CSSPerspective.create(CSSPerspectiveValueInternal(CSSUnitValue.create(10, 'px')))
	assert unit.to_string()! == 'perspective(10px)'

	sum := CSSMathSum.construct_impl([
		CSSNumberish(CSSUnitValue.create(1, 'px')),
		CSSNumberish(CSSUnitValue.create(2, 'em')),
	]) or { panic('${err}') }
	math := CSSPerspective.create(CSSPerspectiveValueInternal(sum))
	assert math.to_string()! == 'perspective(calc(1px + 2em))'

	keyword := CSSPerspective.create(CSSPerspectiveValueInternal(CSSKeywordValue.create('none')))
	assert keyword.to_string()! == 'perspective(none)'
}
