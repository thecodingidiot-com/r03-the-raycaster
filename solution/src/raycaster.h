#ifndef RAYCASTER_H
# define RAYCASTER_H

# include "vec2.h"
# include "camera.h"
# include "map.h"

# define WINDOW_W       640
# define WINDOW_H       480
# define PLANE_SCALE    0.66f

typedef struct s_hit
{
    float   perp_dist;
    int     side;
    float   wall_x;
    int     tex_id;
}   t_hit;

t_hit   raycaster_cast(t_camera const *cam, t_map const *map, int column);

#endif
