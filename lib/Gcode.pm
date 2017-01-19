#$Id$

=pod

=head1 Gcode - Produce Gcode via OO Interface

This module can be used to get and set gcode lines.

=head1 Description

This Class is used as the API for getting, setting and proving gcode lines

=head1 Synopsis

   use Gcode;
   my $g = Gcode->new({
      flavor => 'tinyg', # cnc controller
      wcs    => 59,      # work coordinaten system
   })
   my $gcodetext = [
      $g->fast(0, 53.5, 42),  # G0 X0 Y53.5 Z42
      $g->Move(,,15),         # G1 Z15
      $g->forward(12000),     # M3 S12000
      %g->dwell(0.4),         # G4 P0.4
      $g->backward(12000),    # M4 S12000
      %g->dwell(0.4),         # G4 P0.4
   ];
   
   # or replace last with jitter

   my $gcodetext = [
      $g->fast(0, 53.5, 42),  # G0 X0 Y53.5 Z42
      $g->Move(,,15),         # G1 Z15
      $g->jitter(12000, 0.1), # Jitter: rotate spindle forward for 0.1 sec and backword for 0.1 sec
   ];
   
=head1 Methods

=cut

package Gcode;
use strict;
use warnings;
use DDP;

my $TRUE = 1;

sub new{
   my( $class, $params ) = @_;
   my $self = $params;
   bless $self, $class;
   
   $self->{wcs} //= 59;
   $self->{flavor} //= 'tinyg';
   
   return $self;
}

sub parse{
   my($self, $gcode) = @_;
   die "No parsable gcode found" unless $gcode;
   
   my $result = {gcode => $gcode};

   if($gcode =~ /T(\d+)/){ $result->{toolnumber}         = $1 }
   if($gcode =~ /M.*?6/){  $result->{toolchange}         = $TRUE }
   if($gcode =~ /G[0]+0/){ $result->{fastmove}           = $TRUE }
   if($gcode =~ /G.*?1/){  $result->{feedmove}           = $TRUE }
   if($gcode =~ /G.*?4/){  $result->{pause}              = $TRUE }
   if($gcode =~ /M.*?3/){  $result->{spindle_forward}    = $TRUE }
   if($gcode =~ /M.*?4/){  $result->{spindle_backward}   = $TRUE }
   if($gcode =~ /M.*?5/){  $result->{spindle_break}      = $TRUE }

   return $result;
}

sub G { my ($self, $numeric) = @_; return sprintf('G%02d ', $numeric) } # G01, G04 G00
sub M { my ($self, $numeric) = @_; return sprintf('M%02d ', $numeric)  } # M3, M119
sub X { my ($self, $numeric) = @_; return (defined $numeric ? sprintf('X%.3f ', $numeric) : '') } # X0.1234
sub Y { my ($self, $numeric) = @_; return (defined $numeric ? sprintf('Y%.3f ', $numeric) : '') } # Y0.1234
sub Z { my ($self, $numeric) = @_; return (defined $numeric ? sprintf('Z%.3f ', $numeric) : '') } # Z0.1234
sub A { my ($self, $numeric) = @_; return (defined $numeric ? sprintf('A%.3f ', $numeric) : '') } # A0.1234
sub R { my ($self, $numeric) = @_; return (defined $numeric ? sprintf('R%.2f ', $numeric) : '') } # R0.12
sub F { my ($self, $numeric) = @_; return (defined $numeric ? sprintf('F%d ',   $numeric) : '') } # F500
sub P { my ($self, $numeric) = @_; return sprintf('P%.3f ', $numeric) } # P0.1234
sub S { my ($self, $numeric) = @_; return sprintf('S%d ', $numeric) } # S12000

sub fast {
   my ($self, $x, $y, $z) = @_;
   return $self->G(0) 
      . $self->X($x) 
      . $self->Y($y) 
      . $self->Z($z);
}

sub move {
   my ($self, $x, $y, $z, $feed) = @_;
   return 
      $self->G(1) 
      . $self->X($x) 
      . $self->Y($y) 
      . $self->Z($z),
      . $self->F($feed);
}

sub dwell {
   my ($self, $numeric) = @_;
   return $self->G(4) . $self->P($numeric);
}

