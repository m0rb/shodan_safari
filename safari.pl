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

my $wd     = "/home/morb/shodan_safari/";
my $file   = "shodan-latest.json.gz";
my $track  = "hosts.track";
my $imgdir = $wd . substr( $file, 0, -8 ) . "-images/";
my $cfg    = read_config_file("config.cfg");
my $csv    = $wd . "shodan-latest.csv";
my ( @previous, @hosts, $msg, $pass, $ok );

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
foreach my $compare (@prevbuf) {
  $cmp->set_image1( img => $imgdir . $compare."\.jpg", type => "jpeg" );
  $cmp->set_image2( img => $imgdir . "$ip-$port\.jpg", type => "jpeg" );
  $cmp->set_method( method => &Image::Compare::THRESHOLD_COUNT, arg => 300 );
  my $return = $cmp->compare;
  if ($return && $return < 350) {
    $pass++;
  } else {
    $ok++;
  }
}

if ($pass > $ok) { push(@previous,$ip."-".$port) and goto START; }

if ( length $hostname >= 50 ) { $hostname = substr( $hostname,0,50 )."..."; }

($timestamp)          ? $timestamp = substr( $timestamp, 0, -10 ) : undef;
($id)                 ? $msg .= "ID: $id\n"                   : undef;
( $ip && $port )      ? $msg .= "IP: $ip:$port\n"             : undef;
($hostname)           ? $msg .= "Hostname: $hostname\n"       : undef;
($asn)                ? $msg .= "ASN: $asn\n"                 : undef;
($isp)                ? $msg .= "ISP: $isp\n"                 : undef;
( $city && $country ) ? $msg .= "Location: $city, $country\n" : undef;
($timestamp)          ? $msg .= "Added: $timestamp\n"         : undef;
$msg .= "\n#shodansafari #infosec";
utf8::decode($msg);

if ( -f $imgdir . "$ip-$port\.jpg" ) {
  post_media( {account => "safari", text => $msg, fn => $imgdir . "$ip-$port\.jpg"} );
  eval {
    my $mm = $mt->upload_media( $imgdir . "$ip-$port\.jpg" );
    $mt->post_status( $msg, {media_ids => [ $mm->{'id'} ]} );
  };
}

push( @previous, $ip . "-" . $port );
store( \@previous, $wd . $track );

sub _setup {
  srand;
  unless ( -f $wd . $track ) { store( \@previous, $wd . $track ); }
  unless ( -d $imgdir || -f $csv ) { `./update.sh` }
}
