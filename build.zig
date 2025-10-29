const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Get couchbase-zig-client path from build option or use default
    const couchbase_client_path = b.option(
        []const u8,
        "couchbase-client-path",
        "Path to couchbase-zig-client root.zig file"
    ) orelse "../couchbase-zig-client/src/root.zig";

    // Add couchbase-zig-client as a module
    const couchbase_module = b.addModule("couchbase", .{
        .root_source_file = b.path(couchbase_client_path),
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
    
    // Detect platform and set appropriate paths
    const target_info = target.result;
    
    // Get paths from build options or use platform defaults
    const include_path = b.option([]const u8, "couchbase-include", "Path to Couchbase include directory") orelse 
        detectCouchbaseIncludePath(target_info);
    const lib_path = b.option([]const u8, "couchbase-lib", "Path to Couchbase library directory") orelse 
        detectCouchbaseLibPath(target_info);
    
    // Add include paths
    if (include_path.len > 0) {
        exe.addIncludePath(.{ .cwd_relative = include_path });
        // Also add libcouchbase subdirectory
        const libcouchbase_include = std.fmt.allocPrint(b.allocator, "{s}/libcouchbase", .{include_path}) catch include_path;
        exe.addIncludePath(.{ .cwd_relative = libcouchbase_include });
    }
    
    // Add library path
    if (lib_path.len > 0) {
        exe.addLibraryPath(.{ .cwd_relative = lib_path });
    }

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

    // Use the same paths for tests
    if (include_path.len > 0) {
        test_exe.addIncludePath(.{ .cwd_relative = include_path });
        const libcouchbase_include = std.fmt.allocPrint(b.allocator, "{s}/libcouchbase", .{include_path}) catch include_path;
        test_exe.addIncludePath(.{ .cwd_relative = libcouchbase_include });
    }
    
    if (lib_path.len > 0) {
        test_exe.addLibraryPath(.{ .cwd_relative = lib_path });
    }

    const test_run = b.addRunArtifact(test_exe);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&test_run.step);
}

/// Detect Couchbase include path based on platform
fn detectCouchbaseIncludePath(target_info: std.Target) []const u8 {
    const os_tag = target_info.os.tag;
    
    return switch (os_tag) {
        .macos => "/opt/homebrew/include",  // Apple Silicon (default), Intel: /usr/local/include
        .linux => "/usr/include",            // Most Linux distros
        .windows => "C:\\Program Files\\Couchbase\\include",
        else => "/usr/local/include",
    };
}

/// Detect Couchbase library path based on platform
fn detectCouchbaseLibPath(target_info: std.Target) []const u8 {
    const os_tag = target_info.os.tag;
    
    return switch (os_tag) {
        .macos => "/opt/homebrew/lib",      // Apple Silicon (default), Intel: /usr/local/lib
        .linux => "/usr/lib",                // Most Linux distros
        .windows => "C:\\Program Files\\Couchbase\\lib",
        else => "/usr/local/lib",
    };
}
