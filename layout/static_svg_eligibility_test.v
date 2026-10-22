module layout

import dom
import html

fn static_svg_eligibility_test_source(source string) bool {
	mut document := dom.Document.create(dom.URL{ value: 'https://static-svg.test/image.svg' })
	defer { document.finalize() }
	document.set_content_type('image/svg+xml')
	document.set_document_type(.xml)
	html.parse_xml_document_source(document, source) or { return false }
	return static_svg_document_is_eligible(document)
}

fn test_static_svg_eligibility_accepts_sprite_shapes_gradients_local_use_and_styles() {
	assert static_svg_eligibility_test_source('<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="176" height="811" viewBox="0 0 176 811"><defs><linearGradient id="g" gradientUnits="userSpaceOnUse" gradientTransform="translate(-2 6) scale(3.053)"><stop offset="0" stop-color="red"/><stop offset="100%" stop-color="#069"/></linearGradient><radialGradient id="r" xlink:href="#g" cx=".5" cy=".5" r=".5"/><clipPath id="c"><circle cx="5" cy="5" r="5"/></clipPath></defs><style>.bpetal{opacity:.65}.fcls-1{fill:#069;fill-rule:evenodd} g > path#p, rect {stroke:#000;stroke-width:1px}</style><svg id="nested" y="10" width="100%" viewBox="0 0 20 20"><g clip-path="url(#c)" transform="matrix(-1 0 0 1 20 0)"><path id="p" class="bpetal fcls-1" d="M0 0H20V20H0Z" fill="url(#g)" style="fill:#396"/><use xlink:href="#p" fill="none" transform="rotate(45)"/><rect x="1" y="2" width="5" height="6" rx=".5" fill="#fff"/></g></svg></svg>')
}

fn test_static_svg_colors_accept_only_concrete_named_hexadecimal_and_numeric_values() {
	for color in ['red', 'lime', 'rebeccapurple', 'transparent', '#069', '#12345678',
		'rgb(1 2 3)', 'rgba(1, 2, 3, .5)', 'hsl(120 50% 50%)'] {
		assert static_svg_color_is_eligible(color), color
	}
	for color in ['currentColor', 'CanvasText', 'var(--paint)', 'light-dark(red, blue)',
		'rgb(from red r g b)', 'rgb(calc(1 + 2) 0 0)'] {
		assert !static_svg_color_is_eligible(color), color
	}
}

fn test_static_svg_eligibility_rejects_dynamic_external_and_environment_dependent_sources() {
	for content in [
		'<text>hello</text>',
		'<image href="#local"/>',
		'<foreignObject/>',
		'<script/>',
		'<animate attributeName="fill"/>',
		'<set attributeName="fill"/>',
		'<filter/>',
		'<pattern/>',
		'<path onload="run()"/>',
		'<use href="other.svg#p"/>',
		'<use href="https://example.test/a.svg#p"/>',
		'<path fill="url(other.svg#g)"/>',
		'<path fill="currentColor"/>',
		'<path fill="CanvasText"/>',
		'<rect width="1em"/>',
		'<rect width="1vw"/>',
		'<rect width="calc(1px + 1%)"/>',
		'<path style="fill:var(--paint)"/>',
		'<path style="opacity:env(x)"/>',
		'<path style="font-size:12px"/>',
		'<path style="--paint:red;fill:red"/>',
		'<style>@media(prefers-color-scheme:dark){path{fill:red}}</style>',
		'<style>@import "other.css";</style>',
		'<style>@keyframes a{to{opacity:0}}</style>',
		'<style>path:hover{fill:red}</style>',
		'<style>path:root{fill:red}</style>',
		'<style>path::before{fill:red}</style>',
		'<style>[id=p]{fill:red}</style>',
		'<style>.a{animation:a 1s}</style>',
		'<style>.a{fill:light-dark(red,blue)}</style>',
		'<style>.a{stroke-width:1em}</style>',
		'<style>.a{fill:url(other.svg#g)}</style>',
		'<g xmlns="http://www.w3.org/1999/xhtml"/>',
		'<lineargradient/>',
		'<path FILL="red"/>',
		'<g xml:base="https://other.test/"/>',
		'<?xml-stylesheet href="other.css"?>',
	] {
		assert !static_svg_eligibility_test_source('<svg xmlns="http://www.w3.org/2000/svg">${content}</svg>'), content
	}
}

fn test_static_svg_eligibility_checks_document_siblings_and_namespace_case() {
	assert !static_svg_eligibility_test_source('<?xml-stylesheet href="other.css"?><svg xmlns="http://www.w3.org/2000/svg"/>')
	assert !static_svg_eligibility_test_source('<svg xmlns="http://www.w3.org/1999/xhtml"/>')
	assert !static_svg_eligibility_test_source('<SVG xmlns="http://www.w3.org/2000/svg"/>')
	assert static_svg_eligibility_test_source('<!-- static --><svg xmlns="http://www.w3.org/2000/svg"><path d="M0 0L1 1" fill="#069"/></svg>')
}
