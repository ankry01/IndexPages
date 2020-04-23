#!/usr/bin/perl -w

use Mediawiki::API;
use Data::Dump qw(dump);
use List::MoreUtils qw(uniq);
use Data::Dumper;
use Encode;
require "IP-lib.pl";

my $api = new Mediawiki::API;

$api->base_url("https://pl.wikisource.org/w/api.php");
$api->login("AkBot", "...");

set_regex_for_all($api);

