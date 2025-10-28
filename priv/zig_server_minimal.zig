const std = @import("std");

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
        
        // For now, just echo back a simple JSON response
        std.debug.print("{{\"success\":true,\"data\":{{}},\"error\":\"\",\"request_id\":1}}\n", .{});
    }
}