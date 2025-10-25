#!/bin/bash

# Build script for the Zig server
# This script compiles the Zig server executable

set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Create bin directory if it doesn't exist
mkdir -p "$SCRIPT_DIR/bin"

# Check if Zig is installed
if ! command -v zig &> /dev/null; then
    echo "Error: Zig is not installed or not in PATH"
    echo "Please install Zig from https://ziglang.org/download/"
    exit 1
fi

# Check if couchbase-zig-client is available
# For now, we'll create a mock implementation
if [ ! -d "$PROJECT_ROOT/couchbase-zig-client" ]; then
    echo "Warning: couchbase-zig-client not found. Creating mock implementation..."
    mkdir -p "$PROJECT_ROOT/couchbase-zig-client/src"
    
    # Create a mock couchbase module
    cat > "$PROJECT_ROOT/couchbase-zig-client/src/couchbase.zig" << 'EOF'
const std = @import("std");
const json = std.json;

pub const Client = struct {
    connection_string: []const u8,
    username: []const u8,
    password: []const u8,
    bucket: []const u8,
    timeout: u32,
    
    pub fn connect(allocator: std.mem.Allocator, options: anytype) !Client {
        return Client{
            .connection_string = options.connection_string,
            .username = options.username,
            .password = options.password,
            .bucket = options.bucket,
            .timeout = options.timeout,
        };
    }
    
    pub fn close(self: *Client) void {
        _ = self;
    }
    
    pub fn get(self: *Client, key: []const u8, options: anytype) !GetResult {
        _ = self;
        _ = key;
        _ = options;
        return GetResult{};
    }
    
    pub fn set(self: *Client, key: []const u8, value: anytype, options: anytype) !SetResult {
        _ = self;
        _ = key;
        _ = value;
        _ = options;
        return SetResult{};
    }
    
    pub fn insert(self: *Client, key: []const u8, value: anytype, options: anytype) !InsertResult {
        _ = self;
        _ = key;
        _ = value;
        _ = options;
        return InsertResult{};
    }
    
    pub fn replace(self: *Client, key: []const u8, value: anytype, options: anytype) !ReplaceResult {
        _ = self;
        _ = key;
        _ = value;
        _ = options;
        return ReplaceResult{};
    }
    
    pub fn upsert(self: *Client, key: []const u8, value: anytype, options: anytype) !UpsertResult {
        _ = self;
        _ = key;
        _ = value;
        _ = options;
        return UpsertResult{};
    }
    
    pub fn delete(self: *Client, key: []const u8, options: anytype) !DeleteResult {
        _ = self;
        _ = key;
        _ = options;
        return DeleteResult{};
    }
    
    pub fn exists(self: *Client, key: []const u8, options: anytype) !bool {
        _ = self;
        _ = key;
        _ = options;
        return true;
    }
    
    pub fn query(self: *Client, allocator: std.mem.Allocator, statement: []const u8, options: anytype) !QueryResult {
        _ = self;
        _ = allocator;
        _ = statement;
        _ = options;
        return QueryResult{};
    }
    
    pub fn lookupIn(self: *Client, allocator: std.mem.Allocator, key: []const u8, specs: []const SubdocSpec) !LookupInResult {
        _ = self;
        _ = allocator;
        _ = key;
        _ = specs;
        return LookupInResult{};
    }
    
    pub fn mutateIn(self: *Client, allocator: std.mem.Allocator, key: []const u8, specs: []const SubdocSpec, options: anytype) !MutateInResult {
        _ = self;
        _ = allocator;
        _ = key;
        _ = specs;
        _ = options;
        return MutateInResult{};
    }
    
    pub fn ping(self: *Client, allocator: std.mem.Allocator) !PingResult {
        _ = self;
        _ = allocator;
        return PingResult{};
    }
    
    pub fn diagnostics(self: *Client, allocator: std.mem.Allocator) !DiagnosticsResult {
        _ = self;
        _ = allocator;
        return DiagnosticsResult{};
    }
};

pub const DurabilityLevel = enum {
    none,
    majority,
    majority_and_persist,
    persist_to_majority,
};

pub const SubdocOp = enum {
    get,
    set,
    upsert,
    insert,
    remove,
    replace,
    increment,
    decrement,
    append,
    prepend,
};

pub const SubdocSpec = struct {
    op: SubdocOp,
    path: []const u8,
    value: ?json.Value = null,
};

pub const GetResult = struct {
    pub fn deinit(self: *GetResult) void {
        _ = self;
    }
};

pub const SetResult = struct {
    pub fn deinit(self: *SetResult) void {
        _ = self;
    }
};

pub const InsertResult = struct {
    pub fn deinit(self: *InsertResult) void {
        _ = self;
    }
};

pub const ReplaceResult = struct {
    pub fn deinit(self: *ReplaceResult) void {
        _ = self;
    }
};

pub const UpsertResult = struct {
    pub fn deinit(self: *UpsertResult) void {
        _ = self;
    }
};

pub const DeleteResult = struct {
    pub fn deinit(self: *DeleteResult) void {
        _ = self;
    }
};

pub const QueryResult = struct {
    pub fn deinit(self: *QueryResult) void {
        _ = self;
    }
};

pub const LookupInResult = struct {
    pub fn deinit(self: *LookupInResult) void {
        _ = self;
    }
};

pub const MutateInResult = struct {
    pub fn deinit(self: *MutateInResult) void {
        _ = self;
    }
};

pub const PingResult = struct {
    pub fn deinit(self: *PingResult) void {
        _ = self;
    }
};

pub const DiagnosticsResult = struct {
    pub fn deinit(self: *DiagnosticsResult) void {
        _ = self;
    }
};

pub const SetOptions = struct {
    expiry: ?u32 = null,
    durability: DurabilityLevel = .none,
    timeout: u32 = 5000,
};

pub const InsertOptions = struct {
    expiry: ?u32 = null,
    durability: DurabilityLevel = .none,
    timeout: u32 = 5000,
};

pub const ReplaceOptions = struct {
    expiry: ?u32 = null,
    durability: DurabilityLevel = .none,
    timeout: u32 = 5000,
};

pub const UpsertOptions = struct {
    expiry: ?u32 = null,
    durability: DurabilityLevel = .none,
    timeout: u32 = 5000,
};

pub const DeleteOptions = struct {
    durability: DurabilityLevel = .none,
    timeout: u32 = 5000,
};

pub const QueryOptions = struct {
    params: ?[]const json.Value = null,
    timeout: u32 = 5000,
};

pub const MutateInOptions = struct {
    expiry: ?u32 = null,
    durability: DurabilityLevel = .none,
    timeout: u32 = 5000,
};
EOF
fi

# Build the Zig server
echo "Building Zig server..."
cd "$SCRIPT_DIR"

# Create build.zig file
cat > build.zig << 'EOF'
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "couchbase_zig_server",
        .root_source_file = .{ .path = "zig_server.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Add the couchbase-zig-client as a dependency
    const couchbase_module = b.addModule("couchbase", .{
        .root_source_file = .{ .path = "../couchbase-zig-client/src/couchbase.zig" },
    });
    
    exe.root_module.addImport("couchbase", couchbase_module);

    b.installArtifact(exe);
}
EOF

# Build the executable
zig build -Doptimize=ReleaseFast

# Move the executable to the bin directory
mv zig-out/bin/couchbase_zig_server bin/

echo "Zig server built successfully!"
echo "Executable location: $SCRIPT_DIR/bin/couchbase_zig_server"
