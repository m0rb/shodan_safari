#!/usr/bin/perl -C -w
use 5.36.0;
use strict;
use warnings;
use utf8;
use lib ".";

use Storable;
use Config::File      qw(read_config_file);
use MyLib::ATProto    qw(post_media);
use Image::Compare;
use Mastodon::Client;


START:

my $wd     = "/home/morb/shodan_safari/";
my $exe    = "/home/morb/shodan/bin/shodan";
my $file   = "shodan-latest.json.gz";
my $track  = "hosts.track";
my $imgdir = $wd . substr( $file, 0, -8 ) . "-images";
my $cfg    = read_config_file("config.cfg");
my $csv    = $wd . "shodan-latest.csv";
my ( @previous, @hosts, $msg );

my $mt = Mastodon::Client->new(
  instance        => $cfg->{masto}{instance},
  client_id       => $cfg->{masto}{ckey},
  client_secret   => $cfg->{masto}{csec},
  access_token    => $cfg->{masto}{at},
  coerce_entities => 0
);

my $cmp = Image::Compare->new();

_setup();

@previous = @{retrieve( $wd . $track )};

open (my $fh, "<", $csv);
while (<$fh>) {
  chomp;
  push @hosts, $_;
}
close $fh;

START:
my ( $ip, $port, $hostname, $city, $country, $asn, $isp, $timestamp, $id ) =
  split( /_-_-/, $hosts[ int( rand( scalar @hosts ) ) ] );

if ( grep( /$ip-$port/, @previous ) ) { goto START; }

my @prevbuf = grep(/$ip/, @previous );
my ($pass,$ok) = (0,0);
my $img = $imgdir."/$ip-$port\.jpg";

foreach my $compare (@prevbuf) {
  my $cmg = $imgdir."/".$compare."\.jpg";
  my $return = imgcompare($cmg,$img,300);
  if ($return && $return < 350) {
    $pass++;
  } else {
    $ok++;
  }
}

if (imgcrop($img)) {
  for(my $a=0;$a<4;$a++) {
      my $b=$a+1; ($b>3) ? $b=0 : undef;
    imgcompare("outbuf-$a.jpg","outbuf-$b.jpg",50) ? $ok++ : $pass++; 
  }
}

if ( $pass > $ok ) { push(@previous,$ip."-".$port) and goto START; }

if ( length $hostname >= 50 ) { $hostname = substr( $hostname,0,50 )."..."; }

($timestamp)          ? $timestamp = substr( $timestamp, 0, -10 ) : undef;
#($id)                 ? $msg .= "ID: $id\n"                   : undef;
#( $ip && $port )      ? $msg .= "IP: $ip:$port\n"             : undef;
#($hostname)           ? $msg .= "Hostname: $hostname\n"       : undef;
($asn)                ? $msg .= "ASN: $asn\n"                 : undef;
#($isp)                ? $msg .= "ISP: $isp\n"                 : undef;
( $city && $country ) ? $msg .= "Location: $city, $country\n" : undef;
($timestamp)          ? $msg .= "Added: $timestamp\n"         : undef;
$msg .= "\n#shodansafari #infosec";
utf8::decode($msg);

if ( -f $img ) {
  post_media( {account => "safari", text => $msg, fn => $img } );
  eval {
    my $mm = $mt->upload_media( $img );
    $mt->post_status( $msg, {media_ids => [ $mm->{'id'} ]} );
  };
}

push( @previous, $ip . "-" . $port );
store( \@previous, $wd . $track );

sub _setup {
  srand;
  unless ( -f $wd . $track ) { store( \@previous, $wd . $track ); }
  unless ( -f $wd . $file )  { die "No json bundle. Full stop.\n"; }
  unless ( -d $imgdir )      { `$exe convert $file images` or die; }
}

sub imgcrop {
  my @fileinfo = split(",\ ",`file @_`);
  chomp @fileinfo;
  my $res = $fileinfo[(scalar(@fileinfo) - 2)];
  my ($x,$y) = split("x",$res);
  ($x%2) ? $x-- : undef;
  ($y%2) ? $y-- : undef;
  unless($x%2||$y%2) {
  my $seg = ($x/2)."x".($y/2);
  `rm -f outbuf-?.jpg`;
  `convert @_ -crop $seg\! outbuf.jpg`;
  unless ( -f "outbuf-0.jpg" && -f "outbuf-3.jpg" ) {
    die "bork\n";
  }
  } else {
    return 0;
  }
}

sub imgcompare {
  my ($img1,$img2,$args) = @_;
  my $cmp = Image::Compare->new;
  $cmp->set_image1(img => $img1,type => 'jpeg');
  $cmp->set_image2(img => $img2,type => 'jpeg');
  $cmp->set_method(method => &Image::Compare::THRESHOLD_COUNT,args => $args);
  return $cmp->compare;
}
