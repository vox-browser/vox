module main

import browserjs
import dom
import html

fn test_canvas_image_sampling_follows_the_embedding_document_rendering_policy() {
	$if !darwin {
		return
	}
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		mut document := html.parse_document('<!doctype html><canvas id="source" width="64" height="48"></canvas><canvas id="target" width="192" height="144"></canvas>')
		document.set_font_rendering_policy(policy)
		mut runtime := browserjs.Runtime.create()
		defer {
			runtime.close()
			document.finalize()
		}
		mut messages := []string{}
		run_document_javascript(document, 'about:blank', [r'
 const input=source.getContext("2d"),output=target.getContext("2d");
 input.fillStyle="#e95f35";input.fillRect(0,0,24,48);
 input.fillStyle="#2878bc";input.fillRect(24,0,16,48);
 input.fillStyle="#f1cb3c";input.fillRect(40,0,24,48);
 input.fillStyle="#161c2a";input.fillRect(16,16,32,16);
 output.drawImage(source,0,0,192,144);
 globalThis.sampledPixels=JSON.stringify([[71,10],[72,10],[47,49],[48,49]].map(
  ([x,y])=>Array.from(output.getImageData(x,y,1,1).data)));
 '], runtime, mut messages)
		assert messages == []
		pixels := runtime.evaluate_host('sampledPixels')!
		if policy == .chromium {
			// Brave's accelerated linear sampler, including the two-axis edge.
			assert pixels == '[[169,103,98,255],[104,112,143,255],[163,73,49,255],[92,50,46,255]]'
		} else {
			assert pixels != '[[169,103,98,255],[104,112,143,255],[163,73,49,255],[92,50,46,255]]'
		}
	}
}
