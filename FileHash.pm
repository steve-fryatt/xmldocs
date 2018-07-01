#!/usr/bin/perl -w

package FileHash;

use strict;
use warnings;

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
