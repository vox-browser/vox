module css

import dom
import fetch
import gfxfont
import math
import mimesniff
import os
import platform
import strconv
import strings
import time
import url as liburl
import webidl

const disable_face_specific_font_completion = os.getenv('VOX_DISABLE_FACE_SPECIFIC_FONT_COMPLETION') != ''
const font_completion_diagnostics = os.getenv('VOX_FONT_COMPLETION_DIAGNOSTICS') != ''
const disable_face_specific_font_display = os.getenv('VOX_DISABLE_FACE_SPECIFIC_FONT_DISPLAY') != ''
const font_display_invalidation_diagnostics = os.getenv('VOX_FONT_DISPLAY_INVALIDATION_DIAGNOSTICS') != ''

// This file ports Ladybird's LibWeb/CSS font-face, font-feature-values, and
// font-computer logic. It uses the translated WebIDL promise, Fetch response,
// MIME sniffing, parser descriptor, and style-scope types. Owning HTML tasks,
// actual JSC Promises/wrappers and source-native decoders supply their package
// and ABI boundaries without duplicating the CSS font-loading algorithms.
//
// FontFaceObject is the native stateful translation. css/events_misc.v exposes
// FontFace as its WebIDL alias, so load events retain these same objects.

// --- Font feature data ---

pub enum FontFeatureValueType {
	stylistic
	styleset
	character_variant
	swash
	ornaments
	annotation
}

pub struct FontFeatureValueKey {
pub mut:
	type_ FontFeatureValueType
	name  string
}

pub fn font_feature_value_key_id(key FontFeatureValueKey) string {
	return '${font_feature_value_type_to_string(key.type_)}:${key.name}'
}

pub fn font_feature_value_type_to_string(type_ FontFeatureValueType) string {
	return match type_ {
		.stylistic { 'stylistic' }
		.styleset { 'styleset' }
		.character_variant { 'character-variant' }
		.swash { 'swash' }
		.ornaments { 'ornaments' }
		.annotation { 'annotation' }
	}
}

pub fn font_feature_value_type_from_string(value string) ?FontFeatureValueType {
	return match value {
		'stylistic' { .stylistic }
		'styleset' { .styleset }
		'character-variant' { .character_variant }
		'swash' { .swash }
		'ornaments' { .ornaments }
		'annotation' { .annotation }
		else { none }
	}
}

pub enum EastAsianVariant {
	jis78
	jis83
	jis90
	jis04
	simplified
	traditional
}

pub enum EastAsianWidth {
	full_width
	proportional_width
}

pub enum CommonLigValue {
	common_ligatures
	no_common_ligatures
}

pub enum DiscretionaryLigValue {
	discretionary_ligatures
	no_discretionary_ligatures
}

pub enum HistoricalLigValue {
	historical_ligatures
	no_historical_ligatures
}

pub enum ContextualAltValue {
	contextual
	no_contextual
}

pub enum NumericFigureValue {
	oldstyle_nums
	lining_nums
}

pub enum NumericSpacingValue {
	proportional_nums
	tabular_nums
}

pub enum NumericFractionValue {
	diagonal_fractions
	stacked_fractions
}

pub enum FontVariantCaps {
	normal
	small_caps
	all_small_caps
	petite_caps
	all_petite_caps
	unicase
	titling_caps
}

pub enum FontVariantEmoji {
	normal
	text
	emoji
	unicode
}

pub enum FontVariantPosition {
	normal
	sub
	super
}

pub enum FontKerning {
	auto_
	normal
	none_
}

pub enum TextRendering {
	auto_
	optimizespeed
	optimizelegibility
	geometricprecision
}

pub enum FontSmoothing {
	auto_
	none_
	antialiased
	subpixel_antialiased
}

pub struct FontVariantAlternates {
pub mut:
	historical_forms           bool
	font_feature_value_entries []FontFeatureValueKey
}

pub struct FontVariantEastAsian {
pub mut:
	ruby    bool
	variant ?EastAsianVariant
	width   ?EastAsianWidth
}

pub struct FontVariantLigatures {
pub mut:
	none_         bool
	common        ?CommonLigValue
	discretionary ?DiscretionaryLigValue
	historical    ?HistoricalLigValue
	contextual    ?ContextualAltValue
}

pub struct FontVariantNumeric {
pub mut:
	ordinal      bool
	slashed_zero bool
	figure       ?NumericFigureValue
	spacing      ?NumericSpacingValue
	fraction     ?NumericFractionValue
}

pub struct ShapeFeature {
pub mut:
	tag   string
	value u32
}

pub type ShapeFeatures = []ShapeFeature

pub struct FontFeatureData {
pub mut:
	font_variant_alternates ?FontVariantAlternates
	font_variant_caps       FontVariantCaps = .normal
	font_variant_east_asian ?FontVariantEastAsian
	font_variant_emoji      FontVariantEmoji = .normal
	font_variant_ligatures  ?FontVariantLigatures
	font_variant_numeric    ?FontVariantNumeric
	font_variant_position   FontVariantPosition = .normal

	font_feature_settings map[string]u32

	font_kerning   FontKerning = .auto_
	text_rendering TextRendering = .auto_
}

// Gfx::ShapeFeatures FontFeatureData::to_shape_features(...) const
pub fn (data FontFeatureData) to_shape_features(font_feature_values map[string][]u32) ShapeFeatures {
	$if prealloc {
		mut scratch := platform.begin_thread_scratch('font feature selection')
		selected := select_shape_features(data, font_feature_values)
		scratch.leave()
		mut owned := []ShapeFeature{len: selected.len}
		for index, feature in selected {
			owned[index] = ShapeFeature{tag: feature.tag.clone(), value: feature.value}
		}
		scratch.finish()
		return owned
	}
	return select_shape_features(data, font_feature_values)
}

// The map and generated alternate-feature keys are construction work. Only
// the ordered final feature records and their tag bytes belong to the caller.
fn select_shape_features(data FontFeatureData, font_feature_values map[string][]u32) ShapeFeatures {
	mut features := map[string]u32{}

	// 6.4 https://drafts.csswg.org/css-fonts/#font-variant-ligatures-prop
	if ligature := data.font_variant_ligatures {
		if ligature.none_ {
			// Specifies that all types of ligatures and contextual forms covered by this property are explicitly disabled.
			disable_all_shape_ligatures(mut features)
		} else {
			if common := ligature.common {
				match common {
					.common_ligatures {
						// Enables display of common ligatures (OpenType features: liga, clig).
						features['liga'] = 1
						features['clig'] = 1
					}
					.no_common_ligatures {
						// Disables display of common ligatures (OpenType features: liga, clig).
						features['liga'] = 0
						features['clig'] = 0
					}
				}
			}
			if discretionary := ligature.discretionary {
				match discretionary {
					.discretionary_ligatures {
						// Enables display of discretionary ligatures (OpenType feature: dlig).
						features['dlig'] = 1
					}
					.no_discretionary_ligatures {
						// Disables display of discretionary ligatures (OpenType feature: dlig).
						features['dlig'] = 0
					}
				}
			}
			if historical := ligature.historical {
				match historical {
					.historical_ligatures {
						// Enables display of historical ligatures (OpenType feature: hlig).
						features['hlig'] = 1
					}
					.no_historical_ligatures {
						// Disables display of historical ligatures (OpenType feature: hlig).
						features['hlig'] = 0
					}
				}
			}
			if contextual := ligature.contextual {
				match contextual {
					.contextual {
						// Enables display of contextual ligatures (OpenType feature: calt).
						features['calt'] = 1
					}
					.no_contextual {
						// Disables display of contextual ligatures (OpenType feature: calt).
						features['calt'] = 0
					}
				}
			}
		}
	} else if data.text_rendering == .optimizespeed {
		// AD-HOC: Disable ligatures if font-variant-ligatures is set to normal and text rendering is set to optimize speed.
		disable_all_shape_ligatures(mut features)
	} else {
		// A value of normal specifies that common default features are enabled, as described in detail in the next section.
		features['liga'] = 1
		features['clig'] = 1
	}

	// 6.5 https://drafts.csswg.org/css-fonts/#font-variant-position-prop
	match data.font_variant_position {
		.normal {
			// None of the features listed below are enabled.
		}
		.sub {
			// Enables display of subscripts (OpenType feature: subs).
			features['subs'] = 1
		}
		.super {
			// Enables display of superscripts (OpenType feature: sups).
			features['sups'] = 1
		}
	}

	// 6.6 https://drafts.csswg.org/css-fonts/#font-variant-caps-prop
	match data.font_variant_caps {
		.normal {
			// None of the features listed below are enabled.
		}
		.small_caps {
			// Enables display of small capitals (OpenType feature: smcp). Small-caps glyphs typically use the form of uppercase letters but are reduced to the size of lowercase letters.
			features['smcp'] = 1
		}
		.all_small_caps {
			// Enables display of small capitals for both upper and lowercase letters (OpenType features: c2sc, smcp).
			features['c2sc'] = 1
			features['smcp'] = 1
		}
		.petite_caps {
			// Enables display of petite capitals (OpenType feature: pcap).
			features['pcap'] = 1
		}
		.all_petite_caps {
			// Enables display of petite capitals for both upper and lowercase letters (OpenType features: c2pc, pcap).
			features['c2pc'] = 1
			features['pcap'] = 1
		}
		.unicase {
			// Enables display of mixture of small capitals for uppercase letters with normal lowercase letters (OpenType feature: unic).
			features['unic'] = 1
		}
		.titling_caps {
			// Enables display of titling capitals (OpenType feature: titl).
			features['titl'] = 1
		}
	}

	// 6.7 https://drafts.csswg.org/css-fonts/#font-variant-numeric-prop
	if numeric := data.font_variant_numeric {
		if figure := numeric.figure {
			match figure {
				.oldstyle_nums {
					// Enables display of old-style numerals (OpenType feature: onum).
					features['onum'] = 1
				}
				.lining_nums {
					// Enables display of lining numerals (OpenType feature: lnum).
					features['lnum'] = 1
				}
			}
		}
		if spacing := numeric.spacing {
			match spacing {
				.proportional_nums {
					// Enables display of proportional numerals (OpenType feature: pnum).
					features['pnum'] = 1
				}
				.tabular_nums {
					// Enables display of tabular numerals (OpenType feature: tnum).
					features['tnum'] = 1
				}
			}
		}
		if fraction := numeric.fraction {
			match fraction {
				.diagonal_fractions {
					// Enables display of diagonal fractions (OpenType feature: frac).
					features['frac'] = 1
				}
				.stacked_fractions {
					// Enables display of stacked fractions (OpenType feature: afrc).
					features['afrc'] = 1
				}
			}
		}
		if numeric.ordinal {
			// Enables display of letter forms used with ordinal numbers (OpenType feature: ordn).
			features['ordn'] = 1
		}
		if numeric.slashed_zero {
			// Enables display of slashed zeros (OpenType feature: zero).
			features['zero'] = 1
		}
	}

	// 6.8 https://drafts.csswg.org/css-fonts/#font-variant-alternates-prop
	// FIXME: These values never apply to generic font families
	if alternates := data.font_variant_alternates {
		if alternates.historical_forms {
			// Enables display of historical forms (OpenType feature: hist).
			features['hist'] = 1
		}

		for key in alternates.font_feature_value_entries {
			values := font_feature_values[font_feature_value_key_id(key)] or { continue }
			if values.len == 0 {
				continue
			}

			match key.type_ {
				.stylistic {
					// Enables display of stylistic alternates (font specific, OpenType feature: salt <feature-index>).
					// stylistic(<feature-value-name>)
					features['salt'] = values[0]
				}
				.styleset {
					// Enables display with stylistic sets (font specific, OpenType feature: ss<feature-index> OpenType
					// currently defines ss01 through ss20).
					//
					// https://drafts.csswg.org/css-fonts/#multi-value-features
					// For the styleset() property value and @styleset rule, multiple values indicate the style sets to
					// be enabled. Values between 1 and 99 enable OpenType features ss01 through ss99. However, the
					// OpenType standard only officially defines ss01 through ss20. For OpenType fonts, values greater
					// than 99 or equal to 0 do not generate a syntax error when parsed but enable no OpenType features.
					for value in values {
						if value > 99 || value == 0 {
							continue
						}
						features[two_digit_feature_tag('ss', value)] = 1
					}
				}
				.character_variant {
					// Enables display of specific character variants (font specific, OpenType feature:
					// cv<feature-index> OpenType currently defines cv01 through cv99).
					//
					// https://drafts.csswg.org/css-fonts/#multi-value-features
					// For <@character-variant>, a single value between 1 and 99 indicates the enabling of OpenType
					// feature cv01 through cv99. For OpenType fonts, values greater than 99 or equal to 0 are ignored
					// but do not generate a syntax error when parsed but enable no OpenType features. When two values
					// are listed, the first value indicates the feature used and the second the value passed for that
					// feature.
					feature := values[0]
					if feature > 99 || feature == 0 {
						continue
					}
					value := if values.len > 1 { values[1] } else { u32(1) }
					features[two_digit_feature_tag('cv', feature)] = value
				}
				.swash {
					// Enables display of swash glyphs (font specific, OpenType feature: swsh <feature-index>,
					// cswh <feature-index>).
					features['swsh'] = values[0]
					features['cswh'] = values[0]
				}
				.ornaments {
					// Enables replacement of default glyphs with ornaments, if provided in the font (font specific,
					// OpenType feature: ornm <feature-index>).
					features['ornm'] = values[0]
				}
				.annotation {
					// annotation(<feature-value-name>)
					// Enables display of alternate annotation forms (font specific, OpenType feature: nalt <feature-index>).
					features['nalt'] = values[0]
				}
			}
		}
	}

	// 6.10 https://drafts.csswg.org/css-fonts/#font-variant-east-asian-prop
	if east_asian := data.font_variant_east_asian {
		if variant := east_asian.variant {
			match variant {
				.jis78 {
					// Enables display of JIS78 forms (OpenType feature: jp78).
					features['jp78'] = 1
				}
				.jis83 {
					// Enables display of JIS83 forms (OpenType feature: jp83).
					features['jp83'] = 1
				}
				.jis90 {
					// Enables display of JIS90 forms (OpenType feature: jp90).
					features['jp90'] = 1
				}
				.jis04 {
					// Enables display of JIS04 forms (OpenType feature: jp04).
					features['jp04'] = 1
				}
				.simplified {
					// Enables display of simplified forms (OpenType feature: smpl).
					features['smpl'] = 1
				}
				.traditional {
					// Enables display of traditional forms (OpenType feature: trad).
					features['trad'] = 1
				}
			}
		}
		if width := east_asian.width {
			match width {
				.full_width {
					// Enables display of full-width forms (OpenType feature: fwid).
					features['fwid'] = 1
				}
				.proportional_width {
					// Enables display of proportional-width forms (OpenType feature: pwid).
					features['pwid'] = 1
				}
			}
		}
		if east_asian.ruby {
			// Enables display of ruby forms (OpenType feature: ruby).
			features['ruby'] = 1
		}
	}

	// FIXME: vkrn should be enabled for vertical text.
	match data.font_kerning {
		.auto_ {
			// AD-HOC: Disable kerning if font-kerning is set to normal and text rendering is set to optimize speed.
			features['kern'] = if data.text_rendering != .optimizespeed { u32(1) } else { u32(0) }
		}
		.normal {
			features['kern'] = 1
		}
		.none_ {
			features['kern'] = 0
		}
	}

	// https://drafts.csswg.org/css-fonts-4/#feature-variation-precedence
	// FIXME: 1. Font features enabled by default are applied, including features required for a given script. See
	//           section 7.1 Default features for a description of these.
	// FIXME: 2. Font variations as enabled by the font-weight, font-width, and font-style properties are applied.
	//
	//           The application of the value enabled by font-style is affected by font selection, because this property
	//           might select an italic or an oblique font. The value applied is the closest matching value as determined
	//           by the font matching algorithm. User agents must apply at most one value due to the font-style property;
	//           both "ital" and "slnt" values must not be set together.
	//
	//           If the selected font is defined in an @font-face rule, then the values applied at this step should be
	//           clamped to the value of the font-weight, font-width, and font-style descriptors in that @font-face rule.
	//
	//           Then, the values applied in this step should be clamped (possibly again) to the values that are
	//           supported by the font.
	// FIXME: 3. The language specified by the inherited value of lang/xml:lang is applied.
	// FIXME: 4. If the font is defined via an @font-face rule, the font language override implied by the
	//           font-language-override descriptor in the @font-face rule is applied.
	// FIXME: 5. If the font is defined via an @font-face rule, that @font-face rule includes at least one valid
	//           font-named-instance descriptor with a value other than 'font-named-instance/none', and the loaded font
	//           resource includes a named instance with that name according to the 5.1 Localized name matching rules,
	//           then all the variation values represented by that named instance are applied. These values are clamped
	//           to the values that are supported by the font.
	// FIXME: 6. If the font is defined via an @font-face rule, the font variations implied by the
	//           font-variation-settings descriptor in the @font-face rule are applied.
	// FIXME: 7. If the font is defined via an @font-face rule, the font features implied by the font-feature-settings
	//           descriptor in the @font-face rule are applied.
	// FIXME: 8. The font language override implied by the value of the font-language-override property is applied.
	// FIXME: 9. Font variations implied by the value of the font-optical-sizing property are applied.

	// 10. Font features implied by the value of the font-variant property, the related font-variant subproperties and
	//     any other CSS property that uses OpenType features (e.g. the font-kerning property) are applied.

	// FIXME: 11. Feature settings determined by properties other than font-variant or font-feature-settings are
	//            applied. For example, setting a non-default value for the letter-spacing property disables optional
	//            ligatures.
	// FIXME: 12. Font variations implied by the value of the font-variation-settings property are applied. These values
	//            should be clamped to the values that are supported by the font.

	// 13. Font features implied by the value of font-feature-settings property are applied.
	merge_shape_feature_map(mut features, data.font_feature_settings)

	mut shape_features := ShapeFeatures{}
	for tag, value in features {
		if tag.len != 4 {
			continue
		}
		shape_features << ShapeFeature{
			tag: tag
			value: value
		}
	}
	return shape_features
}

// Mutate the same map header used by the caller. Capturing a map by value in
// a closure can leave the caller's length stale on the old compiler backend.
fn disable_all_shape_ligatures(mut features map[string]u32) {
	features['liga'] = 0
	features['clig'] = 0
	features['dlig'] = 0
	features['hlig'] = 0
	features['calt'] = 0
}

fn merge_shape_feature_map(mut target map[string]u32, source map[string]u32) {
	for key, value in source {
		target[key] = value
	}
}

fn two_digit_feature_tag(prefix string, value u32) string {
	if value < 10 {
		return '${prefix}0${value}'
	}
	return '${prefix}${value}'
}

// --- @font-feature-values CSSOM ---

@[heap]
pub struct CSSFontFeatureValuesMap {
pub mut:
	entries         map[string][]u32
	order           []string
	max_value_count uint
	parent_rule     ?&CSSFontFeatureValuesRule
}

pub fn CSSFontFeatureValuesMap.create(max_value_count uint, parent_rule ?&CSSFontFeatureValuesRule) &CSSFontFeatureValuesMap {
	return &CSSFontFeatureValuesMap{
		entries: map[string][]u32{}
		max_value_count: max_value_count
		parent_rule: parent_rule
	}
}

// https://drafts.csswg.org/css-fonts-4/#cssfontfeaturevaluesmap
pub fn (mut m CSSFontFeatureValuesMap) set(feature_value_name string, values []u32) ! {
	// The CSSFontFeatureValuesMap interface uses the default map class methods but the set method has different
	// behavior. It takes a sequence of unsigned integers and associates it with a given featureValueName. The method
	// behaves the same as the default map class method except that
	//
	// a single unsigned long value is treated as a sequence of a single value.
	if values.len == 0 {
		return error('InvalidAccessError: CSSFontFeatureValuesMap.set requires at least one value.')
	}

	// If the associated feature value block only allows a limited number of values, the set method throws an
	// InvalidAccessError exception when the input sequence to set contains more than the limited number of values. See
	// the description of multi-valued feature value definitions for details on the maximum number of values allowed for
	// a given type of feature value block.
	if uint(values.len) > m.max_value_count {
		return error('InvalidAccessError: CSSFontFeatureValuesMap.set only allows a maximum of ${m.max_value_count} values for the associated feature')
	}

	if feature_value_name !in m.entries {
		m.order << feature_value_name
	}
	m.entries[feature_value_name] = values.clone()

	if mut rule := m.parent_rule {
		rule.clear_caches()
	}
}

pub fn (mut m CSSFontFeatureValuesMap) set_single(feature_value_name string, value u32) ! {
	m.set(feature_value_name, [value])!
}

pub fn (mut m CSSFontFeatureValuesMap) on_map_modified_from_js() {
	if mut rule := m.parent_rule {
		rule.clear_caches()
	}
}

pub fn (m &CSSFontFeatureValuesMap) to_ordered_hash_map() map[string][]u32 {
	mut result := map[string][]u32{}
	for key in m.order {
		if values := m.entries[key] {
			result[key] = values.clone()
		}
	}
	return result
}

@[heap]
pub struct CSSFontFeatureValuesRule {
pub mut:
	font_families_     []string
	annotation_        &CSSFontFeatureValuesMap = unsafe { nil }
	ornaments_         &CSSFontFeatureValuesMap = unsafe { nil }
	stylistic_         &CSSFontFeatureValuesMap = unsafe { nil }
	swash_             &CSSFontFeatureValuesMap = unsafe { nil }
	character_variant_ &CSSFontFeatureValuesMap = unsafe { nil }
	styleset_          &CSSFontFeatureValuesMap = unsafe { nil }
	historical_forms_  &CSSFontFeatureValuesMap = unsafe { nil }
	cache_generation   u64
}

pub fn CSSFontFeatureValuesRule.create(font_families []string) &CSSFontFeatureValuesRule {
	mut rule := &CSSFontFeatureValuesRule{
		font_families_: font_families.clone()
	}
	rule.annotation_ = CSSFontFeatureValuesMap.create(1, rule)
	rule.ornaments_ = CSSFontFeatureValuesMap.create(1, rule)
	rule.stylistic_ = CSSFontFeatureValuesMap.create(1, rule)
	rule.swash_ = CSSFontFeatureValuesMap.create(1, rule)
	rule.character_variant_ = CSSFontFeatureValuesMap.create(2, rule)
	rule.styleset_ = CSSFontFeatureValuesMap.create(max_u32_as_usize(), rule)
	rule.historical_forms_ = CSSFontFeatureValuesMap.create(1, rule)
	return rule
}

pub fn CSSFontFeatureValuesRule.is_font_feature_value_type_at_keyword(keyword string) bool {
	return keyword in [
		'stylistic',
		'historical-forms',
		'styleset',
		'character-variant',
		'swash',
		'ornaments',
		'annotation',
	]
}

pub fn (rule &CSSFontFeatureValuesRule) annotation() &CSSFontFeatureValuesMap {
	return rule.annotation_
}

pub fn (rule &CSSFontFeatureValuesRule) ornaments() &CSSFontFeatureValuesMap {
	return rule.ornaments_
}

pub fn (rule &CSSFontFeatureValuesRule) stylistic() &CSSFontFeatureValuesMap {
	return rule.stylistic_
}

pub fn (rule &CSSFontFeatureValuesRule) swash() &CSSFontFeatureValuesMap {
	return rule.swash_
}

pub fn (rule &CSSFontFeatureValuesRule) character_variant() &CSSFontFeatureValuesMap {
	return rule.character_variant_
}

pub fn (rule &CSSFontFeatureValuesRule) styleset() &CSSFontFeatureValuesMap {
	return rule.styleset_
}

pub fn (rule &CSSFontFeatureValuesRule) historical_forms() &CSSFontFeatureValuesMap {
	return rule.historical_forms_
}

pub fn (rule &CSSFontFeatureValuesRule) font_families() []string {
	return rule.font_families_
}

pub fn (rule &CSSFontFeatureValuesRule) font_family() string {
	mut serialized := []string{}
	for family in rule.font_families_ {
		if contains_ascii_whitespace(family) {
			serialized << serialize_a_string(family)
		} else {
			serialized << serialize_an_identifier(family)
		}
	}
	return serialized.join(', ')
}

pub fn (mut rule CSSFontFeatureValuesRule) set_font_family(value string) {
	mut family_names := []string{}
	for family_name in value.split(',') {
		family_names << family_name.trim_space()
	}
	rule.font_families_ = family_names
}

pub fn (rule &CSSFontFeatureValuesRule) serialized() string {
	mut builder := strings.new_builder(128)

	builder.write_string('@font-feature-values ${rule.font_family()} {')
	serialize_font_feature_values_map(mut builder, rule.annotation_, 'annotation')
	serialize_font_feature_values_map(mut builder, rule.ornaments_, 'ornaments')
	serialize_font_feature_values_map(mut builder, rule.stylistic_, 'stylistic')
	serialize_font_feature_values_map(mut builder, rule.swash_, 'swash')
	serialize_font_feature_values_map(mut builder, rule.character_variant_, 'character-variant')
	serialize_font_feature_values_map(mut builder, rule.styleset_, 'styleset')
	serialize_font_feature_values_map(mut builder, rule.historical_forms_, 'historical-forms')
	builder.write_string(' }')
	return builder.str()
}

fn serialize_font_feature_values_map(mut builder strings.Builder, feature_map &CSSFontFeatureValuesMap, at_rule_name string) {
	entries := feature_map.to_ordered_hash_map()
	if entries.len == 0 {
		return
	}
	builder.write_string('  @${at_rule_name} {')
	for key in feature_map.order {
		value := entries[key] or { continue }
		builder.write_u8(` `)
		builder.write_string(serialize_an_identifier(key))
		builder.write_u8(`:`)
		for item in value {
			builder.write_string(' ${item}')
		}
		builder.write_u8(`;`)
	}
	builder.write_string(' }')
}

