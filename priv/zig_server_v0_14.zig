const std = @import("std");
const json = std.json;
const couchbase = @import("couchbase");

// Global allocator
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

// Global client instance
var client: ?couchbase.Client = null;

// Request/Response structures
const Request = struct {
    command: []const u8,
    params: json.Value,
    request_id: u32,
    timestamp: u64,
};

const Response = struct {
    success: bool,
    data: json.Value,
    @"error": []const u8,
    request_id: u32,
};

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
            // Echo back error response
            std.debug.print("{{\"success\":false,\"data\":{{}},\"error\":\"Invalid JSON\",\"request_id\":0}}\n", .{});
            continue;
        };
        defer request.deinit();
        
        // Process the request
        const response = processRequest(request.value) catch |err| {
            const error_response = Response{
                .success = false,
                .data = json.Value{ .object = json.ObjectMap.init(allocator) },
                .@"error" = try std.fmt.allocPrint(allocator, "Error: {any}", .{err}),
                .request_id = request.value.request_id,
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
    const cmd = request.command;
    
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
    } else if (std.mem.eql(u8, cmd, "query")) {
        return try handleQuery(request);
    } else if (std.mem.eql(u8, cmd, "lookup_in")) {
        return try handleLookupIn(request);
    } else if (std.mem.eql(u8, cmd, "mutate_in")) {
        return try handleMutateIn(request);
    } else {
        return Response{
            .success = false,
            .data = json.Value{ .object = json.ObjectMap.init(allocator) },
            .@"error" = try std.fmt.allocPrint(allocator, "Unknown command: {s}", .{cmd}),
            .request_id = request.request_id,
        };
    }
}

fn handleConnect(request: Request) !Response {
    const params = request.params.object;
    
    // Extract connection parameters
    const conn_str_val = params.get("connection_string") orelse json.Value{ .string = "couchbase://localhost" };
    const username_val = params.get("username") orelse json.Value{ .string = "Administrator" };
    const password_val = params.get("password") orelse json.Value{ .string = "password" };
    const bucket_val = params.get("bucket") orelse json.Value{ .string = "default" };
    
    // Create connect options
    const opts = couchbase.Client.ConnectOptions{
        .connection_string = conn_str_val.string,
        .username = username_val.string,
        .password = password_val.string,
        .bucket = bucket_val.string,
        .timeout_ms = 10000,
    };
    
    // Connect to Couchbase
    const new_client = couchbase.Client.connect(allocator, opts) catch |err| {
        return Response{
            .success = false,
            .data = json.Value{ .object = json.ObjectMap.init(allocator) },
            .@"error" = try std.fmt.allocPrint(allocator, "Connection failed: {any}", .{err}),
            .request_id = request.request_id,
        };
    };
    
    // Store the connected client
    client = new_client;
    
    return Response{
        .success = true,
        .data = json.Value{ .object = json.ObjectMap.init(allocator) },
        .@"error" = "",
        .request_id = request.request_id,
    };
}

fn handleClose(request: Request) !Response {
    // Disconnect from Couchbase if connected
    if (client) |*c| {
        c.disconnect();
        client = null;
    }
    
    return Response{
        .success = true,
        .data = json.Value{ .object = json.ObjectMap.init(allocator) },
        .@"error" = "",
        .request_id = request.request_id,
    };
}

fn handleGet(request: Request) !Response {
    if (client) |*c| {
        const params = request.params.object;
        const key_obj = params.get("key") orelse return error.InvalidParams;
        
        if (key_obj != .string) return error.InvalidParams;
        const key = key_obj.string;
        
        // Call the real Couchbase client
        const result = c.get(key) catch |err| {
            return try createErrorResponse(request.request_id, err, key);
        };
        
        var data = json.ObjectMap.init(allocator);
        try data.put("value", json.Value{ .string = result.value });
        try data.put("cas", json.Value{ .integer = @intCast(result.cas) });
        
        return Response{
            .success = true,
            .data = json.Value{ .object = data },
            .@"error" = "",
            .request_id = request.request_id,
        };
    } else {
        return Response{
            .success = false,
            .data = json.Value{ .object = json.ObjectMap.init(allocator) },
            .@"error" = "Not connected",
            .request_id = request.request_id,
        };
    }
}

