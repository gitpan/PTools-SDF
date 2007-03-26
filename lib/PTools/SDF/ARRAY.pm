# -*- Perl -*-
#
# File:  PTools/SDF/ARRAY.pm
# Desc:  Load array of "IFS delimited fields" into an PTools::SDF::SDF object
# Date:  Thu Aug 23 17:52:18 2001
# Stat:  Prototype
#
# Synopsis:
#        use PTools::SDF::SDF qw( noparse );     # Optional performance boost.
#        use PTools::SDF::ARRAY;
#
# By default the PTools::SDF::SDF Class (from which this class inherits)
# will parse each field separately looking for an encoded delimiter
# character. Often this is unnecessary. Since the overhead is high,
# disable this parsing prior to "using" this package as shown above.
#
#        $sdfRef = new PTools::SDF::ARRAY( $arrayRef );
#
#  or    $sdfRef = new PTools::SDF::ARRAY;
#        $sdfRef->loadFile( $arrayRef );
#
# Usage is identical to both PTools::SDF::SDF and, optionally, 
# PTools::SDF::IDX except that, as shown above, the objects load from 
# an array reference instead of from a data file. The array reference 
# is expected to be a list of "records" delimited with a field separator. 
# For example,
#
#        open(IN,"</etc/passwd") or die $!;
#        (@array) = <IN>;
#        $arrayRef = \@array;
#        close(IN);
#

package PTools::SDF::ARRAY;
use strict;

my $PACK = __PACKAGE__;
use vars qw( $VERSION @ISA );
$VERSION = '0.09';
@ISA     = qw( PTools::SDF::IDX );     # Inherits from PTools::SDF::SDF, too.

use PTools::SDF::IDX;


# Here we override the PTools::SDF::SDF data loader methods to load
# from an array reference instead of a data file.

sub loadFile
{   my($self,$arrayRef,$mode,@fields) = @_;            # Grab parameters

    $mode ||= "";
    my($match) = "";
    #__________________________________
    # Create some additional control elements; fill one
    # with the field names used in creating the associations.
    # Don't use an array here as dereferencing it would be
    # rather more painful than simply using a split().
    #
    $self->{'fileName'}  = "";
    $self->{'ctrlFields'}= 
	"status:error:fileName:readOnly:ctrlFields:dataFields:ifs:parseifs";

    #__________________________________
    # Are we parsing records into fields? or just reading
    # a whole line at a time? The settings here can change
    # in sub "_loadFileSDF()" if "#FieldNames " are found.
    #
    my $dataFields = "";
    if ($mode eq "line") {
	$dataFields = "line";
	$self->{'readOnly'}  = "Data is read only since read via 'line mode'"; 

    } elsif (@fields) {                                # passed by caller
	$dataFields = join(':',@fields);

    } else {
	$dataFields = "line";                          # assume line mode for now
	$mode = "line";                                # and force the $mode
	$self->{'readOnly'} = "unknown field names";   # disallow writes for now
    }
    $self->{'dataFields'}= $dataFields;
    #__________________________________
    # Now we'll load each array entry into a hash array.
    # 
    $self->_loadArraySDF($dataFields,$mode,$arrayRef);  # pass field names list 

   return;
}

