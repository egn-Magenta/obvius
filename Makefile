# $Id$

PREFIX?=/usr/local/obvius

all: build

build:
.if ! exists ( perl/Obvius/Makefile )
	cd perl/Obvius && perl Makefile.PL
.endif
	cd perl/Obvius && make
.if ! exists ( perl/WebObvius/Makefile )
	cd perl/WebObvius && perl Makefile.PL
.endif
	cd perl/WebObvius && make

configure:
	cd perl/Obvius && perl Makefile.PL
	cd perl/WebObvius && perl Makefile.PL

install: build
	mkdir -p ${PREFIX} || true
	cp -pPR bin cron docs example manual mason otto skeleton ${PREFIX}/
	cd perl/Obvius && make install
	cd perl/WebObvius && make install

clean:
	cd perl/Obvius && make clean || true
	cd perl/WebObvius && make clean || true

test:
	@echo 'Checking prerequisites...'
	@sqlpp --help > /dev/null
	@perl -MString::Random -MDBI -MDBIx::Recordset -MParams::Validate -MDate::Calc \
	-MDigest::SHA1 -MImage::Size -MXML::Simple -MUnicode::String -MBerkeleyDB \
	-MHTML::Mason -MApache::Session -MHTML::Tree -MHTML::FormatText -e 1
	@echo 'Running tests...'
	@cd perl/Obvius && make test || true
	@cd perl/WebObvius && make test || true
