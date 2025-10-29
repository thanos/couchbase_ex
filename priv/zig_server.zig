const std = @import("std");
const json = std.json;
const Allocator = std.mem.Allocator;

// Import Couchbase C SDK
const couchbase = @cImport({
    @cInclude("libcouchbase/couchbase.h");
    @cInclude("libcouchbase/logger.h");
    @cInclude("libcouchbase/error.h");
});

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

// Global client instance
var client: ?couchbase.lcb_INSTANCE = null;

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
    // Create Couchbase instance
    var instance: couchbase.lcb_INSTANCE = undefined;
    var create_options: couchbase.lcb_CREATEOPTS = std.mem.zeroes(couchbase.lcb_CREATEOPTS);
    
    // Set connection string
    create_options.connstr = connection_config.connection_string.ptr;
    create_options.connstr_len = connection_config.connection_string.len;
    
    // Set username and password
    create_options.username = connection_config.username.ptr;
    create_options.username_len = connection_config.username.len;
    create_options.password = connection_config.password.ptr;
    create_options.password_len = connection_config.password.len;
    
    // Create the instance
    const err = couchbase.lcb_create(&instance, &create_options);
    if (err != couchbase.LCB_SUCCESS) {
        return Response{
            .success = false,
            .data = null,
            .error = try std.fmt.allocPrint(allocator, "Failed to create Couchbase instance: {s}", .{couchbase.lcb_strerror(instance, err)}),
            .request_id = request.request_id,
        };
    }
    
    // Connect to the cluster
    const connect_err = couchbase.lcb_connect(instance);
    if (connect_err != couchbase.LCB_SUCCESS) {
        couchbase.lcb_destroy(instance);
        return Response{
            .success = false,
            .data = null,
            .error = try std.fmt.allocPrint(allocator, "Failed to connect to Couchbase: {s}", .{couchbase.lcb_strerror(instance, connect_err)}),
            .request_id = request.request_id,
        };
    }
    
    // Wait for connection to be established
    couchbase.lcb_wait(instance, couchbase.LCB_WAIT_DEFAULT);
    
    // Check connection status
    const status = couchbase.lcb_get_bootstrap_status(instance);
    if (status != couchbase.LCB_SUCCESS) {
        couchbase.lcb_destroy(instance);
        return Response{
            .success = false,
            .data = null,
            .error = try std.fmt.allocPrint(allocator, "Connection failed: {s}", .{couchbase.lcb_strerror(instance, status)}),
            .request_id = request.request_id,
        };
    }
    
    // Set the bucket
    const bucket_err = couchbase.lcb_set_bucket(instance, connection_config.bucket.ptr, connection_config.bucket.len);
    if (bucket_err != couchbase.LCB_SUCCESS) {
        couchbase.lcb_destroy(instance);
        return Response{
            .success = false,
            .data = null,
            .error = try std.fmt.allocPrint(allocator, "Failed to set bucket: {s}", .{couchbase.lcb_strerror(instance, bucket_err)}),
            .request_id = request.request_id,
        };
    }
    
    client = instance;
    
    return Response{
        .success = true,
        .data = json.Value{ .object = json.ObjectMap.init(allocator) },
        .error = null,
        .request_id = request.request_id,
    };
}

fn handleClose(request: Request) !Response {
    if (client) |instance| {
        couchbase.lcb_destroy(instance);
        client = null;
    }
    
    return Response{
        .success = true,
        .data = json.Value{ .object = json.ObjectMap.init(allocator) },
        .error = null,
        .request_id = request.request_id,
    };
}

