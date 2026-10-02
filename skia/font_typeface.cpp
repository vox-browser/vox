// ABI projection of LibGfx/Font/TypefaceSkia.cpp::load_from_buffer.
#include "font_typeface.h"
#include "include/core/SkData.h"
#include "include/core/SkFontMgr.h"
#include "include/core/SkFontArguments.h"
#include "include/core/SkStream.h"
#include "include/core/SkTypeface.h"
#ifdef __APPLE__
#include "include/ports/SkFontMgr_mac_ct.h"
#else
#include "include/ports/SkFontMgr_empty.h"
#endif

extern "C" int vox_skia_font_typeface_is_valid(uint8_t const* bytes, size_t size, int index)
{
#ifdef __APPLE__
    static auto manager = SkFontMgr_New_CoreText(nullptr);
#else
    static auto manager = SkFontMgr_New_Custom_Empty();
#endif
    auto data = SkData::MakeWithoutCopy(bytes, size);
    SkFontArguments arguments;
    arguments.setCollectionIndex(index);
    auto stream = std::make_unique<SkMemoryStream>(data);
    return manager->makeFromStream(std::move(stream), arguments) != nullptr;
}
