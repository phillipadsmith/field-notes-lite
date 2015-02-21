#!/usr/bin/env perl

use FindBin;
use lib 'local/lib/perl5';
use Data::Dumper;
use Mojolicious::Lite;
use Mojo::JSON qw(decode_json encode_json);
use Mojolicious::Sessions;
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

    # Figure out the field name
    my $field = $message;

    # Set a cookie for the conversation
    if ( !$c->session->{'field'} ) { # Don't have a field yet
        $c->session({ field => $field }); # Story one in a session
    }
    app->log->info( $c->session->{'field'} );

    # Should get CREATED in the ->{'message'}
    my $response = $twilio->POST('SMS/Messages.json',
                          From => $config->{'twilio_num'},
                          To   => $from,
                          Body => "Your field is $c->session->{'field'}" );

    $c->render( text => "Received: $message, replied and got: $response->{'message'}", status => 200 );
};

app->start;
__DATA__
