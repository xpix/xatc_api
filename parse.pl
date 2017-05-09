#!/usr/bin/env perl
use warnings;
use strict;

use LWP::Simple;

my $starturl = "http://xpix.eu:8080/xatc/replace";
my $version="xatcv4";
my $flavour="tinyg";
my $touch=0;
my $oldtoolnr = 0;

my $url = 
   sprintf('%s/%s/%s',
      $starturl, $version, $flavour      
   );

my $gcode_file = shift or die "Plaese call $0 gcode_file";
my $gcode = `cat $gcode_file` or die "Unable to open this file: $gcode_file";
my @rows = split(/\n/, $gcode);

my $c=0;
foreach my $row (@rows){
   if($row =~ /M[0]*6/){
      $rows[$c] = getToolChange($row);
   }
   $c++;
}

print join("\n", @rows)."\n";

exit;

sub getToolChange {
   my($row) = @_;
   my ($tool) = $row =~ /T(\d+)/;
   $tool = int($tool) or die "Can't find a toolnumber in format T[NR]";
   $row =~ s/[\r|\n]//sig;

   # construct url
   my $request = sprintf('%s/%s/%d?text=1&touch=%d&time=%d', $url, $row, $oldtoolnr, $touch, time);
   my $xatc_gcode = "($request)\n" . get($request) . "\n";

   $oldtoolnr = $tool;
   return $xatc_gcode;
}
