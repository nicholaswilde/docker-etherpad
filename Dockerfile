FROM alpine:3.13.1 as base

FROM base as dl
ARG VERSION
ARG CHECKSUM=2c11b26aa6157104b1a26a4f9efaf501c6986bd3faa839a34685009de904b566
WORKDIR /tmp
ARG FILENAME="${VERSION}.tar.gz"
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
RUN \
  echo "**** install packages ****" && \
  apk add --no-cache \
    wget=1.21.1-r1 && \
  echo "**** download haste ****" && \
  mkdir /app && \
  wget "https://github.com/ether/etherpad-lite/archive/${FILENAME}" && \
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
LABEL build_version="Version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="nicholaswilde"
ENV NODE_ENV=production
RUN \
  echo "**** install packages ****" && \
  apk add --no-cache \
    nodejs=14.15.4-r0 \
    tzdata=2021a-r0 \
    npm=14.15.4-r0 && \
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
