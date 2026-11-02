#pragma once

// Included inside the shared-picture namespace. Tiles contain transparent
// layer ink, never a captured destination. A cache hit still blends against
// this frame's prefix. All keys own their bytes; hashes are only lookup hints.
static bool retained_layer_tiles_enabled()
{
    auto* value = std::getenv("VOX_ENABLE_RETAINED_LAYER_TILES");
    return value && !std::strcmp(value, "1");
}

struct RetainedLayerDraw {
    SkRect bounds;
    std::vector<uint8_t> key;
};

class RetainedLayerCanvas final : public SkNoDrawCanvas {
    SharedRootRecording const& group_;
    SkPictureRecorder recorder_;
    SkCanvas* output_;
    std::vector<uint8_t> clips_;
    std::vector<size_t> saves_;
    size_t key_bytes_ = 0;
    float root_y_;
    template<class T> static void add(std::vector<uint8_t>& key, T const& value)
    {
        auto* bytes = reinterpret_cast<uint8_t const*>(&value);
        key.insert(key.end(), bytes, bytes + sizeof(value));
    }
    bool flatten(std::vector<uint8_t>& key, SkFlattenable const* object)
    {
        uint32_t length = 0;
        sk_sp<SkData> bytes;
        if (object) {
            SkSerialProcs procs;
            procs.fImageProc = serialize_shared_picture_image;
            bytes = object->serialize(&procs);
            if (!bytes || bytes->size() > 65536) return valid = false;
            length = bytes->size();
        }
        add(key, length);
        if (length) {
            auto* data = static_cast<uint8_t const*>(bytes->data());
            key.insert(key.end(), data, data + length);
        }
        return true;
    }
    bool paint_key(std::vector<uint8_t>& key, SkPaint const& paint)
    {
        auto color = paint.getColor4f();
        for (float v : {color.fR, color.fG, color.fB, color.fA}) add(key, v);
        add(key, paint.isAntiAlias()); add(key, paint.isDither());
        add(key, paint.getStyle()); add(key, paint.getStrokeWidth());
        add(key, paint.getStrokeMiter()); add(key, paint.getStrokeCap());
        add(key, paint.getStrokeJoin());
        auto blend = paint.asBlendMode();
        // Destination-reading and custom blending need a different isolation
        // contract. Keep their existing non-retained renderer.
        if (!blend || *blend != SkBlendMode::kSrcOver) return valid = false;
        return flatten(key, paint.getShader()) && flatten(key, paint.getColorFilter())
            && flatten(key, paint.getMaskFilter()) && flatten(key, paint.getImageFilter())
            && flatten(key, paint.getPathEffect());
    }
    SkMatrix matrix()
    {
        auto result = getTotalMatrix();
        if (result.hasPerspective() || !result.isFinite()) { valid = false; return result; }
        auto x = result.getTranslateX(), y = result.getTranslateY();
        // The native rounded-rect recorder already rebases geometry to the
        // layer. Recognize that exact translation before subtracting floats.
        result.setTranslateX(x == group_.origin_x ? 0 : x - group_.origin_x);
        if (y == root_y_) result.setTranslateY(-group_.origin_y);
        else if (y == float(root_y_ + group_.origin_y)) result.setTranslateY(0);
        else result.setTranslateY(y - float(root_y_ + group_.origin_y));
        return result;
    }
    bool begin(uint32_t kind, SkRect bounds, SkPaint const& paint, std::vector<uint8_t>& key)
    {
        if (!valid || !paint.canComputeFastBounds()) return valid = false;
        auto transform = matrix();
        SkRect storage;
        bounds = transform.mapRect(paint.computeFastBounds(bounds, &storage)).makeOutset(2, 2);
        if (!bounds.isFinite() || draws.size() >= 8192) return valid = false;
        add(key, kind);
        float values[9]; transform.get9(values);
        for (float value : values) add(key, value);
        add(key, uint32_t(clips_.size()));
        key.insert(key.end(), clips_.begin(), clips_.end());
        if (!paint_key(key, paint)) return false;
        output_->setMatrix(transform);
        draws.push_back({bounds, {}});
        return true;
    }
    void end(std::vector<uint8_t> key)
    {
        key_bytes_ += key.size();
        if (key.size() > 262144 || key_bytes_ > 4 * 1024 * 1024) valid = false;
        draws.back().key = std::move(key);
    }
    void path_key(std::vector<uint8_t>& key, SkPath const& path)
    {
        size_t length = path.writeToMemory(nullptr);
        if (length > 262144) { valid = false; return; }
        add(key, uint32_t(length));
        size_t start = key.size(); key.resize(start + length);
        path.writeToMemory(key.data() + start);
    }
    void rrect_key(std::vector<uint8_t>& key, SkRRect const& rect)
    {
        uint8_t bytes[SkRRect::kSizeInMemory]; rect.writeToMemory(bytes);
        key.insert(key.end(), bytes, bytes + sizeof(bytes));
    }
    void clip_key(uint32_t kind, SkClipOp op, ClipEdgeStyle edge)
    {
        add(clips_, kind); add(clips_, op); add(clips_, edge);
        float values[9]; matrix().get9(values);
        for (float value : values) add(clips_, value);
        output_->setMatrix(matrix());
        if (clips_.size() > 65536) valid = false;
    }
    bool viewport_clip(SkRect const& rect, SkClipOp op)
    {
        if (op != SkClipOp::kIntersect || !getTotalMatrix().rectStaysRect()) return false;
        auto bounds = getTotalMatrix().mapRect(rect);
        if (!bounds.contains(SkRect::MakeXYWH(0, group_.page_y, group_.viewport_width, group_.viewport_height))) return false;
        for (float v : {bounds.left(), bounds.top(), bounds.right(), bounds.bottom()})
            if (!std::isfinite(v) || v * group_.scale != std::floor(v * group_.scale)) return false;
        return true;
    }
protected:
    void willSave() override { saves_.push_back(clips_.size()); output_->save(); }
    void willRestore() override
    {
        if (saves_.empty()) { valid = false; return; }
        clips_.resize(saves_.back()); saves_.pop_back(); output_->restore();
    }
    SaveLayerStrategy getSaveLayerStrategy(SaveLayerRec const& rec) override
    { valid = false; return SkNoDrawCanvas::getSaveLayerStrategy(rec); }
    bool onDoSaveBehind(SkRect const*) override { valid = false; return false; }
    void onClipRect(SkRect const& rect, SkClipOp op, ClipEdgeStyle edge) override
    {
        if (!viewport_clip(rect, op)) {
            clip_key(1, op, edge); add(clips_, rect);
            output_->clipRect(rect, op, edge == kSoft_ClipEdgeStyle);
        }
        SkNoDrawCanvas::onClipRect(rect, op, edge);
    }
    void onClipRRect(SkRRect const& rect, SkClipOp op, ClipEdgeStyle edge) override
    {
        if (rect.isRect()) { onClipRect(rect.rect(), op, edge); return; }
        clip_key(2, op, edge); rrect_key(clips_, rect);
        output_->clipRRect(rect, op, edge == kSoft_ClipEdgeStyle);
        SkNoDrawCanvas::onClipRRect(rect, op, edge);
    }
    void onClipPath(SkPath const& path, SkClipOp op, ClipEdgeStyle edge) override
    {
        clip_key(3, op, edge); path_key(clips_, path);
        output_->clipPath(path, op, edge == kSoft_ClipEdgeStyle);
        SkNoDrawCanvas::onClipPath(path, op, edge);
    }
    void onClipShader(sk_sp<SkShader>, SkClipOp) override { valid = false; }
    void onClipRegion(SkRegion const&, SkClipOp) override { valid = false; }
    void onResetClip() override { valid = false; }
    void onDrawRect(SkRect const& rect, SkPaint const& paint) override
    { std::vector<uint8_t> k; if (begin(1, rect, paint, k)) { add(k, rect); output_->drawRect(rect, paint); end(std::move(k)); } }
    void onDrawRRect(SkRRect const& rect, SkPaint const& paint) override
    { std::vector<uint8_t> k; if (begin(2, rect.rect(), paint, k)) { rrect_key(k, rect); output_->drawRRect(rect, paint); end(std::move(k)); } }
    void onDrawDRRect(SkRRect const& outer, SkRRect const& inner, SkPaint const& paint) override
    { std::vector<uint8_t> k; if (begin(3, outer.rect(), paint, k)) { rrect_key(k, outer); rrect_key(k, inner); output_->drawDRRect(outer, inner, paint); end(std::move(k)); } }
    void onDrawOval(SkRect const& rect, SkPaint const& paint) override
    { std::vector<uint8_t> k; if (begin(4, rect, paint, k)) { add(k, rect); output_->drawOval(rect, paint); end(std::move(k)); } }
    void onDrawPath(SkPath const& path, SkPaint const& paint) override
    { std::vector<uint8_t> k; if (path.isInverseFillType()) { valid = false; return; } if (begin(5, path.getBounds(), paint, k)) { path_key(k, path); output_->drawPath(path, paint); end(std::move(k)); } }
    void onDrawTextBlob(SkTextBlob const* blob, SkScalar x, SkScalar y, SkPaint const& paint) override
    {
        std::vector<uint8_t> k;
        if (!blob) { valid = false; return; }
        if (begin(6, blob->bounds().makeOffset(x, y), paint, k)) {
            add(k, blob->uniqueID()); add(k, x); add(k, y);
            output_->drawTextBlob(blob, x, y, paint); end(std::move(k));
        }
    }
    void onDrawImageRect2(SkImage const* image, SkRect const& src, SkRect const& dst,
        SkSamplingOptions const& sampling, SkPaint const* paint, SrcRectConstraint constraint) override
    {
        std::vector<uint8_t> k; SkPaint plain;
        if (!image || sampling.isAniso()) { valid = false; return; }
        if (begin(7, dst, paint ? *paint : plain, k)) {
            add(k, image->uniqueID()); add(k, src); add(k, dst); add(k, constraint);
            add(k, sampling.useCubic); add(k, sampling.cubic.B); add(k, sampling.cubic.C);
            add(k, sampling.filter); add(k, sampling.mipmap);
            image_bytes += size_t(image->width()) * image->height() * 4;
            output_->drawImageRect(image, src, dst, sampling, paint, constraint); end(std::move(k));
        }
    }
    void onDrawImage2(SkImage const* image, SkScalar x, SkScalar y,
        SkSamplingOptions const& sampling, SkPaint const* paint) override
    {
        // drawImage has a distinct mipmap/sampling contract. Until represented
        // directly in the canonical stream, leave it on the original path.
        valid = false;
    }
    void onDrawPicture(SkPicture const* picture, SkMatrix const* transform, SkPaint const* paint) override
    {
        if (!picture || paint) { valid = false; return; }
        save(); if (transform) concat(*transform); picture->playback(this); restore();
    }
    // SkNoDrawCanvas intentionally drops these operations. Explicitly decline
    // them so an unfamiliar picture can never become an incomplete cache hit.
    void onDrawPaint(SkPaint const&) override { valid = false; }
    void onDrawBehind(SkPaint const&) override { valid = false; }
    void onDrawPoints(PointMode, size_t, SkPoint const[], SkPaint const&) override { valid = false; }
    void onDrawRegion(SkRegion const&, SkPaint const&) override { valid = false; }
    void onDrawArc(SkRect const&, SkScalar, SkScalar, bool, SkPaint const&) override { valid = false; }
    void onDrawDrawable(SkDrawable*, SkMatrix const*) override { valid = false; }
    void onDrawPatch(SkPoint const[12], SkColor const[4], SkPoint const[4], SkBlendMode, SkPaint const&) override { valid = false; }
    void onDrawImageLattice2(SkImage const*, Lattice const&, SkRect const&, SkFilterMode, SkPaint const*) override { valid = false; }
    void onDrawAtlas2(SkImage const*, SkRSXform const[], SkRect const[], SkColor const[], int, SkBlendMode, SkSamplingOptions const&, SkRect const*, SkPaint const*) override { valid = false; }
    void onDrawVerticesObject(SkVertices const*, SkBlendMode, SkPaint const&) override { valid = false; }
    void onDrawMesh(SkMesh const&, sk_sp<SkBlender>, SkPaint const&) override { valid = false; }
    void onDrawShadowRec(SkPath const&, SkDrawShadowRec const&) override { valid = false; }
    void onDrawEdgeAAQuad(SkRect const&, SkPoint const[4], QuadAAFlags, SkColor4f const&, SkBlendMode) override { valid = false; }
    void onDrawEdgeAAImageSet2(ImageSetEntry const[], int, SkPoint const[], SkMatrix const[], SkSamplingOptions const&, SkPaint const*, SrcRectConstraint) override { valid = false; }
    void onDrawSlug(sktext::gpu::Slug const*, SkPaint const&) override { valid = false; }
public:
    bool valid = true;
    size_t image_bytes = 0;
    std::vector<RetainedLayerDraw> draws;
    explicit RetainedLayerCanvas(SharedRootRecording const& group)
        : SkNoDrawCanvas(SkIRect::MakeLTRB(-32768, -32768, 32768, 32768)), group_(group),
          output_(recorder_.beginRecording(SkRect::MakeLTRB(-32768, -32768, 32768, 32768))),
          root_y_(float(group.page_y - group.scroll_y)) { }
    sk_sp<SkPicture> finish() { return recorder_.finishRecordingAsPicture(); }
};

