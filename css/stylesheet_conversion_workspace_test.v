module css

import dom
import platform

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn test_stylesheet_conversion_workspace_preserves_retained_rule_payloads() {
	sources := [
		'@namespace s url("http://www.w3.org/2000/svg"); s|svg[data-word="中"] { content: "hello\\20 world"; --x: f([a], var(--b, 2px)); width: var(--x); }',
		'@media (width > 1px) { @supports (display: grid) { a:hover { color: red !important; } } } @scope (.root) to (.end) { .child { height: 3px; } }',
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
