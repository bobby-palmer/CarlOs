const MAX_ORDER = 16;

const ListHeader = struct {
    next: ?*@This()
};

var free_lists = [_]ListHeader{ListHeader{.next = null}} ** MAX_ORDER;

// Fix me
pub fn addRam(start: u64, end: u64) void {

    var cstart = start;
    var order: i32 = MAX_ORDER - 1;

    while (order >= 0) : (order -= 1) {
        const sh = 4096 * (@as(u32, 1) << @intCast(order));

        if (cstart + sh <= end)  {

            var header = @as(*ListHeader, @ptrFromInt(cstart));

            header.next = free_lists[@intCast(order)].next;
            free_lists[@intCast(order)].next = header;
            
            cstart += sh;
        }
    }
}
