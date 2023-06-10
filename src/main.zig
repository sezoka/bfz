const std = @import("std");
const vm = @import("vm.zig");
const log = std.log;

// const Op = struct {
//     code: vm.Op_Code,
//     arg: u8,
// };

pub fn main() !void {
    var args = std.process.args();
    _ = args.next().?;
    const file_path = args.next() orelse {
        log.info("usage: bfz <program.b>", .{});
        return;
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const file = try read_file(alloc, file_path);
    defer alloc.free(file);

    var ops = try compile(alloc, file);
    defer ops.deinit();

    try link_program(alloc, &ops);

    try vm.interpret(ops);
}

fn link_program(alloc: std.mem.Allocator, ops: *std.ArrayList(vm.Op)) !void {
    var jumps = std.ArrayList(u32).init(alloc);
    defer jumps.deinit();

    var i: u32 = 0;
    for (ops.items) |*op| {
        switch (op.code) {
            .loop_begin => {
                op.code = .jmp_zero;
                try jumps.append(i);
            },
            .loop_end => if (jumps.popOrNull()) |start_pos| {
                op.code = .jmp_not_zero;
                ops.items[start_pos].a1 = @intCast(i32, i + 1);
                op.a1 = @intCast(i32, start_pos + 1);
            } else {
                log.err("unexpected ']': missing '['", .{});
                return error.MissingBrace;
            },
            else => {},
        }
        i += 1;
    }

    if (jumps.items.len != 0) {
        log.err("Unexpected '[': missing ']'", .{});
    }
}

fn read_file(alloc: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.fs.cwd().readFileAlloc(alloc, path, 102400) catch |err| {
        log.err("can't read file using path '{s}'.", .{path});
        return err;
    };
}

fn compile(alloc: std.mem.Allocator, source: []const u8) !std.ArrayList(vm.Op) {
    var ops = try std.ArrayList(vm.Op).initCapacity(alloc, source.len);

    for (source) |c| {
        const op: vm.Op = switch (c) {
            '+' => .{ .code = .add, .a1 = 1, .a2 = 0 },
            '-' => .{ .code = .add, .a1 = -1, .a2 = 0 },
            '>' => .{ .code = .shift, .a1 = 1, .a2 = 0 },
            '<' => .{ .code = .shift, .a1 = -1, .a2 = 0 },
            '.' => .{ .code = .char_out, .a1 = 1, .a2 = 0 },
            ',' => .{ .code = .char_in, .a1 = 1, .a2 = 0 },
            '[' => .{ .code = .loop_begin, .a1 = 1, .a2 = 0 },
            ']' => .{ .code = .loop_end, .a1 = 1, .a2 = 0 },
            else => continue,
        };
        try ops.append(op);
    }

    try ops.append(.{ .code = .end, .a1 = 0, .a2 = 0 });

    try ops.ensureTotalCapacityPrecise(ops.items.len);

    return ops;
}
