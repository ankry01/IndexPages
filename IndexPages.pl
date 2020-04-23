#!/usr/bin/perl -w

use Mediawiki::API;
use Data::Dump qw(dump);
use List::MoreUtils qw(uniq);
use Data::Dumper;
use Encode;
require "IP-lib.pl";

my ( $api, $revid, $xml, $csrftoken, $title, $rc, $i, $fh, $fh2, $sql );
my @ind = ();
my @ind2 = ();
my @indel = ();
my @indel2 = ();
my $filename = "/usr/home/akbot/.IndexPages/TIMESTAMP";

$api = new Mediawiki::API;

$api->base_url("https://pl.wikisource.org/w/api.php");

$api->login("AkBot", "...");

# get csfr token
$xml  = $api->makeXMLrequest(
                  [ 'action' => 'query',
                    'meta' => 'tokens',
                    'format' => 'xml' ] );
#print Dumper $xml;

if ( ! defined $xml->{'query'}
       || ! defined $xml->{'query'}->{'tokens'}
       || ! defined $xml->{'query'}->{'tokens'}->{'csrftoken'} ) {
     $api->handleXMLerror($xml);
}
$csrftoken = $xml->{'query'}->{'tokens'}->{'csrftoken'};
$api->print(1, "I csrftoken is $csrftoken");

#$start = '20150318000000';
#$end = '20150311000000';

#open($fh, '<:encoding(UTF-8)', $filename)
open($fh, '<', $filename)
  or die "Could not open file '$filename' $!";

if (my $row = <$fh>) {
  chomp $row;
  $end = $row;
}
#$api->print(1, "I checking from $end till now");
print "I last update tme is $end\n";

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=gmtime(time);
if ($hour > 0) {
  $hour--
}
else {
  $hour = 23;
  if ($mday > 1) {
    $mday--;
  }
  else {
    die "Unsuported start time; try again later";
  }
}

my $nice_timestamp = sprintf ( "%04d%02d%02d%02d%02d%02d",
   $year+1900,$mon+1,$mday,$hour,$min,$sec);
print "I current time is $nice_timestamp\n";

$xml = $api->makeXMLrequest(
                  [ 'action' => 'query',
                    'list' => 'recentchanges',
                    'rcnamespace' => '102',
                    'rcprop' => 'title|timestamp|loginfo',
                    'rclimit' => '2500',
                    'rcend' => $end,
                    'continue' => '',
                    'format' => 'xml' ] );
#print Dumper $xml;

if ( ! defined $xml->{'query'}
       || ! defined $xml->{'query'}->{'recentchanges'} ) {
     $api->handleXMLerror($xml);
}

if ( defined $xml->{'query'}->{'recentchanges'}->{'rc'} ) {
  $rc = $xml->{'query'}->{'recentchanges'}->{'rc'};
#  print Dumper $rc;
  if ( ref($rc) eq 'HASH' ) {
    if ( defined $rc->{'title'} ) {
      push(@ind, $rc->{'title'});
    }
    if ( $rc->{'type'} eq 'log' ) {
      if ( $rc->{'logaction'} eq 'move' ) {
        push(@indel, $rc->{'title'});
	if ( defined $rc->{'move'} ) {
          push(@ind, $rc->{'move'}->{'new_title'});
	} else {
	  push(@ind, $rc->{'logparams'}->{'target_title'});
        }
      } elsif ( $rc->{'logaction'} eq 'delete' ) {
        push(@indel, $rc->{'title'});
      }
    }
    print "I single index page in RC: " . $rc->{'title'} . "\n";
  } else {
    $i = 0;
    while ($rc->[$i]) {
      if ($rc->[$i]->{'type'} eq 'edit' or $rc->[$i]->{'type'} eq 'new') {
        push(@ind, $rc->[$i]->{'title'});
      }
      elsif ($rc->[$i]->{'type'} eq 'log') {
        if ($rc->[$i]->{'logaction'} eq 'move') {
#	print Dumper $rc->[$i];
          push(@indel, $rc->[$i]->{'title'});
	  if ( defined $rc->[$i]->{'move'} ) {
            push(@ind, $rc->[$i]->{'move'}->{'new_title'});
	  } else {
	    push(@ind, $rc->[$i]->{'logparams'}->{'target_title'});
	  }
        } elsif ($rc->[$i]->{'logaction'} eq 'delete') {
          push(@indel, $rc->[$i]->{'title'});
        }
      }
      $i++;
    }
  }

  if (@ind) {
    @ind2 = uniq(sort(@ind));
  }
  if (@indel) {
    @indel2 = uniq(sort(@indel));
  }
}
if (@ind2) {
  @ind2 = grep { $_ ne "Indeks:Testowy" } @ind2;
}
print "I index lists prepared\n";
# sprawdzenie czy indeksy z @indel2 rzeczywiście są skasowane

print Dumper @indel2;
foreach $name (@indel2) {
  my $name2 = '';
  Encode::_utf8_off($name2 = $name);
  $xml = $api->makeXMLrequest(
                  [ 'action' => 'query',
                    'prop' => 'info',
                    'titles' => $name2,
                    'continue' => '',
                    'format' => 'xml' ] );

  if ( ! defined $xml->{'query'}
       || ! defined $xml->{'query'}->{'pages'}
       || ! defined $xml->{'query'}->{'pages'}->{'page'} ) {
     $api->handleXMLerror($xml);
  }
#print Dumper $xml;
  print "I $name2 existence investigated...\n";
  if ( defined $xml->{'query'}->{'pages'}->{'page'}->{'missing'} ) {
    if (@ind2) {
      @ind2 = grep { $_ ne $name } @ind2;
    }
    $name2 =~ s/^Indeks://;
    print "I $name being removed fromn list\n";
    system("/usr/home/akbot/bin/eknij", "Szablon:IndexPages/$name2");
    if ( $? != 0 ) {
      die "Nie udało się ek-nąć strony Szablon:IndexPages/$name2";
    }
  }
}
print "I ek setting for indexes finished\n";

