@[has_globals]
module platform

// A variation coordinate. The layout matches hb_variation_t, so a slice of
// these can be passed to HarfBuzz directly.
pub struct FontVariationAxis {
pub:
	tag   u32
	value f32
}

// The concrete installed face selected for a family, weight and size.
// CoreText's vertical metrics for a face at its matched size.
pub struct SystemFontMetrics {
pub:
	ascent     f64
	descent    f64
	leading    f64
	x_height   f64
	cap_height f64
	// The face-wide glyph bounds at the matched size, in pixels.
	bbox_x_min f64
	bbox_y_min f64
	bbox_x_max f64
	bbox_y_max f64
}

pub struct SystemFontFace {
pub:
	path            string
	postscript_name string
	family_name     string
	metrics         SystemFontMetrics
	face_index      int
	weight     int
	italic     bool
	variations []FontVariationAxis
}

__global (
	platform_system_font_faces    map[string]SystemFontFace
	platform_system_font_misses   map[string]bool
	platform_system_font_families map[string]bool
	platform_system_fallbacks     map[string]&Font
	platform_system_fallback_faces map[string]&Font
	platform_system_fallback_miss map[string]bool
)

// Documents with the Chromium font rendering policy select installed faces the
// way Chromium does on macOS: generic families use its default font
// preferences, system-ui is the system UI font, named families are matched
// through CoreText, and characters missing from the cascade use a
// language-aware system fallback. Other documents and the layout tests keep
// the deterministic configured faces.
pub fn system_font_matching_supported() bool {
	$if macos {
		return true
	} $else {
		return false
	}
}

fn (font &Font) uses_system_font_matching() bool {
	return font.font_rendering_policy == .chromium && system_font_matching_supported()
}

// Whether CoreText can match a family for a document with the Chromium
// policy. Other families continue through the configured and bundled faces.
pub fn chromium_system_font_family_available(family string) bool {
	return system_font_matching_supported() && system_font_matching_family_available(family)
}

// Chromium's default macOS font preferences for generic and internal names.
fn system_font_matching_family(family string) string {
	return match family.to_lower() {
		'default', 'serif', 'uiserif' { 'Times' }
		'sansserif', 'uisansserif' { 'Helvetica' }
		'monospace' { 'Menlo' }
		'uimonospace' { 'Courier' }
		'cursive' { 'Apple Chancery' }
		'fantasy' { 'Papyrus' }
		'systemui', 'uirounded' { 'system-ui' }
		else { family }
	}
}

fn system_font_matching_family_available(family string) bool {
	name := system_font_matching_family(family)
	if name.to_lower() == 'system-ui' {
		return true
	}
	key := name.to_lower()
	if cached := platform_system_font_families[key] {
		return cached
	}
	mut available := false
	$if macos {
		available = coretext_family_available(name)
	}
	platform_system_font_families[key] = available
	return available
}

fn resolve_system_font_face(family string, weight int, italic bool, point_size f32) ?SystemFontFace {
	name := system_font_matching_family(family)
	key := '${name.to_lower()}|${weight}|${italic}|${point_size}'
	if face := platform_system_font_faces[key] {
		return face
	}
	if platform_system_font_misses[key] {
		return none
	}
	$if macos {
		if face := coretext_match_family(name, weight, italic, point_size) {
			platform_system_font_faces[key] = face
			return face
		}
	}
	platform_system_font_misses[key] = true
	return none
}

// Brave (Chromium 155) does not take Devanagari from the system font's
// .SF Devanagari face: the text falls through to sans-serif, whose macOS
// cascade begins with Kohinoor Devanagari, for Hindi and Marathi alike.
fn devanagari_fallback_family(code_point u32) ?string {
	if code_point in u32(0x0900) .. u32(0x0980) || code_point in u32(0xa8e0) .. u32(0xa900)
		|| code_point in u32(0x1cd0) .. u32(0x1d00) {
		return 'Kohinoor Devanagari'
	}
	return none
}

