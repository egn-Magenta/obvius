#### Perl packages needed for running Obvius
##
## These are all installed by App::Cpanminus using
## `cpanm --installdeps .`
##
## Packages commented out are not able to be installed from cpan
## Instead, they are installed using the OS package manager but
## are kept here for documentation reasons. Updating to a newer
## version of Perl or using another base OS may necessitate
## changes.
requires 'Algorithm::Diff';
requires 'Apache::Session';
requires 'Apache::Test';
requires 'Apache2::Request';
requires 'Apache2::FakeRequest';
requires 'Apache2::SizeLimit';
#requires 'BerkeleyDB';
requires 'Captcha::reCAPTCHA';
#requires 'Catalyst';
#requires 'Catalyst::Action::RenderView';
#requires 'Catalyst::Plugin::ConfigLoader';
#requires 'Catalyst::Plugin::Static::Simple';
#requires 'Catalyst::View::Mason';
requires 'Clone::PP';
requires 'Config::IOD';
requires 'Convert::NLS_DATE_FORMAT';
#requires 'Crypt::SMIME';
requires 'Crypt::TripleDES';
requires 'Data::Compare';
requires 'Data::Random';
requires 'Database::Migrator';
requires 'Database::Migrator::mysql';
requires 'Date::Calc';
#requires 'Date::ICal';
requires 'DateTime';
requires 'DateTime::Format::Oracle';
requires 'DateTime::Format::Duration';
#requires 'DBD::mysql';
#requires 'DBD::Sybase';
requires 'DBI';
requires 'DBIx::Class';
#requires 'DBIx::Recordset';
requires 'Devel::Cover';
requires 'Devel::Cover::Report::Clover';
requires 'Devel::NYTProf';
requires 'Digest::SHA1';
requires 'Email::Address::XS';
requires 'Email::MIME';
requires 'Encode::Locale';
requires 'ExtUtils::XSBuilder::ParseSource';
requires 'File::Cache';
requires 'File::Type';
requires 'forks';
requires 'Geo::IPfree';
requires 'Getopt::Simple';
requires 'HTML::Diff';
requires 'HTML::FormatText';
requires 'HTML::FromText';
requires 'HTML::Mason';
requires 'HTML::Parser';
requires 'HTML::Scrubber';
requires 'HTML::Tiny';
requires 'HTML::TreeBuilder';
requires 'HTTP::Date';
requires 'HTTP::Message';
requires 'Image::Size';
#requires 'Image::Magick';
requires 'JSON';
requires 'JSON::PP';
requires 'JSON::SL';
requires 'List::Compare';
requires 'Locale::Maketext::Extract';
requires 'Locale::Messages';
requires 'LWP';
requires 'LWP::ConsoleLogger', '==0.000043';
requires 'LWP::MediaTypes';
requires 'MCE::Shared';
requires 'MD5';
requires 'MIME::Types';
requires 'MIME::Words';
requires 'Module::Install::Base';
requires 'Mojo::DOM';
requires 'Net::IDN::Encode';
requires 'Net::LDAP';
requires 'Number::Bytes::Human', '==0.11';
requires 'Number::Format';
requires 'Parallel::ForkManager';
requires 'Params::Validate';
requires 'Rose::DateTime';
requires 'Rose::DB::Object';
requires 'Rose::DB';
requires 'Rose::Object';
requires 'SOAP::Lite';
requires 'SOAP::Transport::HTTP2';
requires 'Spreadsheet::ParseExcel';
requires 'Spreadsheet::WriteExcel';
# Pin to old version because 0.12 doesn't include tap2junit needed in comp test
requires 'TAP::Formatter::JUnit', '==0.11';
#requires 'Term::ReadLine::Gnu';
requires 'Term::Shell';
requires 'Test::MockModule';
requires 'Text::CSV';
requires 'Tie::iCal';
requires 'Time::Clock';
requires 'Time::Out';
requires 'Try::Tiny';
requires 'Unicode::String';
requires 'URI';
requires 'URI::Escape';
requires 'WebService::Solr';
requires 'XML::LibXML';
#requires 'XML::LibXSLT';
requires 'XML::Parser';
requires 'XML::RSS';
requires 'XML::Simple';
requires 'XML::XPath';
