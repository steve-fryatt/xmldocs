#!/usr/bin/perl -w

package ObjectIDs;

use strict;
use warnings;

use XML::LibXML;

use constant TRUE	=> 1;
use constant FALSE	=> 0;

##
# Construct a new Object IDs instance.
#
# \param $manual	The manual to record the icons from.
sub new {
	my ($class, $manual) = @_;

	my $self = {};

	bless($self, $class);

	$self->{object_ids} = {}; 

	return $self;
}


##
# Scan through the manual, creating name attributes for each applicable object
# with sequential numbers and storing any IDs in the %ObjectIDs hash for future
# use.
#
# \param $manual	The manual to be scanned.

sub link_document {
	my ($self, $manual) = @_;

	print "Linking document...\n";

	my $number = 1;

	foreach my $chapter ($manual->findnodes('./manual/index|./manual/chapter')) {
		my $chapter_number = 0;
		if ($chapter->nodeName() eq "chapter") {
			$chapter_number = $number++;
		} elsif ($chapter->nodeName() eq "index") {
		}

		$self->store_object_id($chapter, undef, "Chapter " . $chapter_number);

		my $section_number = 1;
		my $code_number = 1;
		my $image_number = 1;
		my $table_number = 1;
		my $download_number = 1;

		foreach my $section ($chapter->findnodes('./section')) {
			$self->store_object_id($section, $chapter, "Section " . $chapter_number . "." . $section_number);

			foreach my $object ($section->findnodes('./code|./image|./table|./download')) {
				if ($object->nodeName() eq "code") {
					if ($self->store_object_id($object, $chapter, "Listing " . $chapter_number . "." . $code_number)) {
						$code_number++;
					}
				} elsif ($object->nodeName() eq "image") {
					if ($self->store_object_id($object, $chapter, "Figure " . $chapter_number . "." . $image_number)) {
						$image_number++;
					}
				} elsif ($object->nodeName() eq "table") {
					if ($self->store_object_id($object, $chapter, "Table " . $chapter_number . "." . $table_number)) {
						$table_number++;
					}
				} elsif ($object->nodeName() eq "download") {
					if ($self->store_object_id($object, $chapter, "Download " . $chapter_number . "." . $download_number)) {
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
# \return		TRUE if successful; FALSE on failure.

sub store_object_id {
	my ($self, $object, $chapter, $name) = @_;

	my $id = $self->get_object_id($object);
	if (!defined $id) {
		return FALSE;
	}

	if (exists $self->{object_ids}{$id}) {
		die "Duplicate object id ", $id, ".\n";
	}

	$object->setAttribute('name', $name);

	$self->{object_ids}{$id} = {
		'object' => $object,
		'chapter' => $chapter
	};

	return TRUE;
}


##
# Test to see if an object with a given ID exists in the list of known IDs.
#
# \param $id		The object ID to test.
# \return		TRUE of the object is found; otherwise FALSE.

sub object_exists {
	my ($self, $id) = @_;

	return exists $self->{object_ids}{$id};
}


##
# Return the object associated with a given ID.
#
# \param $id		The ID of the object to return.
# \return		The object, or undef.

sub get_object {
	my ($self, $id) = @_;

	if (!$self->object_exists($id)) {
		return undef;
	}

	return $self->{object_ids}{$id}->{'object'};
}


##
# Return the parent chapter associated with a given ID, or undef if the
# object is a chapter.
#
# \param $id		The ID of the object to return.
# \return		The parent chapter, or undef.

sub get_chapter {
	my ($self, $id) = @_;

	if (!$self->object_exists($id)) {
		return undef;
	}

	return $self->{object_ids}{$id}->{'chapter'};
}


##
# Get the reference ID for an object. If one hasn't been defined, undef is
# returned instead.
#
# \param $object	The object to return the ID for.
# \return		The object's ID, or undef if none has been defined.

sub get_object_id {
	my ($self, $object) = @_;

	$self->validate_object_type($object, "reference", "index", "chapter", "section", "code", "image", "table", "download");

	my $id = $object->findvalue('./@id');

	if ($id eq "") {
		$id = undef;
	}

	return $id;
}


##
# Find the chapter before a given chapter.
#
# \param $chapter	The chapter to look up from.
# \return		The previous chapter, or undef if none.

sub find_previous_chapter {
	my ($self, $chapter) = @_;

	$self->validate_object_type($chapter, "chapter");

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
	my ($self, $chapter) = @_;

	$self->validate_object_type($chapter, "chapter");

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
	my ($self, $chapter) = @_;

	$self->validate_object_type($chapter, "chapter", "index");

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
	my ($self, $chapter, $number, $full) = @_;

	$self->validate_object_type($chapter, "chapter");

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
	my ($self, $chapter, $resource) = @_;

	$self->validate_object_type($chapter, "chapter", "index");

	my $folder = '';

	if ($resource eq 'images') {
		$folder = $self->get_value($chapter, './resources/images', '');
	} elsif ($resource eq 'downloads') {
		$folder = $self->get_value($chapter, './resources/downloads', '');
	}

	return $folder;
}


##
# Test the type of an object to see if it's one contained in an acceptable
# list. If the object's type isn't in the list, the subroutine exits via
# die() and does not return.
#
# \param $object	The object to test.
# \param @types		A list of acceptable types.

sub validate_object_type {
	my ($self, $object, @types) = @_;

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
# Return the value of an XML node.
#
# \param $object	The XML object to read from.
# \param $name		The name of the node to be returned.
# \param $default	A default value to return; omit to use undef.
# \return		The value read.

sub get_value {
	my ($self, $object, $name, $default) = @_;

	if ($object->findvalue("count(" . $name . ")") > 1) {
		die("No unique ", $name, " found.\n");
	}

	my $value = $object->findvalue($name);

	if (!defined $value) {
		$value = $default;
	}

	return $value;
}

1;

