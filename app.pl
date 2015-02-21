#!/usr/bin/env perl

use FindBin;
use lib 'local/lib/perl5';
use Data::Dumper;
use Mojolicious::Lite;

# Get the configuration
my $config = plugin 'JSONConfig';
app->secrets( [ $config->{'app_secret'} ] );

# Get a UserAgent
my $ua = Mojo::UserAgent->new;

any '/' => sub {
    my $c = shift;
    my $message  = $c->param('Body');
    #my $SmsMessageSid = $c->param('SmsMessageSid');
    app->log->info( "Got from Twilio: $message" );
    #$c->render(text => Dumper( $c->req ));
    $c->render( text => "$message", status => 200 );
};

app->start;
__DATA__

@@ index.html.ep
% layout 'default';
% title 'Welcome';
Welcome to the Mojolicious real-time web framework!
<

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head><title><%= title %></title></head>
  <body><%= content %></body>
</html>
