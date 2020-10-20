#!/usr/bin/perl -w

package Formatting;

use strict;
use warnings;


##
# Get the date in a suitable format for a page footer.
#
# \param @time		The time to convert.
# \return		The current date.

sub get_date {
	my (@time) = @_;

	my %suffixes = (
		1 => 'st',
		2 => 'nd',
		3 => 'rd',
		21 => 'st',
		22 => 'nd',
		23 => 'rd',
		31 => 'st'
	);

	my $suffix = 'th';
	my $day  = $time[3];
	if (exists $suffixes{$day}) {
		$suffix = $suffixes{$day};
	}
	
	return $day . $suffix . POSIX::strftime(" %B, %Y", @time);
}

##
# Get a date in a format suitable for the CMS.
#
# \param @time		The time to convert.
# \return		The date ad YYYY, M, D

sub get_pagefoot_date {
	my (@time) = @_;
	
	return sprintf("%d, %d, %d", $time[5] + 1900, $time[4] + 1, $time[3]);
}

##
# Get a filetype into a human-readable format.
#
# \param $size		The size to format, in bytes.
# \return		The size in human-readable format.

sub get_filesize {
	my ($size) = @_;

	if ($size < 1024) {
		return sprintf("%d Bytes", $size);
	} elsif ($size < 1048576) {
		return sprintf("%d KBytes", ($size / 1024) + 0.5);
	} else {
		return sprintf("%d Mbytes", (($size / 104857.6) + 0.5) / 10);
	}

	return "";
}

1;
