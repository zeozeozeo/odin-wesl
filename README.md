<img align="left" width="0px" height="18px"/>
<img src="https://raw.githubusercontent.com/wgsl-tooling-wg/wesl-spec/main/assets/logo/logo-square-dark.svg" align="left" width="100px" height="100px"/>

<h3>odin-wesl</h3>

Odin bindings for the [`wesl-rs`](https://github.com/wgsl-tooling-wg/wesl-rs) compiler (based on `wesl-c`).

[Usage examples](./examples) (ported from `wesl-c`)

### Usage

This is best used with the `vendor:wgpu` package. [WESL](https://wesl-lang.dev/) allows you to to do cool stuff like imports in WGSL shaders:

```wgsl
import package::colors::chartreuse;    // 1. modularize shaders in separate files
import random_wgsl::pcg_2u_3f;         // 2. use shader libraries from npm/cargo

fn random_color(uv: vec2u) -> vec3f {
    var color = pcg_2u_3f(uv);

    @if(DEBUG) color = chartreuse;       // 3. set conditions at runtime or build time

    return color;
}
```
