ARG build_label
FROM markussitzmann/appdock_base:$build_label as rdkit-build

### RDKIT

#######################################################################
# Prepare the environment for the rdkit compilation:
ENV RDBASE="/opt/rdkit"
ENV LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$RDBASE/lib:/usr/lib/x86_64-linux-gnu"
#ENV PYTHONPATH="$PYTHONPATH:$RDBASE"
#ENV PostgreSQL_ROOT="/usr/lib/postgresql/9.6"
#ENV PostgreSQL_TYPE_INCLUDE_DIR="/usr/include/postgresql/9.6/server"
#ENV PGPASSWORD="$POSTGRES_PASSWORD"
#ENV PGUSER="$POSTGRES_USER"

ENV RDKIT_BRANCH="master"

WORKDIR /opt

#######################################################################
# Prepare the build requirements for the rdkit compilation:
RUN apt-get update && apt-get install -y \
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
# Cloning RDKit git repo:
    git clone -b $RDKIT_BRANCH --single-branch https://github.com/rdkit/rdkit.git && \
    mkdir $RDBASE/build && \
    cd $RDBASE/build && \
# Compiling and installing RDKit:
    cmake \
      -DRDK_BUILD_INCHI_SUPPORT=ON \
      -DRDK_BUILD_PGSQL=ON \
      -DRDK_BUILD_AVALON_SUPPORT=ON \
      -DPostgreSQL_TYPE_INCLUDE_DIR="/usr/include/postgresql/9.6/server" \
      -DPostgreSQL_ROOT="/usr/lib/postgresql/9.6" .. && \
    make -j `nproc` && \
    make install && \
# Installing RDKit Postgresql extension:
    sh Code/PgSQL/rdkit/pgsql_install.sh && \
# Cleaning up:
    make clean && \
    cd $RDBASE && \
    rm -r $RDBASE/build && \
    apt-get remove -y git cmake build-essential && \
    apt-get autoremove --purge -y && \
    apt-get clean && \
    apt-get purge && \
    rm -rf /var/lib/apt/lists/*

### RDKIT done


ARG build_label
FROM markussitzmann/appdock_base:$build_label
MAINTAINER markussitzmann@gmail.com forked from sameer@damagehead.com


ENV PG_APP_HOME="/etc/docker-postgresql"\
    PG_VERSION=9.6 \
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

COPY runtime/ ${PG_APP_HOME}/
COPY entrypoint.sh /sbin/entrypoint.sh
RUN chmod 755 /sbin/entrypoint.sh

EXPOSE 5432/tcp
VOLUME ["${PG_HOME}", "${PG_RUNDIR}"]
WORKDIR ${PG_HOME}
ENTRYPOINT ["/sbin/entrypoint.sh"]
