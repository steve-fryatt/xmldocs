#!/usr/bin/perl -w

package BuildZip;

use strict;
use warnings;

use Exporter qw(import);

use POSIX;
use File::Spec;
use File::stat;
     
our @EXPORT_OK = qw(build_zip_file);
     

##
# Build a zip file from a set of source folders.
#
# \param $destination	The destination zip archive.
# \param @sources	An array of source folders.

sub build_zip_file
{
	my ($destination, @sources) = @_;

	# Get the most recent modification date for the source files.

	my $source_date = get_file_set_date(@sources);

	# See if the target exists and, if it does, whether any of the source
	# files are newer than it is.

	my $zipinfo = stat($destination);

	if (defined $zipinfo) {
		if ($zipinfo->mtime >= $source_date) {
			return;
		}

		unlink $destination;
	}

	print "- Writing archive $destination...\n";

	# Find the path to the GCCSDK implementation of Zip.

	my $zip = File::Spec->catfile($ENV{GCCSDK_INSTALL_ENV}, "bin/zip");

	# Get a fully-specified filename for the destination zip file.

	$destination = File::Spec->catfile(getcwd, $destination);

	# Process each source folder into the archive. 

	foreach my $folder (@sources) {
		# Set the working directory to the source folder.

		my $cwd = getcwd;
		chdir $folder;

		# Add each file or folder in the source folder to the archive.

		opendir(my $dir, '.') or die $!;

		while (my $object = readdir($dir)) {
			if ($object eq '.' || $object eq '..' || $object eq '.svn') {
				next;
			}

			my $result = `$zip -x "*/.svn/*" -r -, -9 $destination $object`;
			if (defined $? && $? != 0) {
				die "$result\n";
			}
		}

		closedir($dir);

		# Return to the original working directory.

		chdir $cwd;
	}

	return;
}


##
# Return the date of the newest file found in one or more locations
#
# \param $folders	An array of the folders to search.
# \return		The newest file modification date.

sub get_file_set_date
{
	my (@folders) = @_;

	# Build a list of objects in all of the source folders.

	my @files = ();

	foreach my $folder (@folders) {
		@files = (@files, get_file_set($folder));
	}

	# Test the date of each object, and find the newest.

	my $newest = 0;

	foreach my $file (@files) {
		my $fileinfo = stat($file);

		if (!defined $fileinfo) {
			die "Couldn't find file ", $file, "\n";
		}

		my $filesize = $fileinfo->size;
		my $filedate = $fileinfo->mtime;

		if ($filedate > $newest) {
			$newest = $filedate;
		}
	}

	return $newest;
}


##
# Get a list of the files contained in a folder.
#
# \param $folder	The folder to search in.
# \return		An array of relative file names.

sub get_file_set
{
	my ($folder) = @_;

	my $find_rule = File::Find::Rule->new;
	$find_rule->or($find_rule->new->directory->name('.svn')->prune->discard, $find_rule->new);
	my @files = $find_rule->in($folder);

	return @files;
}
     
1;
