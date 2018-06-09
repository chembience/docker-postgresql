ARG build_label
FROM debian:stretch as rdkit-build
LABEL maintainer="markussitzmann@gmail.com "

ENV RDBASE="/opt/rdkit"
ENV LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$RDBASE/lib:/usr/lib/x86_64-linux-gnu"

ENV RDKIT_BRANCH="master"

WORKDIR /opt

RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl wget gosu sudo \
    gnupg \
    unzip tar bzip2 \
    git \
    postgresql-server-dev-all \
    postgresql-client \
    postgresql-plpython-9.6 \
    postgresql-plpython3-9.6 \
    git \
    cmake \
    build-essential \
    python-numpy \
    python-dev \
    sqlite3 \
    libsqlite3-dev \
    libboost-dev \
    libboost-system-dev \
    libboost-thread-dev \
    libboost-serialization-dev \
    libboost-python-dev \
    libboost-regex-dev \
    libeigen3-dev && \

    git clone -b $RDKIT_BRANCH --single-branch https://github.com/rdkit/rdkit.git && \
    mkdir $RDBASE/build && \
    cd $RDBASE/build && \

    cmake \
      -DRDK_BUILD_INCHI_SUPPORT=ON \
      -DRDK_BUILD_PGSQL=ON \
      -DRDK_BUILD_AVALON_SUPPORT=ON \
      -DPostgreSQL_TYPE_INCLUDE_DIR="/usr/include/postgresql/9.6/server" \
      -DPostgreSQL_ROOT="/usr/lib/postgresql/9.6" .. && \
    make -j `nproc` && \
    make install


ARG build_label
FROM chembience/base:$build_label
LABEL maintainer="markussitzmann@gmail.com "
LABEL origin="docker-postgresql sameer@damagehead.com"


ENV PG_APP_HOME="/etc/docker-postgresql"\
    PG_VERSION=10 \
    PG_USER=postgres \
    PG_HOME=/var/lib/postgresql \
    PG_RUNDIR=/run/postgresql \
    PG_LOGDIR=/var/log/postgresql \
    PG_CERTDIR=/etc/postgresql/certs

ENV PG_BINDIR=/usr/lib/postgresql/${PG_VERSION}/bin \
    PG_DATADIR=${PG_HOME}/${PG_VERSION}/main

RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
 && echo 'deb http://apt.postgresql.org/pub/repos/apt/ stretch-pgdg main' > /etc/apt/sources.list.d/pgdg.list \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y acl \
      postgresql-${PG_VERSION} postgresql-client-${PG_VERSION} postgresql-contrib-${PG_VERSION} \
 && ln -sf ${PG_DATADIR}/postgresql.conf /etc/postgresql/${PG_VERSION}/main/postgresql.conf \
 && ln -sf ${PG_DATADIR}/pg_hba.conf /etc/postgresql/${PG_VERSION}/main/pg_hba.conf \
 && ln -sf ${PG_DATADIR}/pg_ident.conf /etc/postgresql/${PG_VERSION}/main/pg_ident.conf \
 && rm -rf ${PG_HOME} \
 && rm -rf /var/lib/apt/lists/*


COPY --from=rdkit-build /opt/rdkit/build/Code/PgSQL/rdkit/rdkit--3.5.sql /usr/share/postgresql/{PG_VERSION}/extension
COPY --from=rdkit-build /opt/rdkit/Code/PgSQL/rdkit/rdkit.control /usr/share/postgresql/{PG_VERSION}/extension
COPY --from=rdkit-build /opt/rdkit/build/Code/PgSQL/rdkit/librdkit.so /usr/lib/postgresql/{PG_VERSION}/lib/rdkit.so
COPY --from=rdkit-build /usr/lib/x86_64-linux-gnu/libboost_* /usr/lib/x86_64-linux-gnu/


COPY runtime/ ${PG_APP_HOME}/
COPY entrypoint.sh /sbin/entrypoint.sh
RUN chmod 755 /sbin/entrypoint.sh

EXPOSE 5432/tcp
VOLUME ["${PG_HOME}", "${PG_RUNDIR}"]
WORKDIR ${PG_HOME}
ENTRYPOINT ["/sbin/entrypoint.sh"]
