#!/usr/bin/perl -w

use strict;
use warnings;

use XML::LibXML;
use Image::Magick;
use File::Find::Rule;
use File::Copy;
use File::Path qw/ make_path remove_tree /;
use File::Spec;

use BuildZip;
use FileHash;
use IconDetails;
use ObjectIDs;

use Formatting;

use OutputHtml;

use constant TRUE	=> 1;
use constant FALSE	=> 0;

# Set up some constant values.

my $filename = "wimp.xml";

my $OutputFolder = "output/";
my $OutputImageFolder = "images/";
my $OutputDownloadFolder = "files/";

my $MaxImageWidth = 500;

my $parser = XML::LibXML->new();
$parser->expand_entities(0);
$parser->set_option('huge', 1);
my $manual = $parser->parse_file($filename);

my $ObjectIDs = ObjectIDs->new();

# Get the local time.

my @Time = localtime();

# Track HTML files, images and files.

my $HtmlList = FileHash->new();
my $ImageList = FileHash->new();
my $DownloadList = FileHash->new();

# Locate the icon details

my $IconDetails = IconDetails->new($manual);

# Identify the manual's title.

my $ManualTitle = $ObjectIDs->get_value($manual, '/manual/title', 'Undefined');

# Find the base resource folders.

my $ImageFolder = $ObjectIDs->get_value($manual, '/manual/resources/images', '');
my $DownloadFolder = $ObjectIDs->get_value($manual, '/manual/resources/downloads', '');
my $CommonDownloadFolder = $ObjectIDs->get_value($manual, '/manual/resources/common', '');
my $ChapterFolder = $ObjectIDs->get_value($manual, '/manual/resources/chapters', '');

# Find the index filename

my $IndexFilename = $ObjectIDs->get_value($manual, '/manual/index/filename', 'index.html');

# Pull in any chapter file.

assemble_chapters($manual);

# Link the document, recording all the id attributes.

$ObjectIDs->link_document($manual);

# Identify the breadcrumb trail that we're going to use.

my @BreadCrumbs;

foreach my $breadcrumb ($manual->findnodes('/manual/breadcrumb/dir')) {
	push(@BreadCrumbs, $breadcrumb->to_literal);
}

push(@BreadCrumbs, $ManualTitle);

# Construct the output engine.

my $OutputEngine = OutputHtml->new($ManualTitle, $IndexFilename, $ObjectIDs, $IconDetails, $MaxImageWidth, $OutputFolder, $OutputImageFolder, $OutputDownloadFolder,
		$ImageFolder, $DownloadFolder, $CommonDownloadFolder, $ImageList, $DownloadList, Formatting::get_date(@Time), @BreadCrumbs);

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
# Process an index object to create the introduction page and a contents
# list for the other pages.
#
# \param $index		The index object to be processed.
# \param $manual	The manual we're working on.

sub process_index {
	my ($index, $manual) = @_;

	my $filename = File::Spec->catfile($OutputFolder, $ObjectIDs->get_chapter_filename($index));

	# Check that we haven't already tried to write a chapter of the same name.

	$HtmlList->add_file_record($filename, "chapter");

	print "Writing Index to ", $filename, "...\n";

	open(my $file, ">", $filename) || die "Couldn't open " . $filename . "\n";

	$OutputEngine->write_header($file);

	foreach my $section ($index->findnodes('./section|./chapterlist')) {
		if ($section->nodeName() eq "section") {
			$OutputEngine->process_section($section, $index, $file);
		} elsif ($section->nodeName() eq "chapterlist") {
			$OutputEngine->generate_chapter_list($manual, $file);
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

	my $filename = File::Spec->catfile($OutputFolder, $ObjectIDs->get_chapter_filename($chapter));

	# Check that we haven't already tried to write a chapter of the same name.

	$HtmlList->add_file_record($filename, "chapter");

	# Start to write the chapter.

	print "Writing Chapter ", $number, " to ", $filename, "...\n";

	open(my $file, ">", $filename) || die "Couldn't open " . $filename . "\n";

	my $full_title = $ObjectIDs->get_chapter_title($chapter, $number, TRUE);
	my $short_title = $ObjectIDs->get_chapter_title($chapter, $number, FALSE);

	$OutputEngine->write_header($file, $full_title, $short_title);

	foreach my $section ($chapter->findnodes('./section')) {
		$OutputEngine->process_section($section, $chapter, $file);
	}

	my $previous = $ObjectIDs->find_previous_chapter($chapter);
	my $next = $ObjectIDs->find_next_chapter($chapter);

	$OutputEngine->generate_previous_next_links($previous, $next, $number, $file);

	$OutputEngine->write_footer($file, $short_title);

	close($file);
}

