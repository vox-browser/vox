module css

import platform

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn resource_candidate_test_sheet(source string, deferred bool) &CSSStyleSheet {
	mut parser := RuleSelectorParser.create(ParsingParams{}, source, 'utf-8')
	parser.defer_style_declarations = deferred
	return parser.parse_as_css_stylesheet('https://resource-candidates.test/assets/site.css', none)
}

fn test_resource_candidates_keep_declarations_deferred_and_walk_nested_escaped_tokens() {
	sheet := resource_candidate_test_sheet(r'.unused { background-image:url("icon.png"); --images:image-set("retina.png" 2x, url(unquoted.png) 1x); --nested:var(--other, { deep:url(nested.png) }); --escaped:url("esc\61 ped.png"); color:red; }', true)
	rule := sheet.css_rules().item(0) or { panic('missing rule') }
	declaration := rule.declaration or { panic('missing declaration') }
	retained := declaration.deferred_declarations_ or { panic('declaration was not deferred') }
	$if gcboehm ? { C.GC_gcollect() }
	candidates := declaration.resource_url_candidates('https://wrong-fallback.test/')
	assert candidates.map(it.url) == ['icon.png', 'retina.png', 'unquoted.png', 'nested.png', 'escaped.png']
	assert candidates.all(it.base_url == 'https://resource-candidates.test/assets/site.css')
	assert (declaration.deferred_declarations_ or { panic('resource discovery materialized declarations') }) == retained
	assert declaration.properties.len == 0
	assert declaration.custom_properties.len == 0
}

fn test_resource_candidates_include_parsed_custom_pending_and_cssom_changed_values() {
	sheet := resource_candidate_test_sheet('.paint { background:var(--bg, url(fallback.png)); --bg:image-set("custom.png" 1x); color:red; }', false)
	rule := sheet.css_rules().item(0) or { panic('missing rule') }
	mut declaration := rule.declaration or { panic('missing declaration') }
	declaration.set_property('border-image-source', r'url("cssom\2e png")', '')!
	candidates := declaration.resource_url_candidates('https://resource-candidates.test/assets/site.css')
	assert candidates.any(it.url == 'fallback.png')
	assert candidates.any(it.url == 'custom.png')
	assert candidates.any(it.url == 'cssom.png')
	assert !candidates.any(it.url == 'red')
	assert candidates.all(it.base_url == 'https://resource-candidates.test/assets/site.css')
}

fn test_resource_candidates_preserve_last_stylesheet_base_for_deferred_and_parsed_values() {
	for deferred in [true, false] {
		sheet := resource_candidate_test_sheet('.paint { background-image:url(icon.png) }', deferred)
		mut rule := sheet.css_rules().item(0) or { panic('missing rule') }
		mut other := resource_candidate_test_sheet('', false)
		other.base_url = 'https://resource-candidates.test/replacement/theme.css'
		rule.set_parent_style_sheet(other)
		rule.set_parent_style_sheet(none)
		declaration := rule.declaration or { panic('missing declaration') }
		candidates := declaration.resource_url_candidates('https://wrong-fallback.test/')
		assert candidates.len == 1
		assert candidates[0].url == 'icon.png'
		assert candidates[0].base_url == 'https://resource-candidates.test/replacement/theme.css'
	}
}

fn test_resource_candidates_tokenize_raw_component_and_dom_boundary_values() {
	declaration := &CSSStyleProperties{
		deferred_declarations_: &DeferredStyleDeclaration{
			declarations: [Declaration{
				name: '--raw'
				value: [ComponentValue.new(r'image-set("raw\2e png" 1x, url(other.png) 2x)')]
			}]
		}
	}
	assert declaration.resource_url_candidates('https://raw.test/').map(it.url) == ['raw.png', 'other.png']
	assert declaration.deferred_declarations_ != none
	boundary := &CSSStyleProperties{
		properties: [CSSStyleProperty{name: 'background-image', value: 'URL(boundary.png)'},
			CSSStyleProperty{name: 'width', value: '17px'}]
	}
	assert boundary.resource_url_candidates('https://raw.test/').map(it.url) == ['boundary.png']
}

fn test_typed_svg_path_geometry_is_not_tokenized_as_a_resource_url() {
	path := svg_presentation_path_value('M0 0 ' + 'l1 1 '.repeat(4096)) or {
		panic('missing path fixture')
	}
	value := dom_style_value_from_value_logic(path)
	assert value.css_text.starts_with('path(')
	declaration := &CSSStyleProperties{
		properties: [CSSStyleProperty{name:'d', style_value:value}]
	}
	before := platform.thread_arena_usage().used
	for _ in 0 .. 8 {
		assert declaration.resource_url_candidates('https://geometry.test/').len == 0
	}
	$if prealloc { assert platform.thread_arena_usage().used - before < 4096 }
}