fn handleSet(request: Request) !Response {
    if (client) |*c| {
        const params = request.params.object;
        const key_obj = params.get("key") orelse return error.InvalidParams;
        const value_obj = params.get("value") orelse return error.InvalidParams;
        
        if (key_obj != .string) return error.InvalidParams;
        if (value_obj != .string) return error.InvalidParams;
        
        const key = key_obj.string;
        const value = value_obj.string;
        
        // Call the real Couchbase client (using upsert as set)
        const result = c.upsert(key, value, .{}) catch |err| {
            return Response{
                .success = false,
                .data = json.Value{ .object = json.ObjectMap.init(allocator) },
                .@"error" = try std.fmt.allocPrint(allocator, "Set failed: {any}", .{err}),
                .request_id = request.request_id,
            };
        };
        
        var data = json.ObjectMap.init(allocator);
        try data.put("cas", json.Value{ .integer = @intCast(result.cas) });
        
        return Response{
            .success = true,
            .data = json.Value{ .object = data },
            .@"error" = "",
            .request_id = request.request_id,
        };
    } else {
        return Response{
            .success = false,
            .data = json.Value{ .object = json.ObjectMap.init(allocator) },
            .@"error" = "Not connected",
            .request_id = request.request_id,
        };
    }
}

fn handleUpsert(request: Request) !Response {
    if (client) |*c| {
        const params = request.params.object;
        const key_obj = params.get("key") orelse return error.InvalidParams;
        const value_obj = params.get("value") orelse return error.InvalidParams;
        
        if (key_obj != .string) return error.InvalidParams;
        if (value_obj != .string) return error.InvalidParams;
        
        const key = key_obj.string;
        const value = value_obj.string;
        
        // Call the real Couchbase client
        const result = c.upsert(key, value, .{}) catch |err| {
            return Response{
                .success = false,
                .data = json.Value{ .object = json.ObjectMap.init(allocator) },
                .@"error" = try std.fmt.allocPrint(allocator, "Upsert failed: {any}", .{err}),
                .request_id = request.request_id,
            };
        };
        
        var data = json.ObjectMap.init(allocator);
        try data.put("cas", json.Value{ .integer = @intCast(result.cas) });
        
        return Response{
            .success = true,
            .data = json.Value{ .object = data },
            .@"error" = "",
            .request_id = request.request_id,
        };
    } else {
        return Response{
            .success = false,
            .data = json.Value{ .object = json.ObjectMap.init(allocator) },
            .@"error" = "Not connected",
            .request_id = request.request_id,
        };
    }
}

fn handleDelete(request: Request) !Response {
    if (client) |*c| {
        const params = request.params.object;
        const key_obj = params.get("key") orelse return error.InvalidParams;
        
        if (key_obj != .string) return error.InvalidParams;
        const key = key_obj.string;
        
        // Call the real Couchbase client
        _ = c.remove(key, .{}) catch |err| {
            return Response{
                .success = false,
                .data = json.Value{ .object = json.ObjectMap.init(allocator) },
                .@"error" = try std.fmt.allocPrint(allocator, "Delete failed: {any}", .{err}),
                .request_id = request.request_id,
            };
        };
        
        return Response{
            .success = true,
            .data = json.Value{ .object = json.ObjectMap.init(allocator) },
            .@"error" = "",
            .request_id = request.request_id,
        };
    } else {
        return Response{
            .success = false,
            .data = json.Value{ .object = json.ObjectMap.init(allocator) },
            .@"error" = "Not connected",
            .request_id = request.request_id,
        };
    }
}

