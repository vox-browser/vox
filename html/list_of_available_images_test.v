module html

import dom

fn available_image_test_client_update() {}

fn available_image_test_data(width int, bytes []u8) &BitmapDecodedImageData {
	return BitmapDecodedImageData.create([
		BitmapDecodedImageFrame{
			frame: dom.DecodedImageFrame_.create(&dom.Bitmap_{
				width:  width
				height: 1
				data:   bytes.clone()
			})
		},
	], 0, false)
}

fn test_list_of_available_images_key_and_storage_algorithms() {
	key := Key{
		url:    'https://example.com/image.png'
		mode:   .anonymous
		origin: dom.Origin{
			value: 'https://example.com'
		}
	}
	other_origin := Key{
		url:    key.url
		mode:   key.mode
		origin: dom.Origin{
			value: 'https://other.example'
		}
	}
	assert key.equals(&key)
	assert !key.equals(&other_origin)
	assert key.hash() == key.hash()
	assert key.hash() != other_origin.hash()

	first_image := BitmapDecodedImageData.create([
		BitmapDecodedImageFrame{
			frame: dom.DecodedImageFrame_.create(&dom.Bitmap_{
				width:  1
				height: 1
			})
		},
	], 0, false)
	second_image := BitmapDecodedImageData.create([
		BitmapDecodedImageFrame{
			frame: dom.DecodedImageFrame_.create(&dom.Bitmap_{
				width:  2
				height: 1
			})
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

fn test_list_of_available_images_prunes_lru_entries_but_preserves_live_images() {
	old_key := Key{ url: 'https://example.com/old.png' }
	untouched_key := Key{ url: 'https://example.com/untouched.png' }
	protected_key := Key{ url: 'https://example.com/protected.png' }
	old_image := available_image_test_data(1, [u8(1), 2, 3])
	untouched_image := available_image_test_data(2, [u8(1), 2, 3, 4])
	protected_image := available_image_test_data(3, [u8(1), 2, 3, 4, 5])
	mut images := ListOfAvailableImages{}
	images.add(old_key, old_image, false)
	images.add(untouched_key, untouched_image, false)
	images.add(protected_key, protected_image, false)
	assert images.get(old_key) != none
	decoded_image_data_register_client(protected_image, 91, available_image_test_client_update)

	// The live entry is neither counted nor pruned. Of the remaining entries,
	// get() made old_key newer, so untouched_key is evicted first.
	images.prune_to_limits(uint(-1), 1)
	assert images.get(old_key) != none
	assert images.get(untouched_key) == none
	assert images.get(protected_key) != none

	decoded_image_data_unregister_client(protected_image, 91)
	images.prune_to_limits(0, 0)
	assert images.get(old_key) == none
	assert images.get(protected_key) == none
}
