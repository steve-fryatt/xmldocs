#!/usr/bin/perl -w

use strict;
use warnings;

use POSIX;
use XML::LibXML;
use Image::Magick;
use File::stat;
use File::Find::Rule;
use File::Copy;
use File::Path qw/ make_path remove_tree /;
use File::Spec;
use File::Temp qw/ tempfile tempdir /;

use constant TRUE	=> 1;
use constant FALSE	=> 0;

my $filename = "wimp.xml";

my $OutputFolder = "output/";
my $OutputImageFolder = "images/";
my $OutputDownloadFolder = "files/";

my $MaxImageWidth = 500;

my $parser = XML::LibXML->new();
$parser->expand_entities(0);
$parser->set_option('huge', 1);
my $manual = $parser->parse_file($filename);

my @Time = localtime();

# Track HTML files, images and files.

my %HtmlList;
my %ImageList;
my %DownloadList;

# Locate the icon details

my %IconDetails;

foreach my $icon ($manual->findnodes('/manual/icons/*')) {
	store_icon_details($icon);
}

# Identify the manual's title.

my $ManualTitle = get_value($manual, '/manual/title', 'Undefined');

# Find the base resource folders.

my $ImageFolder = get_value($manual, '/manual/resources/images', '');
my $DownloadFolder = get_value($manual, '/manual/resources/downloads', '');
my $CommonDownloadFolder = get_value($manual, '/manual/resources/common', '');
my $ChapterFolder = get_value($manual, '/manual/resources/chapters', '');

# Find the index filename

my $IndexFilename = get_value($manual, '/manual/index/filename', 'index.html');

# Pull in any chapter file.

assemble_chapters($manual);

# Identify the breadcrumb trail that we're going to use.

my @BreadCrumbs;

foreach my $breadcrumb ($manual->findnodes('/manual/breadcrumb/dir')) {
	push(@BreadCrumbs, $breadcrumb->to_literal);
}

push(@BreadCrumbs, $ManualTitle);

# Link the document, recording all the id attributes.

my %ObjectIDs;

link_document($manual);

# Process the chapters, outputting a file for each.

# remove_tree($OutputFolder, {keep_root => TRUE} );

make_path(File::Spec->catfile($OutputFolder, $OutputImageFolder));
make_path(File::Spec->catfile($OutputFolder, $OutputDownloadFolder));

my $chapter_no = 1;

foreach my $chapter ($manual->findnodes('/manual/chapter')) {
	process_chapter($chapter, $chapter_no++);
}

foreach my $index ($manual->findnodes('/manual/index')) {
	process_index($index, $manual);
}

remove_obsolete_files(\%HtmlList, $OutputFolder);
remove_obsolete_files(\%ImageList, File::Spec->catfile($OutputFolder, $OutputImageFolder));
remove_obsolete_files(\%DownloadList, File::Spec->catfile($OutputFolder, $OutputDownloadFolder));

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
# Write a page header.
#
# \param $file		The file to write the header to.
# \param $chapter	The chapter title; if undefined, the manual title is
#			used.

sub write_header {
	my ($file, $chapter) = @_;

	print $file "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0 Transitional//EN\" \"http://www.w3.org/TR/REC-html40/loose.dtd\">\n\n";

	print $file "<html>\n<head>\n";
	print $file "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=iso-8859-1\">\n";
	print $file "<link rel=\"stylesheet\" type=\"text/css\" href=\"../../style/base.css\">\n";
	if (defined $chapter && $chapter ne "") {
		print $file "<title>", $ManualTitle, " &ndash; ", $chapter, "</title>\n</head>\n";
	} else {
		print $file "<title>", $ManualTitle, "</title>\n</head>\n";
	}

	print $file "</body>\n";
	print $file "<div id=\"container\">\n";

	if (!defined $chapter || $chapter eq "") {
		$chapter = $ManualTitle;
	}

	print $file "<div id=\"header\">\n";
	print $file "<h1>", $chapter, "</h1>\n";
	print $file "</div>\n\n";

	print $file "<div id=\"content\">\n";
}


##
# Write a page footer.
#
# \param $file		The file to write the footer to.

