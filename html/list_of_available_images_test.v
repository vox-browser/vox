module html

import dom

@[heap]
struct AvailableImageTestData {
	value u8
}

fn test_list_of_available_images_key_and_storage_algorithms() {
	key := AvailableImageKey{
		url:    'https://example.com/image.png'
		mode:   .anonymous
		origin: dom.Origin{
			value: 'https://example.com'
		}
	}
	other_origin := AvailableImageKey{
		url:    key.url
		mode:   key.mode
		origin: dom.Origin{
			value: 'https://other.example'
		}
	}
	assert key.equals(&key)
	assert !key.equals(&other_origin)

	first_image := &AvailableImageTestData{
		value: 1
	}
	second_image := &AvailableImageTestData{
		value: 2
	}
	mut images := ListOfAvailableImages{}
	images.add(key, voidptr(first_image), false)
	entry := images.get(key) or { panic('missing image') }
	assert entry.image_data == voidptr(first_image)
	assert !entry.ignore_higher_layer_caching
	images.add(key, voidptr(second_image), true)
	replaced := images.get(key) or { panic('missing replacement') }
	assert replaced.image_data == voidptr(second_image)
	assert replaced.ignore_higher_layer_caching
	images.remove(key)
	assert images.get(key) == none
}
