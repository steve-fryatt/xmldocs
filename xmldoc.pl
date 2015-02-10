#!/usr/bin/perl -w

use strict;
use warnings;

use XML::LibXML;
use File::Temp qw/ tempfile tempdir /;

my $filename = "wimp.xml";

my $parser = XML::LibXML->new();
my $index = $parser->parse_file($filename);

my $manual_title = $index->findvalue('/manual/title');

if (!defined($manual_title)) {
	$manual_title = "Undefined";
}


print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0 Transitional//EN\" \"http://www.w3.org/TR/REC-html40/loose.dtd\">\n\n";

print "<html>\n<head>\n";
print "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=iso-8859-1\">\n";
print "<link rel=\"stylesheet\" type=\"text/css\" href=\"base.css\">\n";
print "<title>", $manual_title, "</title>\n</head>\n";

print "</body>\n";
print "<div id=\"container\">\n";


foreach my $chapter ($index->findnodes('/manual/chapter')) {
	process_chapter($chapter);
}

print "<div id=\"footer\">\n";
print "<p><a href=\"http://validator.w3.org/check?uri=referer\"><img src=\"../images/vh40.gif\" alt=\"Valid HTML 4.0!\" width=88 height=31 border=0></a>&nbsp;\n";
print "<a href=\"http://www.riscos.com/\"><img src=\"../images/roro4x.gif\" alt=\"RISC OS\" width=88 height=31 border=0></a>&nbsp;\n";
print "<a href=\"http://www.anybrowser.org/campaign/\"><img src=\"../images/any.gif\" alt=\"Best veiwed with Any Browser!\" width=81 height=31 border=0></a>&nbsp;\n";
print "<a href=\"http://jigsaw.w3.org/css-validator/check/referer\"><img src=\"../images/vcss.gif\" alt=\"Valid CSS!\" width=88 height=31 border=0></a></p>\n\n";

print "<p>Page last updated 21st September, 2014 | Maintained by Steve Fryatt:\n";
print "<a href=\"mailto:web\@stevefryatt.org.uk\">web\@stevefryatt.org.uk</a></p>\n";
print "</div>\n\n";

print "</div>\n</body>\n</html>\n";

#	my ($compound_kind) = $compound->findvalue('./@kind');
#	my ($compound_name) = $compound->findvalue('./name');
#
#	if ($compound_kind eq "file" && $compound_name =~ /\.h$/) {
#		process_file($compound);
#
#		foreach my $member ($compound->findnodes('./member')) {
#			my ($member_kind) = $member->findvalue('./@kind');
#			
#			my ($member_name) = $member->findvalue('./name');
#			print $member_name, "\n";
#		}
#	}



sub process_chapter {
	my ($chapter) = @_;

	my $title = $chapter->findvalue('./title');

	if (defined($title) && $title ne "") {
		print "<div id=\"header\">\n";
		print "<h1>", $title, "</h1>\n\n";
		print "</div>\n";
	}

	print "<div id=\"content\">\n";

	print "<p class=\"breadcrumb\">[ <a href=\"../\" class=\"breadcrumb\">Home</a>\n";
	print "| <span class=\"breadcrumb-here\">RISC&nbsp;OS Software</span> ]</p>\n";

	foreach my $section ($chapter->findnodes('./section')) {
		process_section($section);
	}

	print "<p class=\"breadcrumb\">[ <a href=\"../\" class=\"breadcrumb\">Home</a>\n";
	print "| <span class=\"breadcrumb-here\">RISC&nbsp;OS Software</span> ]</p>\n";

	print "</div>\n";
}


sub process_section {
	my ($section) = @_;

	my $title = $section->findvalue('./title');

	if (defined($title) && $title ne "") {
		print "<h2>", $title, "</h2>\n\n";
	}

	foreach my $block ($section->childNodes()) {
		if ($block->nodeName() eq "para") {
			process_text($block);
		} elsif ($block->nodeName() eq "code") {
			process_code($block);
		}
	}
}


sub process_text {
	my ($text) = @_;

	print "<p>", $text->to_literal, "</p>\n\n";
}


sub process_code {
	my ($code) = @_;

	my $language = $code->findvalue('./@lang');

	my ($fh, $filename) = tempfile("codeXXXXX");

	print $fh $code->to_literal;

	my $html = `source-highlight -i $filename --tab=8 --src-lang=$language --out-format=html-css --no-doc`;
	chomp $html;

	unlink $filename;

	print "<div class=\"codeblock\">", $html, "</div>\n\n";
}