fn handleGet(request: Request) !Response {
    if (client == null) {
        return Response{
            .success = false,
            .data = null,
            .error = "Client not connected",
            .request_id = request.request_id,
        };
    }
    
    const params = request.params.object;
    const key = params.get("key").?.string;
    const timeout = params.get("timeout").?.integer;
    
    // Create get command
    var cmd: couchbase.lcb_CMDGET = std.mem.zeroes(couchbase.lcb_CMDGET);
    cmd.key.vtype = couchbase.LCB_KV_COPY;
    cmd.key.u_buf.base = key.ptr;
    cmd.key.u_buf.len = key.len;
    cmd.timeout = @intCast(timeout);
    
    // Result storage
    var result_data: ?[]u8 = null;
    var result_flags: u32 = 0;
    var result_cas: u64 = 0;
    var operation_success = false;
    
    // Callback for get operation
    const get_callback = struct {
        fn callback(instance: couchbase.lcb_INSTANCE, cbtype: c_int, resp: ?*const couchbase.lcb_RESPGET) callconv(.C) void {
            _ = instance;
            _ = cbtype;
            
            if (resp) |response| {
                if (response.rc == couchbase.LCB_SUCCESS) {
                    // Copy the value
                    const value_len = response.value_len;
                    const value_ptr = response.value;
                    result_data = allocator.alloc(u8, value_len) catch return;
                    @memcpy(result_data.?.ptr, value_ptr, value_len);
                    result_flags = response.flags;
                    result_cas = response.cas;
                    operation_success = true;
                }
            }
        }
    }.callback;
    
    // Set callback
    couchbase.lcb_install_callback3(client.?, couchbase.LCB_CALLBACK_GET, get_callback);
    
    // Execute get operation
    const err = couchbase.lcb_get3(client.?, null, &cmd);
    if (err != couchbase.LCB_SUCCESS) {
        return Response{
            .success = false,
            .data = null,
            .error = try std.fmt.allocPrint(allocator, "Get operation failed: {s}", .{couchbase.lcb_strerror(client.?, err)}),
            .request_id = request.request_id,
        };
    }
    
    // Wait for operation to complete
    couchbase.lcb_wait(client.?, couchbase.LCB_WAIT_DEFAULT);
    
    if (!operation_success) {
        return Response{
            .success = false,
            .data = null,
            .error = "Document not found",
            .request_id = request.request_id,
        };
    }
    
    // Parse JSON from result
    const json_value = json.parseFromSlice(json.Value, allocator, result_data.?, .{}) catch |parse_err| {
        return Response{
            .success = false,
            .data = null,
            .error = try std.fmt.allocPrint(allocator, "Failed to parse document JSON: {}", .{parse_err}),
            .request_id = request.request_id,
        };
    };
    
    return Response{
        .success = true,
        .data = json_value,
        .error = null,
        .request_id = request.request_id,
    };
}

fn handleSet(request: Request) !Response {
    if (client == null) {
        return Response{
            .success = false,
            .data = null,
            .error = "Client not connected",
            .request_id = request.request_id,
        };
    }
    
    const params = request.params.object;
    const key = params.get("key").?.string;
    const value = params.get("value").?;
    const expiry = params.get("expiry");
    const durability = params.get("durability");
    const timeout = params.get("timeout").?.integer;
    
    var options = couchbase.SetOptions{};
    if (expiry) |exp| {
        options.expiry = @intCast(exp.integer);
    }
    if (durability) |dur| {
        options.durability = parseDurability(dur.string);
    }
    options.timeout = @intCast(timeout);
    
    const result = try client.?.set(key, value, options);
    defer result.deinit();
    
    return Response{
        .success = true,
        .data = json.Value{ .object = json.ObjectMap.init(allocator) },
        .error = null,
        .request_id = request.request_id,
    };
}

fn handleInsert(request: Request) !Response {
    if (client == null) {
        return Response{
            .success = false,
            .data = null,
            .error = "Client not connected",
            .request_id = request.request_id,
        };
    }
    
    const params = request.params.object;
    const key = params.get("key").?.string;
    const value = params.get("value").?;
    const expiry = params.get("expiry");
    const durability = params.get("durability");
    const timeout = params.get("timeout").?.integer;
    
    var options = couchbase.InsertOptions{};
    if (expiry) |exp| {
        options.expiry = @intCast(exp.integer);
    }
    if (durability) |dur| {
        options.durability = parseDurability(dur.string);
    }
    options.timeout = @intCast(timeout);
    
    const result = try client.?.insert(key, value, options);
    defer result.deinit();
    
    return Response{
        .success = true,
        .data = json.Value{ .object = json.ObjectMap.init(allocator) },
        .error = null,
        .request_id = request.request_id,
    };
}

fn handleReplace(request: Request) !Response {
    if (client == null) {
        return Response{
            .success = false,
            .data = null,
            .error = "Client not connected",
            .request_id = request.request_id,
        };
    }
    
    const params = request.params.object;
    const key = params.get("key").?.string;
    const value = params.get("value").?;
    const expiry = params.get("expiry");
    const durability = params.get("durability");
    const timeout = params.get("timeout").?.integer;
    
    var options = couchbase.ReplaceOptions{};
    if (expiry) |exp| {
        options.expiry = @intCast(exp.integer);
    }
    if (durability) |dur| {
        options.durability = parseDurability(dur.string);
    }
    options.timeout = @intCast(timeout);
    
    const result = try client.?.replace(key, value, options);
    defer result.deinit();
    
    return Response{
        .success = true,
        .data = json.Value{ .object = json.ObjectMap.init(allocator) },
        .error = null,
        .request_id = request.request_id,
    };
}

