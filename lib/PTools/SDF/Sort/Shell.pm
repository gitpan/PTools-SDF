# -*- Perl -*-
#
# File:  PTools/SDF/Sort/Shell.pm
# Desc:  Sort an PTools::SDF::SDF object on the specified key field
# Date:  Thu Oct 14 10:30:00 1999
# Mods:  Wed May 09 10:59:60 2001
# Lang:  Perl 5.0
# Stat:  Prototype
# Note:  This module currently allows a SINGLE sort key only
#

package PTools::SDF::Sort::Shell;
 require 5.001;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.06';
#@ISA     = qw( );


sub new {
   my($class,$fileName,$mode,@fields) = @_;

   bless my $self = {}, $class;              # must allow polymorphism here
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
  my($c,$i,$j,%sortInt,$len,$dec,$idx,$format,@chk);
  #______________________________________
  # Try to guess if we should use numeric or string comparisons for sorting. 
  # If we don't have at least two recs, there isn't much need to sort anything!
  # For each sort key, check the field in both record 0 and record 1. This 
  # routine should work for both integer and decimal numbers. We end up with
  # an array of flags that corresponds to REVERSE of "@keys".
  #
  $^W=0;
  foreach my $field (@keys) {
     $chk[0] = $sdfRef->param(0,$field);
     $chk[1] = $sdfRef->param(1,$field);
     if ( $chk[0] eq $chk[0] + 0        # compare in both 
     &&   $chk[1] eq $chk[1] + 0 ) {    # rec 0 and rec 1
       $sortInt{$field} = 1;
     }
  }
  $^W=1;
  #______________________________________
  # Reverse the "@keys" array as we need to sort from the least significant
  # key to the most significant. The "@sortInt" array is already reversed.
  # Note this is NOT the same as reversing the sort; see "$mode" variable.
  # FIX: allow for multiple sort keys ...
  #
##@keys  = reverse @keys;            # put sort keys in reverse order
  my $field = $keys[0];              # FIX: allow for multiple sort keys

  my($I,$J,$K,$N,$S,$T,$swap);
  #
  # Adapted from "Business Basic" by Bent and Sethares, pg. 116
  #
  $N = $recCount;
  $S = $N;
Sort:
  $S = int( $S / 2 );

  goto End if $S < 1;

  for( $K = 0; $K <= $S; $K++ ) {

     for ( $I = $K; $I <= $N - $S; $I += $S ) {

        $J = $I;
        $T = $sdfRef->{_Data_}[ $I + $S ];
Resort:
        $swap = 0;
	if ($sortInt{$field}) {
	   if ($mode =~ /rev(erse)?/i) {
	     $swap = 1 if $T->{$field} > $sdfRef->{_Data_}[$J]{$field};
	   } else {
	     $swap = 1 if $T->{$field} < $sdfRef->{_Data_}[$J]{$field};
	   }
	} elsif ($mode =~ /ignore(case)?/i) {
	   if ($mode =~ /rev(erse)?/i) {
	     $swap = 1 if lc $T->{$field} gt lc $sdfRef->{_Data_}[$J]{$field};
	   } else {
	     $swap = 1 if lc $T->{$field} lt lc $sdfRef->{_Data_}[$J]{$field};
	   }
	} else {
	   if ($mode =~ /rev(erse)?/i) {
	     $swap = 1 if $T->{$field} gt $sdfRef->{_Data_}[$J]{$field};
	   } else {
	     $swap = 1 if $T->{$field} lt $sdfRef->{_Data_}[$J]{$field};
	   }
	}
	if ($swap) {
           $sdfRef->{_Data_}[ $J + $S ] = $sdfRef->{_Data_}[ $J ];
           $J -= $S;
           goto Resort if $J >= 0;
        }
        $sdfRef->{_Data_}[ $J + $S ] = $T;

     } # end for ( $I = $K; $I <= $N - $S; $I += $S ) {

   } # end for( $K = 0; $K <= $S; $K++ ) {
   goto Sort;
End:

   return;
} # end of sort subroutine


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


# From "Business Basic" by Bent and Sethares, pg. 116

 500 REM  ShellSort
 510 REM  Sort array A in ascending order
 520 LET S = N
