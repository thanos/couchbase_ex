const std = @import("std");
const json = std.json;
const couchbase = @import("couchbase");

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
    @"success": bool,
    @"data": json.Value,
    @"error": []const u8,
    @"request_id": u32,
};

// Global client instance
var client: ?couchbase.Client = null;

pub fn main() !void {
    // Signal that we're ready
    std.debug.print("ready\n", .{});
    
    // Main message loop
    var buffer: [4096]u8 = undefined;
    while (true) {
        // Read a line from stdin
        const stdin = std.io.getStdIn().reader();
        const line = stdin.readUntilDelimiterOrEof(buffer[0..], '\n') catch |err| {
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
                .@"success" = false,
                .@"data" = json.Value{ .object = json.ObjectMap.init(allocator) },
                .@"error" = try std.fmt.allocPrint(allocator, "Error processing request: {any}", .{err}),
                .@"request_id" = request.value.request_id,
            };
            defer allocator.free(error_response.@"error");
            try sendResponse(error_response);
            continue;
        };
        
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
    } else if (std.mem.eql(u8, request.command, "upsert")) {
        return try handleUpsert(request);
    } else if (std.mem.eql(u8, request.command, "delete")) {
        return try handleDelete(request);
    } else {
        return Response{
            .success = false,
            .data = json.Value{ .object = json.ObjectMap.init(allocator) },
            .error = try std.fmt.allocPrint(allocator, "Unknown command: {s}", .{request.command}),
            .request_id = request.request_id,
        };
    }
}

fn handleConnect(request: Request) !Response {
    const params = request.params.object;
    
    const conn_str = params.get("connection_string") orelse .{ .string = "couchbase://localhost" };
    const username = params.get("username") orelse .{ .string = "Administrator" };
    const password = params.get("password") orelse .{ .string = "password" };
    const bucket = params.get("bucket") orelse .{ .string = "default" };
    
    const opts = couchbase.Client.ConnectOptions{
        .connection_string = conn_str.string,
        .username = username.string,
        .password = password.string,
        .bucket = bucket.string,
        .timeout_ms = 5000,
    };
    
    // Create and connect to Couchbase using the couchbase-zig-client
    client = try couchbase.Client.connect(allocator, opts);
    
    return Response{
        .success = true,
        .data = json.Value{ .object = json.ObjectMap.init(allocator) },
        .error = "",
        .request_id = request.request_id,
    };
}

fn handleClose(request: Request) !Response {
    if (client) |*c| {
        c.disconnect();
        client = null;
    }
    
    return Response{
        .success = true,
        .data = json.Value{ .object = json.ObjectMap.init(allocator) },
        .error = "",
        .request_id = request.request_id,
    };
}

fn handleGet(request: Request) !Response {
    if (client) |*c| {
        const params = request.params.object;
        const key = params.get("key").?.string;
        
        const result = try c.get(key);
        
        var mock_data = json.ObjectMap.init(allocator);
        try mock_data.put("value", json.Value{ .string = result.value });
        
        return Response{
            .success = true,
            .data = json.Value{ .object = mock_data },
            .error = "",
            .request_id = request.request_id,
        };
    } else {
        return Response{
            .success = false,
            .data = json.Value{ .object = json.ObjectMap.init(allocator) },
            .error = "Not connected",
            .request_id = request.request_id,
        };
    }
}

fn handleSet(request: Request) !Response {
    // For now, return success - real implementation will store
    return Response{
        .success = true,
        .data = json.Value{ .object = json.ObjectMap.init(allocator) },
        .error = "",
        .request_id = request.request_id,
    };
}

fn handleUpsert(request: Request) !Response {
    // For now, return success
    return Response{
        .success = true,
        .data = json.Value{ .object = json.ObjectMap.init(allocator) },
        .error = "",
        .request_id = request.request_id,
    };
}

fn handleDelete(request: Request) !Response {
    // For now, return success
    return Response{
        .success = true,
        .data = json.Value{ .object = json.ObjectMap.init(allocator) },
        .error = "",
        .request_id = request.request_id,
    };
}

fn sendResponse(response: Response) !void {
    const json_string = try json.stringifyAlloc(allocator, response, .{});
    defer allocator.free(json_string);
    
    std.debug.print("{s}\n", .{json_string});
}

