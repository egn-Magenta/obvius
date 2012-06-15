# Spec file for obvius rpm metadata package

%define _topdir         /var/www/obvius/rpm/build
%define name            obvius-dependencies
%define release         2
%define version         1.0
%define buildroot       %{_topdir}/%{name}-%{version}-root

BuildRoot:              %{buildroot}
Summary:                Meta package for installing Obvius dependencies
License:                GPL
Name:                   %{name}
Version:                %{version}
Release:                %{release}
Source:                 %{name}-%{version}.tar.gz
#Prefix:                 /usr
Group:                  Networking/WWW
Requires:               git mod_perl perl-CPAN perl-Digest-SHA1 perl-YAML perl-Params-Validate perl-Date-Calc perl-libwww-perl perl-Time-HiRes perl-SOAP-Lite perl-Image-Size perl-XML-Simple perl-Unicode-String db4-devel perl-Exception-Class libapreq2 perl-libapreq perl-BerkeleyDB perl-HTML-Mason perl-Cache-Cache perl-Apache-Session perl-Date-ICal perl-XML-RSS perl-Spreadsheet-WriteExcel perl-JSON perl-XML-LibXSLT perl-XML-XPath perl-DateTime-Format-MySQL perl-DateTime-Format-Pg perl-Sub-Exporter perl-Clone perl-HTML-Tree perl-HTML-Format perl-DBD-MySQL

%description
Meta package with the dependencies required to install the Obvius CMS.

%prep

%build

%install

%post

%files
