# New ports collection makefile for: obvius-libs
# Date created:	2 Apr 2007
# Whom:			Dmitry Karasik
#
# $Id$
#
PORTNAME=	obvius-libs
PORTVERSION=	1.0
CATEGORIES=	misc

MASTER_SITES=   # none
DISTFILES=      # none

MAINTAINER=	dmitry@magenta-aps.dk

RUN_DEPENDS=	${SITE_PERL}/String/Random.pm:${PORTSDIR}/devel/p5-String-Random \
		${SITE_PERL}/mach/DBD/mysql.pm:${PORTSDIR}/databases/p5-DBD-mysql \
		${SITE_PERL}/DBIx/Recordset.pm:${PORTSDIR}/databases/p5-DBIx-Recordset \
		${SITE_PERL}/mach/Params/Validate.pm:${PORTSDIR}/devel/p5-Params-Validate \
		${SITE_PERL}/mach/Date/Calc.pm:${PORTSDIR}/devel/p5-Date-Calc \
		${SITE_PERL}/mach/Digest/SHA1.pm:${PORTSDIR}/security/p5-Digest-SHA1 \
		${SITE_PERL}/Image/Size.pm:${PORTSDIR}/graphics/p5-Image-Size \
		${SITE_PERL}/XML/Simple.pm:${PORTSDIR}/textproc/p5-XML-Simple \
		${SITE_PERL}/mach/Unicode/String.pm:${PORTSDIR}/converters/p5-Unicode-String \
		${SITE_PERL}/mach/BerkeleyDB.pm:${PORTSDIR}/databases/p5-BerkeleyDB \
		${SITE_PERL}/HTML/Mason.pm:${PORTSDIR}/www/p5-HTML-Mason \
		${SITE_PERL}/Apache/Session.pm:${PORTSDIR}/www/p5-Apache-Session \
		${SITE_PERL}/HTML/Tree.pm:${PORTSDIR}/www/p5-HTML-Tree \
		${SITE_PERL}/HTML/FormatText.pm:${PORTSDIR}/textproc/p5-HTML-Format \
		${SITE_PERL}/Date/ICal.pm:${PORTSDIR}/devel/p5-Date-ICal \
		${SITE_PERL}/Spreadsheet/WriteExcel.pm:${PORTSDIR}/textproc/p5-Spreadsheet-WriteExcel \
		${SITE_PERL}/XML/RSS.pm:${PORTSDIR}/textproc/p5-XML-RSS

NO_WRKSUBDIR=	YES
NO_BUILD=	YES

do-install: # empty

.include <bsd.port.mk>
