const std = @import("std");

pub fn getCurrentTimestamp() i64 {
    return std.time.timestamp();
}

pub fn isOlderThanDays(timestamp: i64, days: u32) bool {
    const current = std.time.timestamp();
    const castDays: i64 = @intCast(days);
    const days_in_seconds: i64 = castDays * 24 * 60 * 60;
    return (current - timestamp) > days_in_seconds;
}

pub fn formatTimeStamp(arena: *std.heap.ArenaAllocator, timestamp: i64) ![]u8 {
    const castTimeStamp: u64 = @intCast(timestamp);
    const epoch_secs = std.time.epoch.EpochSeconds{ .secs = castTimeStamp };
    const day_secs = epoch_secs.getDaySeconds();
    const epoch_day = epoch_secs.getEpochDay();
    const year_day = epoch_day.calculateYearDay();
    const month_day = year_day.calculateMonthDay();

    return std.fmt.allocPrint(
        arena.allocator(),
        "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}",
        .{
            year_day.year,
            month_day.month.numeric(),
            month_day.day_index + 1,
            day_secs.getHoursIntoDay(),
            day_secs.getMinutesIntoHour(),
            day_secs.getSecondsIntoMinute(),
        },
    );
}

pub fn parseTimeStamp(timestamp_str: []const u8) !i64 {
    if (timestamp_str.len != 19 or timestamp_str[10] != 'T') return error.InvalidFormat;

    const year = try std.fmt.parseInt(i32, timestamp_str[0..4], 10);
    const month_u = try std.fmt.parseInt(u8, timestamp_str[5..7], 10);
    const day = try std.fmt.parseInt(u8, timestamp_str[8..10], 10);
    const hour = try std.fmt.parseInt(u8, timestamp_str[11..13], 10);
    const minute = try std.fmt.parseInt(u8, timestamp_str[14..16], 10);
    const second = try std.fmt.parseInt(u8, timestamp_str[17..19], 10);

    if (month_u < 1 or month_u > 12) return error.InvalidDate;
    if (day < 1 or day > 31) return error.InvalidDate;
    if (hour > 23 or minute > 59 or second > 59) return error.InvalidDate;

    const month_index: u8 = month_u - 1;

    var days_since_epoch: u64 = 0;
    var y: std.time.epoch.Year = std.time.epoch.epoch_year;
    const target_year: std.time.epoch.Year = @intCast(year);

    while (y < target_year) : (y += 1) {
        days_since_epoch += @as(u64, std.time.epoch.getDaysInYear(y));
    }

    const is_leap = std.time.epoch.isLeapYear(target_year);

    const nonleap: [12]u8 = .{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    const leap: [12]u8 = .{ 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };

    var i: u8 = 0;
    while (i < month_index) : (i += 1) {
        days_since_epoch += @as(u64, if (is_leap) leap[i] else nonleap[i]);
    }

    days_since_epoch += @as(u64, day - 1);

    const secs_of_day: u64 = @as(u64, hour) * 3600 + @as(u64, minute) * 60 + @as(u64, second);
    const total_secs: u64 = days_since_epoch * 86400 + secs_of_day;
    const final: i64 = @intCast(total_secs);
    return final;
}
