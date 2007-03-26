# -*- Perl -*-
#
# File:  PTools/SDF/CSV.pm 
# Desc:  Load "CSV" data file into an PTools::SDF::SDF object
# Date:  Thu Oct 14 10:30:00 1999
# Stat:  UNDER CONSTRUCTION
#
# ToDo:  Complete this module.
#

package PTools::SDF::CSV;
require 5.002;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.01';
 @ISA     = qw( PTools::SDF::SDF );

 use PTools::SDF::SDF 0.04;


   *_loadFileSDF = \&_loadFileCSV;

sub _loadFileCSV {
   my($self,$fields,$mode,$fh) = @_;

   $fields = "" if $fields eq "line";

   $self->ctrl('readOnly', "Can't save 'CSV' format files yet");  # FIX!

   # Spliting algorithm (with appreciation) from section titled
   # "An Introductory Example: Parsing CSV Text" in Chapter 7, 
   # (pg. 204) of "Mastering Regular Expressions" by J. Friedl,
   # published by O'Reilly & Associates, Inc., 2ed, Dec, 1998:
   #
   #   @fields = ();   
   #   while ($line =~ m/"([^"\\]*(\\.[^"\\]*)*)",?|([^,]+),?|,/g) {
   #       push(@fields, defined($1) ? $1 : $3);
   #   }
   #   push(@fields, undef) if $text =~ m/,$/;
   #
   my($recIdx,$fldIdx) = (0,0);
   my($tmpPtr,$field,$value);
   my(@fields) = split(":",$fields);

 # die "mode='$mode'  \@fields='@fields'\n";

   local($/)="\n";    # Temporarially override the input record separator
   no strict "refs","vars";
   while(<$fh>) {

      if (/^#FieldNames / && $recIdx == 0) {         # a "self describing" file
         if ($mode ne "line") {
            ($fields) = /^#FieldNames (.*)$/;
            (@fields) = split(/:/,$fields);
            $self->{'dataFields'} = $fields;
            $self->{'readOnly'}   = "";              # allow writes ... for now
         }

      } elsif (/^(\s*)#|^(\s*)$/) {                  # skip comments, empties
         next;

      } elsif ($mode eq "line") {
         chomp;
	 $self->param($recIdx++, 'line', $_);         # grab entire line

      } else {
	chomp;

	$tmpPtr   = {};
	$fldIdx = 0;

	while (m/"([^"\\]*(\\.[^"\\]*)*)",?|([^,]+),?|,/g) {

	    $field = $fields[$fldIdx] || "field$fldIdx";
	    $value = (defined $1 ? $1 : $3);

	    $value = "0" if (!$value) and (length($value));
	    $value = "" unless defined($value);

	    ${$field} = $tmpPtr->{$field} = $value;
	    $fldIdx++;
	}
	m/,$/ and ${$fields[$fldIdx]} = "";    # allow for trailing field

        if ($mode && ! eval "$mode") {
	    $self->{'readOnly'} = "Data is read only: match excludes";
	    next;
        }

	$self->param($recIdx++, $tmpPtr);          # add the new record
      }
    }

    $mode and $recIdx==0 and $self->setError(-1,"No records matched '$mode'");
    $mode  or $recIdx==0 and $self->setError(-1,"No records found in file");
    return;
}

sub save {
##my($self) = shift;
  return(shift->setError(-1,"Can't yet save CSV format file in '$PACK'"));
}
#_________________________
1; # Required by require()

__END__

=head1 NAME

PTools::SDF::CSV - Load "CSV" data file into an PTools::SDF::SDF object

=head1 VERSION

This document describes version 0.01, released Feb 15, 2003

=head1 DEPENDENCIES

This class depends upon the B<PTools::SDF::SDF> class.

=head1 SYNOPSIS

     use PTools::SDF::CSV

     $csvObj = new PTools::SDF::CSV;

 or  $csvObj = new PTools::SDF::CSV( $fileName, $mode, undef, @fieldNames );


=head1 DESCRIPTION

The B<PTools::SDF::CSV> class reads and writes files in the "Comma Separated
Values" format.

  "earth",3,,"moon",1
  "mars",4,,"",
  "jupiter",5,,"callisto",1
  "jupiter",5,,"europa",2
  "jupiter",5,,"ganymede",3

In addition, this class supports the I<Field Names> header that provides
a "Self Defining Format." This is implemented by storing names for the
fields within each record at the top of the data file.


=head2 Constructor

None. This class relies on constructor in the parent class.


=head2 Methods

After instantiation, objects of this class behave identically
to B<PTools::SDF::SDF> objects.

=head1 INHERITANCE

This class inherits from the B<PTools::SDF::SDF> class.


=head1 SEE ALSO

See
L<PTools::SDF::Overview>,
L<PTools::SDF::ARRAY>, L<PTools::SDF::DB>,   L<PTools::SDF::DIR>,
L<PTools::SDF::DSET>,  L<PTools::SDF::File>, L<PTools::SDF::IDX>,
L<PTools::SDF::SDF>,   L<PTools::SDF::INI>,  L<PTools::SDF::TAG>,
L<PTools::SDF::Lock::Advisory>,  L<PTools::SDF::Lock::Selective>,
L<PTools::SDF::Sort::Bubble>, L<PTools::SDF::Sort::Quick> and 
L<PTools::SDF::Sort::Shell>.

=head1 AUTHOR

Chris Cobb, E<lt>nospamplease@ccobb.netE<gt>

Spliting algorithm, with appreciation, from section titled
"An Introductory Example: Parsing CSV Text" in Chapter 7, 
(pg. 204) of "Mastering Regular Expressions" by J. Friedl,
published by O'Reilly & Associates, Inc., 2ed, Dec, 1998.

=head1 COPYRIGHT

Copyright (c) 1997-2007 by Chris Cobb. All rights reserved.
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
