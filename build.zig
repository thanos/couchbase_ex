const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Add couchbase-zig-client as a module
    const couchbase_module = b.addModule("couchbase", .{
        .root_source_file = b.path("../couchbase-zig-client/src/root.zig"),
    });

    // Create the Zig server executable
    const exe = b.addExecutable(.{
        .name = "couchbase_zig_server",
        .root_source_file = b.path("priv/zig_server_v0_14.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add the couchbase module to the exe
    exe.root_module.addImport("couchbase", couchbase_module);

    // Link system libraries
    exe.linkSystemLibrary("c");
    exe.linkLibC();
    
    // Link Couchbase library
    exe.linkSystemLibrary("couchbase");
    
    // Include paths for Couchbase headers (Homebrew location)
    exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
    exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include/libcouchbase" });

    // Library paths (Homebrew location)
    exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });

    // No C source flags needed for pure Zig executable

    // Install the executable
    b.installArtifact(exe);

    // Create a run step for testing
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the Zig server");
    run_step.dependOn(&run_cmd.step);

    // Create a test step
    const test_exe = b.addTest(.{
        .root_source_file = b.path("priv/zig_server_v0_14.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Link the same libraries for tests
    test_exe.linkSystemLibrary("c");
    test_exe.linkLibC();
    test_exe.linkSystemLibrary("couchbase");

    // Include paths for tests (Homebrew location)
    test_exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
    test_exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include/libcouchbase" });
    
    // Library paths (Homebrew location)
    test_exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });

    const test_run = b.addRunArtifact(test_exe);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&test_run.step);
}
