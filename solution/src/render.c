#include <math.h>
#include "render.h"
#include "raycaster.h"

# define MINIMAP_CELL   6

int render_init(t_render *rd)
{
    if (SDL_Init(SDL_INIT_VIDEO) != 0)
        return (0);
    rd->win = SDL_CreateWindow("r03 raycaster", SDL_WINDOWPOS_CENTERED,
            SDL_WINDOWPOS_CENTERED, WINDOW_W, WINDOW_H, 0);
    if (!rd->win)
        return (0);
    rd->ren = SDL_CreateRenderer(rd->win, -1, 0);
    if (!rd->ren)
        return (0);
    return (1);
}

void    render_free(t_render *rd)
{
    int i;

    i = 0;
    while (i < 4) {
        if (rd->wall_tex[i])
            SDL_DestroyTexture(rd->wall_tex[i]);
        i++;
    }
    if (rd->ren)
        SDL_DestroyRenderer(rd->ren);
    if (rd->win)
        SDL_DestroyWindow(rd->win);
    SDL_Quit();
}

static void draw_ceiling_floor(t_render *rd, t_map const *map)
{
    SDL_Rect    top;
    SDL_Rect    bottom;

    top.x = 0;
    top.y = 0;
    top.w = WINDOW_W;
    top.h = WINDOW_H / 2;
    bottom.x = 0;
    bottom.y = WINDOW_H / 2;
    bottom.w = WINDOW_W;
    bottom.h = WINDOW_H - top.h;
    SDL_SetRenderDrawColor(rd->ren, (Uint8)map->ceil_r, (Uint8)map->ceil_g,
        (Uint8)map->ceil_b, 255);
    SDL_RenderFillRect(rd->ren, &top);
    SDL_SetRenderDrawColor(rd->ren, (Uint8)map->floor_r, (Uint8)map->floor_g,
        (Uint8)map->floor_b, 255);
    SDL_RenderFillRect(rd->ren, &bottom);
}

static void draw_column(t_render *rd, int column, t_hit const *hit)
{
    int         line_h;
    int         start_y;
    float       perp_dist;
    SDL_Rect    src;
    SDL_Rect    dst;

    /*
    ** perp_dist can land arbitrarily close to zero (the camera
    ** standing right against, or inside, a wall cell) -- dividing by
    ** it unclamped produces a float too large for the (int) cast
    ** below to represent, which C leaves undefined rather than
    ** saturating. Floor perp_dist BEFORE the division, not the
    ** result after: clamping line_h afterward is too late, the
    ** undefined cast has already happened by then.
    */
    perp_dist = hit->perp_dist;
    if (perp_dist < 1.0f / 8.0f)
        perp_dist = 1.0f / 8.0f;
    line_h = (int)(WINDOW_H / perp_dist);
    start_y = WINDOW_H / 2 - line_h / 2;
    src.x = (int)(hit->wall_x * (float)rd->tex_w);
    src.y = 0;
    src.w = 1;
    src.h = rd->tex_h;
    dst.x = column;
    dst.y = start_y;
    dst.w = 1;
    dst.h = line_h;
    SDL_RenderCopy(rd->ren, rd->wall_tex[hit->tex_id], &src, &dst);
}

static void draw_minimap(t_render *rd, t_camera const *cam, t_map const *map)
{
    SDL_Rect    cell;
    int         x;
    int         y;

    y = 0;
    while (y < map->rows) {
        x = 0;
        while (x < map->cols) {
            cell.x = x * MINIMAP_CELL;
            cell.y = y * MINIMAP_CELL;
            cell.w = MINIMAP_CELL - 1;
            cell.h = MINIMAP_CELL - 1;
            if (map_is_wall(map, x, y))
                SDL_SetRenderDrawColor(rd->ren, 200, 200, 200, 255);
            else
                SDL_SetRenderDrawColor(rd->ren, 40, 40, 40, 255);
            SDL_RenderFillRect(rd->ren, &cell);
            x++;
        }
        y++;
    }
    cell.x = (int)(cam->pos.x * MINIMAP_CELL) - 2;
    cell.y = (int)(cam->pos.y * MINIMAP_CELL) - 2;
    cell.w = 4;
    cell.h = 4;
    SDL_SetRenderDrawColor(rd->ren, 220, 40, 40, 255);
    SDL_RenderFillRect(rd->ren, &cell);
    SDL_RenderDrawLine(rd->ren,
        (int)(cam->pos.x * MINIMAP_CELL), (int)(cam->pos.y * MINIMAP_CELL),
        (int)((cam->pos.x + cam->forward.x) * MINIMAP_CELL),
        (int)((cam->pos.y + cam->forward.y) * MINIMAP_CELL));
}

void    render_frame(t_render *rd, t_camera const *cam, t_map const *map)
{
    int     column;
    t_hit   hit;

    draw_ceiling_floor(rd, map);
    column = 0;
    while (column < WINDOW_W) {
        hit = raycaster_cast(cam, map, column);
        draw_column(rd, column, &hit);
        column++;
    }
    draw_minimap(rd, cam, map);
    SDL_RenderPresent(rd->ren);
}
