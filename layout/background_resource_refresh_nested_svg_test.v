module layout

import dom
import html

fn test_background_refresh_retains_only_self_contained_nested_svg_images() {
	for source, expected in {
		'<path d="M0 0H18V18H0Z" fill="orange"/>':                                                                         true
		'<defs><path id="shape" d="M0 0H18V18H0Z"/></defs><use href="#shape"/>':                                           true
		'<use href="arrow.svg#shape"/>':                                                                                   false
		'<use href="https://nested-background.test/arrow.svg#shape"/>':                                                    false
		'<image href="https://nested-background.test/arrow.svg"/>':                                                        false
		'<style>rect { background: url(https://nested-background.test/arrow.svg) }</style><rect width="18" height="18"/>': false
		'<rect width="18" height="18"><animate attributeName="width" to="9" dur="1s"/></rect>':                            false
		'<script>void 0</script>':                                                                                         false
	} {
		mut image := dom.Document.create(dom.URL{ value: 'https://nested-background.test/logo.svg' })
		defer { image.finalize() }
		image.set_document_type(.xml)
		image.set_is_svg_image_document(true)
		html.parse_xml_document_source(image, '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18">${source}</svg>')!
		box := BlockBox{
			media_data: retained_block_box_media(BlockBoxMediaData{
				replaced_image_url:       'https://nested-background.test/logo.svg#logo'
				nested_viewport_document: image
			})
		}
		assert background_resource_refresh_supported(&box) == expected
		image.set_is_svg_image_document(false)
		assert !background_resource_refresh_supported(&box)
		image.set_is_svg_image_document(true)
		non_image := BlockBox{
			media_data: retained_block_box_media(BlockBoxMediaData{ nested_viewport_document: image })
		}
		assert !background_resource_refresh_supported(&non_image)
	}
}