pub fn (rule &CSSFontFeatureValuesRule) to_hash_map() map[string][]u32 {
	mut feature_map := map[string][]u32{}
	add_font_feature_values_map_to_hash_map(mut feature_map, rule.annotation_, .annotation)
	add_font_feature_values_map_to_hash_map(mut feature_map, rule.ornaments_, .ornaments)
	add_font_feature_values_map_to_hash_map(mut feature_map, rule.stylistic_, .stylistic)
	add_font_feature_values_map_to_hash_map(mut feature_map, rule.swash_, .swash)
	add_font_feature_values_map_to_hash_map(mut feature_map, rule.character_variant_, .character_variant)
	add_font_feature_values_map_to_hash_map(mut feature_map, rule.styleset_, .styleset)

	// NB: We don't include historical-forms since it can't be referenced - it seems like its inclusion in the syntax
	//     for @font-feature-values was a mistake and isn't supported by Chrome or Firefox. See
	//     https://github.com/w3c/csswg-drafts/issues/9926#issuecomment-2017241274
	return feature_map
}

fn add_font_feature_values_map_to_hash_map(mut target map[string][]u32, source &CSSFontFeatureValuesMap, type_ FontFeatureValueType) {
	for key in source.order {
		values := source.entries[key] or { continue }

		target[font_feature_value_key_id(FontFeatureValueKey{
			type_: type_
			name: key
		})] = values.clone()
	}
}

pub fn (mut rule CSSFontFeatureValuesRule) clear_caches() {
	rule.cache_generation++
	// Boundary: CSSFontFeatureValuesRule::clear_caches calls CSSRule::clear_caches(), then clears computed-font and
	// @font-feature-values caches through the parent stylesheet's owning document in C++. This standalone rule object
	// has no owning document link; FontComputer.add/remove_font_feature_values_rule performs the representable cache
	// invalidation when the rule is managed directly by FontComputer.
}

// --- CSS @font-face descriptors and rule ---

pub enum FontFaceDescriptorID {
	unknown
	ascent_override
	descent_override
	font_display
	font_family
	font_feature_settings
	font_language_override
	font_named_instance
	font_style
	font_variation_settings
	font_weight
	font_width
	line_gap_override
	src
	unicode_range
}

pub struct FontFaceDescriptor {
pub mut:
	id             FontFaceDescriptorID
	value          string
	font_sources   []FontSourceStyleValue
	unicode_ranges []UnicodeRange
	style_value    ?StyleValue
}

@[heap]
pub struct CSSFontFaceDescriptors {
pub mut:
	descriptors []FontFaceDescriptor
	parent_rule ?&CSSFontFaceRule
	readonly    bool
}

pub fn CSSFontFaceDescriptors.create(descriptors []FontFaceDescriptor) &CSSFontFaceDescriptors {
	return &CSSFontFaceDescriptors{
		descriptors: descriptors.clone()
	}
}

pub fn (mut descriptors CSSFontFaceDescriptors) set_parent_rule(rule &CSSFontFaceRule) {
	descriptors.parent_rule = rule
}

pub fn (descriptors &CSSFontFaceDescriptors) descriptor(id FontFaceDescriptorID) ?string {
	for descriptor in descriptors.descriptors {
		if descriptor.id == id {
			return descriptor.value
		}
	}
	return none
}

pub fn (descriptors &CSSFontFaceDescriptors) descriptor_or_initial_value(id FontFaceDescriptorID) ?string {
	if value := descriptors.descriptor(id) {
		return value
	}
	return initial_font_face_descriptor_value(id)
}

fn (descriptors &CSSFontFaceDescriptors) font_source_values() []FontSourceStyleValue {
	for descriptor in descriptors.descriptors {
		if descriptor.id == .src {
			return descriptor.font_sources.clone()
		}
	}
	return []FontSourceStyleValue{}
}

fn (descriptors &CSSFontFaceDescriptors) unicode_range_values() []UnicodeRange {
	for descriptor in descriptors.descriptors {
		if descriptor.id == .unicode_range {
			return descriptor.unicode_ranges.clone()
		}
	}
	return []UnicodeRange{}
}

fn (descriptors &CSSFontFaceDescriptors) descriptor_style_value(id FontFaceDescriptorID) ?StyleValue {
	for descriptor in descriptors.descriptors {
		if descriptor.id == id {
			return descriptor.style_value
		}
	}
	return none
}

pub fn (mut descriptors CSSFontFaceDescriptors) set_property(property string, value string, priority string) ! {
	if descriptors.readonly {
		return error('NoModificationAllowedError: Cannot modify properties of readonly CSSStyleDeclaration')
	}

	id := font_face_descriptor_id_from_property(property) or { return }

	if value.len == 0 {
		descriptors.remove_property(property)!
		return
	}

	if priority.len != 0 && priority.to_lower() != 'important' {
		return
	}

	if id == .src {
		parsed := parse_font_source_descriptor(value) or { return }
		descriptors.set_descriptor_value(FontFaceDescriptor{
			id: id
			value: parsed.serialized
			font_sources: parsed.sources
		})
	} else if id == .font_family {
		parsed := parse_font_family_descriptor(value) or { return }
		descriptors.set_descriptor_value(FontFaceDescriptor{
			id: id
			value: parsed.serialize(.normal)
			style_value: parsed
		})
	} else if id == .font_style {
		parsed := parse_font_style_descriptor(value) or { return }
		descriptors.set_descriptor_value(FontFaceDescriptor{
			id: id
			value: parsed.serialize(.normal)
			style_value: parsed
		})
	} else if id == .font_weight {
		parsed := parse_font_weight_descriptor(value) or { return }
		descriptors.set_descriptor_value(FontFaceDescriptor{
			id: id
			value: parsed.serialize(.normal)
			style_value: parsed
		})
	} else if id == .font_width {
		parsed := parse_font_width_descriptor(value) or { return }
		descriptors.set_descriptor_value(FontFaceDescriptor{
			id: id
			value: parsed.serialize(.normal)
			style_value: parsed
		})
	} else if id in [.font_feature_settings, .font_variation_settings] {
		property_id := if id == .font_feature_settings {
			PropertyID.font_feature_settings
		} else {
			PropertyID.font_variation_settings
		}
		parsed := parse_font_property_descriptor(value, property_id) or { return }
		descriptors.set_descriptor_value(FontFaceDescriptor{
			id: id
			value: parsed.serialize(.normal)
			style_value: parsed
		})
	} else if id in [.ascent_override, .descent_override, .line_gap_override] {
		parsed := parse_font_metric_override_descriptor(value) or { return }
		descriptors.set_descriptor_value(FontFaceDescriptor{
			id: id
			value: parsed.serialize(.normal)
			style_value: parsed
		})
	} else if id == .font_display {
		parsed := parse_font_keyword_descriptor(value, ['auto', 'block', 'swap', 'fallback', 'optional']) or { return }
		descriptors.set_descriptor_value(FontFaceDescriptor{
			id: id
			value: parsed.serialize(.normal)
			style_value: parsed
		})
	} else if id in [.font_language_override, .font_named_instance] {
		keyword := if id == .font_language_override { 'normal' } else { 'auto' }
		parsed := parse_font_keyword_or_string_descriptor(value, keyword) or { return }
		descriptors.set_descriptor_value(FontFaceDescriptor{
			id: id
			value: parsed.serialize(.normal)
			style_value: parsed
		})
	} else if id == .unicode_range {
		ranges := parse_unicode_ranges(value)
		if ranges.len == 0 {
			return
		}
		descriptors.set_descriptor_value(FontFaceDescriptor{
			id: id
			value: ranges.map(it.to_css_string()).join(', ')
			unicode_ranges: ranges
		})
	} else {
		parsed := parse_font_face_descriptor(id, value) or { return }
		descriptors.set_descriptor_value(FontFaceDescriptor{
			id: id
			value: parsed
		})
	}

	if mut rule := descriptors.parent_rule {
		rule.handle_descriptor_change(property)
	}
}

pub fn (mut descriptors CSSFontFaceDescriptors) remove_property(property string) !string {
	if descriptors.readonly {
		return error('NoModificationAllowedError: Cannot modify properties of readonly CSSStyleDeclaration')
	}

	id := font_face_descriptor_id_from_property(property) or { return '' }
	old_value := descriptors.descriptor(id) or { return '' }
	descriptors.remove_descriptor(id)

	if mut rule := descriptors.parent_rule {
		rule.handle_descriptor_change(property)
	}

	return old_value
}

fn (mut descriptors CSSFontFaceDescriptors) set_descriptor_value(new_descriptor FontFaceDescriptor) {
	for i, descriptor in descriptors.descriptors {
		if descriptor.id == new_descriptor.id {
			descriptors.descriptors[i] = new_descriptor
			return
		}
	}
	descriptors.descriptors << new_descriptor
}

fn (mut descriptors CSSFontFaceDescriptors) remove_descriptor(id FontFaceDescriptorID) {
	mut kept := []FontFaceDescriptor{}
	for descriptor in descriptors.descriptors {
		if descriptor.id != id {
			kept << descriptor
		}
	}
	descriptors.descriptors = kept
}

pub fn (mut descriptors CSSFontFaceDescriptors) set_ascent_override(value string) ! {
	descriptors.set_property('ascent-override', value, '')!
}

pub fn (descriptors &CSSFontFaceDescriptors) ascent_override() string {
	return descriptors.get_property_value('ascent-override')
}

pub fn (mut descriptors CSSFontFaceDescriptors) set_descent_override(value string) ! {
	descriptors.set_property('descent-override', value, '')!
}

pub fn (descriptors &CSSFontFaceDescriptors) descent_override() string {
	return descriptors.get_property_value('descent-override')
}

pub fn (mut descriptors CSSFontFaceDescriptors) set_font_display(value string) ! {
	descriptors.set_property('font-display', value, '')!
}

pub fn (descriptors &CSSFontFaceDescriptors) font_display() string {
	return descriptors.get_property_value('font-display')
}

pub fn (mut descriptors CSSFontFaceDescriptors) set_font_family(value string) ! {
	descriptors.set_property('font-family', value, '')!
}

pub fn (descriptors &CSSFontFaceDescriptors) font_family() string {
	return descriptors.get_property_value('font-family')
}

pub fn (mut descriptors CSSFontFaceDescriptors) set_font_feature_settings(value string) ! {
	descriptors.set_property('font-feature-settings', value, '')!
}

pub fn (descriptors &CSSFontFaceDescriptors) font_feature_settings() string {
	return descriptors.get_property_value('font-feature-settings')
}

pub fn (mut descriptors CSSFontFaceDescriptors) set_font_language_override(value string) ! {
	descriptors.set_property('font-language-override', value, '')!
}

pub fn (descriptors &CSSFontFaceDescriptors) font_language_override() string {
	return descriptors.get_property_value('font-language-override')
}

pub fn (mut descriptors CSSFontFaceDescriptors) set_font_named_instance(value string) ! {
	descriptors.set_property('font-named-instance', value, '')!
}

pub fn (descriptors &CSSFontFaceDescriptors) font_named_instance() string {
	return descriptors.get_property_value('font-named-instance')
}

pub fn (mut descriptors CSSFontFaceDescriptors) set_font_style(value string) ! {
	descriptors.set_property('font-style', value, '')!
}

pub fn (descriptors &CSSFontFaceDescriptors) font_style() string {
	return descriptors.get_property_value('font-style')
}

pub fn (mut descriptors CSSFontFaceDescriptors) set_font_variation_settings(value string) ! {
	descriptors.set_property('font-variation-settings', value, '')!
}

pub fn (descriptors &CSSFontFaceDescriptors) font_variation_settings() string {
	return descriptors.get_property_value('font-variation-settings')
}

pub fn (mut descriptors CSSFontFaceDescriptors) set_font_weight(value string) ! {
	descriptors.set_property('font-weight', value, '')!
}

pub fn (descriptors &CSSFontFaceDescriptors) font_weight() string {
	return descriptors.get_property_value('font-weight')
}

pub fn (mut descriptors CSSFontFaceDescriptors) set_font_width(value string) ! {
	descriptors.set_property('font-width', value, '')!
}

pub fn (descriptors &CSSFontFaceDescriptors) font_width() string {
	return descriptors.get_property_value('font-width')
}

pub fn (mut descriptors CSSFontFaceDescriptors) set_line_gap_override(value string) ! {
	descriptors.set_property('line-gap-override', value, '')!
}

pub fn (descriptors &CSSFontFaceDescriptors) line_gap_override() string {
	return descriptors.get_property_value('line-gap-override')
}

pub fn (mut descriptors CSSFontFaceDescriptors) set_src(value string) ! {
	descriptors.set_property('src', value, '')!
}

pub fn (descriptors &CSSFontFaceDescriptors) src() string {
	return descriptors.get_property_value('src')
}

pub fn (mut descriptors CSSFontFaceDescriptors) set_unicode_range(value string) ! {
	descriptors.set_property('unicode-range', value, '')!
}

pub fn (descriptors &CSSFontFaceDescriptors) unicode_range() string {
	return descriptors.get_property_value('unicode-range')
}

pub fn (descriptors &CSSFontFaceDescriptors) get_property_value(property string) string {
	id := font_face_descriptor_id_from_property(property) or { return '' }
	return descriptors.descriptor(id) or { '' }
}

pub fn font_face_descriptor_id_from_property(property string) ?FontFaceDescriptorID {
	return match property.to_lower() {
		'ascent-override' { FontFaceDescriptorID.ascent_override }
		'descent-override' { FontFaceDescriptorID.descent_override }
		'font-display' { FontFaceDescriptorID.font_display }
		'font-family' { FontFaceDescriptorID.font_family }
		'font-feature-settings' { FontFaceDescriptorID.font_feature_settings }
		'font-language-override' { FontFaceDescriptorID.font_language_override }
		'font-named-instance' { FontFaceDescriptorID.font_named_instance }
		'font-style' { FontFaceDescriptorID.font_style }
		'font-variation-settings' { FontFaceDescriptorID.font_variation_settings }
		'font-weight' { FontFaceDescriptorID.font_weight }
		'font-width', 'font-stretch' { FontFaceDescriptorID.font_width }
		'line-gap-override' { FontFaceDescriptorID.line_gap_override }
		'src' { FontFaceDescriptorID.src }
		'unicode-range' { FontFaceDescriptorID.unicode_range }
		else { none }
	}
}

pub fn font_face_descriptor_property_name(id FontFaceDescriptorID) string {
	return match id {
		.ascent_override { 'ascent-override' }
		.descent_override { 'descent-override' }
		.font_display { 'font-display' }
		.font_family { 'font-family' }
		.font_feature_settings { 'font-feature-settings' }
		.font_language_override { 'font-language-override' }
		.font_named_instance { 'font-named-instance' }
		.font_style { 'font-style' }
		.font_variation_settings { 'font-variation-settings' }
		.font_weight { 'font-weight' }
		.font_width { 'font-width' }
		.line_gap_override { 'line-gap-override' }
		.src { 'src' }
		.unicode_range { 'unicode-range' }
		.unknown { '' }
	}
}

fn initial_font_face_descriptor_value(id FontFaceDescriptorID) ?string {
	return match id {
		.font_style { 'auto' }
		.font_weight { 'auto' }
		.font_width { 'auto' }
		.unicode_range { 'U+0-10FFFF' }
		.font_feature_settings { 'normal' }
		.font_variation_settings { 'normal' }
		.font_display { 'auto' }
		.ascent_override { 'normal' }
		.descent_override { 'normal' }
		.line_gap_override { 'normal' }
		.font_language_override { 'normal' }
		.font_named_instance { 'auto' }
		else { none }
	}
}

fn parse_font_face_descriptor(id FontFaceDescriptorID, value string) ?string {
	trimmed := value.trim_space()
	if trimmed.len == 0 {
		return none
	}
	for component_value in parse_component_values_for_value_logic(trimmed) {
		if component_value.is(.semicolon) {
			return none
		}
	}

	match id {
		.font_display {
			return parse_font_keyword_descriptor(trimmed, ['auto', 'block', 'swap', 'fallback',
				'optional'])?.serialize(.normal)
		}
		.ascent_override, .descent_override, .line_gap_override {
			return parse_font_metric_override_descriptor(trimmed)?.serialize(.normal)
		}
		.src {
			return parse_font_source_descriptor(trimmed)?.serialized
		}
		.font_family {
			return parse_font_family_descriptor(trimmed)?.serialize(.normal)
		}
		.unicode_range {
			if parse_unicode_ranges(trimmed).len == 0 {
				return none
			}
		}
		.font_weight {
			return parse_font_weight_descriptor(trimmed)?.serialize(.normal)
		}
		.font_style {
			return parse_font_style_descriptor(trimmed)?.serialize(.normal)
		}
		.font_width {
			return parse_font_width_descriptor(trimmed)?.serialize(.normal)
		}
		.font_feature_settings {
			return parse_font_property_descriptor(trimmed, .font_feature_settings)?.serialize(.normal)
		}
		.font_variation_settings {
			return parse_font_property_descriptor(trimmed, .font_variation_settings)?.serialize(.normal)
		}
		.font_language_override {
			return parse_font_keyword_or_string_descriptor(trimmed, 'normal')?.serialize(.normal)
		}
		.font_named_instance {
			return parse_font_keyword_or_string_descriptor(trimmed, 'auto')?.serialize(.normal)
		}
		else {}
	}

	return trimmed
}

@[heap]
pub struct CSSFontFaceRule {
pub mut:
	style_                  &CSSFontFaceDescriptors = unsafe { nil }
	css_connected_font_face ?&FontFaceObject
	parent_style_sheet      ?&CSSStyleSheet
}

pub fn CSSFontFaceRule.create(style &CSSFontFaceDescriptors) &CSSFontFaceRule {
	mut rule := &CSSFontFaceRule{
		style_: style
	}
	mut mutable_style := unsafe { &CSSFontFaceDescriptors(style) }
	mutable_style.set_parent_rule(rule)
	return rule
}

pub fn (rule &CSSFontFaceRule) is_valid() bool {
	// @font-face rules require a font-family and src descriptor; if either of these are missing, the @font-face rule
	// must not be considered when performing the font matching algorithm.
	// https://drafts.csswg.org/css-fonts-4/#font-face-rule
	return rule.style_.descriptor(.font_family) != none && rule.style_.descriptor(.src) != none
}

pub fn (rule &CSSFontFaceRule) font_face() ParsedFontFace {
	return ParsedFontFace.from_descriptors(rule.style_)
}

pub fn (rule &CSSFontFaceRule) style() &CSSFontFaceDescriptors {
	return rule.style_
}

pub fn (rule &CSSFontFaceRule) descriptors() &CSSFontFaceDescriptors {
	return rule.style_
}

pub fn (rule &CSSFontFaceRule) css_connected_font_face_ref() ?&FontFaceObject {
	return rule.css_connected_font_face
}

pub fn (mut rule CSSFontFaceRule) set_css_connected_font_face(font_face ?&FontFaceObject) {
	rule.css_connected_font_face = font_face
}

// https://www.w3.org/TR/cssom/#ref-for-cssfontfacerule
pub fn (rule &CSSFontFaceRule) serialized() string {
	descriptors := rule.style_
	mut builder := strings.new_builder(128)

	// The result of concatenating the following:

	// 1. The string "@font-face {", followed by a single SPACE (U+0020).
	// AD-HOC: We add the in the below AD-HOC block to avoid an extra space if there is no font-family descriptor.
	builder.write_string('@font-face {')

	// AD-HOC: We don't necessary always have a font-family descriptor as the spec assumes,
	//         see https://github.com/w3c/csswg-drafts/issues/13323
	if font_family := descriptors.descriptor(.font_family) {
		builder.write_u8(` `)
		// 2. The string "font-family:", followed by a single SPACE (U+0020).
		builder.write_string('font-family: ')
		// 3. The result of performing serialize a string on the rule's font family name.
		builder.write_string(font_family)
		// 4. The string ";", i.e., SEMICOLON (U+003B).
		builder.write_u8(`;`)
	}

	// 5. If the rule's associated source list is not empty, follow these substeps:
	if sources := descriptors.descriptor(.src) {
		// 1. A single SPACE (U+0020), followed by the string "src:", followed by a single SPACE (U+0020).
		builder.write_string(' src: ')
		// 2. The result of invoking serialize a comma-separated list on performing serialize a URL or serialize a LOCAL for each source on the source list.
		builder.write_string(sources)
		// 3. The string ";", i.e., SEMICOLON (U+003B).
		builder.write_u8(`;`)
	}

	// 6. If rule's associated unicode-range descriptor is present, a single SPACE (U+0020), followed by the string
	// "unicode-range:", followed by a single SPACE (U+0020), followed by the result of performing serialize a
	// <'unicode-range'>, followed by the string ";", i.e., SEMICOLON (U+003B).
	if unicode_range := descriptors.descriptor(.unicode_range) {
		builder.write_string(' unicode-range: ')
		builder.write_string(unicode_range)
		builder.write_u8(`;`)
	}

	// FIXME: 7. If rule's associated font-variant descriptor is present, a single SPACE (U+0020),
	// followed by the string "font-variant:", followed by a single SPACE (U+0020),
	// followed by the result of performing serialize a <'font-variant'>,
	// followed by the string ";", i.e., SEMICOLON (U+003B).

	// 8. If rule's associated font-feature-settings descriptor is present, a single SPACE (U+0020),
	//    followed by the string "font-feature-settings:", followed by a single SPACE (U+0020),
	//    followed by the result of performing serialize a <'font-feature-settings'>,
	//    followed by the string ";", i.e., SEMICOLON (U+003B).
	if font_feature_settings := descriptors.descriptor(.font_feature_settings) {
		builder.write_string(' font-feature-settings: ')
		builder.write_string(font_feature_settings)
		builder.write_u8(`;`)
	}

	// 9. If rule's associated font-stretch descriptor is present, a single SPACE (U+0020),
	//    followed by the string "font-stretch:", followed by a single SPACE (U+0020),
	//    followed by the result of performing serialize a <'font-stretch'>,
	//    followed by the string ";", i.e., SEMICOLON (U+003B).
	// NOTE: font-stretch is now an alias for font-width, so we use that instead.
	if font_width := descriptors.descriptor(.font_width) {
		builder.write_string(' font-stretch: ')
		builder.write_string(font_width)
		builder.write_u8(`;`)
	}

	// 10. If rule's associated font-weight descriptor is present, a single SPACE (U+0020),
	//     followed by the string "font-weight:", followed by a single SPACE (U+0020),
	//     followed by the result of performing serialize a <'font-weight'>,
	//     followed by the string ";", i.e., SEMICOLON (U+003B).
	if font_weight := descriptors.descriptor(.font_weight) {
		builder.write_string(' font-weight: ')
		builder.write_string(font_weight)
		builder.write_u8(`;`)
	}

	// 11. If rule's associated font-style descriptor is present, a single SPACE (U+0020),
	//     followed by the string "font-style:", followed by a single SPACE (U+0020),
	//     followed by the result of performing serialize a <'font-style'>,
	//     followed by the string ";", i.e., SEMICOLON (U+003B).
	if font_style := descriptors.descriptor(.font_style) {
		builder.write_string(' font-style: ')
		builder.write_string(font_style)
		builder.write_u8(`;`)
	}

	// 12. A single SPACE (U+0020), followed by the string "}", i.e., RIGHT CURLY BRACKET (U+007D).
	builder.write_string(' }')

	return builder.str()
}

pub fn (mut rule CSSFontFaceRule) handle_descriptor_change(property string) {
	if rule.css_connected_font_face == none {
		return
	}

	if !rule.is_valid() {
		rule.disconnect_font_face()
		return
	}

	if property.to_lower() == 'src' {
		rule.handle_src_descriptor_change()
		return
	}

	// https://drafts.csswg.org/css-font-loading/#font-face-css-connection
	// any change made to a @font-face descriptor is immediately reflected in the corresponding FontFace attribute
	if mut font_face := rule.css_connected_font_face {
		was_registered := font_face.should_be_registered_with_font_computer()
		if was_registered {
			if mut computer := font_face.font_computer() {
				computer.unregister_font_face(font_face)
			}
		}
		font_face.reparse_connected_css_font_face_rule_descriptors()
		if was_registered {
			if mut computer := font_face.font_computer() {
				computer.register_font_face(font_face)
			}
		}
	}
}

// https://drafts.csswg.org/css-font-loading/#font-face-css-connection
pub fn (mut rule CSSFontFaceRule) handle_src_descriptor_change() {
	// If a @font-face rule has its src descriptor changed to a new value, the original connected FontFace object must
	// stop being CSS-connected. A new FontFace reflecting its new src must be created and CSS-connected to the
	// @font-face.
	old_font_face := rule.css_connected_font_face or { return }
	containing_sets := old_font_face.containing_sets.clone()

	rule.disconnect_font_face()

	new_font_face := create_connected_font_face(old_font_face.environment_font_computer_, rule)
	rule.css_connected_font_face = new_font_face

	for set in containing_sets {
		mut mutable_set := unsafe { &FontFaceSet(set) }
		mutable_set.add_css_connected_font(new_font_face)
	}
}

pub fn (mut rule CSSFontFaceRule) disconnect_font_face() {
	if mut font_face := rule.css_connected_font_face {
		containing_sets := font_face.containing_sets.clone()
		font_face.disconnect_from_css_rule()
		for set in containing_sets {
			mut mutable_set := unsafe { &FontFaceSet(set) }
			mutable_set.delete_(font_face)
		}
	}

	rule.css_connected_font_face = none
}

pub fn (mut rule CSSFontFaceRule) set_parent_style_sheet(parent_style_sheet ?&CSSStyleSheet) {
	// Font faces resolve relative URLs against their containing sheet, but do not
	// participate in the sheet's critical-subresource loading state.
	rule.parent_style_sheet = parent_style_sheet
}

// --- ParsedFontFace ---

pub enum FontSourceKind {
	local
	url
}