# updejtnięcie bazy SQL
$sql = "";
foreach $name (@ind2) {
  my $name2 = '';
  Encode::_utf8_off($name2 = $name);
#  if ( $name2 ne "Indeks:Testowy" ) {
    my $name_nons = substr($name2, 7);
    $name_nons =~ s/'/\\\'/;
    print "$name2\n";
    $sql .= "DELETE FROM pages_in_index WHERE index_name = '$name_nons';\n" . set_regex_for_index($api, $name2) . ";\n";
#  }
}
my $sqlfilename = '/usr/home/akbot/.IndexPages/ind_regex.sql';
open($fh2, '>', $sqlfilename) or die "Could not open file '$sqlfilename' $!";
print $fh2 $sql;
close $fh2;
#print substr($sql,0,500)."...\n";
system("/usr/home/akbot/bin/mysql-script", $sqlfilename);
print "I SQL regex database updated\n";

# teraz zajmijmy się zmianami w przestrzeni Strona

my @modpages = ();
$xml = $api->makeXMLrequest(
                  [ 'action' => 'query',
                    'list' => 'recentchanges',
                    'rcnamespace' => '100',
                    'rcprop' => 'title|timestamp|loginfo',
                    'rclimit' => '5000',
                    'rcend' => $end,
                    'continue' => '',
                    'format' => 'xml' ] );

if ( ! defined $xml->{'query'}
       || ! defined $xml->{'query'}->{'recentchanges'} ) {
     $api->handleXMLerror($xml);
}

# TODO kontynuacja dla > 5000 stron

if ( defined $xml->{'query'}->{'recentchanges'}->{'rc'} ) {
  $rc = $xml->{'query'}->{'recentchanges'}->{'rc'};
  $i = 0;
#  print Dumper $rc;
  if ( ref($rc) eq 'HASH' ) {
    if ( defined $rc->{'title'} ) {
      push(@modpages, $rc->{'title'});
    }
    if ( $rc->{'type'} eq 'log' &&
         $rc->{'logaction'} eq 'move' ) {
#      push(@modpages, $rc->{'move'}->{'new_title'});
      push(@modpages, $rc->{'logparams'}->{'target_title'});
    }
    print "I single page in RC:" . $rc->{'title'} . "\n";
  } else {
    while (defined $rc->[$i]) {
      if ( defined $rc->[$i]->{'title'} ) {
        push(@modpages, $rc->[$i]->{'title'});
      }
      if ( $rc->[$i]->{'type'} eq 'log' &&
           $rc->[$i]->{'logaction'} eq 'move' ) {
#          push(@modpages, $rc->[$i]->{'move'}->{'new_title'});
          push(@modpages, $rc->[$i]->{'logparams'}->{'target_title'});
      }
      $i++;
    }
  }
  @modpages2 = uniq(sort(@modpages));
  $sql = "DELETE FROM pages;\nINSERT IGNORE INTO pages (p) VALUES ";
  $sqlvalues = '';
  foreach $page (@modpages2) {
    my $page2 = '';
    Encode::_utf8_off( $page2 = $page );
    $page2 =~ s/'/\\\'/g;
    $page2 = substr($page2, 7);
    if ( $sqlvalues ne '' ) {
      $sqlvalues .= ',';
    }
    $sqlvalues .= "('$page2')";
  }
  $sql .= $sqlvalues . ";\n";
}
print "I list of pages from RC processed\n";
my $sqlfilename2 = '/usr/home/akbot/.IndexPages/pages.sql';
open($fh2, '>', $sqlfilename2) or die "Could not open file '$sqlfilename2' $!";
print $fh2 $sql;
close $fh2;
#print substr($sql,0,300) . "...\n";
system("/usr/home/akbot/bin/mysql-script", $sqlfilename2);
print "I SQL page database updated\n";

# znajdź indeksy dla stron
system("/usr/home/akbot/bin/mysql-qscript");
print "I SQL query for index pages finished\n";
my $resfileneme = '/usr/home/akbot/.IndexPages/wynik.ind';
open($fh2, '<:utf8', $resfileneme)
  or die "Could not open file '$filename' $!";
my $indname = '';
while ($indname = <$fh2>) {
  chomp $indname;
#  print "Pages edited for $indname\n";
  push(@ind2, "Indeks:$indname");
}
close($fh2);
#print Dumper @ind2;
@ind = uniq(sort(@ind2));

#print scalar @modpages2;
#print "\n";
print Dumper @ind;

purge_inds($api, \@ind);
print "I updated index pages purged\n";
system("sleep", "20");
system("/usr/home/akbot/bin/index-status-v3", "-noupdate");
#print Dumper @ind;
update_ind_data($api, \@ind);

open($fh, '>', $filename)
  or die "Could not open file '$filename' $!";
print $fh $nice_timestamp;
close($fh);

exit 0;


set_regex_for_all();

exit 0;

