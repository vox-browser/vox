module html

fn test_pdf_viewer_plugin_and_mime_type_objects() {
	application_pdf := &MimeType{
		type_: 'application/pdf'
	}
	text_pdf := &MimeType{
		type_: 'text/pdf'
	}
	mime_types := [application_pdf, text_pdf]
	plugin := &Plugin{
		name_: 'PDF Viewer'
	}
	assert plugin.description() == 'Portable Document Format'
	assert plugin.filename() == 'internal-pdf-viewer'
	assert plugin.supported_property_names(true) == pdf_viewer_mime_types
	assert plugin.supported_property_names(false).len == 0
	assert plugin.length(mime_types) == 2
	assert plugin.item(0, mime_types)? == application_pdf
	assert plugin.item_value(1, mime_types)? == text_pdf
	assert plugin.item(2, mime_types) == none
	assert plugin.named_item('text/pdf', mime_types)? == text_pdf
	assert plugin.named_item_value('application/pdf', mime_types)? == application_pdf
	assert plugin.named_item('image/png', mime_types) == none
	assert application_pdf.type_name() == 'application/pdf'
	assert application_pdf.type_() == 'application/pdf'
	assert mime_type_type(application_pdf) == 'application/pdf'
	assert application_pdf.description() == 'Portable Document Format'
	assert application_pdf.suffixes() == 'pdf'
	assert application_pdf.enabled_plugin([plugin]) == plugin
}

fn test_pdf_viewer_plugin_and_mime_type_arrays() {
	plugin := &Plugin{
		name_: 'PDF Viewer'
	}
	plugins := PluginArray{
		pdf_viewer_supported:      true
		pdf_viewer_plugin_objects: [plugin]
	}
	assert plugins.supported_property_names() == pdf_viewer_plugin_names
	assert plugins.length() == 1
	assert plugins.item(0)? == plugin
	assert plugins.item_value(0)? == plugin
	assert plugins.item(1) == none
	assert plugins.named_item('PDF Viewer')? == plugin
	assert plugins.named_item_value('PDF Viewer')? == plugin
	assert plugins.named_item('Missing') == none
	plugins.refresh()

	mime_type := &MimeType{
		type_: 'application/pdf'
	}
	mime_types := MimeTypeArray{
		pdf_viewer_supported:         true
		pdf_viewer_mime_type_objects: [mime_type]
	}
	assert mime_types.supported_property_names() == pdf_viewer_mime_types
	assert mime_types.length() == 1
	assert mime_types.item(0)? == mime_type
	assert mime_types.item_value(0)? == mime_type
	assert mime_types.named_item('application/pdf')? == mime_type
	assert mime_types.named_item_value('application/pdf')? == mime_type
	assert mime_types.named_item('text/plain') == none
}
