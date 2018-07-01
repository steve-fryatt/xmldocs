#!/usr/bin/perl -w

package ObjectIDs;

use strict;
use warnings;

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

	my $id = get_object_id($object);
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

	return exists $ObjectIDs{$id};
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

1;

