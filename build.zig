const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .riscv32,
        .os_tag = .freestanding,
        .abi = .none
    });

    const optimize = b.standardOptimizeOption(.{});

    const kernel = b.addExecutable(.{
        .name = "kernel",
        .target = target,
        .optimize = optimize,
    });

    kernel.addCSourceFiles(.{
        .files = &.{
            "kernel/kmain.c"
        },
        .flags = &.{
            "-std=c11",
            "-g3",
            "-Wall",
            "-Wextra",
            "-fno-stack-protector",
            "-ffreestanding",
            "-nostdlib",
        }
    });

    kernel.setLinkerScript(b.path("kernel/kernel.ld"));

    b.installArtifact(kernel);
}
