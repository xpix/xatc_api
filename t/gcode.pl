#!/usr/bin/env perl

use Gcode;
use DDP;

my $g = Gcode->new({
   flavor => 'tinyg', # cnc controller
   wcs    => 59,      # work coordinaten system
});

my $gcodetext = [
   $g->fast(0, 53.5, 42),  # G0 X0 Y53.5 Z42
   $g->move(undef,undef,15),         # G1 Z15
   $g->forward(12000),     # M3 S12000
   $g->dwell(0.4),         # G4 P0.4
   $g->backward(12000),    # M4 S12000
   $g->dwell(0.4),         # G4 P0.4
];

p $gcodetext;

# or replace last with jitter

$gcodetext = [
   $g->fast(0, 53.5, 42),  # G0 X0 Y53.5 Z42
   $g->move(undef,undef,15),         # G1 Z15
   $g->jitter(12000, 0.1), # Jitter: rotate spindle forward for 0.1 sec and backword for 0.1 sec
];

p $gcodetext;

my $r = $g->parse( $g->dwell(0.4) ); p $r;
   
exit;   