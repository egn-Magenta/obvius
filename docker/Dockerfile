FROM debian:stretch-slim

ARG DEBIAN_FRONTEND=noninteractive

#Install Apache, perl and dependencies
RUN apt-get update && \
    apt-get install -y \
    apache2 \
    apache2-dev \
    libfile-spec-native-perl \
    make \
    gcc \
    libperl-dev \
    libapache2-mod-apreq2 \
    libapache2-request-perl \
    libapache-session-perl \
    locales \
    libberkeleydb-perl \
    libcatalyst-devel-perl \
    libcatalyst-modules-perl \
    libdbix-recordset-perl \
    libdbd-mysql-perl \
    libdbd-sybase-perl \
    libcrypt-smime-perl \
    libterm-readline-gnu-perl \
    libxml-libxslt-perl \
    libgraphics-magick-perl \
    perlmagick \
    vim \
    nano \
    mc \
    mariadb-client \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/obvius

# Only add requirements file; this rarely changes so we try to cache dependencies
COPY ./cpanfile .

# Install cpanm & deps
RUN cpan App::cpanminus && \
    cpanm --installdeps . && \
    cpanm Date::ICal --force && \
    cpanm GnuPG::Interface --force

# Set up locales
COPY ./docker/locale.gen /etc/locale.gen
RUN locale-gen && \
    cp /usr/share/zoneinfo/Europe/Copenhagen /etc/localtime

ENV PERL5LIB=/var/www/obvius/perl

# Add source code
COPY --chown=www-data:www-data ./bin ./bin
COPY --chown=www-data:www-data ./catalyst_utils ./catalyst_utils
COPY --chown=www-data:www-data ./docs ./docs
COPY --chown=www-data:www-data ./i18n ./i18n
COPY --chown=www-data:www-data ./mason ./mason
COPY --chown=www-data:www-data ./perl ./perl
COPY --chown=www-data:www-data ./sql ./sql
COPY --chown=www-data:www-data ./tests ./tests

COPY ./recordset_patches/DBIx/* /usr/share/perl5/DBIx/
