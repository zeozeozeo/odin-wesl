package wesl

import "core:c"
import "core:strings"

when ODIN_OS == .Windows do foreign import wesl_foreign {"lib/wesl-windows-x86_64-msvc-release/wesl_c.lib", "system:kernel32.lib", "system:ntdll.lib", "system:userenv.lib", "system:ws2_32.lib", "system:dbghelp.lib"}
when ODIN_OS == .Linux do foreign import wesl_foreign "lib/wesl-linux-x86_64-gnu-release/wesl_c.a"
// TODO: when ODIN_OS == .Darwin do foreign import wesl_foreign "lib/wesl-i-have-no-clue-release/wesl_c.a"

WeslCompiler :: distinct rawptr
WeslCompileResult :: distinct rawptr

// -- enums

WeslManglerKind :: enum c.int {
	ESCAPE = 0,
	HASH   = 1,
	NONE   = 2,
}

WeslBindingType :: enum c.int {
	UNIFORM            = 0,
	STORAGE            = 1,
	READ_ONLY_STORAGE  = 2,
	FILTERING          = 3,
	NON_FILTERING      = 4,
	COMPARISON         = 5,
	FLOAT              = 6,
	UNFILTERABLE_FLOAT = 7,
	SINT               = 8,
	UINT               = 9,
	DEPTH              = 10,
	WRITE_ONLY         = 11,
	READ_WRITE         = 12,
	READ_ONLY          = 13,
}

// -- structs

WeslBinding :: struct {
	group:    c.uint,
	binding:  c.uint,
	kind:     WeslBindingType,
	data:     [^]u8,
	data_len: c.size_t,
}

WeslCompileOptions :: struct {
	mangler:     WeslManglerKind,
	sourcemap:   bool,
	imports:     bool,
	condcomp:    bool,
	generics:    bool,
	strip:       bool,
	lower:       bool,
	validate:    bool,
	naga:        bool,
	lazy:        bool,
	keep_root:   bool,
	mangle_root: bool,
}

WeslStringMap :: struct {
	keys:   [^]cstring,
	values: [^]cstring,
	len:    c.size_t,
}

WeslBoolMap :: struct {
	keys:   [^]cstring,
	values: [^]bool,
	len:    c.size_t,
}

WeslStringArray :: struct {
	items: [^]cstring,
	len:   c.size_t,
}

WeslBindingArray :: struct {
	items: [^]WeslBinding,
	len:   c.size_t,
}

WeslDiagnostic :: struct {
	file:       cstring,
	span_start: c.uint,
	span_end:   c.uint,
	title:      cstring,
}

WeslError :: struct {
	source:          cstring,
	message:         cstring,
	diagnostics:     [^]WeslDiagnostic,
	diagnostics_len: c.size_t,
}

WeslResult :: struct {
	success: bool,
	data:    cstring,
	error:   WeslError,
}

WeslExecOptions :: struct {
	compile:    WeslCompileOptions,
	entrypoint: cstring,
	resources:  ^WeslBindingArray,
	overrides:  ^WeslStringMap,
}

WeslExecResult :: struct {
	success:   bool,
	resources: ^WeslBindingArray,
	error:     WeslError,
}

@(link_prefix = "wesl_", default_calling_convention = "c")
foreign wesl_foreign {
	create_compiler :: proc() -> ^WeslCompiler ---
	destroy_compiler :: proc(compiler: ^WeslCompiler) ---

	@(link_name = "wesl_compile")
	raw_compile :: proc(files: ^WeslStringMap, root: cstring, options: ^WeslCompileOptions, keep: ^WeslStringArray, features: ^WeslBoolMap) -> WeslResult ---

	@(link_name = "wesl_eval")
	raw_eval :: proc(files: ^WeslStringMap, root: cstring, expression: cstring, options: ^WeslCompileOptions, features: ^WeslBoolMap) -> WeslResult ---

	@(link_name = "wesl_exec")
	raw_exec :: proc(files: ^WeslStringMap, root: cstring, entrypoint: cstring, options: ^WeslCompileOptions, resources: ^WeslBindingArray, overrides: ^WeslStringMap, features: ^WeslBoolMap) -> WeslExecResult ---

	free_string :: proc(ptr: cstring) ---
	free_result :: proc(result: ^WeslResult) ---
	free_compile_result :: proc(result: ^WeslCompileResult) ---
	free_exec_result :: proc(result: ^WeslExecResult) ---

	@(link_name = "wesl_version")
	raw_version :: proc() -> cstring ---
}

// -- helpers

@(private)
_make_string_map :: proc(m: map[string]string, allocator := context.allocator) -> WeslStringMap {
	if len(m) == 0 {
		return {}
	}

	keys := make([]cstring, len(m), allocator)
	values := make([]cstring, len(m), allocator)

	i := 0
	for k, v in m {
		keys[i] = strings.clone_to_cstring(k)
		values[i] = strings.clone_to_cstring(v)
		i += 1
	}

	return WeslStringMap{keys = raw_data(keys), values = raw_data(values), len = c.size_t(len(m))}
}

