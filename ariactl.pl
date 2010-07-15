use strict;
use warnings;
use diagnostics;

#use CGI qw/:standard *table *Tr *td/;
use CGI::Pretty qw/ :standard *table *Tr *td/;
use CGI::Carp qw/fatalsToBrowser warningsToBrowser/;

use Net::INET6Glue::INET_is_INET6;
use Frontier::Client;
use Tie::IxHash;

use Number::Format qw/:subs/;
use Data::Dumper;

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
	    print td(p($dl->{status})),
	          td(p($progress));

	    print end_Tr();
	}
	print end_table();
    } else {
	print p("No downloads");
    }
    print comment(Dumper $dls);
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

if (my $url = param("url") and
    my $dir = param("dir")) {
    print p("Adding $url to the download list, ouputting to $dir...");
    my $gid = $ariactl->call("aria2.addUri", [$url], {dir => $dir});
    print p("Added to the queue as $gid");
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

#print comment(Dumper $dls);

print hr(),
    p(sprintf "Version: %s, features: %s\n",
      $v->{version},
      join(", ", @{$v->{enabledFeatures}}));

print end_html();

