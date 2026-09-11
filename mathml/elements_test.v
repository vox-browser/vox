module mathml

import dom

fn test_names_are_complete() {
	assert attribute_names.len == 12
	assert attribute_names[5] == 'href'
	assert tag_names.len == 33
	assert tag_names[0] == 'a'
	assert tag_names[2] == 'annotation-xml'
	assert tag_names#[-1] == 'semantics'
}

fn test_mathml_anchor_href_resolves_and_falls_back_to_raw_attribute() {
	mut anchor := MathMLAnchorElement.create(dom.URL{
		value: 'https://example.test/math/page.html'
	})
	assert anchor.href() == ''
	anchor.set_href('../next?q=1#result')
	assert anchor.href() == 'https://example.test/next?q=1#result'
	assert anchor.attribute('href')? == '../next?q=1#result'

	anchor.set_href('http://[:::')
	assert anchor.href() == 'http://[:::'
	anchor.remove_attribute('href')
	assert anchor.href() == ''
}

fn test_mathml_anchor_exposes_hyperlink_components_and_reflected_attributes() {
	mut anchor := MathMLAnchorElement.create(dom.URL{
		value: 'https://base.example/'
	})
	anchor.set_href('https://user:pass@example.test:8443/a?x=1#old')
	assert anchor.origin() == 'https://example.test:8443'
	assert anchor.protocol() == 'https:'
	assert anchor.username() == 'user'
	assert anchor.password() == 'pass'
	assert anchor.host() == 'example.test:8443'
	assert anchor.hostname() == 'example.test'
	assert anchor.port() == '8443'
	assert anchor.pathname() == '/a'
	assert anchor.search() == '?x=1'
	assert anchor.hash() == '#old'

	anchor.set_protocol('http')
	anchor.set_hostname('other.example')
	anchor.set_port('9000')
	anchor.set_pathname('/translated')
	anchor.set_search('?done=yes')
	anchor.set_hash('#ready')
	assert anchor.href() == 'http://user:pass@other.example:9000/translated?done=yes#ready'
	assert anchor.attribute('href')? == anchor.href()

	anchor.set_target('_blank')
	anchor.set_hreflang('en')
	anchor.set_type('text/html')
	assert anchor.target() == '_blank'
	assert anchor.hreflang() == 'en'
	assert anchor.type_() == 'text/html'
	assert anchor.hyperlink_element_utils_element().local_name == 'a'
}

fn test_mathml_anchor_re_resolves_when_its_document_url_changes() {
	mut anchor := MathMLAnchorElement.create(dom.URL{
		value: 'https://first.example/one/'
	})
	anchor.set_href('relative')
	assert anchor.href() == 'https://first.example/one/relative'
	anchor.set_document_url(dom.URL{
		value: 'https://second.example/two/'
	})
	assert anchor.href() == 'https://second.example/two/relative'
}

fn test_common_presentational_hints_and_role() {
	mut element := MathMLElement.create('math')
	element.set_attribute('dir', 'RtL')
	element.set_attribute('mathcolor', 'rgb(1 2 3)')
	element.set_attribute('mathbackground', '#abcdef')
	element.set_attribute('mathsize', '120%')
	element.set_attribute('displaystyle', 'TRUE')
	element.set_attribute('scriptlevel', '-3')
	hints := element.apply_presentational_hints()
	assert element.default_role() or { '' } == 'math'
	assert hints.direction or { '' } == 'rtl'
	assert hints.color != none
	assert hints.background_color != none
	assert hints.font_size or { '' } == '120%'
	assert hints.math_style or { '' } == 'normal'
	assert hints.math_depth or { MathDepthHint{} } == MathDepthHint{.add, -3}
	assert MathMLElement.create('mrow').default_role() == none
}

fn test_invalid_common_hints_are_ignored() {
	mut element := MathMLElement.create('math')
	element.set_attribute('dir', 'auto')
	element.set_attribute('mathcolor', 'not a color')
	element.set_attribute('mathsize', 'medium')
	element.set_attribute('displaystyle', 'yes')
	element.set_attribute('scriptlevel', 'word')
	hints := element.apply_presentational_hints()
	assert hints.direction == none
	assert hints.color == none
	assert hints.font_size == none
	assert hints.math_style == none
	assert hints.math_depth == none
}

fn test_mathml_element_lifecycle_preserves_and_hides_cryptographic_nonce() {
	mut element := MathMLElement.create('math')
	element.set_attribute('nonce', 'secret')
	assert element.nonce() == 'secret'

	mut copy := MathMLElement.create('math')
	copy.attributes = element.attributes.clone()
	element.cloned(mut copy, false)!
	assert copy.nonce() == 'secret'

	element.set_insertion_policy_state(true, true)
	element.inserted()
	assert element.attribute('nonce')? == ''
	assert element.nonce() == 'secret'
	element.remove_attribute('nonce')
	assert element.nonce() == ''

	first := element.global_event_handlers_to_event_target('click')
	second := element.global_event_handlers_to_event_target('input')
	assert voidptr(first) == voidptr(second)
}

fn test_scriptlevel_preserves_html_integer_prefix_parsing() {
	mut element := MathMLElement.create('mrow')
	element.set_attribute('scriptlevel', ' \t+12trailing')
	hint := element.apply_presentational_hints().math_depth or { panic('missing math depth') }
	assert hint == MathDepthHint{.add, 12}
}

fn test_mi_mathvariant_normal_is_ascii_case_insensitive() {
	mut element := MathMLMiElement.create()
	element.set_attribute('mathvariant', 'NoRmAl')
	assert element.is_presentational_hint('mathvariant')
	assert element.apply_presentational_hints().text_transform or { '' } == 'none'
	element.set_attribute('mathvariant', 'bold')
	assert element.apply_presentational_hints().text_transform == none
}

fn test_mspace_length_hints_match_upstream() {
	mut element := MathMLMspaceElement.create()
	element.set_attribute('width', '2em')
	element.set_attribute('height', '3px')
	element.set_attribute('depth', '4px')
	hints := element.apply_presentational_hints()
	assert hints.width or { '' } == '2em'
	assert hints.height or { '' } == 'calc(7px)'

	element.set_attribute('width', '25%')
	element.set_attribute('height', '10%')
	element.remove_attribute('depth')
	hints_without_percentages := element.apply_presentational_hints()
	assert hints_without_percentages.width == none
	assert hints_without_percentages.height == none
}
