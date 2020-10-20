#!/usr/bin/perl -w

package OutputHtml;

use strict;
use warnings;

use XML::LibXML;
use Image::Magick;
use HTML::Entities;
use File::Temp qw/ tempfile tempdir /;
use File::stat;

use Formatting;

use constant TRUE	=> 1;
use constant FALSE	=> 0;

##
# Construct a new FileHash instance.
sub new {
	my $class = shift;

	my $self = {};

	bless($self, $class);

	$self->{ManualTitle} = shift;
	$self->{IndexFilename} = shift;
	$self->{ObjectIDs} = shift;
	$self->{IconDetails} = shift;

	$self->{MaxImageWidth} = shift;

	$self->{OutputFolder} = shift;
	$self->{OutputImageFolder} = shift;
	$self->{OutputDownloadFolder} = shift;

	$self->{ImageFolder} = shift;
	$self->{DownloadFolder} = shift;
	$self->{CommonDownloadFolder} = shift;

	$self->{ImageList} = shift;
	$self->{DownloadList} = shift;

	$self->{LinkPrefix} = shift;
	$self->{ImagePrefix} = shift;
	$self->{DownloadPrefix} = shift;

	$self->{Time} = shift;
	$self->{BreadCrumbs} = \@_;

	return $self;
}


##
# Write a page header.
#
# \param $file		The file to write the header to.
# \param $chapter	The chapter title; if undefined, the manual title is
#			used.

sub write_header {
	my ($self, $file, $chapter, $breadcrumb) = @_;

	print $file "<!DOCTYPE HTML>\n\n";

	print $file "<html>\n";
	print $file "<head>\n";
	print $file "<?php echo \$Templates->Head(array(\"RISC&nbsp;OS\", \"", $self->{ManualTitle},"\"";

	if (defined $chapter && $chapter ne "") {
		print $file " ,\"", $chapter, "\"";
	}

	print $file "), array(\"style/docs.css\")); ?>\n";
	print $file "</head>\n\n";

	print $file "<body>\n";
	print $file "<?php echo \$Templates->PageTop(array(";

	$self->write_breadcrumb($file, $breadcrumb);

	print $file ")); ?>\n\n";

	if (!defined $chapter || $chapter eq "") {
		$chapter = $self->{ManualTitle};
	}

	print $file "<h1>", $chapter, "</h1>\n";
}


##
# Write a page footer.
#
# \param $file		The file to write the footer to.

sub write_footer {
	my ($self, $file, $breadcrumb) = @_;

	print $file "<?php\n";
	print $file "	echo \$Templates->SideBar();\n";
	print $file "	echo \$Templates->PageEnd(", $self->{Time}, ");\n";
	print $file "?>\n\n";

	print $file "</body>\n";
	print $file "</html>\n";
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
	my ($self, $file, $local) = @_;

	my @names = @{$self->{BreadCrumbs}};
	if (defined $local) {
		push(@names, $local);
	}

	my $entries = scalar(@names);
	my $count = $entries;

	foreach my $item (@names) {
		if ($count < $entries) {
			print $file ", ";
		}

		$count--;

		print $file "\"";
		
		if ($count > 1 && defined $local) {
			print $file "../" x ($count - 1);
		} elsif ($count > 0 && defined $local) {
			print $file "./";
		} elsif ($count > 1) {
			print $file "../" x ($count - 1);
		} elsif ($count > 0) {
			print $file "./";
		}

		print $file "\" => \"", $item,"\"";
 	}
}


##
# Generate a chapter list for a manual and write it to a file.
#
# \param $manual	The manual to generate the list for.
# \param $file		The file to write the list to.

