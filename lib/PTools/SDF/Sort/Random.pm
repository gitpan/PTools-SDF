# -*- Perl -*-
#
# File:  PTools/SDF/Sort/Random.pm
# Desc:  Sort an PTools::SDF::SDF object in random order
# Date:  Wed Mar 09 15:41:40 2005
# Lang:  Perl 5.0
# Stat:  Prototype
#

package PTools::SDF::Sort::Random;
 require 5.001;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.01';
#@ISA     = qw( );


sub new {
   my($class) = @_;

   my $self = {};                            # use hash array
   bless $self, ref($class)||$class;         # allow polymorphism
   $self->setError(0,"");                    # assume the best

   return $self;
}


sub sort {
  my($self,$sdfRef) = @_;

  #______________________________________
  # Can only sort "PTools::SDF::SDF" objects, 
  # and only if we have more than 1 rec,
  #
  $self->setError(0,"");
  my $err = "";
       if (! ref $sdfRef)              { $err = "Required sort object missing";
  } elsif (! $sdfRef->isa("PTools::SDF::SDF")) { $err = "Unknown object '$sdfRef'";
  } elsif (! $sdfRef->hasData)         { $err = "Can't sort empty 'SDF' object";
  } elsif (! $sdfRef->isSortable)      { $err = "Not enough records to sort"; }

  if ($err) {
     $err .= " in '$PACK'";
     $self->setError(-1,$err);
     return( wantarray ? (-1,$err) : (-1) );
  }
  #______________________________________
  # Simple randomization algorithm:
  # o  foreach record in the PTools::SDF::SDF object:
  #    .  skip record, if current record has already been swapped
  #    .  generate a random number between zero and <record_count>
  #    .  keep generating numbers until number != <current_record>
  #    .  swap <current_record> with the generated <record_number>

  my($recCount) = $sdfRef->param;       # collect the record count
  my($i,$j,$swapped) = (0,0,{});

  for ($i=0; $i <= $recCount; $i++ ) {

      next if (defined $swapped->{$i});

      $j = $i;
      while ($j == $i) { $j = int(rand( $recCount )) }

      $self->_swapPointers( $sdfRef, $i,$j );

      $swapped->{$j} = 1;
  }

  return;
}
#______________________________________
# Subroutine to swap the record pointers
#
sub _swapPointers 
{   my($self,$sdfRef,$i,$j) = @_;
    my $tmpPtr = $sdfRef->{_Data_}[$j];
    $sdfRef->{_Data_}[$j] = $sdfRef->{_Data_}[$i];
    $sdfRef->{_Data_}[$i] = $tmpPtr;
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

SDF::Sort::Random - Sort an PTools::SDF::SDF object in random order

=head1 VERSION

This document describes version 0.01, released March, 2005.

=head1 SYNOPSIS

     use PTools::SDF::SDF;       # or any subclass thereof, including:
     use PTools::SDF::ARRAY;
     use PTools::SDF::IDX;
     use PTools::SDF::DIR;
     use PTools::SDF::DSET;

     $sdfObj = new PTools::SDF::SDF( $fileName );

     $sdfObj->extend( "sort", "PTools::SDF::Sort::Random" );

     $sdfObj->sort();

     ($stat,$err) = $sdfObj->status;

     $stat and die $err;


=head1 DESCRIPTION

This sort class is one of several I<extended> classes used to select
which algorithm is employed to sort data in the calling object. It
is up to the client script to select the specific algorithm, as shown
in the B<Synopsis> section, above. 

This class is used to sort the data in random order.

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

=item sort

As shown in the B<Synopsis> section, above, objects of this class are
not accessed directly. Make a call to this method I<through> the
containing object where the unsorted data resides.

No arguments are needed, and the resulting ordering will be random.

At least two records must exist in the containing B<PTools::SDF::SDF> object
or an exception is generated.

Example:

     use PTools::SDF::SDF;

     $sdfObj = new PTools::SDF::SDF( "/etc/passwd" );

     $sdfObj->extend( "sort", "PTools::SDF::Sort::Random" );

     $sdfObj->sort();

     ($stat,$err) = $sdfObj->status;

     $stat and die $err;

Of course, this just an example. It might seem strange to sort the
system password file in a random order.

=back


=head2 Private Methods

The actual calling syntax for module designers is documented here. This is
the syntax used when invoking this method from withn the I<extended>
B<sort> method of the B<PTools::SDF::SDF> class only.

The B<user interface> of this B<sort> method is shown in the preceeding 
section.

=over 4


=item sort ( SdfRef )

The B<SdfRef> is a reference to the actual B<PTools::SDF::SDF> object, 
or subclass.  This is passed as the first parameter to give this object 
access to the data to be sorted.

No other parameters are necessary when using this class.

=back


=head1 INHERITANCE

None currently.

=head1 SEE ALSO

Other I<extended> sort classes are available.
See
L<PTools::SDF::Sort::Bubble>,
L<PTools::SDF::Sort::Quick> and 
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

Copyright (c) 2005-2007 by Chris Cobb. All rights reserved.
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
