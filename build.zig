const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "rnnoise",
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(lib);

    const cflags: []const []const u8 = switch (target.toTarget().abi) {
        .msvc => &.{"-DM_PI=3.1415826535"},
        else => &.{},
    };
    lib.addCSourceFiles(&.{
        "src/denoise.c",
        "src/rnn.c",
        "src/rnn_data.c",
        "src/rnn_reader.c",
        "src/pitch.c",
        "src/kiss_fft.c",
        "src/celt_lpc.c",
    }, cflags);
    lib.addIncludePath(.{ .path = "include" });
    lib.linkLibC();
    lib.installHeader("include/rnnoise.h", "rnnoise.h");

    {
        const exe = b.addExecutable(.{
            .name = "rnnoise_demo",
            .target = target,
            .optimize = optimize,
        });
        exe.addCSourceFiles(&.{
            "examples/rnnoise_demo.c",
        }, &.{});
        exe.linkLibrary(lib);
        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step("demo", "Run the demo");
        run_step.dependOn(&run_cmd.step);
    }
}