fn handlePing(request: Request) !Response {
    if (client) |*c| {
        // Call the real Couchbase client for ping
        _ = c.ping(allocator) catch |err| {
            return Response{
                .success = false,
                .data = json.Value{ .object = json.ObjectMap.init(allocator) },
                .@"error" = try std.fmt.allocPrint(allocator, "Ping failed: {any}", .{err}),
                .request_id = request.request_id,
            };
        };
        
        var ping_data = json.ObjectMap.init(allocator);
        try ping_data.put("status", json.Value{ .string = "ok" });
        
        return Response{
            .success = true,
            .data = json.Value{ .object = ping_data },
            .@"error" = "",
            .request_id = request.request_id,
        };
    } else {
        return Response{
            .success = false,
            .data = json.Value{ .object = json.ObjectMap.init(allocator) },
            .@"error" = "Not connected",
            .request_id = request.request_id,
        };
    }
}

fn handleQuery(request: Request) !Response {
    if (client) |*c| {
        const params = request.params.object;
        const statement_obj = params.get("statement") orelse return error.InvalidParams;
        
        if (statement_obj != .string) return error.InvalidParams;
        const statement = statement_obj.string;
        
        // Call the real Couchbase client
        const result = c.query(allocator, statement, .{}) catch |err| {
            return Response{
                .success = false,
                .data = json.Value{ .object = json.ObjectMap.init(allocator) },
                .@"error" = try std.fmt.allocPrint(allocator, "Query failed: {any}", .{err}),
                .request_id = request.request_id,
            };
        };
        defer result.deinit();
        
        // Convert results to JSON
        var rows = json.Array.init(allocator);
        for (result.rows) |row| {
            try rows.append(json.Value{ .string = row });
        }
        
        var data = json.ObjectMap.init(allocator);
        try data.put("rows", json.Value{ .array = rows });
        try data.put("status", json.Value{ .string = "success" });
        
        return Response{
            .success = true,
            .data = json.Value{ .object = data },
            .@"error" = "",
            .request_id = request.request_id,
        };
    } else {
        return Response{
            .success = false,
            .data = json.Value{ .object = json.ObjectMap.init(allocator) },
            .@"error" = "Not connected",
            .request_id = request.request_id,
        };
    }
}

fn handleLookupIn(request: Request) !Response {
    if (client) |*c| {
        const params = request.params.object;
        const key_obj = params.get("key") orelse return error.InvalidParams;
        const specs_obj = params.get("specs") orelse return error.InvalidParams;
        
        if (key_obj != .string) return error.InvalidParams;
        if (specs_obj != .array) return error.InvalidParams;
        
        const key = key_obj.string;
        const specs_array = specs_obj.array;
        
        // Convert JSON specs to Couchbase SubdocSpec
        var subdoc_specs = std.ArrayList(couchbase.operations.SubdocSpec).init(allocator);
        defer subdoc_specs.deinit();
        
        for (specs_array.items) |spec_val| {
            if (spec_val != .object) continue;
            const spec_obj = spec_val.object;
            
            const op_val = spec_obj.get("op") orelse continue;
            const path_val = spec_obj.get("path") orelse continue;
            
            if (op_val != .string or path_val != .string) continue;
            
            const op_str = op_val.string;
            const path = path_val.string;
            
            // Parse subdoc operation type
            const op = parseSubdocOp(op_str);
            
            try subdoc_specs.append(.{
                .op = op,
                .path = path,
                .value = "",
                .flags = 0,
            });
        }
        
        // Call the real Couchbase client
        var result = c.lookupIn(allocator, key, subdoc_specs.items) catch |err| {
            return Response{
                .success = false,
                .data = json.Value{ .object = json.ObjectMap.init(allocator) },
                .@"error" = try std.fmt.allocPrint(allocator, "LookupIn failed: {any}", .{err}),
                .request_id = request.request_id,
            };
        };
        defer result.deinit();
        
        // Convert results to JSON
        var values = json.Array.init(allocator);
        for (result.values) |val| {
            try values.append(json.Value{ .string = val });
        }
        
        var data = json.ObjectMap.init(allocator);
        try data.put("values", json.Value{ .array = values });
        try data.put("cas", json.Value{ .integer = @intCast(result.cas) });
        
        return Response{
            .success = true,
            .data = json.Value{ .object = data },
            .@"error" = "",
            .request_id = request.request_id,
        };
    } else {
        return Response{
            .success = false,
            .data = json.Value{ .object = json.ObjectMap.init(allocator) },
            .@"error" = "Not connected",
            .request_id = request.request_id,
        };
    }
}

