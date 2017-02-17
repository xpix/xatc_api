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
use Data::Dumper;

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

sub G { my ($self, $numeric) = @_; return ($numeric =~ /\./ ? sprintf('G%02.1f ', $numeric) : sprintf('G%02d ', $numeric)) } # G01, G04, G92.1
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
      . $self->Z($z)
      . $self->F($feed);
}

sub dwell {
   my ($self, $numeric) = @_;
   return $self->G(4) . $self->P($numeric);
}

sub forward {
   my ($self, $numeric, $time) = @_;
   my $sp = $self->cfg->{control}{Spindle};
   my @ret = ( $self->M($sp->{cw}) . $self->S($numeric) );
   if(defined $time){
      push(@ret, $self->break($time));
   }
   return @ret;
}

sub backward {
   my ($self, $numeric, $time) = @_;
   my $sp = $self->cfg->{control}{Spindle};
   my @ret = ( $self->M($sp->{ccw}) . $self->S($numeric) );
   if(defined $time){
      push(@ret, $self->break($time));
   }
   return @ret;
}

sub break {
   my ($self, $time) = @_;
   my $sp = $self->cfg->{control}{Spindle};
   my @ret = ();
   if(defined $time){
      push(@ret, $self->dwell($time));
   }
   push(@ret, $self->M($sp->{brk}));
   return @ret;
}

sub jitter {
   my ($self, $rpm, $time) = @_;
   return 
      $self->forward(   $rpm, $time*0.001 ),
      $self->backward(  $rpm, $time*0.001 );
}

sub servo {
   my ($self, $status) = @_;
   my $sv = $self->cfg->{control}{Servo};
   if(defined $status){
      return $self->M($sv->{block}); # 
   }
   return $self->M($sv->{unblock}); # 
}

sub block {
   my ($self, $rpm, $pause) = @_;
   my $jit = $self->cfg->{atcParameters}{jitter};
   return 
      $self->comment('block spindle --'),
      $self->forward($rpm),              # spindle slow rotate
      $self->dwell($pause),
      $self->servo('block'),               # block with servo
      $self->dwell($pause),
      $self->jitter($jit->{speed}, $jit->{time}),
      $self->comment('----------------'),
      ;  # jitter for accurate block
                     
}

sub unblock {
   my ($self, $rpm, $pause) = @_;
   my $jit = $self->cfg->{atcParameters}{jitter};
   return 
      $self->comment('UN-block spindle --'),
      $self->servo(),               # unblock with servo
      $self->dwell($pause),
      $self->jitter($jit->{speed}, $jit->{time}),  # jitter for accurate unblock
      $self->comment('----------------');
}

sub wcs {
   my ($self, $wcs) = @_;
   return $self->G($wcs || $self->{wcs}); 
}

sub comment {
   my ($self, $message) = @_;
   return sprintf('( %s ) ', $message);
}

sub cfg {
   my ($self, $cfg) = @_;
   $self->{cfg} = $cfg if defined $cfg;
   $self->{cfg} or die "Unable to find configuration";
   return $self->{cfg};
}

sub config {
   my ($self, $model, $control) = @_;
   my $control_cfg = $self->load($control) 
      if($control);
   my $config = $self->model($model);
   $config->{control} = $control_cfg 
      if(ref $control_cfg);
   $self->cfg($config);
   return $config;
}

sub model {
   my ($self, $model) = @_;
   return $self->load($model);
}

sub load {
   my ($self, $filename) = @_;
   my %config;
   my $BIN = $self->{bin};
   open (FILE, "< $BIN/data/${filename}.cfg") or die "$!";
   undef $/;                        # read in file all at once
   eval <FILE>;                     # recreate $config
   die "can't recreate data from $filename: $@" if $@;
   close FILE or die "can't close : $!";
   return \%config;
};

sub save {
   my ($self, $filename, $config) = @_;
   my $BIN = $self->{bin};
   open (FILE, "> $BIN/data/$filename") or die "$!";
   print FILE Data::Dumper->Dump([$config], ['*config']);
   close FILE or die "$!";   
};


1;