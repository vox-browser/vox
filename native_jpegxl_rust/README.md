Vox's JPEG XL helper uses the pinned `jxl` 0.7 decoder, also identified in the
installed Brave 156 framework. `Cargo.lock` pins every dependency. macOS production
builds copy and sign `libVoxJPEGXL.dylib` beside Vox; Linux builds install the `.so`
when Cargo is available. Without the helper, decoding reports unsupported input.

The FFI accepts complete static 8-bit sRGB/grayscale codestreams and JXL containers,
applies EXIF orientation, and returns owned, top-down RGBA rows. Image models retain straight alpha; native
painting requests premultiplied output before byte conversion, matching Brave. It rejects
animation, HDR, ICC and wide-gamut profiles. Input and decoded RGBA are each limited
to 64 MiB; the decoder also enforces its sample limit. The caller must release the
buffer with the returned pitch times height. Panics cannot unwind into V/C.

`python3 tools/test_jpegxl.py` runs an ASan/UBSan native driver under memory guards.
The native test uses libjxl only to encode its known test vectors. `main_jpegxl_test.v`
checks request/model/paint-cache alpha handling, and `jpegxl-image-paths.html` covers
image elements, CSS backgrounds, orientation, transparency, clipping and a lossy
Guardian photograph against an independently captured Brave reference.