sub write_footer {
	my ($file) = @_;

	print $file "</div>\n\n";

	print $file "<div id=\"footer\">\n";
	print $file "<p><a href=\"http://validator.w3.org/check?uri=referer\"><img src=\"../../images/vh40.gif\" alt=\"Valid HTML 4.0!\" width=88 height=31 border=0></a>&nbsp;\n";
	print $file "<a href=\"http://www.riscos.com/\"><img src=\"../../images/roro4x.gif\" alt=\"RISC OS\" width=88 height=31 border=0></a>&nbsp;\n";
	print $file "<a href=\"http://www.anybrowser.org/campaign/\"><img src=\"../../images/any.gif\" alt=\"Best veiwed with Any Browser!\" width=81 height=31 border=0></a>&nbsp;\n";
	print $file "<a href=\"http://jigsaw.w3.org/css-validator/check/referer\"><img src=\"../../images/vcss.gif\" alt=\"Valid CSS!\" width=88 height=31 border=0></a></p>\n\n";

	print $file "<p>Page last updated ", get_date(@Time), " | Maintained by Steve Fryatt:\n";
	print $file "<a href=\"mailto:web\@stevefryatt.org.uk\">web\@stevefryatt.org.uk</a></p>\n";
	print $file "</div>\n\n";

	print $file "</div>\n</body>\n</html>\n";
}


##
# Write a breadcrumb trail for a page, based on the manual root location
# and any subsequent pages added to suit the location.
#
# \param $file		The file to write the trail to.
# \param $local		The name of a local page to add to the trail; if
#			undefined, the generated breadcrumb trail is for
#			the index page.

