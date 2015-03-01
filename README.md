# Field Notes

Also known as, 604-670-SCCR (7227).

A open data day hackathon project. Read more [here](http://phillipadsmith.com/2015/02/successful-products-solve-problems.html).

## Installation

### Install Perl

These days, I recommend using [plenv](https://github.com/tokuhirom/plenv) to install a local version of Perl that doesn't muck with your system perl binary.

To do that, just:

`git clone git://github.com/tokuhirom/plenv.git ~/.plenv`

`echo 'export PATH="$HOME/.plenv/bin:$PATH"' >> ~/.bash_profile`

`echo 'eval "$(plenv init -)"' >> ~/.bash_profile`

`exec $SHELL -l`

`git clone git://github.com/tokuhirom/Perl-Build.git ~/.plenv/plugins/perl-build/`

`plenv install 5.20.0`

### Get the source

First, fork the repository so that you have your own copy. Then:

`git clone git@github.com:yourusername/field-notes-lite`

`git checkout -b develop` (Always work on the `develop` branch while developing!)

### Install the Perl dependencies

From here, if you don't have a global install of [cpanm](https://github.com/miyagawa/cpanminus), you'll want to install that with the command `plenv install-cpanm` (this assumes that you installed Perl with `plenv` as described above).

Next, to localize the libraries that the project requires, you'll want to install [Carton](https://github.com/perl-carton/carton):

`cpanm install Carton`

Then install the project requirements into a local directory so that you know you're using the right ones:

`cd field-notes-lite`

`carton install`

When that finishes, you should have a `local` directory full of libraries.

### Create the configuration file

Your configuration file, `app.production.json` or `app.development.json`, should look like this:

```
{
    "app_secret"      : "A secret here",
    "twilio_sid"      : "",
    "twilio_token"    : "",
    "twilio_num"      : "+15555555555",
    "forecast_key"    : "",
    "cartodb_key"     : "",
    "hypnotoad"       : {
      "listen"        : [ "http://*:1234" ],
      "workers"       : "10",
      "proxy"         : "1"
    }
}
```

### Start the development server

At this point you should have everything needed to start developing. Run the app in development mode with:

`carton exec morbo app.pl` (automatically loads `app.development.json`)

And, if everythign worked, you should see:

`Server available at http://127.0.0.1:1234.`

### 7. Bask in the glory of local development!


The development server will reload the app when any of the files are edited. So you can just edit the template files and the single-file application to your needs and refresh your browser to see the results. 

Errors will be written to your terminal, as well as shown in the browser.

### 8. Send a pull request with the changes

When you're done making changes, create a new pull request pointing from the branch that you're working on lcoally (probaby `develop`) pointing to the `develop` branch at https://github.com/phillipadsmith/field-notes-lite

Submit the pull request and congratulate yourself on a job well done. :)
