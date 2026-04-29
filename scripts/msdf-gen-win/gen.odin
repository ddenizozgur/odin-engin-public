package main

import "base:runtime"
import "core:c/libc"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

main :: proc() {
	if len(os.args) < 3 {
		fmt.eprintfln("Usage: odin run gen.odin -file -- <src_folder> <dst_folder>")
		os.exit(1)
	}

	src_folder_path := os.args[1]
	dst_folder_path := os.args[2]

	fd, err := os.open(src_folder_path)
	if err != os.ERROR_NONE {
		fmt.eprintfln("Failed to open src directory: %s", src_folder_path)
		os.exit(1)
	}
	defer os.close(fd)

	if !os.exists(dst_folder_path) {
		make_err := os.make_directory(dst_folder_path)
		if make_err != os.ERROR_NONE {
			fmt.eprintfln("Failed to create dst directory: %s", dst_folder_path)
			os.exit(1)
		}
	}

	file_infos, read_err := os.read_dir(fd, -1, context.allocator)
	if read_err != os.ERROR_NONE {
		fmt.eprintfln("Failed to read directory contents.")
		os.exit(1)
	}
	defer os.file_info_slice_delete(file_infos, context.allocator)

	processed_count := 0

	for fi in file_infos {
		runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

		if fi.type == .Directory do continue

		original_ext := filepath.ext(fi.name)
		ext := strings.to_lower(original_ext)
		if ext != ".ttf" && ext != ".otf" do continue

		name_no_ext := strings.trim_suffix(fi.name, original_ext)

		dst_img_name := fmt.tprintf("%s.png", name_no_ext)
		dst_json_name := fmt.tprintf("%s.json", name_no_ext)

		dst_img, _ := filepath.join({dst_folder_path, dst_img_name}, context.temp_allocator)
		dst_json, _ := filepath.join({dst_folder_path, dst_json_name}, context.temp_allocator)

		fmt.printfln("\n--- Processing: %s ---", fi.name)

		cmd := fmt.tprintf(
			"msdf-atlas-gen.exe -font \"%s\" -type msdf -format png -imageout \"%s\" -json \"%s\" -pxrange 8",
			fi.fullpath,
			dst_img,
			dst_json,
		)

		cmd_cstr := strings.clone_to_cstring(cmd, context.temp_allocator)

		result := libc.system(cmd_cstr)

		if result == 0 {
			fmt.printfln("[SUCCESS] Generated atlas for %s", name_no_ext)
			processed_count += 1
		} else {
			fmt.eprintfln("[ERROR] msdf-atlas-gen failed on %s with code %v", fi.name, result)
		}
	}
}