fn handleMutateIn(request: Request) !Response {
    if (client) |*c| {
        const params = request.params.object;
        const key_obj = params.get("key") orelse return error.InvalidParams;
        const specs_obj = params.get("specs") orelse return error.InvalidParams;
        
        if (key_obj != .string) return error.InvalidParams;
        if (specs_obj != .array) return error.InvalidParams;
        
        const key = key_obj.string;
        const specs_array = specs_obj.array;
        
        // Convert JSON specs to Couchbase SubdocSpec
        var subdoc_specs = std.ArrayList(couchbase.operations.SubdocSpec).init(allocator);
        defer subdoc_specs.deinit();
        
        for (specs_array.items) |spec_val| {
            if (spec_val != .object) continue;
            const spec_obj = spec_val.object;
            
            const op_val = spec_obj.get("op") orelse continue;
            const path_val = spec_obj.get("path") orelse continue;
            
            if (op_val != .string or path_val != .string) continue;
            
            const op_str = op_val.string;
            const path = path_val.string;
            
            // Get value if present (for mutation operations)
            const value_str = if (spec_obj.get("value")) |v| blk: {
                if (v == .string) {
                    break :blk v.string;
                } else {
                    // Convert non-string values to JSON string
                    break :blk try json.stringifyAlloc(allocator, v, .{});
                }
            } else "";
            
            // Parse subdoc operation type
            const op = parseSubdocOp(op_str);
            
            try subdoc_specs.append(.{
                .op = op,
                .path = path,
                .value = value_str,
                .flags = 0,
            });
        }
        
        // Parse options
        const options = couchbase.operations.SubdocOptions{
            .cas = 0,
            .expiry = 0,
            .durability = .{},
            .access_deleted = false,
        };
        
        // Call the real Couchbase client
        var result = c.mutateIn(allocator, key, subdoc_specs.items, options) catch |err| {
            return Response{
                .success = false,
                .data = json.Value{ .object = json.ObjectMap.init(allocator) },
                .@"error" = try std.fmt.allocPrint(allocator, "MutateIn failed: {any}", .{err}),
                .request_id = request.request_id,
            };
        };
        defer result.deinit();
        
        // Convert results to JSON
        var values = json.Array.init(allocator);
        for (result.values) |val| {
            try values.append(json.Value{ .string = val });
        }
        
        var data = json.ObjectMap.init(allocator);
        try data.put("values", json.Value{ .array = values });
        try data.put("cas", json.Value{ .integer = @intCast(result.cas) });
        
        return Response{
            .success = true,
            .data = json.Value{ .object = data },
            .@"error" = "",
            .request_id = request.request_id,
        };
    } else {
        return Response{
            .success = false,
            .data = json.Value{ .object = json.ObjectMap.init(allocator) },
            .@"error" = "Not connected",
            .request_id = request.request_id,
        };
    }
}

fn parseSubdocOp(op_str: []const u8) couchbase.types.SubdocOp {
    if (std.mem.eql(u8, op_str, "get")) return .get;
    if (std.mem.eql(u8, op_str, "exists")) return .exists;
    if (std.mem.eql(u8, op_str, "replace")) return .replace;
    if (std.mem.eql(u8, op_str, "dict_add")) return .dict_add;
    if (std.mem.eql(u8, op_str, "dict_upsert")) return .dict_upsert;
    if (std.mem.eql(u8, op_str, "upsert")) return .dict_upsert;
    if (std.mem.eql(u8, op_str, "array_add_first")) return .array_add_first;
    if (std.mem.eql(u8, op_str, "array_add_last")) return .array_add_last;
    if (std.mem.eql(u8, op_str, "array_add_unique")) return .array_add_unique;
    if (std.mem.eql(u8, op_str, "array_insert")) return .array_insert;
    if (std.mem.eql(u8, op_str, "delete")) return .delete;
    if (std.mem.eql(u8, op_str, "remove")) return .delete;
    if (std.mem.eql(u8, op_str, "counter")) return .counter;
    if (std.mem.eql(u8, op_str, "increment")) return .counter;
    if (std.mem.eql(u8, op_str, "get_count")) return .get_count;
    
    // Default to get
    return .get;
}

