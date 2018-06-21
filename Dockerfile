ARG build_label
FROM chembience/base:$build_label
FROM chembience/rdkit_postgres_compile:${build_label} as rdkit-build
LABEL maintainer="markussitzmann@gmail.com "
LABEL origin="docker-postgresql sameer@damagehead.com"


ENV PG_APP_HOME="/etc/docker-postgresql" \
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


COPY --from=rdkit-build /opt/rdkit/build/Code/PgSQL/rdkit/rdkit--3.5.sql /usr/share/postgresql/${PG_VERSION}/extension
COPY --from=rdkit-build /opt/rdkit/Code/PgSQL/rdkit/rdkit.control /usr/share/postgresql/${PG_VERSION}/extension
COPY --from=rdkit-build /opt/rdkit/build/Code/PgSQL/rdkit/librdkit.so /usr/lib/postgresql/${PG_VERSION}/lib/rdkit.so
COPY --from=rdkit-build /usr/lib/x86_64-linux-gnu/libboost_* /usr/lib/x86_64-linux-gnu/


COPY runtime/ ${PG_APP_HOME}/
COPY entrypoint.sh /sbin/entrypoint.sh
RUN chmod 755 /sbin/entrypoint.sh

EXPOSE 5432/tcp
VOLUME ["${PG_HOME}", "${PG_RUNDIR}"]
WORKDIR ${PG_HOME}
ENTRYPOINT ["/sbin/entrypoint.sh"]
