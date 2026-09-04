#ifndef MAP_H
# define MAP_H

# include "vec2.h"

# define MAP_MAX_ROWS   32
# define MAP_MAX_COLS   32

typedef struct s_map
{
    char    grid[MAP_MAX_ROWS][MAP_MAX_COLS + 1];
    int     rows;
    int     cols;
    int     floor_r;
    int     floor_g;
    int     floor_b;
    int     ceil_r;
    int     ceil_g;
    int     ceil_b;
    t_vec2  start_pos;
    float   start_angle;
}   t_map;

int     map_load(t_map *map, char const *path);
int     map_is_wall(t_map const *map, int x, int y);

#endif
