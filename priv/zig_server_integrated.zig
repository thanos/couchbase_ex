const std = @import("std");
const json = std.json;
const couchbase = @import("couchbase");

// Global allocator
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

// Request/Response structures
const Request = struct {
    @"command": []const u8,
    @"params": json.Value,
    @"request_id": u32,
    @"timestamp": u64,
};

const Response = struct {
    @"success": bool,
    @"data": json.Value,
    @"error": []const u8,
    @"request_id": u32,
};

// Global client instance
var client: ?*couchbase.Client = null;

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
                .@"data" = json.Value{ .@"object" = json.ObjectMap.init(allocator) },
                .@"error" = try std.fmt.allocPrint(allocator, "Error processing request: {any}", .{err}),
                .@"request_id" = request.value.@"request_id",
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
    const cmd = request.@"command";
    
    if (std.mem.eql(u8, cmd, "connect")) {
        return try handleConnect(request);
    } else if (std.mem.eql(u8, cmd, "close")) {
        return try handleClose(request);
    } else if (std.mem.eql(u8, cmd, "get")) {
        return try handleGet(request);
    } else if (std.mem.eql(u8, cmd, "set")) {
        return try handleSet(request);
    } else if (std.mem.eql(u8, cmd, "upsert")) {
        return try handleUpsert(request);
    } else if (std.mem.eql(u8, cmd, "delete")) {
        return try handleDelete(request);
    } else if (std.mem.eql(u8, cmd, "ping")) {
        return try handlePing(request);
    } else {
        return Response{
            .@"success" = false,
            .@"data" = json.Value{ .@"object" = json.ObjectMap.init(allocator) },
            .@"error" = try std.fmt.allocPrint(allocator, "Unknown command: {s}", .{cmd}),
            .@"request_id" = request.@"request_id",
        };
    }
}

fn handleConnect(request: Request) !Response {
    const params = request.@"params".@"object";
    
    const conn_str_val = params.get("connection_string") orelse json.Value{ .@"string" = "couchbase://localhost" };
    const username_val = params.get("username") orelse json.Value{ .@"string" = "Administrator" };
    const password_val = params.get("password") orelse json.Value{ .@"string" = "password" };
    const bucket_val = params.get("bucket") orelse json.Value{ .@"string" = "default" };
    
    const opts = couchbase.Client.ConnectOptions{
        .connection_string = conn_str_val.@"string",
        .username = username_val.@"string",
        .password = password_val.@"string",
        .bucket = bucket_val.@"string",
        .timeout_ms = 10000,
    };
    
    // Create and connect to Couchbase using the couchbase-zig-client
    const new_client = try couchbase.Client.connect(allocator, opts);
    client = try allocator.create(couchbase.Client);
    client.?.* = new_client;
    
    return Response{
        .@"success" = true,
        .@"data" = json.Value{ .@"object" = json.ObjectMap.init(allocator) },
        .@"error" = "",
        .@"request_id" = request.@"request_id",
    };
}

fn handleClose(request: Request) !Response {
    if (client) |*c| {
        c.disconnect();
        client = null;
    }
    
    return Response{
        .@"success" = true,
        .@"data" = json.Value{ .@"object" = json.ObjectMap.init(allocator) },
        .@"error" = "",
        .@"request_id" = request.@"request_id",
    };
}

fn handleGet(request: Request) !Response {
    if (client) |c| {
        const params = request.@"params".@"object";
        const key_obj = params.get("key") orelse return error.InvalidParams;
        const key = key_obj.@"string";
        
        // Call the real Couchbase client
        const result = try c.get(key);
        
        var data = json.ObjectMap.init(allocator);
        try data.put("value", json.Value{ .@"string" = result.value });
        try data.put("cas", json.Value{ .@"integer" = @intCast(result.cas) });
        
        return Response{
            .@"success" = true,
            .@"data" = json.Value{ .@"object" = data },
            .@"error" = "",
            .@"request_id" = request.@"request_id",
        };
    } else {
        return Response{
            .@"success" = false,
            .@"data" = json.Value{ .@"object" = json.ObjectMap.init(allocator) },
            .@"error" = "Not connected",
            .@"request_id" = request.@"request_id",
        };
    }
}

