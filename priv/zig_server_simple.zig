const std = @import("std");
const json = std.json;
const Allocator = std.mem.Allocator;

// Global allocator
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

// Request/Response structures
const Request = struct {
    command: []const u8,
    params: json.Value,
    request_id: u32,
    timestamp: u64,
};

const Response = struct {
    success: bool,
    data: ?json.Value,
    error: ?[]const u8,
    request_id: u32,
    
    pub fn deinit(self: Response) void {
        // Clean up allocated error message if present
        if (self.error) |err| {
            allocator.free(err);
        }
        // Note: data cleanup is handled by the caller since it may contain
        // references to other allocated memory
    }
};

// Connection configuration
var connection_config: ConnectionConfig = undefined;

const ConnectionConfig = struct {
    connection_string: []const u8,
    username: []const u8,
    password: []const u8,
    bucket: []const u8,
    timeout: u32,
    pool_size: u32,
};

pub fn main() !void {
    // Parse command line arguments
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    
    // Skip the program name
    _ = args.next();
    
    // Parse connection arguments
    connection_config = try parseConnectionArgs(&args);
    
    // Signal that we're ready
    std.debug.print("ready\n");
    
    // Main message loop
    var buffer: [4096]u8 = undefined;
    while (true) {
        // Read a line from stdin
        const line = std.io.getStdIn().readUntilDelimiterOrEof(buffer[0..], '\n') catch |err| {
            std.debug.print("Error reading input: {}\n", .{err});
            break;
        };
        
        if (line == null) break;
        
        // Parse JSON request
        const request = json.parseFromSlice(Request, allocator, line.?, .{}) catch |err| {
            std.debug.print("Error parsing request: {}\n", .{err});
            continue;
        };
        defer request.deinit();
        
        // Process the request
        const response = processRequest(request.value) catch |err| {
            const error_response = Response{
                .success = false,
                .data = null,
                .error = try std.fmt.allocPrint(allocator, "Error processing request: {}", .{err}),
                .request_id = request.value.request_id,
            };
            defer error_response.deinit();
            try sendResponse(error_response);
            continue;
        };
        defer response.deinit();
        
        // Send response
        try sendResponse(response);
    }
}

fn processRequest(request: Request) !Response {
    if (std.mem.eql(u8, request.command, "connect")) {
        return try handleConnect(request);
    } else if (std.mem.eql(u8, request.command, "close")) {
        return try handleClose(request);
    } else if (std.mem.eql(u8, request.command, "get")) {
        return try handleGet(request);
    } else if (std.mem.eql(u8, request.command, "set")) {
        return try handleSet(request);
    } else if (std.mem.eql(u8, request.command, "insert")) {
        return try handleInsert(request);
    } else if (std.mem.eql(u8, request.command, "replace")) {
        return try handleReplace(request);
    } else if (std.mem.eql(u8, request.command, "upsert")) {
        return try handleUpsert(request);
    } else if (std.mem.eql(u8, request.command, "delete")) {
        return try handleDelete(request);
    } else if (std.mem.eql(u8, request.command, "exists")) {
        return try handleExists(request);
    } else if (std.mem.eql(u8, request.command, "query")) {
        return try handleQuery(request);
    } else if (std.mem.eql(u8, request.command, "lookup_in")) {
        return try handleLookupIn(request);
    } else if (std.mem.eql(u8, request.command, "mutate_in")) {
        return try handleMutateIn(request);
    } else if (std.mem.eql(u8, request.command, "ping")) {
        return try handlePing(request);
    } else if (std.mem.eql(u8, request.command, "diagnostics")) {
        return try handleDiagnostics(request);
    } else {
        return Response{
            .success = false,
            .data = null,
            .error = try std.fmt.allocPrint(allocator, "Unknown command: {s}", .{request.command}),
            .request_id = request.request_id,
        };
    }
}

fn parseConnectionArgs(args: *std.process.ArgIterator) !ConnectionConfig {
    var config = ConnectionConfig{
        .connection_string = "couchbase://localhost",
        .username = "Administrator",
        .password = "password",
        .bucket = "default",
        .timeout = 5000,
        .pool_size = 10,
    };
    
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--connection-string")) {
            config.connection_string = args.next() orelse return error.MissingValue;
        } else if (std.mem.eql(u8, arg, "--username")) {
            config.username = args.next() orelse return error.MissingValue;
        } else if (std.mem.eql(u8, arg, "--password")) {
            config.password = args.next() orelse return error.MissingValue;
        } else if (std.mem.eql(u8, arg, "--bucket")) {
            config.bucket = args.next() orelse return error.MissingValue;
        } else if (std.mem.eql(u8, arg, "--timeout")) {
            const timeout_str = args.next() orelse return error.MissingValue;
            config.timeout = try std.fmt.parseInt(u32, timeout_str, 10);
        } else if (std.mem.eql(u8, arg, "--pool-size")) {
            const pool_size_str = args.next() orelse return error.MissingValue;
            config.pool_size = try std.fmt.parseInt(u32, pool_size_str, 10);
        }
    }
    
    return config;
}

fn handleConnect(request: Request) !Response {
    // For now, just return success - real implementation will connect to Couchbase
    return Response{
        .success = true,
        .data = json.Value{ .object = json.ObjectMap.init(allocator) },
        .error = null,
        .request_id = request.request_id,
    };
}

