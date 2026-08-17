module html

import dom

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

	first_image := BitmapDecodedImageData.create([
		BitmapDecodedImageFrame{
			bitmap: &dom.ImmutableBitmap_{
				width:  1
				height: 1
			}
		},
	], 0, false)
	second_image := BitmapDecodedImageData.create([
		BitmapDecodedImageFrame{
			bitmap: &dom.ImmutableBitmap_{
				width:  2
				height: 1
			}
		},
	], 0, false)
	mut images := ListOfAvailableImages{}
	images.add(key, first_image, false)
	entry := images.get(key) or { panic('missing image') }
	assert entry.image_data.intrinsic_width() or { 0 } == 1
	assert !entry.ignore_higher_layer_caching
	images.add(key, second_image, true)
	replaced := images.get(key) or { panic('missing replacement') }
	assert replaced.image_data.intrinsic_width() or { 0 } == 2
	assert replaced.ignore_higher_layer_caching
	images.remove(key)
	assert images.get(key) == none
}