sub generate_chapter_list {
	my ($self, $manual, $file) = @_;

	my $number = 1;

	print $file "<dl>";

	foreach my $chapter ($manual->findnodes('/manual/chapter')) {
		print $file "\n<dt><a href=\"", $self->{LinkPrefix},
				$self->{ObjectIDs}->get_chapter_uri($chapter),
				"\">",
				$self->{ObjectIDs}->get_chapter_title($chapter, $number, TRUE),
				"</a></dt>\n";
		my @summaries = $chapter->findnodes('./summary');

		if (defined $summaries[0]) {
			print $file "<dd class=\"doc\">";
			$self->process_text($summaries[0], $file);
			print $file "</dd>\n";
		}

		$number++;
	}

	print $file "</dl>\n\n";
}


##
# Generate the previous and next links for the foot of a page.
#
# \param $previous	The previous chapter information, or undef.
# \param $next		The next chapter information, or undef.
# \param $number	The current chapter number.
# \param $file		The file to write the links to.

sub generate_previous_next_links {
	my ($self, $previous, $next, $number, $file) = @_;

	if (defined $previous || defined $next) {
		print $file "<p class=\"navigate\">";
		if (defined $previous) {
			print $file "Previous: <a href=\"",
					$self->{ObjectIDs}->get_chapter_uri($previous),
					"\">",
					$self->{ObjectIDs}->get_chapter_title($previous, $number - 1, FALSE),
					"</a>";
		}
		if (defined $previous && defined $next) {
			print $file " | ";
		}
		if (defined $next) {
			print $file "Next: <a href=\"",
					$self->{ObjectIDs}->get_chapter_uri($next),
					"\">",
					$self->{ObjectIDs}->get_chapter_title($next, $number + 1, FALSE),
					"</a>";
		}
		print $file "</p>\n\n";
	}
}


##
# Process a section object and write it to the output.
#
# \param $section	The section object to be processed.
# \param $chapter	The parent chapter or index.
# \param $file		The file to write output to.

sub process_section {
	my ($self, $section, $chapter, $file) = @_;

	my $title = $section->findvalue('./title');

	if (defined($title) && $title ne "") {
		my $id = $self->{ObjectIDs}->get_object_id($section);

		print $file "<h2";
		if (defined $id) {
			print $file " id=\"", $id, "\"";
		}
		print $file ">";
		print $file $title;
		print $file "</h2>\n\n";
	}

	foreach my $block ($section->childNodes()) {
		if ($block->nodeName() eq "p") {
			print $file "<p class=\"doc\">";
			$self->process_text($block, $file);
			print $file "</p>\n\n";
		} elsif ($block->nodeName() eq "list") {
			$self->process_list($block, $file);
		} elsif ($block->nodeName() eq "table") {
			$self->process_table($block, $file);
		} elsif ($block->nodeName() eq "code") {
			$self->process_code($block, $file);
		} elsif ($block->nodeName() eq "image") {
			$self->process_image($block, $chapter, $file);
		} elsif ($block->nodeName() eq "download") {
			$self->process_download($block, $chapter, $file);
		}
	}
}


##
# Process a text object and write it to the output.
#
# \param $text		The text object to be processed.
# \param $file		The file to write output to.

