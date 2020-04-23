#!/usr/bin/perl -w

use Mediawiki::API;
use Data::Dump qw(dump);
use List::MoreUtils qw(uniq);
use Data::Dumper;
use Encode;

#========================================================================
sub purge_inds {
  my $api = $_[0];
  my @ind_table = @{$_[1]};
  my ( $idx, $index, $xml );
  foreach $index (@ind_table) {
    Encode::_utf8_off( $idx = $index );
#    print "idx = $idx\n";
    $xml = $api->makeXMLrequest(
                 [ 'action' => 'purge',
		   'titles' => $idx,
		   'continue' => '',
                   'format' => 'xml' ] );

    if ( ! defined $xml->{'purge'}
      || ! defined $xml->{'purge'}->{'page'}
      || ( ! defined $xml->{'purge'}->{'page'}->{'purged'}
       &&  ! defined $xml->{'purge'}->{'page'}->{'missing'} ) ) {
      $api->handleXMLerror($xml);
      return (-1);
    }
    print "I $idx purged\n";
#    print Dumper $xml;
  }
  return 0;
}
#========================================================================
sub update_ind_data {
  my $api = $_[0];
  my @ind_table = @{$_[1]};
  my ( $n, $idx, $index, $name, $fd, $line, $line2, $xml );
  my @tbdata = ();
  my $datafile = '/usr/home/akbot/.IndexPages/IndexPages.3';
  open($fd, '<:utf8', $datafile)
    or die "Could not open file '$datafile' $!";
  while ($line = <$fd>) {
    chomp $line;
    Encode::_utf8_off( $line2 = $line );
#    print "$line2\n";
    push(@tbdata, $line2);
  }
  print "I update_ind_data() started\n";
  close($fd);
#  print "Indexes to update:\n";
  print Dumper @ind_table;
  foreach $index (@ind_table) {
    Encode::_utf8_off( $idx = $index );
    $name = $idx;
    $name =~ s/^Indeks://;
print Dumper $tbdata;
print Dumper $tbdata[$_];
print "name=$name\n";
print "_=$_\n";
    ( $n ) = grep { substr($tbdata[$_], 0, length($name)+1) eq $name . '<' } 0..$#tbdata;
print "n- $n\n";
    $data = substr($tbdata[$n], length($name)+1);
    if ( defined $n ) {
      $s = substr($data, 0, index($data, '<'));
      $data = substr($data, length($s)+1);
      $x4 = substr($data, 0, index($data, '<'));
      $data = substr($data, length($x4)+1);
      $x3 = substr($data, 0, index($data, '<'));
      $data = substr($data, length($x3)+1);
      $x2 = substr($data, 0, index($data, '<'));
      $data = substr($data, length($x2)+1);
      $x1 = substr($data, 0, index($data, '<'));
      $data = substr($data, length($x1)+1);
      $x0 = $data;
#      print "n=$n\n";
#      print "python pwb.py replace -page:'Szablon:IndexPages/$name' -regex '<pc>.*</q0>' '<pc>$s</pc><q4>$x4</q4><q3>$x3</q3><q2>$x2</q2><q1>$x1</q1><q0>$x0</q0>'\n"
      $xml = $api->makeXMLrequest(
                   [ 'action' => 'query',
                     'prop' => 'info',
                     'titles' => "Szablon:IndexPages/$name",
                     'continue' => '',
                     'format' => 'xml' ] );
#     print Dumper $xml;

      if ( ! defined $xml->{'query'}
        || ! defined $xml->{'query'}->{'pages'}
        || ! defined $xml->{'query'}->{'pages'}->{'page'} ) {
        $api->handleXMLerror($xml);
        return (-1);
      }
#      my $createfile = '/usr/home/akbot/.IndexPages/IndexPages.4';
#      open($fd, '>', $createfile)
#        or die "Could not open file '$createfile' $!";
#      print $fd $tbdata[$n] . "\n";
#      close($fd);
      if ( defined $xml->{'query'}->{'pages'}->{'page'}->{'missing'} ) {
        # zapisać coś do pliku
        my $createfile = '/usr/home/akbot/.IndexPages/IndexPages.4';
        open($fd, '>', $createfile)
          or die "Could not open file '$createfile' $!";
        print $fd $tbdata[$n] . "\n";
        close($fd);
        system("/usr/home/akbot/bin/index-status-newpages", "/usr/home/akbot/.IndexPages/IndexPages.4");
      } else {
        system("/usr/home/akbot/bin/page-update", "Szablon:IndexPages/$name", "<pc>$s</pc><q4>$x4</q4><q3>$x3</q3><q2>$x2</q2><q1>$x1</q1><q0>$x0</q0>");
      }
    }
  }
  return 0;
}
#========================================================================
sub check_regex {
  $page = $_[0];
  @regex_table = @{$_[1]};
  if (index($page, 'Strona:') == 0) {
    $page2 = substr($page, 7);
  }
  $i = 0;
  foreach $regex (@regex_table) {
    if ( $page2 ~~ qr/$regex/ ) {
      return $i;
    }
    $i++;
  }
  return (-1);
}
#========================================================================
sub set_regex_for_index {
  my $api = $_[0];
  my $name = $_[1];
  my @pagel = ();
  my $sqlvalues = '';
  my $sql = '';
  my $page = '';
  my $regex = '';
  my $title = '';
  
  my $xml = $api->makeXMLrequest(
                  [ 'action' => 'query',
                    'prop' => 'links',
                    'titles' => $name,
                    'plnamespace' => 100,
                    'pllimit' => 2000,
                    'continue' => '',
                    'format' => 'xml' ] );

  if ( ! defined $xml->{'query'}
       || ! defined $xml->{'query'}->{'pages'}
       || ! defined $xml->{'query'}->{'pages'}->{'page'} ) {
     $api->handleXMLerror($xml);
  }
#  print Dumper $xml->{'query'}->{'pages'}->{'page'}->{'links'};
  if ( defined $xml->{'query'}->{'pages'}->{'page'}->{'links'} ) {
    $links = $xml->{'query'}->{'pages'}->{'page'}->{'links'};
    $i = 0;
    if ( defined $links->{pl} ) {
      if ( ref($links->{pl}) eq 'HASH' && defined $links->{pl}->{'title'}  ) {
        Encode::_utf8_off( $title = $links->{pl}->{'title'} );
        push(@pagel, $title);
      } else {
        while ( defined $links->{pl}->[$i] ) {
          Encode::_utf8_off( $title = $links->{pl}->[$i]->{'title'} );
          push(@pagel, $title);
          $i++;
        }
      }
    }
#    print Dumper @pagel;
    my @regex_table = ();
    my $bname;
    foreach $page (@pagel) {
      if ( scalar(@regex_table) == 0 or
           check_regex($page, \@regex_table) <0 ) {
        # wcześniejsze nie pasują
        my $npage = $page;
	$npage =~ s/\?/\\?/g;
        $npage =~ s/\./\\./g;
        $npage =~ s/\(/\\(/g;
        $npage =~ s/\)/\\)/g;
        $npage =~ s/\+/\\+/g;
        $npage =~ s/'/\\'/g;
        $npage =~ s/^Strona:/^/;
        my $n = index($npage, '/');
        if ( $n > 0 ) {
          my $n2page = substr($npage, 0, $n+1);
          my $nd = substr($npage, $n+1);
          $nd =~ s/./[0-9]/g;
          $regex = $n2page . $nd . '$';
          if ( substr($page,7) ~~ qr/$regex/ ) {
            push(@regex_table, $regex);
          } else {
            push(@regex_table, $npage . '$');
          }
        } elsif ( $page ~~ /[0-9]+\.[a-zA-Z]{1,4}$/ ) {
          $npage =~ s/(.*[^0-9])([0-9])([0-9]*\\\.[a-zA-Z]+)/$1\[0-9\]$3/g;
          $npage =~ s/(.*[^0-9])([0-9])([0-9]*\\\.[a-zA-Z]+)/$1\[0-9\]$3/g;
          $npage =~ s/(.*[^0-9])([0-9])([0-9]*\\\.[a-zA-Z]+)/$1\[0-9\]$3/g;
          $npage =~ s/(.*[^0-9])([0-9])([0-9]*\\\.[a-zA-Z]+)/$1\[0-9\]$3/g;
          $npage =~ s/(.*[^0-9])([0-9])([0-9]*\\\.[a-zA-Z]+)/$1\[0-9\]$3/g;
          push(@regex_table, $npage . '$');
        } else {
          push(@regex_table, $npage . '$');
        }
      }
    }
    $sql = 'INSERT INTO pages_in_index (index_name,page_regex,base_name) VALUES ';
    foreach $regex (@regex_table) {
      if ( $sqlvalues ne '' ) {
        $sqlvalues = $sqlvalues . ',';
      }
      $name =~ s/'/\\'/g;
      if ( $regex ~~ qr:/: ) {
        $bname = $regex;
        $bname =~ s/\\//g;
        $bname =~ s:/.*::;
        $bname =~ s/^\^//;
        $bname =~ s/'/\\'/g;
	$bname = '\'' . $bname . '\'';
      } else {
        $bname = 'NULL';
      }
      $regex =~ s/\?/\\\?/g;
      $regex =~ s/\./\\\./g;
      $regex =~ s/\(/\\\(/g;
      $regex =~ s/\)/\\\)/g;
      $regex =~ s/\+/\\\+/g;
      $regex =~ s/'/\\\\'/g;
      $sqlvalues = $sqlvalues . '(\'' . substr($name,7) . '\',\'' . $regex
        . '\',' . $bname . ')';
    }
    $sql .= $sqlvalues;
    
#    print "$sql\n";
  }
  return $sql;
}
#========================================================================
sub set_regex_for_all {
  my $api = $_[0];
  my $sql = "DELETE FROM pages_in_index;\n";
  my $title = '';
  
  my $xml = $api->makeXMLrequest(
                  [ 'action' => 'query',
                    'list' => 'categorymembers',
                    'cmtitle' => 'Kategoria:Indeks',
                    'cmprop' => 'title',
                    'cmlimit' => 5000,
                    'continue' => '',
                    'format' => 'xml' ] );

  if ( ! defined $xml->{'query'}
       || ! defined $xml->{'query'}->{'categorymembers'} ) {
     $api->handleXMLerror($xml);
  }
#  print Dumper $xml->{'query'}->{'categorymembers'}->{'cm'};
  if ( defined $xml->{'query'}->{'categorymembers'}->{'cm'} ) {
    my $i = 0;
    while ( defined $xml->{'query'}->{'categorymembers'}->{'cm'}->[$i] ) {
#      print Dumper $xml->{'query'}->{'categorymembers'}->{'cm'}->[$i];
      Encode::_utf8_off( $title = $xml->{'query'}->{'categorymembers'}->{'cm'}->[$i]->{'title'} );
      $sql .= set_regex_for_index($api, $title) . ";\n";
      $i++;
    }
  }
#  print Dumper $xml->{'query'}->{'categorymembers'};
  print "$sql\n";
  return $sql;
}
#========================================================================
1;
