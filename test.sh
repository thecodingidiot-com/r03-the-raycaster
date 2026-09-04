#!/bin/bash
# r03 — The Raycaster / test.sh
#
# Builds the real binary, then checks the DDA math deterministically --
# compiled and linked WITHOUT SDL2 at all (vec2.c, camera.c, map.c, and
# raycaster.c never call an SDL2 function), plus a headless smoke test
# of the real binary.
#
# Copy this file and fixtures/map1.cub into your working directory,
# build with 'make re', then run:
#
#   bash test.sh

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES="${SCRIPT_DIR}/fixtures"

# ── colour ────────────────────────────────────────────────────────────────────

if [[ ! -t 1 ]]; then
    C_GREEN=""
    C_RED=""
    C_BOLD=""
    C_RESET=""
else
    C_GREEN="\033[0;32m"
    C_RED="\033[0;31m"
    C_BOLD="\033[1m"
    C_RESET="\033[0m"
fi

pass_count=0
fail_count=0
WORK_DIR=$(mktemp -d)

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

hr() {
    echo "────────────────────────────────────────────────────────────────"
}

banner() {
    hr
    echo "  r03 — The Raycaster / test.sh"
    hr
}

pass() {
    local label="$1"
    printf "  ${C_GREEN}PASS${C_RESET}  %s\n" "$label"
    pass_count=$((pass_count + 1))
}

fail() {
    local label="$1"
    local detail="${2:-}"
    printf "  ${C_RED}FAIL${C_RESET}  %s\n" "$label"
    if [[ -n "$detail" ]]; then
        echo "        $detail"
    fi
    fail_count=$((fail_count + 1))
}

banner

# ── build the real game ───────────────────────────────────────────────────────

echo "Building..."
build_log=$(make re 2>&1)
build_status=$?
if [[ "$build_status" -ne 0 ]]; then
    fail "build succeeds" "make re failed:"
    echo "$build_log"
    exit 1
fi
pass "build succeeds"

if echo "$build_log" | grep -qi "warning"; then
    fail "build produces no warnings" "$(echo "$build_log" | grep -i warning)"
else
    pass "build produces no warnings"
fi

if [[ -x ./raycaster ]]; then
    pass "raycaster binary exists"
else
    fail "raycaster binary exists"
fi

# ── build the SDL2-free DDA tester ───────────────────────────────────────────

if [[ ! -f "${FIXTURES}/map1.cub" ]]; then
    fail "fixtures/map1.cub found" "keep the r03-the-raycaster clone alongside your working directory"
    exit 1
fi
cp "${FIXTURES}/map1.cub" "$WORK_DIR/map1.cub"

cat > "$WORK_DIR/test_logic.c" <<'TESTC'
#include <math.h>
#include <stdio.h>
#include "vec2.h"
#include "camera.h"
#include "map.h"
#include "raycaster.h"

static int  g_pass = 0;
static int  g_fail = 0;

static void check_int(char const *label, int got, int want)
{
    if (got == want)
    {
        printf("PASS  %s (got %d)\n", label, got);
        g_pass++;
    }
    else
    {
        printf("FAIL  %s (got %d, want %d)\n", label, got, want);
        g_fail++;
    }
}

static void check_float_near(char const *label, float got, float want, float eps)
{
    if (fabsf(got - want) <= eps)
    {
        printf("PASS  %s (got %f)\n", label, got);
        g_pass++;
    }
    else
    {
        printf("FAIL  %s (got %f, want %f)\n", label, got, want);
        g_fail++;
    }
}