sub process_text {
	my ($self, $text, $file) = @_;

	my %tags = (
		'cite' => 'cite',
		'code' => 'code',
		'em' => 'em',
		'strong' => 'strong'
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
		'variable' => 'code',
		'window' => 'window'
	);

	my %entities = (
		'amp' => '&amp;',
		'lt' => '&lt;',
		'gt' => '&gt;',
		'le' => '&le;',
		'ge' => '&ge;',
		'quot' => '&quot;',
		'ldquo' => '&ldquo;',
		'lsquo' => '&lsquo;',
		'minus' => '&minus;',
		'msep' => '&#8594;',
		'nbsp' => '&nbsp;',
		'ndash' => '&ndash;',
		'rdquo' => '&rdquo;',
		'rsquo' => '&rsquo;',
		'times' => '&times;'
	);

	foreach my $chunk ($text->childNodes()) {
		if ($chunk->nodeType() == XML_TEXT_NODE) {
			print $file encode_entities($chunk->to_literal);
		} elsif ($chunk->nodeType() == XML_ELEMENT_NODE) {
			if (exists $styles{$chunk->nodeName()}) {
				print $file "<span class=\"", $styles{$chunk->nodeName()}, "\">";
				$self->process_text($chunk, $file);
				print $file "</span>";
			} elsif (exists $tags{$chunk->nodeName()}) {
				print $file "<", $tags{$chunk->nodeName()}, ">";
				$self->process_text($chunk, $file);
				print $file "</", $tags{$chunk->nodeName()}, ">";
			} elsif ($chunk->nodeName() eq "reference") {
				print $file $self->create_reference($chunk);
			} elsif ($chunk->nodeName() eq "link") {
				print $file $self->create_link($chunk);
			} else {
				print $file encode_entities($chunk->to_literal);
			}
		} elsif ($chunk->nodeType() == XML_ENTITY_REF_NODE) {
			if (exists $entities{$chunk->nodeName()}) {
				print $file $entities{$chunk->nodeName()};
			} else {
				print $file encode_entities($chunk->to_literal);
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
	my ($self, $reference) = @_;

	$self->{ObjectIDs}->validate_object_type($reference, "reference");

	my $id = $self->{ObjectIDs}->get_object_id($reference);

	if (!defined $id) {
		die "Missing id.\n";
	}

	if (!($self->{ObjectIDs}->object_exists($id))) {
		die "Id ".$id." undefined.\n";
	}

	my $link = "";

	my $object = $self->{ObjectIDs}->get_object($id);
	my $chapter = $self->{ObjectIDs}->get_chapter($id);

	if (defined $chapter) {
		$link = $self->{ObjectIDs}->get_chapter_uri($chapter)."#".$id;
	} else {
		$link = $link = $self->{ObjectIDs}->get_chapter_uri($object);
	}

	my $text = "";

	if (defined $reference->to_literal && $reference->to_literal ne "") {
		$text = $reference->to_literal;
	} else {
		$text = $object->findvalue('./@name');
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
	my ($self, $link) = @_;

	$self->{ObjectIDs}->validate_object_type($link, "link");

	if (!defined $link->findvalue('./@href') || $link->findvalue('./@href') eq "") {
		die "Missing external link.\n";
	}

	return "<a href=\"".$link->findvalue('./@href')."\" class=\"external\">".$link->to_literal."</a>";
}


##
# Process a list object and write it to the output.
#
# \param $list		The list object to be processed.
# \param $file		The file to write output to.

sub process_list {
	my ($self, $list, $file) = @_;

	my $type = $list->findvalue('./@type');

	if (defined $type && $type ne "") {
		if ($type eq "ol") {
			$type = "ordered";
		} elsif ($type eq "ul") {
			$type = "unordered";
		} else {
			die "Unknown list type ", $type, ".\n";
		}
	} else {
		$type = "unordered";
	}

	if ($type eq "ordered") {
		print $file "<ol class=\"doc\">";
	} elsif ($type eq "unordered") {
		print $file "<ul class=\"doc\">";
	} else {
		die "Unknown list type ", $type, ".\n";
	}

	foreach my $chunk ($list->childNodes()) {
		if ($chunk->nodeType() == XML_TEXT_NODE) {
			# print $file $chunk->to_literal;
		} elsif ($chunk->nodeType() == XML_ELEMENT_NODE) {
			if ($chunk->nodeName() eq "li") {
				print $file "\n<li class=\"doc\">";
				$self->process_text($chunk, $file);
				print $file "</li>\n";
			} else {
				print $file "(unknown node ", $chunk->nodeName(), ")";
			}
		} elsif ($chunk->nodeType() == XML_COMMENT_NODE) {
			# Ignore comments.
		} else {
			print $file "(unknown chunk ", $chunk->nodeType(), ")";
		}
	}

	if ($type eq "ordered") {
		print $file "</ol>\n\n";
	} elsif ($type eq "unordered") {
		print $file "</ul>\n\n";
	} else {
		die "Unknown list type ", $type, ".\n";
	}
}


##
# Process a table object and write it to the output.
#
# \param $table		The table object to be processed.
# \param $file		The file to write output to.

sub process_table {
	my ($self, $table, $file) = @_;

	my $caption = undef;
	my $id = $self->{ObjectIDs}->get_object_id($table);

	if (defined $id) {
		$caption = $table->findvalue('./@name');
		if (defined $table->findvalue('./@title') && $table->findvalue('./@title') ne "") {
			$caption .= ": ".$table->findvalue('./@title');
		}
	}

	my @columns = undef;

	print $file "<div class=\"titled\"";
	if (defined $id) {
		print $file " id=\"", $id, "\"";
	}
	print $file ">";
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
				@columns = $self->process_table_headings($chunk, $file);
				print $file "</tr>\n";
			} elsif ($chunk->nodeName() eq "row") {
				print $file "<tr>";
				$self->process_table_row($chunk, $file, @columns);
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
	print $file "</div>\n\n";
}


##
# Process a reading row of a table object and write it to the output.
#
# \param $row		The row object to be processed.
# \param $file		The file to write output to.
# \return		The column definitions for the table.

sub process_table_headings {
	my ($self, $row, $file) = @_;

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
				$self->process_text($chunk, $file);
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
	my ($self, $row, $file, @columns) = @_;

	my $column = 0;

	foreach my $chunk ($row->childNodes()) {
		if ($chunk->nodeType() == XML_TEXT_NODE) {
			print $file encode_entities($chunk->to_literal);
		} elsif ($chunk->nodeType() == XML_ELEMENT_NODE) {
			if ($chunk->nodeName() eq "col") {
				if ($column >= scalar @columns) {
					die "Too many columns\n";
				}

				print $file "<td class=\"".$columns[$column]."\">";
				$self->process_text($chunk, $file);
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
	my ($self, $code, $file) = @_;

	my $language = $code->findvalue('./@lang');

	my $caption = undef;
	my $id = $self->{ObjectIDs}->get_object_id($code);

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

	print $file "<div class=\"titled\"";
	if (defined $id) {
		print $file " id=\"", $id, "\"";
	}
	print $file ">";
	print $file "<div class=\"codeblock\">", $html, "</div>";
	if (defined $caption) {
		print $file "\n<p class=\"title\">", $caption, "</p>";
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
	my ($self, $image, $chapter, $file) = @_;

	my $imagefile = $image->findvalue('./@file');

	my $caption = undef;
	my $id = $self->{ObjectIDs}->get_object_id($image);

	if (defined $id) {
		$caption = $image->findvalue('./@name');
		if (defined $image->findvalue('./@title') && $image->findvalue('./@title') ne "") {
			$caption .= ": ".$image->findvalue('./@title');
		}
	}

	my $infile = File::Spec->catfile($self->{ImageFolder}, $self->{ObjectIDs}->get_chapter_resource_folder($chapter, 'images'), $imagefile);
	my $outfile = File::Spec->catfile($self->{OutputFolder}, $self->{OutputImageFolder}, $imagefile);

	my $ininfo = stat($infile);
	my $outinfo = stat($outfile);

	# Check that we haven't already tried to write an image of the same name.

	$self->{ImageList}->add_file_record($outfile, "image");

	if (!defined $ininfo) {
		die "Couldn't find imagefile file ", $imagefile, "\n";
	}

	my $convert = Image::Magick->new;
	my $x = $convert->ReadImage($infile);
	if ($x) {
		die $x."\n";
	}
	
	$x = $convert->Resize(geometry => $self->{MaxImageWidth}.'x>');
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

	print $file "<div class=\"titled\"";
	if (defined $id) {
		print $file " id=\"", $id, "\"";
	}
	print $file ">";
	print $file "<p><img src=\"", File::Spec::Unix->catfile($self->{ImagePrefix}, $imagefile), "\" class=\"responsive\" width=", $width," height=", $height,"></p>";
	if (defined $caption) {
		print $file "\n<p class=\"title\">", $caption, "</p>";
	};
	print $file "</div>\n\n";
}


##
# Process a download object and write it to the output.
#
# \param $download	The download object to be processed.
# \param $chapter	The parent chapter or index.
# \param $file		The file to write output to.

sub process_download {
	my ($self, $download, $chapter, $file) = @_;

	my $downloadfile = $download->findvalue('./@file');

	my $caption = undef;
	my $title = undef;
	my $id = $self->{ObjectIDs}->get_object_id($download);

	if (defined $id) {
		$caption = $download->findvalue('./@name');
	} else {
		$caption = "Download";
	}

	my $chapterfolder = File::Spec->catfile($self->{DownloadFolder}, $self->{ObjectIDs}->get_chapter_resource_folder($chapter, 'downloads'), $downloadfile);

	if (!-d $chapterfolder) {
		die "Couldn't find chapter download folder ", $downloadfile, "\n";
	}

	my $commonfolder = File::Spec->catfile($self->{DownloadFolder}, $self->{CommonDownloadFolder});

	if (!-d $commonfolder) {
		die "Couldn't find common download folder ", $self->{CommonDownloadFolder}, "\n";
	}

	if (defined $download->findvalue('./@title') && $download->findvalue('./@title') ne "") {
		$title = $download->findvalue('./@title');
	} else {
		$title = $downloadfile;
	}

	my $destinationfile = (File::Spec->catfile($self->{OutputFolder}, $self->{OutputDownloadFolder}, $downloadfile));
	$destinationfile .= ".zip";

	# Check that we haven't already tried to write a download of the same name.

	$self->{DownloadList}->add_file_record($destinationfile, "download");

	BuildZip::build_zip_file($destinationfile, $chapterfolder, $commonfolder);

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

	print $file "<div class=\"download\"";
	if (defined $id) {
		print $file " id=\"", $id, "\"";
	}
	print $file ">\n";
	print $file "<div class=\"title\">",$caption,"</div>\n";
	
	print $file "<div class=\"info\">The source code and files in this example are licenced under the EUPL v1.1.</div>\n";

	print $file "<div class=\"file\">";

	$self->write_icon_image($file, 'zip');
	if ($iyonix_ok) {
		$self->write_icon_image($file, 'armv7', 'compatibility');
	}
	if ($armv7_ok) {
		$self->write_icon_image($file, 'iyonix', 'compatibility');
	}
		
	print $file "<a href=\"", File::Spec::Unix->catfile($self->{DownloadPrefix}, $downloadfile), ".zip\" target=\"_blank\">", $title, "</a></div>\n";
	
	print $file "<div class=\"metadata\"><span class=\"metadata\">";
	print $file Formatting::get_filesize($filesize), " | ", Formatting::get_date(localtime($filedate));
	
	if ($compatibility ne "") {
		print $file "</span><span class=\"metadata-separator\">&nbsp;| </span><span class=\"metadata\">", $compatibility;
	}
		
	print $file "</span></div>\n";
	print $file "</div>\n\n";
}


##
# Write an image tag for an icon to the output file.
#
# \param $file		The file to write to.
# \param $icon		The internal image icon name.
# \param $class		If supplied, the CSS class name to apply to the image.

sub write_icon_image {
	my ($self, $file, $icon, $class) = @_;

	my ($filename, $width, $height, $alt) = $self->{IconDetails}->get_icon_details($icon);

	print $file "<img src=\"", $filename, "\" alt=\"", $alt, "\" width=", $width, " height=", $height;

	if (defined $class) {
		print $file " class=\"", $class, "\"";
	}

	print $file ">\n";
}

1;
