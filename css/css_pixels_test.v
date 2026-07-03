module css

// Translation of Tests/LibWeb/TestCSSPixels.cpp (the subset that maps to the ported
// CSSPixels API). The V port models CSSPixels as a simplified fixed-point value
// (`raw_value_ int`, 6 fractional bits) and does NOT yet implement: saturating
// arithmetic (`might_be_saturated()` is a stub returning false), `to_float()`/`to_int()`,
// CSSPixels*CSSPixels / CSSPixels/CSSPixels operators (only `times_float`/`divided_by_float`),
// or the free `ceil()`/`floor()`/`round()` functions. Those C++ cases are intentionally
// omitted here; see the report accompanying this translation.
//
// NOTE: this file type-checks with `v -check test css/`, but cannot currently be executed
// because the css module does not survive V's C codegen (a pre-existing, module-wide V
// compiler bug unrelated to these tests).

fn test_css_pixels_addition1() {
	a := CSSPixels.new(10)
	b := CSSPixels.new(20)
	c := a.plus(b)
	assert c == CSSPixels.new(30)
}

fn test_css_pixels_subtraction1() {
	a := CSSPixels.new(30)
	b := CSSPixels.new(10)
	c := a.minus(b)
	assert c == CSSPixels.new(20)
}

fn test_css_pixels_division1() {
	a := CSSPixels.new(10)
	b := CSSPixels.new(5)
	c := a.divided_by_float(b.to_double())
	assert c == CSSPixels.new(2)
}

fn test_css_pixels_multiplication1() {
	a := CSSPixels.new(3)
	b := CSSPixels.new(4)
	c := a.times_float(b.to_double())
	assert c == CSSPixels.new(12)
}

fn test_css_pixels_addition2() {
	mut a := CSSPixels.new(3)
	a = a.plus(CSSPixels.new(2))
	assert a == CSSPixels.new(5)
}

fn test_css_pixels_to_double() {
	a := CSSPixels.new(10)
	assert a.to_double() == 10.0
}

fn test_css_pixels_comparison1() {
	assert CSSPixels.new(1).to_double() < CSSPixels.new(2).to_double()
}

fn test_css_pixels_comparison2() {
	assert CSSPixels.new(123) == CSSPixels.new(123)
}

fn test_css_pixels_multiplication_large_values() {
	a := CSSPixels.new(1200)
	b := CSSPixels.new(647)
	c := a.times_float(b.to_double())
	assert c == CSSPixels.new(776400)
}

fn test_css_pixels_nearest_value_for() {
	assert CSSPixels.nearest_value_for(2.0) == CSSPixels.new(2)
	assert CSSPixels.nearest_value_for(0.0) == CSSPixels.new(0)
}