sub forward {
   my ($self, $numeric, $time) = @_;
   my @ret = ( $self->M(3) . $self->S($numeric) );
   if(defined $time){
      push(@ret, $self->break($time));
   }
   return @ret;
}

sub backward {
   my ($self, $numeric, $time) = @_;
   my @ret = ( $self->M(4) . $self->S($numeric) );
   if(defined $time){
      push(@ret, $self->break($time));
   }
   return @ret;
}

sub break {
   my ($self, $time) = @_;
   my @ret = ();
   if(defined $time){
      push(@ret, $self->dwell($time));
   }
   push(@ret, $self->M(5));
   return @ret;
}

sub jitter {
   my ($self, $rpm, $time) = @_;
   return 
      $self->comment("    jitter with ${rpm}rpm and timeout: ${time}sec"),
      $self->forward(   $rpm, $time*0.001 ),
      $self->backward(  $rpm, $time*0.001 ),
}

sub servo {
   my ($self, $angle) = @_;
   return $self->G(1) . $self->A($angle); # TODO: recalculate angle? 
}

sub wcs {
   my ($self, $wcs) = @_;
   return $self->G($wcs || $self->{wcs}); 
}

sub comment {
   my ($self, $message) = @_;
   return sprintf('( %s ) ', $message);
}

sub config {
   my ($self, $model) = @_;
   return $self->model($model);
}

sub model {
   my ($self, $model) = @_;

   my $models = {
     'xatcv2' => {
         wcs    => 59,
         holder => [
            # Data for XATC 0.2 without(!) Gator Grips 
            # Center Position holder, catch height, tighten val, tighten ms,    deg
            # ---------------|----------------|----------|-------------------|------------|------
            {posX =>   53.50,  posY =>  0,     posZ => 5,   tourque => 12000, time => 500, deg=> 360},  # 1. endmill holder
            {posX =>       0,  posY => -53.50, posZ => 5,   tourque => 12000, time => 500, deg=> 270},  # 2, endmill holder
            {posX =>  -53.50,  posY =>  0,     posZ => 5,   tourque => 12000, time => 500, deg=> 180},  # 3. endmill holder
            {posX =>       0,  posY =>  53.50, posZ => 5,   tourque => 12000, time => 500, deg=> 90},   # 4. endmill holder
         ],
         atcParameters => {
            slow =>        1000,   # value for minimum rpm
            fast =>       12000,   # value for maximum rpm
            safetyHeight =>  40,   # safety height
            feedRate =>      300,  # Feedrate to move to screw position
            nutZ =>          -5,   # safety deep position of collet in nut
            loose =>{               
               speed => 200,       # after unscrew the collet,  params to rotate the spindle shaft with X speed ... 
               time =>   50,       # ... for X time (in milliseconds) to loose the collet complete
            },
            jitter =>{
               z =>       -4,      # Position to start jitter
               speed =>  200,      # Power to jitter (means rotate X ms in every direction)
               time =>   15,       # time in ms to jitter on every direction
            },
         },
         carousel =>{
            enabled => $TRUE,
            center => { r => 53.50 },
            servo => { 
               # please test with ./blocktest.js to find perfect parameters
               block =>   125,   # arc in degress to block the spindle shaft 
               unblock => 60,    # arc in degress to deblock the spindle shaft 
               touch =>   100,   # arc in degress to touch the spindle shaft for touch probe
               level =>   2500,  # level in mA to break spindle at ~2.5 Ampere
            }, # position values are in degress
            catchDegrees =>  15, # in screw mode => degrees for opposite direction to catch the collet
                                 # 0 means no opposite move
            torqueDegrees => 50, # IMPORTANT => maximum arc degrees to torque collet 
                                 # This value set the maximum torque on  ER-collet-nut, too high 
                                 # values can result in loose steps of motors or destroy your machine
         },
         touchprobe =>{
            position => {x =>5, y =>-5},
            enabled => $TRUE,
            servo => 130,       # Angel to connect Spindle shaft for sure!
            feedrate => 150,    # Feedrate for touch probe
            thick => 0.035,     # thick of probe (copper tape or other)
            secure_height => 2, # move to this z-height after probing
         },
     } 
   };
   
   return $models->{$model};
}


1;