#!/usr/bin/perl

# http://wiki.apache.org/couchdb/HTTP_database_API#Changes

use warnings;
use strict;

use lib 'common/mojo/lib';

use Mojo::Client;
use Mojo::JSON;
use Data::Dump qw(dump);
use JSON::XS;

my $url = 'http://localhost:5984/monitor/_changes?feed=continuous;include_docs=true;since=';
my $seq = 0;
our $last_id_rev = '';

my $client = Mojo::Client->new;
my $json   = Mojo::JSON->new;
my $error;

$client->keep_alive_timeout(90); # couchdb timeout is 60s

while( ! $error ) {

	warn "GET $url$seq\n";
	my $tx = $client->build_tx( GET => $url . $seq );
	$tx->res->body(sub{
		my ( $content, $body ) = @_;

		warn "## BODY $body\n";

		if ( length($body) == 0 ) {
			warn "# empty chunk, heartbeat?\n";
			return;
		}

		foreach my $change ( split(/\r?\n/, $body) ) { # we can get multiple documents in one chunk

			my $data = $json->decode($change);

			if ( exists $data->{error} ) {
				$error = $data;
			} elsif ( exists $data->{last_seq} ) {
				$seq = $data->{last_seq};
			} elsif ( $data->{seq} <= $seq ) {
				warn "# stale $body";
			} elsif ( exists $data->{changes} ) {

				my $id  = $data->{id} || warn "no id?";
				my $rev = $data->{changes}->[0]->{rev} || warn "no rev?";
				   $seq = $data->{seq} || warn "no seq?";

				if ( $last_id_rev eq "$id $rev" ) {
					warn "# duplicate $last_id_rev\n";
				} else {
					$last_id_rev = "$id $rev";
					warn "# ",dump( $data );
				}

			} else {
				warn "UNKNOWN", dump($data);
			}

		}

	});
	$client->start($tx);

}

die dump($error) if $error;
