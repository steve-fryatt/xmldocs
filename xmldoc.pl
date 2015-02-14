#!/usr/bin/perl -w

use strict;
use warnings;

use POSIX;
use XML::LibXML;
use File::Temp qw/ tempfile tempdir /;

my $index_filename = "index.html";

my $filename = "wimp.xml";

my $parser = XML::LibXML->new();
$parser->expand_entities(0);
my $manual = $parser->parse_file($filename);

my @Time = localtime();

# Identify the manual's title.

my $ManualTitle = $manual->findvalue('/manual/title');

if (!defined($ManualTitle)) {
	$ManualTitle = "Undefined";
}

# Identify the breadcrumb trail that we're going to use.

my @BreadCrumbs;

foreach my $breadcrumb ($manual->findnodes('/manual/breadcrumb/dir')) {
	push(@BreadCrumbs, $breadcrumb->to_literal);
}

push(@BreadCrumbs, $ManualTitle);

# Process the chapters, outputting a file for each.

my $chapter_no = 1;

foreach my $chapter ($manual->findnodes('/manual/chapter')) {
	process_chapter($chapter, $chapter_no++);
}

foreach my $index ($manual->findnodes('/manual/index')) {
	process_index($index, $manual);
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
	print $file "<link rel=\"stylesheet\" type=\"text/css\" href=\"base.css\">\n";
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
	print $file "<p><a href=\"http://validator.w3.org/check?uri=referer\"><img src=\"../images/vh40.gif\" alt=\"Valid HTML 4.0!\" width=88 height=31 border=0></a>&nbsp;\n";
	print $file "<a href=\"http://www.riscos.com/\"><img src=\"../images/roro4x.gif\" alt=\"RISC OS\" width=88 height=31 border=0></a>&nbsp;\n";
	print $file "<a href=\"http://www.anybrowser.org/campaign/\"><img src=\"../images/any.gif\" alt=\"Best veiwed with Any Browser!\" width=81 height=31 border=0></a>&nbsp;\n";
	print $file "<a href=\"http://jigsaw.w3.org/css-validator/check/referer\"><img src=\"../images/vcss.gif\" alt=\"Valid CSS!\" width=88 height=31 border=0></a></p>\n\n";

	print $file "<p>Page last updated ", get_date(), " | Maintained by Steve Fryatt:\n";
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
			print $file "<a href=\"", $index_filename, "\" class=\"breadcrumb\">", $item, "</a>\n";
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
# \return		The current date.

sub get_date {
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
	my $day  = $Time[3];
	if (exists $suffixes{$day}) {
		$suffix = $suffixes{$day};
	}
	
	return $day . $suffix . POSIX::strftime(" %B, %Y", @Time);
}


##
# Process an index object to create the introduction page and a contents
# list for the other pages.
#
# \param $index		The index object to be processed.
# \param $manual	The manual we're working on.

sub process_index {
	my ($index, $manual) = @_;

	my $filename = $index_filename;

	open(my $file, ">", $filename) || die "Couldn't open " . $filename . "\n";

	write_header($file);

	write_breadcrumb($file);

	foreach my $section ($index->findnodes('./section|./chapterlist')) {
		if ($section->nodeName() eq "section") {
			process_section($section, $file);
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
				get_chapter_title($chapter, $number),
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

	my $filename = get_chapter_filename($chapter);

	open(my $file, ">", $filename) || die "Couldn't open " . $filename . "\n";

	my $title = get_chapter_title($chapter, $number);

	write_header($file, $title);

	write_breadcrumb($file, $title);

	foreach my $section ($chapter->findnodes('./section')) {
		process_section($section, $file);
	}

	my $previous = find_previous_chapter($chapter);
	my $next = find_next_chapter($chapter);

	if (defined $previous || defined $next) {
		print $file "<p class=\"navigate\">";
		if (defined $previous) {
			print $file "Previous: <a href=\"",
					get_chapter_filename($previous),
					"\">",
					get_chapter_title($previous, $number - 1),
					"</a>";
		}
		if (defined $previous && defined $next) {
			print $file " | ";
		}
		if (defined $next) {
			print $file "Next: <a href=\"",
					get_chapter_filename($next),
					"\">",
					get_chapter_title($next, $number + 1),
					"</a>";
		}
		print $file "</p>\n\n";
	}

	write_breadcrumb($file, $title);

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

	my $next = $chapter->nextNonBlankSibling();

	while (defined $next && ($next->nodeName() ne "chapter" || $next->nodeType() != XML_ELEMENT_NODE)) {
		$next = $next->nextNonBlankSibling();
	}

	return $next;
}


##
# Find the filename to use for a chapter.
#
# \param $chapter	The chapter to return the filename for.
# \return		The filename of the chapter.

sub get_chapter_filename {
	my ($chapter) = @_;
	
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
# \return		The title to give to teh chapter.

sub get_chapter_title {
	my ($chapter, $number) = @_;

	my $name = $chapter->findvalue('./title');

	if (!defined $name || $name eq "") {
		$name = "Chapter " . $number;
	}

	return $name;
}






sub process_section {
	my ($section, $file) = @_;

	my $title = $section->findvalue('./title');

	if (defined($title) && $title ne "") {
		print $file "<h2>", $title, "</h2>\n\n";
	}

	foreach my $block ($section->childNodes()) {
		if ($block->nodeName() eq "p") {
			print $file "<p class=\"doc\">";
			process_text($block, $file);
			print $file "</p>\n\n";
		} elsif ($block->nodeName() eq "code") {
			process_code($block, $file);
		}
	}
}


sub process_text {
	my ($text, $file) = @_;

	my %styles = (
		'const' => 'code',
		'event' => 'name',
		'function' => 'code',
		'message' => 'name',
		'name' => 'name',
		'swi' => 'name',
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
			} else {
				print $file $chunk->to_literal;
			}
		} elsif ($chunk->nodeType() == XML_ENTITY_REF_NODE) {
			if (exists $entities{$chunk->nodeName()}) {
				print $file $entities{$chunk->nodeName()};
			} else {
				print $file $chunk->to_literal;
			}
		} else {
			print $file "(unknown chunk ", $chunk->nodeType(), ")";
		}
	}
}


sub process_code {
	my ($code, $file) = @_;

	my $language = $code->findvalue('./@lang');

	my ($fh, $filename) = tempfile("codeXXXXX");

	print $fh $code->to_literal;

	my $html = `source-highlight -i $filename --tab=8 --src-lang=$language --out-format=html-css --no-doc`;
	chomp $html;

	unlink $filename;

	print $file "<div class=\"codeblock\">", $html, "</div>\n\n";
}