fn errorToString(err: anyerror) []const u8 {
    return switch (err) {
        // Document errors
        error.DocumentNotFound => "DocumentNotFound",
        error.DocumentExists => "DocumentExists",
        error.DocumentLocked => "DocumentLocked",
        
        // Connection errors
        error.ConnectionFailed => "ConnectionFailed",
        error.ConnectionTimeout => "ConnectionTimeout",
        error.NetworkError => "NetworkError",
        error.CannotConnect => "CannotConnect",
        
        // Authentication errors
        error.AuthenticationFailed => "AuthenticationFailed",
        error.InvalidCredentials => "InvalidCredentials",
        
        // Timeout errors
        error.Timeout => "Timeout",
        error.DurabilityTimeout => "DurabilityTimeout",
        
        // Server errors
        error.ServerError => "ServerError",
        error.TemporaryFailure => "TemporaryFailure",
        error.OutOfMemory => "OutOfMemory",
        error.NotSupported => "NotSupported",
        error.InternalError => "InternalError",
        
        // Bucket/Scope/Collection errors
        error.BucketNotFound => "BucketNotFound",
        error.ScopeNotFound => "ScopeNotFound",
        error.CollectionNotFound => "CollectionNotFound",
        
        // Query errors
        error.QueryError => "QueryError",
        error.PlanningFailure => "PlanningFailure",
        error.IndexNotFound => "IndexNotFound",
        error.PreparedStatementFailure => "PreparedStatementFailure",
        error.PreparedStatementNotFound => "PreparedStatementNotFound",
        error.QueryCancelled => "QueryCancelled",
        
        // Durability errors
        error.DurabilityImpossible => "DurabilityImpossible",
        error.DurabilityAmbiguous => "DurabilityAmbiguous",
        error.DurabilitySyncWriteInProgress => "DurabilitySyncWriteInProgress",
        
        // Subdocument errors
        error.SubdocPathNotFound => "SubdocPathNotFound",
        error.SubdocPathExists => "SubdocPathExists",
        error.SubdocPathMismatch => "SubdocPathMismatch",
        error.SubdocPathInvalid => "SubdocPathInvalid",
        error.SubdocValueTooDeep => "SubdocValueTooDeep",
        
        // Encoding errors
        error.EncodingError => "EncodingError",
        error.DecodingError => "DecodingError",
        error.InvalidArgument => "InvalidArgument",
        
        // Transaction errors
        error.TransactionNotActive => "TransactionNotActive",
        error.TransactionFailed => "TransactionFailed",
        error.TransactionTimeout => "TransactionTimeout",
        error.TransactionConflict => "TransactionConflict",
        error.TransactionRollbackFailed => "TransactionRollbackFailed",
        
        // Generic errors
        error.GenericError => "GenericError",
        error.Unknown => "Unknown",
        
        // Standard Zig errors
        error.InvalidParams => "InvalidArgument",
        
        else => "Unknown",
    };
}

fn createErrorResponse(request_id: u32, err: anyerror, context: ?[]const u8) !Response {
    const error_code = errorToString(err);
    const error_message = if (context) |ctx| 
        try std.fmt.allocPrint(allocator, "{s}: {s}", .{error_code, ctx})
    else
        try std.fmt.allocPrint(allocator, "{s}", .{error_code});
    
    var error_data = json.ObjectMap.init(allocator);
    try error_data.put("code", json.Value{ .string = error_code });
    try error_data.put("message", json.Value{ .string = error_message });
    
    return Response{
        .success = false,
        .data = json.Value{ .object = error_data },
        .@"error" = error_message,
        .request_id = request_id,
    };
}

fn sendResponse(response: Response) !void {
    const json_string = try json.stringifyAlloc(allocator, response, .{});
    defer allocator.free(json_string);
    
    std.debug.print("{s}\n", .{json_string});
}

