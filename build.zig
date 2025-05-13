const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .riscv64,
        .os_tag = .freestanding,
        .abi = .none
    });

    const kernel = b.addExecutable(.{
        .name = "kmain",
        .target = target,
        .optimize = .ReleaseSmall,
    });

    kernel.link_z_max_page_size = 4096;
    kernel.setLinkerScript(b.path("kernel/loader/kernel.ld"));

    const cflags = &.{
        "-fno-omit-frame-pointer",
        "-mcmodel=medany",
        "-ffreestanding",
        "-fno-common",
        "-nostdlib",
        "-mno-relax",
        "-fno-stack-protector",
        "-fno-pie",
    };


    kernel.addCSourceFiles(.{
        .files = &.{
            "kernel/kmain.c",
        },
        .flags = cflags
    });

    kernel.addAssemblyFile(.{ .cwd_relative =  "kernel/loader/crt0.s"});


    const qemu = b.step("qemu", "Run Qemu");
    const runQemu = b.addSystemCommand(&.{
        "qemu-system-riscv64",
        "-nographic", 
        "-machine", "virt", 
        "-bios",    "none", 
       "-kernel", 
    });

    runQemu.addArtifactArg(kernel);

    qemu.dependOn(&runQemu.step);
    runQemu.step.dependOn(&kernel.step);

}
