#!/usr/local/bin/perl5

use diagnostics;
use strict;
use warnings;

use CGI qw/:standard *table *Tr *td/;
#use CGI::Pretty qw/ :standard *table *Tr *td/;
use CGI::Carp qw/fatalsToBrowser warningsToBrowser/;
use File::Basename;
use Number::Format qw/:subs/;
use Tie::IxHash;

use Net::INET6Glue::INET_is_INET6;
use Frontier::Client;

use Data::Dumper;

sub clean_die {
    print map(p($_), @_),
        end_html();
    exit(0);
}

# There are also log and log-level, not sure how useful these are in a Web
# interface. Another option may be to call getGlobalOption to retreive
# this list. No: getGlobalOption returns way too many options (including many
# that can't be modified from the XML-RPC interface).
our %ariaopts = ("max-concurrent-downloads" => "Max simultaneous downloads",
                 "max-overall-download-limit" => "Overall d/l bandwidth limit",
                 "max-overall-upload-limit" => "Overall u/l bandwidth limit");

our %ariadlopts = ("max-download-limit" => "D/L bandwidth limit",
                   "max-upload-limit" => "U/L bandwidth limit",
                   "bt-max-peers" => "Max nb. of peers",
                   "bt-request-peer-speed-limit" => "Lower peer speed limit");

sub show_dl {
    my $dls = shift;
    if (not scalar @$dls) {
        print p("No downloads");
        return;
    }

    my $odd = 1;
    print start_table();
    print Tr(th(["Filename", "Status", "Progress"]));
    foreach my $dl (@$dls) {
        print start_Tr({-class => ($odd ? "oddrow" : "evenrow")});
        $odd = !$odd;

        my ($basedir, $basename) = ($dl->{files}[0]{path} =~ m#^(.*)/(.*?)$#);
        # The filename being downloaded, with the details hidden by default,
        # viewable by clicking on the filename
        print td(dl(dt({ -onClick => "toggle(".$dl->{gid}.")" },
                       escapeHTML($basename)),
                    map({ +dd({-class => $dl->{gid}}, escapeHTML($_->{path})) }
                        @{$dl->{files}})));
        my $progress;
        if ($dl->{totalLength}) {
            $progress = sprintf(
                "%.2f%% (%s/%s)",
                100*$dl->{completedLength} / $dl->{totalLength},
                format_bytes($dl->{completedLength}),
                format_bytes($dl->{totalLength}));
        } else {
	    $progress = "n/a";
	}
	print td(p($dl->{status}),
                 start_form(),
                 popup_menu(-name => "dloptname", -values => [keys %ariadlopts],
                            -labels => \%ariadlopts),
                 textfield(-name => "dloptval"),
                 hidden(-name => "dlid",
                        -default => $dl->{gid}),
                 end_form()),
              td(p($progress));
        print end_Tr();
    }
    print end_table();
}

binmode STDOUT, ':utf8';
print header(),
    start_html(-title => "Aria Control",
               -style => { -src => "/style.css" },
               -script => { -src => "/behaviour.js" },
               -encoding => "UTF-8");

my $urlfilename = dirname($ENV{"SCRIPT_FILENAME"}) . "/ariaurl.txt";
open my $urlfile, "<", $urlfilename or clean_die("Could not open the URL file at $urlfilename: $!.");
my $ariaurl = <$urlfile>;
close $urlfile;
my $ariactl = Frontier::Client->new(url => $ariaurl);

my $v;
eval {
    $v = $ariactl->call("aria2.getVersion");
};
if ($@) {
    clean_die("aria2 doesn't seem to be available...", $@),
}

print h1("aria2 Control"),
    start_form(),
    fieldset(legend("Add downloads"),
             "URL to add to the queue of aria2: ",
             textfield(-name => "url"), br(),
             "Output directory: ",
             textfield(-name => "dir", -value => "/storage"), br(),
             submit()),
    end_form();

print
    start_form(),
    fieldset(legend("aria2 options"),
             "Option: ",
             popup_menu(-name => "optname", -values => [keys %ariaopts],
                        -labels => \%ariaopts), br(),
             "Value: ",
             textfield(-name => "optval"), br(),
             submit()),
    end_form();

if (my $url = param("url") and
    my $dir = param("dir")) {
    if ($dir !~ m#^/[a-zA-Z0-9/ -_]+$#) {
        die(p(escapeHTML($dir), " is not a valid path."));
    }
    print p("Adding ", escapeHTML($url), " to the download list,",
        "ouputting to $dir...");
    my $gid;
    $gid = $ariactl->call("aria2.addUri", [$url], {dir => $dir});
    print p("Added to the queue as $gid");
}

if (my $optname = param("optname") and
    my $optval = param("optval")) {
    print p("Setting ", escapeHTML($optname), " to ",
        escapeHTML($optval), "...");
    my $resp = $ariactl->call("aria2.changeGlobalOption",
                              {$optname => $optval});
    print p("aria2 said $resp.");
}

if (my $dlid = param("dlid") and
    my $optname = param("dloptname") and
    my $optval = param("dloptval")) {
    print p("Setting ", escapeHTML($optname), " to ", escapeHTML($optval),
        " for download ", escapeHTML($dlid), "...");
    my $resp = $ariactl->call("aria2.changeOption",
                              $ariactl->string($dlid), {$optname => $optval});
    print p("aria2 said $resp.");
}

my @tellargs = qw/files gid totalLength completedLength status/;

tie my %methods => 'Tie::IxHash',
    "Current Downloads" => ["aria2.tellActive", \@tellargs],
    "Finished Downloads" => ["aria2.tellStopped", 0, 50, \@tellargs],
    "Waiting Downloads" => ["aria2.tellWaiting", 0, 50, \@tellargs],
    ;

foreach my $title (keys %methods) {
    my $dls = $ariactl->call(@{$methods{$title}});
    print h1($title);
    show_dl $dls;
}

print hr(),
    p(sprintf "Version: %s, features: %s\n",
        $v->{version},
        join(", ", @{$v->{enabledFeatures}}));

my $options = $ariactl->call("aria2.getGlobalOption");
print p("Options: "),
    table(map { Tr(td[$_, $options->{$_}]) if !/passwd/; } keys %$options);

print end_html();
