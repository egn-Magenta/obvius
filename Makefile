# $Id$

PREFIX?=/usr/local/obvius

all: build

build: perl/Makefile
	cd perl && make

perl/Makefile:
	cd perl && perl Makefile.PL

configure:
	cd perl && perl Makefile.PL

install: build
	mkdir -p ${PREFIX} || true
	cp -pPR bin cron docs example manual mason otto skeleton ${PREFIX}/
	cd perl && make install

clean:
	cd perl && make clean || true

test:
	@echo 'Checking prerequisites...'
	@perl -MString::Random -MDBI -MDBIx::Recordset -MParams::Validate -MDate::Calc \
	-MDigest::SHA1 -MImage::Size -MXML::Simple -MUnicode::String -MBerkeleyDB \
	-MTime::HiRes \
	-MHTML::Mason -MApache::Session -MHTML::Tree -MHTML::FormatText -e 1
	@echo 'Running tests...'
	@cd perl && make test || true