sub write_breadcrumb {
	my ($file, $local) = @_;

	print $file "<p class=\"breadcrumb\">[ ";

	my @names = @BreadCrumbs;
	if (defined $local) {
		push(@names, $local);
	}

	my $entries = scalar(@names);
	my $count = $entries;

	foreach my $item (@names) {
		if ($count < $entries) {
			print $file "| ";
		}

		$count--;

		if ($count > 1 && defined $local) {
			print $file "<a href=\"", "../" x ($count - 1), "\" class=\"breadcrumb\">", $item, "</a>\n";
		} elsif ($count > 0 && defined $local) {
			print $file "<a href=\"", $IndexFilename, "\" class=\"breadcrumb\">", $item, "</a>\n";
		} elsif ($count > 0) {
			print $file "<a href=\"", "../" x $count, "\" class=\"breadcrumb\">", $item, "</a>\n";
		} else {
			print $file "<span class=\"breadcrumb-here\">", $item, "</span>\n";
		}
	}
	
	print $file " ]</p>\n";
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
# Scan through the manual, creating name attributes for each applicable object
# with sequential numbers and storing any IDs in the %ObjectIDs hash for future
# use.
#
# \param $manual	The manual to be scanned.

sub link_document {
	my ($manual) = @_;

	print "Linking document...\n";

	my $number = 1;

	foreach my $chapter ($manual->findnodes('./manual/index|./manual/chapter')) {
		my $chapter_number = 0;
		if ($chapter->nodeName() eq "chapter") {
			$chapter_number = $number++;
		} elsif ($chapter->nodeName() eq "index") {
		}

		store_object_id($chapter, undef, "Chapter " . $chapter_number);

		my $section_number = 1;
		my $code_number = 1;
		my $image_number = 1;
		my $table_number = 1;
		my $download_number = 1;

		foreach my $section ($chapter->findnodes('./section')) {
			store_object_id($section, $chapter, "Section " . $chapter_number . "." . $section_number);

			foreach my $object ($section->findnodes('./code|./image|./table|./download')) {
				if ($object->nodeName() eq "code") {
					if (store_object_id($object, $chapter, "Listing " . $chapter_number . "." . $code_number)) {
						$code_number++;
					}
				} elsif ($object->nodeName() eq "image") {
					if (store_object_id($object, $chapter, "Figure " . $chapter_number . "." . $image_number)) {
						$image_number++;
					}
				} elsif ($object->nodeName() eq "table") {
					if (store_object_id($object, $chapter, "Table " . $chapter_number . "." . $table_number)) {
						$table_number++;
					}
				} elsif ($object->nodeName() eq "download") {
					if (store_object_id($object, $chapter, "Download " . $chapter_number . "." . $download_number)) {
						$download_number++;
					}
				}
			}
		
			$section_number++;
		}
	}
}


##
# Check to see if an object has an ID and, if it does, whether it's stored in
# the list of known IDs. If it's not known, store the ID and a reference to
# the object.
#
# \param $object	The object to store.
# \param $chapter	The chapter containing the object, of undef if the
#			object is a chapter itself.
# \param $name		The name to give the object.

sub store_object_id {
	my ($object, $chapter, $name) = @_;

	my $id = get_object_id($object);
	if (!defined $id) {
		return FALSE;
	}
	
	if (exists $ObjectIDs{$id}) {
		die "Duplicate object id ", $id, ".\n";
	}

	$object->setAttribute('name', $name);

	$ObjectIDs{$id} = {
		'object' => $object,
		'chapter' => $chapter
	};

	return TRUE;
}


##
# Store details of an icon's image file.
#
# \param $icon		The icon object to be processed

sub store_icon_details {
	my ($icon) = @_;

	my $name = $icon->nodeName();

	if (exists $IconDetails{$name}) {
		die "Duplicate icon details ", $name, ".\n";
	}

	$IconDetails{$name} = {
		'file' => $icon->to_literal,
		'alt' => $icon->findvalue('./@alt'),
		'width' => $icon->findvalue('./@width'),
		'height' => $icon->findvalue('./@height')
	};
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

	add_file_record(\%HtmlList, $filename, "chapter");

	print "Writing Index to ", $filename, "...\n";

	open(my $file, ">", $filename) || die "Couldn't open " . $filename . "\n";

	write_header($file);

	write_breadcrumb($file);

	foreach my $section ($index->findnodes('./section|./chapterlist')) {
		if ($section->nodeName() eq "section") {
			process_section($section, $index, $file);
		} elsif ($section->nodeName() eq "chapterlist") {
			generate_chapter_list($manual, $file);
		}
	}

	write_breadcrumb($file);

	write_footer($file);

	close($file);
}


##
# Generate a chapter list for a manual and write it to a file.
#
# \param $manual	The manual to generate the list for.
# \param $file		The file to write the list to.

sub generate_chapter_list {
	my ($manual, $file) = @_;

	my $number = 1;

	print $file "<dl>";

	foreach my $chapter ($manual->findnodes('/manual/chapter')) {
		print $file "\n<dt><a href=\"",
				get_chapter_filename($chapter),
				"\">",
				get_chapter_title($chapter, $number, TRUE),
				"</a></dt>\n";
		my @summaries = $chapter->findnodes('./summary');

		if (defined $summaries[0]) {
			print $file "<dd class=\"doc\">";
			process_text($summaries[0], $file);
			print $file "</dd>\n";
		}

		$number++;
	}

	print $file "</dl>\n\n";
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

	add_file_record(\%HtmlList, $filename, "chapter");

	# Start to write the chapter.

	print "Writing Chapter ", $number, " to ", $filename, "...\n";

	open(my $file, ">", $filename) || die "Couldn't open " . $filename . "\n";

	my $full_title = get_chapter_title($chapter, $number, TRUE);
	my $short_title = get_chapter_title($chapter, $number, FALSE);

	write_header($file, $full_title);

	write_breadcrumb($file, $short_title);

	foreach my $section ($chapter->findnodes('./section')) {
		process_section($section, $chapter, $file);
	}

	my $previous = find_previous_chapter($chapter);
	my $next = find_next_chapter($chapter);

	if (defined $previous || defined $next) {
		print $file "<p class=\"navigate\">";
		if (defined $previous) {
			print $file "Previous: <a href=\"",
					get_chapter_filename($previous),
					"\">",
					get_chapter_title($previous, $number - 1, FALSE),
					"</a>";
		}
		if (defined $previous && defined $next) {
			print $file " | ";
		}
		if (defined $next) {
			print $file "Next: <a href=\"",
					get_chapter_filename($next),
					"\">",
					get_chapter_title($next, $number + 1, FALSE),
					"</a>";
		}
		print $file "</p>\n\n";
	}

	write_breadcrumb($file, $short_title);

	write_footer($file);

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
# Process a section object and write it to the output.
#
# \param $section	The section object to be processed.
# \param $chapter	The parent chapter or index.
# \param $file		The file to write output to.

sub process_section {
	my ($section, $chapter, $file) = @_;

	my $title = $section->findvalue('./title');

	if (defined($title) && $title ne "") {
		my $id = get_object_id($section);

		print $file "<h2>";
		if (defined $id) {
			print $file "<a name=\"", $id, "\">";
		}
		print $file $title;
		if (defined $id) {
			print $file "</a>";
		}
		print $file "</h2>\n\n";
	}

	foreach my $block ($section->childNodes()) {
		if ($block->nodeName() eq "p") {
			print $file "<p class=\"doc\">";
			process_text($block, $file);
			print $file "</p>\n\n";
		} elsif ($block->nodeName() eq "table") {
			process_table($block, $file);
		} elsif ($block->nodeName() eq "code") {
			process_code($block, $file);
		} elsif ($block->nodeName() eq "image") {
			process_image($block, $chapter, $file);
		} elsif ($block->nodeName() eq "download") {
			process_download($block, $chapter, $file);
		}
	}
}


##
# Process a text object and write it to the output.
#
# \param $text		The text object to be processed.
# \param $file		The file to write output to.

sub process_text {
	my ($text, $file) = @_;

	my %tags = (
		'cite' => 'cite',
		'code' => 'code',
		'em' => 'em'
	);

	my %styles = (
		'command' => 'command',
		'const' => 'code',
		'event' => 'name',
		'file' => 'filename',
		'function' => 'code',
		'intro' => 'introduction',
		'icon' => 'icon',
		'key' => 'key',
		'maths' => 'maths',
		'menu' => 'name',
		'message' => 'name',
		'mouse' => 'mouse',
		'name' => 'name',
		'swi' => 'name',
		'type' => 'name',
		'variable' => 'code'
	);

	my %entities = (
		'ldquo' => '&ldquo;',
		'lsquo' => '&lsquo;',
		'minus' => '&minus;',
		'nbsp' => '&nbsp;',
		'ndash' => '&ndash;',
		'rdquo' => '&rdquo;',
		'rsquo' => '&rsquo;',
		'times' => '&times;'
	);

	foreach my $chunk ($text->childNodes()) {
		if ($chunk->nodeType() == XML_TEXT_NODE) {
			print $file $chunk->to_literal;
		} elsif ($chunk->nodeType() == XML_ELEMENT_NODE) {
			if (exists $styles{$chunk->nodeName()}) {
				print $file "<span class=\"", $styles{$chunk->nodeName()}, "\">", $chunk->to_literal, "</span>";
			} elsif (exists $tags{$chunk->nodeName()}) {
				print $file "<", $tags{$chunk->nodeName()}, ">", $chunk->to_literal, "</", $tags{$chunk->nodeName()}, ">";
			} elsif ($chunk->nodeName() eq "reference") {
				print $file create_reference($chunk);
			} elsif ($chunk->nodeName() eq "link") {
				print $file create_link($chunk);
			} else {
				print $file $chunk->to_literal;
			}
		} elsif ($chunk->nodeType() == XML_ENTITY_REF_NODE) {
			if (exists $entities{$chunk->nodeName()}) {
				print $file $entities{$chunk->nodeName()};
			} else {
				print $file $chunk->to_literal;
			}
		} elsif ($chunk->nodeType() == XML_COMMENT_NODE) {
			# Ignore comments.
		} else {
			print $file "(unknown chunk ", $chunk->nodeType(), ")";
		}
	}
}


##
# Create an HTML link to the object indicated by the supplied reference.
#
# \param $reference	The reference object to use.
# \return		An HTML link corresponding to the supplied reference.

sub create_reference {
	my ($reference) = @_;

	validate_object_type($reference, "reference");

	my $id = get_object_id($reference);

	if (!defined $id) {
		die "Missing id.\n";
	}

	if (!exists $ObjectIDs{$id}) {
		die "Id ".$id." undefined.\n";
	}

	my $link = "";

	if (defined $ObjectIDs{$id}->{'chapter'}) {
		$link = get_chapter_filename($ObjectIDs{$id}->{'chapter'})."#".$id;
	} else {
		$link = $link = get_chapter_filename($ObjectIDs{$id}->{'object'});
	}

	my $text = "";

	if (defined $reference->to_literal && $reference->to_literal ne "") {
		$text = $reference->to_literal;
	} else {
		$text = $ObjectIDs{$id}->{'object'}->findvalue('./@name');
	}


	return "<a href=\"".$link."\">".$text."</a>";
}


##
# Create an HTML link to an external resource indicated by the supplied
# link.
#
# \param $link		The link object to use.
# \return		An HTML link corresponding to the supplied link.

sub create_link {
	my ($link) = @_;

	validate_object_type($link, "link");

	if (!defined $link->findvalue('./@href') || $link->findvalue('./@href') eq "") {
		die "Missing external link.\n";
	}

	return "<a href=\"".$link->findvalue('./@href')."\" class=\"external\">".$link->to_literal."</a>";
}


##
# Process a table object and write it to the output.
#
# \param $table		The table object to be processed.
# \param $file		The file to write output to.

sub process_table {
	my ($table, $file) = @_;

	my $caption = undef;
	my $id = get_object_id($table);

	if (defined $id) {
		$caption = $table->findvalue('./@name');
		if (defined $table->findvalue('./@title') && $table->findvalue('./@title') ne "") {
			$caption .= ": ".$table->findvalue('./@title');
		}
	}

	my @columns = undef;

	print $file "<div class=\"titled\">";
	if (defined $id) {
		print $file "<a name=\"", $id, "\">";
	}
	print $file "<table class=\"doc\">\n";

	foreach my $chunk ($table->childNodes()) {
		if ($chunk->nodeType() == XML_TEXT_NODE) {
			# print $file $chunk->to_literal;
		} elsif ($chunk->nodeType() == XML_ELEMENT_NODE) {
			if ($chunk->nodeName() eq "columns") {
	#			if (defined(@columns)) {
	#				die "Multiple column sets defined\n";
	#			}
				print $file "<tr>";
				@columns = process_table_headings($chunk, $file);
				print $file "</tr>\n";
			} elsif ($chunk->nodeName() eq "row") {
				print $file "<tr>";
				process_table_row($chunk, $file, @columns);
				print $file "</tr>\n";
			} else {
				print $file "(unknown node ", $chunk->nodeName(), ")";
			}
		} elsif ($chunk->nodeType() == XML_COMMENT_NODE) {
			# Ignore comments.
		} else {
			print $file "(unknown chunk ", $chunk->nodeType(), ")";
		}
	}

	print $file "</table>";
	if (defined $caption) {
		print $file "\n<p class=\"title\">", $caption, "</p>";
	};
	if (defined $id) {
		print $file "</a>";
	}
	print $file "</div>\n\n";
}


##
# Process a reading row of a table object and write it to the output.
#
# \param $row		The row object to be processed.
# \param $file		The file to write output to.
# \return		The column definitions for the table.

sub process_table_headings {
	my ($row, $file) = @_;

	my @columns = ();

	foreach my $chunk ($row->childNodes()) {
		if ($chunk->nodeType() == XML_TEXT_NODE) {
			# print $file $chunk->to_literal;
		} elsif ($chunk->nodeType() == XML_ELEMENT_NODE) {
			if ($chunk->nodeName() eq "col") {
				if (!defined $chunk->findvalue('./@align') || $chunk->findvalue('./@align') eq "") {
					die "Missing external link.\n";
				}

				my $align = $chunk->findvalue('./@align');

				if ($align ne "left" && $align ne "centre" && $align ne "right") {
					die "Bad alignment: $align\n";
				}

				push(@columns, $align);

				print $file "<th class=\"$align\">";
				process_text($chunk, $file);
				print $file "</th>";
				
			} else {
	#			print $file $chunk->to_literal;
			}
		} elsif ($chunk->nodeType() == XML_COMMENT_NODE) {
			# Ignore comments.
		} else {
			print $file "(unknown chunk ", $chunk->nodeType(), ")";
		}
	}

	return @columns;
}


##
# Process a standard row of a table object and write it to the output.
#
# \param $row		The row object to be processed.
# \param $file		The file to write output to.
# \param @columns	The column definitions for the table.

sub process_table_row {
	my ($row, $file, @columns) = @_;

	my $column = 0;

	foreach my $chunk ($row->childNodes()) {
		if ($chunk->nodeType() == XML_TEXT_NODE) {
			print $file $chunk->to_literal;
		} elsif ($chunk->nodeType() == XML_ELEMENT_NODE) {
			if ($chunk->nodeName() eq "col") {
				if ($column >= scalar @columns) {
					die "Too many columns\n";
				}

				print $file "<td class=\"".$columns[$column]."\">";
				process_text($chunk, $file);
				print $file "</td>";

				$column++;
			} else {
	#			print $file $chunk->to_literal;
			}
		} elsif ($chunk->nodeType() == XML_COMMENT_NODE) {
			# Ignore comments.
		} else {
			print $file "(unknown chunk ", $chunk->nodeType(), ")";
		}
	}
}


##
# Process a code object and write it to the output.
#
# \param $code		The code object to be processed.
# \param $file		The file to write output to.

sub process_code {
	my ($code, $file) = @_;

	my $language = $code->findvalue('./@lang');

	my $caption = undef;
	my $id = get_object_id($code);

	if (defined $id) {
		$caption = $code->findvalue('./@name');
		if (defined  $code->findvalue('./@file') && $code->findvalue('./@file') ne "") {
			$caption .= " (".$code->findvalue('./@file').")";
		}
		if (defined  $code->findvalue('./@title') && $code->findvalue('./@title') ne "") {
			$caption .= ": ".$code->findvalue('./@title');
		}
	}

	my ($fh, $filename) = tempfile("codeXXXXX");

	print $fh $code->to_literal;

	close $fh;

	my $html = `source-highlight -i $filename --tab=8 --src-lang=$language --out-format=html-css --no-doc`;
	chomp $html;

	unlink $filename;

	print $file "<div class=\"titled\">";
	if (defined $id) {
		print $file "<a name=\"", $id, "\">";
	}
	print $file "<div class=\"codeblock\">", $html, "</div>";
	if (defined $caption) {
		print $file "\n<p class=\"title\">", $caption, "</p>";
	}
	if (defined $id) {
		print $file "</a>";
	}
	print $file "</div>\n\n";
}


##
# Process an image object and write it to the output.
#
# \param $image		The image object to be processed.
# \param $chapter	The parent chapter or index.
# \param $file		The file to write output to.

sub process_image {
	my ($image, $chapter, $file) = @_;

	my $imagefile = $image->findvalue('./@file');

	my $caption = undef;
	my $id = get_object_id($image);

	if (defined $id) {
		$caption = $image->findvalue('./@name');
		if (defined $image->findvalue('./@title') && $image->findvalue('./@title') ne "") {
			$caption .= ": ".$image->findvalue('./@title');
		}
	}

	my $infile = File::Spec->catfile($ImageFolder, get_chapter_resource_folder($chapter, 'images'), $imagefile);
	my $outfile = File::Spec->catfile($OutputFolder, $OutputImageFolder, $imagefile);

	my $ininfo = stat($infile);
	my $outinfo = stat($outfile);

	# Check that we haven't already tried to write an image of the same name.

	add_file_record(\%ImageList, $outfile, "image");

	if (!defined $ininfo) {
		die "Couldn't find imagefile file ", $imagefile, "\n";
	}

	my $convert = Image::Magick->new;
	my $x = $convert->ReadImage($infile);
	if ($x) {
		die $x."\n";
	}
	
	$x = $convert->Resize(geometry => $MaxImageWidth.'x>');
	if ($x) {
		die $x."\n";
	}

	if (!defined($outinfo) || $ininfo->mtime > $outinfo->mtime) {
		print "- Writing image $imagefile...\n";
		$x = $convert->Write($outfile);
		if ($x) {
			die $x."\n";
		}
	}

	my ($width, $height) = $convert->Get('width', 'height');

	undef $convert;

	print $file "<div class=\"titled\">";
	if (defined $id) {
		print $file "<a name=\"", $id, "\">";
	}
	print $file "<p><img src=\"", File::Spec::Unix->catfile($OutputImageFolder, $imagefile), "\" width=", $width," height=", $height,"></p>";
	if (defined $caption) {
		print $file "\n<p class=\"title\">", $caption, "</p>";
	};
	if (defined $id) {
		print $file "</a>";
	}
	print $file "</div>\n\n";
}


##
# Process a download object and write it to the output.
#
# \param $download	The download object to be processed.
# \param $chapter	The parent chapter or index.
# \param $file		The file to write output to.

sub process_download {
	my ($download, $chapter, $file) = @_;

	my $downloadfile = $download->findvalue('./@file');

	my $caption = undef;
	my $title = undef;
	my $id = get_object_id($download);

	if (defined $id) {
		$caption = $download->findvalue('./@name');
	} else {
		$caption = "Download";
	}

	my $chapterfolder = File::Spec->catfile($DownloadFolder, get_chapter_resource_folder($chapter, 'downloads'), $downloadfile);

	if (!-d $chapterfolder) {
		die "Couldn't find chapter download folder ", $downloadfile, "\n";
	}

	my $commonfolder = File::Spec->catfile($DownloadFolder, $CommonDownloadFolder);

	if (!-d $commonfolder) {
		die "Couldn't find common download folder ", $CommonDownloadFolder, "\n";
	}

	if (defined $download->findvalue('./@title') && $download->findvalue('./@title') ne "") {
		$title = $download->findvalue('./@title');
	} else {
		$title = $downloadfile;
	}

	my $destinationfile = (File::Spec->catfile($OutputFolder, $OutputDownloadFolder, $downloadfile));
	$destinationfile .= ".zip";

	# Check that we haven't already tried to write a download of the same name.

	add_file_record(\%DownloadList, $destinationfile, "download");

	build_zip_file($destinationfile, $chapterfolder, $commonfolder);

	my $fileinfo = stat($destinationfile);

	if (!defined $fileinfo) {
		die "Couldn't find download file ", $destinationfile, "\n";
	}

	my $filesize = $fileinfo->size;
	my $filedate = $fileinfo->mtime;

	my $compatibility = "";
	my $iyonix_ok = FALSE;
	my $armv7_ok = FALSE;

	if ($download->findvalue('./@compatibility') eq "26bit") {
		$compatibility = " | <em>26-bit only</em>";
	} elsif ($download->findvalue('./@compatibility') eq "32bit") {
		$compatibility = " | 26/32-bit neutral";
		$iyonix_ok = TRUE;
	} elsif ($download->findvalue('./@compatibility') eq "armv7") {
		$compatibility = " | 26/32-bit neutral, ARMv7 OK";
		$iyonix_ok = TRUE;
		$armv7_ok = TRUE;
	}

	print $file "<p class=\"download\">";
	
	write_icon_image($file, 'zip');
	if ($iyonix_ok) {
		write_icon_image($file, 'armv7', 'iyonix');
	}
	if ($armv7_ok) {
		write_icon_image($file, 'iyonix', 'iyonix');
	}
	if (defined $id) {
		print $file "<a name=\"", $id, "\">";
	}
	print $file "<b>", $caption, ":</b>";
	if (defined $id) {
		print $file "</a>";
	}
	print $file " <a href=\"", File::Spec::Unix->catfile($OutputDownloadFolder, $downloadfile),".zip\">", $title,"</a><br>\n";
	print $file get_filesize($filesize), " | ", get_date(localtime($filedate)), $compatibility, "</p>\n\n";
}


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


##
# Write an image tag for an icon to the output file.
#
# \param $file		The file to write to.
# \param $icon		The internal image icon name.
# \param $class		If supplied, the CSS class name to apply to the image.

sub write_icon_image {
	my ($file, $icon, $class) = @_;

	if (!defined $IconDetails{$icon}) {
		die "Icon ", $icon, " not defined.\n";
	}

	print $file "<img src=\"", $IconDetails{$icon}->{'file'}, "\" alt=\"", $IconDetails{$icon}->{'alt'},
			"\" width=", $IconDetails{$icon}->{'width'}, " height=", $IconDetails{$icon}->{'height'};

	if (defined $class) {
		print $file " class=\"", $class, "\"";
	}

	print $file ">\n";
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


##
# Add a filename to a hash for reference of the objects written, erroring
# if a duplicate is encountered.
#
# \param $files		Reference to the file name index hash.
# \param $filename	The filename to be added.
# \param $type		The type of object to be added, in human-readable form.
sub add_file_record {
	my ($files, $filename, $type) = @_;
	
	# Check that we haven't already tried to write a file of the same name.

	if (exists $$files{$filename}) {
		die "Duplicate $type file name $filename\n";
	}

	# Record the name.

	$$files{$filename} = 1;
}


##
# Scan the files in a folder and compare each to the names in a hash of
# files, deleting any which aren't referenced.
#
# \param $files		Reference to the file name index hash.
# \param $folder	The folder containing the files.
sub remove_obsolete_files {
	my ($files, $folder) = @_;

	opendir(my $dir, $folder) or die $!;

	while (my $object = readdir($dir)) {
		my $file = File::Spec->catfile($folder, $object);

		if (not -f $file) {
			next;
		}

		if (not exists $$files{$file}) {
			print "Removing unused file $file...\n";
			unlink $file;
		}
	}

	closedir($dir);
}
