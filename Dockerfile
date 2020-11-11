FROM postgres

ARG celery_version

RUN apt-get update && apt-get install -y python-software-properties software-properties-common

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
RUN    /etc/init.d/postgresql start &&\
    psql --command "CREATE USER docker WITH SUPERUSER PASSWORD 'docker';" &&\
    createdb -O docker docker

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