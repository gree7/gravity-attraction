const rl = @import("raylib");
const std = @import("std");

const allocator = std.heap.page_allocator;

const G = 6.67e-11;

pub fn main() anyerror!void {
    const screenWidth = 800;
    const screenHeight = 450;

    var random = std.rand.DefaultPrng.init(12345);
    const rnd = random.random();

    var t:f64 = 0.0;
    const dt = 2500.0;

    const grid_size = 20; // 10x10 grid
    const num_objects = grid_size * grid_size;

    var x = try allocator.alloc(f64, num_objects);
    var y = try allocator.alloc(f64, num_objects);
    var vx = try allocator.alloc(f64, num_objects);
    var vy = try allocator.alloc(f64, num_objects);
    var m = try allocator.alloc(f64, num_objects);
    defer allocator.free(x);
    defer allocator.free(y);
    defer allocator.free(vx);
    defer allocator.free(vy);
    defer allocator.free(m);

    // Initialize bodies in a grid with randomized masses
    const spacing = 1e8; // Spacing between bodies
    const spacing_variation = 1e7; // Variation in spacing
    const mass_base = 1e22;
    const mass_variation = 1e22;

    inline for (0..grid_size) |i| {
        inline for (0..grid_size) |j| {
            const idx = i * grid_size + j;

            x[idx] = @floatFromInt(@as(i32,i) - grid_size / 2);
            x[idx] *= spacing + rnd.float(f64) * spacing_variation;

            y[idx] = @floatFromInt(@as(i32,j) - grid_size / 2);
            y[idx] *= spacing + rnd.float(f64) * spacing_variation;

            vx[idx] = 0.0;
            vy[idx] = 0.0;

            m[idx] = mass_base + (rnd.float(f64) - 0.5) * mass_variation;

            std.debug.print("Initialized body {} at ({}, {}) with mass {}\n", .{idx, x[idx], y[idx], m[idx]});
        }
    }


    // const num_objects = 3;
    // var x: [num_objects]f64 = [_]f64{
    //     0.0,
    //     384400000.0,
    //     350000000.0,
    // };
    // var y: [num_objects]f64 = [_]f64{
    //     0.0,
    //     0.0,
    //     0.0,
    // };
    // var vx: [num_objects]f64 = [_]f64{
    //     0.0,
    //     0.0,
    //     -300.0,
    // };
    // var vy: [num_objects]f64 = [_]f64{
    //     0.0,
    //     1000.0,
    //     1000.0,
    // };
    // const m: [num_objects]f64 = [_]f64{
    //     5.97e24, // Mass of Earth in kg
    //     7.34e22, // Mass of Moon in kg
    //     1.0e3,   // 1 tonne ship
    // };

    rl.setConfigFlags(.{ .msaa_4x_hint = true });

    rl.initWindow(screenWidth, screenHeight, "Gravity Attraction");
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
            const screen_r:f32 = @floatCast(m[i] / 1e21);

            rl.drawCircle(screen_x + 400, screen_y + 200, screen_r + 3.0, rl.Color.light_gray);
        }

        const gstr = try std.fmt.allocPrintZ(allocator, "G: {e}", .{ G });
        defer allocator.free(gstr);
        rl.drawText(gstr, 5, 5, 20, rl.Color.black);

        const tstr = try std.fmt.allocPrintZ(allocator, "t: {d}", .{ t });
        defer allocator.free(tstr);
        rl.drawText(tstr, 5, 22, 20, rl.Color.black);
    }
}
