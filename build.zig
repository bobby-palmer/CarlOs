const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .riscv64,
        .os_tag = .freestanding,
        .abi = .none
    });

    const optimize = b.standardOptimizeOption(.{});

    const kernel = b.addExecutable(.{
        .name = "kmain",
        .target = target,
        .optimize = optimize,
    });

    const cflags = &.{
        "-ffreestanding", 
        "-nostartfiles", 
        "-nostdlib", 
        "-nodefaultlibs", 
        "-g", 
        "-Wl,--gc-sections", 
        "-mcmodel=medany", 
    };


    kernel.addCSourceFiles(.{
        .files = &.{
            "kernel/kmain.c",
            "kernel/crt0.s",
        },
        .flags = cflags
    });

    kernel.setLinkerScript(b.path("kernel/kernel.ld"));

    const qemu = b.step("qemu", "Run Qemu");
    const runQemu = b.addSystemCommand(&.{
        "qemu-system-riscv64",
        "-nographic", 
        "-machine", "virt", 
        "-m",       "128M",      
        "-bios",    "none", 
       "-kernel", 
    });

    runQemu.addArtifactArg(kernel);

    qemu.dependOn(&runQemu.step);
    runQemu.step.dependOn(&kernel.step);

}
