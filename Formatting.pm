#!/usr/bin/perl -w

# Copyright 2015-2021, Stephen Fryatt (info@stevefryatt.org.uk)
#
# This file is part of XML Docs:
#
#   http://www.stevefryatt.org.uk/software/
#
# Licensed under the EUPL, Version 1.2 only (the "Licence");
# You may not use this work except in compliance with the
# Licence.
#
# You may obtain a copy of the Licence at:
#
#   http://joinup.ec.europa.eu/software/page/eupl
#
# Unless required by applicable law or agreed to in
# writing, software distributed under the Licence is
# distributed on an "AS IS" basis, WITHOUT WARRANTIES
# OR CONDITIONS OF ANY KIND, either express or implied.
#
# See the Licence for the specific language governing
# permissions and limitations under the Licence.

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
