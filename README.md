# Obsidian.md, a Docker container with noVNC http access
This container allows you to have a working Obsidian.md, reachable via a http noVNC that can be placed behind a reverse proxy.

More information about the noVNC baseimage here : https://github.com/jlesage/docker-baseimage-gui.

More info about Obsidian.md : https://obsidian.md/

Basically, here is a docker-compose exmaple of how to use it :
```
version: '2'
services:
  obsidianmd:
    image: CatalinGB/docker-Obsidianmd
    environment:
      - VNC_PASSWORD=<yourVNCpassword>
    volumes:
      - <yourdockervolume>:/config/xdg/config/obsidian:rw
      - <yournotesvolume>:/media/notes:rw
    ports:
      - 5800:5800
```

NB : the volume for config/data files must be read/write for UID/GID 1000/1000
