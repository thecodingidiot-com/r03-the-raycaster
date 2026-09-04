CC      = gcc
CFLAGS  = -Wall -Wextra -Werror -D_REENTRANT -Isrc
LDFLAGS = $(shell sdl2-config --libs) -lSDL2_image -lm
SRCS    = src/main.c src/vec2.c src/camera.c src/map.c src/raycaster.c src/render.c
OBJS    = $(SRCS:.c=.o)
NAME    = raycaster

.PHONY: all clean fclean re

all: $(NAME)

$(NAME): $(OBJS)
	$(CC) $(OBJS) $(LDFLAGS) -o $(NAME)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS)

fclean: clean
	rm -f $(NAME)

re: fclean all
