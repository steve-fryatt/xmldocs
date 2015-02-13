#!/usr/bin/perl -w

use strict;
use warnings;

use POSIX;
use XML::LibXML;
use File::Temp qw/ tempfile tempdir /;

my $filename = "wimp.xml";

my $parser = XML::LibXML->new();
$parser->expand_entities(0);
my $index = $parser->parse_file($filename);

my $manual_title = $index->findvalue('/manual/title');

if (!defined($manual_title)) {
	$manual_title = "Undefined";
}




foreach my $chapter ($index->findnodes('/manual/chapter')) {
	process_chapter($chapter);
}


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


sub write_header {
	my ($title, $chapter, $file) = @_;

	print $file "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0 Transitional//EN\" \"http://www.w3.org/TR/REC-html40/loose.dtd\">\n\n";

	print $file "<html>\n<head>\n";
	print $file "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=iso-8859-1\">\n";
	print $file "<link rel=\"stylesheet\" type=\"text/css\" href=\"base.css\">\n";
	print $file "<title>", $title, " &ndash; ", $chapter, "</title>\n</head>\n";

	print $file "</body>\n";
	print $file "<div id=\"container\">\n";

}


sub write_footer {
	my ($file) = @_;

	print $file "<div id=\"footer\">\n";
	print $file "<p><a href=\"http://validator.w3.org/check?uri=referer\"><img src=\"../images/vh40.gif\" alt=\"Valid HTML 4.0!\" width=88 height=31 border=0></a>&nbsp;\n";
	print $file "<a href=\"http://www.riscos.com/\"><img src=\"../images/roro4x.gif\" alt=\"RISC OS\" width=88 height=31 border=0></a>&nbsp;\n";
	print $file "<a href=\"http://www.anybrowser.org/campaign/\"><img src=\"../images/any.gif\" alt=\"Best veiwed with Any Browser!\" width=81 height=31 border=0></a>&nbsp;\n";
	print $file "<a href=\"http://jigsaw.w3.org/css-validator/check/referer\"><img src=\"../images/vcss.gif\" alt=\"Valid CSS!\" width=88 height=31 border=0></a></p>\n\n";

	print $file "<p>Page last updated ", make_date(), " | Maintained by Steve Fryatt:\n";
	print $file "<a href=\"mailto:web\@stevefryatt.org.uk\">web\@stevefryatt.org.uk</a></p>\n";
	print $file "</div>\n\n";

	print $file "</div>\n</body>\n</html>\n";
}


sub make_date {
	my %suffixes = ( 1 => 'st', 2 => 'nd', 3 => 'rd', 21 => 'st', 22 => 'nd', 23 => 'rd', 31 => 'st' );

	my @time = localtime();

	my $suffix = 'th';
	my $day  = $time[3];
	if (exists $suffixes{$day}) {
		$suffix = $suffixes{$day};
	}
	
	return $day . $suffix . POSIX::strftime(" %B, %Y", @time);

}


sub process_chapter {
	my ($chapter) = @_;

	my $filename = $chapter->findvalue('./filename');

	open(my $file, ">", $filename);

	my $title = $chapter->findvalue('./title');

	write_header($manual_title, $title, $file);

	if (defined($title) && $title ne "") {
		print $file "<div id=\"header\">\n";
		print $file "<h1>", $title, "</h1>\n\n";
		print $file "</div>\n";
	}

	print $file "<div id=\"content\">\n";

	print $file "<p class=\"breadcrumb\">[ <a href=\"../\" class=\"breadcrumb\">Home</a>\n";
	print $file "| <a href=\"index.html\" class=\"breadcrumb\">", $manual_title, "</a>\n";
	print $file "| <span class=\"breadcrumb-here\">", $title, "</span> ]</p>\n";

	foreach my $section ($chapter->findnodes('./section')) {
		process_section($section, $file);
	}

	print $file "<p class=\"breadcrumb\">[ <a href=\"../\" class=\"breadcrumb\">Home</a>\n";
	print $file "| <a href=\"index.html\" class=\"breadcrumb\">", $manual_title, "</a>\n";
	print $file "| <span class=\"breadcrumb-here\">", $title, "</span> ]</p>\n";

	print $file "</div>\n";

	write_footer($file);

	close($file);
}


sub process_section {
	my ($section, $file) = @_;

	my $title = $section->findvalue('./title');

	if (defined($title) && $title ne "") {
		print $file "<h2>", $title, "</h2>\n\n";
	}

	foreach my $block ($section->childNodes()) {
		if ($block->nodeName() eq "p") {
			process_text($block, $file);
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


	print $file "<p class=\"doc\">";

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

	print $file "</p>\n\n";
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