struct RetainedLayerTilePixels {
    VoxRasterSnapshot pixels;
    int width, height;
    explicit RetainedLayerTilePixels(std::vector<uint32_t> const& input, int w, int h)
        : pixels(reinterpret_cast<uint8_t const*>(input.data()), size_t(w) * 4, size_t(w) * 4, h),
          width(w), height(h) { }
};

class RetainedLayerTileCache {
    struct Entry {
        uint64_t hash;
        std::vector<uint8_t> key;
        std::shared_ptr<RetainedLayerTilePixels const> pixels;
        sk_sp<SkPicture> owner;
        size_t cost;
    };
    using Entries = std::list<Entry>;
    Entries entries_;
    std::unordered_multimap<uint64_t, Entries::iterator> index_;
    size_t bytes_ = 0;
    static uint64_t hash(std::vector<uint8_t> const& key)
    {
        uint64_t value = 14695981039346656037ull;
        for (auto byte : key) value = (value ^ byte) * 1099511628211ull;
        return value;
    }
public:
    void clear() { index_.clear(); entries_.clear(); bytes_ = 0; }
    std::shared_ptr<RetainedLayerTilePixels const> find(std::vector<uint8_t> const& key)
    {
        auto candidates = index_.equal_range(hash(key));
        for (auto it = candidates.first; it != candidates.second; ++it) {
            auto entry = it->second;
            if (entry->key != key) continue;
            auto pixels = entry->pixels; entries_.splice(entries_.begin(), entries_, entry); return pixels;
        }
        return {};
    }
    void insert(std::vector<uint8_t> key, std::shared_ptr<RetainedLayerTilePixels const> pixels,
        sk_sp<SkPicture> owner, size_t resources)
    {
        size_t cost = key.capacity() + pixels->pixels.size() + owner->approximateBytesUsed() + resources;
        constexpr size_t limit = 64 * 1024 * 1024;
        if (cost > limit / 2) return;
        while (!entries_.empty() && (bytes_ + cost > limit || entries_.size() >= 2048)) {
            auto last = std::prev(entries_.end());
            auto candidates = index_.equal_range(last->hash);
            for (auto it = candidates.first; it != candidates.second; ++it)
                if (it->second == last) { index_.erase(it); break; }
            bytes_ -= last->cost; entries_.pop_back();
        }
        auto value = hash(key);
        bytes_ += cost; entries_.push_front({value, std::move(key), std::move(pixels), std::move(owner), cost});
        index_.emplace(value, entries_.begin());
    }
};
RetainedLayerTileCache s_retained_layer_tiles;
void clear_retained_layer_tiles() { s_retained_layer_tiles.clear(); }

