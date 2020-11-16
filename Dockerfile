FROM debian:jessie

ARG celery_version

RUN groupadd -r postgres && useradd -r -g postgres postgres

# grab gosu for easy step-down from root
RUN gpg --keyserver pgp.mit.edu --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/* \
&& curl -o /usr/local/bin/gosu -SL "https://github.com/tianon/gosu/releases/download/1.2/gosu-$(dpkg --print-architecture)" \
&& curl -o /usr/local/bin/gosu.asc -SL "https://github.com/tianon/gosu/releases/download/1.2/gosu-$(dpkg --print-architecture).asc" \
&& gpg --verify /usr/local/bin/gosu.asc \
&& rm /usr/local/bin/gosu.asc \
&& chmod +x /usr/local/bin/gosu \
&& apt-get purge -y --auto-remove curl

# make the "en_US.UTF-8" locale so postgres will be utf-8 enabled by default
RUN apt-get update && apt-get install -y locales && rm -rf /var/lib/apt/lists/* \
	&& localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

RUN mkdir /docker-entrypoint-initdb.d

RUN apt-key adv --keyserver pgp.mit.edu --recv-keys B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8

ENV PG_MAJOR 9.4
ENV PG_VERSION 9.4.0-1.pgdg70+1

RUN echo 'deb http://apt.postgresql.org/pub/repos/apt/ wheezy-pgdg main' $PG_MAJOR > /etc/apt/sources.list.d/pgdg.list

RUN apt-get update \
&& apt-get install -y postgresql-common \
&& sed -ri 's/#(create_main_cluster) .*$/\1 = false/' /etc/postgresql-common/createcluster.conf \
&& apt-get install -y \
postgresql-$PG_MAJOR=$PG_VERSION \
postgresql-contrib-$PG_MAJOR=$PG_VERSION \
&& rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/run/postgresql && chown -R postgres /var/run/postgresql

ENV PATH /usr/lib/postgresql/$PG_MAJOR/bin:$PATH
ENV PGDATA /var/lib/postgresql/data
VOLUME /var/lib/postgresql/data

COPY postgres/docker-entrypoint.sh /

ENTRYPOINT ["postgres/docker-entrypoint.sh"]

EXPOSE 5432

RUN apt-get update && \
	apt-get install -y --no-install-recommends \
				curl \
				gcc \
				python-dev \
				python-pip \
				python3-pip \
    			python3-dev \
    			git \
    			vim \
				redis-server \
				python-setuptools \
				python3-setuptools \
	&& \
	apt-get clean -y && \
	rm -rf /var/lib/apt/lists/*

# Note: The official Debian and Ubuntu images automatically ``apt-get clean``
# after each ``apt-get``

# Run the rest of the commands as the ``postgres`` user created by the ``postgres-9.5`` package when it was ``apt-get installed``
USER postgres

# Create a PostgreSQL role named ``docker`` with ``docker`` as the password and
# then create a database `docker` owned by the ``docker`` role.
# Note: here we use ``&&\`` to run commands one after the other - the ``\``
#       allows the RUN command to span multiple lines.


# Adjust PostgreSQL configuration so that remote connections to the
# database are possible.
RUN echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/9.5/main/pg_hba.conf

# And add ``listen_addresses`` to ``/etc/postgresql/9.5/main/postgresql.conf``
RUN echo "listen_addresses='*'" >> /etc/postgresql/9.5/main/postgresql.conf

# Expose the PostgreSQL port
EXPOSE 5432

# Add VOLUMEs to allow backup of config, logs and databases
VOLUME  ["/etc/postgresql", "/var/log/postgresql", "/var/lib/postgresql"]

USER root

# Upgrade pip
RUN pip install --upgrade --ignore-installed pip
RUN pip3 install --upgrade --ignore-installed pip

RUN pip2.7 install wheel
RUN pip3 install wheel

ADD requirements.txt /app/requirements.txt
ADD requirements-dev.txt /app/requirements-dev.txt

RUN pip2.7 install celery==$celery_version
RUN pip3 install celery==$celery_version

RUN pip3 install -r /app/requirements.txt && \
    pip3 install -r /app/requirements-dev.txt && \
	rm -rf ~/.cache

RUN pip2.7 install -r /app/requirements.txt && \
    pip2.7 install -r /app/requirements-dev.txt && \
	rm -rf ~/.cache

WORKDIR /app

# Redis
EXPOSE 6379

# dashboard
EXPOSE 5555