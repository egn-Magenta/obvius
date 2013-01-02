#!/usr/bin/perl

use strict;
use warnings;

use DBI;
use Obvius::Config;
use Data::Dumper;

use Encode;
use DateTime;
use DateTime::TimeZone;
use Obvius::CharsetTools qw(mixed2utf8);
use Text::CSV;
use LWP::UserAgent;

my ($confname, @docids) = @ARGV;

die "No confname specified" unless($confname);

my $config = new Obvius::Config($confname);
die "Couldn't load obvius config for '$confname'" unless($config);

my $servers_str = $config->param('solr_servers');
exit 0 unless($servers_str);

my $fieldnames = $config->param('solr_fieldnames') ||
    'id,published,path,docdate,teaser,content,title,tags,lang,type';

my @destinations = map {
    "http://${_}/solr/update/csv?fieldnames=${fieldnames}&commit=true"
} split(/\s*,\s*/, $servers_str);


my $local_tz = new DateTime::TimeZone(name => 'local');

sub convert_datetime {
    my $str = shift;

    my ($Y, $M, $D, $h, $m, $s) = split(/\D+/, $str);

    my $dt = new DateTime(
        year => $Y,
        month => $M,
        day => $D,
        hour => $h,
        minute => $m,
        second => $s,
        time_zone => $local_tz
    );

    # Make it UTC
    $dt->subtract(seconds => $dt->offset());
    return $dt->iso8601 . "Z";
}

my $dbh = DBI->connect(
    $config->param('dsn'),
    $config->param('normal_db_login'),
    $config->param('normal_db_passwd'),
);
$dbh->do("set names utf8");


my $qmarks = join(",", map {"?"} @docids);

my $query = qq|
select
    v.docid id,
    published.date_value published,
    dp.path path,
    docdate.date_value docdate,
    binary teaser.text_value teaser,
    binary content.text_value content,
    binary title.text_value title,
    tags.tags tags,
    v.lang lang,
    dt.name type,
    v.version version
from
    versions v
    natural join
    docid_path dp
    join
    doctypes dt on (
        dt.id = v.type
    )
    left join
    vfields published on (
        v.docid = published.docid
        and
        v.version = published.version
        and
        published.name = 'published'
    )
    left join vfields docdate on (
        v.docid = docdate.docid
        and
        v.version = docdate.version
        and
        docdate.name = 'docdate'
        and
        docdate.date_value != '0000-00-00 00:00:00'
    )
    left join vfields content on (
        v.docid = content.docid
        and
        v.version = content.version
        and
        content.name = 'content'
    )
    left join vfields teaser on (
        v.docid = teaser.docid
        and
        v.version = teaser.version
        and
        teaser.name = 'teaser'
    )
    left join vfields title on (
        v.docid = title.docid
        and
        title.version = v.version
        and
        title.name = 'title'
    )
    left join (
        select
            group_concat(binary vf.text_value separator ', ') tags,
            vf.docid docid,
            vf.version version
        from
            versions v
            natural join
            vfields vf
        where
            vf.name = 'tags'
            and
            v.public = 1
            and
            v.docid IN ($qmarks)
        group by
            docid,
            version
    ) tags on (
        tags.docid = v.docid
        and
        tags.version = v.version
    )
    where
        v.public = 1
        and
        v.docid IN ($qmarks)
|;

# Allow query to be overwritten by local config
if(my $filename = $config->param('solr_live_index_query_file')) {
    local $/ = undef;
    open(FH, $filename) or die "Couldn't open $filename";
    $query = <FH>;
    close(FH);
    $query =~ s!#DOCIDS#!$qmarks!gs;
}

my $sth = $dbh->prepare($query);
$sth->execute(@docids, @docids);


my $csv = new Text::CSV({binary => 1});

my $csv_data = '';

while(my @row = $sth->fetchrow_array) {
    # Date values defaults to version string
    $row[1] = convert_datetime($row[1] || $row[10]);
    $row[3] = convert_datetime($row[3] || $row[10]);
    for(4..7) {
        $row[$_] = mixed2utf8($row[$_]);
    }
    # Discard the version string
    pop(@row);
    $csv->combine(@row);
    $csv_data .= $csv->string() . "\n";
}

print STDERR $csv_data;

my $ua = new LWP::UserAgent;
for my $dest (@destinations) {
    print STDERR "Posting CSV data to $dest\n";
    my $req = HTTP::Request->new( POST => $dest );
    $req->content_type("text/csv; charset=utf-8");
    $req->content($csv_data);

    $ua->request($req);
}