fn handleSet(request: Request) !Response {
    if (client) |c| {
        const params = request.@"params".@"object";
        const key_obj = params.get("key") orelse return error.InvalidParams;
        const value_obj = params.get("value") orelse return error.InvalidParams;
        
        const key = key_obj.@"string";
        const value = value_obj.@"string";
        
        // Call the real Couchbase client
        const result = try c.upsert(key, value, .{});
        
        var data = json.ObjectMap.init(allocator);
        try data.put("cas", json.Value{ .@"integer" = @intCast(result.cas) });
        
        return Response{
            .@"success" = true,
            .@"data" = json.Value{ .@"object" = data },
            .@"error" = "",
            .@"request_id" = request.@"request_id",
        };
    } else {
        return Response{
            .@"success" = false,
            .@"data" = json.Value{ .@"object" = json.ObjectMap.init(allocator) },
            .@"error" = "Not connected",
            .@"request_id" = request.@"request_id",
        };
    }
}

fn handleUpsert(request: Request) !Response {
    if (client) |c| {
        const params = request.@"params".@"object";
        const key_obj = params.get("key") orelse return error.InvalidParams;
        const value_obj = params.get("value") orelse return error.InvalidParams;
        
        const key = key_obj.@"string";
        const value = value_obj.@"string";
        
        // Call the real Couchbase client
        const result = try c.upsert(key, value, .{});
        
        var data = json.ObjectMap.init(allocator);
        try data.put("cas", json.Value{ .@"integer" = @intCast(result.cas) });
        
        return Response{
            .@"success" = true,
            .@"data" = json.Value{ .@"object" = data },
            .@"error" = "",
            .@"request_id" = request.@"request_id",
        };
    } else {
        return Response{
            .@"success" = false,
            .@"data" = json.Value{ .@"object" = json.ObjectMap.init(allocator) },
            .@"error" = "Not connected",
            .@"request_id" = request.@"request_id",
        };
    }
}

fn handleDelete(request: Request) !Response {
    if (client) |c| {
        const params = request.@"params".@"object";
        const key_obj = params.get("key") orelse return error.InvalidParams;
        const key = key_obj.@"string";
        
        // Call the real Couchbase client
        _ = try c.remove(key, .{});
        
        return Response{
            .@"success" = true,
            .@"data" = json.Value{ .@"object" = json.ObjectMap.init(allocator) },
            .@"error" = "",
            .@"request_id" = request.@"request_id",
        };
    } else {
        return Response{
            .@"success" = false,
            .@"data" = json.Value{ .@"object" = json.ObjectMap.init(allocator) },
            .@"error" = "Not connected",
            .@"request_id" = request.@"request_id",
        };
    }
}

fn handlePing(request: Request) !Response {
    if (client) |c| {
        // Call the real Couchbase ping
        const result = try c.ping(allocator);
        defer result.deinit();
        
        var data = json.ObjectMap.init(allocator);
        try data.put("status", json.Value{ .@"string" = "ok" });
        
        return Response{
            .@"success" = true,
            .@"data" = json.Value{ .@"object" = data },
            .@"error" = "",
            .@"request_id" = request.@"request_id",
        };
    } else {
        return Response{
            .@"success" = false,
            .@"data" = json.Value{ .@"object" = json.ObjectMap.init(allocator) },
            .@"error" = "Not connected",
            .@"request_id" = request.@"request_id",
        };
    }
}

fn sendResponse(response: Response) !void {
    const json_string = try json.stringifyAlloc(allocator, response, .{});
    defer allocator.free(json_string);
    
    std.debug.print("{s}\n", .{json_string});
}

