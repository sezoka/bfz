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

pub const Arg = i16;

pub const Op = struct {
    code: Op_Code,
    a1: Arg = 0,
    a2: Arg = 0,
};

pub fn interpret(ops: std.ArrayList(Op)) !void {
    const reader = std.io.getStdIn().reader();
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
                const shifted = if (op.a2 < 0) sp - @intCast(usize, -op.a2) else sp + @intCast(usize, op.a2);
                if (op.a1 < 0) {
                    shifted[0] = @subWithOverflow(shifted[0], @intCast(u8, @rem(-op.a1, 256)))[0];
                } else {
                    shifted[0] = @addWithOverflow(shifted[0], @intCast(u8, @rem(op.a1, 256)))[0];
                }
            },
            .set_offset => {
                const shifted = if (op.a2 < 0) sp - @intCast(usize, -op.a2) else sp + @intCast(usize, op.a2);
                shifted[0] = @intCast(u8, @rem(op.a1, 256));
            },
            .shift => {
                sp = if (op.a1 < 0) sp - @intCast(usize, -op.a1) else sp + @intCast(usize, op.a1);
            },
            .mac => {
                sp[0] += @intCast(u8, op.a1 * sp[@intCast(usize, op.a2)]);
            },
            .shift_until_zero => {
                while (sp[0] != 0) {
                    sp = if (op.a1 < 0) sp - @intCast(usize, -op.a1) else sp + @intCast(usize, op.a1);
                }
            },
            .jmp_zero => {
                if (sp[0] == 0) {
                    ip = @ptrCast([*]Op, ops.items.ptr) + @intCast(usize, op.a1);
                } else {
                    ip += 1;
                }
                continue;
            },
            .jmp_not_zero => {
                if (sp[0] != 0) {
                    ip = @ptrCast([*]Op, ops.items.ptr) + @intCast(usize, op.a1);
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
            .char_in => {
                sp[0] = reader.readByte() catch 0;
            },
            .end => return,
            else => unreachable,
        }

        ip += 1;
    }
}