fn handleClose(request: Request) !Response {
    // For now, just return success - real implementation will close connection
    return Response{
        .success = true,
        .data = json.Value{ .object = json.ObjectMap.init(allocator) },
        .error = null,
        .request_id = request.request_id,
    };
}

fn handleGet(request: Request) !Response {
    const params = request.params.object;
    const key = params.get("key").?.string;
    
    // For now, return a mock response - real implementation will get from Couchbase
    var mock_data = json.ObjectMap.init(allocator);
    try mock_data.put("key", json.Value{ .string = key });
    try mock_data.put("value", json.Value{ .string = "mock_value" });
    
    return Response{
        .success = true,
        .data = json.Value{ .object = mock_data },
        .error = null,
        .request_id = request.request_id,
    };
}

fn handleSet(request: Request) !Response {
    const params = request.params.object;
    const key = params.get("key").?.string;
    const value = params.get("value").?;
    
    // For now, return success - real implementation will store in Couchbase
    return Response{
        .success = true,
        .data = json.Value{ .object = json.ObjectMap.init(allocator) },
        .error = null,
        .request_id = request.request_id,
    };
}

fn handleInsert(request: Request) !Response {
    const params = request.params.object;
    const key = params.get("key").?.string;
    const value = params.get("value").?;
    
    // For now, return success - real implementation will insert in Couchbase
    return Response{
        .success = true,
        .data = json.Value{ .object = json.ObjectMap.init(allocator) },
        .error = null,
        .request_id = request.request_id,
    };
}

fn handleReplace(request: Request) !Response {
    const params = request.params.object;
    const key = params.get("key").?.string;
    const value = params.get("value").?;
    
    // For now, return success - real implementation will replace in Couchbase
    return Response{
        .success = true,
        .data = json.Value{ .object = json.ObjectMap.init(allocator) },
        .error = null,
        .request_id = request.request_id,
    };
}

fn handleUpsert(request: Request) !Response {
    const params = request.params.object;
    const key = params.get("key").?.string;
    const value = params.get("value").?;
    
    // For now, return success - real implementation will upsert in Couchbase
    return Response{
        .success = true,
        .data = json.Value{ .object = json.ObjectMap.init(allocator) },
        .error = null,
        .request_id = request.request_id,
    };
}

fn handleDelete(request: Request) !Response {
    const params = request.params.object;
    const key = params.get("key").?.string;
    
    // For now, return success - real implementation will delete from Couchbase
    return Response{
        .success = true,
        .data = json.Value{ .object = json.ObjectMap.init(allocator) },
        .error = null,
        .request_id = request.request_id,
    };
}

fn handleExists(request: Request) !Response {
    const params = request.params.object;
    const key = params.get("key").?.string;
    
    // For now, return mock existence - real implementation will check Couchbase
    return Response{
        .success = true,
        .data = json.Value{ .bool = true },
        .error = null,
        .request_id = request.request_id,
    };
}

fn handleQuery(request: Request) !Response {
    const params = request.params.object;
    const statement = params.get("statement").?.string;
    
    // For now, return mock query results - real implementation will query Couchbase
    var mock_results = json.Array.init(allocator);
    try mock_results.append(json.Value{ .string = "mock_result" });
    
    return Response{
        .success = true,
        .data = json.Value{ .array = mock_results },
        .error = null,
        .request_id = request.request_id,
    };
}

fn handleLookupIn(request: Request) !Response {
    const params = request.params.object;
    const key = params.get("key").?.string;
    const specs = params.get("specs").?.array;
    
    // For now, return mock subdocument results - real implementation will lookup in Couchbase
    var mock_results = json.Array.init(allocator);
    try mock_results.append(json.Value{ .string = "mock_subdoc_result" });
    
    return Response{
        .success = true,
        .data = json.Value{ .array = mock_results },
        .error = null,
        .request_id = request.request_id,
    };
}

fn handleMutateIn(request: Request) !Response {
    const params = request.params.object;
    const key = params.get("key").?.string;
    const specs = params.get("specs").?.array;
    
    // For now, return success - real implementation will mutate in Couchbase
    return Response{
        .success = true,
        .data = json.Value{ .object = json.ObjectMap.init(allocator) },
        .error = null,
        .request_id = request.request_id,
    };
}

fn handlePing(request: Request) !Response {
    // For now, return mock ping result - real implementation will ping Couchbase
    var mock_ping = json.ObjectMap.init(allocator);
    try mock_ping.put("status", json.Value{ .string = "ok" });
    try mock_ping.put("services", json.Value{ .string = "kv,query,index" });
    
    return Response{
        .success = true,
        .data = json.Value{ .object = mock_ping },
        .error = null,
        .request_id = request.request_id,
    };
}

fn handleDiagnostics(request: Request) !Response {
    // For now, return mock diagnostics - real implementation will get from Couchbase
    var mock_diagnostics = json.ObjectMap.init(allocator);
    try mock_diagnostics.put("version", json.Value{ .string = "7.0.0" });
    try mock_diagnostics.put("uptime", json.Value{ .integer = 3600 });
    
    return Response{
        .success = true,
        .data = json.Value{ .object = mock_diagnostics },
        .error = null,
        .request_id = request.request_id,
    };
}

fn sendResponse(response: Response) !void {
    const json_string = try json.stringifyAlloc(allocator, response, .{});
    defer allocator.free(json_string);
    
    std.debug.print("{s}\n", .{json_string});
}
