const std = @import("std");
const builtin = @import("builtin");
const compress = std.compress;
const mem = std.mem;

allocator: mem.Allocator,
fold: [][]u21 = undefined,
cwcf: []bool = undefined,

const Self = @This();

pub fn init(allocator: mem.Allocator) !Self {
    const decompressor = compress.flate.inflate.decompressor;
    const in_bytes = @embedFile("fold");
    var in_fbs = std.io.fixedBufferStream(in_bytes);
    var in_decomp = decompressor(.raw, in_fbs.reader());
    var reader = in_decomp.reader();

    const endian = builtin.cpu.arch.endian();
    var self = Self{
        .allocator = allocator,
        .fold = try allocator.alloc([]u21, 0x110000),
        .cwcf = try allocator.alloc(bool, 0x110000),
    };

    var slices: usize = 0;
    errdefer {
        for (self.fold[0..slices]) |slice| self.allocator.free(slice);
        self.allocator.free(self.fold);
        self.allocator.free(self.cwcf);
    }

    @memset(self.fold, &.{});
    @memset(self.cwcf, false);

    while (true) {
        const len: u8 = try reader.readInt(u8, endian);
        if (len == 0) break;
        const cp = try reader.readInt(u24, endian);
        self.fold[cp >> 1] = try allocator.alloc(u21, len - 1);
        slices += 1;
        for (0..len - 1) |i| {
            self.fold[cp >> 1][i] = @intCast(try reader.readInt(u24, endian));
        }
        self.cwcf[cp >> 1] = cp & 1 == 1;
    }

    return self;
}

pub fn deinit(self: *const Self) void {
    for (self.fold) |slice| self.allocator.free(slice);
    self.allocator.free(self.fold);
    self.allocator.free(self.cwcf);
}

/// Returns the case fold for `cp`.
pub inline fn caseFold(self: Self, cp: u21) []const u21 {
    return self.fold[cp];
}

/// Returns true when caseFold(NFD(`cp`)) != NFD(`cp`).
pub inline fn changesWhenCaseFolded(self: Self, cp: u21) bool {
    return self.cwcf[cp];
}