int main(void)
{
    t_map       map;
    t_camera    cam;
    t_hit       hit;
    int         i;
    int         col;

    if (!map_load(&map, "map1.cub"))
    {
        printf("FAIL  map_load\n");
        return (1);
    }
    check_int("map1.cub has ten rows", map.rows, 10);
    check_int("map1.cub has thirteen columns", map.cols, 13);
    check_int("(0,0) is a wall", map_is_wall(&map, 0, 0), 1);
    check_int("the marked start cell is open floor", map_is_wall(&map,
        (int)map.start_pos.x, (int)map.start_pos.y), 0);
    check_int("out of bounds is a wall", map_is_wall(&map, -1, 0), 1);

    /* A closed 5x5 room, camera centred and facing straight at one
     * flat wall: every column across the whole field of view must
     * report the SAME perpendicular distance, because that's the one
     * property that actually defines "no fisheye" -- a flat wall
     * perpendicular to the view has to render as a flat wall, not a
     * bulge, regardless of which column of it a given ray happens to
     * cross. This is the numeric proof, not just an eyeballed
     * screenshot. */
    {
        t_map   room;
        int     y;
        int     x;
        char const  *rows[5] = {"11111", "10001", "10001", "10001", "11111"};

        room.rows = 5;
        room.cols = 5;
        y = 0;
        while (y < 5)
        {
            x = 0;
            while (x < 5)
            {
                room.grid[y][x] = rows[y][x];
                x++;
            }
            y++;
        }
        camera_init(&cam, 2.5f, 2.5f, 0.0f);
        i = 0;
        while (i <= 4)
        {
            col = i * WINDOW_W / 4;
            hit = raycaster_cast(&cam, &room, col);
            check_float_near("flat wall: every column reports the same perp_dist",
                hit.perp_dist, 1.5f, 0.01f);
            i++;
        }
        check_int("centre ray hits an X-side wall", hit.side, 0);
    }

    /* Moving straight toward a wall must shorten perp_dist by exactly
     * the distance moved -- the same "does the number move the right
     * amount" discipline r01/r02 both used. */
    camera_init(&cam, 1.5f, 1.5f, 0.0f);
    hit = raycaster_cast(&cam, &map, WINDOW_W / 2);
    check_float_near("depth from x=1.5 toward the east wall",
        hit.perp_dist, 10.5f, 0.01f);
    camera_move(&cam, 4.0f);
    hit = raycaster_cast(&cam, &map, WINDOW_W / 2);
    check_float_near("moving forward shortens perp_dist by the distance moved",
        hit.perp_dist, 6.5f, 0.01f);

    printf("\n%d passed, %d failed\n", g_pass, g_fail);
    return (g_fail > 0);
}
TESTC

logic_build_log=$(gcc -Wall -Wextra -I src -c "$WORK_DIR/test_logic.c" -o "$WORK_DIR/test_logic.o" 2>&1 \
    && gcc "$WORK_DIR/test_logic.o" src/vec2.o src/camera.o src/map.o src/raycaster.o -lm -o "$WORK_DIR/test_logic" 2>&1)
logic_build_status=$?

if [[ "$logic_build_status" -ne 0 ]]; then
    fail "logic tester builds without SDL2" "$logic_build_log"
    exit 1
fi
pass "logic tester builds without SDL2 (vec2.o/camera.o/map.o/raycaster.o only)"

echo
echo "Running the logic tester..."
cd "$WORK_DIR"
logic_out=$(./test_logic)
logic_status=$?
cd - > /dev/null

echo "$logic_out" | grep "^PASS\|^FAIL" | while read -r line; do
    echo "  $line"
done

logic_pass_count=$(echo "$logic_out" | grep -c "^PASS")
logic_fail_count=$(echo "$logic_out" | grep -c "^FAIL")
pass_count=$((pass_count + logic_pass_count))
fail_count=$((fail_count + logic_fail_count))

if [[ "$logic_status" -ne 0 ]]; then
    fail "all logic assertions pass" "see failures above"
fi

# ── headless smoke test of the real binary ───────────────────────────────────

echo
echo "Running raycaster headless (2s)..."
SDL_VIDEODRIVER=dummy timeout 2 ./raycaster "$FIXTURES/map1.cub"
rc_status=$?
if [[ "$rc_status" -eq 124 ]]; then
    pass "raycaster runs its event loop for 2s without crashing"
else
    fail "raycaster runs its event loop for 2s without crashing" "exit code: $rc_status"
fi

# ── summary ───────────────────────────────────────────────────────────────────

echo
hr
printf "  ${C_BOLD}%d passed, %d failed${C_RESET}\n" "$pass_count" "$fail_count"
hr

if [[ "$fail_count" -gt 0 ]]; then
    exit 1
fi
exit 0
