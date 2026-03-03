# Zig build for xiph/rnnoise

## Build script

Run `zig build` to create static and dynamic libraries.
See `zig build -h` for all custom options.
```
Project-Specific Options:
  -Dtarget=[string]            The CPU architecture, OS, and ABI to build for
  -Dcpu=[string]               Target CPU features to add or subtract
  -Dofmt=[string]              Target object format
  -Ddynamic-linker=[string]    Path to interpreter on the target system
  -Doptimize=[enum]            Prioritize performance, safety, or binary size
                                 Supported Values:
                                   Debug
                                   ReleaseSafe
                                   ReleaseFast
                                   ReleaseSmall
  -Dlittle=[bool]              load the little model (default false)
  -Drtcd=[bool]                x86 only option
  -Dassertions=[bool]          (default false)
```

### Usage from Zig

If you're using this library from Zig, import the `rnnoise` module, which will contain
the full implementation and translated C header files which you can use like so:

```zig
const rnnoise = @import("rnnoise");

test {
    std.testing.expectEqual(480, rnnoise.rnnoise_get_frame_size());
}
```

If you want to make use of dynamic linking, then you can import the `headers` module,
which will contain the translated C header files, but none of the implementation.

## Usage note

This library expects float samples to be in the [−32768, +32767] range.
If your float samples are in [-1, 1], you will need to multiply (and then divide) them by 32768.
