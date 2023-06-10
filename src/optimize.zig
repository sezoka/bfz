const std = @import("std");
const vm = @import("vm.zig");

const Optimizer = *const fn (ops: *std.ArrayList(vm.Op), begin: usize, end: usize) bool;

pub fn optimize(alloc: std.mem.Allocator, ops: *std.ArrayList(vm.Op)) !void {
    const pass_count = 10;
    _ = alloc;

    const tasks = [1]([1]Optimizer){
        .{&merge_stackable},
    };

    for (0..tasks.len) |stage| {
        for (0..pass_count) |_| {
            var pass_effective = false;

            for (tasks[stage]) |task| {
                pass_effective = task(ops, 0, ops.items.len);
            }

            if (!pass_effective) break;
        }
    }

    // print_opcodes(ops.items);
}

fn print_opcodes(ops: []vm.Op) void {
    for (ops) |op| {
        const c = @as(u8, switch (op.code) {
            .add => if (op.a1 < 0) '-' else '+',
            .set => '!',
            .add_offset => '^',
            .set_offset => '*',
            .shift => if (op.a1 < 0) '<' else '>',
            .mac => 'm',
            .shift_until_zero => '0',

            .jmp_zero => 'z',
            .jmp_not_zero => 'n',

            .char_out => '.',
            .char_in => ',',

            .loop_begin => '[',
            .loop_end => ']',
            else => continue,
        });
        std.debug.print("{c}", .{c});
    }
}

fn merge_stackable(ops: *std.ArrayList(vm.Op), begin: usize, end: usize) bool {
    const items = ops.items;
    var i = begin;
    while (i < end) : (i += 1) {
        const iop = items[i];
        if (iop.code != .add and iop.code != .shift) continue;

        var j = i + 1;
        while (j < end and items[j].code == iop.code) : (j += 1) {
            items[i].a1 += items[j].a1;
            items[j].code = .nop;
        }
    }

    return erase_nop(ops);
}

fn erase_nop(ops: *std.ArrayList(vm.Op)) bool {
    const old_size = ops.items.len;
    var i: usize = 0;
    while (i < ops.items.len) {
        if (ops.items[i].code == .nop) {
            _ = ops.orderedRemove(i);
        } else {
            i += 1;
        }
    }

    return old_size != ops.items.len;
}
