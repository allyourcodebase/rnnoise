const std = @import("std");

pub fn build(b: *std.Build) void {
    var target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const upstream = b.dependency("upstream", .{});
    const model = b.dependency("model", .{});

    const little_model = b.option(
        bool,
        "little",
        "embed the little model (default false)",
    ) orelse false;

    const x86_rtcd = (b.option(bool, "rtcd", "Enable x86 rtcd") orelse false) and
        target.result.cpu.arch.isX86();
    const sse4_1 = !x86_rtcd and (target.result.cpu.arch.isX86() and
        std.Target.x86.featureSetHas(target.result.cpu.features, .sse4_1));
    const avx2 = !x86_rtcd and (target.result.cpu.arch.isX86() and
        std.Target.x86.featureSetHas(target.result.cpu.features, .avx2));

    const config = b.addConfigHeader(.{}, .{
        .RNNOISE_BUILD = true,
        .DISABLE_DEBUG_FLOAT = b.option(bool, "disable-debug-float", "(default true)") orelse true,
        .HAVE_DLFCN_H = true,
        .HAVE_INTTYPES_H = true,
        .HAVE_STDINT_H = true,
        .HAVE_STDIO_H = true,
        .HAVE_STDLIB_H = true,
        .HAVE_STRINGS_H = true,
        .HAVE_STRING_H = true,
        .HAVE_SYS_STAT_H = true,
        .HAVE_SYS_TYPES_H = true,
        .HAVE_UNISTD_H = true,
        .HAVE_WCHAR_H = true,
        .HAVE_MINIX_CONFIG_H = null,
        .OP_ENABLE_ASSERTIONS = b.option(
            bool,
            "assertions",
            "Enable assertions (enabled by default in debug)",
        ) orelse if (optimize == .Debug) true else null,
        .STDC_HEADERS = true,
        .SUPPORT_ATTRIBUTE_VISIBILITY_DEFAULT = true,
        .SUPPORT_FLAG_VISIBILITY = true,
        .CPU_INFO_BY_ASM = true,
        .RNN_ENABLE_X86_RTCD = if (x86_rtcd) true else null,
    });

    const headers = b.addTranslateC(.{
        .root_source_file = upstream.path("include/rnnoise.h"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    _ = headers.addModule("headers");

    const mod = b.addModule("rnnoise", .{
        .root_source_file = headers.getOutput(),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    mod.addConfigHeader(config);
    mod.addIncludePath(upstream.path("include"));
    mod.addIncludePath(upstream.path("src"));
    if (target.result.cpu.arch.isX86()) {
        mod.addIncludePath(upstream.path("src/x86"));
    }

    mod.addCSourceFiles(.{
        .root = upstream.path("src"),
        .files = rnnoise_sources,
        .flags = cflags,
    });

    if (x86_rtcd) {
        mod.addCSourceFiles(.{
            .root = upstream.path("src"),
            .files = x86_rtcd_sources,
            .flags = cflags,
        });

        const sse_obj = b.addObject(.{
            .name = "rnnoise_sse4_1",
            .root_module = b.createModule(.{
                .target = b.resolveTargetQuery(.{
                    .cpu_arch = .x86_64,
                    .cpu_model = .baseline,
                    .cpu_features_add = std.Target.x86.featureSet(&.{.sse4_1}),
                    .os_tag = target.result.os.tag,
                    .abi = target.result.abi,
                }),
                .optimize = optimize,
                .link_libc = true,
            }),
        });

        const avx_obj = b.addObject(.{
            .name = "rnnoise_avx2",
            .root_module = b.createModule(.{
                .target = b.resolveTargetQuery(.{
                    .cpu_arch = .x86_64,
                    .cpu_model = .baseline,
                    .cpu_features_add = std.Target.x86.featureSet(&.{.avx2}),
                    .os_tag = target.result.os.tag,
                    .abi = target.result.abi,
                }),
                .optimize = optimize,
                .link_libc = true,
            }),
        });

        sse_obj.root_module.addIncludePath(upstream.path("src"));
        sse_obj.root_module.addCSourceFiles(.{
            .root = upstream.path("src"),
            .files = rnnoise_sources_sse4_1,
        });

        avx_obj.root_module.addIncludePath(upstream.path("src"));
        avx_obj.root_module.addCSourceFiles(.{
            .root = upstream.path("src"),
            .files = rnnoise_sources_avx2,
        });

        mod.addObject(sse_obj);
        mod.addObject(avx_obj);
    }

    if (sse4_1) {
        mod.addCSourceFiles(.{
            .root = upstream.path("src"),
            .files = rnnoise_sources_sse4_1,
            .flags = cflags,
        });
    }
    if (avx2) {
        mod.addCSourceFiles(.{
            .root = upstream.path("src"),
            .files = rnnoise_sources_avx2,
            .flags = cflags,
        });
    }

    mod.addIncludePath(model.path("src/"));
    mod.addCSourceFiles(.{
        .root = model.path("src/"),
        .files = if (little_model) &.{
            "rnnoise_data_little.c",
        } else &.{
            "rnnoise_data.c",
        },
        .flags = cflags,
    });

    const lib = b.addLibrary(.{
        .name = "rnnoise",
        .linkage = .static,
        .root_module = mod,
    });

    lib.installHeadersDirectory(upstream.path("include"), "", .{});
    b.installArtifact(lib);

    const dynlib = b.addLibrary(.{
        .name = "rnnoise",
        .linkage = .dynamic,
        .root_module = mod,
    });

    dynlib.installHeadersDirectory(upstream.path("include"), "", .{});
    b.installArtifact(dynlib);
}

const cflags = &[_][]const u8{};

const rnnoise_sources = &[_][]const u8{
    "denoise.c",
    "rnn.c",
    "pitch.c",
    "kiss_fft.c",
    "celt_lpc.c",
    "nnet.c",
    "nnet_default.c",
    "parse_lpcnet_weights.c",
    "rnnoise_tables.c",
};

const rnnoise_sources_sse4_1 = &[_][]const u8{
    "x86/nnet_sse4_1.c",
};

const rnnoise_sources_avx2 = &[_][]const u8{
    "x86/nnet_avx2.c",
};

const x86_rtcd_sources = &[_][]const u8{
    "x86/x86_dnn_map.c",
    "x86/x86cpu.c",
};
