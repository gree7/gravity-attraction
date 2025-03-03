const rl = @import("raylib");
const std = @import("std");

const allocator = std.heap.page_allocator;

const G = 6.67e-11;

const System = struct {
    x: []f64,
    y: []f64,
    vx: []f64,
    vy: []f64,
    ax: []f64,
    ay: []f64,
    m: []f64,
    num_objects: usize,

    fn initGrid(alloc: std.mem.Allocator, rnd: std.rand.Random, comptime grid_size: usize) !@This() {
        const num_objects = grid_size * grid_size;

        const system = try init(alloc, num_objects);

        // Initialize bodies in a grid with randomized masses
        const spacing = 1e8; // Spacing between bodies
        const spacing_variation = 1e7; // Variation in spacing
        const mass_base = 1e22;
        const mass_variation = 1e22;

        inline for (0..grid_size) |i| {
            inline for (0..grid_size) |j| {
                const idx = i * grid_size + j;

                system.x[idx] = @floatFromInt(@as(i32, i) - @as(i32, grid_size / 2));
                system.x[idx] *= spacing + rnd.float(f64) * spacing_variation;

                system.y[idx] = @floatFromInt(@as(i32, j) - @as(i32, grid_size / 2));
                system.y[idx] *= spacing + rnd.float(f64) * spacing_variation;

                system.vx[idx] = 0.0;
                system.vy[idx] = 0.0;

                system.ax[idx] = 0.0;
                system.ay[idx] = 0.0;

                system.m[idx] = mass_base + (rnd.float(f64) - 0.5) * mass_variation;

                std.debug.print("Initialized body {} at ({}, {}) with mass {}\n",
                    .{idx, system.x[idx], system.y[idx], system.m[idx]});
            }
        }

        return system;
    }

    fn initShip(alloc: std.mem.Allocator, rnd: std.rand.Random) !@This() {
        const num_objects = 3;
        _ = rnd;

        const system = try init(alloc, num_objects);

        std.mem.copyForwards(f64, system.x, &[_]f64{
            0.0,
            384400000.0,
            350000000.0,
        });
        std.mem.copyForwards(f64, system.y, &[_]f64{
            0.0,
            0.0,
            0.0,
        });
        std.mem.copyForwards(f64, system.vx, &[_]f64{
            0.0,
            0.0,
            -300.0,
        });
        std.mem.copyForwards(f64, system.vy, &[_]f64{
            0.0,
            1000.0,
            1000.0,
        });
        std.mem.copyForwards(f64, system.ax, &[_]f64{
            0.0,
            0.0,
            0.0,
        });
        std.mem.copyForwards(f64, system.ay, &[_]f64{
            0.0,
            0.0,
            0.0,
        });
        std.mem.copyForwards(f64, system.m, &[_]f64{
            5.97e24, // Mass of Earth in kg
            7.34e22, // Mass of Moon in kg
            1.0e3,   // 1 tonne ship
        });

        return system;
    }

    pub fn init(alloc: std.mem.Allocator, num_objects: usize) !@This() {
        const system = @This(){
            .num_objects = num_objects,
            .x = try alloc.alloc(f64, num_objects),
            .y = try alloc.alloc(f64, num_objects),
            .vx = try alloc.alloc(f64, num_objects),
            .vy = try alloc.alloc(f64, num_objects),
            .ax = try alloc.alloc(f64, num_objects),
            .ay = try alloc.alloc(f64, num_objects),
            .m = try alloc.alloc(f64, num_objects),
        };

        return system;
    }

    pub fn deinit(self: *const System, alloc: std.mem.Allocator) void {
        alloc.free(self.x);
        alloc.free(self.y);
        alloc.free(self.vx);
        alloc.free(self.vy);
        alloc.free(self.ax);
        alloc.free(self.ay);
        alloc.free(self.m);
    }
};

