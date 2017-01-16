use Mojolicious::Lite;
use Mojo::Util qw(secure_compare);

use lib "./lib";
use Gcode;

my $gobj = Gcode->new({});

# App instructions
get '/' => qw(index);

# Authentication
under(sub {
    my $c = shift;

    return 1;
});

helper replace => sub {
   my($self, $gcode) = @_;
   die "No parsable gcode found" unless $gcode;

   if(my $toolnumber = $gobj->parse($gcode)->{toolnumber}){
      #return $self->xatc($toolnumber);
   } else {
      return {error => "Can't parse this gcode: $gcode"};
   }
   return {};
};

# Anything works, a long as it's GET and POST
any ['GET', 'POST'] => '/v1/time' => sub {
    shift->render(json => { now => scalar(localtime) });
};

# Parse gcode line and get XATC Gcode as relpace
any ['GET', 'POST'] => '/xatc/replace/:gcode' => sub {
    my $self = shift;
    my $gcode = $self->stash('gcode') or die "No Gcode parameter";
    $self->render(json => { replace => $self->replace($gcode) });
};

# Required
app->start;

__DATA__

@@ index.html.ep

<pre>
Try: 

    $ curl -v -X GET    http://127.0.0.1:8080/v1/time
    $ curl -v -X POST   http://127.0.0.1:8080/v1/time

    $ curl -v -X GET    http://127.0.0.1:8080/xatc/replace/M5
    $ curl -v -X POST   http://127.0.0.1:8080/xatc/replace/M6 T6

    All except the last should work.
</pre>

