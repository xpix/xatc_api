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

sub new{
   my( $class, $params ) = @_;
   my $self = $params;
   bless $self, $class;
   
   $self->{wcs} //= 53;
   $self->{flavor} //= 'tinyg';
   
   return $self;
}

sub G { my ($self, $numeric) = @_; return sprintf('G%02d ', $numeric) } # G01, G04 G00
sub M { my ($self, $numeric) = @_; return sprintf('M%02d ', $numeric)  } # M3, M119
sub X { my ($self, $numeric) = @_; return (defined $numeric ? sprintf('X%.4f ', $numeric) : '') } # X0.1234
sub Y { my ($self, $numeric) = @_; return (defined $numeric ? sprintf('Y%.4f ', $numeric) : '') } # Y0.1234
sub Z { my ($self, $numeric) = @_; return (defined $numeric ? sprintf('Z%.4f ', $numeric) : '') } # Z0.1234
sub A { my ($self, $numeric) = @_; return (defined $numeric ? sprintf('A%.4f ', $numeric) : '') } # A0.1234
sub P { my ($self, $numeric) = @_; return sprintf('P%.4f ', $numeric) } # P0.1234
sub S { my ($self, $numeric) = @_; return sprintf('S%d ', $numeric) } # S12000

sub fast {
   my ($self, $x, $y, $z) = @_;
   return $self->G(0) 
      . $self->X($x) 
      . $self->Y($y) 
      . $self->Z($z);
}

sub move {
   my ($self, $x, $y, $z) = @_;
   return 
      $self->G(1) 
      . $self->X($x) 
      . $self->Y($y) 
      . $self->Z($z);
}

sub dwell {
   my ($self, $numeric) = @_;
   return $self->G(4) . $self->P($numeric);
}

sub forward {
   my ($self, $numeric) = @_;
   return $self->M(3) . $self->S($numeric);
}

sub backward {
   my ($self, $numeric) = @_;
   return $self->M(4) . $self->S($numeric);
}

sub break {
   my ($self) = @_;
   return $self->M(5);
}

sub jitter {
   my ($self, $rpm, $time) = @_;
   return 
      $self->forward($rpm),
      $self->dwell($time),
      $self->backward($rpm),
      $self->dwell($time);
}



1;