#!/usr/bin/env perl

=head1 NAME

skyscape_web_demo -

This script will listen into a port for machines being built and ouput their details.

=head1 USAGE

 perl skyscape_web_demo.pl daemon -l http://*:8080 -i 0

=head1 DESCRIPTION

=cut

use utf8;
use Mojolicious::Lite;
use Mojo::JSON;

use DateTime;

# Disable client incativty
BEGIN {
    $ENV{"MOJO_INACTIVITY_TIMEOUT"} = 0;
};

my $json = Mojo::JSON->new;
my @host_rows = qw|vapp host role ip|;

# setup base route
get '/' => sub {
    my $self = shift;
    $self->render('index', rows => undef );
};

my $clients = {};

websocket '/echo' => sub {
    my $self = shift;

    app->log->debug(sprintf 'Client connected: %s', $self->tx);
    my $id = sprintf "%s", $self->tx;
    $clients->{$id} = $self->tx;

    $self->on(message => sub {
		  my ($self, $msg) = @_;

		  my $dt = DateTime->now( time_zone => 'Europe/London');

		  for (keys %$clients) {
		      $clients->{$_}->send({json => {
			  hms  => $dt->hms,
			  text => $msg,
		      }});
		  }
	      });


    $self->on(finish => sub {
        app->log->debug('Client disconnected');
        delete $clients->{$id};
    });
};

# Receives requests from boxes just built...
post '/server' => sub {
    my $self = shift;

    # Post server is alive message to all the clients.
    for (keys %$clients) {
	my $ws = $clients->{$_};
	my $rows = [ map { $self->param($_) } @host_rows ];

	# Add the datetime to the hosts data.
	my $dt = DateTime->now( time_zone => 'Europe/London');
	unshift @{$rows},$dt->hms;
	$DB::single=1;
	my $html = $self->render_to_string( template => 'table', rows => [ $rows ], partial => 1 );
	$ws->send($json->encode({row => $html}));
    }

    $DB::single=1;
    app->log->debug(sprintf 'DBG: host %s', $self->param('host'));
    app->log->debug(sprintf 'DBG: POST: %s', $self->tx);

    $self->res->headers->content_type('text/plain');
    $self->res->body('Data received!');
    $self->rendered(200);
};


app->start;

__DATA__
@@ index.html.ep
<html>
  <head>
    <title>DevOpsGuys Skyscape Demo</title>
    <script
      type="text/javascript"
      src="http://ajax.googleapis.com/ajax/libs/jquery/1.4.2/jquery.min.js"></script>
     <script type="text/javascript" >
$(function () {

  $(document).ready(function() {
   $('#data').hide();
  });


  $('#msg').focus();

  var log = function (text) {
    $('#log').val( $('#log').val() + text + "\n");
    $('#log').scrollTop($('#log')[0].scrollHeight);
    console.log(text);
};

  var ws = new WebSocket("<%= url_for('echo')->to_abs %>");
  ws.onopen = function () {
    log('Connection opened');
  };

  ws.onmessage = function (evt) {
    $('#data').show();
    $('#nodata').hide();

    var data = JSON.parse(evt.data);
    $('#table').append(data.row);
    log('DBG: Data received ... row:[' + data.row + '] ');

  };

$('#msg').keydown(function (e) {
    if (e.keyCode == 13 && $('#msg').val()) {
        ws.send($('#msg').val());
        $('#msg').val('');
    }
  });
});

     </script>
    <style type="text/css">
      textarea {
          width: 40em;
          height:10em;
      }
    </style>
  </head>
<body>

<h1>Skyscape Demo</h1>
<div id="nodata">
Waiting for hosts that are building automatically. No data yet ...
</div>
<div id="data">
  Data: <br>
<table border="1">
  <thead>
    <tr>
      <th>Time</th>
      <th>vApp</th>
      <th>Hostname</th>
      <th>Role</th>
      <th>IP</th>
    </tr>
  </thead>
  <tbody id="table">
    %= include 'table'
  </tbody>
</table>
</div>
<br />
Log:
<br />
<textarea id="log" readonly style="width: 522px; height: 347px;"></textarea>
</body>
</html>

@@ table.html.ep
% foreach my $row (@$rows) {
  <tr>
    % foreach my $text (@$row) {
      <td><%= $text %></td>
    % }
  </tr>
% }
