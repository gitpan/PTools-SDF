# -*- Perl -*-
#
# File:  PTools/SDF/Sort/Bubble.pm
# Desc:  Sort an PTools::SDF::SDF object on specified key field(s)
# Date:  Thu Oct 14 10:30:00 1999
# Mods:  Wed May 09 10:59:60 2001
# Lang:  Perl 5.0
# Stat:  Prototype
#

package PTools::SDF::Sort::Bubble;
 require 5.001;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.08';
#@ISA     = qw( );


sub new {
   my($class) = @_;

   my $self = {};                            # use hash array
   bless $self, ref($class)||$class;         # allow polymorphism
   $self->setError(0,"");                    # assume the best

   return $self;
}


sub sort {
  my($self,$sdfRef,$mode,@keys) = @_;

  $mode ||= "";
  #______________________________________
  # Can only sort "PTools::SDF::SDF" objects, 
  # and only if we have more than 1 rec,
  # and only if we have at least 1 sort key.
  #
  $self->setError(0,"");
  my $err = "";
       if (! ref $sdfRef)              { $err = "Required sort object missing";
  } elsif (! $sdfRef->isa("PTools::SDF::SDF")) { $err = "Unknown object '$sdfRef'";
  } elsif (! $sdfRef->hasData)         { $err = "Can't sort empty 'SDF' object";
  } elsif (! $sdfRef->isSortable)      { $err = "Not enough records to sort";
  } elsif (! @keys)                    { $err = "No sort keys specified";     }

  if ($err) {
     $err .= " in '$PACK'";
     $self->setError(-1,$err);
     return( wantarray ? (-1,$err) : (-1) );
  }
  (@keys) = split(':',$keys[0]) if $#keys == 0;   # colon separated string?
  #______________________________________
  #
  my($recCount) = $sdfRef->param;       # collect the record count
  my($c,$i,$j,$tmpPtr,@sortInt,$len,$dec,$idx,$format,@chk);
  #______________________________________
  # Determine if we should use numeric or string comparisons 
  # for sorting. If we don't have at least two recs, there isn't 
  # much need to sort anything! For each sort key, check the
  # field in both record 0 and record 1. This routine should 
  # work for both integer and decimal numbers. We end up with
  # an array of flags that corresponds to REVERSE of "@keys".
  #
  $c=$#keys;
  $^W=0;
  foreach my $field (@keys) {
    $chk[0] = $sdfRef->param(0,$field);
    $chk[1] = $sdfRef->param(1,$field);
    if ( $chk[0] eq $chk[0] + 0         # compare in both 
    &&   $chk[1] eq $chk[1] + 0 ) {     # rec 0 and rec 1
      $sortInt[$c] = "True";
    }
    $c--;
  }
  $^W=1;
  #______________________________________
  # A bubble sort (even single key) will get *very* slow with large files.
  # This isn't the *end* of the world as our files are small (so far!) and
  # we are just swapping the *pointers* to each record, not the actual data.
  #
  # Reverse the "@keys" array as we need to sort from the least significant
  # key to the most significant. The "@sortInt" array is already reversed.
  # Note this is NOT the same as reversing the sort; see "$mode" variable.
  #
  $mode ||= "";
  @keys = reverse @keys;            # put sort keys in reverse order

  local($^W)=0;

  for ($i=0; $i < $recCount; $i++) {
    for ($j=0; $j < $recCount - $i; $j++) {
      $c = 0;
      foreach my $field (@keys) {         # sort on EACH of our key fields
        if ($sortInt[$c++]) {
   	   if ($mode =~ /rev(erse)?/i) {
              if ($sdfRef->{_Data_}[$j]{$field} < $sdfRef->{_Data_}[$j + 1]{$field}) {
                $self->_swapPointers( $sdfRef, $i,$j );
              }
	   } else {
              if ($sdfRef->{_Data_}[$j]{$field} > $sdfRef->{_Data_}[$j + 1]{$field}) {
                $self->_swapPointers( $sdfRef, $i,$j );
              }
	   }
        } elsif ($mode =~ /ignore(case)?/i) {
   	   if ($mode =~ /rev(erse)?/i) {
              if (lc $sdfRef->{_Data_}[$j]{$field} lt lc $sdfRef->{_Data_}[$j + 1]{$field}) {
                $self->_swapPointers( $sdfRef, $i,$j );
              }
	   } else {
              if (lc $sdfRef->{_Data_}[$j]{$field} gt lc $sdfRef->{_Data_}[$j + 1]{$field}) {
                $self->_swapPointers( $sdfRef, $i,$j );
              }
	   }
        } else {
	   if ($mode =~ /rev(erse)?/i) {
              if ($sdfRef->{_Data_}[$j]{$field} lt $sdfRef->{_Data_}[$j + 1]{$field}) {
                $self->_swapPointers( $sdfRef, $i,$j );
              }
	   } else {
              if ($sdfRef->{_Data_}[$j]{$field} gt $sdfRef->{_Data_}[$j + 1]{$field}) {
                $self->_swapPointers( $sdfRef, $i,$j );
              }
	   }
        }
      } # end of foreach $field
    }
  }
  return;
}
#______________________________________
# Subroutine to swap the record pointers
#
sub _swapPointers {
  my($self,$sdfRef,$i,$j) = @_;
  my $tmpPtr = $sdfRef->{_Data_}[$j];
  $sdfRef->{_Data_}[$j] = $sdfRef->{_Data_}[$j + 1];
  $sdfRef->{_Data_}[$j + 1] = $tmpPtr;
}

