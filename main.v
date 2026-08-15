module main

import css
import dom
import domurl
import encoding
import fetch
import fileapi
import geolocation
import geometry
import highresolutiontime
import html
import infra
import layout
import mimesniff
import namespace_
import http
import referrerpolicy
import selection
import sri
import storageapi
import url
import webvtt

fn main() {
	_ = css.StyleInvalidationReason.dom_mutation
	_ = dom.NodeType.invalid
	_ = domurl.url_encode
	_ = encoding.TextEncoder.create
	_ = fetch.is_ok_status
	_ = fileapi.Blob.create
	_ = fileapi.File.construct
	_ = fileapi.FileList.create
	_ = geolocation.GeolocationCoordinates.create
	_ = geometry.DOMPoint.construct
	_ = highresolutiontime.coarsen_time
	_ = html.event_load
	_ = http.HeaderList.create
	_ = referrerpolicy.from_string
	_ = infra.ascii_whitespace
	_ = layout.translated_layout_function_count
	_ = layout.AvailableSize.make_indefinite()
	_ = mimesniff.javascript_mime_type_essence_strings
	_ = namespace_.html
	_ = selection.selection_create
	_ = sri.do_bytes_match_metadata_list
	_ = storageapi.registered_endpoints
	_ = url.percent_encode
	_ = webvtt.ScrollSetting.empty
}
