FROM debian:stretch-slim

ARG GRAFANA_URL="https://dl.grafana.com/oss/release/grafana-5.3.4.linux-amd64.tar.gz"
ARG GF_UID="472"
ARG GF_GID="472"


ENV PATH=/usr/share/grafana/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    GF_PATHS_CONFIG="/etc/grafana/grafana.ini" \
    GF_PATHS_DATA="/var/lib/grafana" \
    GF_PATHS_HOME="/usr/share/grafana" \
    GF_PATHS_LOGS="/var/lib/grafana" \
    GF_PATHS_PLUGINS="/var/lib/grafana_plugins" \
    GF_PATHS_PROVISIONING="/etc/grafana/provisioning"

RUN apt-get update && apt-get install -qq -y tar libfontconfig curl telnet build-essential ca-certificates && \
    mkdir -p "$GF_PATHS_HOME/.aws" && \
    curl "$GRAFANA_URL" | tar xfvz - --strip-components=1 -C "$GF_PATHS_HOME" && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* && \
    groupadd -r -g $GF_GID grafana && \
    useradd -r -u $GF_UID -g grafana grafana && \
    mkdir -p "$GF_PATHS_PROVISIONING/datasources" \
             "$GF_PATHS_PROVISIONING/dashboards" \
             "$GF_PATHS_LOGS" \
             "$GF_PATHS_PLUGINS" \
             "$GF_PATHS_DATA" && \
    cp "$GF_PATHS_HOME/conf/sample.ini" "$GF_PATHS_CONFIG" && \
    cp "$GF_PATHS_HOME/conf/ldap.toml" /etc/grafana/ldap.toml && \
    chown -R grafana:grafana "$GF_PATHS_DATA" "$GF_PATHS_HOME/.aws" "$GF_PATHS_LOGS" "$GF_PATHS_PLUGINS" && \
    chmod 777 "$GF_PATHS_DATA" "$GF_PATHS_HOME/.aws" "$GF_PATHS_LOGS" "$GF_PATHS_PLUGINS"

ENV TZ=Europe/Stockholm
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

EXPOSE 3000

COPY ./run.sh /run.sh
COPY ./grafana.ini /etc/grafana/grafana.ini

USER grafana
WORKDIR /

ARG GF_INSTALL_PLUGINS="alexanderzobnin-zabbix-app,grafana-clock-panel"

RUN if [ ! -z "${GF_INSTALL_PLUGINS}" ]; then \
    OLDIFS=$IFS; \
    IFS=','; \
    for plugin in ${GF_INSTALL_PLUGINS}; do \
    IFS=$OLDIFS; \
    grafana-cli --pluginsDir "$GF_PATHS_PLUGINS" plugins install ${plugin}; \
    done; \
    fi

VOLUME /var/lib/grafana

COPY healthcheck /healthcheck
HEALTHCHECK --interval=30s --timeout=5s CMD /healthcheck || exit 1

ENTRYPOINT [ "/run.sh" ]
