CC      = gcc
CFLAGS  = -Wall -Wextra -Werror -D_REENTRANT -Isrc
BUILD   = -g -O0
RELEASE = -O2
LDFLAGS = $(shell sdl2-config --libs) -lSDL2_image -lm
SRCS    = src/main.c src/vec2.c src/camera.c src/map.c src/raycaster.c src/render.c
OBJS    = $(SRCS:.c=.o)
NAME    = raycaster

.PHONY: all release clean fclean re

all: $(NAME)

$(NAME): $(OBJS)
	$(CC) $(BUILD) $(OBJS) $(LDFLAGS) -o $(NAME)

%.o: %.c
	$(CC) $(CFLAGS) $(BUILD) -c $< -o $@

release:
	@$(MAKE) --no-print-directory fclean
	@$(MAKE) --no-print-directory BUILD="$(RELEASE)"
	strip $(NAME)

clean:
	rm -f $(OBJS)

fclean: clean
	rm -f $(NAME)

re: fclean all
