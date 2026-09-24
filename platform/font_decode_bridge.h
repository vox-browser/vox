#pragma once

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(__APPLE__)

#    include <CoreFoundation/CoreFoundation.h>
#    include <CoreGraphics/CoreGraphics.h>

typedef struct {
    uint32_t tag;
    CFDataRef data;
    size_t length;
    size_t offset;
    uint32_t checksum;
} libweb_v_font_table;

static void libweb_v_font_write_u16(uint8_t* output, size_t offset, uint16_t value)
{
    output[offset] = (uint8_t)(value >> 8);
    output[offset + 1] = (uint8_t)value;
}

static void libweb_v_font_write_u32(uint8_t* output, size_t offset, uint32_t value)
{
    output[offset] = (uint8_t)(value >> 24);
    output[offset + 1] = (uint8_t)(value >> 16);
    output[offset + 2] = (uint8_t)(value >> 8);
    output[offset + 3] = (uint8_t)value;
}

static uint32_t libweb_v_font_checksum(uint8_t const* bytes, size_t length)
{
    uint32_t checksum = 0;
    for (size_t offset = 0; offset < length; offset += 4) {
        uint32_t word = 0;
        for (size_t byte = 0; byte < 4 && offset + byte < length; ++byte)
            word |= (uint32_t)bytes[offset + byte] << (24 - byte * 8);
        checksum += word;
    }
    return checksum;
}

static int libweb_v_font_table_compare(void const* left, void const* right)
{
    uint32_t left_tag = ((libweb_v_font_table const*)left)->tag;
    uint32_t right_tag = ((libweb_v_font_table const*)right)->tag;
    return left_tag < right_tag ? -1 : left_tag > right_tag ? 1
                                                            : 0;
}

// CoreGraphics accepts sfnt, WOFF, and WOFF2 font data. Copying its decoded
// tables into an sfnt container gives the V metrics and HarfBuzz boundaries a
// stable file-backed face without depending on Ladybird's build directory.
static int libweb_v_decode_web_font(char const* input_path, char const* output_path)
{
    int result = 0;
    CGDataProviderRef provider = NULL;
    CGFontRef font = NULL;
    CFArrayRef tags = NULL;
    libweb_v_font_table* tables = NULL;
    uint8_t* output = NULL;
    FILE* file = NULL;

    provider = CGDataProviderCreateWithFilename(input_path);
    if (!provider)
        goto cleanup;
    font = CGFontCreateWithDataProvider(provider);
    if (!font)
        goto cleanup;
    tags = CGFontCopyTableTags(font);
    if (!tags)
        goto cleanup;

    CFIndex table_count_cf = CFArrayGetCount(tags);
    // searchRange and rangeShift are 16-bit byte counts, so an sfnt directory
    // cannot represent more than 4095 sixteen-byte records.
    if (table_count_cf <= 0 || table_count_cf > 4095)
        goto cleanup;
    size_t table_count = (size_t)table_count_cf;
    tables = calloc(table_count, sizeof(libweb_v_font_table));
    if (!tables)
        goto cleanup;

    for (size_t index = 0; index < table_count; ++index) {
        // Despite being a CFArray, CGFontCopyTableTags stores each four-byte
        // tag directly in the pointer-sized array slot rather than wrapping it
        // in a CFNumber.
        tables[index].tag = (uint32_t)(uintptr_t)CFArrayGetValueAtIndex(tags, (CFIndex)index);
        tables[index].data = CGFontCopyTableForTag(font, tables[index].tag);
        if (!tables[index].data)
            goto cleanup;
        CFIndex length = CFDataGetLength(tables[index].data);
        if (length < 0)
            goto cleanup;
        tables[index].length = (size_t)length;
    }
    qsort(tables, table_count, sizeof(libweb_v_font_table), libweb_v_font_table_compare);

    size_t directory_size = 12 + table_count * 16;
    size_t output_size = directory_size;
    for (size_t index = 0; index < table_count; ++index) {
        if (tables[index].length > UINT32_MAX - 3)
            goto cleanup;
        tables[index].offset = output_size;
        size_t padded_length = (tables[index].length + 3) & ~(size_t)3;
        if (output_size > UINT32_MAX - padded_length)
            goto cleanup;
        output_size += padded_length;
    }
    output = calloc(output_size, 1);
    if (!output)
        goto cleanup;

    uint32_t sfnt_version = 0x00010000;
    for (size_t index = 0; index < table_count; ++index) {
        if (tables[index].tag == 0x43464620 || tables[index].tag == 0x43464632) {
            sfnt_version = 0x4f54544f;
            break;
        }
    }
    libweb_v_font_write_u32(output, 0, sfnt_version);
    libweb_v_font_write_u16(output, 4, (uint16_t)table_count);
    uint16_t maximum_power_of_two = 1;
    uint16_t entry_selector = 0;
    while ((uint32_t)maximum_power_of_two * 2 <= table_count) {
        maximum_power_of_two *= 2;
        ++entry_selector;
    }
    libweb_v_font_write_u16(output, 6, (uint16_t)(maximum_power_of_two * 16));
    libweb_v_font_write_u16(output, 8, entry_selector);
    libweb_v_font_write_u16(output, 10, (uint16_t)(table_count * 16 - maximum_power_of_two * 16));

    size_t head_offset = 0;
    for (size_t index = 0; index < table_count; ++index) {
        uint8_t const* data = CFDataGetBytePtr(tables[index].data);
        if (tables[index].length != 0 && !data)
            goto cleanup;
        memcpy(output + tables[index].offset, data, tables[index].length);
        if (tables[index].tag == 0x68656164 && tables[index].length >= 12) {
            head_offset = tables[index].offset;
            memset(output + head_offset + 8, 0, 4);
        }
        tables[index].checksum = libweb_v_font_checksum(output + tables[index].offset,
            (tables[index].length + 3) & ~(size_t)3);
        size_t record = 12 + index * 16;
        libweb_v_font_write_u32(output, record, tables[index].tag);
        libweb_v_font_write_u32(output, record + 4, tables[index].checksum);
        libweb_v_font_write_u32(output, record + 8, (uint32_t)tables[index].offset);
        libweb_v_font_write_u32(output, record + 12, (uint32_t)tables[index].length);
    }
    if (head_offset != 0) {
        uint32_t checksum_adjustment = 0xb1b0afba - libweb_v_font_checksum(output, output_size);
        libweb_v_font_write_u32(output, head_offset + 8, checksum_adjustment);
    }

    file = fopen(output_path, "wb");
    if (!file)
        goto cleanup;
    if (fwrite(output, 1, output_size, file) != output_size)
        goto cleanup;
    if (fclose(file) != 0) {
        file = NULL;
        goto cleanup;
    }
    file = NULL;
    result = 1;

cleanup:
    if (file)
        fclose(file);
    free(output);
    if (tables) {
        for (size_t index = 0; tags && index < (size_t)CFArrayGetCount(tags); ++index) {
            if (tables[index].data)
                CFRelease(tables[index].data);
        }
    }
    free(tables);
    if (tags)
        CFRelease(tags);
    if (font)
        CFRelease(font);
    if (provider)
        CFRelease(provider);
    return result;
}

#else

static int libweb_v_decode_web_font(char const* input_path, char const* output_path)
{
    (void)input_path;
    (void)output_path;
    return 0;
}

#endif
