#!/usr/bin/perl -w

use strict;
use warnings;

use XML::LibXML;
use Image::Magick;
use File::Find::Rule;
use File::Copy;
use File::Path qw/ make_path remove_tree /;
use File::Spec;
use File::stat;
use File::Temp qw/ tempfile tempdir /;

use BuildZip;
use FileHash;
use IconDetails;

use OutputHtml;

use constant TRUE	=> 1;
use constant FALSE	=> 0;

# Construct the output engine.

my $OutputEngine = OutputHtml->new();

# Set up some constant values.

my $filename = "wimp.xml";

my $OutputFolder = "dumpout/";
my $OutputImageFolder = "images/";
my $OutputDownloadFolder = "files/";

my $MaxImageWidth = 500;

my $parser = XML::LibXML->new();
$parser->expand_entities(0);
$parser->set_option('huge', 1);
my $manual = $parser->parse_file($filename);

my @Time = localtime();

# Track HTML files, images and files.

my $HtmlList = FileHash->new();
my $ImageList = FileHash->new();
my $DownloadList = FileHash->new();

# Locate the icon details

my $IconDetails = IconDetails->new($manual);

# Identify the manual's title.

$OutputEngine->ManualTitle = get_value($manual, '/manual/title', 'Undefined');

# Find the base resource folders.

my $ImageFolder = get_value($manual, '/manual/resources/images', '');
my $DownloadFolder = get_value($manual, '/manual/resources/downloads', '');
my $CommonDownloadFolder = get_value($manual, '/manual/resources/common', '');
my $ChapterFolder = get_value($manual, '/manual/resources/chapters', '');

# Find the index filename

$OutputEngine->IndexFilename = get_value($manual, '/manual/index/filename', 'index.html');

# Pull in any chapter file.

assemble_chapters($manual);

# Identify the breadcrumb trail that we're going to use.

my @BreadCrumbs;

foreach my $breadcrumb ($manual->findnodes('/manual/breadcrumb/dir')) {
	push(@BreadCrumbs, $breadcrumb->to_literal);
}

push(@BreadCrumbs, $ManualTitle);

# Link the document, recording all the id attributes.

my $ObjectIDs = $ObjectIDs->new();

$ObjectIDs->link_document($manual);

$OutputEngine->ObjectIDs = $ObjectIDs;

# Process the chapters, outputting a file for each.

make_path(File::Spec->catfile($OutputFolder, $OutputImageFolder));
make_path(File::Spec->catfile($OutputFolder, $OutputDownloadFolder));

my $chapter_no = 1;

foreach my $chapter ($manual->findnodes('/manual/chapter')) {
	process_chapter($chapter, $chapter_no++);
}

foreach my $index ($manual->findnodes('/manual/index')) {
	process_index($index, $manual);
}

$HtmlList->remove_obsolete_files($OutputFolder);
$ImageList->remove_obsolete_files(File::Spec->catfile($OutputFolder, $OutputImageFolder));
$DownloadList->remove_obsolete_files(File::Spec->catfile($OutputFolder, $OutputDownloadFolder));

##
# Return the value of an XML node.
#
# \param $object	The XML object to read from.
# \param $name		The name of the node to be returned.
# \param $default	A default value to return; omit to use undef.
# \return		The value read.

sub get_value {
	my ($object, $name, $default) = @_;

	if ($object->findvalue("count(" . $name . ")") > 1) {
		die("No unique ", $name, " found.\n");
	}

	my $value = $object->findvalue($name);

	if (!defined $value) {
		$value = $default;
	}

	return $value;
}


##
# Assemble sub chapters into the master DOM.
#
# \param $manual	The manual to assemble.

sub assemble_chapters {
	my ($manual) = @_;

	foreach my $chapter ($manual->findnodes('/manual/chapter')) {
		my $file = $chapter->findvalue('./@file');

		if (!defined $file || $file eq "") {
			next;
		}

		my $chapter_file = File::Spec->catfile($ChapterFolder, $file);

		print "Pull in chapter ... $chapter_file\n";

		my $chapter_content = $parser->parse_file($chapter_file);

		my @child = $chapter_content->findnodes('/manual/chapter');
		if (scalar @child != 1) {
			die "Not exacltly one chapter in $file\n";
		}

		my $clone = $child[0]->cloneNode(1);
		$chapter->replaceNode($clone);
	}

	$manual->toFile("dump.xml", 1);
}


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


##
# Process an index object to create the introduction page and a contents
# list for the other pages.
#
# \param $index		The index object to be processed.
# \param $manual	The manual we're working on.

sub process_index {
	my ($index, $manual) = @_;

	my $filename = File::Spec->catfile($OutputFolder, get_chapter_filename($index));

	# Check that we haven't already tried to write a chapter of the same name.

	$HtmlList->add_file_record($filename, "chapter");

	print "Writing Index to ", $filename, "...\n";

	open(my $file, ">", $filename) || die "Couldn't open " . $filename . "\n";

	$OutputEngine->write_header($file);

	foreach my $section ($index->findnodes('./section|./chapterlist')) {
		if ($section->nodeName() eq "section") {
			process_section($section, $index, $file);
		} elsif ($section->nodeName() eq "chapterlist") {
			generate_chapter_list($manual, $file);
		}
	}

	$OutputEngine->write_footer($file);

	close($file);
}


