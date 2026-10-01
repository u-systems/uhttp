const std = @import("std");

extern fn http_start_server(handler: *const fn (?*anyopaque, [*]u8, i32) callconv(.c) void) callconv(.c) void;
extern fn http_send_response(fd: i32, h_buf: [*]const u8, h_len: u64, b_buf: [*]const u8, b_len: u64) callconv(.c) void;

const headers = "HTTP/1.1 200 OK\r\nServer: asmhttp-zig\r\nContent-Type: text/plain\r\nContent-Length: 15\r\n\r\n";
const body = "Hello from Zig\n";

fn handle_request(req: ?*anyopaque, wire_buf: [*]u8, client_fd: i32) callconv(.c) void {
    _ = req;
    _ = wire_buf;
    http_send_response(client_fd, headers.ptr, headers.len, body.ptr, body.len);
}

pub fn main() void {
    http_start_server(handle_request);
}
