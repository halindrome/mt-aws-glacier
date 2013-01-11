# mt-aws-glacier - Amazon Glacier sync client
# Copyright (C) 2012-2013  Victor Efimov
# http://mt-aws.com (also http://vs-dev.com) vs@vs-dev.com
# License: GPLv3
#
# This file is part of "mt-aws-glacier"
#
#    mt-aws-glacier is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    mt-aws-glacier is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

package InventoryFetchJob;

use strict;
use warnings;
use utf8;
use base qw/Job/;
use InventoryDownloadJob;

use JSON::XS;


sub new
{
    my ($class, %args) = @_;
    my $self = \%args;
    bless $self, $class;
    $self->{raised} = 0;
    return $self;
}

# returns "ok" "wait" "ok subtask"
sub get_task
{
	my ($self) = @_;
	if ($self->{raised}) {
		return ("wait");
	} else {
		$self->{raised} = 1;
		return ("ok", Task->new(id => "inventory_fetch",action=>"inventory_fetch_job", data => { marker => $self->{marker} } ));
	}
}

# returns "ok" "ok replace" "done"
sub finish_task
{
	my ($self, $task) = @_;
	if ($self->{raised}) {
		my $json = JSON::XS->new->allow_nonref;
		my $scalar = $json->decode( $task->{result}->{response} );
		for my $job (@{$scalar->{JobList}}) {
			#print "$job->{Completed}|$job->{JobId}|$job->{ArchiveId}\n";
			if ($job->{Action} eq 'InventoryRetrieval' && $job->{Completed} && $job->{StatusCode} eq 'Succeeded') {
				return ("ok replace", InventoryDownloadJob->new(job_id => $job->{JobId}));
			}
		}
		
		if ($scalar->{Marker}) {
			return ("ok replace", InventoryFetchJob->new(marker => $scalar->{Marker}) );
		} else {
			return ("done");
		}
	} else {
		die;
	}
}
	
1;