pub enum FontTech {
	features_opentype
	features_aat
	features_graphite
	variations
	color_colrv0
	color_colrv1
	color_svg
	color_sbix
	color_cbdt
	palettes
	incremental
	avar2
}

pub struct ParsedFontFaceSource {
pub mut:
	kind   FontSourceKind
	value  string
	url    ?URL
	format ?string
	tech   []FontTech
}

pub enum FontDisplay {
	auto_
	block
	swap
	fallback
	optional
}

pub enum FontDisplayPeriod {
	block
	swap
	failure
}

pub struct UnicodeRange {
pub mut:
	start u32
	end   u32
}

pub struct FontWeightRange {
pub mut:
	min int
	max int
}

pub fn (range FontWeightRange) contains_inclusive(weight int) bool {
	return range.min <= weight && weight <= range.max
}

pub struct ParsedFontFace {
pub mut:
	parent_rule              ?&CSSFontFaceRule
	font_family_             string
	weight_                  ?FontWeightRange
	slope_                   ?int
	width_                   ?int
	sources_                 []ParsedFontFaceSource
	unicode_ranges_          []UnicodeRange
	ascent_override_         ?Percentage
	descent_override_        ?Percentage
	line_gap_override_       ?Percentage
	font_display_            FontDisplay = .auto_
	font_named_instance_     ?string
	font_language_override_  ?string
	font_feature_settings_   ?map[string]i64
	font_variation_settings_ ?map[string]f64
}

pub fn ParsedFontFace.sources_from_style_value(style_value string) []ParsedFontFaceSource {
	return parse_font_face_sources(style_value)
}

pub fn ParsedFontFace.from_descriptors(descriptors &CSSFontFaceDescriptors) ParsedFontFace {
	mut font_family := ''
	if value := descriptors.descriptor_or_initial_value(.font_family) {
		if parsed_family := descriptors.descriptor_style_value(.font_family) {
			font_family = string_from_style_value(parsed_family)
		} else {
			font_family = string_from_font_family_descriptor(value)
		}
	}

	mut weight := ?FontWeightRange(none)
	if value := descriptors.descriptor_or_initial_value(.font_weight) {
		// https://drafts.csswg.org/css-fonts-4/#font-prop-desc
		// The auto values for these three descriptors have the following effects:
		//  - For font selection purposes, the font is selected as if the appropriate normal value (normal, normal or normal) is chosen
		//  - FIXME: For variation axis clamping, clamping does not occur
		if value.to_lower() == 'auto' {
			weight = FontWeightRange{
				min: 400
				max: 400
			}
		} else if parsed_weight := descriptors.descriptor_style_value(.font_weight) {
			weight = font_weight_range_from_style_value(parsed_weight)
		} else {
			weight = parse_font_weight_range(value)
		}
	}

	mut slope := ?int(none)
	if value := descriptors.descriptor_or_initial_value(.font_style) {
		// https://drafts.csswg.org/css-fonts-4/#font-prop-desc
		// The auto values for these three descriptors have the following effects:
		//  - For font selection purposes, the font is selected as if the appropriate normal value (normal, normal or normal) is chosen
		//  - FIXME: For variation axis clamping, clamping does not occur
		if value.to_lower() == 'auto' {
			slope = 0
		} else if parsed_style := descriptors.descriptor_style_value(.font_style) {
			if font_style := parsed_style.as_font_style() {
				slope = font_style.to_font_slope()
			} else {
				slope = compute_font_style_slope(value)
			}
		} else {
			slope = compute_font_style_slope(value)
		}
	}

	mut width := ?int(none)
	if value := descriptors.descriptor_or_initial_value(.font_width) {
		// https://drafts.csswg.org/css-fonts-4/#font-prop-desc
		// The auto values for these three descriptors have the following effects:
		//  - For font selection purposes, the font is selected as if the appropriate normal value (normal, normal or normal) is chosen
		//  - FIXME: For variation axis clamping, clamping does not occur
		if value.to_lower() == 'auto' {
			width = 100
		} else if parsed_width := descriptors.descriptor_style_value(.font_width) {
			width = font_width_from_style_value(parsed_width)
		} else {
			width = compute_font_width(value)
		}
	}

	mut sources := []ParsedFontFaceSource{}
	if value := descriptors.descriptor(.src) {
		font_source_values := descriptors.font_source_values()
		// Descriptors produced by the parser and CSSOM retain their parsed values. Keep a
		// compatibility fallback for callers that manually construct the public V struct.
		sources = if font_source_values.len > 0 {
			parsed_font_face_sources_from_style_values(font_source_values)
		} else {
			ParsedFontFace.sources_from_style_value(value)
		}
	}

	mut unicode_ranges := []UnicodeRange{}
	if value := descriptors.descriptor_or_initial_value(.unicode_range) {
		parsed_ranges := descriptors.unicode_range_values()
		unicode_ranges = if parsed_ranges.len > 0 {
			parsed_ranges.clone()
		} else {
			parse_unicode_ranges(value)
		}
	}

	mut ascent_override := ?Percentage(none)
	if value := descriptors.descriptor_or_initial_value(.ascent_override) {
		if parsed_value := descriptors.descriptor_style_value(.ascent_override) {
			ascent_override = percentage_from_font_metric_override(parsed_value)
		} else if parsed_value := parse_font_metric_override_descriptor(value) {
			ascent_override = percentage_from_font_metric_override(parsed_value)
		}
	}

	mut descent_override := ?Percentage(none)
	if value := descriptors.descriptor_or_initial_value(.descent_override) {
		if parsed_value := descriptors.descriptor_style_value(.descent_override) {
			descent_override = percentage_from_font_metric_override(parsed_value)
		} else if parsed_value := parse_font_metric_override_descriptor(value) {
			descent_override = percentage_from_font_metric_override(parsed_value)
		}
	}

	mut line_gap_override := ?Percentage(none)
	if value := descriptors.descriptor_or_initial_value(.line_gap_override) {
		if parsed_value := descriptors.descriptor_style_value(.line_gap_override) {
			line_gap_override = percentage_from_font_metric_override(parsed_value)
		} else if parsed_value := parse_font_metric_override_descriptor(value) {
			line_gap_override = percentage_from_font_metric_override(parsed_value)
		}
	}

	mut font_display := FontDisplay.auto_
	if value := descriptors.descriptor_or_initial_value(.font_display) {
		if parsed_value := descriptors.descriptor_style_value(.font_display) {
			font_display = font_display_from_keyword(parsed_value.to_keyword()) or { FontDisplay.auto_ }
		} else {
			font_display = font_display_from_string(value) or { FontDisplay.auto_ }
		}
	}

	mut font_named_instance := ?string(none)
	if value := descriptors.descriptor_or_initial_value(.font_named_instance) {
		if parsed_value := descriptors.descriptor_style_value(.font_named_instance) {
			font_named_instance = string_from_font_keyword_or_string(parsed_value)
		} else if parsed_value := parse_font_keyword_or_string_descriptor(value, 'auto') {
			font_named_instance = string_from_font_keyword_or_string(parsed_value)
		}
	}

	mut font_language_override := ?string(none)
	if value := descriptors.descriptor_or_initial_value(.font_language_override) {
		if parsed_value := descriptors.descriptor_style_value(.font_language_override) {
			font_language_override = string_from_font_keyword_or_string(parsed_value)
		} else if parsed_value := parse_font_keyword_or_string_descriptor(value, 'normal') {
			font_language_override = string_from_font_keyword_or_string(parsed_value)
		}
	}

	mut font_feature_settings := ?map[string]i64(none)
	if value := descriptors.descriptor_or_initial_value(.font_feature_settings) {
		if value.to_lower() != 'normal' {
			if parsed_value := descriptors.descriptor_style_value(.font_feature_settings) {
				font_feature_settings = font_feature_settings_from_style_value(parsed_value)
			} else if parsed_value := parse_font_property_descriptor(value, .font_feature_settings) {
				font_feature_settings = font_feature_settings_from_style_value(parsed_value)
			}
		}
	}

	mut font_variation_settings := ?map[string]f64(none)
	if value := descriptors.descriptor_or_initial_value(.font_variation_settings) {
		if value.to_lower() != 'normal' {
			if parsed_value := descriptors.descriptor_style_value(.font_variation_settings) {
				font_variation_settings = font_variation_settings_from_style_value(parsed_value)
			} else if parsed_value := parse_font_property_descriptor(value, .font_variation_settings) {
				font_variation_settings = font_variation_settings_from_style_value(parsed_value)
			}
		}
	}

	return ParsedFontFace{
		parent_rule: descriptors.parent_rule
		font_family_: font_family
		weight_: weight
		slope_: slope
		width_: width
		sources_: sources
		unicode_ranges_: unicode_ranges
		ascent_override_: ascent_override
		descent_override_: descent_override
		line_gap_override_: line_gap_override
		font_display_: font_display
		font_named_instance_: font_named_instance
		font_language_override_: font_language_override
		font_feature_settings_: font_feature_settings
		font_variation_settings_: font_variation_settings
	}
}

pub fn (face &ParsedFontFace) font_family() string {
	return face.font_family_
}

pub fn (face &ParsedFontFace) parent_rule_ref() ?&CSSFontFaceRule {
	return face.parent_rule
}

pub fn (face &ParsedFontFace) weight() ?FontWeightRange {
	return face.weight_
}

pub fn (face &ParsedFontFace) slope() ?int {
	return face.slope_
}

pub fn (face &ParsedFontFace) width() ?int {
	return face.width_
}

pub fn (face &ParsedFontFace) sources() []ParsedFontFaceSource {
	return face.sources_
}

pub fn (face &ParsedFontFace) unicode_ranges() []UnicodeRange {
	return face.unicode_ranges_
}

pub fn (face &ParsedFontFace) font_display() FontDisplay {
	return face.font_display_
}

pub fn (face &ParsedFontFace) ascent_override() ?Percentage {
	return face.ascent_override_
}

pub fn (face &ParsedFontFace) descent_override() ?Percentage {
	return face.descent_override_
}

pub fn (face &ParsedFontFace) line_gap_override() ?Percentage {
	return face.line_gap_override_
}

pub fn (face &ParsedFontFace) font_named_instance() ?string {
	return face.font_named_instance_
}

pub fn (face &ParsedFontFace) font_language_override() ?string {
	return face.font_language_override_
}

pub fn (face &ParsedFontFace) font_feature_settings() ?map[string]i64 {
	return face.font_feature_settings_
}

pub fn (face &ParsedFontFace) font_variation_settings() ?map[string]f64 {
	return face.font_variation_settings_
}

// --- FontFace object model ---

pub enum FontFaceLoadStatus {
	unloaded
	loading
	loaded
	error
}

pub struct FontFaceDescriptors {
pub mut:
	style              string = 'normal'
	weight             string = 'normal'
	stretch            string = 'normal'
	unicode_range      string = 'U+0-10FFFF'
	feature_settings   string = 'normal'
	variation_settings string = 'normal'
	display            string = 'auto'
	ascent_override    string = 'normal'
	descent_override   string = 'normal'
	line_gap_override  string = 'normal'
}

pub enum FontFaceSourceKind {
	cssom_string
	binary_data
}

pub struct FontFaceSource {
pub mut:
	kind FontFaceSourceKind
	text string
	data []u8
}

pub fn FontFaceSource.from_string(text string) FontFaceSource {
	return FontFaceSource{
		kind: .cssom_string
		text: text
	}
}

pub fn FontFaceSource.from_binary(data []u8) FontFaceSource {
	return FontFaceSource{
		kind: .binary_data
		data: data.clone()
	}
}

@[heap]
pub struct FontFaceObject {
pub mut:
	family_             string
	style_              string
	weight_             string
	stretch_            string
	unicode_range_      string
	unicode_ranges_     []UnicodeRange
	feature_settings_   string
	variation_settings_ string
	display_            string
	ascent_override_    string
	descent_override_   string
	line_gap_override_  string

	status_             FontFaceLoadStatus = .unloaded
	font_status_promise &webidl.Promise = unsafe { nil }
	cached_width_       int = 100
	cached_slope_       int
	urls                []ParsedFontFaceSource
	binary_data         []u8
	parsed_font                    &PlatformTypeface = unsafe { nil }
	font_display_       FontDisplay = .auto_
	font_display_period_ FontDisplayPeriod = .block
	font_download_timer_start_ns_ ?i64
	font_download_timer_ ?&platform.Timer
	font_loader_ ?&FontLoader
	font_display_time_for_testing_ ?u32
	font_display_failed_ bool
	font_download_completed_ bool

	// The relevant global owns loading tasks and Promise creation, independently of set membership.
	environment_font_computer_ ?&FontComputer
	load_error_ ?webidl.Value
	css_font_face_rule ?&CSSFontFaceRule
	containing_sets    []&FontFaceSet
}

pub fn (mut face FontFaceObject) set_font_display_time_for_testing(milliseconds u32) {
	face.font_display_time_for_testing_ = milliseconds
	face.update_font_display_period()
}

pub fn (face &FontFaceObject) font_display_time_for_testing() ?u32 {
	return face.font_display_time_for_testing_
}

// https://drafts.csswg.org/css-font-loading/#font-face-constructor
pub fn FontFaceObject.construct_impl(family string, source FontFaceSource, descriptors FontFaceDescriptors) &FontFaceObject {
	return construct_font_face(none, family, source, descriptors)
}

pub fn FontFaceObject.construct_impl_for_font_computer(computer &FontComputer, family string, source FontFaceSource, descriptors FontFaceDescriptors) &FontFaceObject {
	return construct_font_face(computer, family, source, descriptors)
}

fn construct_font_face(computer ?&FontComputer, family string, source FontFaceSource, descriptors FontFaceDescriptors) &FontFaceObject {
	// 1. Let font face be a fresh FontFace object. Set font face's status attribute to "unloaded",
	//    Set its internal [[FontStatusPromise]] slot to a fresh pending Promise object.
	mut font_face := &FontFaceObject{
		font_status_promise: webidl.create_promise_for(font_loading_promise_context(computer))
		environment_font_computer_: computer
	}

	//    Parse the family argument, and the members of the descriptors argument,
	//    according to the grammars of the corresponding descriptors of the CSS @font-face rule.
	//    If the source argument is a CSSOMString, parse it according to the grammar of the CSS src descriptor of the @font-face rule.
	//    If any of them fail to parse correctly, reject font face's [[FontStatusPromise]] with a DOMException named "SyntaxError",
	//    set font face's corresponding attributes to the empty string, and set font face's status attribute to "error".
	//    Otherwise, set font face's corresponding attributes to the serialization of the parsed values.
	if parsed_family := parse_font_family_descriptor(family) {
		font_face.family_ = string_from_style_value(parsed_family)
	} else {
		font_face.reject_status_promise('FontFace constructor: Invalid font-family')
	}
	font_face.set_style_impl(font_face_try_parse_descriptor(mut font_face, .font_style, descriptors.style))
	font_face.weight_ = font_face_try_parse_descriptor(mut font_face, .font_weight, descriptors.weight)
	stretch := font_face_try_parse_descriptor(mut font_face, .font_width, descriptors.stretch)
	font_face.set_stretch_impl(stretch)
	unicode_range := font_face_try_parse_descriptor(mut font_face, .unicode_range, descriptors.unicode_range)
	font_face.set_unicode_range_impl(unicode_range)
	font_face.feature_settings_ = font_face_try_parse_descriptor(mut font_face, .font_feature_settings, descriptors.feature_settings)
	font_face.variation_settings_ = font_face_try_parse_descriptor(mut font_face, .font_variation_settings, descriptors.variation_settings)
	font_face.set_display_impl(font_face_try_parse_descriptor(mut font_face, .font_display, descriptors.display))
	font_face.ascent_override_ = font_face_try_parse_descriptor(mut font_face, .ascent_override, descriptors.ascent_override)
	font_face.descent_override_ = font_face_try_parse_descriptor(mut font_face, .descent_override, descriptors.descent_override)
	font_face.line_gap_override_ = font_face_try_parse_descriptor(mut font_face, .line_gap_override, descriptors.line_gap_override)

	mut parsed_source_values := []FontSourceStyleValue{}
	if source.kind == .cssom_string {
		if parsed := parse_font_source_descriptor(source.text) {
			parsed_source_values = parsed.sources.clone()
		} else {
			font_face.reject_status_promise('FontFace constructor: Invalid src')
		}
	}

	//    Return font face. If font face's status is "error", terminate this algorithm;
	//    otherwise, complete the rest of these steps asynchronously.
	// FIXME: Do the rest of this asynchronously.
	if font_face.status() == .error {
		return font_face
	}

	// 2. If the source argument was a CSSOMString, set font face's internal [[Urls]] slot to the string.
	//    If the source argument was a BinaryData, set font face's internal [[Data]] slot to the passed argument.
	if source.kind == .cssom_string {
		font_face.urls = parsed_font_face_sources_from_style_values(parsed_source_values)
		font_face.urls = font_face.urls.filter(!is_unsupported_source(it))
	} else {
		font_face.binary_data = source.data.clone()
	}

	if font_face.binary_data.len == 0 && font_face.urls.len == 0 {
		font_face.reject_status_promise('FontFace constructor: Invalid font source')
	}

	// 3. If font face's [[Data]] slot is not null, queue a task to run the following steps synchronously:
	if font_face.binary_data.len == 0 {
		return font_face
	}

	if computer != none {
		queue_font_loading_task(computer, true, fn [font_face] () {
			mut face := unsafe { &FontFaceObject(font_face) }
			face.start_owned_binary_load()
		})
	} else {
		// The standalone CSS adapter has no relevant global or owning task queue.
		font_face.start_binary_load()
	}
	return font_face
}

// https://drafts.csswg.org/css-font-loading/#font-face-css-connection
pub fn FontFaceObject.create_css_connected(rule &CSSFontFaceRule) &FontFaceObject {
	return create_connected_font_face(none, rule)
}

pub fn FontFaceObject.create_css_connected_for_font_computer(computer &FontComputer, rule &CSSFontFaceRule) &FontFaceObject {
	return create_connected_font_face(computer, rule)
}

fn create_connected_font_face(computer ?&FontComputer, rule &CSSFontFaceRule) &FontFaceObject {
	mut font_face := &FontFaceObject{
		// CSS-connected source states materialize their Promise only when exposed.
		font_status_promise: if computer == none { webidl.create_promise() } else { unsafe { &webidl.Promise(nil) } }
		environment_font_computer_: computer
		css_font_face_rule: rule
	}

	font_face.reparse_connected_css_font_face_rule_descriptors()

	if _ := rule.descriptors().descriptor(.src) {
		font_face.urls = parsed_font_face_sources_from_style_values(rule.descriptors().font_source_values())
		font_face.urls = font_face.urls.filter(!is_unsupported_source(it))
	}

	mut mutable_rule := unsafe { &CSSFontFaceRule(rule) }
	mutable_rule.set_css_connected_font_face(font_face)

	return font_face
}

pub fn (mut face FontFaceObject) reparse_connected_css_font_face_rule_descriptors() {
	rule := face.css_font_face_rule or { return }
	descriptors := rule.descriptors()

	if parsed_family := descriptors.descriptor_style_value(.font_family) {
		face.family_ = string_from_style_value(parsed_family)
	} else if value := descriptors.descriptor(.font_family) {
		face.set_family_impl(value)
	}
	face.set_style_impl(descriptors.descriptor_or_initial_value(.font_style) or { 'auto' })
	face.set_weight_impl(descriptors.descriptor_or_initial_value(.font_weight) or { 'auto' })
	face.set_stretch_impl(descriptors.descriptor_or_initial_value(.font_width) or { 'auto' })
	face.set_unicode_range_impl(descriptors.descriptor_or_initial_value(.unicode_range) or {
		'U+0-10FFFF'
	})
	face.set_feature_settings_impl(descriptors.descriptor_or_initial_value(.font_feature_settings) or {
		'normal'
	})
	face.set_variation_settings_impl(descriptors.descriptor_or_initial_value(.font_variation_settings) or {
		'normal'
	})
	face.set_display_impl(descriptors.descriptor_or_initial_value(.font_display) or { 'auto' })
	face.set_ascent_override_impl(descriptors.descriptor_or_initial_value(.ascent_override) or {
		'normal'
	})
	face.set_descent_override_impl(descriptors.descriptor_or_initial_value(.descent_override) or {
		'normal'
	})
	face.set_line_gap_override_impl(descriptors.descriptor_or_initial_value(.line_gap_override) or {
		'normal'
	})
}

pub fn (face &FontFaceObject) parsed_font_face() ParsedFontFace {
	if rule := face.css_font_face_rule {
		return rule.font_face()
	}

	// FIXME: The ParsedFontFace is kind of expensive to create. We should be using a shared sub-object for the data
	return ParsedFontFace{
		// Create a dummy CSSFontFaceRule so that we load relative to the document's base URL.
		parent_rule: CSSFontFaceRule.create(CSSFontFaceDescriptors.create([]FontFaceDescriptor{}))
		font_family_: face.family_
		// FIXME: Actually parse this as we're supposed to.
		weight_: parse_font_face_object_numeric_weight(face.weight_)
		slope_: face.cached_slope_
		width_: face.cached_width_
		sources_: face.urls.clone()
		unicode_ranges_: face.unicode_ranges_.clone()
		font_display_: face.font_display_
		font_named_instance_: none // font-named-instance doesn't exist in FontFace
		// font-language-override doesn't exist in FontFace
		font_language_override_: none
		font_feature_settings_: none // FIXME: feature_settings
		font_variation_settings_: none // FIXME: variation_settings
	}
}

pub fn (face &FontFaceObject) family() string {
	return face.family_
}

pub fn (face &FontFaceObject) style() string {
	return face.style_
}

pub fn (face &FontFaceObject) weight() string {
	return face.weight_
}

pub fn (face &FontFaceObject) stretch() string {
	return face.stretch_
}

pub fn (face &FontFaceObject) unicode_range() string {
	return face.unicode_range_
}

pub fn (face &FontFaceObject) unicode_ranges() []UnicodeRange {
	return face.unicode_ranges_.clone()
}

pub fn (face &FontFaceObject) has_urls() bool {
	return face.urls.len > 0
}

pub fn (face &FontFaceObject) has_non_default_unicode_range() bool {
	return face.unicode_ranges_.len != 1 || face.unicode_ranges_[0].start != 0
		|| face.unicode_ranges_[0].end != 0x10ffff
}

pub fn (face &FontFaceObject) feature_settings() string {
	return face.feature_settings_
}

pub fn (face &FontFaceObject) variation_settings() string {
	return face.variation_settings_
}

pub fn (face &FontFaceObject) display() string {
	return face.display_
}

pub fn (face &FontFaceObject) ascent_override() string {
	return face.ascent_override_
}

pub fn (face &FontFaceObject) descent_override() string {
	return face.descent_override_
}

pub fn (face &FontFaceObject) line_gap_override() string {
	return face.line_gap_override_
}

pub fn (face &FontFaceObject) is_css_connected() bool {
	return face.css_font_face_rule != none
}

pub fn (face &FontFaceObject) should_be_registered_with_font_computer() bool {
	return face.is_css_connected() || face.has_urls() || face.status() == .loaded
}

pub fn (face &FontFaceObject) declared_width() int {
	return face.cached_width_
}

fn (face &FontFaceObject) font_computer() ?&FontComputer {
	for set in face.containing_sets {
		if computer := set.font_computer_ {
			return computer
		}
	}
	return none
}

fn (face &FontFaceObject) font_with_point_size(point_size f32, variations FontVariationSettings, shape_features ShapeFeatures) &FontCascadeList {
	if face.font_display_failed_ || face.status_ == .error {
		return unsafe { nil }
	}
	mut font_list := FontCascadeList.create()
	if face.parsed_font != unsafe { nil } {
		font_list.add(PlatformFont{
			typeface:   face.parsed_font
			point_size: point_size
			variations: variations
			features: shape_features
		}, face.unicode_ranges_)
	} else if face.has_urls() {
		font_list.add_pending_face(face)
	}
	if font_list.is_empty() {
		return unsafe { nil }
	}
	return font_list
}

// https://drafts.csswg.org/css-fonts-4/#font-display-timeline
fn (mut face FontFaceObject) resolve_for_rendering() PendingFontState {
	if face.font_display_failed_ || face.status_ == .error {
		return .failed
	}
	if face.status_ == .loaded {
		return .visible
	}
	if face.font_download_timer_start_ns_ == none {
		face.font_download_timer_start_ns_ = time.sys_mono_now()
		if face.font_display_ == .swap {
			face.font_display_period_ = .swap
		}
		face.update_font_display_period()
	}
	face.load_for_style()
	if mut loader := face.font_loader_ {
		loader.did_request_for_rendering()
	}
	if face.status_ == .loaded {
		return .visible
	}
	if face.status_ == .error {
		return .failed
	}
	return match face.font_display_period_ {
		.block { .invisible }
		.swap { .visible }
		.failure { .failed }
	}
}

fn (mut face FontFaceObject) invalidate_font_display() {
	if mut computer := face.font_computer() {
		computer.invalidate_font_face_display(face)
	}
}

