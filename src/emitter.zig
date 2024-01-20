const std = @import("std");
const Op = @import("./vm.zig").Op;

pub fn emit(ally: std.mem.Allocator, ops: []Op) !void {
    var buff = std.ArrayList(u8).init(ally);
    defer buff.deinit();

    const writer = buff.writer();

    try writer.writeAll("int main() {\n");
    try writer.writeAll("  char mem[3000] = {0};\n");
    try writer.writeAll("  char *sp = 0;\n");

    for (ops) |op| {
        switch (op.code) {
            .add => {
                if (op.a1 < 0) {
                    try writer.print("  *sp -= {};\n", .{-op.a1});
                } else {
                    try writer.print("  *sp += {};\n", .{op.a1});
                }
            },
            .set => {
                try writer.print("  *sp = {};\n", .{op.a1});
            },
            .add_offset => {
                try writer.print("  *(sp + {}) += {};\n", .{ op.a2, op.a1 });
            },
            .set_offset => {
                try writer.print("  *(sp + {}) = {};\n", .{ op.a2, op.a1 });
            },
            .shift => {
                try writer.print("  sp += {};\n", .{op.a1});
            },
            .mac => {
                try writer.print("  *sp += {} * sp[{}];\n", .{ op.a1, op.a2 });
            },
            .shift_until_zero => {
                try writer.print("  while (*sp != 0) sp += {} \n", .{op.a1});
            },
            .jmp_zero => {
                try writer.print("  while (*sp != 0) sp += {} \n", .{op.a1});
                if (sp[0] == 0) {
                    ip = @as([*]Op, @ptrCast(ops.ptr)) + @as(usize, @intCast(@as(u16, @as(u16, @bitCast(op.a1)))));
                } else {
                    ip += 1;
                }
                continue;
            },
            else => {},


            // jmp_zero,
            // jmp_not_zero,

            // char_out,
            // char_in,

            // end,

            // loop_begin,
            // loop_end,

            // total,

            // nop,
        }
    }

    try buff.appendSlice("  return 0;\n");
    try buff.appendSlice("}\n");

    std.debug.print("{s}\n", .{buff.items});
}
