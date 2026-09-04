#include <stdio.h>
#include "map.h"

# define RC_PI  3.14159265358979323846f

/*
** No tci_getline, same as r01: this is libc territory now. fopen,
** fgets, sscanf -- every target this curriculum still has left
** carries its own C library, and none of them carry libtci.
*/
static int  parse_colour_line(char const *line, int *r, int *g, int *b)
{
    return (sscanf(line + 1, " %d,%d,%d", r, g, b) == 3);
}

static int  find_start(t_map *map)
{
    int y;
    int x;
    char c;

    y = 0;
    while (y < map->rows) {
        x = 0;
        while (x < map->cols) {
            c = map->grid[y][x];
            if (c == 'N' || c == 'S' || c == 'E' || c == 'W') {
                map->start_pos.x = (float)x + 0.5f;
                map->start_pos.y = (float)y + 0.5f;
                if (c == 'E')
                    map->start_angle = 0.0f;
                else if (c == 'S')
                    map->start_angle = (RC_PI / 2.0f);
                else if (c == 'W')
                    map->start_angle = RC_PI;
                else
                    map->start_angle = -(RC_PI / 2.0f);
                map->grid[y][x] = '0';
                return (1);
            }
            x++;
        }
        y++;
    }
    return (0);
}

int map_load(t_map *map, char const *path)
{
    FILE    *fp;
    char    line[256];
    size_t  len;
    int     y;

    y = 0;
    while (y < MAP_MAX_ROWS) {
        len = 0;
        while (len < (size_t)MAP_MAX_COLS)
            map->grid[y][len++] = ' ';
        map->grid[y][len] = '\0';
        y++;
    }
    map->cols = 0;
    fp = fopen(path, "r");
    if (!fp)
        return (0);
    if (!fgets(line, sizeof(line), fp) || !parse_colour_line(line,
            &map->floor_r, &map->floor_g, &map->floor_b)) {
        fclose(fp);
        return (0);
    }
    if (!fgets(line, sizeof(line), fp) || !parse_colour_line(line,
            &map->ceil_r, &map->ceil_g, &map->ceil_b)) {
        fclose(fp);
        return (0);
    }
    map->rows = 0;
    while (map->rows < MAP_MAX_ROWS && fgets(line, sizeof(line), fp)) {
        len = 0;
        while (line[len] && line[len] != '\n' && len < MAP_MAX_COLS) {
            map->grid[map->rows][len] = line[len];
            len++;
        }
        map->grid[map->rows][len] = '\0';
        if ((int)len > map->cols)
            map->cols = (int)len;
        map->rows++;
    }
    fclose(fp);
    if (!find_start(map))
        return (0);
    return (1);
}

int map_is_wall(t_map const *map, int x, int y)
{
    if (x < 0 || x >= map->cols || y < 0 || y >= map->rows)
        return (1);
    if ((size_t)x >= sizeof(map->grid[0]) - 1)
        return (1);
    return (map->grid[y][x] != '0');
}
