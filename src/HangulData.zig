const std = @import("std");
const builtin = @import("builtin");
const compress = std.compress;
const mem = std.mem;
const testing = std.testing;

pub const Syllable = enum {
    none,
    L,
    LV,
    LVT,
    V,
    T,
};

allocator: mem.Allocator,
s1: []u16 = undefined,
s2: []u3 = undefined,

const Self = @This();

pub fn init(allocator: mem.Allocator) !Self {
    const decompressor = compress.flate.inflate.decompressor;
    const in_bytes = @embedFile("hangul");
    var in_fbs = std.io.fixedBufferStream(in_bytes);
    var in_decomp = decompressor(.raw, in_fbs.reader());
    var reader = in_decomp.reader();

    const endian = builtin.cpu.arch.endian();
    var self = Self{ .allocator = allocator };

    const stage_1_len: u16 = try reader.readInt(u16, endian);
    self.s1 = try allocator.alloc(u16, stage_1_len);
    errdefer allocator.free(self.s1);
    for (0..stage_1_len) |i| self.s1[i] = try reader.readInt(u16, endian);

    const stage_2_len: u16 = try reader.readInt(u16, endian);
    self.s2 = try allocator.alloc(u3, stage_2_len);
    errdefer allocator.free(self.s2);
    for (0..stage_2_len) |i| self.s2[i] = @intCast(try reader.readInt(u8, endian));

    return self;
}

pub fn deinit(self: *const Self) void {
    self.allocator.free(self.s1);
    self.allocator.free(self.s2);
}

/// Returns the Hangul syllable type for `cp`.
pub inline fn syllable(self: Self, cp: u21) Syllable {
    return @enumFromInt(self.s2[self.s1[cp >> 8] + (cp & 0xff)]);
}
