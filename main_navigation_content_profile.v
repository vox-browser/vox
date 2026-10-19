module main

import crypto.sha256
import dom
import json2
import os

struct BrowserNavigationContentProfile {
	url_sha256 string
	elements int
	class_matches int
}

fn navigation_content_profile(document &dom.Document, class_name string) BrowserNavigationContentProfile {
	mut elements := 0
	mut matches := 0
	root := document.as_node()
	mut current := root.first_child()
	for {
		node := current or { break }
		if element := node.as_element() {
			elements++
			if element.has_class(class_name) { matches++ }
		}
		current = node.next_in_pre_order(root)
	}
	return BrowserNavigationContentProfile{
		url_sha256: sha256.hexhash(document.url.serialize())
		elements: elements
		class_matches: matches
	}
}

fn (app &BrowserApp) report_navigation_content_profile() {
	class_name := os.getenv('VOX_PROFILE_CLASS')
	if class_name == '' { return }
	profile := navigation_content_profile(app.document, class_name)
	eprintln('Vox navigation content: ${json2.encode(profile)}')
}
