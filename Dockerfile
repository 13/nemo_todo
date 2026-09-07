# syntax=docker/dockerfile:1

# ---- Stage 1: build the Flutter web app -----------------------------------
FROM debian:bookworm-slim AS web-build
RUN apt-get update \
 && apt-get install -y --no-install-recommends git curl ca-certificates unzip xz-utils zip \
 && rm -rf /var/lib/apt/lists/*
ARG FLUTTER_VERSION=3.47.2
RUN git clone --depth 1 -b "${FLUTTER_VERSION}" https://github.com/flutter/flutter.git /opt/flutter \
 && git config --global --add safe.directory /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}"
RUN flutter config --no-analytics --enable-web && flutter precache --web
WORKDIR /src
COPY pubspec.yaml pubspec.lock ./
COPY packages/nemo_core/pubspec.yaml packages/nemo_core/
COPY app/pubspec.yaml app/
COPY server/pubspec.yaml server/
RUN flutter pub get
COPY packages ./packages
COPY app ./app
COPY tool ./tool
RUN tool/fetch_web_assets.sh \
 && cd app && flutter build web --release --no-web-resources-cdn

# ---- Stage 2: compile the server ------------------------------------------
FROM dart:3.13.2-sdk AS server-build
WORKDIR /src
COPY pubspec.yaml pubspec.lock ./
COPY packages/nemo_core/pubspec.yaml packages/nemo_core/
COPY app/pubspec.yaml app/
COPY server/pubspec.yaml server/
RUN dart pub get
COPY packages ./packages
COPY server ./server
RUN dart compile exe server/bin/nemo_server.dart -o /nemo_server

# ---- Stage 3: runtime -----------------------------------------------------
FROM debian:bookworm-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends libsqlite3-0 ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --system --uid 1000 --create-home nemo \
 && mkdir -p /data && chown nemo:nemo /data
COPY --from=server-build /nemo_server /usr/local/bin/nemo_server
COPY --from=web-build /src/app/build/web /app/web
USER nemo
ENV NEMO_PORT=8080 NEMO_DB=/data/nemo.db NEMO_WEB_DIR=/app/web
EXPOSE 8080
VOLUME ["/data"]
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s CMD ["nemo_server", "healthcheck"]
ENTRYPOINT ["nemo_server"]
CMD ["serve"]
