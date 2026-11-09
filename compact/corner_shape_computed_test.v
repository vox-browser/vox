module main

import browserjs
import dom
import css

fn test_navigation_cssom_computes_corner_keywords() {
 mut document := parse_browser_navigation_document('<!doctype html><style>#test{corner-shape:bevel;border-radius:999px}</style><div id="test"></div>', dom.URL{value:'https://corner.test/'}, none)
 mut runtime := browserjs.Runtime.create()
 defer { runtime.close(); document.finalize() }
 mut messages := []string{}
 run_document_javascript(document,document.url.serialize(),[r'if(getComputedStyle(document.getElementById("test")).cornerTopLeftShape!=="superellipse(0)")throw Error("computed corner: "+getComputedStyle(document.getElementById("test")).cornerTopLeftShape)'],runtime,mut messages)
 element := document.get_element_by_id('test') or { panic('test') }
 actual := css.up_to_date_computed_properties_for_element(element)
 assert (actual.property(.corner_top_left_shape,.no) or { panic('corner') }).css_text == 'superellipse(0)'
 assert messages == []string{},messages.str()
}
