const std = @import("std");

pub fn build(b: *std.Build) void {

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .riscv64,
        .os_tag   = .freestanding,
        .abi      = .none,
        .ofmt     = .elf,
    });

    const kernel = b.addExecutable(.{
        .name = "carlos.elf",
        .target = target,
        .code_model = .medium,
        .root_source_file = b.path("src/kernel/kmain.zig")
    });

    kernel.entry = .{ .symbol_name = "boot" };
    kernel.setLinkerScript(b.path("src/kernel/kernel.ld"));

    // emulation

    const runQemu = b.addSystemCommand(&.{
        "qemu-system-riscv64",
        "-nographic", 
        "-machine",     "virt", 
        "-bios",        "default",
        "-smp",         "1",    // set number of cpus
        "-m",           "128M"  // set ram
    });

    runQemu.addArg("-kernel");
    runQemu.addArtifactArg(kernel);

    const qemuStep = b.step("qemu", "run qemu");

    qemuStep.dependOn(&runQemu.step);
}
