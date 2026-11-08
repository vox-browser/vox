module contentsecuritypolicy

fn test_script_nonces_reject_dangling_link_names_and_values_case_insensitively() {
	for text in ['<link','<LinK','prefix<lInKsuffix'] {
		assert !is_element_nonceable(ElementContext{is_html_or_svg:true,is_script:true,nonce:'abc',attributes:{text:'x'}})
		assert !is_element_nonceable(ElementContext{is_html_or_svg:true,is_script:true,nonce:'abc',attributes:{'data-x':text}})
	}
	assert is_element_nonceable(ElementContext{is_html_or_svg:true,is_script:true,nonce:'abc',attributes:{'data-x':'link'}})
}
