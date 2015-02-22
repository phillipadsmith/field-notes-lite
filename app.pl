#!/usr/bin/env perl

use FindBin;
use lib 'local/lib/perl5';
use Data::Dumper;
use Mojolicious::Lite;
use Mojo::JSON qw(decode_json encode_json);
use Mojolicious::Sessions;
use WWW::Twilio::API;
use WWW::Twilio::TwiML;
use Text::CSV;
use IO::All;

# Get the configuration
my $config = plugin 'JSONConfig';
app->secrets( [ $config->{'app_secret'} ] );

my $twilio = WWW::Twilio::API->new(
    AccountSid => $config->{'twilio_sid'},
    AuthToken  => $config->{'twilio_token'}
);

my $forecast_api = 'https://api.forecast.io/forecast/';
my $forecast_key = $config->{'forecast_key'};

my $cartodb_key = $config->{'cartodb_key'};

# Get a UserAgent
my $ua = Mojo::UserAgent->new;
$ua->max_redirects( 5 );

my $google    = 'https://docs.google.com/spreadsheets/d/';
my $google_id = '172HoOQDKJaIMr930fugUK4GkxkzxR3mV3C3zJ0ruGeY';
my $sheets    = {
    fields => '0',
    parks  => '227162659',
    quotes => '490907553',
    gifs   => '490907553'
};

my $data_fields = load_csv_data( 'fields' );
my $data_parks  = load_csv_data( 'parks' );
my $data_quotes = load_csv_data( 'quotes' );
my $data_gifs   = load_csv_data( 'gifs' );

sub load_csv_data {
    my $sheet = shift;
    my $gid   = $sheets->{$sheet};
    my $string
        = $ua->get( $google
            . $google_id
            . '/export?format=csv&id='
            . $google_id . '&gid='
            . $gid => { DNT => 1 } )->res->body;
    my $file = "tmp/$sheet.csv";
    $string > io( $file );
    my $csv = Text::CSV->new( { binary => 1 } ) # should set binary attribute.
        or die "Cannot use CSV: " . Text::CSV->error_diag();
    open my $fh, "<:encoding(utf8)", $file or die "$file $!";
    $csv->column_names( $csv->getline( $fh ) );
    my $hashref = $csv->getline_hr_all( $fh );
    $csv->eof or $csv->error_diag();
    close $fh;
    return $hashref;
}

# What commands to we respond to?
# - 'weather' (Forecast.io)
# - 'coffee' -> Hugh's data
# - 'hospital' -> Hugh's data
# - 'zen' -> Quote table
# - ':)' -> GIF
# - delete location
my @commands = qw/ weather coffee hospital zen :) delete /;

helper check_location => sub {    # Returns true/false
    app->log->info( "check_location" );
    my $c = shift;
    if ( $c->session->{'location'} )
    {    # Do we already have a field for this person?
        return $c->session->{'location'};
    }
    else {
        return undef;
    }
};

helper check_command => sub {    # Returns true/false
    app->log->info( "check_command" );
    my $c       = shift;
    my $from    = shift;
    my $message = shift;
    my ( $matched ) = grep $_ eq $message, @commands;
    if ( $matched ) {
        return $matched;
    }
    else {
        return undef;
    }
};

helper ask_command => sub {    # Replies
    app->log->info( "ask_command" );
    my $c       = shift;
    my $from    = shift;
    my $message = shift;
    my $reply
        = "I don't understand the command '$message'. Some clarification text TK here";
    $c->send_reply( $from, $reply );

};

# Helper: Ask for the field or park name
helper ask_location => sub {    # $c, $from, $message
    app->log->info( "ask_location" );
    my $c       = shift;
    my $from    = shift;
    my $message = shift;
    my $reply
        = "We don't appear to have enough information. Please reply with a park or feild name!";
    $c->send_reply( $from, $reply );
};

helper weather => sub {         # $c, $from, $message, $lat, $long
    app->log->info( "weather" );
    my $c         = shift;
    my $from      = shift;
    my $message   = shift;
    my $lat       = $c->session->{'lat'};
    my $long      = $c->session->{'long'};
    my $park_name = $c->session->{'park_name'};
    my $response
        = $ua->get( $forecast_api . $forecast_key . '/' . $lat . ',' . $long )
        ->res->json;
    my $minutely_summary = $response->{'minutely'}->{'summary'};
    my $reply            = "The forecast is $minutely_summary at $park_name";
    $c->send_reply( $from, $reply );
};