fn (mut face FontFaceObject) update_font_display_period() {
	if mut timer := face.font_download_timer_ {
		timer.stop()
	}
	if face.font_download_timer_start_ns_ == none {
		return
	}
	if face.font_download_completed_ || face.status_ in [.loaded, .error] {
		return
	}
	mut block_period_ms := i64(0)
	mut failure_period_start_ms := ?i64(none)
	match face.font_display_ {
		.auto_, .block {
			block_period_ms = 3000
		}
		.swap {}
		.fallback {
			block_period_ms = 100
			failure_period_start_ms = i64(3100)
		}
		.optional {
			block_period_ms = 100
			failure_period_start_ms = i64(100)
		}
	}

	elapsed_ms := face.font_download_elapsed_time()
	previous_period := face.font_display_period_
	mut failure_period_reached := false
	mut next_deadline_ms := ?i64(none)
	if failure_start := failure_period_start_ms {
		failure_period_reached = elapsed_ms >= failure_start
	}
	if face.font_display_failed_ || failure_period_reached {
		face.font_display_period_ = .failure
		face.font_display_failed_ = true
	} else if elapsed_ms < block_period_ms {
		face.font_display_period_ = .block
		next_deadline_ms = block_period_ms
	} else {
		face.font_display_period_ = .swap
		next_deadline_ms = failure_period_start_ms
	}
	if previous_period != face.font_display_period_ {
		face.invalidate_font_display()
	}
	deadline_ms := next_deadline_ms or { return }
	if face.font_display_time_for_testing_ != none {
		return
	}
	if face.font_download_timer_ == none {
		face_pointer := unsafe { &FontFaceObject(face) }
		face.font_download_timer_ = platform.Timer.create_single_shot(0, fn [face_pointer] () {
			mut mutable_face := unsafe { &FontFaceObject(face_pointer) }
			mutable_face.update_font_display_period()
		})
	}
	if mut timer := face.font_download_timer_ {
		timer.start_with_interval(int(deadline_ms - elapsed_ms))
	}
}

fn (face &FontFaceObject) font_download_elapsed_time() i64 {
	started_at := face.font_download_timer_start_ns_ or { return 0 }
	return if milliseconds := face.font_display_time_for_testing_ {
		i64(milliseconds)
	} else {
		(time.sys_mono_now() - started_at) / 1_000_000
	}
}

pub fn (face &FontFaceObject) has_pending_rendering() bool {
	return face.font_download_timer_start_ns_ != none && face.status_ == .loading
		&& !face.font_display_failed_
}

pub fn (face &FontFaceObject) is_pending_rendering_from_cache() bool {
	loader := face.font_loader_ or { return false }
	return face.has_pending_rendering() && loader.may_finish_from_cache()
		&& (loader.has_started_request() || loader.has_received_font_data_
			|| face.font_download_elapsed_time() < 100)
}

pub fn (mut face FontFaceObject) disconnect_from_css_rule() {
	face.css_font_face_rule = none
}

pub fn (face &FontFaceObject) status() FontFaceLoadStatus {
	return face.status_
}

pub fn (face &FontFaceObject) loaded() &webidl.Promise {
	if face.font_status_promise == unsafe { nil } {
		mut mutable_face := unsafe { &FontFaceObject(face) }
		mutable_face.font_status_promise = webidl.create_promise_for(font_loading_promise_context(face.environment_font_computer_))
		if face.status_ == .loaded {
			mutable_face.font_status_promise.resolve(face.binding_value())
		} else if face.status_ == .error {
			mutable_face.font_status_promise.reject(face.load_error_ or { panic('missing font load error') })
			webidl.mark_promise_as_handled(mut mutable_face.font_status_promise)
		}
	}
	return face.font_status_promise
}

pub fn (face &FontFaceObject) font_status_promise_ref() &webidl.Promise {
	return face.loaded()
}

fn (face &FontFaceObject) binding_value() webidl.Value {
	return webidl.Value{ kind: .platform_object, opaque_id: u64(voidptr(face)), platform_interfaces: ['FontFace'] }
}

pub fn (mut face FontFaceObject) set_family(value string) ! {
	parsed := parse_font_family_descriptor(value) or {
		return error('SyntaxError: FontFace.family setter: Invalid descriptor value')
	}
	if mut rule := face.css_font_face_rule {
		mut descriptors := unsafe { &CSSFontFaceDescriptors(rule.descriptors()) }
		descriptors.set_font_family(value)!
		return
	}
	was_registered := face.should_be_registered_with_font_computer()
	if was_registered {
		if mut computer := face.font_computer() {
			computer.unregister_font_face(face)
		}
	}
	face.family_ = string_from_style_value(parsed)
	if was_registered {
		if mut computer := face.font_computer() {
			computer.register_font_face(face)
		}
	}
}

pub fn (mut face FontFaceObject) set_family_impl(value string) {
	face.family_ = string_from_font_family_descriptor(value)
}

pub fn (mut face FontFaceObject) set_style(value string) ! {
	parsed := parse_font_face_descriptor(.font_style, value) or {
		return error('SyntaxError: FontFace.style setter: Invalid descriptor value')
	}
	if mut rule := face.css_font_face_rule {
		mut descriptors := unsafe { &CSSFontFaceDescriptors(rule.descriptors()) }
		descriptors.set_font_style(value)!
		return
	}
	was_registered := face.should_be_registered_with_font_computer()
	if was_registered {
		if mut computer := face.font_computer() {
			computer.unregister_font_face(face)
		}
	}
	face.set_style_impl(parsed)
	if was_registered {
		if mut computer := face.font_computer() {
			computer.register_font_face(face)
		}
	}
}

pub fn (mut face FontFaceObject) set_style_impl(value string) {
	face.style_ = value
	face.cached_slope_ = compute_font_style_slope(value)
}

pub fn (mut face FontFaceObject) set_weight(value string) ! {
	parsed := parse_font_face_descriptor(.font_weight, value) or {
		return error('SyntaxError: FontFace.weight setter: Invalid descriptor value')
	}
	if mut rule := face.css_font_face_rule {
		mut descriptors := unsafe { &CSSFontFaceDescriptors(rule.descriptors()) }
		descriptors.set_font_weight(value)!
		return
	}
	was_registered := face.should_be_registered_with_font_computer()
	if was_registered {
		if mut computer := face.font_computer() {
			computer.unregister_font_face(face)
		}
	}
	face.set_weight_impl(parsed)
	if was_registered {
		if mut computer := face.font_computer() {
			computer.register_font_face(face)
		}
	}
}

pub fn (mut face FontFaceObject) set_weight_impl(value string) {
	face.weight_ = value
}

pub fn (mut face FontFaceObject) set_stretch(value string) ! {
	// NOTE: font-stretch is now an alias for font-width
	parsed := parse_font_face_descriptor(.font_width, value) or {
		return error('SyntaxError: FontFace.stretch setter: Invalid descriptor value')
	}
	if mut rule := face.css_font_face_rule {
		mut descriptors := unsafe { &CSSFontFaceDescriptors(rule.descriptors()) }
		descriptors.set_font_width(value)!
		return
	}
	was_registered := face.should_be_registered_with_font_computer()
	if was_registered {
		if mut computer := face.font_computer() {
			computer.unregister_font_face(face)
		}
	}
	face.set_stretch_impl(parsed)
	if was_registered {
		if mut computer := face.font_computer() {
			computer.register_font_face(face)
		}
	}
}

pub fn (mut face FontFaceObject) set_stretch_impl(value string) {
	face.stretch_ = value
	face.cached_width_ = compute_font_width(value)
}

pub fn (mut face FontFaceObject) set_unicode_range(value string) ! {
	parsed := parse_font_face_descriptor(.unicode_range, value) or {
		return error('SyntaxError: FontFace.unicodeRange setter: Invalid descriptor value')
	}
	if mut rule := face.css_font_face_rule {
		mut descriptors := unsafe { &CSSFontFaceDescriptors(rule.descriptors()) }
		descriptors.set_unicode_range(value)!
		return
	}
	face.set_unicode_range_impl(parsed)
	if face.should_be_registered_with_font_computer() {
		if mut computer := face.font_computer() {
			computer.did_load_font(face.family_)
		}
	}
}

pub fn (mut face FontFaceObject) set_unicode_range_impl(value string) {
	face.unicode_range_ = value
	face.unicode_ranges_ = parse_unicode_ranges(value)
}

pub fn (mut face FontFaceObject) set_feature_settings(value string) ! {
	parsed := parse_font_face_descriptor(.font_feature_settings, value) or {
		return error('SyntaxError: FontFace.featureSettings setter: Invalid descriptor value')
	}
	if mut rule := face.css_font_face_rule {
		mut descriptors := unsafe { &CSSFontFaceDescriptors(rule.descriptors()) }
		descriptors.set_font_feature_settings(value)!
	}
	face.set_feature_settings_impl(parsed)
}

pub fn (mut face FontFaceObject) set_feature_settings_impl(value string) {
	face.feature_settings_ = value
}

pub fn (mut face FontFaceObject) set_variation_settings(value string) ! {
	parsed := parse_font_face_descriptor(.font_variation_settings, value) or {
		return error('SyntaxError: FontFace.variationSettings setter: Invalid descriptor value')
	}
	if mut rule := face.css_font_face_rule {
		mut descriptors := unsafe { &CSSFontFaceDescriptors(rule.descriptors()) }
		descriptors.set_font_variation_settings(value)!
	}
	face.set_variation_settings_impl(parsed)
}

pub fn (mut face FontFaceObject) set_variation_settings_impl(value string) {
	face.variation_settings_ = value
}

pub fn (mut face FontFaceObject) set_display(value string) ! {
	parsed := parse_font_face_descriptor(.font_display, value) or {
		return error('SyntaxError: FontFace.display setter: Invalid descriptor value')
	}
	if mut rule := face.css_font_face_rule {
		mut descriptors := unsafe { &CSSFontFaceDescriptors(rule.descriptors()) }
		descriptors.set_font_display(value)!
	}
	face.set_display_impl(parsed)
}

pub fn (mut face FontFaceObject) set_display_impl(value string) {
	face.display_ = value
	face.font_display_ = font_display_from_string(value) or { FontDisplay.auto_ }
	face.update_font_display_period()
}

pub fn (mut face FontFaceObject) set_ascent_override(value string) ! {
	parsed := parse_font_face_descriptor(.ascent_override, value) or {
		return error('SyntaxError: FontFace.ascentOverride setter: Invalid descriptor value')
	}
	if mut rule := face.css_font_face_rule {
		mut descriptors := unsafe { &CSSFontFaceDescriptors(rule.descriptors()) }
		descriptors.set_ascent_override(value)!
	}
	face.set_ascent_override_impl(parsed)
}

pub fn (mut face FontFaceObject) set_ascent_override_impl(value string) {
	face.ascent_override_ = value
}

pub fn (mut face FontFaceObject) set_descent_override(value string) ! {
	parsed := parse_font_face_descriptor(.descent_override, value) or {
		return error('SyntaxError: FontFace.descentOverride setter: Invalid descriptor value')
	}
	if mut rule := face.css_font_face_rule {
		mut descriptors := unsafe { &CSSFontFaceDescriptors(rule.descriptors()) }
		descriptors.set_descent_override(value)!
	}
	face.set_descent_override_impl(parsed)
}

pub fn (mut face FontFaceObject) set_descent_override_impl(value string) {
	face.descent_override_ = value
}

pub fn (mut face FontFaceObject) set_line_gap_override(value string) ! {
	parsed := parse_font_face_descriptor(.line_gap_override, value) or {
		return error('SyntaxError: FontFace.lineGapOverride setter: Invalid descriptor value')
	}
	if mut rule := face.css_font_face_rule {
		mut descriptors := unsafe { &CSSFontFaceDescriptors(rule.descriptors()) }
		descriptors.set_line_gap_override(value)!
	}
	face.set_line_gap_override_impl(parsed)
}

pub fn (mut face FontFaceObject) set_line_gap_override_impl(value string) {
	face.line_gap_override_ = value
}

// https://drafts.csswg.org/css-font-loading/#dom-fontface-load
pub fn (mut face FontFaceObject) load() &webidl.Promise {
	face.load_for_style()
	return face.loaded()
}

pub fn (mut face FontFaceObject) load_for_style() {
	//  1. Let font face be the FontFace object on which this method was called.

	// 2. If font face's [[Urls]] slot is null, or its status attribute is anything other than "unloaded",
	//    return font face's [[FontStatusPromise]] and abort these steps.
	if !face.begin_url_load() {
		return
	}

	// 3. Otherwise, set font face's status attribute to "loading", return font face's [[FontStatusPromise]],
	//    and continue executing the rest of this algorithm asynchronously.
	// The source starts the request in this task; its completion is a separate
	// font-loading task. FontLoader's transport remains an explicit boundary.
	if mut computer := face.environment_font_computer_ {
		face.continue_url_load_with_font_computer(mut computer)
	} else if mut computer := face.font_computer() {
		face.continue_url_load_with_font_computer(mut computer)
	} else {
		face.finish_loading_from_typeface(face.load_first_available_url())
	}
}

pub fn (mut face FontFaceObject) load_with_font_computer(font_computer &FontComputer) &webidl.Promise {
	if !face.begin_url_load() {
		return face.loaded()
	}

	mut mutable_computer := unsafe { &FontComputer(font_computer) }
	face.continue_url_load_with_font_computer(mut mutable_computer)
	return face.loaded()
}

fn (mut face FontFaceObject) continue_url_load_with_font_computer(mut font_computer FontComputer) {
	face_pointer := unsafe { &FontFaceObject(face) }
	computer_pointer := unsafe { &FontComputer(font_computer) }
	on_load := fn [face_pointer, computer_pointer] (typeface &PlatformTypeface) {
		queue_font_loading_task(computer_pointer, true, fn [face_pointer, typeface] () {
			mut mutable_face := unsafe { &FontFaceObject(face_pointer) }
			mutable_face.finish_loading_from_typeface(typeface)
		})
	}
	loader := font_computer.load_font_face(face.parsed_font_face(), on_load) or { return }
	face.font_loader_ = loader

	mut mutable_loader := unsafe { &FontLoader(loader) }
	mutable_loader.start_loading_next_url()
}

pub fn (mut face FontFaceObject) add_to_set(set &FontFaceSet) {
	if !font_face_set_array_contains(face.containing_sets, set) {
		face.containing_sets << set
	}
}

pub fn (mut face FontFaceObject) remove_from_set(set &FontFaceSet) {
	mut kept := []&FontFaceSet{}
	for existing in face.containing_sets {
		if existing != set {
			kept << existing
		}
	}
	face.containing_sets = kept
}

fn (mut face FontFaceObject) reject_status_promise(reason string) {
	face.reject_status_exception('SyntaxError', reason)
}

fn (mut face FontFaceObject) reject_status_exception(name string, reason string) {
	if face.status_ == .error { return }
	value := if face.environment_font_computer_ != none {
		webidl.dom_exception_value(webidl.DOMException.create(name, reason))
	} else { webidl.string_value(reason) }
	if face.font_status_promise != unsafe { nil } {
		face.font_status_promise.reject(value)
		webidl.mark_promise_as_handled(mut face.font_status_promise)
	} else {
		face.load_error_ = value
	}
	face.status_ = .error
}

fn (mut face FontFaceObject) begin_url_load() bool {
	if face.urls.len == 0 || face.status_ != .unloaded {
		return false
	}

	face.status_ = .loading

	// AD-HOC: URL-backed fonts must update their containing FontFaceSets just like
	// BufferSource-backed fonts do while their load is in progress.
	for mut font_face_set in face.containing_sets {
		if font_face_set.loading_fonts_.len == 0 {
			font_face_set.switch_to_loading()
		}
		font_face_set.loading_fonts_ << face
	}
	return true
}

fn (face &FontFaceObject) load_first_available_url() &PlatformTypeface {
	for source in face.urls {
		if source.kind != .url {
			continue
		}
		url := source.url or { URL.from_url(source.value) }
		resolved_url := resolve_font_face_source_url(url, face.css_font_face_rule)
		typeface := platform_load_font_from_url_boundary(resolved_url, face.family_)
		if typeface != unsafe { nil } {
			return typeface
		}
	}
	return unsafe { nil }
}

// FontFaceState::create_for_constructor: both publication paths are separate
// global font-loading tasks, including immediately decoded sfnt/WOFF data.
fn (mut face FontFaceObject) start_owned_binary_load() {
	face.status_ = .loading
	for mut set in face.containing_sets {
		if set.loading_fonts_.len == 0 { set.switch_to_loading() }
		set.loading_fonts_ << face
	}
	data := face.binary_data
	face.binary_data = []u8{}
	handle := voidptr(&face)
	if requires_off_thread_vector_font_preparation(data, none) {
		if prepare_vector_font_data_for_computer(data, fn [handle] (prepared PreparedVectorFontData) {
			mut owner := unsafe { &FontFaceObject(handle) }
			if message := prepared.error_message {
				owner.queue_binary_completion(unsafe { nil }, message)
			} else {
				typeface := font_typeface_from_prepared_bytes(prepared.data, owner.family_) or {
					owner.queue_binary_completion(unsafe { nil }, err.msg())
					return
				}
				owner.queue_binary_completion(typeface, '')
			}
		}, face.environment_font_computer_) { return }
	}
	typeface := try_load_vector_font(data, none, face.family_) or {
		face.queue_binary_completion(unsafe { nil }, err.msg())
		return
	}
	face.queue_binary_completion(typeface, '')
}

fn (mut face FontFaceObject) queue_binary_completion(typeface &PlatformTypeface, message string) {
	face_pointer := unsafe { &FontFaceObject(face) }
	queue_font_loading_task(face.environment_font_computer_, true, fn [face_pointer, typeface, message] () {
		mut face := unsafe { &FontFaceObject(face_pointer) }
		face.finish_loading_with_error(typeface, 'SyntaxError', 'Failed to load font: ${message}')
	})
}

fn (mut face FontFaceObject) start_binary_load() {
	face.status_ = .loading
	for mut font_face_set in face.containing_sets {
		if font_face_set.loading_fonts_.len == 0 {
			font_face_set.switch_to_loading()
		}
		font_face_set.loading_fonts_ << face
	}
	typeface := platform_load_font_from_bytes_boundary(face.binary_data, face.family_)
	face.finish_loading_from_typeface(typeface)
}

fn (mut face FontFaceObject) finish_loading_from_typeface(typeface &PlatformTypeface) {
	face.update_font_display_period()
	face.font_download_completed_ = true
	if mut timer := face.font_download_timer_ {
		timer.stop()
	}
	face.finish_loading_with_error(typeface, 'NetworkError', 'Failed to load font')
	face.font_loader_ = none
}

fn (mut face FontFaceObject) finish_loading_with_error(typeface &PlatformTypeface, error_name string, message string) {
	if typeface != unsafe { nil } {
		// 1. If the load was successful, font face now represents the parsed font;
		//    fulfill font face's [[FontStatusPromise]] with font face, and set its status attribute to "loaded".
		face.parsed_font = owned_platform_typeface(typeface)
		face.status_ = .loaded
		if face.font_status_promise != unsafe { nil } { face.font_status_promise.resolve(face.binding_value()) }
		if mut computer := face.font_computer() {
			computer.publish_loaded_font_face(face)
		}

		// For each FontFaceSet font face is in:
		for mut font_face_set in face.containing_sets {
			// 1. Add font face to the FontFaceSet's [[LoadedFonts]] list.
			font_face_set.loaded_fonts_ << face

			// 2. Remove font face from the FontFaceSet's [[LoadingFonts]] list. If font was the last item in
			//    that list (and so the list is now empty), switch the FontFaceSet to loaded.
			font_face_set.remove_loading_font(face)
			if font_face_set.loading_fonts_.len == 0 {
				font_face_set.switch_to_loaded()
			}
		}
	} else {
		// 2. Otherwise, reject font face's [[FontStatusPromise]] with a DOMException named "SyntaxError"/"NetworkError"
		//    and set font face's status attribute to "error".
		face.reject_status_exception(error_name, message)
		if error_name == 'NetworkError' { face.invalidate_font_display() }

		for mut font_face_set in face.containing_sets {
			font_face_set.failed_fonts_ << face
			font_face_set.remove_loading_font(face)
			if font_face_set.loading_fonts_.len == 0 {
				font_face_set.switch_to_loaded()
			}
		}
	}
}

fn font_face_try_parse_descriptor(mut font_face FontFaceObject, descriptor_id FontFaceDescriptorID, value string) string {
	result := parse_font_face_descriptor(descriptor_id, value) or {
		font_face.reject_status_promise('FontFace constructor: Invalid ${font_face_descriptor_property_name(descriptor_id)}')
		return ''
	}
	if descriptor_id == .font_family {
		return string_from_font_family_descriptor(result)
	}
	return result
}

// In order to avoid conflicts with the old WinIE style of @font-face, if there is no format specified,
// we check to see if the URL ends with .eot. We will not try to load those.
// This matches the behavior of other engines (Blink, WebKit).
fn is_unsupported_source(source ParsedFontFaceSource) bool {
	if source.kind != .url {
		return false
	}
	if format := source.format {
		return !font_format_is_supported(format)
	}
	return source.value.to_lower().ends_with('.eot')
}

pub fn font_format_is_supported(name string) bool {
	// https://drafts.csswg.org/css-fonts-4/#font-format-definitions
	return match name.to_lower() {
		'collection', 'opentype', 'truetype', 'woff', 'woff2' {
			true
		}

		// LibGfx::font_format_is_supported currently reports these as unsupported.
		'embedded-opentype', 'svg' {
			false
		}
		else {
			false
		}
	}
}

pub fn font_tech_is_supported(font_tech FontTech) bool {
	// https://drafts.csswg.org/css-fonts-4/#font-tech-definitions
	// https://drafts.csswg.org/css-fonts-5/#font-tech-definitions
	return match font_tech {
		.features_opentype, .features_aat, .color_colrv0, .color_colrv1, .color_svg, .color_sbix,
		.color_cbdt, .palettes, .avar2 {
			true
		}

		// The C++ implementation makes Graphite support depend on the HarfBuzz build flag. This standalone V port has
		// no such capability check, so keep the boundary conservative.
		.features_graphite, .variations, .incremental {
			false
		}
	}
}

pub fn font_tech_is_supported_name(name string) bool {
	if font_tech := font_tech_from_string(name) {
		return font_tech_is_supported(font_tech)
	}
	return false
}

// --- FontFaceSet ---

pub enum FontFaceSetLoadStatus {
	loading
	loaded
}

@[heap]
pub struct FontFaceSet {
	dom.EventTarget
pub mut:
	set_entries_   []&FontFaceObject
	font_computer_ ?&FontComputer
	setlike_binding_hooks_ []FontFaceSetBindingHooks

	ready_promise &webidl.Promise = unsafe { nil }

	loading_fonts_ []&FontFaceObject
	loaded_fonts_  []&FontFaceObject
	failed_fonts_  []&FontFaceObject

	status_ FontFaceSetLoadStatus = .loaded

	is_pending_on_the_environment bool = true
	// https://drafts.csswg.org/css-font-loading/#fontfaceset-stuck-on-the-environment
	is_stuck_on_the_environment bool
	fired_events                []FontFaceSetLoadEventRecord
}

// FontFaceSet.cpp Bindings::{did_add,did_remove,did_reorder}_font_face(s).
pub struct FontFaceSetBindingHooks {
pub:
	owner voidptr
	did_add fn (&FontFaceObject) @[required]
	did_remove fn (&FontFaceObject) @[required]
	did_reorder fn () @[required]
}

pub fn (mut set FontFaceSet) install_setlike_binding_hooks(hooks FontFaceSetBindingHooks) {
	set.setlike_binding_hooks_ = set.setlike_binding_hooks_.filter(it.owner != hooks.owner)
	set.setlike_binding_hooks_ << hooks
}

pub fn (mut set FontFaceSet) clear_setlike_binding_hooks(owner voidptr) {
	set.setlike_binding_hooks_ = set.setlike_binding_hooks_.filter(it.owner != owner)
}

pub struct FontFaceSetLoadEventRecord {
pub mut:
	name      string
	fontfaces []&FontFaceObject
}

pub fn FontFaceSet.create() &FontFaceSet {
	mut set := &FontFaceSet{
		ready_promise: webidl.create_promise()
	}
	set.initialize()
	return set
}

pub fn FontFaceSet.create_for_font_computer(font_computer &FontComputer) &FontFaceSet {
	mut set := &FontFaceSet{
		font_computer_: font_computer
		ready_promise: webidl.create_promise_for(font_loading_promise_context(font_computer))
	}
	set.initialize()
	return set
}

pub fn (mut set FontFaceSet) associate_font_computer(font_computer &FontComputer) {
	set.font_computer_ = font_computer
}

pub fn (mut set FontFaceSet) initialize() {
	// WEB_SET_PROTOTYPE_FOR_INTERFACE(FontFaceSet);
	set.EventTarget.initialize()
}

pub fn (mut set FontFaceSet) visit_edges(mut visitor dom.CellVisitor) {
	set.EventTarget.visit_edges(mut visitor)
	for face in set.set_entries_ {
		visitor.visit(face)
	}
	visitor.visit(set.ready_promise)
	for face in set.loading_fonts_ {
		visitor.visit(face)
	}
	for face in set.loaded_fonts_ {
		visitor.visit(face)
	}
	for face in set.failed_fonts_ {
		visitor.visit(face)
	}
}

pub fn (set &FontFaceSet) event_target() &dom.EventTarget {
	return unsafe { &dom.EventTarget(set) }
}

pub fn (set &FontFaceSet) font_face_set_record() voidptr {
	return voidptr(set)
}

pub fn (set &FontFaceSet) set_entries() []&FontFaceObject {
	return set.set_entries_
}

pub fn (set &FontFaceSet) loading_fonts() []&FontFaceObject {
	return set.loading_fonts_
}

pub fn (set &FontFaceSet) loaded_fonts() []&FontFaceObject {
	return set.loaded_fonts_
}

pub fn (set &FontFaceSet) failed_fonts() []&FontFaceObject {
	return set.failed_fonts_
}

pub fn (set &FontFaceSet) set_onloading(event_handler ?&dom.CallbackType) {
	set.event_target().set_event_handler_attribute('loading', event_handler)
}

pub fn (set &FontFaceSet) onloading() ?&dom.CallbackType {
	return set.event_target().event_handler_attribute('loading')
}

pub fn (set &FontFaceSet) set_onloadingdone(event_handler ?&dom.CallbackType) {
	set.event_target().set_event_handler_attribute('loadingdone', event_handler)
}

pub fn (set &FontFaceSet) onloadingdone() ?&dom.CallbackType {
	return set.event_target().event_handler_attribute('loadingdone')
}

