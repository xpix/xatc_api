use Mojolicious::Lite;
use Mojo::Util qw(secure_compare);

use lib "./lib";
use Gcode;

use constant PI    => 4 * atan2(1, 1);

my $gobj = Gcode->new({});

# App instructions
get '/' => qw(index);

# Authentication
under(sub {
    my $c = shift;

    return 1;
});

# Anything works, a long as it's GET and POST
any ['GET', 'POST'] => '/v1/time' => sub {
    shift->render(json => { now => scalar(localtime) });
};

# Parse gcode line and get XATC Gcode as relpace
any ['GET', 'POST'] => '/xatc/replace/:gcode/:oldtool' => sub {
    my $self = shift;
    my $gcode = $self->stash('gcode') or die "No Gcode parameter";
    my $oldtool = $self->stash('oldtool') || 0;
    $self->render(json => { replace => $self->replace($gcode, $oldtool) });
};

helper replace => sub {
   my($self, $gcode, $oldtool) = @_;
   $self->error("No parsable gcode found") unless $gcode;

   if(my $toolnumber = $gobj->parse($gcode)->{toolnumber}){
      my $list = $self->xatc($toolnumber, $oldtool);
      map { $_ =~ s/\s+$//sig } @$list;
      return $list;
   } else {
      return $self->error("Can't parse this gcode: $gcode");
   }
   return {};
};

helper xatc => sub {
   my($self, $toolnumber, $oldtoolnumber) = @_;
   $self->error("No toolnumber found") unless $toolnumber;
   $self->{cfg} = my $cfg = $gobj->model('xatcv2');
   my $srv = $cfg->{carousel}->{servo};

   my $gcode = [ 
      $gobj->servo($srv->{unblock}),
      $gobj->wcs(),
      $gobj->G(17),
      $gobj->comment("XATC Moves to get Endmill nr $toolnumber"),
   ];

   if($oldtoolnumber and $toolnumber != $oldtoolnumber){
      push( @$gcode, @{$self->putoldTool($cfg, $oldtoolnumber)} );
   } elsif($toolnumber) {
      push( @$gcode, @{$self->getnewTool($cfg, $toolnumber)} ); 
   }
      
   return $gcode;

};

helper getnewTool => sub {
   my($self, $cfg, $toolnumber) = @_;
};

helper putoldTool => sub {
   my($self, $cfg, $toolnumber) = @_;

   my $atc  = $cfg->{atcParameters};
   my $slot = $cfg->{holder}->[ $toolnumber-1 ];
   my $jit  = $atc->{jitter};
   my $los  = $atc->{loose};
   my $car  = $cfg->{carousel};
   my $srv  = $car->{servo};

   my $theta1   = $slot->{deg};
   my $theta2   = $slot->{deg} + $car->{torqueDegrees};
   my $theta1_back   = $slot->{deg} - $car->{torqueDegrees};
   my $theta2_back   = $slot->{deg};

   my $gcode = [
      $gobj->comment("Put old tool back to slot $toolnumber"),
      
      $gobj->comment(" Move to slot position and run spindle slow"),
      $gobj->forward( $atc->{slow} ),
      $gobj->fast( undef, undef, $atc->{safetyHeight} ),
      $gobj->fast( $slot->{posX}, $slot->{posY} ),

      # Block spindle process
      $gobj->forward( $atc->{slow} ),              # spindle slow rotate
      $gobj->servo($srv->{block}),                 # block with servo
      $gobj->jitter($jit->{speed}, $jit->{time}),  # jitter for accurate block

      # Move to -2.1 and call jitter to catch the frame AFTER block spindle
      $gobj->move( undef, undef, $jit->{z}, 750 ),
      $gobj->jitter($jit->{speed}, $jit->{time}),

      # // move to nutZ+x
      $gobj->move( undef, undef, $atc->{nutZ}+0.2, 750 ),
      $gobj->forward( $atc->{slow} ),
      $self->arc(2, $theta1, $theta2, $slot),

      # deblock spindle at end of arc move
      $gobj->servo($srv->{unblock}),
      $gobj->break(),
      $self->arc(3, $theta1_back, $theta2_back, $slot),

      $gobj->comment("-------------- END put tool back"),
   ];
  
   return $gcode;
};

helper arc => sub {
   my($self, $mode, $th1, $th2, $slot) = @_;

   my $car  = $self->{cfg}->{carousel}{center};
$self->Dumper($self->{cfg}{carousel});
   my $radius = $car->{r};

   my $theta1 = $th1*(PI/180); # calculate in radians
   my $theta2 = $th2*(PI/180); # calculate in radians

   my $xc = 0; 
   my $yc = 0;

   # calculate the arc move, from center of carousel
   # http://www.instructables.com/id/How-to-program-arcs-and-linear-movement-in-G-Code-/?ALLSTEPS
   my $xe   = ($xc+( $radius * cos($theta2) ));   # Xc+(R*cos(Theta2))
   my $ye   = ($yc+( $radius * sin($theta2) ));   # Yc+(R*sin(Theta2))

   $self->{darc} = {XEnd => $xe, YEnd => $ye};

   return $gobj->G($mode). $gobj->X($xe). $gobj->Y($ye). $gobj->R($radius);

};

helper error => sub {
   my($self, $error) = @_;
    return {error => $error};
};

helper Dumper => sub {
   my($self, $var) = @_;
   use Data::Dumper;
   warn Dumper($var);
};

# Required
app->start;

__DATA__

@@ index.html.ep

<pre>
Try: 

    $ curl -v -X GET    http://xpix.eu:8080/xatc/replace/M6%20T6/4
    $ curl -v -X POST   http://xpix.eu:8080/xatc/replace/M6 T6/3

    All except the last should work.
</pre>