helper coffee => sub {    # $c, $from, $message, $lat, $long
    app->log->info( "coffee" );
    my $c         = shift;
    my $from      = shift;
    my $message   = shift;
    my $lat       = $c->session->{'lat'};
    my $long      = $c->session->{'long'};
    my $park_name = $c->session->{'park_name'};
    my $geo_str   = $long . '%20' . $lat;
    my $api_get
        = "https://geocology.cartodb.com/api/v2/sql?q=SELECT%20fieldnotes_cafes.name%20as%20name%2C%20st_astext(the_geom)%20as%20latlng%2C%20st_distance(fieldnotes_cafes.the_geom%3A%3Ageography%2C%20%27SRID%3D4326%3BPOINT($geo_str)%27%3A%3Ageography)%2F1000%20as%20kilometers%20FROM%20fieldnotes_cafes%20WHERE%20fieldnotes_cafes.the_geom%20%26%26%20ST_Expand(%27SRID%3D4326%3BPOINT($geo_str)%27%3A%3Ageometry%2C%201)%20ORDER%20BY%20ST_Distance(fieldnotes_cafes.the_geom%2C%20%27SRID%3D4326%3BPOINT($geo_str)%27%3A%3Ageometry)%20ASC%20LIMIT%202&api_key=$cartodb_key";
    say $api_get;
    my $response = $ua->get( $api_get )->res->json;
    app->log->info( Dumper( $response ) );
    my $rows = $response->{'rows'};
    my $reply;
    if ( $rows ) {
        if ( @$rows == 1 ) {
            $reply = "The closest coffee option is: $rows->[0]->{'name'}";
        } elsif ( @$rows >= 2 ) {
            $reply = "The closest coffee options are:\n";
            for my $row ( @$rows ) {
                next unless $row->{'name'};
                my $km = $row->{'kilometer'};
                $km = printf("%.3f", $km);
                $reply .= "$row->{'name'} ($km km away)\n";
            }
        } else {
            $reply = "Couldn't find any coffee shops! :( Good luck!";
        }
    } else {
        $reply = "Had a problem finding data...";
    }
    $c->send_reply( $from, $reply );
};

helper hospital => sub {    # $c, $from, $message, $lat, $long
    app->log->info( "hospital" );
    my $c         = shift;
    my $from      = shift;
    my $message   = shift;
    my $lat       = $c->session->{'lat'};
    my $long      = $c->session->{'long'};
    my $park_name = $c->session->{'park_name'};
    my $geo_str   = $long . '%20' . $lat;
    my $api_get
        = "https://geocology.cartodb.com/api/v2/sql?q=SELECT%20fieldnotes_hospitals.fcltnm%20as%20name%2C%20fieldnotes_hospitals.address%20as%20address%2C%20mncplt%20as%20municipality%2C%20pstlcd%20as%20postalcode%2C%20phnnmbr%20as%20phone%2C%20st_distance(fieldnotes_hospitals.the_geom%3A%3Ageography%2C%20%27SRID%3D4326%3BPOINT($geo_str)%27%3A%3Ageography)%2F1000%20as%20kilometers%20FROM%20fieldnotes_hospitals%20WHERE%20fieldnotes_hospitals.the_geom%20%26%26%20ST_Expand(%27SRID%3D4326%3BPOINT($geo_str)%27%3A%3Ageometry%2C%201)%20ORDER%20BY%20ST_Distance(fieldnotes_hospitals.the_geom%2C%20%27SRID%3D4326%3BPOINT($geo_str)%27%3A%3Ageometry)%20ASC%20LIMIT%202&api_key=$cartodb_key";
    my $response = $ua->get( $api_get )->res->json;
    #say Dumper( $response );
    app->log->info( Dumper( $response ) );
    my $rows = $response->{'rows'};
    my $reply;
    if ( @$rows == 1 ) {
        $reply = "The closest hospital is: $rows->[0]->{'name'}";
    } elsif ( @$rows >= 2 ) {
        $reply = "The closest hospitals are:\n";
        for my $row ( @$rows ) {
            next unless $row->{'name'};
            my $km = $row->{'kilometer'};
            $km = printf("%.3f", $km);
            $reply .= "$row->{'name'} ($km km away)\n";
        }
    } else {
        $reply = "Couldn't find any hospitals. :( Play safe!";
    }
    $c->send_reply( $from, $reply );
};

