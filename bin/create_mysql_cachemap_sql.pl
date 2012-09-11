#!/usr/bin/perl

use strict;
use warnings;

my $tablename = shift(@ARGV);

die "You must specify a table name" unless($tablename);

print <<EOT;
DROP TABLE IF EXISTS `$tablename`;
CREATE TABLE `$tablename` (
    `uri` blob NOT NULL DEFAULT '',
    `querystring` varchar(255) NOT NULL DEFAULT '',
    `cache_uri` varchar(255) NOT NULL DEFAULT '',
    PRIMARY KEY (`uri`(255), `querystring`(255)),
    KEY `${tablename}_querystring_idx` (`querystring`(255))
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
EOT
