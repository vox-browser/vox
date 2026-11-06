// Gfx::Typeface::try_load_from_temporary_memory() rejects data that LibWeb's
// Skia font manager cannot load. These make the same platform calls without
// Skia: SkTypeface_Mac::MakeFromStream() on macOS and
// SkTypeface_FreeType::MakeFromStream() (SkFontScanner_FreeType::scanInstance)
// with the system FreeType elsewhere.
#pragma once

#include <stddef.h>
#include <stdint.h>

#ifdef __APPLE__
#include <CoreText/CoreText.h>

static int vox_typeface_data_is_valid(uint8_t const* data, size_t size, int index)
{
    // CoreText descriptors cannot select a collection member.
    if (index != 0)
        return 0;
    CFDataRef bytes = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, data, (CFIndex)size, kCFAllocatorNull);
    if (!bytes)
        return 0;
    CTFontDescriptorRef descriptor = CTFontManagerCreateFontDescriptorFromData(bytes);
    CFRelease(bytes);
    if (!descriptor)
        return 0;
    CTFontRef font = CTFontCreateWithFontDescriptor(descriptor, 0, NULL);
    CFRelease(descriptor);
    if (!font)
        return 0;
    CFRelease(font);
    return 1;
}
#else
#include <ft2build.h>
#include FT_FREETYPE_H
#include FT_MULTIPLE_MASTERS_H
#include <pthread.h>
#include <stdlib.h>

static int vox_typeface_data_is_valid(uint8_t const* data, size_t size, int index)
{
    static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
    static FT_Library library;
    static int initialized;
    int valid = 0;
    pthread_mutex_lock(&mutex);
    if (!initialized) {
        initialized = 1;
        if (FT_Init_FreeType(&library))
            library = NULL;
    }
    FT_Open_Args arguments = { 0 };
    arguments.flags = FT_OPEN_MEMORY;
    arguments.memory_base = data;
    arguments.memory_size = (FT_Long)size;
    FT_Face face;
    if (library && !FT_Open_Face(library, &arguments, index, &face)) {
        valid = 1;
        // scanInstance() requires the variation axes and their current design
        // coordinates (GetAxes() and GetVariationDesignPosition()).
        if (face->face_flags & FT_FACE_FLAG_MULTIPLE_MASTERS) {
            FT_MM_Var* variations = NULL;
            valid = 0;
            if (!FT_Get_MM_Var(face, &variations)) {
                FT_UInt count = variations->num_axis;
                FT_Fixed* coordinates = (FT_Fixed*)malloc(sizeof(FT_Fixed) * (count ? count : 1));
                valid = coordinates && !FT_Get_Var_Design_Coordinates(face, count, coordinates);
                free(coordinates);
                FT_Done_MM_Var(library, variations);
            }
        }
        FT_Done_Face(face);
    }
    pthread_mutex_unlock(&mutex);
    return valid;
}
#endif