helper delete => sub {
    app->log->info( "delete" );
    my $c = shift;
    delete $c->session->{'location'};
    delete $c->session->{'park_name'};
    delete $c->session->{'lat'};
    delete $c->session->{'long'};
    app->log->info( 'Session: ' . Dumper( $c->session ) );
};

helper send_reply => sub {    # $c, $from, $reply
    app->log->info( "send_reply" );
    my $c     = shift;
    my $from  = shift;
    my $reply = shift;
    app->log->info( "Sending to Twilio: $reply" )
        if app->mode eq 'development';
    unless ( app->mode eq 'development' ) {
        my $response
            = $twilio
            ->POST(    # Should get CREATED in the ->{'message'} for success
            'SMS/Messages.json',
            From => $config->{'twilio_num'},
            To   => $from,
            Body => $reply
            );
        app->log->info( Dumper( $response ) );
    }
};

helper get_location => sub {    # $c, $from, $message
    app->log->info( "get_location" );
    my $c       = shift;
    my $from    = shift;
    my $message = shift;
    my $field_data;
    my $park_data;
    my $park_id;

    my @fields;
    my @closed;

    #TODO Replace this with an actual data interface!
    for my $field ( @$data_fields ) {
        if ( $field->{'Field Name'} =~ m/$message/gi ) {
            $park_id = $field->{'Park ID'};
            push @fields, $field;
        }
    }
    for my $field ( @fields ) {
        if ( $field->{'Status'} eq 'Closed' ) {
            push @closed, $field;
        }
    }
    if ( $park_id ) {
        app->log->info( 'Got park id setting session data' );
        for my $park ( @$data_parks ) {
            if ( $park->{'Park ID'} eq $park_id ) {
                $park_data = $park;
                $c->session(
                    {   location  => $park_data->{'Park ID'},
                        park_name => $park_data->{'Park Name'},
                        lat       => $park_data->{'Lat'},
                        long      => $park_data->{'Long'}
                    }
                );
                say Dumper( $c->session );
            }
        }
        my $reply;
        if ( @closed == 1 ) {
            $reply
                = "There is one closed field at $park_data->{'Park Name'}: $closed[0]->{'Field Name'}";
        }
        elsif ( @closed >= 2 ) {
            $reply
                = "There are closed fields at $park_data->{'Park Name'}:\n";
            for my $closed ( @closed ) {
                $reply .= "$closed->{'Field Name'}\n";
            }
        }
        else {
            $reply = "Looks like it's all clear at $park_data->{'Park Name'}";
        }
        $c->send_reply( $from, $reply );
    }
    else {
        $c->ask_location( $from, $message );
    }
};

post '/' => sub {
    my $c = shift;

    # This is the ID of our user, and what they want
    my $from    = $c->param( 'From' );
    my $message = $c->param( 'Body' );
    app->log->info( "Got the message $message from $from" );

    # Do we have a location yet? If not, get one
    if ( $c->check_location ) {
        app->log->info( 'Got location...' );

  # Then, if we have a location, check that message is a command we understand
        if ( $c->check_command( $from, $message ) ) {
            app->log->info( 'Got command ...' );

            # If it is, dispatch to the command's helper
            $c->$message( $from, $message );    # Very simple dispatcher
        }
        else {
            app->log->info( 'Asking for command...' );

            # Otherwise, ask for clarification
            $c->ask_command( $from, $message );
        }
    }
    else {    # Otherwise, we need the location
        app->log->info( 'Asking for location...' );
        $c->get_location( $from, $message );
    }
    $c->render(

        text   => "Received: $message",
        status => 200
    );
};

app->start;
__DATA__
