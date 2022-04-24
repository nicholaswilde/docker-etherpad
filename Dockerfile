FROM alpine:3.14.0 as base

FROM base as dl
ARG VERSION
ARG CHECKSUM
WORKDIR /tmp
ARG FILENAME="${VERSION}.tar.gz"
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
RUN \
  echo "**** install packages ****" && \
  apk add --no-cache \
    wget=1.21.1-r1 && \
  echo "**** download haste ****" && \
  mkdir /app && \
  wget -q --progress=dot:giga "https://github.com/ether/etherpad-lite/archive/${FILENAME}" && \
  echo "${CHECKSUM}  ${FILENAME}" | sha256sum -c && \
  tar -xvf "${FILENAME}" -C /app --strip-components 1
WORKDIR /app
RUN \
  echo "**** cleanup ****" && \
  rm -rf \
    ./*.md \
    .github \
    .gitignore \
    Dockerfile \
    doc \
    Makefile \
    settings.json\
    src/node_modules

FROM base
ARG BUILD_DATE
ARG VERSION
ARG ETHERPAD_PLUGINS=""
# hadolint ignore=DL3048
LABEL build_version="Version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="nicholaswilde"
ENV NODE_ENV=production
RUN \
  echo "**** install packages ****" && \
  apk add --no-cache \
    nodejs=14.19.0-r0 \
    tzdata=2022a-r0 \
    npm=7.17.0-r0 && \
  adduser -S etherpad --uid 5001 && \
  mkdir /opt/etherpad-lite && \
	echo "**** cleanup ****" && \
  rm -rf /tmp/*
WORKDIR /opt/etherpad-lite
COPY --from=dl /app ./
COPY --from=dl /app/settings.json.docker /opt/etherpad-lite/settings.json
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
RUN \
  echo "**** install packages ****" && \
  bin/installDeps.sh && \
  rm -rf ~/.npm/_cacache && \
  echo "**** install plugins ****" && \
  for PLUGIN_NAME in ${ETHERPAD_PLUGINS}; do npm install "${PLUGIN_NAME}" || exit 1; done && \
  echo "**** change permissions ****" && \
  chmod -R g=u . && \
	chown -R etherpad:0 /opt/etherpad-lite && \
	chown -R 5001:65533 "/root/.npm"
USER etherpad
EXPOSE 9001
VOLUME \
  /opt/etherpad-lite/var \
  /opt/etherpad-lite
CMD ["node", "--experimental-worker", "node_modules/ep_etherpad-lite/node/server.js"]