pub fn (set &FontFaceSet) set_onloadingerror(event_handler ?&dom.CallbackType) {
	set.event_target().set_event_handler_attribute('loadingerror', event_handler)
}

pub fn (set &FontFaceSet) onloadingerror() ?&dom.CallbackType {
	return set.event_target().event_handler_attribute('loadingerror')
}

pub fn (set &FontFaceSet) on_set_modified_from_js() {
	_ = set
}

// https://drafts.csswg.org/css-font-loading/#dom-fontfaceset-add
pub fn (mut set FontFaceSet) add(face &FontFaceObject) !&FontFaceSet {
	// 1. If font is already in the FontFaceSet's set entries, skip to the last step of this algorithm immediately.
	if font_face_object_array_contains(set.set_entries_, face) {
		return set
	}

	// 2. If font is CSS-connected, throw an InvalidModificationError exception and exit this algorithm immediately.
	if face.is_css_connected() {
		return error('InvalidModificationError: Cannot add a CSS-connected FontFace to a FontFaceSet')
	}

	// NB: This method implements steps 3 and 4.
	set.add_css_connected_font(face)

	// 5. Return the FontFaceSet.
	return set
}

// https://drafts.csswg.org/css-font-loading/#dom-fontfaceset-add
pub fn (mut set FontFaceSet) add_css_connected_font(face &FontFaceObject) {
	// 3. Add the font argument to the FontFaceSet's set entries.
	if font_face_object_array_contains(set.set_entries_, face) { return }
	set.set_entries_ << face
	for hooks in set.setlike_binding_hooks_ { hooks.did_add(face) }
	mut mutable_face := unsafe { &FontFaceObject(face) }
	mutable_face.add_to_set(set)
	if face.should_be_registered_with_font_computer() {
		if mut computer := set.font_computer_ {
			computer.register_font_face(face)
		}
	}

	// 4. If font's status attribute is "loading"
	if face.status() == .loading {
		// 1. If the FontFaceSet's [[LoadingFonts]] list is empty, switch the FontFaceSet to loading.
		if set.loading_fonts_.len == 0 {
			set.switch_to_loading()
		}

		// 2. Append font to the FontFaceSet's [[LoadingFonts]] list.
		set.loading_fonts_ << face
	}
}

pub fn (mut set FontFaceSet) synchronize_css_connected_font_order(ordered_connected_faces []&FontFaceObject) {
	mut ordered_faces := []&FontFaceObject{cap: set.set_entries_.len}
	for face in ordered_connected_faces {
		if font_face_object_array_contains(set.set_entries_, face)
			&& !font_face_object_array_contains(ordered_faces, face) {
			ordered_faces << face
		}
	}
	for face in set.set_entries_ {
		if face.is_css_connected() && !font_face_object_array_contains(ordered_faces, face) {
			ordered_faces << face
		}
	}
	for face in set.set_entries_ {
		if !face.is_css_connected() {
			ordered_faces << face
		}
	}

	mut order_changed := ordered_faces.len != set.set_entries_.len
	if !order_changed {
		for index, face in ordered_faces {
			if voidptr(face) != voidptr(set.set_entries_[index]) {
				order_changed = true
				break
			}
		}
	}
	if !order_changed {
		return
	}

	set.set_entries_ = ordered_faces
	for hooks in set.setlike_binding_hooks_ { hooks.did_reorder() }
	if mut computer := set.font_computer_ {
		computer.synchronize_font_face_order(set.set_entries_)
	}
}

// https://drafts.csswg.org/css-font-loading/#dom-fontfaceset-delete
pub fn (mut set FontFaceSet) delete_(face &FontFaceObject) bool {
	// 1. If font is CSS-connected, return false and exit this algorithm immediately.
	if face.is_css_connected() {
		return false
	}
	if face.should_be_registered_with_font_computer() {
		if mut computer := set.font_computer_ {
			computer.unregister_font_face(face)
		}
	}

	// 2. Let deleted be the result of removing font from the FontFaceSet's set entries.
	deleted := set.remove_set_entry(face)
	mut mutable_face := unsafe { &FontFaceObject(face) }
	mutable_face.remove_from_set(set)

	// 3. If font is present in the FontFaceSet's [[LoadedFonts]], or [[FailedFonts]] lists, remove it.
	set.loaded_fonts_ = font_face_object_array_without(set.loaded_fonts_, face)
	set.failed_fonts_ = font_face_object_array_without(set.failed_fonts_, face)

	// 4. If font is present in the FontFaceSet's [[LoadingFonts]] list, remove it.
	//    If font was the last item in that list (and so the list is now empty), switch the FontFaceSet to loaded.
	was_in_loading_fonts := font_face_object_array_contains(set.loading_fonts_, face)
	set.loading_fonts_ = font_face_object_array_without(set.loading_fonts_, face)
	if was_in_loading_fonts && set.loading_fonts_.len == 0 {
		set.switch_to_loaded()
	}

	return deleted
}

// https://drafts.csswg.org/css-font-loading/#dom-fontfaceset-clear
pub fn (mut set FontFaceSet) clear() {
	// 1. Remove all non-CSS-connected items from the FontFaceSet's set entries,
	//    its [[LoadedFonts]] list, and its [[FailedFonts]] list.
	mut kept_entries := []&FontFaceObject{}
	for face in set.set_entries_ {
		if face.is_css_connected() {
			kept_entries << face
		} else {
			if face.should_be_registered_with_font_computer() {
				if mut computer := set.font_computer_ {
					computer.unregister_font_face(face)
				}
			}
			mut mutable_face := unsafe { &FontFaceObject(face) }
			mutable_face.remove_from_set(set)
			for hooks in set.setlike_binding_hooks_ { hooks.did_remove(face) }
		}
	}
	set.set_entries_ = kept_entries
	set.loaded_fonts_ = set.loaded_fonts_.filter(it.is_css_connected())
	set.failed_fonts_ = set.failed_fonts_.filter(it.is_css_connected())

	// 2. If the FontFaceSet's [[LoadingFonts]] list is non-empty, remove all items from it,
	//    then switch the FontFaceSet to loaded.
	if set.loading_fonts_.len != 0 {
		set.loading_fonts_.clear()
		set.switch_to_loaded()
	}
}

// https://drafts.csswg.org/css-font-loading/#find-the-matching-font-faces
fn find_matching_font_faces(font_face_set &FontFaceSet, font string, text string) ![]&FontFaceObject {
	// 1. Parse font using the CSS value syntax of the font property. If a syntax error occurs, return a syntax error.
	font_family_list := parse_font_shorthand_family_list(font) or {
		return error('SyntaxError: Unable to parse font')
	}

	// FIXME: Absolutize all relative lengths against the initial values of the corresponding properties. (For example, a
	//        relative font weight like bolder is evaluated against the initial value normal.)
	// FIXME: 2. If text was not explicitly provided, let it be a string containing a single space character (U+0020 SPACE).

	// 4. Let available font faces be the available font faces within source. If the allow system fonts flag is specified,
	//    add all system fonts to available font faces.
	available_font_faces := font_face_set.set_entries()

	// 5. Let matched font faces initially be an empty list.
	mut matched_font_faces := []&FontFaceObject{}

	// 6. For each family in font family list, use the font matching rules to select the font faces from available font
	//    faces that match the font style, and add them to matched font faces. The use of the unicodeRange attribute means
	//    that this may be more than just a single font face.
	for font_family in font_family_list {
		if is_generic_font_family(font_family) {
			continue
		}
		for font_face in available_font_faces {
			if font_face.family() != font_family {
				continue
			}
			if !font_face_object_array_contains(matched_font_faces, font_face) {
				matched_font_faces << font_face
			}
		}
	}

	// FIXME: 7. If matched font faces is empty, set the found faces flag to false. Otherwise, set it to true.

	// 8. Remove faces whose unicode-range does not contain any code point in text.
	mut matching_text_faces := []&FontFaceObject{}
	for font_face in matched_font_faces {
		mut includes_text_code_point := false
		for code_point in text.runes() {
			for unicode_range in font_face.unicode_ranges_ {
				if unicode_range.start <= u32(code_point) && u32(code_point) <= unicode_range.end {
					includes_text_code_point = true
					break
				}
			}
			if includes_text_code_point {
				break
			}
		}
		if includes_text_code_point {
			matching_text_faces << font_face
		}
	}

	// 9. Return matched font faces and the found faces flag.
	return matching_text_faces
}

// https://drafts.csswg.org/css-font-loading/#dom-fontfaceset-load
pub fn (mut set FontFaceSet) load(font string, text_arguments ...string) !&webidl.Promise {
	// 1. Let font face set be the FontFaceSet object this method was called on. Let promise be a newly-created promise object.
	promise := webidl.create_promise_for(font_loading_promise_context(set.font_computer_))
	text := if text_arguments.len > 0 { text_arguments[0] } else { ' ' }
	set_handle := voidptr(&set)
	defer_font_loading_steps(set.font_computer_, fn [set_handle, promise, font, text] () {
		mut deferred_set := unsafe { &FontFaceSet(set_handle) }
		deferred_set.load_deferred(promise, font, text)
	})
	// 2. Return promise. Complete the rest of these steps asynchronously.
	return promise
}

fn (mut set FontFaceSet) load_deferred(promise &webidl.Promise, font string, text string) {

	// 3. Find the matching font faces from font face set using the font and text arguments passed to the function,
	//    and let font face list be the return value (ignoring the found faces flag). If a syntax error was returned,
	//    reject promise with a SyntaxError exception and terminate these steps.
	matched_font_faces := find_matching_font_faces(set, font, text) or {
		mut rejected := unsafe { &webidl.Promise(promise) }
		rejected.reject(webidl.dom_exception_value(webidl.DOMException.create('SyntaxError', err.msg())))
		return
	}

	// 4. Queue a task to run the following steps synchronously:
	queue_font_loading_task(set.font_computer_, false, fn [promise, matched_font_faces] () {
		// 1. For all of the font faces in the font face list, call their load() method.
		mut promises := []&webidl.Promise{cap: matched_font_faces.len}
		for font_face in matched_font_faces {
			mut mutable_font_face := unsafe { &FontFaceObject(font_face) }
			mutable_font_face.load()
			promises << font_face.loaded()
		}

		// 2. Resolve promise with the result of waiting for all of the [[FontStatusPromise]]s of each font face in
		//    the font face list, in order.
		webidl.wait_for_all(promises, fn [promise, matched_font_faces] (_ []webidl.Value) {
			// The source binding resolves with the matched FontFaces themselves,
			// preserving their identity and order, rather than the promise values.
			mut fonts := []webidl.Value{cap: matched_font_faces.len}
			for face in matched_font_faces {
				fonts << webidl.platform_object_value_with_id(u64(voidptr(face)))
			}
			mut resolved := unsafe { &webidl.Promise(promise) }
			resolved.resolve(webidl.sequence_value(fonts))
		}, fn [promise] (reason webidl.Value) {
			mut rejected := unsafe { &webidl.Promise(promise) }
			rejected.reject(reason)
		})
	})
}

// https://drafts.csswg.org/css-font-loading/#dom-fontfaceset-check
pub fn (set &FontFaceSet) check(font string, text_arguments ...string) !bool {
	// Find matching FontFace entries without initiating a load. System fonts are
	// represented by an empty result in this translation boundary and therefore
	// satisfy the check immediately.
	text := if text_arguments.len > 0 { text_arguments[0] } else { ' ' }
	matched_font_faces := find_matching_font_faces(set, font, text)!
	for font_face in matched_font_faces {
		if font_face.status() != .loaded {
			return false
		}
	}
	return true
}

// https://drafts.csswg.org/css-font-loading/#font-face-set-ready
pub fn (set &FontFaceSet) ready() &webidl.Promise {
	if set.ready_promise.state == .fulfilled {
		if computer := set.font_computer_ {
			if document := computer.document_ {
				mut owner := unsafe { &dom.Document(document) }
				owner.update_layout(.font_face_set_ready)
			}
		}
	}
	return set.ready_promise
}

pub fn (set &FontFaceSet) status() FontFaceSetLoadStatus {
	return set.status_
}

// https://drafts.csswg.org/css-font-loading/#fire-a-font-load-event
pub fn (mut set FontFaceSet) fire_a_font_load_event(name string, font_faces []&FontFaceObject) {
	// To fire a font load event named e at a FontFaceSet target with optional font faces means to fire a simple
	// event named e using the FontFaceSetLoadEvent interface that also meets these conditions:
	// 1. The fontfaces attribute is initialized to the result of filtering font faces to only contain FontFace
	//    objects contained in target.
	mut filtered := []&FontFaceObject{}
	for font_face in font_faces {
		if font_face_object_array_contains(set.set_entries_, font_face) {
			filtered << font_face
		}
	}
	set.fired_events << FontFaceSetLoadEventRecord{
		name: name
		fontfaces: filtered
	}
	event := FontFaceSetLoadEvent.create_for_fonts(name, filtered, font_loading_event_time_stamp(set.font_computer_))
	dom.event_target_dispatch_event(set.event_target(), event.base_event())
}

// https://drafts.csswg.org/css-font-loading/#ref-for-fontfaceset-pending-on-the-environment
pub fn (mut set FontFaceSet) set_is_pending_on_the_environment(is_pending_on_the_environment bool) {
	if is_pending_on_the_environment == set.is_pending_on_the_environment {
		return
	}
	set.is_pending_on_the_environment = is_pending_on_the_environment

	// Whenever a FontFaceSet goes from pending on the environment to not pending on the environment, the user agent
	// must run the following steps:
	if !is_pending_on_the_environment {
		// 1. If the FontFaceSet is stuck on the environment and its [[LoadingFonts]] list is empty, switch the
		//    FontFaceSet to loaded.
		// FIXME: We also need to mark empty FontFaceSets as loaded, so that the [[ReadyPromise]] gets resolved.
		//        Spec issue: https://github.com/w3c/csswg-drafts/issues/13538#issuecomment-3933951987
		if set.set_entries_.len == 0
			|| (set.is_stuck_on_the_environment && set.loading_fonts_.len == 0) {
			set.switch_to_loaded()
		} else if set.loading_fonts_.len == 0 {
			// A set containing only deferred unicode-range faces never entered the
			// loading list, but its ready promise must still settle.
			set.switch_to_loaded()
		}

		// 2. If the FontFaceSet is stuck on the environment, unmark it as such.
		set.is_stuck_on_the_environment = false
	}
}

// https://drafts.csswg.org/css-font-loading/#switch-the-fontfaceset-to-loading
pub fn (mut set FontFaceSet) switch_to_loading() {
	// 1. Let font face set be the given FontFaceSet.
	// 2. Set the status attribute of font face set to "loading".
	set.status_ = .loading

	// 3. If font face set's [[ReadyPromise]] slot currently holds a fulfilled promise, replace it with a fresh pending
	//    promise.
	if set.ready_promise.state == .fulfilled {
		set.ready_promise = webidl.create_promise_for(font_loading_promise_context(set.font_computer_))
	}

	// 4. Queue a task to fire a font load event named loading at font face set.
	set_pointer := unsafe { &FontFaceSet(set) }
	queue_font_loading_task(set.font_computer_, false, fn [set_pointer] () {
		mut mutable_set := unsafe { &FontFaceSet(set_pointer) }
		mutable_set.fire_a_font_load_event('loading', [])
	})
}

// https://drafts.csswg.org/css-font-loading/#switch-the-fontfaceset-to-loaded
pub fn (mut set FontFaceSet) switch_to_loaded() {
	// 1. Let font face set be the given FontFaceSet.
	// 2. If font face set is pending on the environment, mark it as stuck on the environment, and exit this algorithm.
	if set.is_pending_on_the_environment {
		set.is_stuck_on_the_environment = true
		return
	}

	if computer := set.font_computer_ {
		if document := computer.document_ {
			mut owner := unsafe { &dom.Document(document) }
			if !owner.is_running_update_layout() {
				owner.update_layout(.font_face_set_ready)
			}
		}
	}
	if set.loading_fonts_.len != 0 {
		return
	}
	mut context_document := ?&dom.Document(none)
	mut context_handle := voidptr(0)
	if computer := set.font_computer_ {
		if document := computer.document_ {
			context_document = document
			context_handle = document.begin_temporary_execution_context()
		}
	}
	defer {
		if document := context_document {
			document.end_temporary_execution_context(context_handle)
		}
	}

	// 3. Set font face set's status attribute to "loaded".
	set.status_ = .loaded

	// 4. Fulfill font face set's [[ReadyPromise]] attribute's value with font face set.
	set.ready_promise.resolve(webidl.Value{ kind: .platform_object, opaque_id: u64(voidptr(&set)), platform_interfaces: ['FontFaceSet'] })

	// 5. Queue a task to perform the following steps synchronously:
	set_pointer := unsafe { &FontFaceSet(set) }
	queue_font_loading_task(set.font_computer_, false, fn [set_pointer] () {
		mut mutable_set := unsafe { &FontFaceSet(set_pointer) }
		mutable_set.dispatch_loaded_events()
	})
}

fn (mut set FontFaceSet) dispatch_loaded_events() {
	// 1. Let loaded fonts be the (possibly empty) contents of font face set's [[LoadedFonts]] slot.
	// 2. Let failed fonts be the (possibly empty) contents of font face set's [[FailedFonts]] slot.
	// 3. Reset the [[LoadedFonts]] and [[FailedFonts]] slots to empty lists.
	loaded_fonts := set.loaded_fonts_.clone()
	failed_fonts := set.failed_fonts_.clone()
	set.loaded_fonts_.clear()
	set.failed_fonts_.clear()

	// 4. Fire a font load event named loadingdone at font face set with loaded fonts.
	set.fire_a_font_load_event('loadingdone', loaded_fonts)

	// 5. If font face set's failed fonts is non-empty, fire a font load event named loadingerror at font face set
	//    with failed fonts.
	if failed_fonts.len != 0 {
		set.fire_a_font_load_event('loadingerror', failed_fonts)
	}
}

fn (mut set FontFaceSet) remove_loading_font(face &FontFaceObject) {
	set.loading_fonts_ = font_face_object_array_without(set.loading_fonts_, face)
}

fn (mut set FontFaceSet) remove_set_entry(face &FontFaceObject) bool {
	mut did_remove := false
	mut kept := []&FontFaceObject{}
	for existing in set.set_entries_ {
		if existing == face {
			did_remove = true
			continue
		}
		kept << existing
	}
	set.set_entries_ = kept
	if did_remove { for hooks in set.setlike_binding_hooks_ { hooks.did_remove(face) } }
	return did_remove
}

// --- FontComputer and FontLoader ---

pub enum FontOpticalSizing {
	auto_
	none_
}

@[heap]
pub struct PlatformTypeface {
pub mut:
	family_name string
	weight_     int = 400
	width_      int = 100
	slope_      int
	source_path string
}

pub struct PlatformFont {
pub mut:
	typeface     &PlatformTypeface = unsafe { nil }
	point_size f32
	variations FontVariationSettings
	features   ShapeFeatures
	is_invisible bool
	font_rendering_policy platform.FontRenderingPolicy
	italic bool
	font_synthesis_disabled u8
mut:
	metrics_font_ &platform.Font = unsafe { nil }
	native_variations_ FontVariationSettings
	pixel_size_override_ ?f32
}

// CSS metrics queries must reuse the native handle: its decoded face and
// pixel metrics are cached on that handle. The translated font records remain
// mutable, so validate every input consumed by this metrics bridge first.
fn (font &PlatformFont) font_for_metrics() &platform.Font {
	return font.font_for_rendering()
}

// The native handle is immutable and can be shared by metrics, text iterators
// and retained layout nodes. Revalidate the mutable CSS inputs before reuse.
pub fn (font &PlatformFont) font_for_rendering() &platform.Font {
	cached := font.metrics_font_
	if font.matches_native_font(cached) {
		return cached
	}
	// The handle is cached on a font that outlives any arena entered by the
	// caller, such as keyframe sampling.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	native_font := &platform.Font{
		family: font.typeface.family_name.clone()
		point_size: font.pixel_size_override_ or { font.point_size / 0.75 }
		weight: int(font.variations.weight)
		italic: font.italic
		font_synthesis_disabled: font.font_synthesis_disabled
		source_path: font.typeface.source_path.clone()
		requested_variations: if font.typeface.source_path == '' { []platform.FontVariationAxis{} } else { font.variations.native_axes() }
		is_invisible: font.is_invisible
		font_rendering_policy: font.font_rendering_policy
	}
	mut mutable_font := unsafe { &PlatformFont(font) }
	mutable_font.metrics_font_ = native_font
	mutable_font.native_variations_ = font.variations.owned_clone()
	return native_font
}

fn (font &PlatformFont) matches_native_font(cached &platform.Font) bool {
	return cached != unsafe { nil } && cached.family == font.typeface.family_name
		&& cached.point_size == (font.pixel_size_override_ or { font.point_size / 0.75 })
		&& cached.weight == int(font.variations.weight)
		&& cached.italic == font.italic
		&& cached.font_synthesis_disabled == font.font_synthesis_disabled
		&& cached.source_path == font.typeface.source_path
		&& cached.is_invisible == font.is_invisible
		&& cached.font_rendering_policy == font.font_rendering_policy
		&& (font.typeface.source_path == '' || (font.native_variations_.weight == font.variations.weight
			&& font.native_variations_.width == font.variations.width
			&& font.native_variations_.opsz == font.variations.opsz
			&& font.native_variations_.axis_values_equal(font.variations)))
}

fn owned_platform_typeface(typeface &PlatformTypeface) &PlatformTypeface {
	// PlatformTypeface is immutable after construction and heap-backed. Retain
	// its identity through cascades; copying its string-bearing value under the
	// old backend can release storage still referenced by another cascade.
	return typeface
}

fn owned_shape_features(features ShapeFeatures) ShapeFeatures {
	// The new array owns its feature records. Immutable tag strings keep their
	// backing storage reachable through each copied record without another copy.
	mut result := ShapeFeatures{ cap: features.len }
	for feature in features {
		result << ShapeFeature{
			tag:   feature.tag
			value: feature.value
		}
	}
	return result
}

fn owned_platform_font(font &PlatformFont) PlatformFont {
	return PlatformFont{
		typeface:     owned_platform_typeface(font.typeface)
		point_size:   font.point_size
		variations:   font.variations.owned_clone()
		features:     owned_shape_features(font.features)
		is_invisible: font.is_invisible
		font_rendering_policy: font.font_rendering_policy
		italic: font.italic
		font_synthesis_disabled: font.font_synthesis_disabled
		pixel_size_override_: font.pixel_size_override_
		// An input mutation replaces the clone's cache on its next lookup; the
		// immutable old handle remains valid for previously retained fragments.
		metrics_font_: if font.matches_native_font(font.metrics_font_) { font.metrics_font_ } else { unsafe { &platform.Font(nil) } }
		native_variations_: font.native_variations_.owned_clone()
	}
}

fn owned_platform_font_ref(font &PlatformFont) &PlatformFont {
	working_copy := owned_platform_font(font)
	return &working_copy
}

pub enum PendingFontState {
	invisible
	visible
	failed
}

pub struct FontCascadeEntry {
pub:
	font           PlatformFont
	unicode_ranges []UnicodeRange
}

pub struct PendingFontFace {
pub:
	font_index     int
	unicode_ranges []UnicodeRange
	font_face      &FontFaceObject = unsafe { nil }
}

@[heap]
struct FontCascadeInvisibleStorage {
mut:
	values map[string]&PlatformFont
}

@[heap]
pub struct FontCascadeList {
pub mut:
	fonts            []FontCascadeEntry
	pending_faces    []PendingFontFace
	last_resort_font &PlatformFont = unsafe { nil }
mut:
	invisible_font_storage_ &FontCascadeInvisibleStorage = unsafe { nil }
	device_layout_font_projection_ &FontCascadeList = unsafe { nil }
}

pub fn FontCascadeList.create() &FontCascadeList {
	return &FontCascadeList{}
}

fn (list &FontCascadeList) cached_invisible_font(key string) ?&PlatformFont {
	if list.invisible_font_storage_ == unsafe { nil } {
		return none
	}
	return list.invisible_font_storage_.values[key] or { return none }
}

fn (mut list FontCascadeList) ensure_invisible_font_storage() &FontCascadeInvisibleStorage {
	if list.invisible_font_storage_ == unsafe { nil } {
		list.invisible_font_storage_ = &FontCascadeInvisibleStorage{
			values: map[string]&PlatformFont{}
		}
	}
	return list.invisible_font_storage_
}

pub fn (mut list FontCascadeList) add(font PlatformFont, unicode_ranges []UnicodeRange) {
	list.fonts << FontCascadeEntry{
		font:           owned_platform_font(&font)
		unicode_ranges: unicode_ranges.clone()
	}
}

pub fn (mut list FontCascadeList) extend(other &FontCascadeList) {
	font_offset := list.fonts.len
	for entry in other.fonts {
		list.add(entry.font, entry.unicode_ranges)
	}
	for pending_face in other.pending_faces {
		list.pending_faces << PendingFontFace{
			font_index: font_offset + pending_face.font_index
			unicode_ranges: pending_face.unicode_ranges.clone()
			font_face: pending_face.font_face
		}
	}
	if other.last_resort_font != unsafe { nil } {
		list.last_resort_font = other.last_resort_font
	}
}

pub fn (list &FontCascadeList) is_empty() bool {
	return list.fonts.len == 0 && list.pending_faces.len == 0
		&& list.last_resort_font == unsafe { nil }
}

fn (list &FontCascadeList) depends_on_pending_face(face &FontFaceObject) bool {
	for pending in list.pending_faces {
		if voidptr(pending.font_face) == voidptr(face) { return true }
	}
	return false
}

pub fn (mut list FontCascadeList) add_pending_face(font_face &FontFaceObject) {
	if font_face.unicode_ranges_.len == 0 {
		return
	}
	list.pending_faces << PendingFontFace{
		font_index: list.fonts.len
		unicode_ranges: font_face.unicode_ranges_.clone()
		font_face: font_face
	}
}

