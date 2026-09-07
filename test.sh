#!/bin/bash
# r03 — The Raycaster / test.sh
#
# Builds the real binary, then checks the DDA math deterministically --
# compiled and linked WITHOUT SDL2 at all (vec2.c, camera.c, map.c, and
# raycaster.c never call an SDL2 function), plus a headless smoke test
# of the real binary.
#
# Copy this file and fixtures/map1.map into your working directory,
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

if [[ ! -f "${FIXTURES}/map1.map" ]]; then
    fail "fixtures/map1.map found" "keep the r03-the-raycaster clone alongside your working directory"
    exit 1
fi
cp "${FIXTURES}/map1.map" "$WORK_DIR/map1.map"

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

    if (!map_load(&map, "map1.map"))
    {
        printf("FAIL  map_load\n");
        return (1);
    }
    check_int("map1.map has ten rows", map.rows, 10);
    check_int("map1.map has thirteen columns", map.cols, 13);
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

    /*
     * Handedness. The map's y axis points down, so a player facing
     * east has south on their right -- and the camera plane is built
     * from that vector, so getting its sign wrong mirrors the entire
     * screen rather than distorting it, which is exactly why nothing
     * else in this file would notice.
     *
     * Asserted twice: once on the vector, once on a picture. The map
     * below presses a wall against the NORTH side and leaves the south
     * open, with the camera facing east -- north is then the player's
     * LEFT, so the near wall must land in the left half of the screen.
     */
    camera_init(&cam, 1.5f, 2.5f, 0.0f);
    check_float_near("facing east, right is south (+y), not north",
        cam.right.y, 1.0f, 0.001f);
    {
        t_map   hall;
        int     y;
        int     x;
        float   near_side = 0.0f;
        float   far_side = 0.0f;
        char const  *hrows[7] = {
            "1111111111111", "1111111111111", "1000000000001",
            "1000000000001", "1000000000001", "1000000000001",
            "1111111111111"
        };

        hall.rows = 7;
        hall.cols = 13;
        y = 0;
        while (y < 7)
        {
            x = 0;
            while (x < 13)
            {
                hall.grid[y][x] = hrows[y][x];
                x++;
            }
            hall.grid[y][13] = '\0';
            y++;
        }
        camera_init(&cam, 1.5f, 2.5f, 0.0f);
        col = 0;
        while (col < WINDOW_W)
        {
            hit = raycaster_cast(&cam, &hall, col);
            if (col < WINDOW_W / 4)
                near_side += hit.perp_dist;
            if (col >= WINDOW_W - WINDOW_W / 4)
                far_side += hit.perp_dist;
            col++;
        }
        check_int("the wall on the player's left renders on the left of the screen",
            near_side < far_side, 1);
    }

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
SDL_VIDEODRIVER=dummy timeout 2 ./raycaster "$FIXTURES/map1.map"
rc_status=$?
if [[ "$rc_status" -eq 124 ]]; then
    pass "raycaster runs its event loop for 2s without crashing"
else
    fail "raycaster runs its event loop for 2s without crashing" "exit code: $rc_status"
fi

# ── summary ───────────────────────────────────────────────────────────────────

# ── leak report ─────────────────────────────────────────────────────────────────
#
# Runs one representative invocation under valgrind and REPORTS what it finds.
# It never changes the pass/fail count. A leak is something to look at, not a
# reason to refuse your work — but you should see it, because a program that
# leaks is a program that will eventually be killed by the machine it runs on.
#
# Leaks are split by whose code lost the memory. A loss record whose stack
# names one of your own .c files is yours. One that lives entirely inside
# SDL, Mesa or glibc is not, and there is nothing for you to fix there.

