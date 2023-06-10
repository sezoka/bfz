const std = @import("std");

pub const Op_Code = enum {
    add,
    set,
    add_offset,
    set_offset,
    shift,
    mac,
    shift_until_zero,

    jmp_zero,
    jmp_not_zero,

    char_out,
    char_in,

    end,

    loop_begin,
    loop_end,

    total,

    nop,
};

pub const Arg = i32;

pub const Op = struct {
    code: Op_Code,
    a1: Arg,
    a2: Arg,
};

pub fn interpret(ops: std.ArrayList(Op)) !void {
    const writer = std.io.getStdOut().writer();
    var mem = [_]u8{0} ** 3000;
    var sp: [*]u8 = &mem;
    var ip: [*]Op = @ptrCast([*]Op, ops.items);

    var op: Op = ip[0];

    while (true) {
        // std.debug.print("{}\n", .{op.code});
        switch (op.code) {
            .add => {
                sp[0] = if (op.a1 < 0) @subWithOverflow(sp[0], @intCast(u8, -op.a1))[0] else @addWithOverflow(sp[0], @intCast(u8, op.a1))[0];
                ip += 1;
                op = ip[0];
            },
            .set => {
                sp[0] = @intCast(u8, op.a1);
                ip += 1;
                op = ip[0];
            },
            .add_offset, .set_offset => {
                sp[@intCast(usize, op.a2)] += @intCast(u8, op.a1);
                ip += 1;
                op = ip[0];
            },
            .shift => {
                sp = if (op.a1 < 0) sp - @intCast(usize, -op.a1) else sp + @intCast(usize, op.a1);
                ip += 1;
                op = ip[0];
            },
            .mac => {
                sp[0] += @intCast(u8, op.a1 * sp[@intCast(usize, op.a2)]);
                ip += 1;
                op = ip[0];
            },
            .shift_until_zero => {
                while (sp[0] != 0) {
                    sp += @intCast(usize, op.a1);
                }
                ip += 1;
                op = ip[0];
            },
            .jmp_zero => {
                if (sp[0] == 0) {
                    ip = @ptrCast([*]Op, ops.items) + @intCast(usize, op.a1);
                } else {
                    ip += 1;
                }
                op = ip[0];
            },
            .jmp_not_zero => {
                if (sp[0] != 0) {
                    ip = @ptrCast([*]Op, ops.items) + @intCast(usize, op.a1);
                } else {
                    ip += 1;
                }
                op = ip[0];
            },
            .char_out => {
                try writer.writeByte(sp[0]);
                ip += 1;
                op = ip[0];
            },
            .char_in => {
                ip += 1;
                op = ip[0];
            },
            .end => return,
            else => unreachable,
        }
    }
}
