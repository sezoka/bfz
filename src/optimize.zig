const std = @import("std");
const vm = @import("vm.zig");

const Optimizer = *const fn (ops: *std.ArrayList(vm.Op), begin: usize, end: usize) bool;
const Optimization_Sequence = struct {
    seq: []const vm.Op_Kind,
    fun: *const fn (v: []vm.Op) void,
};

pub fn optimize(alloc: std.mem.Allocator, ops: *std.ArrayList(vm.Op)) !void {
    const pass_count = 10;
    _ = alloc;

    const tasks = [_]([2]Optimizer){
        .{ merge_stackable, stage_1_peephole },
        .{ merge_stackable, stage_2_peephole },
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

pub fn stage_1_peephole(ops: *std.ArrayList(vm.Op), begin: usize, end: usize) bool {
    const optimizer_functions = struct {
        fn set_zero(v: []vm.Op) void {
            v[0] = .{ .code = .set, .a1 = 0 };
            v[1] = .{ .code = .nop };
            v[2] = .{ .code = .nop };
        }
        fn add_to_set(v: []vm.Op) void {
            v[0] = .{ .code = .set, .a1 = v[0].a1 + v[1].a1 };
            v[1] = .{ .code = .nop };
        }
        fn replace_add_with_set(v: []vm.Op) void {
            v[0] = .{ .code = .set, .a1 = v[1].a1 };
            v[1] = .{ .code = .nop };
        }
        fn dedup_sets(v: []vm.Op) void {
            v[0] = .{ .code = .set, .a1 = v[1].a1 };
            v[1] = .{ .code = .nop };
        }
        fn scan_loop(v: []vm.Op) void {
            v[0] = .{ .code = .shift_until_zero, .a1 = v[1].a1 };
            v[1] = .{ .code = .nop };
            v[2] = .{ .code = .nop };
        }
    };

    const optimizers = [_]Optimization_Sequence{ .{
        .seq = &[_]vm.Op_Kind{ .loop_begin, .add, .loop_end },
        .fun = optimizer_functions.set_zero,
    }, .{
        .seq = &[_]vm.Op_Kind{ .set, .add },
        .fun = optimizer_functions.add_to_set,
    }, .{
        .seq = &[_]vm.Op_Kind{ .add, .set },
        .fun = optimizer_functions.replace_add_with_set,
    }, .{
        .seq = &[_]vm.Op_Kind{ .set, .set },
        .fun = optimizer_functions.dedup_sets,
    }, .{
        .seq = &[_]vm.Op_Kind{ .loop_begin, .shift, .loop_end },
        .fun = optimizer_functions.scan_loop,
    } };

    return peephole_optimize_for(ops, begin, end, &optimizers);
}

pub fn stage_2_peephole(ops: *std.ArrayList(vm.Op), begin: usize, end: usize) bool {
    const optimizer_functions = struct {
        fn shifted_add(v: []vm.Op) void {
            const v0 = v[0];
            const v1 = v[1];
            v[0] = .{ .code = .add_offset, .a1 = v1.a1, .a2 = v0.a1 };
            v[1] = v0;
        }
        fn shifted_add_offset(v: []vm.Op) void {
            const v0 = v[0];
            const v1 = v[1];
            v[0] = .{ .code = .add_offset, .a1 = v1.a1, .a2 = v1.a2 + v0.a1 };
            v[1] = v0;
        }
        fn shifted_set(v: []vm.Op) void {
            const v0 = v[0];
            const v1 = v[1];
            v[0] = .{ .code = .set_offset, .a1 = v1.a1, .a2 = v0.a1 };
            v[1] = v0;
        }
        fn shifted_set_offset(v: []vm.Op) void {
            const v0 = v[0];
            const v1 = v[1];
            v[0] = .{ .code = .set_offset, .a1 = v1.a1, .a2 = v0.a1 + v0.a1 };
            v[1] = v0;
        }
    };

    const optimizers = [_]Optimization_Sequence{
        .{
            .seq = &[_]vm.Op_Kind{ .shift, .add },
            .fun = optimizer_functions.shifted_add,
        },
        .{
            .seq = &[_]vm.Op_Kind{ .shift, .add_offset },
            .fun = optimizer_functions.shifted_add_offset,
        },
        .{
            .seq = &[_]vm.Op_Kind{ .shift, .set },
            .fun = optimizer_functions.shifted_set,
        },
        .{
            .seq = &[_]vm.Op_Kind{ .set, .set_offset },
            .fun = optimizer_functions.shifted_set_offset,
        },
    };

    return peephole_optimize_for(ops, begin, end, &optimizers);
}

fn peephole_optimize_for(ops: *std.ArrayList(vm.Op), begin: usize, end: usize, optimizers: []const Optimization_Sequence) bool {
    var effective = false;

    for (optimizers) |optimizer| {
        var pos = search_seq(begin, ops.items, optimizer.seq);

        while (pos != end) {
            optimizer.fun(ops.items[pos .. pos + 3]);

            effective = true;

            pos = search_seq(pos + 1, ops.items, optimizer.seq);
        }
    }

    _ = erase_nop(ops);

    return effective;
}

fn search_seq(start: usize, arr: []vm.Op, seq: []const vm.Op_Kind) usize {
    var pos = start + seq.len - 1;
    outer: while (pos < arr.len) {
        var i: usize = 0;
        while (i < seq.len) {
            if (seq[seq.len - i - 1] != arr[pos - i].code) {
                pos += 1;
                continue :outer;
            }
            i += 1;
        }
        return pos + 1 - seq.len;
    }
    return arr.len;
}