sub _loadArraySDF
{   my($self,$fields,$mode,$arrayRef) = @_;

    # collect list of fields ... if any were passed in
    my(@fields) = split(":",$fields) unless $fields eq "line";

    my($IFS) = $self->ctrl('ifs') || ":";
    my $splitIFS;
    if ($IFS =~ m#^\\s\+?$#) {
	($splitIFS) = $IFS;                 # don't eacape special cases!
    } else {
	($splitIFS) = "\\" . $IFS;          # escape problematic IFS chars!
    }
    my(@values,$tmpPtr);
    my($i)=0;

    local($/)="\n";    # Temporarially override the input record separator
    no strict "refs","vars";
    foreach (@$arrayRef) {

	if (/^#FieldNames / && $i == 0) {       # a "self describing" file
	    # If any fieldnames were passed into this module,
	    # these will override the fieldnames in the file,
	    # and fieldnames in file override "line" mode.

	    next if @fields;
	    $mode = "";
	    #
	    ($fields) = /^#FieldNames (.*)$/;       
	    (@fields) = split(":",$fields);        

	    $self->{'dataFields'} = $fields;         
	    $self->{'readOnly'}   = "";         # allow writes ... for now

	} elsif (/^#IFSChar "?(\D)(s\+?)?/ && $i == 0) {   
	    # Here we allow for a "self described" IFS character,
	    # contained within the Self Defining File's header,
	    # that can be any non-numeric character. We also allow
	    # here for the special cases of "\s" and "\s+".

	    if ($2 and $1 eq "\\") {
		$IFS = "$1$2";                # ($1 eq "\") ($2 eq "s" or "s+");
		($splitIFS) = $IFS;
	    } else {
		$IFS = $1;                    # Note: allows space, tab, etc.
		($splitIFS) = "\\". $IFS;     # escape problematic IFS chars!!
	    }
	    $self->ctrl('ifs', $IFS);

	} elsif (/^(\s*)#|^(\s*)$/) {           # skip comments, empties 
	    next;

	} elsif ($mode eq "line") {
	    chomp;
	    $self->{_Data_}[$i++]{'line'} = $_;          # grab entire line

	} else {
	    #__________________________________________
	    # Create an array of the field values ... we just ass*u*me 
	    # that there will be as many @values as @fields here!
	    #
	    chomp;
	    @values = split($splitIFS);               # split rec into fields

	    #__________________________________________
	    # Be sure to create a new $tmpPtr EACH time we go through this 
	    # loop; otherwise, we are just changing the values in a single 
	    # hash array and we don't want that ... we want new hash array 
	    # for each record.
	    #
	    $tmpPtr = {};

	    #__________________________________________
	    # Note the variable syntax here. We want to be able to test our 
	    # match criteria (if any) against the values in the fieldnames 
	    # without knowing in advance what the fieldnames will be. 
	    #
	    my($j) = 0;                                   
	    my($parseIFS) = $self->ctrl('parseifs') || "";
	    foreach my $field (@fields) {                
		$values[$j]= $self->unescapeIFS($values[$j]) if $parseIFS; 
		$@ and die $@;
		${$field}         = $values[$j];     # this is NOT "$field"
		$tmpPtr->{$field} = $values[$j];     # fill hash record too
		$j++;                                  
	    }                                         
	    #__________________________________________
	    # Now that we have a the current record split into
	    # variables named for each field, we can check for
	    # any "match criteria" passed from the calling prog
	    # (see notes above for further details). Examples:
	    #
	    #  $dataRef = new PTools::SDF("$fileName","\$field=~/value/");
	    #  $dataRef = new PTools::SDF("$fileName","/matchAnyField/i");
	    #
	    # The second example works since we still have the
	    # entire record in the special "$_" variable.
	    #
	    # DISALLOW "partial"writes if match fails, skip rec
	    #
	    if ($mode && ! eval "$mode") {
		$self->{'readOnly'} = "Data is read only: match excludes";
		next;
	    }
	    #__________________________________________
	    # When we get this far, we have a record that
	    # is already loaded into a hash array, so we can
	    # just copy the pointer ... This is why we need to 
	    # create a new $tmpPtr each time through the loop.
	    #
	    $self->{_Data_}[$i++] = $tmpPtr;           # this one's a keeper!
	}
    }

    $self->setError(-1,"No records found in '_loadFileSDF' method of '$PACK'")
	if ( $i == 0 );

    return;
}
#_________________________
1; # Required by require()

=head1 NAME

PTools::SDF::ARRAY - Load array of 'IFS delimited fields' into PTools::SDF::SDF object

=head1 VERSION

This document describes version 0.08, released March, 2005.

=head1 SYNOPSIS

        use PTools::SDF::SDF qw( noparse );     # Optional performance boost.
        use PTools::SDF::ARRAY;

By default the B<PTools::SDF::SDF> Class (from which this class inherits)
will parse each field separately looking for an encoded delimiter
character. Often this is unnecessary. Since the overhead is high,
disable this parsing prior to 'using' this package as shown above.

        $sdfRef = new PTools::SDF::ARRAY( $arrayRef );

  or    $sdfRef = new PTools::SDF::ARRAY;
        $sdfRef->loadFile( $arrayRef );

Usage is identical to both B<PTools::SDF::SDF> and, optionally, 
B<PTools::SDF::IDX> except that, as shown above, the objects load from 
an array reference instead of from a data file. The array reference is 
expected to be a list of 'records' delimited with a field separator. 
For example,

        open(IN,'</etc/passwd') or die $!;
        (@array) = <IN>;
        $arrayRef = \@array;
        close(IN);

=head1 DESCRIPTION

=head2 Constructor

None. This class relies on a parent class for the constructor method.

=head2 Methods

No additional public methods are defined here. A couple of private
methods are overridden to facilitate loading data from an array.

=head1 INHERITANCE

This B<PTools::SDF::ARRAY> class inherits from the B<PTools::SDF::SDF> class.
Additional methods are available via this and other parent classes.

=head1 SEE ALSO

See
L<PTools::SDF::Overview>, 
L<PTools::SDF::CSV>,   L<PTools::SDF::DB>,   L<PTools::SDF::DIR>,
L<PTools::SDF::DSET>,  L<PTools::SDF::File>, L<PTools::SDF::IDX>, 
L<PTools::SDF::INI>,   L<PTools::SDF::SDF>,  L<PTools::SDF::TAG>   
L<PTools::SDF::Lock::Advisory>, 
L<PTools::SDF::Sort::Bubble>,
L<PTools::SDF::Sort::Quick>,
L<PTools::SDF::Sort::Random> and
L<PTools::SDF::Sort::Shell>.

In addition, several implementation examples are available. See
L<PTools::SDF::File::AutoHome>, L<PTools::SDF::File::Mnttab> 
and L<PTools::SDF::File::Passwd>. These can be found in the
'PTools-SDF-File-Cmd' distribution on CPAN.

=head1 AUTHOR

Chris Cobb, E<lt>nospamplease@ccobb.netE<gt>

=head1 COPYRIGHT

Copyright (c) 1997-2007 by Chris Cobb. All rights reserved. 
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
