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

package FileHash;
#use Moose;

use strict;
use warnings;

#has 'files' => (is => 'r', isa => 'HashRef', default => {});

##
# Construct a new FileHash instance.
sub new {
	my ($class) = @_;

	my $self = {};

	bless($self, $class);

	$self->{files} = {}; 

	return $self;
}


##
# Add a filename to the hash for reference of the objects written, erroring
# if a duplicate is encountered.
#
# \param $filename	The filename to be added.
# \param $type		The type of object to be added, in human-readable form.
sub add_file_record {
	my ($self, $filename, $type) = @_;
	
	# Check that we haven't already tried to write a file of the same name.

	if (exists $self->{files}{$filename}) {
		die "Duplicate $type file name $filename\n";
	}

	# Record the name.

	$self->{files}{$filename} = 1;
}


##
# Scan the files in a folder and compare each to the names in the hash of
# files, deleting any which aren't referenced.
#
# \param $folder	The folder containing the files.
sub remove_obsolete_files {
	my ($self, $folder) = @_;

	opendir(my $dir, $folder) or die $!;

	while (my $object = readdir($dir)) {
		my $file = File::Spec->catfile($folder, $object);

		if (not -f $file) {
			next;
		}

		if (not exists $self->{files}{$file}) {
			print "Removing unused file $file...\n";
			unlink $file;
		}
	}

	closedir($dir);
}

1;
