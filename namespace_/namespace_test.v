module namespace_

fn test_namespace_urls() {
	assert html == 'http://www.w3.org/1999/xhtml'
	assert svg == 'http://www.w3.org/2000/svg'
	assert mathml == 'http://www.w3.org/1998/Math/MathML'
	assert xlink == 'http://www.w3.org/1999/xlink'
	assert xml == 'http://www.w3.org/XML/1998/namespace'
	assert xmlns == 'http://www.w3.org/2000/xmlns/'
}
