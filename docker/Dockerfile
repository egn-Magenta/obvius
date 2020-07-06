FROM debian:stretch-slim

ARG DEBIAN_FRONTEND=noninteractive
ARG SUPERCRONIC_VERSION=v0.1.9
ARG SUPERCRONIC_SHA1SUM=5ddf8ea26b56d4a7ff6faecdd8966610d5cb9d85

WORKDIR /var/www/obvius

# Add list of apt packages
COPY ./sys-requirements.txt sys-requirements.txt

# Install system dependencies from file.
RUN apt-get -y update \
    && apt-get -y install --no-install-recommends $(grep -o '^[^#][[:alnum:].-]*' sys-requirements.txt) \
    # clean up after apt-get and man-pages
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/man/?? /usr/share/man/??_* \
    # Install supercronic
    && curl -fsSL "https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/supercronic-linux-amd64" -o /usr/local/bin/supercronic\
    && echo "${SUPERCRONIC_SHA1SUM}  /usr/local/bin/supercronic" | sha1sum -c - \
    && chmod +x /usr/local/bin/supercronic

# Only add requirements file; this rarely changes so we try to cache dependencies
COPY ./cpanfile .

# Install cpanm & deps
RUN cpan App::cpanminus && \
    cpanm --installdeps . && \
    cpanm Date::ICal --force

# Set up locales
COPY ./docker/locale.gen /etc/locale.gen
RUN locale-gen && \
    cp /usr/share/zoneinfo/Europe/Copenhagen /etc/localtime

ENV PERL5LIB=/var/www/obvius/perl

# Add source code
COPY --chown=www-data:www-data ./bin ./bin
COPY --chown=www-data:www-data ./catalyst_utils ./catalyst_utils
COPY --chown=www-data:www-data ./db ./db
COPY --chown=www-data:www-data ./docs ./docs
COPY --chown=www-data:www-data ./i18n ./i18n
COPY --chown=www-data:www-data ./mason ./mason
COPY --chown=www-data:www-data ./perl ./perl
COPY --chown=www-data:www-data ./sql ./sql
COPY --chown=www-data:www-data ./tests ./tests

COPY ./recordset_patches/DBIx/* /usr/share/perl5/DBIx/
