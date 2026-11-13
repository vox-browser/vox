module imageraster

import math

pub struct PNGSamplingProfile {
pub:
	gamma f32
	// Column-major transform from the encoded primaries into linear sRGB.
	gamut [9]f32 = [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
}

// The D50 adaptation and f32 inverse used for PNG's canonical sRGB cHRM
// coordinates. These differ slightly from the named sRGB gamut matrix.
const png_srgb_chromaticities_gamut = [f32(0.999893188477), 1.83315132745e-05, 1.40946358442e-05,
	-0.000191695988178, 1.00009226799, 1.31726264954e-05, 4.23192977905e-06, 1.01085752249e-05,
	1.0001322031]!

fn png_u32(bytes []u8, at int) u32 {
	return (u32(bytes[at]) << 24) | (u32(bytes[at + 1]) << 16) | (u32(bytes[at + 2]) << 8) | u32(bytes[at + 3])
}

// Other chromaticities, ICC/cICP profiles and animated PNGs keep the decoder's
// existing path. sRGB has precedence over legacy gamma/chromaticity chunks.
pub fn png_sampling_profile(bytes []u8) ?PNGSamplingProfile {
	if bytes.len < 33 || bytes[..8] != [u8(137), 80, 78, 71, 13, 10, 26, 10] { return none }
	mut at := 8
	mut gamma := f32(0)
	mut has_gamma, mut has_chrm, mut srgb, mut idat := false, false, false, false
	mut chromaticities := [8]u32{}
	for at + 12 <= bytes.len {
		size := png_u32(bytes, at)
		if u64(at) + u64(size) + 12 > u64(bytes.len) { return none }
		kind := bytes[at + 4..at + 8].bytestr()
		if kind in ['acTL', 'iCCP', 'cICP'] { return none }
		if kind == 'sRGB' { srgb = true }
		if kind == 'gAMA' {
			if size != 4 || has_gamma { return none }
			gamma = f32(png_u32(bytes, at + 8)) / 100000
			has_gamma = true
		}
		if kind == 'cHRM' {
			if size != 32 || has_chrm { return none }
			for i in 0 .. 8 { chromaticities[i] = png_u32(bytes, at + 8 + i * 4) }
			has_chrm = true
		}
		if kind == 'IDAT' {
			idat = true
			break
		}
		at += int(size) + 12
	}
	if !idat { return none }
	if srgb || (!has_gamma && !has_chrm) { return PNGSamplingProfile{} }
	if !has_gamma || gamma <= 0 { return none }
	if !has_chrm && gamma * f32(2.2) > 0.95 && gamma * f32(2.2) < 1.05 {
		return PNGSamplingProfile{}
	}
	mut exponent := f32(1) / gamma
	if exponent < 0.1 || exponent > 10 { return none }
	if math.abs(exponent - f32(2.2)) < 0.001 { exponent = 2.2 }
	if math.abs(exponent - f32(1)) < 0.001 { exponent = 1 }
	if !has_chrm { return PNGSamplingProfile{ gamma: exponent } }
	if chromaticities != [u32(31270), 32900, 64000, 33000, 30000, 60000, 15000, 6000]! {
		return none
	}
	// A canonical linear space normalizes to the named sRGB gamut.
	if exponent == 1 { return PNGSamplingProfile{ gamma: exponent } }
	return PNGSamplingProfile{ gamma: exponent, gamut: png_srgb_chromaticities_gamut }
}
