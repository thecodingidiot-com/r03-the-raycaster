#include <stdio.h>
#include <SDL2/SDL.h>
#include <SDL2/SDL_image.h>
#include "camera.h"
#include "map.h"
#include "render.h"

# define TURN_SPEED 0.035f
# define MOVE_SPEED 0.06f

static void handle_input(t_camera *cam, Uint8 const *keys)
{
    /*
    ** Angle grows clockwise on a y-down map (east, south, west,
    ** north), so turning left DECREASES it. These two were the wrong
    ** way round, which cancelled the mirrored camera plane in
    ** camera.c and made both look correct. Both are fixed; neither
    ** now relies on the other.
    */
    if (keys[SDL_SCANCODE_LEFT] || keys[SDL_SCANCODE_H])
        camera_turn(cam, -TURN_SPEED);
    if (keys[SDL_SCANCODE_RIGHT] || keys[SDL_SCANCODE_L])
        camera_turn(cam, TURN_SPEED);
    if (keys[SDL_SCANCODE_UP] || keys[SDL_SCANCODE_K])
        camera_move(cam, MOVE_SPEED);
    if (keys[SDL_SCANCODE_DOWN] || keys[SDL_SCANCODE_J])
        camera_move(cam, -MOVE_SPEED);
}

static int  load_wall_textures(t_render *rd)
{
    char const  *paths[4] = {
        "assets/wall_west.png", "assets/wall_east.png",
        "assets/wall_north.png", "assets/wall_south.png"
    };
    int         i;

    IMG_Init(IMG_INIT_PNG);
    i = 0;
    while (i < 4) {
        rd->wall_tex[i] = IMG_LoadTexture(rd->ren, paths[i]);
        if (!rd->wall_tex[i]) {
            printf("failed to load %s: %s\n", paths[i], IMG_GetError());
            printf("did you run 'bash gen_assets.sh' first?\n");
            return (0);
        }
        i++;
    }
    SDL_QueryTexture(rd->wall_tex[0], NULL, NULL, &rd->tex_w, &rd->tex_h);
    return (1);
}

int main(int argc, char **argv)
{
    t_render    rd;
    t_map       map;
    t_camera    cam;
    SDL_Event   ev;
    Uint8 const *keys;
    int         running;

    if (argc < 2) {
        printf("usage: %s <map_file>\n", argv[0]);
        return (1);
    }
    if (!map_load(&map, argv[1])) {
        printf("failed to load map: %s\n", argv[1]);
        return (1);
    }
    if (!render_init(&rd))
        return (1);
    if (!load_wall_textures(&rd)) {
        render_free(&rd);
        return (1);
    }
    camera_init(&cam, map.start_pos.x, map.start_pos.y, map.start_angle);
    running = 1;
    while (running) {
        while (SDL_PollEvent(&ev)) {
            if (ev.type == SDL_QUIT)
                running = 0;
            if (ev.type == SDL_KEYDOWN && (ev.key.keysym.sym == SDLK_ESCAPE
                    || ev.key.keysym.sym == SDLK_q))
                running = 0;
        }
        keys = SDL_GetKeyboardState(NULL);
        handle_input(&cam, keys);
        render_frame(&rd, &cam, &map);
        SDL_Delay(16);
    }
    render_free(&rd);
    IMG_Quit();
    return (0);
}
