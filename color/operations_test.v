module color

fn hsl(h f64, s f64, l f64) []u8 {
	c := Color.from_hsl(h, s, l)
	return [c.red, c.green, c.blue]
}

fn test_from_hsl_primaries() {
	assert hsl(0.0, 1.0, 0.5) == [u8(255), 0, 0] // red
	assert hsl(120.0, 1.0, 0.5) == [u8(0), 255, 0] // green
	assert hsl(240.0, 1.0, 0.5) == [u8(0), 0, 255] // blue
}

fn test_from_hsl_grays() {
	assert hsl(0.0, 0.0, 0.0) == [u8(0), 0, 0] // black
	assert hsl(0.0, 0.0, 1.0) == [u8(255), 255, 255] // white
	assert hsl(0.0, 0.0, 0.5) == [u8(128), 128, 128] // 127.5 rounds to 128
}

fn test_from_hsl_wraps_hue_and_clamps() {
	// Hue wraps modulo 360.
	assert hsl(-120.0, 1.0, 0.5) == hsl(240.0, 1.0, 0.5)
	assert hsl(480.0, 1.0, 0.5) == hsl(120.0, 1.0, 0.5)
	// Saturation/lightness are clamped to [0, 1].
	assert hsl(0.0, 2.0, 0.5) == hsl(0.0, 1.0, 0.5)
	assert hsl(0.0, 1.0, -0.5) == [u8(0), 0, 0]
}

fn test_from_hsla_alpha() {
	half := Color.from_hsla(0.0, 1.0, 0.5, 0.5)
	assert half.alpha == u8(128) // 0.5 * 255 rounds to 128
	opaque := Color.from_hsl(0.0, 1.0, 0.5)
	assert opaque.alpha == u8(255)
}

fn test_luminosity() {
	assert Color{ red: 255, green: 255, blue: 255 }.luminosity() == u8(255)
	assert Color{ red: 0, green: 0, blue: 0 }.luminosity() == u8(0)
	assert Color{ red: 255, green: 0, blue: 0 }.luminosity() == u8(54) // round(255 * 0.2126)
	assert Color{ red: 0, green: 255, blue: 0 }.luminosity() == u8(182) // round(255 * 0.7152)
	assert Color{ red: 0, green: 0, blue: 255 }.luminosity() == u8(18) // round(255 * 0.0722)
}

fn test_inverted() {
	red := Color{ red: 255, green: 0, blue: 0, alpha: 255 }
	inv := red.inverted()
	assert inv.red == u8(0) && inv.green == u8(255) && inv.blue == u8(255)
	assert inv.alpha == u8(255) // alpha is preserved
	// A partial alpha is kept while the RGB is complemented.
	c := Color{ red: 100, green: 150, blue: 200, alpha: 50 }
	ci := c.inverted()
	assert ci.red == u8(155) && ci.green == u8(105) && ci.blue == u8(55) && ci.alpha == u8(50)
}
