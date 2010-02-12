use strict;
use warnings;

#use CGI qw/:standard -no_xhtml *table *Tr *td/;
use CGI::Pretty;
use CGI::Carp qw/fatalsToBrowser warningsToBrowser/;

use Net::INET6Glue::INET_is_INET6;
use Frontier::Client;

use Data::Dumper;

print header();

open ARIAURL, "/usr/local/www/cmd/ariaurl.txt";
my $ariaurl = <ARIAURL>;
close ARIAURL;
my $ariactl = Frontier::Client->new(url => $ariaurl);

print start_html(-title => "Aria Control",
		 -style => { -src => "/style.css" },
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
	     textfield(-name => "url"),
	     submit()),
    end_form();

if (my $url = param("url")) {
    print p("Adding ".$url." to the download list...");
    my $gid = $ariactl->call("aria2.addUri", [$url]);
    print p("Added to the queue as $gid");
}

my $dls = $ariactl->call("aria2.tellActive");
print h1("Current Downloads");

if (scalar @$dls) {
    my $odd = 1;
    print start_table();
    print Tr(th(["Filename", "Status", "Progress"]));
    foreach my $dl (@$dls) {
	print start_Tr({-class => $odd ? "oddrow" : "evenrow"}), start_td();
	my $progress;
	if ($dl->{totalLength}) {
	    $progress = sprintf(
		"%.2f%% (%d/%d)",
		100*$dl->{completedLength} / $dl->{totalLength},
		$dl->{completedLength},
		$dl->{totalLength});
	} else {
	    $progress = "n/a";
	}
	foreach (@{$dl->{files}}) {
	    $_->{path} =~ m#/([^/]*)$#;
	    print $1, br();
	}
	print end_td(),
	      td($dl->{status}),
              td($progress),
	      end_Tr();
    }
    print end_table();
}

print comment(Dumper $dls);

print hr(),
    p(sprintf "Version: %s, features: %s\n",
      $v->{version},
      join(", ", @{$v->{enabledFeatures}}));

print end_html();

