#+feature dynamic-literals
package main

import wesl ".."
import "core:fmt"
import "core:strings"

main :: proc() {
	// print version
	version := wesl.version()
	fmt.printfln("WESL version: %s", version)

	// add some modules
	files := map[string]string {
		"package::main"  = "import package::utils::add;\nfn some_fn_in_main() -> i32 { let a = add(1, 2); return a; }",
		"package::utils" = "fn add(a: i32, b: i32) -> i32 { return a + b; }",
	}

	// setup compile options
	options := wesl.WeslCompileOptions {
		mangler     = .NONE,
		sourcemap   = true,
		imports     = true,
		condcomp    = true,
		generics    = true,
		strip       = false,
		lower       = true,
		validate    = true,
		naga        = true,
		lazy        = false,
		keep_root   = true,
		mangle_root = false,
	}

	// setup features
	features := map[string]bool {
		"debug" = true,
	}

	// compile
	fmt.println("calling wesl_compile...")
	result, ok := wesl.compile(
		files,
		"package::main",
		&options,
		{}, // omit keep array
		features,
	)
	defer wesl.free_result(&result)

	if result.success {
		fmt.println("Compilation successful!")
		fmt.printfln("Output:\n%s", result.data)

		// evaluate
		eval_files := map[string]string {
			"package::source" = "const my_const = 4; @const fn my_fn(v: u32) -> u32 { return v * 10; }",
		}

		fmt.println("\ncalling wesl_eval...")
		eval_options := wesl.WeslCompileOptions{}
		eval_result, eval_ok := wesl.eval(
			eval_files,
			"package::source",
			"my_fn(my_const) + 2",
			&eval_options,
			features,
		)
		defer wesl.free_result(&eval_result)

		if eval_result.success {
			fmt.println("Evaluation successful!")
			fmt.printfln("Result: %s (expected: 42u)", eval_result.data)
			expected := "42u"
			if string(eval_result.data) != expected {
				fmt.printf("ERROR: wesl_eval produced unexpected result\n")
			}
		} else {
			fmt.println("Evaluation failed!")
			fmt.println(eval_result.error.message)
			if eval_result.error.diagnostics_len > 0 {
				fmt.printfln(
					"Diagnostic: %s at %s (%u:%u)",
					eval_result.error.diagnostics[0].title,
					eval_result.error.diagnostics[0].file,
					eval_result.error.diagnostics[0].span_start,
					eval_result.error.diagnostics[0].span_end,
				)
			}
		}
	} else {
		fmt.println("Compilation failed!")
		fmt.println(result.error.message)
		if result.error.diagnostics_len > 0 {
			fmt.printf(
				"Diagnostic: %s at %s (%u:%u)\n",
				result.error.diagnostics[0].title,
				result.error.diagnostics[0].file,
				result.error.diagnostics[0].span_start,
				result.error.diagnostics[0].span_end,
			)
		}
	}
}
