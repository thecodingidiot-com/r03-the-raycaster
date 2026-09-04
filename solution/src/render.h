#ifndef RENDER_H
# define RENDER_H

# include <SDL2/SDL.h>
# include "camera.h"
# include "map.h"

typedef struct s_render
{
    SDL_Window      *win;
    SDL_Renderer    *ren;
    SDL_Texture     *wall_tex[4];
    int             tex_w;
    int             tex_h;
}   t_render;

int     render_init(t_render *rd);
void    render_free(t_render *rd);
void    render_frame(t_render *rd, t_camera const *cam, t_map const *map);

#endif