fn pending_face_covers(pending_face PendingFontFace, code_point u32) bool {
	for unicode_range in pending_face.unicode_ranges {
		if unicode_range.start <= code_point && code_point <= unicode_range.end {
			return true
		}
	}
	return false
}

fn platform_font_equals(left PlatformFont, right PlatformFont) bool {
	return left.typeface.family_name == right.typeface.family_name
		&& left.typeface.source_path == right.typeface.source_path
		&& left.typeface.weight_ == right.typeface.weight_
		&& left.typeface.width_ == right.typeface.width_
		&& left.typeface.slope_ == right.typeface.slope_
		&& left.point_size == right.point_size
		&& left.variations.weight == right.variations.weight
		&& left.variations.width == right.variations.width
		&& left.variations.opsz == right.variations.opsz
		&& left.variations.axis_values_equal(&right.variations) && left.features == right.features
		&& left.is_invisible == right.is_invisible
		&& left.italic == right.italic
		&& left.font_synthesis_disabled == right.font_synthesis_disabled
}

pub fn (list &FontCascadeList) equals(other &FontCascadeList) bool {
	if list.pending_faces.len != 0 || other.pending_faces.len != 0 {
		return false
	}
	if list.fonts.len != other.fonts.len {
		return false
	}
	for index, entry in list.fonts {
		other_entry := other.fonts[index]
		if entry.unicode_ranges != other_entry.unicode_ranges
			|| !platform_font_equals(entry.font, other_entry.font) {
			return false
		}
	}
	if list.last_resort_font != unsafe { nil } {
		return other.last_resort_font != unsafe { nil }
			&& platform_font_equals(*list.last_resort_font, *other.last_resort_font)
	}
	return other.last_resort_font == unsafe { nil }
}

pub fn (mut list FontCascadeList) set_last_resort_font(font PlatformFont) {
	list.last_resort_font = owned_platform_font_ref(&font)
}

struct PendingFontResolution {
mut:
	pending_index          int
	rendering_with_fallback bool
	invisible              bool
}

fn (mut list FontCascadeList) resolve_pending_faces(code_point u32, through_font_index int, current PendingFontResolution) PendingFontResolution {
	mut result := current
	for !result.rendering_with_fallback && result.pending_index < list.pending_faces.len
		&& list.pending_faces[result.pending_index].font_index <= through_font_index {
		pending_face := list.pending_faces[result.pending_index]
		result.pending_index++
		if !pending_face_covers(pending_face, code_point) {
			continue
		}
		mut face := unsafe { &FontFaceObject(pending_face.font_face) }
		state := face.resolve_for_rendering()
		if state == .failed {
			continue
		}
		result.invisible = state == .invisible
		result.rendering_with_fallback = true
	}
	return result
}

fn platform_font_cache_key(font &PlatformFont) string {
	return '${font.typeface.family_name}|${font.typeface.source_path}|${font.typeface.weight_}|${font.typeface.width_}|${font.typeface.slope_}|${font.point_size}|${font.variations.weight}|${font.variations.width}|${font.variations.opsz}|${font.font_rendering_policy}|${font.pixel_size_override_}|${font.italic}|${font.font_synthesis_disabled}'
}

fn (list &FontCascadeList) font_with_visibility(font &PlatformFont, invisible bool) &PlatformFont {
	if !invisible {
		return unsafe { font }
	}
	mut mutable_list := unsafe { &FontCascadeList(list) }
	key := platform_font_cache_key(font)
	if cached := mutable_list.cached_invisible_font(key) {
		return cached
	}
	variant := &PlatformFont{
		typeface:     owned_platform_typeface(font.typeface)
		point_size: font.point_size
		variations:   font.variations.owned_clone()
		features:     owned_shape_features(font.features)
		is_invisible: true
		font_rendering_policy: font.font_rendering_policy
		italic: font.italic
		font_synthesis_disabled: font.font_synthesis_disabled
		pixel_size_override_: font.pixel_size_override_
	}
	mut storage := mutable_list.ensure_invisible_font_storage()
	storage.values[key] = variant
	return variant
}

fn (list &FontCascadeList) font_for_code_point_internal(code_point u32, trigger_pending_loads bool) &PlatformFont {
	mut resolution := PendingFontResolution{}
	mut mutable_list := unsafe { &FontCascadeList(list) }
	for index, entry in list.fonts {
		if trigger_pending_loads {
			resolution = mutable_list.resolve_pending_faces(code_point, index, resolution)
		}
		if entry.unicode_ranges.len == 0 {
			return list.font_with_visibility(unsafe { &list.fonts[index].font }, resolution.invisible)
		}
		for unicode_range in entry.unicode_ranges {
			if unicode_range.start <= code_point && code_point <= unicode_range.end {
				return list.font_with_visibility(unsafe { &list.fonts[index].font }, resolution.invisible)
			}
		}
	}
	if trigger_pending_loads {
		resolution = mutable_list.resolve_pending_faces(code_point, list.fonts.len, resolution)
	}
	if list.last_resort_font != unsafe { nil } {
		return list.font_with_visibility(list.last_resort_font, resolution.invisible)
	}
	panic('FontCascadeList must contain a font or a last-resort font')
}

// Gfx::FontCascadeList::font_for_code_point(). An empty unicode-range means
// that the face covers the full Unicode range for cascade selection. Probes do
// not start pending downloads; only the shaping entry point below does.
pub fn (list &FontCascadeList) font_for_code_point(code_point u32) &PlatformFont {
	return list.font_for_code_point_internal(code_point, false)
}

pub fn (list &FontCascadeList) font_for_code_point_for_shaping(code_point u32) &PlatformFont {
	return list.font_for_code_point_internal(code_point, true)
}

// Layout performs the concrete platform glyph-coverage check. Resolve only the
// pending author faces which precede that selected fallback in cascade order.
pub fn (list &FontCascadeList) fallback_is_invisible_for_code_point_through(code_point u32, font_index int) bool {
	mut mutable_list := unsafe { &FontCascadeList(list) }
	resolution := mutable_list.resolve_pending_faces(code_point, font_index, PendingFontResolution{})
	return resolution.invisible
}

pub struct FontVariationSettings {
pub mut:
	weight f64 = 400
	width  f64 = 100
	opsz   ?f64
mut:
	axis_storage_ &FontVariationAxisStorage = unsafe { nil }
}

pub struct FontFaceKey {
pub mut:
	family_name string
	weight      FontWeightRange
	slope       int
	width       int = 100
}

pub fn (weight FontWeightRange) id() string {
	return '${weight.min}-${weight.max}'
}

pub fn (key FontFaceKey) id() string {
	return '${key.family_name.to_lower()}|${key.weight.id()}|${key.slope}|${key.width}'
}

pub struct OwnFontFaceKey {
pub mut:
	family_name string
	weight      FontWeightRange
	slope       int
	width       int = 100
}

pub fn OwnFontFaceKey.from_font_face_key(other FontFaceKey) OwnFontFaceKey {
	return OwnFontFaceKey{
		family_name: other.family_name
		weight: other.weight
		slope: other.slope
		width: other.width
	}
}

pub fn (key OwnFontFaceKey) as_font_face_key() FontFaceKey {
	return FontFaceKey{
		family_name: key.family_name
		weight: key.weight
		slope: key.slope
		width: key.width
	}
}

pub fn (key OwnFontFaceKey) id() string {
	return key.as_font_face_key().id()
}

fn font_face_key_for_parsed_font_face(font_face ParsedFontFace) FontFaceKey {
	return FontFaceKey{
		family_name: font_face.font_family()
		weight: font_face.weight() or {
			FontWeightRange{
				min: 0
				max: 0
			}
		}
		slope: font_face.slope() or { 0 }
		width: font_face.width() or { 100 }
	}
}

pub struct ComputedFontCacheKey {
pub mut:
	font_family             []string
	font_optical_sizing     FontOpticalSizing
	font_size               CSSPixels
	font_slope              int
	font_weight             f64
	font_width              Percentage
	font_variation_settings map[string]f64
	font_feature_data       FontFeatureData
	font_synthesis_disabled u8
}

pub fn (key ComputedFontCacheKey) id() string {
	mut builder := strings.new_builder(64)
	builder.write_string(key.font_family.join(','))
	builder.write_string('|${key.font_optical_sizing}|${key.font_size.raw_value()}|${key.font_slope}|${key.font_weight}|${key.font_width.value()}')
	if key.font_synthesis_disabled != 0 { builder.write_string('|synthesis:${key.font_synthesis_disabled}') }
	for name, value in key.font_variation_settings {
		builder.write_string('|${name}:${value}')
	}
	for name, value in key.font_feature_data.font_feature_settings {
		builder.write_string('|${name}:${value}')
	}
	return builder.str()
}

fn computed_font_cache_key_references_family(cache_key string, family_name string) bool {
	if family_name.len == 0 {
		return false
	}
	font_family_end := cache_key.index_u8(`|`)
	font_family_part := if font_family_end < 0 { cache_key } else { cache_key[..font_family_end] }
	for family in split_css_comma_list(font_family_part) {
		if unquote_css_string(family).to_lower() == family_name.to_lower() {
			return true
		}
	}
	return false
}

@[heap]
pub struct FontLoader {
pub mut:
	font_computer   &FontComputer = unsafe { nil }
	family_name_    string
	unicode_ranges_ []UnicodeRange
	typeface                &PlatformTypeface = unsafe { nil }
	urls            []URL
	subscribers             []fn (&PlatformTypeface)
	has_completed   bool
	has_started_request_ bool
	has_received_font_data_ bool
	requires_network_ bool
	fetch_controller_ ?&fetch.FetchController
	rule_or_declaration_ RuleOrDeclaration
	document_load_event_delayer_ ?dom.DocumentLoadEventDelayer
}

pub fn FontLoader.create(font_computer &FontComputer, family_name string, unicode_ranges []UnicodeRange, urls []URL, on_load ?fn (&PlatformTypeface)) &FontLoader {
	mut loader := &FontLoader{
		font_computer: font_computer
		family_name_: family_name
		unicode_ranges_: unicode_ranges.clone()
		urls: urls.clone()
		rule_or_declaration_: font_rule_or_declaration(font_computer, none)
	}
	if callback := on_load {
		loader.subscribers << callback
	}
	return loader
}

pub fn (mut loader FontLoader) subscribe(callback fn (&PlatformTypeface)) {
	if loader.has_completed {
		callback(loader.typeface)
		return
	}
	loader.subscribers << callback
}

pub fn (loader &FontLoader) unicode_ranges() []UnicodeRange {
	return loader.unicode_ranges_
}

pub fn (mut loader FontLoader) font_with_point_size(point_size f32, variations FontVariationSettings, shape_features ShapeFeatures) ?PlatformFont {
	if loader.typeface == unsafe { nil } {
		if loader.urls.len != 0 {
			loader.start_loading_next_url()
		}
		// The V file-resource boundary completes synchronously. Consume its
		// result now; network-backed loading still returns none here.
		if loader.typeface == unsafe { nil } {
			return none
		}
	}
	return PlatformFont{
		typeface:   loader.typeface
		point_size: point_size
		variations: variations.owned_clone()
		features:   owned_shape_features(shape_features)
	}
}

pub fn (mut loader FontLoader) start_loading_next_url() {
	// FontComputer can return a shared loader after its first subscriber has
	// settled. Its typeface is final; do not consume another fallback URL.
	if loader.has_completed {
		return
	}
	// FIXME: Load local() fonts somehow.
	if controller := loader.fetch_controller_ {
		if controller.state() == .ongoing { return }
	}
	if loader.urls.len == 0 {
		return
	}

	// https://drafts.csswg.org/css-fonts-4/#fetch-a-font
	// To fetch a font given a selected <url> url for @font-face rule, fetch url, with ruleOrDeclaration being rule,
	// destination "font", CORS mode "cors", and processResponse being the following steps given response res and null,
	// failure or a byte stream stream:
	url := loader.urls[0]
	loader.urls.delete(0)
	loader.has_received_font_data_ = false
	if host := loader.font_computer.font_fetch_host() {
		loader_handle := voidptr(&loader)
		loader.fetch_controller_ = fetch_a_style_resource(url, loader.rule_or_declaration_, .font, .cors,
			fn [loader_handle] (response &fetch.Response, body fetch.BodyBytes) {
				mut current := unsafe { &FontLoader(loader_handle) }
				if body.kind != .bytes {
					current.try_next_url_or_fail()
					return
				}
				current.has_received_font_data_ = true
				mime := current.try_load_font_mime_type_essence(response, body.bytes)
				if requires_off_thread_vector_font_preparation(body.bytes, mime) {
					if prepare_vector_font_data_for_computer(body.bytes,
						fn [loader_handle] (prepared PreparedVectorFontData) {
							mut owner := unsafe { &FontLoader(loader_handle) }
							if prepared.error_message != none {
								owner.try_next_url_or_fail()
								return
							}
							typeface := font_typeface_from_prepared_bytes(prepared.data, owner.family_name_) or {
								owner.try_next_url_or_fail()
								return
							}
							owner.font_did_load_or_fail(typeface)
						}, current.font_computer) {
						return
					}
				}
				typeface := current.try_load_font(response, body.bytes) or {
					current.try_next_url_or_fail()
					return
				}
				current.font_did_load_or_fail(typeface)
			}, host)
		if loader.fetch_controller_ == none { loader.font_did_load_or_fail(unsafe { nil }) }
		return
	}
	// Frozen standalone callers without an installed RequestServer retain the
	// file-font adapter. Document/native callers use the Fetch path above.
	loader.has_started_request_ = true
	loader.requires_network_ = !url.url().starts_with('file:')

	typeface := platform_load_font_from_url_boundary(url.url(), loader.family_name_)
	if typeface != unsafe { nil } {
		loader.has_received_font_data_ = true
	}
	if typeface == unsafe { nil } && loader.urls.len != 0 {
		loader.start_loading_next_url()
		return
	}
	loader.font_did_load_or_fail(typeface)
}

fn (mut loader FontLoader) try_next_url_or_fail() {
	if loader.urls.len == 0 {
		loader.font_did_load_or_fail(unsafe { nil })
	} else {
		loader.fetch_controller_ = none
		loader.start_loading_next_url()
	}
}

pub fn (loader &FontLoader) is_loading() bool {
	if loader.fetch_controller_ != none {
		return loader.typeface == unsafe { nil }
	}
	return loader.urls.len != 0 && loader.typeface == unsafe { nil }
}

pub fn (mut loader FontLoader) did_request_for_rendering() {
	if loader.is_loading() && loader.document_load_event_delayer_ == none {
		if document := loader.font_computer.document_ {
			mut mutable_document := unsafe { &dom.Document(document) }
			loader.document_load_event_delayer_ = dom.DocumentLoadEventDelayer.new(mut mutable_document)
		}
	}
}

pub fn (loader &FontLoader) may_finish_from_cache() bool {
	if controller := loader.fetch_controller_ { return !controller.requires_network() }
	return !loader.has_started_request_ || !loader.requires_network_
}

pub fn (loader &FontLoader) has_started_request() bool {
	if controller := loader.fetch_controller_ { return controller.has_started_request() }
	return loader.has_started_request_
}

pub fn (loader &FontLoader) family_name() string {
	return loader.family_name_
}

pub fn (loader &FontLoader) try_load_font(response &fetch.Response, bytes []u8) !&PlatformTypeface {
	mime := loader.try_load_font_mime_type_essence(response, bytes)
	if requires_off_thread_vector_font_preparation(bytes, mime) {
		return font_typeface_from_prepared_bytes(gfxfont.convert_woff2_to_sfnt(bytes)!, loader.family_name_)
	}
	return try_load_vector_font(bytes, mime, loader.family_name_)
}

pub fn (_ &FontLoader) try_load_font_mime_type_essence(response &fetch.Response, bytes []u8) ?string {
	if mime := fetch.extract_mime_type(response.header_list) {
		if mime.is_font() { return mime.essence() }
	}
	// Resource::sniff in the font context with no supplied MIME returns the
	// font-pattern match, including null when no font pattern matches.
	if mime := mimesniff.match_a_font_type_pattern(bytes) { return mime.essence() }
	return none
}

fn (mut loader FontLoader) font_did_load_or_fail(typeface &PlatformTypeface) {
	if typeface != unsafe { nil } {
		loader.typeface = owned_platform_typeface(typeface)
	}
	loader.has_completed = true
	for callback in loader.subscribers {
		callback(loader.typeface)
	}
	loader.subscribers.clear()
	// Subscribers enqueue the FontFace completion tasks. Release the load delay
	// on that same task source after those completions, so a parser check cannot
	// shape fallback text between transport completion and FontFace publication.
	if loader.document_load_event_delayer_ != none {
		loader_handle := voidptr(&loader)
		queue_font_loading_task(loader.font_computer, true, fn [loader_handle] () {
			mut owner := unsafe { &FontLoader(loader_handle) }
			if mut delayer := owner.document_load_event_delayer_ { delayer.finish() }
			owner.document_load_event_delayer_ = none
		})
	}
	loader.fetch_controller_ = none
}

struct MatchingFontCandidate {
	key              FontFaceKey
	width            int = 5
	font_faces       []&FontFaceObject
	typeface         &PlatformTypeface = unsafe { nil }
	is_platform_font bool
}

fn (mut candidate MatchingFontCandidate) font_with_point_size(point_size f32, variations FontVariationSettings, font_feature_data FontFeatureData, font_feature_values map[string][]u32) &FontCascadeList {
	shape_features := font_feature_data.to_shape_features(font_feature_values)

	if candidate.is_platform_font {
		if candidate.typeface == unsafe { nil } {
			return unsafe { nil }
		}
		mut font_list := FontCascadeList.create()
		font_list.add(PlatformFont{
			typeface:   candidate.typeface
			point_size: point_size
			variations: variations
			features: shape_features
		}, [])
		return font_list
	}

	mut font_list := FontCascadeList.create()
	for face in candidate.font_faces {
		face_fonts := face.font_with_point_size(point_size, variations, shape_features)
		if face_fonts != unsafe { nil } {
			font_list.extend(face_fonts)
		}
	}
	if font_list.is_empty() {
		return unsafe { nil }
	}
	return font_list
}

@[heap]
pub struct FontComputer {
pub mut:
	document_                 ?&dom.Document
	fetch_host_               ?&fetch.FetchHost
	font_faces                map[string][]&FontFaceObject
	loaders_by_url            map[string]&FontLoader
	computed_font_cache              map[string]&FontCascadeList
	font_feature_values_cache map[string]map[string][]u32
	font_feature_values_rules []&CSSFontFeatureValuesRule
	has_completed_initial_paint_ bool
	initial_paint_had_pending_fonts_ bool
	environment_generation_ u64 = 1
mut:
	environment_font_rendering_policy_ platform.FontRenderingPolicy
	// Internal font computation only reads these valid empty maps. Public
	// snapshot getters always construct their own independently mutable maps.
	normal_variation_settings_ map[string]f64
	normal_feature_settings_ map[string]u32
	font_key_scratch_ &platform.Arena = unsafe { nil }
	font_input_scratch_ &FontInputScratchPool = unsafe { nil }
}

pub fn FontComputer.create() &FontComputer {
	return &FontComputer{
		font_faces: map[string][]&FontFaceObject{}
		loaders_by_url: map[string]&FontLoader{}
		computed_font_cache:       map[string]&FontCascadeList{}
		font_feature_values_cache: map[string]map[string][]u32{}
	}
}

pub fn FontComputer.create_for_document(document &dom.Document) &FontComputer {
	mut computer := FontComputer.create()
	computer.document_ = document
	return computer
}

pub fn (mut computer FontComputer) add_font_feature_values_rule(rule &CSSFontFeatureValuesRule) {
	if !font_feature_values_rule_array_contains(computer.font_feature_values_rules, rule) {
		computer.font_feature_values_rules << rule
	}
	for family in rule.font_families() {
		computer.clear_computed_font_cache(family)
		computer.clear_font_feature_values_cache(family)
	}
}

pub fn (mut computer FontComputer) remove_font_feature_values_rule(rule &CSSFontFeatureValuesRule) {
	computer.font_feature_values_rules =
		font_feature_values_rule_array_without(computer.font_feature_values_rules, rule)
	for family in rule.font_families() {
		computer.clear_computed_font_cache(family)
		computer.clear_font_feature_values_cache(family)
	}
}

pub fn (computer &FontComputer) initial_font() PlatformFont {
	// FIXME: This is not correct.
	return platform_default_font_boundary(12, FontVariationSettings{}, ShapeFeatures{})
}

pub fn (mut computer FontComputer) clear_computed_font_cache(family_name string) {
	computer.environment_generation_++
	// Only clear cache entries that reference the loaded font family.
	mut kept := map[string]&FontCascadeList{}
	mut removed_referenced_family := false
	for key, value in computer.computed_font_cache {
		if computed_font_cache_key_references_family(key, family_name) {
			removed_referenced_family = true
		} else {
			kept[key] = value
		}
	}
	computer.computed_font_cache = kept.clone()

	if removed_referenced_family {
		if document := computer.document_ {
			mark_font_family_inputs_changed(document, family_name)
		}
	}
}

pub fn (mut computer FontComputer) did_load_font(family_name string) {
	computer.clear_computed_font_cache(family_name)
}

// The successful load of an existing face cannot change which weights,
// stretches or unicode ranges match it. Keep the cascades which never selected
// that pending face; descriptor and FontFaceSet changes still invalidate the
// complete family through register_font_face/unregister_font_face.
fn (mut computer FontComputer) publish_loaded_font_face(face &FontFaceObject) {
	if !face.should_be_registered_with_font_computer() { return }
	if disable_face_specific_font_completion {
		computer.register_font_face(face)
		return
	}
	key := font_face_key_for_parsed_font_face(face.parsed_font_face())
	faces := computer.font_faces[key.id()] or { []&FontFaceObject{} }
	if !font_face_object_array_contains(faces, face) {
		computer.register_font_face(face)
		return
	}
	computer.invalidate_selected_font_face_cascades(face, key.family_name, 'completion')
}

// Display-period changes and failed downloads change availability just as a
// successful completion does. Other weights and stretches never selected this
// pending face and keep their cascades. Unknown faces still use the family-wide
// path, as do matching/descriptor changes through register_font_face.
fn (mut computer FontComputer) invalidate_font_face_display(face &FontFaceObject) {
	key := font_face_key_for_parsed_font_face(face.parsed_font_face())
	faces := computer.font_faces[key.id()] or { []&FontFaceObject{} }
	if disable_face_specific_font_display || !font_face_object_array_contains(faces, face) {
		computer.did_load_font(face.family_)
		return
	}
	computer.invalidate_selected_font_face_cascades(face, key.family_name, 'display invalidation')
}

fn (mut computer FontComputer) invalidate_selected_font_face_cascades(face &FontFaceObject,
	family_name string, reason string) {
	computer.environment_generation_++
	mut affected := false
	mut expired := []string{}
	for cache_key, list in computer.computed_font_cache {
		if list.depends_on_pending_face(face) {
			expired << cache_key
			affected = true
		}
	}
	for cache_key in expired { computer.computed_font_cache.delete(cache_key) }
	if (reason == 'completion' && font_completion_diagnostics)
		|| (reason == 'display invalidation' && font_display_invalidation_diagnostics) {
		eprintln('Vox font ${reason}: family=${face.family_} weight=${face.weight_} expired=${expired.len} retained=${computer.computed_font_cache.len}')
	}
	if affected {
		if document := computer.document_ {
			if font_completion_diagnostics {
				if root := document.document_element() {
					if bridge := root.el_computed_properties() {
						if style := computed_properties_from_dom(bridge) {
								eprintln('Vox font completion root: safe=${style.font_input_refresh_safe_} size_relative=${style.font_input_depends_on_font_size_} affected=${retained_style_needs_changed_font_inputs(bridge, family_name, face)}')
						}
					}
				}
			}
			mark_changed_font_inputs(document, family_name, face)
		}
	}
}

pub fn (mut computer FontComputer) should_defer_initial_paint() bool {
	if computer.has_completed_initial_paint_ {
		return false
	}
	mut has_pending_fonts := false
	for _, faces in computer.font_faces {
		for face in faces {
			if face.is_pending_rendering_from_cache() {
				return true
			}
			has_pending_fonts = has_pending_fonts || face.has_pending_rendering()
		}
	}
	computer.initial_paint_had_pending_fonts_ = has_pending_fonts
	computer.has_completed_initial_paint_ = true
	return false
}

pub fn (computer &FontComputer) has_completed_initial_paint() bool {
	return computer.has_completed_initial_paint_
}

pub fn (computer &FontComputer) initial_paint_had_pending_fonts() bool {
	return computer.initial_paint_had_pending_fonts_
}

pub fn (computer &FontComputer) environment_generation() u64 {
	policy := computer.font_rendering_policy()
	if policy != computer.environment_font_rendering_policy_ {
		mut mutable := unsafe { &FontComputer(computer) }
		mutable.environment_font_rendering_policy_ = policy
		mutable.environment_generation_++
	}
	return computer.environment_generation_
}

pub fn (mut computer FontComputer) register_font_face(face &FontFaceObject) {
	if !face.should_be_registered_with_font_computer() {
		return
	}
	key := font_face_key_for_parsed_font_face(face.parsed_font_face())
	mut faces := computer.font_faces[key.id()] or { []&FontFaceObject{} }
	if !font_face_object_array_contains(faces, face) {
		faces << face
		computer.font_faces[key.id()] = faces
	}
	computer.did_load_font(key.family_name)
}

pub fn (mut computer FontComputer) unregister_font_face(face &FontFaceObject) {
	key := font_face_key_for_parsed_font_face(face.parsed_font_face())
	if faces := computer.font_faces[key.id()] {
		kept := font_face_object_array_without(faces, face)
		if kept.len == 0 {
			computer.font_faces.delete(key.id())
		} else {
			computer.font_faces[key.id()] = kept
		}
	}
	computer.did_load_font(key.family_name)
}

