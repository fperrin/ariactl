#!/usr/local/bin/perl5

use diagnostics;
use strict;
use warnings;

use CGI qw/:standard *table *Tr *td/;
#use CGI::Pretty qw/ :standard *table *Tr *td/;
use CGI::Carp qw/fatalsToBrowser warningsToBrowser/;

use Net::INET6Glue::INET_is_INET6;
use Frontier::Client;
use Tie::IxHash;

use Number::Format qw/:subs/;
use Data::Dumper;

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
    if (scalar @$dls) {
	my $odd = 1;
	print start_table();
	print Tr(th(["Filename", "Status", "Progress"]));
	foreach my $dl (@$dls) {
	    print start_Tr({-class => ($odd ? "oddrow" : "evenrow")});
	    $odd = !$odd;

	    my ($basedir) = ($dl->{files}[0]{path} =~ m#^(.*)/#);
	    print td(dl(dt({ -onClick => "toggle(".$dl->{gid}.")" }, $basedir),
			map({ +dd({-id => $dl->{gid}}, $_->{path}) }
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
    } else {
	print p("No downloads");
    }
}

open ARIAURL, "/usr/local/www/cmd/ariaurl.txt";
my $ariaurl = <ARIAURL>;
close ARIAURL;
my $ariactl = Frontier::Client->new(url => $ariaurl);

binmode STDOUT, ':utf8';
print header(),
    start_html(-title => "Aria Control",
	       -style => { -src => "/style.css" },
	       -script => { -src => "/behaviour.js" },
	       -encoding => "UTF-8");

my $v;
eval {
    $v = $ariactl->call("aria2.getVersion");
};
if ($@) {
    print p("aria2 doesn't seem to be available..."),
        p($@),
        end_html();
    exit 0;
}

print h1("Aria Control"),
    start_form(),
    fieldset(legend("Add downloads"),
	     "URL to add to the queue of Aria: ",
	     textfield(-name => "url"), br(),
	     "Output directory: ",
	     textfield(-name => "dir", -value => "/storage"), br(),
	     submit()),
    end_form();

print
    start_form(),
    fieldset(legend("Aria2c options"),
             "Option: ",
             popup_menu(-name => "optname", -values => [keys %ariaopts],
			-labels => \%ariaopts), br(),
             "Value: ",
             textfield(-name => "optval"), br(),
             submit()),
    end_form();

if (my $url = param("url") and
    my $dir = param("dir")) {
    print p("Adding $url to the download list, ouputting to $dir...");
    my $gid;
    $gid = $ariactl->call("aria2.addUri", [$url], {dir => $dir});
    print p("Added to the queue as $gid");
}

if (my $optname = param("optname") and
    my $optval = param("optval")) {
    print p("Setting $optname to $optval...");
    my $resp = $ariactl->call("aria2.changeGlobalOption",
			      {$optname => $optval});
    print p("Aria2c said $resp.");
}

if (my $dlid = param("dlid") and
    my $optname = param("dloptname") and
    my $optval = param("dloptval")) {
    print p("Setting $optname to $optval for download $dlid...");
    my $resp = $ariactl->call("aria2.changeOption",
			      $ariactl->string($dlid), {$optname => $optval});
    print p("Aria2c said $resp.");
}

tie my %methods => 'Tie::IxHash',
    "Current Downloads" => "aria2.tellActive",
    "Finished Downloads" => "aria2.tellStopped",
    "Waiting Downloads" => "aria2.tellWaiting",
    ;
foreach my $title (keys %methods) {
    my $dls = $ariactl->call($methods{$title}, 0, 50);
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

