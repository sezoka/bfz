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

var op_counter = [_]u32{0} ** 16;

fn count_op(code: Op_Code) void {
    op_counter[@intFromEnum(code)] += 1;
}

fn print_cnt() void {
    std.debug.print("{d} add\n", .{op_counter[@intFromEnum(Op_Code.add)]});
    std.debug.print("{d} set\n", .{op_counter[@intFromEnum(Op_Code.set)]});
    std.debug.print("{d} add_offset\n", .{op_counter[@intFromEnum(Op_Code.add_offset)]});
    std.debug.print("{d} set_offset\n", .{op_counter[@intFromEnum(Op_Code.set_offset)]});
    std.debug.print("{d} shift\n", .{op_counter[@intFromEnum(Op_Code.shift)]});
    std.debug.print("{d} mac\n", .{op_counter[@intFromEnum(Op_Code.mac)]});
    std.debug.print("{d} shift_until_zero\n", .{op_counter[@intFromEnum(Op_Code.shift_until_zero)]});
    std.debug.print("{d} jmp_zero\n", .{op_counter[@intFromEnum(Op_Code.jmp_zero)]});
    std.debug.print("{d} jmp_not_zero\n", .{op_counter[@intFromEnum(Op_Code.jmp_not_zero)]});
    std.debug.print("{d} char_out\n", .{op_counter[@intFromEnum(Op_Code.char_out)]});
    std.debug.print("{d} char_in\n", .{op_counter[@intFromEnum(Op_Code.char_in)]});
}

pub fn interpret(ops: std.ArrayList(Op)) !void {
    const reader = std.io.getStdIn().reader();
    const unbuff_writer = std.io.getStdOut().writer();
    var buff = std.io.BufferedWriter(128, @TypeOf(unbuff_writer)){ .unbuffered_writer = unbuff_writer };
    const writer = buff.writer();

    var mem = [_]u8{0} ** 3000;
    var sp: [*]u8 = &mem;
    var ip: [*]Op = @ptrCast(ops.items);
    var op: Op = undefined;

    while (true) {
        op = ip[0];

        switch (op.code) {
            .add => {
                // count_op(.add);
                @setRuntimeSafety(false);
                sp[0] = @truncate(@as(u16, @bitCast(@as(i16, @intCast(sp[0])) + op.a1)));
            },
            .set => {
                // count_op(.set);
                @setRuntimeSafety(false);
                sp[0] = @intCast(op.a1);
            },
            .add_offset => {
                // count_op(.add_offset);
                @setRuntimeSafety(false);
                const shifted = @as(@TypeOf(sp), @ptrFromInt(@as(usize, @bitCast(@as(isize, @bitCast(@intFromPtr(sp))) + op.a2))));
                shifted[0] = @truncate(@as(u16, @bitCast(@as(i16, @intCast(shifted[0])) + op.a1)));
            },
            .set_offset => {
                // count_op(.set_offset);
                @setRuntimeSafety(false);
                const shifted = @as(@TypeOf(sp), @ptrFromInt(@as(usize, @bitCast(@as(isize, @bitCast(@intFromPtr(sp))) + op.a2))));
                shifted[0] = @truncate(@as(u16, @bitCast(op.a1)));
            },
            .shift => {
                // count_op(.shift);
                @setRuntimeSafety(false);
                sp = @as(@TypeOf(sp), @ptrFromInt(@as(usize, @bitCast(@as(isize, @bitCast(@intFromPtr(sp))) + op.a1))));
            },
            .mac => {
                // count_op(.mac);
                sp[0] += @intCast(op.a1 * sp[@intCast(op.a2)]);
            },
            .shift_until_zero => {
                // count_op(.shift_until_zero);
                while (sp[0] != 0) {
                    sp = @as(@TypeOf(sp), @ptrFromInt(@as(usize, @bitCast(@as(isize, @bitCast(@intFromPtr(sp))) + op.a1))));
                }
            },
            .jmp_zero => {
                @setRuntimeSafety(false);
                // count_op(.jmp_zero);
                if (sp[0] == 0) {
                    ip = @as([*]Op, @ptrCast(ops.items.ptr)) + @as(usize, @intCast(@as(u16, @as(u16, @bitCast(op.a1)))));
                } else {
                    ip += 1;
                }
                continue;
            },
            .jmp_not_zero => {
                @setRuntimeSafety(false);
                // count_op(.jmp_not_zero);
                if (sp[0] != 0) {
                    ip = @as([*]Op, @ptrCast(ops.items.ptr)) + @as(usize, @intCast(@as(u16, @bitCast(op.a1))));
                } else {
                    ip += 1;
                }
                continue;
            },
            .char_out => {
                // count_op(.char_out);
                try writer.writeByte(sp[0]);
                if (sp[0] == '\n') {
                    try buff.flush();
                }
            },
            .char_in => {
                // count_op(.char_in);
                sp[0] = reader.readByte() catch 0;
            },
            .end => {
                // print_cnt();
                return;
            },
            else => unreachable,
        }

        ip += 1;
    }
}