pub fn (mut computer FontComputer) synchronize_font_face_order(ordered_faces []&FontFaceObject) {
	for key, faces in computer.font_faces {
		mut ordered_for_key := []&FontFaceObject{cap: faces.len}
		for face in ordered_faces {
			if font_face_object_array_contains(faces, face) {
				ordered_for_key << face
			}
		}
		for face in faces {
			if !font_face_object_array_contains(ordered_for_key, face) {
				ordered_for_key << face
			}
		}
		computer.font_faces[key] = ordered_for_key
	}
}

pub fn (mut computer FontComputer) clear_font_feature_values_cache(family_name string) {
	computer.font_feature_values_cache.delete(family_name)
}

pub fn (mut computer FontComputer) load_font_face(font_face ParsedFontFace, on_load ?fn (&PlatformTypeface)) ?&FontLoader {
	if font_face.sources().len == 0 {
		if callback := on_load {
			callback(unsafe { nil })
		}
		return none
	}

	// FIXME: Handle local() font sources.
	mut urls := []URL{}
	for source in font_face.sources() {
		if source.kind == .url {
			font_url := source.url or { URL.from_url(source.value) }
			resolved_url := resolve_font_face_source_url(font_url, font_face.parent_rule_ref())
			urls << URL.new(resolved_url, font_url.type_, font_url.request_url_modifiers())
		}
	}

	if urls.len == 0 {
		if callback := on_load {
			callback(unsafe { nil })
		}
		return none
	}

	key := urls[0].url()
	if existing := computer.loaders_by_url[key] {
		if callback := on_load {
			mut mutable_loader := unsafe { &FontLoader(existing) }
			mutable_loader.subscribe(callback)
		}
		return existing
	}

	loader := FontLoader.create(computer, font_face.font_family(), font_face.unicode_ranges(), urls, on_load)
	mut mutable_loader := unsafe { &FontLoader(loader) }
	mutable_loader.rule_or_declaration_ = font_rule_or_declaration(computer, font_face.parent_rule_ref())
	computer.loaders_by_url[key] = loader
	return loader
}

pub fn (mut computer FontComputer) load_fonts_from_font_face_rules(rules []&CSSFontFaceRule, font_face_set &FontFaceSet) {
	mut associated_set := unsafe { &FontFaceSet(font_face_set) }
	associated_set.associate_font_computer(computer)
	// FIXME: Handle @font-face and @font-feature-values within grouping rules (@media, @supports, etc)
	for rule in rules {
		if !rule.is_valid() {
			continue
		}
		font_face := FontFaceObject.create_css_connected_for_font_computer(computer, rule)
		mut mutable_set := unsafe { &FontFaceSet(font_face_set) }
		mutable_set.add_css_connected_font(font_face)

		computer.register_font_face(font_face)
	}
}

pub fn (mut computer FontComputer) load_fonts_from_css_rules(rules []&CSSRule, font_face_set &FontFaceSet) {
	computer.synchronize_fonts_from_css_rules(rules, font_face_set, true)
}

pub fn (mut computer FontComputer) synchronize_fonts_from_css_rules(rules []&CSSRule, font_face_set &FontFaceSet, ancestors_effective bool) {
	mut associated_set := unsafe { &FontFaceSet(font_face_set) }
	associated_set.associate_font_computer(computer)
	for rule in rules {
		mut rule_effective := ancestors_effective
		if rule.type_ in [.media, .supports] && !rule.condition_matches() {
			rule_effective = false
		}

		if font_face_rule := rule.font_face_rule_ref() {
			if rule_effective && font_face_rule.is_valid() {
				if connected_face := font_face_rule.css_connected_font_face_ref() {
					if !font_face_object_array_contains(associated_set.set_entries_, connected_face) {
						associated_set.add_css_connected_font(connected_face)
					}
				} else {
					font_face := FontFaceObject.create_css_connected_for_font_computer(computer, font_face_rule)
					associated_set.add_css_connected_font(font_face)
				}
			} else if font_face_rule.css_connected_font_face_ref() != none {
				mut mutable_rule := unsafe { &CSSFontFaceRule(font_face_rule) }
				mutable_rule.disconnect_font_face()
			}
		}

		if font_feature_values_rule := rule.font_feature_values_rule_ref() {
			if rule_effective {
				computer.add_font_feature_values_rule(font_feature_values_rule)
			} else {
				computer.remove_font_feature_values_rule(font_feature_values_rule)
			}
		}

		if child_rules := rule.rules {
			computer.synchronize_fonts_from_css_rules(child_rules.rules, font_face_set, rule_effective)
		}
	}
}

pub fn (mut computer FontComputer) unload_fonts_from_font_face_rules(rules []&CSSFontFaceRule) {
	// FIXME: Handle @font-face and @font-feature-values within grouping rules (@media, @supports, etc)
	// https://drafts.csswg.org/css-font-loading/#font-face-css-connection
	// If a @font-face rule is removed from the document, its connected FontFace object is no longer CSS-connected.
	for rule in rules {
		if rule.is_valid() {
			if face := rule.css_connected_font_face_ref() {
				computer.unregister_font_face(face)
			}
		}
		mut mutable_rule := unsafe { &CSSFontFaceRule(rule) }
		mutable_rule.disconnect_font_face()
	}
}

pub fn (mut computer FontComputer) unload_fonts_from_css_rules(rules []&CSSRule) {
	for rule in rules {
		if font_face_rule := rule.font_face_rule_ref() {
			mut mutable_rule := unsafe { &CSSFontFaceRule(font_face_rule) }
			mutable_rule.disconnect_font_face()
		}

		if font_feature_values_rule := rule.font_feature_values_rule_ref() {
			computer.remove_font_feature_values_rule(font_feature_values_rule)
		}

		if child_rules := rule.rules {
			computer.unload_fonts_from_css_rules(child_rules.rules)
		}
	}
}

pub fn disconnect_font_faces_in_css_rules(rules []&CSSRule) {
	for rule in rules {
		if font_face_rule := rule.font_face_rule_ref() {
			mut mutable_rule := unsafe { &CSSFontFaceRule(font_face_rule) }
			mutable_rule.disconnect_font_face()
		}
		if child_rules := rule.rules {
			disconnect_font_faces_in_css_rules(child_rules.rules)
		}
	}
}

pub fn (mut computer FontComputer) compute_font_for_style_values(font_family []string, font_size CSSPixels, font_slope int, font_weight f64, font_width Percentage, font_optical_sizing FontOpticalSizing, font_variation_settings map[string]f64, font_feature_data FontFeatureData) &FontCascadeList {
	return computer.compute_font_for_style_values_at_size(font_family, font_size.to_double(), font_slope,
		font_weight, font_width, font_optical_sizing, font_variation_settings, font_feature_data)
}

fn (mut computer FontComputer) compute_font_for_style_values_at_size(font_family []string, font_size_px f64, font_slope int, font_weight f64, font_width Percentage, font_optical_sizing FontOpticalSizing, font_variation_settings map[string]f64, font_feature_data FontFeatureData) &FontCascadeList {
	return computer.compute_font_for_style_values_with_synthesis(font_family, font_size_px,
		font_slope, font_weight, font_width, font_optical_sizing, font_variation_settings,
		font_feature_data, 0)
}

fn (mut computer FontComputer) compute_font_for_style_values_with_synthesis(font_family []string, font_size_px f64, font_slope int, font_weight f64, font_width Percentage, font_optical_sizing FontOpticalSizing, font_variation_settings map[string]f64, font_feature_data FontFeatureData, synthesis_disabled u8) &FontCascadeList {
	// id() consumes these inputs synchronously and retains only its own string.
	// The cached cascade still owns the font data materialized on a cache miss.
	cache_key := ComputedFontCacheKey{
		font_family: font_family
		font_optical_sizing: font_optical_sizing
		font_size: CSSPixels.nearest_value_for(font_size_px)
		font_slope: font_slope
		font_weight: font_weight
		font_width: font_width
		font_variation_settings: font_variation_settings
		font_feature_data: font_feature_data
		font_synthesis_disabled: synthesis_disabled
	}
	policy := computer.font_rendering_policy()
	cached, key := computer.lookup_font_cache_key(cache_key, policy, font_size_px)
	if cached != unsafe { nil } {
		return cached
	}
	// Input formatting may run in a reusable scope. A cached cascade and its
	// map/key must instead belong to this computer's document (or ordinary
	// persistent storage for standalone and worker computers).
	owner := if document := computer.document_ { document.native_storage() } else { unsafe { &platform.RetainedArena(nil) } }
	use_document := owner != unsafe { nil } && voidptr(owner) == voidptr(platform.current_retained_arena())
	persistent := platform.enter_persistent_if(platform.arena_thread_is_current() && !use_document && platform.transient_arena_entered())
	mut retained := if use_document { platform.enter_retained_allocations() } else { platform.RetainedAllocationScope{} }
	defer { retained.finish(); platform.leave_persistent(persistent) }
	owned_key := key.clone()
	mut value := computer.compute_font_for_style_values_impl(font_family, font_size_px, font_slope, font_weight, font_width, font_optical_sizing, font_variation_settings, font_feature_data)
	value.set_font_rendering_policy(policy, font_size_px, font_slope)
	value.set_font_synthesis_disabled(synthesis_disabled)
	computer.computed_font_cache[owned_key] = value
	return value
}

fn (mut computer FontComputer) compute_font_for_style_values_impl(font_family []string, font_size_px f64, slope int, font_weight f64, font_width Percentage, font_optical_sizing FontOpticalSizing, font_variation_settings map[string]f64, font_feature_data FontFeatureData) &FontCascadeList {
	// FIXME: We round to int here as that is what is expected by our font infrastructure below
	weight := int(math.round(font_weight))

	// FIXME: We need to respect `font-size-adjust` once that is implemented.
	font_size_used_value := font_size_px

	mut variation := FontVariationSettings{}
	variation.weight = font_weight
	variation.width = font_width.value()

	// NB: The spec recommends that we use the 'used value' of font-size for 'opsz' when font-optical-sizing is 'auto'.
	// FIXME: User agents must not select a value for the "opsz" axis which is not supported by the font used for
	//        rendering the text. This can be accomplished by clamping a chosen value to the range supported by the
	//        font. https://drafts.csswg.org/css-fonts/#font-optical-sizing-def
	if font_optical_sizing == .auto_ {
		variation.opsz = font_size_used_value
	}

	for tag_string, value in font_variation_settings {
		if tag_string.len != 4 {
			continue
		}
		variation.set_axis(tag_string, value)
	}

	// FIXME: Implement the full font-matching algorithm: https://www.w3.org/TR/css-fonts-4/#font-matching-algorithm
	font_size_in_pt := f32(font_size_used_value * 0.75)

	mut font_list := FontCascadeList.create()

	for family in font_family {
		other_font_list := if is_generic_font_family(family) {
			computer.find_font(platform_generic_font_name_boundary(family,
				computer.font_rendering_policy()), weight, slope,
				font_size_in_pt, variation, font_feature_data)
		} else {
			computer.find_font(family, weight, slope, font_size_in_pt, variation,
				font_feature_data)
		}
		if other_font_list != unsafe { nil } {
			font_list.extend(other_font_list)
		}
	}

	// NB: @font-feature-values can't apply to the default font since it's not loaded from CSS
	default_font := platform_default_font_boundary(font_size_in_pt, variation, font_feature_data.to_shape_features(map[string][]u32{}))
	if font_list.is_empty() {
		// This is needed to make sure we check default font before reaching to emojis.
		font_list.add(default_font, [])
	}

	// Add emoji and symbol fonts
	for font_name in platform_symbol_font_names_boundary() {
		other_font_list := computer.find_font(font_name, weight, slope, font_size_in_pt,
			variation, font_feature_data)
		if other_font_list != unsafe { nil } {
			font_list.extend(other_font_list)
		}
	}

	// The default font is already included in the font list, but we explicitly set it
	// as the last-resort font. This ensures that if none of the specified fonts contain
	// the requested code point, there is still a font available to provide a fallback glyph.
	font_list.set_last_resort_font(default_font)

	// Boundary: System-font fallback callback is a platform font database integration point.
	return font_list
}

fn (mut computer FontComputer) find_font(family string, weight int, slope int, font_size_in_pt f32, variation FontVariationSettings, font_feature_data FontFeatureData) &FontCascadeList {
	font_feature_values := computer.font_feature_values_for_family(family)

	// OPTIMIZATION: Look for an exact match in loaded fonts first.
	// FIXME: Respect the other font-* descriptors
	key := FontFaceKey{
		family_name: family
		weight: FontWeightRange{
			min: weight
			max: weight
		}
		slope: slope
		width: int(variation.width)
	}
	if faces := computer.font_faces[key.id()] {
		mut result := FontCascadeList.create()
		shape_features := font_feature_data.to_shape_features(font_feature_values)
		for face in faces {
			face_fonts := face.font_with_point_size(font_size_in_pt, variation, shape_features)
			if face_fonts != unsafe { nil } {
				result.extend(face_fonts)
			}
		}
		if !result.is_empty() {
			return result
		}
	}

	found_font := computer.font_matching_algorithm(family, weight, slope, font_size_in_pt,
		variation, font_feature_data, font_feature_values)
	if found_font != unsafe { nil } {
		if !found_font.is_empty() {
			return found_font
		}
	}
	return unsafe { nil }
}

// Partial implementation of the font-matching algorithm: https://www.w3.org/TR/css-fonts-4/#font-matching-algorithm
// FIXME: This should be replaced by the full CSS font selection algorithm.
fn (mut computer FontComputer) font_matching_algorithm(family_name string, weight int, slope int, font_size_in_pt f32, variations FontVariationSettings, font_feature_data FontFeatureData, font_feature_values map[string][]u32) &FontCascadeList {
	// If a font family match occurs, the user agent assembles the set of font faces in that family and then
	// narrows the set to a single face using other font properties in the order given below.
	mut matching_family_fonts := []MatchingFontCandidate{}
	for key_string, faces in computer.font_faces {
		key := font_face_key_from_id(key_string)
		if key.family_name.to_lower() == family_name.to_lower() {
			matching_family_fonts << MatchingFontCandidate{
				key: key
				width: font_width_bucket_from_percentage(key.width)
				font_faces: faces.clone()
			}
		}
	}
	if matching_family_fonts.len == 0 {
		for typeface in platform_typefaces_with_family_name_boundary(family_name,
			computer.font_rendering_policy()) {
			matching_family_fonts << MatchingFontCandidate{
				key: FontFaceKey{
					family_name: typeface.family_name
					// FIXME: Support system fonts that have a range of weights, etc.
					weight: FontWeightRange{
						min: typeface.weight_
						max: typeface.weight_
					}
					slope: typeface.slope_
				}
				width: font_width_bucket_from_percentage(typeface.width_)
				typeface: typeface
				is_platform_font: true
			}
		}
	}

	if matching_family_fonts.len == 0 {
		return unsafe { nil }
	}

	// 1. font-width is tried first. If the desired width is present, discard
	// every face in the family with a different width.
	desired_width := font_width_bucket_from_percentage(variations.width)
	if matching_family_fonts.any(it.width == desired_width) {
		matching_family_fonts = matching_family_fonts.filter(it.width == desired_width)
	}

	sort_matching_font_candidates_by_weight(mut matching_family_fonts)
	// 2. font-style is tried next.
	// We don't have complete support of italic and oblique fonts, so matching on font-style can be simplified to:
	// If a matching slope is found, all faces which don't have that matching slope are excluded from the matching set.
	mut has_style_match := false
	for candidate in matching_family_fonts {
		if candidate.key.slope == slope {
			has_style_match = true
			break
		}
	}
	if has_style_match {
		matching_family_fonts = matching_family_fonts.filter(it.key.slope == slope)
	}

	// 3. font-weight is matched next.
	// If a font does not have any concept of varying strengths of weights, its weight is mapped according list in the
	// property definition. If bolder/lighter relative weights are used, the effective weight is calculated based on
	// the inherited weight value, as described in the definition of the font-weight property.
	// FIXME: "varying strengths of weights"
	// If the matching set after performing the steps above includes faces with weight values containing the
	// font-weight desired value, faces with weight values which do not include the desired font-weight value are
	// removed from the matching set.

	// FIXME: This whole function currently just returns the first match instead of progressing further, so we'll do that here too.
	mut matching_weight_index := -1
	for i, candidate in matching_family_fonts {
		if candidate.key.weight.contains_inclusive(weight) {
			matching_weight_index = i
			break
		}
	}
	if matching_weight_index >= 0 {
		for i := matching_weight_index; i < matching_family_fonts.len; i++ {
			mut candidate := matching_family_fonts[i]
			found_font := candidate.font_with_point_size(font_size_in_pt, variations,
				font_feature_data, font_feature_values)
			if found_font != unsafe { nil } {
				return found_font
			}
		}
	}

	// If there is no face which contains the desired value, a weight value is chosen using the rules below:

	// - If the desired weight is inclusively between 400 and 500, weights greater than or equal to the target weight
	//   are checked in ascending order until 500 is hit and checked, followed by weights less than the target weight
	//   in descending order, followed by weights greater than 500, until a match is found.
	if weight >= 400 && weight <= 500 {
		mut i := 0
		for i < matching_family_fonts.len && matching_family_fonts[i].key.weight.min < weight {
			i++
		}
		for ; i < matching_family_fonts.len && matching_family_fonts[i].key.weight.min <= 500; i++ {
			mut candidate := matching_family_fonts[i]
			found_font := candidate.font_with_point_size(font_size_in_pt, variations,
				font_feature_data, font_feature_values)
			if found_font != unsafe { nil } {
				return found_font
			}
		}
		found_descending := find_matching_font_weight_descending(mut matching_family_fonts,
			weight, font_size_in_pt, variations, font_feature_data, font_feature_values, false)
		if found_descending != unsafe { nil } {
			return found_descending
		}
		for ; i < matching_family_fonts.len; i++ {
			mut candidate := matching_family_fonts[i]
			found_font := candidate.font_with_point_size(font_size_in_pt, variations,
				font_feature_data, font_feature_values)
			if found_font != unsafe { nil } {
				return found_font
			}
		}
	}
	// - If the desired weight is less than 400, weights less than or equal to the desired weight are checked in
	//   descending order followed by weights above the desired weight in ascending order until a match is found.
	if weight < 400 {
		found_descending := find_matching_font_weight_descending(mut matching_family_fonts,
			weight, font_size_in_pt, variations, font_feature_data, font_feature_values, true)
		if found_descending != unsafe { nil } {
			return found_descending
		}
		found_ascending := find_matching_font_weight_ascending(mut matching_family_fonts,
			weight, font_size_in_pt, variations, font_feature_data, font_feature_values, false)
		if found_ascending != unsafe { nil } {
			return found_ascending
		}
	}
	// - If the desired weight is greater than 500, weights greater than or equal to the desired weight are checked in
	//   ascending order followed by weights below the desired weight in descending order until a match is found.
	if weight > 500 {
		found_ascending := find_matching_font_weight_ascending(mut matching_family_fonts,
			weight, font_size_in_pt, variations, font_feature_data, font_feature_values, true)
		if found_ascending != unsafe { nil } {
			return found_ascending
		}
		found_descending := find_matching_font_weight_descending(mut matching_family_fonts,
			weight, font_size_in_pt, variations, font_feature_data, font_feature_values, false)
		if found_descending != unsafe { nil } {
			return found_descending
		}
	}

	return unsafe { nil }
}

fn find_matching_font_weight_ascending(mut candidates []MatchingFontCandidate, target_weight int, font_size_in_pt f32, variations FontVariationSettings, font_feature_data FontFeatureData, font_feature_values map[string][]u32, inclusive bool) &FontCascadeList {
	for mut candidate in candidates {
		if inclusive {
			if candidate.key.weight.min < target_weight {
				continue
			}
		} else if candidate.key.weight.min <= target_weight {
			continue
		}
		found_font := candidate.font_with_point_size(font_size_in_pt, variations,
			font_feature_data, font_feature_values)
		if found_font != unsafe { nil } {
			return found_font
		}
	}
	return unsafe { nil }
}

fn find_matching_font_weight_descending(mut candidates []MatchingFontCandidate, target_weight int, font_size_in_pt f32, variations FontVariationSettings, font_feature_data FontFeatureData, font_feature_values map[string][]u32, inclusive bool) &FontCascadeList {
	for i := candidates.len - 1; i >= 0; i-- {
		mut candidate := candidates[i]
		if inclusive {
			if candidate.key.weight.max > target_weight {
				continue
			}
		} else if candidate.key.weight.max >= target_weight {
			continue
		}
		found_font := candidate.font_with_point_size(font_size_in_pt, variations,
			font_feature_data, font_feature_values)
		if found_font != unsafe { nil } {
			return found_font
		}
	}
	return unsafe { nil }
}

fn (mut computer FontComputer) font_feature_values_for_family(family_name string) map[string][]u32 {
	if cached := computer.font_feature_values_cache[family_name] {
		return cached
	}

	mut font_feature_values := map[string][]u32{}

	// https://drafts.csswg.org/css-fonts/#font-feature-values-syntax
	// For each <family-name> in the @font-feature-values prelude, each font feature value declaration defines a
	// mapping between a (family name, feature block name, declaration name) tuple and the list of one or more
	// integers from the declaration's value. If the same tuple appears more than once in a document (such as if a
	// single block), the last-defined one is used.
	//
	// FIXME: We only account for Author stylesheets here, we should also account for UserAgent and User.
	for rule in computer.font_feature_values_rules {
		mut matches_family := false
		for family in rule.font_families() {
			if family == family_name {
				matches_family = true
				break
			}
		}
		if !matches_family {
			continue
		}
		merge_font_feature_values(mut font_feature_values, rule.to_hash_map())
	}

	computer.font_feature_values_cache[family_name] = font_feature_values.clone()
	return font_feature_values
}

fn merge_font_feature_values(mut target map[string][]u32, source map[string][]u32) {
	for key, value in source {
		target[key] = value.clone()
	}
}

// --- Parsing stubs and platform boundaries local to this file ---

struct ParsedFontSourceDescriptor {
	serialized string
	sources    []FontSourceStyleValue
}

fn parse_font_family_descriptor(value string) ?StyleValue {
	return parse_font_family_descriptor_components(parse_component_values_for_value_logic(value))
}

fn parse_font_family_descriptor_components(component_values []ComponentValue) ?StyleValue {
	mut parser := Parser.from_component_values(component_values)
	mut tokens := ComponentValueStream.new(component_values)
	font_family := parser.parse_family_name_value(mut tokens) or { return none }
	tokens.consume_whitespace()
	if tokens.has_more_tokens() {
		return none
	}
	return font_family
}

fn parse_font_style_descriptor(value string) ?StyleValue {
	return parse_font_style_descriptor_components(parse_component_values_for_value_logic(value))
}

fn parse_font_style_descriptor_components(component_values []ComponentValue) ?StyleValue {
	mut parser := Parser.from_component_values(component_values)
	mut tokens := ComponentValueStream.new(component_values)
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	if component_value := transaction.peek() {
		if component_value.is(.ident)
			&& equals_ignoring_ascii_case(component_value.token().ident(), 'auto') {
			transaction.consume()
			transaction.consume_whitespace()
			if !transaction.has_more_tokens() {
				return StyleValue(KeywordStyleValue.create(.auto))
			}
		}
	}

	font_style := parser.parse_font_style_value(mut tokens) or { return none }
	tokens.consume_whitespace()
	if tokens.has_more_tokens() {
		return none
	}
	return font_style
}

fn parse_font_weight_descriptor(value string) ?StyleValue {
	return parse_font_weight_descriptor_components(parse_component_values_for_value_logic(value))
}

fn parse_font_weight_descriptor_components(component_values []ComponentValue) ?StyleValue {
	mut parser := Parser.from_component_values(component_values)
	mut tokens := ComponentValueStream.new(component_values)
	mut auto_attempt := tokens.clone()
	auto_attempt.consume_whitespace()
	if component_value := auto_attempt.consume() {
		if component_value.is(.ident)
			&& equals_ignoring_ascii_case(component_value.token().ident(), 'auto') {
			auto_attempt.consume_whitespace()
			if !auto_attempt.has_more_tokens() {
				return StyleValue(KeywordStyleValue.create(.auto))
			}
		}
	}

	mut weights := []StyleValue{}
	for weights.len < 2 {
		tokens.consume_whitespace()
		if !tokens.has_more_tokens() {
			break
		}
		weight := parser.parse_font_weight_value(mut tokens) or { return none }
		if weight.to_keyword() in [.lighter, .bolder] {
			return none
		}
		weights << weight
	}
	tokens.consume_whitespace()
	if weights.len == 0 || tokens.has_more_tokens() {
		return none
	}
	return StyleValue(StyleValueList.create(weights, .space, .yes))
}

fn font_weight_range_from_style_value(style_value StyleValue) ?FontWeightRange {
	list := style_value.as_value_list() or { return none }
	values := list.values()
	if values.len == 0 || values.len > 2 {
		return none
	}
	first := absolute_font_weight_from_style_value(values[0]) or { return none }
	second := if values.len == 2 {
		absolute_font_weight_from_style_value(values[1]) or { return none }
	} else {
		first
	}
	return FontWeightRange{
		min: if first < second { first } else { second }
		max: if first > second { first } else { second }
	}
}

fn absolute_font_weight_from_style_value(style_value StyleValue) ?int {
	return match style_value.to_keyword() {
		.normal { 400 }
		.bold { 700 }
		.invalid { int(number_from_style_value(style_value, none)) }
		else { none }
	}
}

fn parse_font_width_descriptor(value string) ?StyleValue {
	return parse_font_width_descriptor_components(parse_component_values_for_value_logic(value))
}

fn parse_font_property_descriptor(value string, property_id PropertyID) ?StyleValue {
	return parse_font_property_descriptor_components(parse_component_values_for_value_logic(value), property_id)
}

