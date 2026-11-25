module css

import dom
import platform

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn test_stylesheet_conversion_preserves_supplied_media_owner_and_default() {
	mut media := MediaList.create_empty()
	media.set_media_text('screen')
	sheet := parse_css_stylesheet_in_workspace(ParsingParams{}, 'a { color: red; }',
		'https://workspace.test/style.css', media, false)
	assert voidptr(sheet.base.media) == voidptr(media)
	assert sheet.base.media.media_text() == 'screen'
	assert sheet.base.location or { '' } == 'https://workspace.test/style.css'
	owner := media.associated_style_sheet or { panic('missing media owner') }
	assert voidptr(owner) == voidptr(sheet)
	default_sheet := parse_css_stylesheet_in_workspace(ParsingParams{}, 'b { color: blue; }',
		none, none, false)
	assert default_sheet.base.media.length() == 0
	default_owner := default_sheet.base.media.associated_style_sheet or { panic('missing default media owner') }
	assert voidptr(default_owner) == voidptr(default_sheet)
}

fn test_stylesheet_conversion_workspace_preserves_retained_rule_payloads() {
	sources := [
		'@namespace s url("http://www.w3.org/2000/svg"); s|svg[data-word="中"] { content: "hello\\20 world"; --x: f([a], var(--b, 2px)); width: var(--x); }',
		'@media (width > 1px) { @supports (display: grid) { a:hover { color: red !important; } } } @scope (.root) to (.end) { .child { height: 3px; } }',
		'@mEdIa (width > 1px) { @SuPpOrTs (display: grid) { @ScOpE ([data-word="中"]) to ([data-end="終"]) { .child { height: 3px; } } } }',
		'@font-face { font-family: "Probe Font"; src: url("probe.woff2"); font-weight: 400; }',
		'@property --size { syntax: "<length>"; inherits: true; initial-value: 2px; }',
		'@counter-style probe { system: cyclic; symbols: "a" "中"; suffix: ". "; }',
		'@function --double(--x <length>: calc(2px + 3px)) returns <length> { @media (width > 1px) { result: var(--x); } }',
		'@page :first { margin: 1cm; @top-left { content: "page"; } }',
		'@keyframes probe { from { transform: translateX(1px); } 100% { transform: translateX(2px); } }',
	]
	for source in sources {
		mut legacy := RuleSelectorParser.create(ParsingParams{}, source, 'utf-8')
		expected := legacy.parse_as_css_stylesheet('https://workspace.test/style.css', none)
		actual := parse_css_stylesheet_in_workspace(ParsingParams{}, source, 'https://workspace.test/style.css', none, false)
		$if gcboehm ? {
			C.GC_gcollect()
		}
		assert actual.css_rules().length() == expected.css_rules().length()
		assert actual.css_rules().length() > 0
		for index, rule in actual.css_rules().rules {
			assert rule.css_text() == expected.css_rules().rules[index].css_text()
		}
	}
}

fn test_font_face_descriptors_outlive_conversion_input_and_workspace() {
	source := r'@font-face {
		font-family: Old;
		font-family: Retained Probe;
		src: local("Fallback Name"),
			url("../probe.woff2" cross-origin(anonymous) referrer-policy(no-referrer) integrity("sha384-example"))
			format(woff2) tech(features-opentype);
		font-style: oblique 18deg;
		font-weight: 300 650;
		font-width: 80%;
		font-display: swap;
		unicode-range: U+0020-007E, U+1F600;
		font-feature-settings: "kern" 0, "liga" 1;
		font-variation-settings: "wght" 412;
		font-language-override: "ENG";
		font-named-instance: "Display";
		ascent-override: 91%;
		descent-override: 21%;
		line-gap-override: 0%;
	}'
	location := 'https://workspace.test/fonts/main.css'
	mut legacy := RuleSelectorParser.create(ParsingParams{}, source, 'utf-8')
	expected := legacy.parse_as_css_stylesheet(location, none)
	input := platform.begin_thread_scratch('stylesheet face test source')
	defer { input.finish() }
	temporary := source.clone()
	input.leave()
	actual := parse_css_stylesheet_in_workspace(ParsingParams{}, temporary, location, none, true)
	input.finish()

	face_rule := actual.css_rules().rules[0].kind_data().font_face_rule?
	expected_rule := expected.css_rules().rules[0].kind_data().font_face_rule?
	assert face_rule.serialized() == expected_rule.serialized()
	face := face_rule.font_face()
	assert face.font_family_ == 'Retained Probe'
	assert face.weight_? == FontWeightRange{min: 300, max: 650}
	assert face.width_? == 80
	assert face.sources_.len == 2
	assert face.sources_[0].value == 'Fallback Name'
	remote := face.sources_[1]
	source_url := remote.url?
	assert source_url.url() == '../probe.woff2'
	assert remote.format? == 'woff2'
	assert remote.tech == [FontTech.features_opentype]
	assert source_url.request_url_modifiers().map(it.to_string())
		== ['cross-origin(anonymous)', 'integrity("sha384-example")', 'referrer-policy(no-referrer)']
	assert face.unicode_ranges_ == [UnicodeRange{0x20, 0x7e}, UnicodeRange{0x1f600, 0x1f600}]
	assert face.font_display_ == .swap
	assert face.font_feature_settings_? == {'kern': i64(0), 'liga': i64(1)}
	assert face.font_variation_settings_? == {'wght': f64(412)}
	assert face.font_language_override_? == 'ENG'
	assert face.font_named_instance_? == 'Display'
}

