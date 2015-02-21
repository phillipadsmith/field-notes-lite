#!/usr/bin/env perl

use FindBin;
use lib 'local/lib/perl5';
use Data::Dumper;
use Mojolicious::Lite;
use WWW::Twilio::API;
use WWW::Twilio::TwiML;

# Get the configuration
my $config = plugin 'JSONConfig';
app->secrets( [ $config->{'app_secret'} ] );

my $twilio = WWW::Twilio::API->new(
AccountSid => $config->{'twilio_sid'},
AuthToken  => $config->{'twilio_token'}
);

app->log->info( Dumper( $twilio ) );

# Get a UserAgent
my $ua = Mojo::UserAgent->new;

post '/' => sub {
    my $c = shift;
    my $message  = $c->param('Body');
    my $from  = $c->param('From');
    app->log->info( "Got from Twilio: $message" );
    app->log->info( "From: $from" );
    app->log->info( Dumper( $c->req ) );
    my $response = $twilio->POST('SMS/Messages',
                          From => $config->{'twilio_num'},
                          To   => $from,
                          Body => "Hey, let's have lunch" );
    $c->render( text => "$message, $response", status => 200 );
};

app->start;
__DATA__
