module browserjs

import dom
import math
import x.json2

fn test_canvas_host_serializes_em_square_and_baseline_metrics() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'canvas')!
	mut host := CanvasHost.create(document)
	host.elements['canvas'] = element
	host.call(r'{"key":"canvas","method":"set","property":"font","value":"80px serif"}')!
	for baseline in ['top', 'middle', 'bottom'] {
		host.call('{"key":"canvas","method":"set","property":"textBaseline","value":"${baseline}"}')!
		response := host.call(r'{"key":"canvas","method":"measureText","args":["Hello"]}')!
		metrics := canvas_host_object(json2.decode[json2.Any](response)!)!
		for property in ['emHeightAscent', 'emHeightDescent', 'hangingBaseline', 'alphabeticBaseline', 'ideographicBaseline'] {
			assert property in metrics, 'missing ${property}'
		}
		ascent := canvas_host_number(metrics['emHeightAscent']!)
		descent := canvas_host_number(metrics['emHeightDescent']!)
		expected_ascent := match baseline {
			'top' { 0.0 }
			'middle' { 40.0 }
			else { 80.0 }
		}
		assert math.abs(ascent - expected_ascent) < 0.0001
		assert math.abs(descent - (80 - expected_ascent)) < 0.0001
	}
}
