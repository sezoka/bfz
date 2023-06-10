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
    const unbuff_writer = std.io.getStdOut().writer();
    var buff = std.io.BufferedWriter(128, @TypeOf(unbuff_writer)){ .unbuffered_writer = unbuff_writer };
    const writer = buff.writer();

    var mem = [_]u8{0} ** 3000;
    var sp: [*]u8 = &mem;
    var ip: [*]Op = @ptrCast([*]Op, ops.items);
    var op: Op = undefined;

    while (true) {
        op = ip[0];

        switch (op.code) {
            .add => {
                if (op.a1 < 0) {
                    sp[0] = @subWithOverflow(sp[0], @intCast(u8, @rem(-op.a1, 256)))[0];
                } else {
                    sp[0] = @addWithOverflow(sp[0], @intCast(u8, @rem(op.a1, 256)))[0];
                }
            },
            .set => {
                sp[0] = @intCast(u8, op.a1);
            },
            .add_offset => {
                sp[@intCast(usize, op.a2)] += @intCast(u8, op.a1);
            },
            .set_offset => {
                sp[@intCast(usize, op.a2)] = @intCast(u8, op.a1);
            },
            .shift => {
                sp = if (op.a1 < 0) sp - @intCast(usize, -op.a1) else sp + @intCast(usize, op.a1);
            },
            .mac => {
                sp[0] += @intCast(u8, op.a1 * sp[@intCast(usize, op.a2)]);
            },
            .shift_until_zero => {
                while (sp[0] != 0) {
                    sp += @intCast(usize, op.a1);
                }
            },
            .jmp_zero => {
                if (sp[0] == 0) {
                    ip = @ptrCast([*]Op, ops.items) + @intCast(usize, op.a1);
                } else {
                    ip += 1;
                }
                continue;
            },
            .jmp_not_zero => {
                if (sp[0] != 0) {
                    ip = @ptrCast([*]Op, ops.items) + @intCast(usize, op.a1);
                } else {
                    ip += 1;
                }
                continue;
            },
            .char_out => {
                try writer.writeByte(sp[0]);
                if (sp[0] == '\n') {
                    try buff.flush();
                }
            },
            // .char_in => {},
            .end => return,
            else => unreachable,
        }

        ip += 1;
    }
}