fn handleUpsert(request: Request) !Response {
    if (client == null) {
        return Response{
            .success = false,
            .data = null,
            .error = "Client not connected",
            .request_id = request.request_id,
        };
    }
    
    const params = request.params.object;
    const key = params.get("key").?.string;
    const value = params.get("value").?;
    const expiry = params.get("expiry");
    const durability = params.get("durability");
    const timeout = params.get("timeout").?.integer;
    
    var options = couchbase.UpsertOptions{};
    if (expiry) |exp| {
        options.expiry = @intCast(exp.integer);
    }
    if (durability) |dur| {
        options.durability = parseDurability(dur.string);
    }
    options.timeout = @intCast(timeout);
    
    const result = try client.?.upsert(key, value, options);
    defer result.deinit();
    
    return Response{
        .success = true,
        .data = json.Value{ .object = json.ObjectMap.init(allocator) },
        .error = null,
        .request_id = request.request_id,
    };
}

fn handleDelete(request: Request) !Response {
    if (client == null) {
        return Response{
            .success = false,
            .data = null,
            .error = "Client not connected",
            .request_id = request.request_id,
        };
    }
    
    const params = request.params.object;
    const key = params.get("key").?.string;
    const durability = params.get("durability");
    const timeout = params.get("timeout").?.integer;
    
    var options = couchbase.DeleteOptions{};
    if (durability) |dur| {
        options.durability = parseDurability(dur.string);
    }
    options.timeout = @intCast(timeout);
    
    const result = try client.?.delete(key, options);
    defer result.deinit();
    
    return Response{
        .success = true,
        .data = json.Value{ .object = json.ObjectMap.init(allocator) },
        .error = null,
        .request_id = request.request_id,
    };
}

fn handleExists(request: Request) !Response {
    if (client == null) {
        return Response{
            .success = false,
            .data = null,
            .error = "Client not connected",
            .request_id = request.request_id,
        };
    }
    
    const params = request.params.object;
    const key = params.get("key").?.string;
    const timeout = params.get("timeout").?.integer;
    
    const result = try client.?.exists(key, .{ .timeout = @intCast(timeout) });
    
    return Response{
        .success = true,
        .data = json.Value{ .bool = result },
        .error = null,
        .request_id = request.request_id,
    };
}

fn handleQuery(request: Request) !Response {
    if (client == null) {
        return Response{
            .success = false,
            .data = null,
            .error = "Client not connected",
            .request_id = request.request_id,
        };
    }
    
    const params = request.params.object;
    const statement = params.get("statement").?.string;
    const query_params = params.get("params");
    const timeout = params.get("timeout").?.integer;
    
    var options = couchbase.QueryOptions{};
    options.timeout = @intCast(timeout);
    
    if (query_params) |qp| {
        options.params = qp.array.items;
    }
    
    const result = try client.?.query(allocator, statement, options);
    defer result.deinit();
    
    // Convert result to JSON
    const json_value = try convertToJson(result);
    
    return Response{
        .success = true,
        .data = json_value,
        .error = null,
        .request_id = request.request_id,
    };
}

fn handleLookupIn(request: Request) !Response {
    if (client == null) {
        return Response{
            .success = false,
            .data = null,
            .error = "Client not connected",
            .request_id = request.request_id,
        };
    }
    
    const params = request.params.object;
    const key = params.get("key").?.string;
    const specs = params.get("specs").?.array;
    const timeout = params.get("timeout").?.integer;
    
    // Convert specs to couchbase format
    var couchbase_specs = std.ArrayList(couchbase.SubdocSpec).init(allocator);
    defer couchbase_specs.deinit();
    
    for (specs.items) |spec| {
        const spec_obj = spec.object;
        const op = spec_obj.get("op").?.string;
        const path = spec_obj.get("path").?.string;
        
        const couchbase_spec = couchbase.SubdocSpec{
            .op = parseSubdocOp(op),
            .path = path,
        };
        
        try couchbase_specs.append(couchbase_spec);
    }
    
    const result = try client.?.lookupIn(allocator, key, couchbase_specs.items);
    defer result.deinit();
    
    // Convert result to JSON
    const json_value = try convertToJson(result);
    
    return Response{
        .success = true,
        .data = json_value,
        .error = null,
        .request_id = request.request_id,
    };
}

