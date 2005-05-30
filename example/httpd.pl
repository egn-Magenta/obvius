use strict;

$ENV{LANG} = 'da_DK';
$ENV{LC_CTYPE} = 'da_DK';
$ENV{LC_TIME} = 'da_DK';

use DynaLoader ();

use Apache::DBI ();
use DBI ();
use DBD::mysql ();

use Apache::Constants ();
use Apache::File ();
use Apache::Log ();
use Apache::Request ();
use Apache::Registry ();
use Apache::Cookie ();
use Apache::Session ();
use Apache::Util ();

#use Apache::Leak ();

use Date::Calc qw(:all);

use Digest::MD5 ();

use CGI (); CGI->compile(':all');
use CGI::Carp ();

use IO ();
use Image::Size ();
use Image::Magick;

use HTTP::Date ();

use LWP::Simple ();
use HTML::TokeParser ();

use HTML::Entities ();
use HTML::FormatText;
use HTML::Parser;
use HTML::TreeBuilder;
use URI::Escape;

use Time::HiRes;

use MIME::Base64;
use Net::SMTP ();

use Unicode::String;
use XML::Parser;
use XML::Simple;

use Cache::FileCache;


use Obvius;
use Obvius::Log::Apache;

$Obvius::LOG = new Obvius::Log::Apache;

use WebObvius;
use WebObvius::Site;
use WebObvius::Site::Mason;

use WebObvius::Cache;
use WebObvius::Timer;

1;
