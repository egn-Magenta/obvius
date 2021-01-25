FROM debian:stretch-slim

ARG DEBIAN_FRONTEND=noninteractive
WORKDIR /var/www/obvius

# Set supercronic env
ENV SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/v0.1.12/supercronic-linux-amd64 \
    SUPERCRONIC=supercronic-linux-amd64 \
    SUPERCRONIC_SHA1SUM=048b95b48b708983effb2e5c935a1ef8483d9e3e

# Change the UID and GID for the www-data user and group to reflect
# the ones used by the old KU Obvius setup.
RUN groupmod -g 48 www-data && usermod -u 48 www-data

# Add list of apt packages
COPY ./sys-requirements.txt sys-requirements.txt

# Install system dependencies from file.
# Hadolint fails to recognize that we are installing from a file. Suppress version warning
# Hadolint also suggests we quote the grep command to avoid word splitting. Quoting it causes, err, word splitting
# hadolint ignore=SC2046,DL3008
RUN apt-get -y update \
    && apt-get -y install --no-install-recommends $(grep -o '^[^#][[:alnum:].-]*' sys-requirements.txt) \
    # clean up after apt-get and man-pages
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/man/?? /usr/share/man/??_*

# Install supercronic
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -fsSLO "$SUPERCRONIC_URL" \
    && echo "${SUPERCRONIC_SHA1SUM}  ${SUPERCRONIC}" | sha1sum -c - \
    && chmod +x "$SUPERCRONIC" \
    && mv "$SUPERCRONIC" "/usr/local/bin/${SUPERCRONIC}" \
    && ln -s "/usr/local/bin/${SUPERCRONIC}" /usr/local/bin/supercronic

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
