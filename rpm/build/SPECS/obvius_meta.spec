# Spec file for obvius rpm metadata package

%define _topdir         /var/www/obvius/rpm/build
%define name            obvius-dependencies
%define release         3
%define version         1.0
%define buildroot       %{_topdir}/%{name}-%{version}-root

%define dependencies1   git mod_perl perl-CPAN perl-Digest-SHA1 perl-YAML perl-Params-Validate
%define dependencies2   perl-Date-Calc perl-libwww-perl perl-Time-HiRes perl-SOAP-Lite perl-Image-Size
%define dependencies3   perl-XML-Simple perl-Unicode-String db4-devel perl-Exception-Class libapreq2
%define dependencies4   perl-libapreq perl-BerkeleyDB perl-HTML-Mason perl-Cache-Cache perl-Apache-Session
%define dependencies5   perl-Date-ICal perl-XML-RSS perl-Spreadsheet-WriteExcel perl-JSON perl-XML-LibXSLT
%define dependencies6   perl-XML-XPath perl-DateTime-Format-MySQL perl-DateTime-Format-Pg perl-Sub-Exporter
%define dependencies7   perl-Clone perl-HTML-Tree perl-HTML-Format perl-DBD-MySQL freetds freetds-devel
%define dependencies8   gcc iptraf openssl-devel perl-Algorithm-Diff perl-Apache-DBI perl-Apache2-SOAP
%define dependencies9   perl-Archive-Zip perl-Authen-SASL perl-Compress-Raw-Bzip2 perl-Convert-ASN1
%define dependencies10  perl-Convert-BinHex perl-DateTime-Format-Builder perl-Digest-HMAC
%define dependencies11  perl-Email-Valid perl-GSSAPI perl-IO-Compress-Bzip2 perl-IO-Socket-INET6
%define dependencies12  perl-IO-Socket-SSL perl-LDAP perl-MIME-tools perl-Module-Load-Conditional
%define dependencies13  perl-Net-LibIDN perl-Net-SSLeay perl-Net-Telnet perl-Socket6 perl-Text-Iconv
%define dependencies14  perl-XML-Filter-BufferText perl-XML-SAX-Writer zlib-devel

%define all_deps1       %{dependencies1} %{dependencies2} %{dependencies3} %{dependencies4}
%define all_deps2       %{dependencies5} %{dependencies6} %{dependencies7} %{dependencies8}
%define all_deps3       %{dependencies9} %{dependencies10} %{dependencies11} %{dependencies12}
%define all_deps4       %{dependencies13} %{dependencies14}

BuildRoot:              %{buildroot}
Summary:                Meta package for installing Obvius dependencies
License:                GPL
Name:                   %{name}
Version:                %{version}
Release:                %{release}
Source:                 %{name}-%{version}.tar.gz
#Prefix:                 /usr
Group:                  Networking/WWW
Requires:               %{all_deps1} %{all_deps2} %{all_deps3}
# %{all_deps4}


%description
Meta package with the dependencies required to install the Obvius CMS.

%prep

%build

%install

%post

%files