fn handleMutateIn(request: Request) !Response {
    if (client == null) {
        return Response{
            .success = false,
            .data = null,
            .error = "Client not connected",
            .request_id = request.request_id,
        };
    }
    
    const params = request.params.object;
    const key = params.get("key").?.string;
    const specs = params.get("specs").?.array;
    const expiry = params.get("expiry");
    const durability = params.get("durability");
    const timeout = params.get("timeout").?.integer;
    
    // Convert specs to couchbase format
    var couchbase_specs = std.ArrayList(couchbase.SubdocSpec).init(allocator);
    defer couchbase_specs.deinit();
    
    for (specs.items) |spec| {
        const spec_obj = spec.object;
        const op = spec_obj.get("op").?.string;
        const path = spec_obj.get("path").?.string;
        const value = spec_obj.get("value");
        
        const couchbase_spec = couchbase.SubdocSpec{
            .op = parseSubdocOp(op),
            .path = path,
            .value = value,
        };
        
        try couchbase_specs.append(couchbase_spec);
    }
    
    var options = couchbase.MutateInOptions{};
    if (expiry) |exp| {
        options.expiry = @intCast(exp.integer);
    }
    if (durability) |dur| {
        options.durability = parseDurability(dur.string);
    }
    options.timeout = @intCast(timeout);
    
    const result = try client.?.mutateIn(allocator, key, couchbase_specs.items, options);
    defer result.deinit();
    
    // Convert result to JSON
    const json_value = try convertToJson(result);
    
    return Response{
        .success = true,
        .data = json_value,
        .error = null,
        .request_id = request.request_id,
    };
}

fn handlePing(request: Request) !Response {
    if (client == null) {
        return Response{
            .success = false,
            .data = null,
            .error = "Client not connected",
            .request_id = request.request_id,
        };
    }
    
    const result = try client.?.ping(allocator);
    defer result.deinit();
    
    // Convert result to JSON
    const json_value = try convertToJson(result);
    
    return Response{
        .success = true,
        .data = json_value,
        .error = null,
        .request_id = request.request_id,
    };
}

fn handleDiagnostics(request: Request) !Response {
    if (client == null) {
        return Response{
            .success = false,
            .data = null,
            .error = "Client not connected",
            .request_id = request.request_id,
        };
    }
    
    const result = try client.?.diagnostics(allocator);
    defer result.deinit();
    
    // Convert result to JSON
    const json_value = try convertToJson(result);
    
    return Response{
        .success = true,
        .data = json_value,
        .error = null,
        .request_id = request.request_id,
    };
}

fn parseDurability(durability_str: []const u8) couchbase.DurabilityLevel {
    if (std.mem.eql(u8, durability_str, "none")) {
        return .none;
    } else if (std.mem.eql(u8, durability_str, "majority")) {
        return .majority;
    } else if (std.mem.eql(u8, durability_str, "majority_and_persist")) {
        return .majority_and_persist;
    } else if (std.mem.eql(u8, durability_str, "persist_to_majority")) {
        return .persist_to_majority;
    } else {
        return .none;
    }
}

fn parseSubdocOp(op_str: []const u8) couchbase.SubdocOp {
    if (std.mem.eql(u8, op_str, "get")) {
        return .get;
    } else if (std.mem.eql(u8, op_str, "set")) {
        return .set;
    } else if (std.mem.eql(u8, op_str, "upsert")) {
        return .upsert;
    } else if (std.mem.eql(u8, op_str, "insert")) {
        return .insert;
    } else if (std.mem.eql(u8, op_str, "remove")) {
        return .remove;
    } else if (std.mem.eql(u8, op_str, "replace")) {
        return .replace;
    } else if (std.mem.eql(u8, op_str, "increment")) {
        return .increment;
    } else if (std.mem.eql(u8, op_str, "decrement")) {
        return .decrement;
    } else if (std.mem.eql(u8, op_str, "append")) {
        return .append;
    } else if (std.mem.eql(u8, op_str, "prepend")) {
        return .prepend;
    } else {
        return .get;
    }
}

fn convertToJson(value: anytype) !json.Value {
    // This is a simplified conversion - in a real implementation,
    // you'd need to handle all the different types properly
    return json.Value{ .object = json.ObjectMap.init(allocator) };
}

fn sendResponse(response: Response) !void {
    const json_string = try json.stringifyAlloc(allocator, response, .{});
    defer allocator.free(json_string);
    
    std.debug.print("{s}\n", .{json_string});
}

// Cleanup function
pub fn deinit() void {
    if (client) |*c| {
        c.close();
    }
}