sub setError {
  return( $_[0]->{'status'}=($_[1]||""), $_[0]->{'error'}=($_[2]||"") );
}

sub getError {
  return($_[0]->{'status'}, $_[0]->{'error'}) if wantarray;
  return $_[0]->{'error'};
}
1;

__END__

=head1 NAME

SDF::Sort::Bubble - Sort an PTools::SDF::SDF object on specified key field(s)

=head1 VERSION

This document describes version 0.08, released March, 2005.

=head1 SYNOPSIS

     use PTools::SDF::SDF;       # or any subclass thereof, including:
     use PTools::SDF::ARRAY;
     use PTools::SDF::IDX;
     use PTools::SDF::DIR;
     use PTools::SDF::DSET;

     $sdfObj = new PTools::SDF::SDF( $fileName );

     $sdfObj->extend( "sort", "PTools::SDF::Sort::Bubble" );

     $sdfObj->sort( $mode, @keyFields );

     ($stat,$err) = $sdfObj->status;

     $stat and die $err;


=head1 DESCRIPTION

This sort class is one of several I<extended> classes used to select
which algorithm is employed to sort data in the calling object. It
is up to the client script to select the specific algorithm, as shown
in the B<Synopsis> section, above. 

By default this class will be used to sort the data, unless one of the
other sort classes is specified via the B<extend> method in B<PTools::SDF::SDF>.

The tradeoff is I<flexibility> vs I<performance>. This is by far the
slowest sort algorithm but is also the most flexible. Even so, for
files containing no more than 100 records, all of the sort modules
are roughly equivalent in speed.


=head2 Constructor

=over 4

=item new

Note that this is not intended to be a public method. It is only invoked
by objects of the B<PTools::SDF::SDF> class, or any subclasses thereof.
Objects of this class are not intended for direct access, but only
indirectly through the containing object.

=back


=head2 Public Methods

The B<interface> of this B<sort> method is documented here. This is
the intended usage for clients of the B<PTools::SDF::*> class of objects.

The actual calling syntax for module designers is shown in the following
section, below.

=over 4

=item sort ( [ Mode ], KeyFields )

As shown in the B<Synopsis> section, above, objects of this class are
not accessed directly. Make a call to this method I<through> the
containing object where the unsorted data resides.

This class will attempt to determine whether numeric or character
sorting should occur for each of the B<KeyFields> passed, based on
the values in the first two records in the object containing data.

At least two records must exist in the containing B<PTools::SDF::SDF> object
or an exception is generated.

=over 4

=item Mode

The B<Mode> parameter is one of the following strings, used to control
the behavior of the Bubble Sort algorithm used by this class.

 rev     reverse      - to sort in reverse order
 ignore  ignorecase   - ignore case sensitivity during the sort

Any combination of the above may be used

 rev:ignorecase

Using I<reverse> sorting with multiple B<KeyFields> should be 'experimented
with' to ensure the desired results are obtained.

=item KeyFields

One or more B<KeyFields> may be specified when using this sort class.
Keys are specified using the same I<field names> as are used within
the B<PTools::SDF::SDF> object.

Keys can be passed either in a simple array or as a colon separated list.

At least one key field must be passed or an exception is generated.

=back

Example:

     use PTools::SDF::IDX;

     $idxObj = new PTools::SDF::IDX( "/etc/passwd" );

     $sdfObj->sort( undef, "uname" );

     ($stat,$err) = $sdfObj->status;

     $stat and die $err;

Of course, this just an example. It would be appropriate to use the
B<PTools::SDF::File::Passwd> class instead as this provides additional methods
for manipulating password file data.

=back


=head2 Private Methods

The actual calling syntax for module designers is documented here. This is
the syntax used when invoking this method from withn the I<extended>
B<sort> method of the B<PTools::SDF::SDF> class only.

The B<user interface> of this B<sort> method is shown in the preceeding 
section.

=over 4


=item sort ( SdfRef [, Mode ], KeyFields )

The B<SdfRef> is a reference to the actual B<PTools::SDF::SDF> object, or subclass. 
This is passed as the first parameter to give this object access to the data
to be sorted.

The other parameters are the same as explained above.

=back


=head1 INHERITANCE

None currently.

=head1 SEE ALSO

Other I<extended> sort classes are available.
See
L<PTools::SDF::Sort::Quick>,
L<PTools::SDF::Sort::Random> and
L<PTools::SDF::Sort::Shell>.

Also see
L<PTools::SDF::Overview>,
L<PTools::SDF::ARRAY>, L<PTools::SDF::CSV>,  L<PTools::SDF::DB>,
L<PTools::SDF::DIR>,   L<PTools::SDF::DSET>, L<PTools::SDF::File>,
L<PTools::SDF::IDX>,   L<PTools::SDF::INI>,  L<PTools::SDF::SDF>,
L<PTools::SDF::TAG>    and L<PTools::SDF::Lock::Advisory>.

=head1 AUTHOR

Chris Cobb, E<lt>nospamplease@ccobb.netE<gt>

=head1 COPYRIGHT

Copyright (c) 1997-2007 by Chris Cobb. All rights reserved.
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