static bool draw_retained_layer_tiles(SharedRootRecording const& group, SkPicture const* picture,
    std::vector<uint32_t>& output, int width, int height, float left, float top)
{
    if (!retained_layer_tiles_enabled() || !group.speculative || group.root
        || !picture_regions_draw() || group.tile_width <= 2 || group.tile_height <= 2
        || size_t(group.tile_width) * group.tile_height > 1024 * 1024) return false;
    RetainedLayerCanvas canvas(group); picture->playback(&canvas);
    auto canonical = canvas.finish();
    if (!canvas.valid || !canonical || canvas.draws.empty()) return false;
    float world_x = group.origin_x, world_y = float(group.origin_y + group.page_y - group.scroll_y);
    float device_x = world_x * group.scale, device_y = world_y * group.scale;
    int anchor_x = std::floor(device_x), anchor_y = std::floor(device_y);
    float phase_x = device_x - anchor_x, phase_y = device_y - anchor_y;
    int first_x = std::lround(left * group.scale) - anchor_x;
    int first_y = std::lround(top * group.scale) - anchor_y;
    int tw = group.tile_width, th = group.tile_height, step_x = tw - 2, step_y = th - 2;
    auto owner = [](int value, int step) { return int(std::floor(double(value - 1) / step)); };
    struct Tile {
        int x, y;
        std::vector<uint8_t> key;
        std::shared_ptr<RetainedLayerTilePixels const> pixels;
        std::shared_ptr<std::vector<uint32_t>> raster;
    };
    std::vector<Tile> tiles;
    int hits = 0, misses = 0;
    size_t raster_area = 0;
    for (int row = owner(first_y, step_y); row <= owner(first_y + height - 1, step_y); ++row) {
        for (int col = owner(first_x, step_x); col <= owner(first_x + width - 1, step_x); ++col) {
            Tile tile {col * step_x, row * step_y, {}, {}, {}};
            if (tiles.size() >= 64) return false;
            auto append = [&](auto value) {
                auto* bytes = reinterpret_cast<uint8_t const*>(&value);
                tile.key.insert(tile.key.end(), bytes, bytes + sizeof(value));
            };
            append(tw); append(th); append(group.scale); append(phase_x); append(phase_y);
            append(tile.x); append(tile.y);
            // Key every operation affecting the complete tile, even when the
            // current viewport exposes only part of it. Missing/changed culled
            // operations change that key; unchanged input can reuse edge tiles.
            auto bounds = SkRect::MakeXYWH((tile.x - phase_x) / group.scale,
                (tile.y - phase_y) / group.scale, tw / group.scale, th / group.scale);
            for (auto const& draw : canvas.draws) {
                if (!SkRect::Intersects(bounds, draw.bounds)) continue;
                append(uint32_t(draw.key.size()));
                tile.key.insert(tile.key.end(), draw.key.begin(), draw.key.end());
                if (tile.key.size() > 1024 * 1024) return false;
            }
            tile.pixels = s_retained_layer_tiles.find(tile.key);
            if (tile.pixels) ++hits;
            else {
                ++misses; raster_area += size_t(tw) * th;
                if (raster_area > 8 * 1024 * 1024) return false;
                tile.raster = std::make_shared<std::vector<uint32_t>>(size_t(tw) * th);
            }
            tiles.push_back(std::move(tile));
        }
    }
    if (misses) {
        SkSerialProcs procs;
        procs.fImageProc = serialize_shared_picture_image;
        procs.fTypefaceProc = vox_serialize_picture_typeface;
        auto bytes = canonical->serialize(&procs);
        if (!bytes || bytes->size() > 64 * 1024 * 1024) return false;
        std::vector<VoxGraphitePictureRegion> regions;
        for (auto const& tile : tiles) {
            if (!tile.raster) continue;
            VoxGraphitePictureRegion region {};
            region.output = {0, 0, tw, th, tw * 4, reinterpret_cast<uint8_t*>(tile.raster->data())};
            region.bytes = bytes->data(); region.size = bytes->size();
            float matrix[] {group.scale, 0, phase_x - tile.x, 0, group.scale, phase_y - tile.y, 0, 0, 1};
            std::copy(matrix, matrix + 9, region.matrix); regions.push_back(region);
        }
        if (!picture_regions_draw()(regions.data(), regions.size(), tw, th)) return false;
    }
    for (auto& tile : tiles) {
        if (tile.raster) {
            tile.pixels = std::make_shared<RetainedLayerTilePixels>(*tile.raster, tw, th);
            s_retained_layer_tiles.insert(std::move(tile.key), tile.pixels, canonical, canvas.image_bytes);
        }
        int x0 = std::max(first_x, tile.x + 1), x1 = std::min(first_x + width, tile.x + tw - 1);
        int y0 = std::max(first_y, tile.y + 1), y1 = std::min(first_y + height, tile.y + th - 1);
        if (x1 > x0 && y1 > y0 && !tile.pixels->pixels.copy_region_to(
                reinterpret_cast<uint8_t*>(output.data() + size_t(y0 - first_y) * width + x0 - first_x),
                tw, th, size_t(width) * 4,
                {size_t(x0 - tile.x), size_t(y0 - tile.y), size_t(x1 - tile.x), size_t(y1 - tile.y)})) return false;
    }
    if (std::getenv("VOX_RETAINED_LAYER_TILES_DIAGNOSTICS"))
        std::fprintf(stderr, "VOX_RETAINED_LAYER_TILES hits=%d misses=%d raster_pixels=%zu draws=%zu phase_x=%.9g phase_y=%.9g t_us=%.3f\n",
            hits, misses, raster_area, canvas.draws.size(), phase_x, phase_y, speculative_picture_time());
    return true;
}