leak_report() {
    local label="$1"; shift
    local log="${WORK_DIR:-/tmp}/leaks.$$.log"
    local mine=0 theirs=0 rec frames

    if ! command -v valgrind >/dev/null 2>&1; then
        printf "  ${C_BOLD}NOTE${C_RESET}  %s: valgrind is not installed, skipping\n" "$label"
        return 0
    fi

    valgrind --leak-check=full --show-leak-kinds=definite,indirect \
             --error-exitcode=0 --log-file="$log" "$@" >/dev/null 2>&1

    if [[ ! -s "$log" ]]; then
        printf "  ${C_BOLD}NOTE${C_RESET}  %s: valgrind produced no output\n" "$label"
        return 0
    fi

    # Split the log into loss records and ask, of each, whether any frame
    # points at a source file sitting in this directory.
    while IFS= read -r rec; do
        frames=$(sed -n "${rec}"',/^==[0-9]*== *$/p' "$log")
        # Every record carries valgrind's own malloc frame; that is not yours.
        # A frame is yours only if it names a source file sitting right here.
        local f owned=0
        for f in $(grep -oE '\(([A-Za-z0-9_-]+\.c):[0-9]+\)' <<<"$frames" \
                   | tr -d '()' | cut -d: -f1 | sort -u); do
            [[ "$f" == vg_replace_malloc.c ]] && continue
            [[ -f "$f" ]] && owned=1
        done
        if (( owned )); then
            mine=$((mine + 1))
            if (( mine == 1 )); then
                printf "  ${C_RED}LEAK${C_RESET}  %s — memory lost by your code:\n" "$label"
            fi
            grep -E 'bytes in [0-9,]+ blocks are (definitely|indirectly)' <<<"$frames" \
                | sed 's/^==[0-9]*== /        /'
            grep -oE '\(([A-Za-z0-9_-]+\.c:[0-9]+)\)' <<<"$frames" \
                | grep -v vg_replace_malloc | head -3 | tr -d '()' \
                | sed 's/^/          at /'
        else
            theirs=$((theirs + 1))
        fi
    done < <(grep -nE 'bytes in [0-9,]+ blocks are (definitely|indirectly) lost' "$log" | cut -d: -f1)

    if (( mine == 0 )); then
        printf "  ${C_GREEN}OK${C_RESET}    %s — no memory lost by your code" "$label"
        if (( theirs > 0 )); then
            printf ' (%d leak(s) inside libraries you did not write)' "$theirs"
        fi
        printf '\n'
    else
        printf '        this does not fail the tester — fix it anyway\n'
    fi
    rm -f "$log"
    return 0
}

# The graphical chapters run until you quit them, and a program killed
# mid-loop reports everything it has not freed yet as "lost" -- which would be
# a lie. So this starts a virtual display, lets the program run, sends it a
# 'q', and measures the clean exit.
leak_report_gui() {
    local label="$1"; shift
    if ! command -v valgrind >/dev/null 2>&1; then
        printf "  ${C_BOLD}NOTE${C_RESET}  %s: valgrind is not installed, skipping\n" "$label"
        return 0
    fi
    if ! command -v xvfb-run >/dev/null 2>&1 || ! command -v xte >/dev/null 2>&1; then
        printf "  ${C_BOLD}NOTE${C_RESET}  %s: needs xvfb-run and xte for a clean exit, skipping\n" "$label"
        return 0
    fi
    printf "  ${C_BOLD}....${C_RESET}  %s: running under valgrind, this takes a minute\n" "$label"
    local inner="${WORK_DIR:-/tmp}/leak_gui.$$.sh"
    {
        echo "C_GREEN=\"${C_GREEN}\"; C_RED=\"${C_RED}\"; C_BOLD=\"${C_BOLD}\"; C_RESET=\"${C_RESET}\""
        echo "WORK_DIR=\"${WORK_DIR:-/tmp}\""
        declare -f leak_report
        echo '( sleep 12; xte "key q" 2>/dev/null; sleep 5; xte "key q" 2>/dev/null ) &'
        printf 'leak_report %q' "$label"
        printf ' %q' "$@"
        printf '\n'
    } > "$inner"
    timeout 240 xvfb-run -a bash "$inner"
    local rc=$?
    rm -f "$inner"
    if (( rc == 124 )); then
        printf "  ${C_BOLD}NOTE${C_RESET}  %s: the program never exited, so there is nothing honest to measure\n" "$label"
        printf "        (a program killed mid-loop reports everything it holds as lost)\n"
    fi
    return 0
}

echo
leak_report_gui "raycaster" ./raycaster "$FIXTURES/map1.map"

echo
hr
printf "  ${C_BOLD}%d passed, %d failed${C_RESET}\n" "$pass_count" "$fail_count"
hr

if [[ "$fail_count" -gt 0 ]]; then
    exit 1
fi
exit 0