fn test_deferred_workspace_declarations_keep_source_without_token_trees() {
	source := '.probe { width: 1/**/px; height: 2px !important; --word: "hello\\20 world"; --empty: ; background: url("../image.png"); padding: var(--size, calc(2px + 3%)); }'
	sheet := parse_css_stylesheet_in_workspace(ParsingParams{}, source, 'https://workspace.test/css/theme.css', none, true)
	rule := sheet.css_rules().item(0) or { panic('missing rule') }
	style := rule.declaration or { panic('missing declaration') }
	deferred := style.deferred_declarations_ or { panic('expected lazy declaration') }
	$if prealloc {
		assert deferred.declarations.len == 0
		assert deferred.source_declarations.len == 6
		assert deferred.source_declarations[0].text == '1/**/px'
	}
	$if gcboehm ? {
		C.GC_gcollect()
	}
	assert style.get_property_value('width') == ''
	assert style.get_property_value('height') == '2px'
	assert style.get_property_priority('height') == 'important'
	assert style.get_property_value('--word') == '"hello\\20 world"'
	assert style.get_property_value('--empty') == ''
	assert style.get_property_value('padding').contains('calc(2px + 3%)')
	property := style.get_property(.background_image) or { panic('missing image') }
	assert property.value.base_url or { '' } == 'https://workspace.test/css/theme.css'
	assert style.deferred_declarations_ == none
}

fn test_stylesheet_conversion_retires_discarded_large_token_input() {
	$if prealloc {
		mut document := dom.Document.create(dom.url_about_blank())
		document.enable_native_storage()
		mut small_growth := i64(0)
		for count in [1, 1, 8192] {
			source := '/*' + 'discarded comment '.repeat(count) + '*/ a { color: red; }'
			mut owner := document.enter_native_storage()
			before := document.native_storage().arena.usage().used
			sheet := parse_css_stylesheet_in_workspace(ParsingParams{}, source, none, none, false)
			growth := document.native_storage().arena.usage().used - before
			if count == 1 {
				small_growth = growth
			} else {
				assert growth < small_growth + 32768, '${growth} retained versus ${small_growth}'
			}
			assert sheet.css_rules().length() == 1
			assert sheet.css_rules().rules[0].style()?.get_property_value('color') == 'red'
			owner.finish()
		}
		document.release_native_storage()
	}
}

fn test_stylesheet_conversion_retires_ignored_at_rule_preludes() {
	$if prealloc {
		mut document := dom.Document.create(dom.url_about_blank())
		document.enable_native_storage()
		defer { document.release_native_storage() }
		mut small_growth := i64(0)
		for count in [1, 1, 8192] {
			source := '@ignored ' + 'discarded '.repeat(count) + '; a { color: red; }'
			mut owner := document.enter_native_storage()
			before := document.native_storage().arena.usage().used
			sheet := parse_css_stylesheet_in_workspace(ParsingParams{}, source, none, none, false)
			growth := document.native_storage().arena.usage().used - before
			if count == 1 {
				small_growth = growth
			} else {
				assert growth < small_growth + 32768, '${growth} retained versus ${small_growth}'
			}
			assert sheet.css_rules().length() == 1
			assert sheet.css_rules().rules[0].style()?.get_property_value('color') == 'red'
			owner.finish()
		}
	}
}
