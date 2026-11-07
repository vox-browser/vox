module main

$if vox_document_retention_diagnostics ? {
	#flag -DVOX_DOCUMENT_RETENTION_DIAGNOSTICS
}

import os
import page

#include "@DIR/main_document_release_probe_test.h"

$if gcboehm ? {
	fn C.vox_document_release_run_worker(work fn (voidptr), context voidptr)
	fn C.vox_probe_watch(owner voidptr)
	fn C.vox_probe_explain()
	fn C.vox_probe_set_seed(seed voidptr)
	fn C.vox_probe_histogram(path &char)
	fn C.GC_gcollect_and_unmap()
	fn C.GC_get_heap_size() uint
	fn C.GC_get_free_bytes() uint
}

struct DocumentReleaseProbe {
mut:
	app    &BrowserApp
	markup string
	url    string
	watch  bool
}

fn document_release_probe_install(context voidptr) {
	$if vox_document_retention_diagnostics ? {
		$if darwin {
			$if gcboehm ? {
				mut probe := unsafe { &DocumentReleaseProbe(context) }
				probe.app.install_loaded_page(LoadedPage{ url: probe.url, content_type: 'text/html', markup: probe.markup }, false)
				if probe.watch {
					if id := os.getenv_opt('VOX_PROBE_WATCH_ID') {
						element := probe.app.document.get_element_by_id(id) or { panic('missing ${id}') }
						C.vox_probe_watch(voidptr(element))
					} else {
						C.vox_probe_watch(voidptr(probe.app.document))
					}
				}
			}
		}
	}
}

fn document_release_probe_page() string {
	mut rows := []string{}
	for i in 0 .. 300 {
		rows << '<div class="thread" id="t${i}"><a href="/t/${i}"><img width="20" height="10" src="data:image/gif;base64,R0lGODlhAQABAAAAACw="></a><b>Subject ${i}</b><span class="teaser">Teaser text for thread ${i} with some words</span></div>'
	}
	return '<!doctype html><html><head><style>.thread{display:inline-block;width:150px;margin:4px}.teaser{color:#333}</style></head><body><div id="threads">' +
		rows.join('') + '</div><div id="more"></div><script>' +
		'var more = document.getElementById("more"); var html = ""; for (var i = 0; i < 300; i++) { html += "<p class=extra>Extra " + i + "</p>"; } more.innerHTML = html;' +
		'document.querySelectorAll(".thread").forEach(function (t) { t.addEventListener("click", function () { t.className += " hit"; }); });' +
		'setTimeout(function () { document.body.dataset.ready = "1"; }, 0);' +
		'</script></body></html>'
}

fn test_document_retention_diagnostic_after_navigation() {
	$if vox_document_retention_diagnostics ? {
		$if darwin {
			$if gcboehm ? {
				$if gcboehm ? {
					mut owner := page.Page.create(1) or { panic(err) }
					mut app := &BrowserApp{ page_model: owner, layout_tree_only: os.getenv('VOX_PROBE_FULL_LAYOUT') == '', viewport_width: 800, viewport_height: 600 }
					mut probe := &DocumentReleaseProbe{ app: app, markup: '<!doctype html><p>first</p>', url: 'https://release.test/warm' }
					// Warm global caches with a first page so the measurement excludes them.
					C.vox_document_release_run_worker(document_release_probe_install, probe)
					if os.getenv('VOX_PROBE_SKIP_A') == '' {
						probe.markup = document_release_probe_page()
						probe.url = 'https://release.test/a'
						probe.watch = true
						C.vox_document_release_run_worker(document_release_probe_install, probe)
					}
					probe.watch = false
					probe.markup = '<!doctype html><p>next</p>'
					probe.url = 'https://release.test/b'
					C.vox_document_release_run_worker(document_release_probe_install, probe)
					for _ in 0 .. 3 { C.GC_gcollect_and_unmap() }
					live := C.GC_get_heap_size() - C.GC_get_free_bytes()
					eprintln('probe-test: live ${live >> 20}M after replacing the large page')
					C.vox_probe_set_seed(voidptr(app))
					if path := os.getenv_opt('VOX_PROBE_HISTOGRAM') {
						C.vox_probe_histogram(&char(path.str))
					}
					C.vox_probe_explain()
					assert app.document != unsafe { nil }
				}
			}
		}
	}
}