fn parse_font_property_descriptor_components(component_values []ComponentValue, property_id PropertyID) ?StyleValue {
	mut parser := Parser.from_component_values(component_values)
	mut tokens := ComponentValueStream.new(component_values)
	style_value := parser.parse_css_value_tokens(property_id, mut tokens) or { return none }
	// Descriptor property references reuse the property grammar, but unlike properties they
	// do not accept CSS-wide keywords or arbitrary substitution functions.
	if style_value.is_css_wide_keyword() || style_value is UnresolvedStyleValue {
		return none
	}
	return style_value
}

fn parse_font_keyword_descriptor(value string, allowed_keywords []string) ?StyleValue {
	return parse_font_keyword_descriptor_components(parse_component_values_for_value_logic(value), allowed_keywords)
}

fn parse_font_keyword_descriptor_components(component_values []ComponentValue, allowed_keywords []string) ?StyleValue {
	mut tokens := ComponentValueStream.new(component_values)
	style_value := parse_property_keyword_value(mut tokens, allowed_keywords) or { return none }
	tokens.consume_whitespace()
	if tokens.has_more_tokens() {
		return none
	}
	return style_value
}

fn parse_font_keyword_or_string_descriptor(value string, keyword string) ?StyleValue {
	return parse_font_keyword_or_string_descriptor_components(parse_component_values_for_value_logic(value), keyword)
}

fn parse_font_keyword_or_string_descriptor_components(component_values []ComponentValue, keyword string) ?StyleValue {
	if keyword_value := parse_font_keyword_descriptor_components(component_values, [
		keyword,
	]) {
		return keyword_value
	}
	mut parser := Parser.from_component_values(component_values)
	mut tokens := ComponentValueStream.new(component_values)
	string_value := parser.parse_string_value(mut tokens) or { return none }
	tokens.consume_whitespace()
	if tokens.has_more_tokens() {
		return none
	}
	return StyleValue(string_value)
}

fn string_from_font_keyword_or_string(style_value StyleValue) ?string {
	if style_value is StringStyleValue {
		return style_value.string_value()
	}
	return none
}

fn parse_font_metric_override_descriptor(value string) ?StyleValue {
	return parse_font_metric_override_descriptor_components(parse_component_values_for_value_logic(value))
}

fn parse_font_metric_override_descriptor_components(component_values []ComponentValue) ?StyleValue {
	if normal := parse_font_keyword_descriptor_components(component_values, ['normal']) {
		return normal
	}
	mut parser := Parser.from_component_values(component_values)
	mut tokens := ComponentValueStream.new(component_values)
	percentage_value := parser.parse_percentage_value(mut tokens) or { return none }
	tokens.consume_whitespace()
	if tokens.has_more_tokens() {
		return none
	}
	if percentage_value is PercentageStyleValue {
		if percentage_value.raw_value() < 0 {
			return none
		}
		return percentage_value
	}
	if percentage_value is CalculatedStyleValue {
		percentage := percentage_value.resolve_percentage(CalculationResolutionContext{}) or {
			return none
		}
		if percentage.value() < 0 {
			return none
		}
		return StyleValue(PercentageStyleValue.create(percentage))
	}
	return none
}

fn percentage_from_font_metric_override(style_value StyleValue) ?Percentage {
	if style_value is PercentageStyleValue {
		return style_value.percentage()
	}
	return none
}

fn parse_font_width_descriptor_components(component_values []ComponentValue) ?StyleValue {
	mut parser := Parser.from_component_values(component_values)
	mut tokens := ComponentValueStream.new(component_values)
	mut auto_attempt := tokens.clone()
	auto_attempt.consume_whitespace()
	if component_value := auto_attempt.consume() {
		if component_value.is(.ident)
			&& equals_ignoring_ascii_case(component_value.token().ident(), 'auto') {
			auto_attempt.consume_whitespace()
			if !auto_attempt.has_more_tokens() {
				return StyleValue(KeywordStyleValue.create(.auto))
			}
		}
	}

	font_width := parser.parse_font_width_value(mut tokens) or { return none }
	tokens.consume_whitespace()
	if tokens.has_more_tokens() {
		return none
	}
	if font_width is PercentageStyleValue {
		if font_width.percentage().value() < 0 {
			return none
		}
	} else if font_width is CalculatedStyleValue {
		percentage := font_width.resolve_percentage(CalculationResolutionContext{}) or { return none }
		if percentage.value() < 0 {
			return none
		}
	}
	return font_width
}

fn font_width_from_style_value(style_value StyleValue) ?int {
	if style_value is PercentageStyleValue {
		return int(style_value.percentage().value())
	}
	if style_value is CalculatedStyleValue {
		percentage := style_value.resolve_percentage(CalculationResolutionContext{}) or {
			return none
		}
		return int(percentage.value())
	}
	return font_width_from_keyword(style_value.to_keyword())
}

fn font_width_from_keyword(keyword Keyword) ?int {
	return match keyword {
		.ultra_condensed { 50 }
		.extra_condensed { 62 }
		.condensed { 75 }
		.semi_condensed { 87 }
		.normal { 100 }
		.semi_expanded { 112 }
		.expanded { 125 }
		.extra_expanded { 150 }
		.ultra_expanded { 200 }
		else { none }
	}
}

fn parse_font_source_descriptor(value string) ?ParsedFontSourceDescriptor {
	sources := parse_font_source_style_values(value)
	if sources.len == 0 {
		return none
	}
	return ParsedFontSourceDescriptor{
		serialized: sources.map(it.serialize(.normal)).join(', ')
		sources: sources
	}
}

fn parse_font_face_sources(value string) []ParsedFontFaceSource {
	return parsed_font_face_sources_from_style_values(parse_font_source_style_values(value))
}

fn parsed_font_face_sources_from_style_values(style_values []FontSourceStyleValue) []ParsedFontFaceSource {
	mut sources := []ParsedFontFaceSource{}
	for style_value in style_values {
		source := style_value.source()
		match source {
			FontSourceLocal {
				sources << ParsedFontFaceSource{
					kind: .local
					value: string_from_style_value(source.name)
				}
			}
			URL {
				sources << ParsedFontFaceSource{
					kind: .url
					value: source.url()
					url: source
					format: style_value.format()
					tech: style_value.tech()
				}
			}
		}
	}
	return sources
}

fn parse_font_source_style_values(value string) []FontSourceStyleValue {
	mut parser := Parser.from_css_text(value)
	mut tokens := ComponentValueStream.new(parser.component_values)
	return parser.parse_font_source_values(mut tokens)
}

struct NormalizedFontFormatName {
	name         string
	implied_tech []FontTech
}

fn normalize_legacy_font_format_name(value string) ?NormalizedFontFormatName {
	// Quoted legacy format strings are normalized before support is checked:
	// format("woff2")                 -> format(woff2)
	// format("woff")                  -> format(woff)
	// format("truetype")              -> format(truetype)
	// format("opentype")              -> format(opentype)
	// format("collection")            -> format(collection)
	// format("woff2-variations")      -> format(woff2) tech(variations)
	// format("woff-variations")       -> format(woff) tech(variations)
	// format("truetype-variations")   -> format(truetype) tech(variations)
	// format("opentype-variations")   -> format(opentype) tech(variations)
	lower := value.to_lower()
	return match lower {
		'woff2', 'woff', 'truetype', 'opentype', 'collection' {
			if !font_format_is_supported(lower) {
				none
			} else {
				NormalizedFontFormatName{
					name: lower
				}
			}
		}
		'woff2-variations' {
			if !font_format_is_supported('woff2') {
				none
			} else {
				NormalizedFontFormatName{
					name: 'woff2'
					implied_tech: [FontTech.variations]
				}
			}
		}
		'woff-variations' {
			if !font_format_is_supported('woff') {
				none
			} else {
				NormalizedFontFormatName{
					name: 'woff'
					implied_tech: [FontTech.variations]
				}
			}
		}
		'truetype-variations' {
			if !font_format_is_supported('truetype') {
				none
			} else {
				NormalizedFontFormatName{
					name: 'truetype'
					implied_tech: [FontTech.variations]
				}
			}
		}
		'opentype-variations' {
			if !font_format_is_supported('opentype') {
				none
			} else {
				NormalizedFontFormatName{
					name: 'opentype'
					implied_tech: [FontTech.variations]
				}
			}
		}
		else {
			none
		}
	}
}

fn split_css_comma_list(value string) []string {
	mut result := []string{}
	mut start := 0
	mut depth := 0
	mut quote := u8(0)
	for i, ch in value {
		if quote != 0 {
			if ch == quote {
				quote = 0
			}
			continue
		}
		if ch == `"` || ch == `'` {
			quote = u8(ch)
			continue
		}
		if ch == `(` {
			depth++
		} else if ch == `)` {
			depth--
		} else if ch == `,` && depth == 0 {
			part := value[start..i].trim_space()
			if part.len != 0 {
				result << part
			}
			start = i + 1
		}
	}
	part := value[start..].trim_space()
	if part.len != 0 {
		result << part
	}
	return result
}

fn split_css_space_list(value string) []string {
	mut result := []string{}
	mut start := -1
	mut depth := 0
	mut quote := u8(0)
	for i, ch in value {
		if quote != 0 {
			if ch == quote {
				quote = 0
			}
			continue
		}
		if ch == `"` || ch == `'` {
			if start == -1 {
				start = i
			}
			quote = u8(ch)
			continue
		}
		if ch == `(` {
			if start == -1 {
				start = i
			}
			depth++
			continue
		}
		if ch == `)` {
			depth--
			continue
		}
		if is_ascii_whitespace_u8(u8(ch)) && depth == 0 {
			if start != -1 {
				part := value[start..i].trim_space()
				if part.len != 0 {
					result << part
				}
				start = -1
			}
			continue
		}
		if start == -1 {
			start = i
		}
	}
	if start != -1 {
		part := value[start..].trim_space()
		if part.len != 0 {
			result << part
		}
	}
	return result
}

fn parse_unicode_ranges(value string) []UnicodeRange {
	mut parser := Parser.from_css_text(value)
	mut tokens := ComponentValueStream.new(parser.component_values)
	return parser.parse_unicode_ranges(mut tokens)
}

fn make_valid_unicode_range(start u64, end u64) ?UnicodeRange {
	if end > 0x10ffff || start > end {
		return none
	}
	return UnicodeRange{
		start: u32(start)
		end: u32(end)
	}
}

fn is_hex_digit_string(text string) bool {
	if text.len == 0 || text.len > 6 {
		return false
	}
	for ch in text {
		if !is_hex_digit(u32(ch)) {
			return false
		}
	}
	return true
}

fn parse_unicode_range(value string) ?UnicodeRange {
	mut text := value.trim_space()
	if !text.to_upper().starts_with('U+') {
		return none
	}
	text = text[2..]
	if text.contains('?') {
		if text.len == 0 || text.len > 6 {
			return none
		}
		mut seen_question_mark := false
		for ch in text {
			if ch == `?` {
				seen_question_mark = true
				continue
			}
			if seen_question_mark || !is_hex_digit(u32(ch)) {
				return none
			}
		}
		start_text := text.replace('?', '0')
		end_text := text.replace('?', 'F')
		start := strconv.parse_uint(start_text, 16, 32) or { return none }
		end := strconv.parse_uint(end_text, 16, 32) or { return none }
		return make_valid_unicode_range(start, end)
	}
	if text.contains('-') {
		parts := text.split_nth('-', 2)
		if parts.len != 2 || !is_hex_digit_string(parts[0]) || !is_hex_digit_string(parts[1]) {
			return none
		}
		start := strconv.parse_uint(parts[0], 16, 32) or { return none }
		end := strconv.parse_uint(parts[1], 16, 32) or { return none }
		return make_valid_unicode_range(start, end)
	}
	if !is_hex_digit_string(text) {
		return none
	}
	code_point := strconv.parse_uint(text, 16, 32) or { return none }
	return make_valid_unicode_range(code_point, code_point)
}

fn font_display_from_string(value string) ?FontDisplay {
	return match value.to_lower() {
		'auto' { FontDisplay.auto_ }
		'block' { FontDisplay.block }
		'swap' { FontDisplay.swap }
		'fallback' { FontDisplay.fallback }
		'optional' { FontDisplay.optional }
		else { none }
	}
}

fn font_display_from_keyword(keyword Keyword) ?FontDisplay {
	return match keyword {
		.auto { FontDisplay.auto_ }
		.block { FontDisplay.block }
		.swap { FontDisplay.swap }
		.fallback { FontDisplay.fallback }
		.optional { FontDisplay.optional }
		else { none }
	}
}

fn font_tech_from_string(value string) ?FontTech {
	return match value.to_lower() {
		'features-opentype' { FontTech.features_opentype }
		'features-aat' { FontTech.features_aat }
		'features-graphite' { FontTech.features_graphite }
		'variations' { FontTech.variations }
		'color-colrv0' { FontTech.color_colrv0 }
		'color-colrv1' { FontTech.color_colrv1 }
		'color-svg' { FontTech.color_svg }
		'color-sbix' { FontTech.color_sbix }
		'color-cbdt' { FontTech.color_cbdt }
		'palettes' { FontTech.palettes }
		'incremental' { FontTech.incremental }
		'avar2' { FontTech.avar2 }
		else { none }
	}
}

fn parse_font_weight_range(value string) ?FontWeightRange {
	parsed := parse_font_weight_descriptor(value) or { return none }
	return font_weight_range_from_style_value(parsed)
}

fn parse_font_face_object_numeric_weight(value string) ?FontWeightRange {
	weight := strconv.atoi(value.trim_space()) or { return none }
	return FontWeightRange{
		min: weight
		max: weight
	}
}

fn compute_font_style_slope(value string) int {
	parsed := parse_font_style_descriptor(value) or { return 0 }
	if font_style := parsed.as_font_style() {
		return font_style.to_font_slope()
	}
	return 0
}

fn compute_font_width(value string) int {
	parsed := parse_font_width_descriptor(value) or { return 100 }
	if parsed.to_keyword() == .auto {
		return 100
	}
	return font_width_from_style_value(parsed) or { 100 }
}

fn font_feature_settings_from_style_value(style_value StyleValue) ?map[string]i64 {
	if style_value.to_keyword() == .normal {
		return none
	}
	list := style_value.as_value_list() or { return none }
	mut settings := map[string]i64{}
	for item in list.values() {
		if item !is OpenTypeTaggedStyleValue {
			return none
		}
		tagged := item as OpenTypeTaggedStyleValue
		settings[tagged.tag()] = int_from_style_value(tagged.value())
	}
	return settings
}

fn font_variation_settings_from_style_value(style_value StyleValue) ?map[string]f64 {
	if style_value.to_keyword() == .normal {
		return none
	}
	list := style_value.as_value_list() or { return none }
	mut settings := map[string]f64{}
	for item in list.values() {
		if item !is OpenTypeTaggedStyleValue {
			return none
		}
		tagged := item as OpenTypeTaggedStyleValue
		settings[tagged.tag()] = number_from_style_value(tagged.value(), none)
	}
	return settings
}

fn string_from_font_family_descriptor(value string) string {
	trimmed := value.trim_space()
	if trimmed.contains(',') {
		return unquote_css_string(split_css_comma_list(trimmed)[0])
	}
	return unquote_css_string(trimmed)
}

fn unquote_css_string(value string) string {
	trimmed := value.trim_space()
	if trimmed.len >= 2 {
		if (trimmed[0] == `"` && trimmed[trimmed.len - 1] == `"`)
			|| (trimmed[0] == `'` && trimmed[trimmed.len - 1] == `'`) {
			return trimmed[1..trimmed.len - 1]
		}
	}
	return trimmed
}

fn is_valid_css_number(value string) bool {
	trimmed := value.trim_space()
	if trimmed.len == 0 || trimmed.to_lower().contains('inf') || trimmed.to_lower().contains('nan') {
		return false
	}
	_ := strconv.atof64(trimmed) or { return false }
	return true
}

fn is_valid_css_percentage(value string) bool {
	trimmed := value.trim_space()
	if trimmed.len < 2 || !trimmed.ends_with('%') {
		return false
	}
	return is_valid_css_number(trimmed[..trimmed.len - 1])
}

fn parse_font_family_list(value string) []string {
	mut families := []string{}
	for item in split_css_comma_list(value) {
		trimmed := item.trim_space()
		if trimmed.len != 0 {
			families << unquote_css_string(trimmed)
		}
	}
	return families
}

fn parse_font_shorthand_family_list(value string) ?[]string {
	tokens := split_css_space_list(value)
	if tokens.len == 0 {
		return none
	}

	mut family_start := -1
	for i, token in tokens {
		if !is_font_size_token(token) {
			continue
		}

		mut next := i + 1
		if token.ends_with('/') && next < tokens.len {
			next++
		} else if !token.contains('/') && next < tokens.len {
			line_height_token := tokens[next]
			if line_height_token == '/' {
				next += 2
			} else if line_height_token.starts_with('/') {
				next++
			} else if line_height_token.ends_with('/') {
				next += 2
			}
		}
		family_start = next
		break
	}

	if family_start < 0 || family_start >= tokens.len {
		return none
	}

	families := parse_font_family_list(tokens[family_start..].join(' '))
	if families.len == 0 {
		return none
	}
	return families
}

fn is_font_size_token(token string) bool {
	mut size := token.trim_space()
	slash := size.index_u8(`/`)
	if slash >= 0 {
		size = size[..slash]
	}
	size = size.trim_space()
	if size.len == 0 {
		return false
	}

	lower := size.to_lower()
	if lower in [
		'xx-small',
		'x-small',
		'small',
		'medium',
		'large',
		'x-large',
		'xx-large',
		'xxx-large',
		'larger',
		'smaller',
		'math',
	] {
		return true
	}
	if is_valid_css_percentage(lower) {
		return true
	}
	if starts_with_css_math_function(lower) {
		return true
	}
	for unit in [
		'cap',
		'cqb',
		'cqh',
		'cqi',
		'cqmax',
		'cqmin',
		'cqw',
		'rem',
		'rlh',
		'vmax',
		'vmin',
		'vb',
		'vh',
		'vi',
		'vw',
		'ch',
		'cm',
		'em',
		'ex',
		'ic',
		'in',
		'lh',
		'mm',
		'pc',
		'pt',
		'px',
		'q',
	] {
		if lower.ends_with(unit) && lower.len > unit.len {
			return is_valid_css_number(lower[..lower.len - unit.len])
		}
	}
	return false
}

fn starts_with_css_math_function(value string) bool {
	for name in ['calc(', 'min(', 'max(', 'clamp('] {
		if value.starts_with(name) && value.ends_with(')') {
			return true
		}
	}
	return false
}

fn contains_ascii_whitespace(value string) bool {
	for ch in value {
		if is_ascii_whitespace_u8(u8(ch)) {
			return true
		}
	}
	return false
}

fn is_ascii_whitespace_u8(ch u8) bool {
	return ch == ` ` || ch == `\t` || ch == `\n` || ch == `\r` || ch == 0x0c
}

fn is_generic_font_family(value string) bool {
	return value.to_lower() in [
		'serif',
		'sans-serif',
		'monospace',
		'cursive',
		'fantasy',
		'system-ui',
		'ui-serif',
		'ui-sans-serif',
		'ui-monospace',
		'ui-rounded',
		'math',
		'fangsong',
	]
}

fn font_face_object_array_contains(values []&FontFaceObject, needle &FontFaceObject) bool {
	for value in values {
		if value == needle {
			return true
		}
	}
	return false
}

fn font_face_set_array_contains(values []&FontFaceSet, needle &FontFaceSet) bool {
	for value in values {
		if value == needle {
			return true
		}
	}
	return false
}

fn font_feature_values_rule_array_contains(values []&CSSFontFeatureValuesRule, needle &CSSFontFeatureValuesRule) bool {
	for value in values {
		if value == needle {
			return true
		}
	}
	return false
}

fn font_face_object_array_without(values []&FontFaceObject, needle &FontFaceObject) []&FontFaceObject {
	mut kept := []&FontFaceObject{}
	for value in values {
		if value != needle {
			kept << value
		}
	}
	return kept
}

fn font_feature_values_rule_array_without(values []&CSSFontFeatureValuesRule, needle &CSSFontFeatureValuesRule) []&CSSFontFeatureValuesRule {
	mut kept := []&CSSFontFeatureValuesRule{}
	for value in values {
		if value != needle {
			kept << value
		}
	}
	return kept
}

fn max_u32_as_usize() uint {
	return uint(0xffffffff)
}

fn sort_matching_font_candidates_by_weight(mut candidates []MatchingFontCandidate) {
	for i := 1; i < candidates.len; i++ {
		mut j := i
		for j > 0 && candidates[j - 1].key.weight.min > candidates[j].key.weight.min {
			tmp := candidates[j - 1]
			candidates[j - 1] = candidates[j]
			candidates[j] = tmp
			j--
		}
	}
}

fn font_width_bucket_from_percentage(percentage f64) int {
	percentages := [50.0, 62.5, 75.0, 87.5, 100.0, 112.5, 125.0, 150.0, 200.0]
	mut best_index := 0
	mut best_distance := math.abs(percentage - percentages[0])
	for index := 1; index < percentages.len; index++ {
		distance := math.abs(percentage - percentages[index])
		if distance < best_distance {
			best_index = index
			best_distance = distance
		}
	}
	return best_index + 1
}

fn font_face_key_from_id(id string) FontFaceKey {
	parts := id.split('|')
	if parts.len != 4 {
		return FontFaceKey{}
	}
	range_parts := parts[1].split_nth('-', 2)
	mut min := 0
	mut max := 0
	if range_parts.len == 2 {
		min = strconv.atoi(range_parts[0]) or { 0 }
		max = strconv.atoi(range_parts[1]) or { 0 }
	}
	return FontFaceKey{
		family_name: parts[0]
		weight: FontWeightRange{
			min: min
			max: max
		}
		slope: strconv.atoi(parts[2]) or { 0 }
		width: strconv.atoi(parts[3]) or { 100 }
	}
}

fn platform_load_font_from_url_boundary(raw_url string, family_name string) &PlatformTypeface {
	// Frozen layout and pixel fixtures use file: resources. Prepare sfnt, WOFF,
	// and WOFF2 sources through the platform font boundary before retaining the
	// concrete file used by metrics, HarfBuzz shaping, and native replay.
	parsed := liburl.parse(raw_url) or { return unsafe { nil } }
	if parsed.scheme != 'file' {
		return unsafe { nil }
	}
	path := liburl.percent_decode(parsed.serialize_path()).bytestr()
	prepared_path := platform.prepare_font_file(path) or { return unsafe { nil } }
	return &PlatformTypeface{
		family_name: family_name.clone()
		source_path: prepared_path.clone()
	}
}

fn resolve_font_face_source_url(source URL, parent_rule ?&CSSFontFaceRule) string {
	rule := parent_rule or { return source.url() }
	sheet := rule.parent_style_sheet or { return source.url() }
	base_url := sheet.base_url or { sheet.base.location or { return source.url() } }
	return resolve_css_url_with_base(source.url(), base_url) or { source.url() }
}

fn platform_load_font_from_bytes_boundary(data []u8, family_name string) &PlatformTypeface {
	prepared_path := platform.prepare_font_data(data) or { return unsafe { nil } }
	return &PlatformTypeface{
		family_name: family_name.clone()
		source_path: prepared_path.clone()
	}
}

fn platform_default_font_boundary(point_size f32, variations FontVariationSettings, shape_features ShapeFeatures) PlatformFont {
	return PlatformFont{
		typeface:   &PlatformTypeface{
			family_name: 'Default'
			weight_: int(variations.weight)
			width_: int(variations.width)
		}
		point_size: point_size
		variations: variations
		features: shape_features
	}
}

fn platform_symbol_font_names_boundary() []string {
	return platform.symbol_font_names_for_environment()
}

fn platform_typefaces_with_family_name_boundary(family_name string, policy platform.FontRenderingPolicy) []&PlatformTypeface {
	if policy == .chromium && platform.system_font_matching_supported() {
		// Missing names (including -apple-system) continue through the author's
		// list. The platform recognizes system-ui and BlinkMacSystemFont.
		resolved_family := family_name
		if !platform.chromium_system_font_family_available(resolved_family) {
			return []
		}
		// The platform resolves the installed face for the requested weight.
		return [
			&PlatformTypeface{
				family_name: resolved_family.clone()
				weight_: 400
			},
			&PlatformTypeface{
				family_name: resolved_family.clone()
				weight_: 700
			},
		]
	}
	if !platform.system_font_family_available(family_name) {
		return []
	}
	regular_path := platform.font_path_for_family(family_name, 400) or { '' }
	bold_path := platform.font_path_for_family(family_name, 700) or { regular_path }
	return [
		&PlatformTypeface{
			family_name: family_name.clone()
			source_path: regular_path
			weight_: 400
		},
		&PlatformTypeface{
			family_name: family_name.clone()
			source_path: bold_path
			weight_: 700
		},
	]
}

fn platform_generic_font_name_boundary(generic_family string, policy platform.FontRenderingPolicy) string {
	return match generic_family.to_lower() {
		'monospace', 'ui-monospace' { 'Monospace' }
		'serif', 'ui-serif' { 'Serif' }
		'fantasy' { 'Fantasy' }
		'cursive' { 'Cursive' }
		'ui-rounded' { 'UiRounded' }
		'ui-sans-serif' {
			// Chromium on macOS leaves this family unavailable. Keep looking
			// through the author's list instead of selecting ordinary sans or
			// system UI and hiding a later explicit family.
			if policy == .chromium && platform.system_font_matching_supported() {
				'ui-sans-serif'
			} else {
				'SansSerif'
			}
		}
		'system-ui' {
			if policy == .chromium && platform.system_font_matching_supported() {
				'SystemUi'
			} else {
				'SansSerif'
			}
		}
		else { 'SansSerif' }
	}
}