// Chromium's per-script macOS font preferences for Han, Kana and Hangul. The
// content language selects the Han variant; untagged Han text uses CoreText.
fn cjk_fallback_family(code_point u32, language string) ?string {
	is_hangul := code_point in u32(0xac00) .. u32(0xd7b0) || code_point in u32(0x1100) .. u32(0x1200)
		|| code_point in u32(0x3130) .. u32(0x3190)
	if is_hangul {
		return 'Apple SD Gothic Neo'
	}
	is_kana := code_point in u32(0x3040) .. u32(0x3100) || code_point in u32(0x31f0) .. u32(0x3200)
	if is_kana {
		return 'Hiragino Kaku Gothic ProN'
	}
	is_han := code_point in u32(0x4e00) .. u32(0xa000) || code_point in u32(0x3400) .. u32(0x4dc0)
		|| code_point in u32(0xf900) .. u32(0xfb00) || code_point in u32(0x20000) .. u32(0x32000)
		|| code_point in u32(0x3000) .. u32(0x3040) || code_point in u32(0xff00) .. u32(0xfff0)
	if !is_han {
		return none
	}
	tag := language.to_lower().replace('_', '-')
	primary := tag.all_before('-')
	if primary == 'ja' {
		return 'Hiragino Kaku Gothic ProN'
	}
	if primary == 'ko' {
		return 'Apple SD Gothic Neo'
	}
	if primary in ['yue', 'nan', 'hak', 'lzh'] || tag.contains('-hant') || tag.ends_with('-tw')
		|| tag.ends_with('-hk') || tag.ends_with('-mo') {
		return 'PingFang TC'
	}
	if primary in ['zh', 'wuu', 'gan', 'cdo'] {
		return 'PingFang SC'
	}
	return none
}

// The native replay key naming an installed face and its variation coordinates.
pub fn (face SystemFontFace) replay_key() string {
	mut key := 'vox-system-face:${face.path}#${face.face_index}|${face.postscript_name}'
	for axis in face.variations {
		key += '|${axis.tag}=${axis.value}'
	}
	return key
}

// Font for a code point that no face in the CSS cascade covers.
pub fn system_fallback_font(code_point u32, language string, base &Font) ?&Font {
	if !base.uses_system_font_matching() {
		return none
	}
	key := '${code_point}|${language}|${base.family}|${base.weight}|${base.italic}|${base.point_size}'
	if font := platform_system_fallbacks[key] {
		return font
	}
	if platform_system_fallback_miss[key] {
		return none
	}
	mut result := ?&Font(none)
	preferred_family := if family := cjk_fallback_family(code_point, language) {
		?string(family)
	} else {
		devanagari_fallback_family(code_point)
	}
	if family := preferred_family {
		candidate := &Font{
			family: family
			point_size: base.point_size
			weight: base.weight
			italic: base.italic
			font_rendering_policy: base.font_rendering_policy
		}
		if candidate.system_face() != none && candidate.contains_glyph(code_point) {
			result = candidate
		}
	}
	if result == none {
		$if macos {
			if face := coretext_fallback(utf16_code_units(rune(code_point).str()), language,
				system_font_matching_family(base.family), base.weight, base.italic, base.point_size)
			{
				result = &Font{
					family: '${face.path}#${face.face_index}'
					point_size: base.point_size
					weight: base.weight
					italic: base.italic
					font_rendering_policy: base.font_rendering_policy
					system_face_override: face
				}
			}
		}
	}
	if font := result {
		canonical := canonical_system_fallback_font(font)
		platform_system_fallbacks[key] = canonical
		return canonical
	}
	platform_system_fallback_miss[key] = true
	return none
}

// Code points that fall back to the same face share one Font, so text runs
// split only where the used face changes, as Blink's fallback segmentation
// does, and are shaped together.
fn canonical_system_fallback_font(font &Font) &Font {
	face_key := if face := font.system_face() {
		'${face.path}#${face.face_index}|${face.postscript_name}|${face.variations}'
	} else {
		font.family
	}
	key := '${face_key}|${font.point_size}|${font.weight}|${font.italic}|${font.font_rendering_policy}'
	if existing := platform_system_fallback_faces[key] {
		return existing
	}
	platform_system_fallback_faces[key] = font
	return font
}

// The concrete installed face for this handle under the Chromium font
// rendering policy. File-backed @font-face sources never use it.
pub fn (font &Font) system_face() ?SystemFontFace {
	if face := font.system_face_override {
		return face
	}
	if !font.uses_system_font_matching() || font.source_path != '' {
		return none
	}
	if font.system_face_resolved_ {
		return font.resolved_system_face_
	}
	face := resolve_system_font_face(font.family, font.weight, font.italic, font.point_size)
	mut mutable_font := unsafe { &Font(font) }
	mutable_font.resolved_system_face_ = face
	mutable_font.system_face_resolved_ = true
	return face
}

// Variation coordinates used by shaping and replay for this face.
pub fn (font &Font) variations() []FontVariationAxis {
	if face := font.system_face() {
		return face.variations
	}
	return []
}
