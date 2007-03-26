# -*- Perl -*-
#
# File:  PTools/SDF/Sort/Quick.pm
# Desc:  Sort an PTools::SDF::SDF object on the specified key field
# Date:  Thu Oct 14 10:30:00 1999
# Mods:  Wed May 09 10:59:60 2001
# Lang:  Perl 5.0
# Stat:  Prototype
# Note:  This module currently uses a SINGLE sort key only
#
# ToDo:  FIX "reverse" sorting, confirm "ignorecase" works
#

package PTools::SDF::Sort::Quick;
 require 5.001;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.07';
#@ISA     = qw( );


sub new {
   my($class) = @_;

   bless my $self = {}, $class;              # must allow polymorphism here
   $self->setError(0,"");                    # assume the best

   return $self;
}


sub sort {
  my($self,$sdfRef,$mode,@keys) = @_;

  $mode ||="";
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
  my($recCount) = $sdfRef->param;         # collect the record count
  my($c,$i,$j,%sortInt,$len,$dec,$idx,$format,@chk);
  #______________________________________
  # Try to guess if we should use numeric or string comparisons 
  # for sorting. If we don't have at least two recs, there isn't 
  # much need to sort anything! For each sort key, check the
  # field in both record 0 and record 1. This routine should 
  # work for both integer and decimal numbers. We end up with
  # an array of flags that corresponds to REVERSE of "@keys".
  #
  $^W=0;
  foreach my $field (@keys) {
     $chk[0] = $sdfRef->param(0,$field);
     $chk[1] = $sdfRef->param(1,$field);
     if ( $chk[0] eq $chk[0] + 0         # compare in both 
     &&   $chk[1] eq $chk[1] + 0 ) {     # rec 0 and rec 1
       $sortInt{$field} = "True";
     }
  }
  $^W=1;
  #______________________________________
  # Reverse the "@keys" array to sort from least to most significant keys.
  # Note this is NOT the same as reversing the sort; see "$mode" variable.
  #
##@keys  = reverse @keys;            # put sort keys in reverse order
  my $lo = 0;
  my $hi = $recCount;

  ## FIX: allow for multiple sort keys

  $self->quickSort($sdfRef, $lo, $hi, $keys[0], $sortInt{$keys[0]});

  return;
}

#
# The following was adapted from 
# http://java.sun.com/applets/jdk/1.1/demo/SortDemo/QSortAlgorithm.java
#

sub quickSort {
  my($self, $sdfRef, $lo0, $hi0, $field, $sortInt) = @_;

  my $lo = $lo0;
  my $hi = $hi0;
  my $mid;

 if ( $hi0 > $lo0 ) {

   $mid = $sdfRef->{_Data_}[ int(( $lo0 + $hi0 ) / 2) ];  # arbitrary mid-point

   while ( $lo <= $hi ) {
     if ($sortInt) {
        while(( $lo < $hi0 ) && ( $sdfRef->{_Data_}[$lo]{$field} < $mid->{$field})) { 
          ++$lo; }
        while(( $hi > $lo0 ) && ( $sdfRef->{_Data_}[$hi]{$field} > $mid->{$field})) {
          --$hi; }
     } else {
        while(( $lo < $hi0 ) && ( $sdfRef->{_Data_}[$lo]{$field} lt $mid->{$field})) {
          ++$lo; }
        while(( $hi > $lo0 ) && ( $sdfRef->{_Data_}[$hi]{$field} gt $mid->{$field})) {
          --$hi; }
     }
     if ( $lo <= $hi ) {
       $self->_swapPointers( $sdfRef, $lo, $hi);
       ++$lo;
       --$hi;
     }
   } # end of while ( $lo <= $hi )

   if ( $lo0 < $hi ) {
     $self->quickSort( $sdfRef, $lo0, $hi, $field, $sortInt );
   }
   if ( $lo < $hi0 ) {
     $self->quickSort( $sdfRef, $lo, $hi0, $field, $sortInt );
   }

 } # end of if ( $hi0 > $lo 0 )

 return;
}

