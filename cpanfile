# Basic stack
# Web framework
requires 'Mojolicious', '5.61';

# Log Mojolicious info to the console (patched to work with JSON responses)
requires 'Mojolicious::Plugin::ConsoleLogger', '0';
requires 'Mojolicious::Plugin::JSONP', '0';

requires 'WWW::Twilio::API', '0';
requires 'WWW::Twilio::TwiML', '0';
