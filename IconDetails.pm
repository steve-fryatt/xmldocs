#!/usr/bin/perl -w

# Copyright 2015-2021, Stephen Fryatt (info@stevefryatt.org.uk)
#
# This file is part of XML Docs:
#
#   http://www.stevefryatt.org.uk/software/
#
# Licensed under the EUPL, Version 1.2 only (the "Licence");
# You may not use this work except in compliance with the
# Licence.
#
# You may obtain a copy of the Licence at:
#
#   http://joinup.ec.europa.eu/software/page/eupl
#
# Unless required by applicable law or agreed to in
# writing, software distributed under the Licence is
# distributed on an "AS IS" basis, WITHOUT WARRANTIES
# OR CONDITIONS OF ANY KIND, either express or implied.
#
# See the Licence for the specific language governing
# permissions and limitations under the Licence.

package IconDetails;

use strict;
use warnings;

##
# Construct a new Icon Details instance.
#
# \param $manual	The manual to record the icons from.
sub new {
	my ($class, $manual) = @_;

	my $self = {};

	bless($self, $class);

	$self->{icons} = {}; 

	foreach my $icon ($manual->findnodes('/manual/icons/*')) {
		$self->store_icon_details($icon);
	}

	return $self;
}


##
# Store details of an icon's image file.
#
# \param $icon		The icon object to be processed.

sub store_icon_details {
	my ($self, $icon) = @_;

	my $name = $icon->nodeName();

	if (exists $self->{icons}{$name}) {
		die "Duplicate icon details ", $name, ".\n";
	}

	$self->{icons}{$name} = {
		'file' => $icon->to_literal,
		'alt' => $icon->findvalue('./@alt'),
		'width' => $icon->findvalue('./@width'),
		'height' => $icon->findvalue('./@height')
	};
}


##
# Return details for an icon's image file.
#
# \param $name		The name of the icon to return.
# \return		An array of (name, width, height, alt).

sub get_icon_details {
	my ($self, $name) = @_;

	if (!exists $self->{icons}{$name}) {
		die "Icon details not found for ", $name, ".\n";
	}

	return ($self->{icons}{$name}{'file'}, $self->{icons}{$name}{'width'}, $self->{icons}{$name}{'height'}, $self->{icons}{$name}{'alt'});
}

1;

