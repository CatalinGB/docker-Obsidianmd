FROM jlesage/baseimage-gui:ubuntu-18.04

RUN apt-get update && apt-get install -y wget libnss3 libgtk-3-0 libxss1 libasound2 libgbm1
RUN useradd --shell /sbin/nologin --home /app --uid 1000  -G users appuser
RUN mkdir /app && chown appuser -Rfv /app
USER appuser
RUN echo $USER
WORKDIR /app
RUN wget -O - https://raw.githubusercontent.com/CatalinGB/docker-Obsidianmd/master/Obsidianmd_install_and_update.sh >/app/install-Obsidianmd.sh && chmod +x /app/install-Obsidianmd.sh
RUN TERM=xterm /app/install-Obsidianmd.sh --allow-root --force
RUN /app/.Obsidian/Obsidian.AppImage --appimage-extract
ENV APPDIR=/app/squashfs-root
ADD startapp.sh /startapp.sh
USER root
ADD https://forum.obsidian.md/uploads/default/original/2X/7/7d2b71c58ded80e1dd507918089f582286b3540d.png /app/Obsidianmd-logo.png
RUN APP_ICON_URL=file:///app/Obsidianmd-logo.png && install_app_icon.sh "$APP_ICON_URL"
ENV APP_NAME="Obsidian.md"
