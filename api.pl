use Mojolicious::Lite;

use Mojo::Util qw(secure_compare);

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

# Required
app->start;

__DATA__

@@ index.html.ep

<pre>
Try: 

    $ curl -v -X GET    http://127.0.0.1:8080/v1/time
    $ curl -v -X POST   http://127.0.0.1:8080/v1/time

    All except the last should work.
</pre>