>530 LET S = INT(S/2)
 540 IF S < 1 THEN 670
 550 FOR K = 1 TO S
 560    FOR I = K TO N - S STEP S
 570       LET J = I
 580       LET T = A(I+S)
>590       IF T>= A(J) then 630
 600       LET A(J+S) = A(J)
 610       LET J = J - S
 620       IF J >= 1 then 590
>630       LET A(J+S) = T
 640    NEXT I
 650 NEXT K
 660 GOTO 530
>670 REM  List is now sorted

=head1 NAME

SDF::Sort::Shell - Sort an PTools::SDF::SDF object on a specified key field

=head1 VERSION

This document describes version 0.06, released March, 2005.

=head1 SYNOPSIS

     use PTools::SDF::SDF;       # or any subclass thereof, including:
     use PTools::SDF::ARRAY;
     use PTools::SDF::IDX;
     use PTools::SDF::DIR;
     use PTools::SDF::DSET;

     $sdfObj = new PTools::SDF::SDF( $fileName );

     $sdfObj->extend( "sort", "PTools::SDF::Sort::Shell" );

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

The tradeoff is I<flexibility> vs I<performance>. This is a 'medium
speed' sort algorithm that is also 'moderately flexible.' 
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

The B<Mode> parameter is one of the following strings, used to control
the behavior of the Shell Sort algorithm used by this class.

 rev     reverse      - to sort in reverse order
 ignore  ignorecase   - ignore case sensitivity during the sort

Any combination of the above may be used

 rev:ignorecase

Using I<reverse> sorting with multiple B<KeyField> should be 'experimented
with' to ensure the desired results are obtained.

=item KeyField

Only a single B<KeyField> may be specified when using this sort class.
The key is specified using the same I<field names> as are used within
the B<PTools::SDF::SDF> object.

If no key field is passed, an exception is generated.

=back

Example:

     use PTools::SDF::IDX;

     $idxObj = new PTools::SDF::IDX( "/etc/passwd" );

     $sdfObj->extend( "sort", "PTools::SDF::Sort::Shell" );

     $sdfObj->sort( undef, "uname" );

     ($stat,$err) = $sdfObj->status;

     $stat and die $err;

For this example, the B<extend> method must be called prior to invoking
the B<sort> method. Otherwise the default B<PTools::SDF::Sort::Bubble> 
class is used.

Of course, this just an example. It would be appropriate to use the
B<PTools::SDF::File::Passwd> class instead as this provides additional 
methods for manipulating password file data.

=back


=head2 Private Methods

The actual calling syntax for module designers is documented here. This is
the syntax used when invoking this method from withn the I<extended>
B<sort> method of the B<PTools::SDF::SDF> class only.

The B<user interface> of this B<sort> method is shown in the preceeding 
section.

=over 4


=item sort ( SdfRef [, Mode ], KeyField )

The B<SdfRef> is a reference to the actual B<PTools::SDF::SDF> object, 
or subclass.  This is passed as the first parameter to give this object 
access to the data to be sorted.

The other parameters are the same as explained above.

=back


=head1 INHERITANCE

None currently.

=head1 SEE ALSO

Other I<extended> sort classes are available.
See
L<PTools::SDF::Sort::Bubble>,
L<PTools::SDF::Sort::Quick> and
L<PTools::SDF::Sort::Random>.

Also see
L<PTools::SDF::Overview>, 
L<PTools::SDF::ARRAY>, L<PTools::SDF::CSV>,  L<PTools::SDF::DB>,
L<PTools::SDF::DIR>,   L<PTools::SDF::DSET>, L<PTools::SDF::File>, 
L<PTools::SDF::IDX>,   L<PTools::SDF::INI>,  L<PTools::SDF::SDF>,
L<PTools::SDF::TAG>    and L<PTools::SDF::Lock::Advisory>.

=head1 AUTHOR

Chris Cobb, E<lt>nospamplease@ccobb.netE<gt>

Adapted from a Shell Sort algorithm in the book I<Business Basic> 
by Bent and Sethares, pg. 116

=head1 COPYRIGHT

Copyright (c) 1997-2007 by Chris Cobb. All rights reserved.
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
