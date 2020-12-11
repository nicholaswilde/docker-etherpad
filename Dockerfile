FROM --platform=$BUILDPLATFORM alpine:3.12.1 as base
ARG TARGETARCH
ARG BUILDPLATFORM
ARG VERSION=0.2.9
RUN \
  echo "**** install packages ****" && \
  apk add --no-cache \
    git=2.26.2-r0 && \
  git clone https://github.com/ether/etherpad-lite.git

FROM alpine:3.12.1
ARG ETHERPAD_PLUGINS=
ENV NODE_ENV=production
RUN \
  echo "**** install packages ****" && \
  apk add --no-cache \
    nodejs=12.18.4-r0 \
    npm=12.18.4-r0 && \
  adduser -S etherpad --uid 5001 && \
  mkdir /opt/etherpad-lite && \
  chown etherpad:0 /opt/etherpad-lite
USER etherpad
WORKDIR /opt/etherpad-lite
COPY --from=base --chown=etherpad:0 /etherpad-lite ./
COPY --from=base --chown=etherpad:0 /etherpad-lite/settings.json.docker /opt/etherpad-lite/settings.json
RUN bin/installDeps.sh && \
  rm -rf ~/.npm/_cacache && \
  for PLUGIN_NAME in ${ETHERPAD_PLUGINS}; do npm install "${PLUGIN_NAME}" || exit 1; done && \
  chmod -R g=u .
EXPOSE 9001
CMD ["node", "--experimental-worker", "node_modules/ep_etherpad-lite/node/server.js"]
