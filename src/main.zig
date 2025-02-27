const rl = @import("raylib");
const std = @import("std");

const allocator = std.heap.page_allocator;

const G = 6.67e-11;

pub fn main() anyerror!void {
    const screenWidth = 800;
    const screenHeight = 450;

    var t:f64 = 0.0;
    const dt = 2500.0;
    const num_objects = 3;
    var x: [num_objects]f64 = [_]f64{
        0.0,
        384400000.0,
        350000000.0,
    };
    var y: [num_objects]f64 = [_]f64{
        0.0,
        0.0,
        0.0,
    };
    var vx: [num_objects]f64 = [_]f64{
        0.0,
        0.0,
        -300.0,
    };
    var vy: [num_objects]f64 = [_]f64{
        0.0,
        1000.0,
        1000.0,
    };
    const m: [num_objects]f64 = [_]f64{
        5.97e24, // Mass of Earth in kg
        7.34e22, // Mass of Moon in kg
        1.0e3,   // 1 tonne ship
    };

    rl.setConfigFlags(.{ .msaa_4x_hint = true });

    rl.initWindow(screenWidth, screenHeight, "Gravity Attraction with Multiple Objects");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        var ax: [num_objects]f64 = [_]f64{ 0.0 } ** num_objects;
        var ay: [num_objects]f64 = [_]f64{ 0.0 } ** num_objects;

        // Calculate gravitational forces between all pairs
        for (0..num_objects) |i| {
            for (i + 1..num_objects) |j| {
                const deltaX = x[j] - x[i];
                const deltaY = y[j] - y[i];
                var r = @sqrt(deltaX * deltaX + deltaY * deltaY);

                // Prevent division by zero
                if (r == 0.0) {
                    r = 0.0001;
                }

                const F = G * m[i] * m[j] / (r * r);

                const ux = deltaX / r;
                const uy = deltaY / r;

                // Update accelerations
                ax[i] += (F / m[i]) * ux;
                ay[i] += (F / m[i]) * uy;
                ax[j] -= (F / m[j]) * ux;
                ay[j] -= (F / m[j]) * uy;
            }
        }

        // Update velocities and positions
        for (0..num_objects) |i| {
            vx[i] += ax[i] * dt;
            vy[i] += ay[i] * dt;
            x[i] += vx[i] * dt;
            y[i] += vy[i] * dt;
        }
        t += dt;

        // Draw
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.dark_gray);

        // Draw objects
        inline for (0..num_objects) |i| {
            const screen_x:i32 = @intFromFloat(x[i] / 2000000.0);
            const screen_y:i32 = @intFromFloat(y[i] / 2000000.0);

            const color = switch (i) {
                inline 0 => rl.Color.light_gray,
                inline 1 => rl.Color.light_gray,
                inline 2 => rl.Color.red,
                inline else => rl.Color.white,
            };
            const radius = switch (i) {
                inline 0 => 30,
                inline 1 => 10,
                inline 2 => 5,
                inline else => 5,
            };
            rl.drawCircle(screen_x + 400, screen_y + 200, radius, color);
        }

        const gstr = try std.fmt.allocPrintZ(allocator, "G: {e}", .{ G });
        defer allocator.free(gstr);
        rl.drawText(gstr, 5, 5, 20, rl.Color.black);

        const tstr = try std.fmt.allocPrintZ(allocator, "t: {d}", .{ t });
        defer allocator.free(tstr);
        rl.drawText(tstr, 5, 22, 20, rl.Color.black);
    }
}
