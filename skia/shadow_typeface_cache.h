#pragma once

#include "include/core/SkTypeface.h"
#include <cstdint>
#include <list>
#include <string>
#include <sys/stat.h>
#include <utility>
#ifdef _WIN32
#include <windows.h>
#endif

// One cache belongs to one raster thread. Entries own their path and typeface;
// no V string, document arena, glyph buffer, or SkFont is retained. File bytes
// provide a second bound alongside entry count (Skia owns its strike cache).
class VoxShadowTypefaceCache {
    struct FileIdentity {
        uint64_t device, inode, size;
        int64_t modified_seconds, changed_seconds;
        int64_t modified_nanoseconds, changed_nanoseconds;

        bool operator==(FileIdentity const&) const = default;
    };
    struct Entry {
        std::string path;
        int face_index;
        FileIdentity file;
        sk_sp<SkTypeface> face;
    };
    std::list<Entry> entries;
    uint64_t bytes = 0;
    size_t entry_limit;
    uint64_t byte_limit;

    static bool identify(char const* path, FileIdentity& identity)
    {
#ifdef _WIN32
        if (!path || !*path) return false;
        int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, nullptr, 0);
        if (!count) return false;
        std::wstring wide(size_t(count), L'\0');
        if (!MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, wide.data(), count))
            return false;
        HANDLE file = CreateFileW(wide.c_str(), FILE_READ_ATTRIBUTES,
            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr,
            OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
        if (file == INVALID_HANDLE_VALUE) return false;
        BY_HANDLE_FILE_INFORMATION info {};
        FILE_BASIC_INFO times {};
        bool valid = GetFileInformationByHandle(file, &info)
            && !(info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
            && GetFileInformationByHandleEx(file, FileBasicInfo, &times, sizeof(times));
        CloseHandle(file);
        if (!valid) return false;
        identity = {uint64_t(info.dwVolumeSerialNumber),
            uint64_t(info.nFileIndexHigh) << 32 | info.nFileIndexLow,
            uint64_t(info.nFileSizeHigh) << 32 | info.nFileSizeLow,
            times.LastWriteTime.QuadPart / 10000000, times.ChangeTime.QuadPart / 10000000,
            times.LastWriteTime.QuadPart % 10000000 * 100,
            times.ChangeTime.QuadPart % 10000000 * 100};
        return true;
#else
        struct stat info;
        if (!path || !*path || stat(path, &info) || !S_ISREG(info.st_mode) || info.st_size < 0)
            return false;
#ifdef __APPLE__
        auto modified = info.st_mtimespec;
        auto changed = info.st_ctimespec;
#else
        auto modified = info.st_mtim;
        auto changed = info.st_ctim;
#endif
        identity = {uint64_t(info.st_dev), uint64_t(info.st_ino), uint64_t(info.st_size),
            int64_t(modified.tv_sec), int64_t(changed.tv_sec),
            int64_t(modified.tv_nsec), int64_t(changed.tv_nsec)};
        return true;
#endif
    }

public:
    explicit VoxShadowTypefaceCache(size_t count = 32, uint64_t budget = 32 * 1024 * 1024)
        : entry_limit(count), byte_limit(budget) { }

    template<class Loader>
    sk_sp<SkTypeface> get(char const* path, int face_index, Loader&& load)
    {
        FileIdentity current {};
        bool regular = identify(path, current);
        if (path) {
            for (auto it = entries.begin(); it != entries.end();) {
                if (it->path != path) {
                    ++it;
                    continue;
                }
                if (!regular || !(it->file == current)) {
                    // Invalidate all retained faces of a replaced/removed file.
                    bytes -= it->file.size;
                    it = entries.erase(it);
                    continue;
                }
                if (it->face_index == face_index) {
                    auto face = it->face;
                    entries.splice(entries.begin(), entries, it);
                    return face;
                }
                ++it;
            }
        }
        auto face = load(path, face_index);
        if (!face || !regular || !entry_limit || !current.size || current.size > byte_limit)
            return face;
        // A load must not publish a face under a pre-replacement file identity.
        FileIdentity after {};
        if (!identify(path, after) || !(current == after))
            return face;
        while (!entries.empty() && (entries.size() >= entry_limit || bytes > byte_limit - current.size)) {
            bytes -= entries.back().file.size;
            entries.pop_back();
        }
        entries.push_front({std::string(path), face_index, current, face});
        bytes += current.size;
        return face;
    }

    size_t entry_count() const { return entries.size(); }
    uint64_t retained_font_bytes() const { return bytes; }
    void clear() { entries.clear(); bytes = 0; }
};