##
# Process a chapter object, generating a suitable file for output and sending
# the contents out to it.
#
# \param $chapter	The chapter object to be processed.
# \param $number	The chapter number.

sub process_chapter {
	my ($chapter, $number) = @_;

	# Get the relative file name for the chapter.

	my $filename = File::Spec->catfile($OutputFolder, get_chapter_filename($chapter));

	# Check that we haven't already tried to write a chapter of the same name.

	$HtmlList->add_file_record($filename, "chapter");

	# Start to write the chapter.

	print "Writing Chapter ", $number, " to ", $filename, "...\n";

	open(my $file, ">", $filename) || die "Couldn't open " . $filename . "\n";

	my $full_title = get_chapter_title($chapter, $number, TRUE);
	my $short_title = get_chapter_title($chapter, $number, FALSE);

	$OutputEngine->write_header($file, $full_title);

	foreach my $section ($chapter->findnodes('./section')) {
		process_section($section, $chapter, $file);
	}

	my $previous = find_previous_chapter($chapter);
	my $next = find_next_chapter($chapter);

	$outputEngine->generate_previous_next_links($previous, $next, $number, $file);

	$OutputEngine->write_footer($file);

	close($file);
}


##
# Find the chapter before a given chapter.
#
# \param $chapter	The chapter to look up from.
# \return		The previous chapter, or undef if none.

sub find_previous_chapter {
	my ($chapter) = @_;

	validate_object_type($chapter, "chapter");

	my $previous = $chapter->previousNonBlankSibling();

	while (defined $previous && ($previous->nodeName() ne "chapter" || $previous->nodeType() != XML_ELEMENT_NODE)) {
		$previous = $previous->previousNonBlankSibling();
	}

	return $previous;
}


##
# Find the chapter after a given chapter.
#
# \param $chapter	The chapter to look up from.
# \return		The next chapter, or undef if none.

sub find_next_chapter {
	my ($chapter) = @_;

	validate_object_type($chapter, "chapter");

	my $next = $chapter->nextNonBlankSibling();

	while (defined $next && ($next->nodeName() ne "chapter" || $next->nodeType() != XML_ELEMENT_NODE)) {
		$next = $next->nextNonBlankSibling();
	}

	return $next;
}


##
# Find the filename to use for a chapter or index.
#
# \param $chapter	The chapter to return the filename for.
# \return		The filename of the chapter.

sub get_chapter_filename {
	my ($chapter) = @_;

	validate_object_type($chapter, "chapter", "index");

	my $filename = $chapter->findvalue('./filename');

	if (!defined $filename || $filename eq "") {
		die "No filename for chapter.\n";
	}

	return $filename;
}


##
# Get the title to use for a chapter.
#
# \param $chapter	The chapter to return the title for.
# \param $number	The sequence number of the chapter in question.
# \param $full		TRUE to prefix with Chapter <n>:
# \return		The title to give to the chapter.

sub get_chapter_title {
	my ($chapter, $number, $full) = @_;

	validate_object_type($chapter, "chapter");

	my $name = $chapter->findvalue('./title');

	if (!defined $name || $name eq "") {
		$name = "Chapter $number";
	} elsif ($full == TRUE) {
		$name = "Chapter $number: $name";
	}

	return $name;
}


##
# Return the local resource folder for a chapter or index.
#
# \param $chapter	The chapter to return the folder for.
# \param $resource	The resource folder of interest.
# \return		The folder name, or '' if unavailable.

sub get_chapter_resource_folder {
	my ($chapter, $resource) = @_;

	validate_object_type($chapter, "chapter", "index");

	my $folder = '';

	if ($resource eq 'images') {
		$folder = get_value($chapter, './resources/images', '');
	} elsif ($resource eq 'downloads') {
		$folder = get_value($chapter, './resources/downloads', '');
	}

	return $folder;
}


##
# Get the reference ID for an object. If one hasn't been defined, undef is
# returned instead.
#
# \param $object	The object to return the ID for.
# \return		The object's ID, or undef if none has been defined.

sub get_object_id {
	my ($object) = @_;

	validate_object_type($object, "reference", "index", "chapter", "section", "code", "image", "table", "download");

	my $id = $object->findvalue('./@id');

	if ($id eq "") {
		$id = undef;
	}

	return $id;
}


##
# Test the type of an object to see if it's one contained in an acceptable
# list. If the object's type isn't in the list, the subroutine exits via
# die() and does not return.
#
# \param $object	The object to test.
# \param @types		A list of acceptable types.

sub validate_object_type {
	my ($object, @types) = @_;

	my $found = FALSE;

	foreach my $type (@types) {
		if ($type eq $object->nodeName()) {
			$found = TRUE;
			last;
		}
	}

	if (!$found) {
		die "ID in invalid object ".$object->nodeName()."\n";
	}
}