@(private)
_free_string_map :: proc(m: ^WeslStringMap, allocator := context.allocator) {
	for i in 0 ..< m.len {
		delete(m.keys[i], allocator)
		delete(m.values[i], allocator)
	}
}

@(private)
_make_bool_map :: proc(m: map[string]bool, allocator := context.allocator) -> WeslBoolMap {
	if len(m) == 0 {
		return {}
	}

	keys := make([]cstring, len(m), allocator)
	values := make([]bool, len(m), allocator)

	i := 0
	for k, v in m {
		keys[i] = strings.clone_to_cstring(k, allocator)
		values[i] = v
		i += 1
	}

	return WeslBoolMap{keys = raw_data(keys), values = raw_data(values), len = c.size_t(len(m))}
}

@(private)
_free_bool_map :: proc(m: ^WeslBoolMap, allocator := context.allocator) {
	for i in 0 ..< m.len do delete(m.keys[i], allocator)
}

@(private)
_make_string_array :: proc(arr: []string, allocator := context.allocator) -> WeslStringArray {
	if len(arr) == 0 {
		return {}
	}

	cstrings := make([]cstring, len(arr), allocator)
	for s, i in arr {
		cstrings[i] = strings.clone_to_cstring(s, allocator)
	}

	return WeslStringArray{items = raw_data(cstrings), len = c.size_t(len(arr))}
}

@(private)
_free_string_array :: proc(arr: ^WeslStringArray, allocator := context.allocator) {
	for i in 0 ..< arr.len do delete(arr.items[i], allocator)
}

// -- wrappers

compile :: proc(
	files: map[string]string,
	root: string,
	options: ^WeslCompileOptions,
	keep: []string = {},
	features: map[string]bool = {},
) -> (
	result: WeslResult,
	ok: bool,
) {
	temp_allocator := context.temp_allocator

	files_map := _make_string_map(files, temp_allocator)
	defer _free_string_map(&files_map, temp_allocator)
	keep_array := _make_string_array(keep, temp_allocator)
	defer _free_string_array(&keep_array, temp_allocator)
	features_map := _make_bool_map(features, temp_allocator)
	defer _free_bool_map(&features_map, temp_allocator)

	root_cstr := strings.clone_to_cstring(root, temp_allocator)
	defer delete(root_cstr, temp_allocator)

	raw_result := raw_compile(&files_map, root_cstr, options, &keep_array, &features_map)
	return raw_result, raw_result.success
}

eval :: proc(
	files: map[string]string,
	root: string,
	expression: string,
	options: ^WeslCompileOptions,
	features: map[string]bool = {},
) -> (
	result: WeslResult,
	ok: bool,
) {
	temp_allocator := context.temp_allocator

	files_map := _make_string_map(files, temp_allocator)
	defer _free_string_map(&files_map, temp_allocator)
	features_map := _make_bool_map(features, temp_allocator)
	defer _free_bool_map(&features_map, temp_allocator)

	root_cstr := strings.clone_to_cstring(root, temp_allocator)
	defer delete(root_cstr, temp_allocator)

	expression_cstr := strings.clone_to_cstring(expression, temp_allocator)
	defer delete(expression_cstr, temp_allocator)

	raw_result := raw_eval(&files_map, root_cstr, expression_cstr, options, &features_map)
	return raw_result, raw_result.success
}

exec :: proc(
	files: map[string]string,
	root: string,
	entrypoint: string,
	options: ^WeslCompileOptions,
	resources: ^WeslBindingArray,
	overrides: map[string]string = {},
	features: map[string]bool = {},
) -> (
	result: WeslExecResult,
	ok: bool,
) {
	temp_allocator := context.temp_allocator

	files_map := _make_string_map(files, temp_allocator)
	defer _free_string_map(&files_map, temp_allocator)
	overrides_map := _make_string_map(overrides, temp_allocator)
	defer _free_string_map(&overrides_map, temp_allocator)
	features_map := _make_bool_map(features, temp_allocator)
	defer _free_bool_map(&features_map, temp_allocator)

	root_cstr := strings.clone_to_cstring(root, temp_allocator)
	defer delete(root_cstr, temp_allocator)

	entrypoint_cstr := strings.clone_to_cstring(entrypoint, temp_allocator)
	defer delete(entrypoint_cstr, temp_allocator)

	// Call the raw function
	raw_result := raw_exec(
		&files_map,
		root_cstr,
		entrypoint_cstr,
		options,
		resources,
		&overrides_map,
		&features_map,
	)

	return raw_result, raw_result.success
}

version :: proc() -> string {
	return string(raw_version())
}