pub fn main() anyerror!void {
    const screenWidth = 1280;
    const screenHeight = 720;

    var random = std.rand.DefaultPrng.init(12345);
    const rnd = random.random();

    var t:f64 = 0.0;
    const dt = 500.0;

    const system = try System.initGrid(allocator, rnd, 10);
    defer system.deinit(allocator);

    rl.setConfigFlags(.{ .msaa_4x_hint = true });

    rl.initWindow(screenWidth, screenHeight, "Gravity Attraction");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    var camera = rl.Camera2D {
        .offset = rl.Vector2.init(screenWidth / 2.0, screenHeight / 2.0),
        .target = rl.Vector2.init(0.0, 0.0),
        .rotation = 0.0,
        .zoom = 1.0,
    };

    while (!rl.windowShouldClose()) {
        // Controls
        camera.zoom += rl.getMouseWheelMove() * 0.05;

        if (rl.isMouseButtonDown(rl.MouseButton.middle)) {
            const delta = rl.getMouseDelta().scale(-1.0 / camera.zoom);
            camera.target = camera.target.add(delta);
        }

        const wheel = rl.getMouseWheelMove();
        if (wheel != 0) {
            const mouseWorldPos = rl.getScreenToWorld2D(rl.getMousePosition(), camera);
            camera.offset = rl.getMousePosition();
            camera.target = mouseWorldPos;
            var scaleFactor = 1.0 + (0.25 * @abs(wheel));
            if (wheel < 0) {
                scaleFactor = 1.0 / scaleFactor;
            }
            var newZoom = camera.zoom * scaleFactor;
            if (newZoom < 0.125) {
                newZoom = 0.125;
            } else if (newZoom > 64.0) {
                newZoom = 64.0;
            }
            camera.zoom = newZoom;
        }


        if (camera.zoom > 3.0) {
            camera.zoom = 3.0;
        } else if (camera.zoom < 0.1) {
            camera.zoom = 0.1;
        }

        if (rl.isKeyPressed(rl.KeyboardKey.r)) {
            camera.zoom = 1.0;
            camera.target = .{ .x = 0.0, .y = 0.0 };
        }

        // Calculate gravitational forces between all pairs
        for (0..system.num_objects) |i| {
            for (i + 1..system.num_objects) |j| {
                const deltaX = system.x[j] - system.x[i];
                const deltaY = system.y[j] - system.y[i];
                var r = @sqrt(deltaX * deltaX + deltaY * deltaY);

                // Prevent division by zero
                if (r == 0.0) {
                    r = 0.0001;
                }

                const F = G * system.m[i] * system.m[j] / (r * r);

                const ux = deltaX / r;
                const uy = deltaY / r;

                // Update accelerations
                system.ax[i] += (F / system.m[i]) * ux;
                system.ay[i] += (F / system.m[i]) * uy;
                system.ax[j] -= (F / system.m[j]) * ux;
                system.ay[j] -= (F / system.m[j]) * uy;
            }
        }

        // Update velocities and positions
        for (0..system.num_objects) |i| {
            system.vx[i] += system.ax[i] * dt;
            system.vy[i] += system.ay[i] * dt;
            system.x[i] += system.vx[i] * dt;
            system.y[i] += system.vy[i] * dt;
        }
        t += dt;

        // Draw
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.dark_gray);

        camera.begin();

        // Draw objects
        for (0..system.num_objects) |i| {
            const screen_x:i32 = @intFromFloat(system.x[i] / 2000000.0);
            const screen_y:i32 = @intFromFloat(system.y[i] / 2000000.0);
            const screen_r:f32 = @floatCast(system.m[i] / 1e23);

            rl.drawCircle(screen_x, screen_y, screen_r + 3.0, rl.Color.light_gray);
        }

        camera.end();

        const gstr = try std.fmt.allocPrintZ(allocator, "G: {e}", .{ G });
        defer allocator.free(gstr);
        rl.drawText(gstr, 5, 5, 20, rl.Color.black);

        const tstr = try std.fmt.allocPrintZ(allocator, "t: {d}", .{ t });
        defer allocator.free(tstr);
        rl.drawText(tstr, 5, 22, 20, rl.Color.black);
    }
}