#______________________________________
# Subroutine to swap the record pointers
#
sub _swapPointers {
     my($self,$sdfRef,$i,$j) = @_;

     ($sdfRef->{_Data_}[$i], $sdfRef->{_Data_}[$j]) =
     ($sdfRef->{_Data_}[$j], $sdfRef->{_Data_}[$i]);

     return;
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

#  ___________________________________________________________________________
# |                                                                           |
# | Sub: sort                                                                 |
# | Dsc: Sort existing data array                                             |
# | Arg: $mode, @keys    (array of field name(s) to use as sort keys)         |
# | Ret: n/a      (records in reference are now sorted array)                 |
# |                                                                           |
# | Recognized "modes" are                                                    |
# | .  reverse     -  Reverse sort order                                      |
# | .  ignoreCase  -  Ignore upper/lower case when sorting ("ignore" ok too)  |
# | These two are not exclusive. Simply put both in the "$mode" string.       |
# |                                                                           |
# |    "reverse:ignore"                                                       |
# |___________________________________________________________________________|


# http://java.sun.com/applets/jdk/1.1/demo/SortDemo/QSortAlgorithm.java

/**
 * A quick sort demonstration algorithm
 * SortAlgorithm.java
 *
 * @author James Gosling
 * @author Kevin A. Smith
 * @version     @(#)QSortAlgorithm.java 1.3, 29 Feb 1996
 */
public class QSortAlgorithm extends SortAlgorithm 
{

    /**
     * A version of pause() that makes it easier to ensure that we pause
     * exactly the right number of times.
     */
    private boolean pauseTrue(int lo, int hi) throws Exception {
        super.pause(lo, hi);
        return true;
    }

   /** This is a generic version of C.A.R Hoare's Quick Sort 
    * algorithm.  This will handle arrays that are already
    * sorted, and arrays with duplicate keys.<BR>
    *
    * If you think of a one dimensional array as going from
    * the lowest index on the left to the highest index on the right
    * then the parameters to this function are lowest index or
    * left and highest index or right.  The first time you call
    * this function it will be with the parameters 0, a.length - 1.
    *
    * @param a       an integer array
    * @param lo0     left boundary of array partition
    * @param hi0     right boundary of array partition
    */
   void QuickSort(int a[], int lo0, int hi0) throws Exception
   {
      int lo = lo0;
      int hi = hi0;
      int mid;

      if ( hi0 > lo0)
      {

         /* Arbitrarily establishing partition element as the midpoint of
          * the array.
          */
         mid = a[ ( lo0 + hi0 ) / 2 ];

         // loop through the array until indices cross
         while( lo <= hi )
         {
            /* find the first element that is greater than or equal to 
             * the partition element starting from the left Index.
             */
             while( ( lo < hi0 ) && pauseTrue(lo0, hi0) && ( a[lo] < mid ))
                 ++lo;

            /* find an element that is smaller than or equal to 
             * the partition element starting from the right Index.
             */
             while( ( hi > lo0 ) && pauseTrue(lo0, hi0) && ( a[hi] > mid ))
                 --hi;

            // if the indexes have not crossed, swap
            if( lo <= hi ) 
            {
               swap(a, lo, hi);
               ++lo;
               --hi;
            }
         }

         /* If the right index has not reached the left side of array
          * must now sort the left partition.
          */
         if( lo0 < hi )
            QuickSort( a, lo0, hi );

         /* If the left index has not reached the right side of array
          * must now sort the right partition.
          */
         if( lo < hi0 )
            QuickSort( a, lo, hi0 );

      }
   }

   private void swap(int a[], int i, int j)
   {
      int T;
      T = a[i]; 
      a[i] = a[j];
      a[j] = T;

   }

   public void sort(int a[]) throws Exception
   {
      QuickSort(a, 0, a.length - 1);
   }
}

=head1 NAME

SDF::Sort::Quick - Sort an PTools::SDF::SDF object on a specified key field

=head1 VERSION

This document describes version 0.07, released March, 2005.

=head1 SYNOPSIS

     use PTools::SDF::SDF;       # or any subclass thereof, including:
     use PTools::SDF::ARRAY;
     use PTools::SDF::IDX;
     use PTools::SDF::DIR;
     use PTools::SDF::DSET;

     $sdfObj = new PTools::SDF::SDF( $fileName );

     $sdfObj->extend( "sort", "PTools::SDF::Sort::Quick" );

     $sdfObj->sort( $mode, $keyField );

     ($stat,$err) = $sdfObj->status;

     $stat and die $err;


=head1 DESCRIPTION

This sort class is one of several I<extended> classes used to select
which algorithm is employed to sort data in the calling object. It
is up to the client script to select the specific algorithm, as shown
in the B<Synopsis> section, above. 

By default this class will B<not> be used to sort the data. This sort
sort classe must specified via the B<extend> method in B<PTools::SDF::SDF>.

The tradeoff is I<flexibility> vs I<performance>. This by far the 'highest
speed' sort algorithm; however, it is 'not very flexible.' 
For files containing no more than 100 records, all of the sort modules
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

=item sort ( [ Mode ], KeyField )

As shown in the B<Synopsis> section, above, objects of this class are
not accessed directly. Make a call to this method I<through> the
containing object where the unsorted data resides.

This class will attempt to determine whether numeric or character
sorting should occur for each of the B<KeyField> passed, based on
the values in the first two records in the object containing data.

At least two records must exist in the containing B<PTools::SDF::SDF> object
or an exception is generated.

=over 4

=item Mode

The B<Mode> parameter is not used by this class. It is included in
the interface definition to keep the various sort modules as
polymorphic as possible.


=item KeyField

Only a single B<KeyField> may be specified when using this sort class.
The key is specified using the same I<field names> as are used within
the B<PTools::SDF::SDF> object.

If no key field is passed, an exception is generated.

=back

Example:

     use PTools::SDF::IDX;

     $idxObj = new PTools::SDF::IDX( "/etc/passwd" );

     $sdfObj->extend( "sort", "PTools::SDF::Sort::Quick" );

     $sdfObj->sort( undef, "uname" );

     ($stat,$err) = $sdfObj->status;

     $stat and die $err;

For this example, the B<extend> method must be called prior to invoking
the B<sort> method. Otherwise the default B<PTools::SDF::Sort::Bubble> class
is used.

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


=item sort ( SdfRef [, Mode ], KeyField )

The B<SdfRef> is a reference to the actual B<PTools::SDF::SDF> object, or subclass. 
This is passed as the first parameter to give this object access to the data
to be sorted.

The other parameters are the same as explained above.

=back


=head1 INHERITANCE

None currently.

=head1 SEE ALSO

Other I<extended> sort classes are available.
L<PTools::SDF::Sort::Bubble>,
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

Adapted from I<A quick sort demonstration algorithm> B<SortAlgorithm.java>
(version QSortAlgorithm.java 1.3, 29 Feb 1996) by James Gosling and
Kevin A. Smith.

=head1 COPYRIGHT

Copyright (c) 1997-2007 by Chris Cobb. All rights reserved.
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
