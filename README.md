# r03-the-raycaster

Companion repository for **r03 — The Raycaster on x86** at
[thecodingidiot.com](https://thecodingidiot.com) — the third chapter of
Part III, The Rendering Journey.

---

## Follow my journey

Working through r03 alongside the implementation pages? Build
`raycaster` step by step, then run the tester.

Clone this repository:

```bash
git clone https://github.com/thecodingidiot-com/r03-the-raycaster.git r03-practice
cd r03-practice/solution
bash gen_assets.sh
make re
bash ../test.sh
```

All tests must pass before the chapter is complete.

---

## Follow your journey

Building `raycaster` independently? Here is the full project brief.

A first-person engine in the style of Wolfenstein 3D (1992): one ray
per screen column, cast through a grid map with DDA (Digital
Differential Analysis), the nearest wall hit determining that column's
height and texture. No true 3D geometry — every wall is a flat, full-
height grid cell; the illusion is entirely a loop over screen columns.

- A camera with a world position and `forward`/`right` unit vectors,
  reused unchanged from r01/r02 — the field of view is a `right`-scaled
  "camera plane" blended with `forward`, not a separate cast angle.
- A plain-text map file (floor colour, ceiling colour, then the grid
  itself: `1` wall, `0` floor, `N`/`S`/`E`/`W` player start), loaded
  with `fopen`/`fgets`/`sscanf`.
- The raycaster itself: step the ray through the grid one cell
  boundary at a time (DDA), find the nearest wall, and compute a
  *perpendicular* distance — not the raw ray length — which is what
  actually keeps flat walls looking flat instead of bulging (the
  fisheye effect).
- One of four wall textures, picked by which cardinal face was hit;
  `WINDOW_H / perpDist` for that column's height, the same divide-by-
  depth idea r01/r02 both used, just per column instead of per
  billboard.

Source is split by concern, one file per module:

| File | Contents |
| --- | --- |
| `main.c` | SDL2 init, the game loop (event → update → render), cleanup |
| `vec2.c` / `vec2.h` | a small 2D vector type: add, subtract, scale, dot (unchanged from r01/r02) |
| `camera.c` / `camera.h` | position, facing angle, and the derived `forward`/`right` axes — no SDL2 anywhere |
| `map.c` / `map.h` | load a plain-text map file — no SDL2 anywhere |
| `raycaster.c` / `raycaster.h` | the DDA cast itself: world position + map → distance, side, texture coordinate — no SDL2 anywhere |
| `render.c` / `render.h` | the only file that calls actual SDL2 drawing functions |

`vec2.c`, `camera.c`, `map.c`, and `raycaster.c` never call an SDL2
function, so they link into a test binary with no SDL2 library at all.

Build and test your own version first. Use `solution/` to compare once
you are done, not before.

---

## Building the solution

```bash
cd solution
bash gen_assets.sh
make re
./raycaster ../fixtures/map1.map
```

Controls: Left/Right arrows or `h`/`l` to turn, Up/Down arrows or
`k`/`j` to move forward/backward, Escape or `q` to quit.

`gen_assets.sh` needs Python3 + Pillow:

```bash
sudo apt install python3-pil
```

---

## What the tester checks

**Build** — the real game compiles and links with zero warnings.

**A standalone DDA tester** — `vec2.o`, `camera.o`, `map.o`, and
`raycaster.o` compiled and linked with no SDL2 at all, asserting real
numbers:

- `fixtures/map1.map` parses to the right dimensions, and the marked
  start cell resolves to open floor.
- A closed, symmetric room: casting a ray at every column across the
  full field of view at a flat wall reports the *same* perpendicular
  distance for all of them — the actual numeric proof there's no
  fisheye distortion, not an eyeballed screenshot.
- Moving the camera forward shortens the perpendicular distance to a
  wall ahead by exactly the distance moved.

**`raycaster`** — runs its event loop for two seconds under a headless
(`SDL_VIDEODRIVER=dummy`) video driver without crashing. A smoke test,
not a visual check — actually walking the corridors and watching
walls resize as you approach is done by running it yourself.

---

## License

MIT License. See [LICENSE](LICENSE).
