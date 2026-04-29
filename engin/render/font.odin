package render

import "base:runtime"
import "core:encoding/json"
import "core:fmt"
import "core:image"
import "core:image/png"
import "core:os"

MSDF_Atlas :: struct {
	// dont change var names
	type:                string,
	distanceRange:       f32,
	distanceRangeMiddle: f32,
	size:                f32,
	width, height:       i32,
	yOrigin:             string,
}

MSDF_Metrics :: struct {
	// dont change var names
	emSize:             f32,
	lineHeight:         f32,
	ascender:           f32,
	descender:          f32,
	underlineY:         f32,
	underlineThickness: f32,
}

MSDF_KerningPair :: struct {
	// dont change var names
	unicode1, unicode2: i32,
	advance:            f32,
}

MSDF_Bounds :: struct {
	left, bottom, right, top: f32,
}

MSDF_Glyph :: struct {
	// dont change var names
	unicode:     i32,
	advance:     f32,
	planeBounds: MSDF_Bounds,
	atlasBounds: MSDF_Bounds,
}

MSDF_File :: struct {
	// dont change var names
	atlas:   MSDF_Atlas,
	metrics: MSDF_Metrics,
	glyphs:  []MSDF_Glyph,
	kerning: []MSDF_KerningPair,
}

font_load_from_image :: proc(
	json_path: string,
	img: ^image.Image,
	allocator := context.allocator,
) -> (
	font: Font,
	ok: bool,
) {
	inner :: proc(
		json_path: string,
		img: ^image.Image,
		temp_alloc: runtime.Allocator,
		final_alloc: runtime.Allocator,
	) -> (
		font: Font,
		ok: bool,
	) {
		file_data, file_err := os.read_entire_file(json_path, allocator = temp_alloc)
		if file_err != nil {
			fmt.eprintfln("[ERROR] Failed to read font JSON: %v", json_path)
			return {}, false
		}

		msdf_data: MSDF_File
		if json_err := json.unmarshal(file_data, &msdf_data, allocator = temp_alloc);
		   json_err != nil {
			fmt.eprintfln("[ERROR] Failed to parse MSDF JSON: %v", json_err)
			return {}, false
		}

		atlas_h := cast(f32)msdf_data.atlas.height
		y_flip := msdf_data.atlas.yOrigin == "top"

		font.texture = texture_load_from_image(img) or_return
		font.texture.size.x = cast(int)msdf_data.atlas.width
		font.texture.size.y = cast(int)msdf_data.atlas.height
		font.distance_range = msdf_data.atlas.distanceRange
		font.line_height = msdf_data.metrics.lineHeight
		font.ascender = msdf_data.metrics.ascender
		font.descender = msdf_data.metrics.descender

		font.glyphs = make(map[rune]Glyph, allocator = final_alloc)
		for g in msdf_data.glyphs {
			ab := g.atlasBounds.bottom
			at := g.atlasBounds.top
			if y_flip {
				// (0,0) is bottom-left in UV space
				ab, at = atlas_h - g.atlasBounds.top, atlas_h - g.atlasBounds.bottom
			}
			font.glyphs[cast(rune)g.unicode] = Glyph {
				unicode = cast(rune)g.unicode,
				advance = g.advance,
				pl      = g.planeBounds.left,
				pb      = g.planeBounds.bottom,
				pr      = g.planeBounds.right,
				pt      = g.planeBounds.top,
				al      = g.atlasBounds.left,
				ab      = ab,
				ar      = g.atlasBounds.right,
				at      = at,
			}
		}

		font.kerning = make(map[[2]rune]f32, allocator = final_alloc)
		for k in msdf_data.kerning {
			font.kerning[[2]rune{cast(rune)k.unicode1, cast(rune)k.unicode2}] = k.advance
		}

		return font, true
	}

	if allocator == context.temp_allocator {
		return inner(json_path, img, allocator, allocator)
	}

	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
	return inner(json_path, img, context.temp_allocator, allocator)
}

font_load_from_file :: proc(
	json_path: string,
	img_path: string,
	allocator := context.allocator,
) -> (
	Font,
	bool,
) {
	inner :: proc(
		json_path: string,
		img_path: string,
		temp_alloc: runtime.Allocator,
		final_alloc: runtime.Allocator,
	) -> (
		Font,
		bool,
	) {
		img, img_err := image.load_from_file(img_path, allocator = temp_alloc)
		if img_err != nil {
			fmt.eprintfln("[ERROR] image.load_from_file(): %v", img_err)
			return {}, false
		}
		return font_load_from_image(json_path, img, allocator = final_alloc)
	}

	if allocator == context.temp_allocator {
		return inner(json_path, img_path, allocator, allocator)
	}

	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
	return inner(json_path, img_path, context.temp_allocator, allocator)
}
