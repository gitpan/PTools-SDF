# -*- Perl -*-
#
# File:  PTools/SDF/IDX.pm
# Desc:  Allow for user-defined indices into PTools::SDF::SDF objects.
# Date:  Fri Aug 27 11:42:27 1999
# Note:  See "POD" at end of this module.
#
# "PTools-SDF" the bundle includes several modules for "Simple Data Files"
# while "PTools::SDF::SDF" the class implements a "Self Defining File."
#
#
package PTools::SDF::IDX;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.15';
 @ISA     = qw( PTools::SDF::SDF );

 use PTools::SDF::SDF 0.04;

sub index
{   my($self,$field,$value,@params) = @_;

    return undef unless ($field and $value);  ### and scalar @params);

    unless ($self->ctrl("idx_$field")) {
	$self->setErr(-1, "Must init index for '$field' prior to accessing");
	return undef;
    }
    my $recnbr = $self->ctrl("idx_$field")->{$value};
    $recnbr = "" unless defined($recnbr);                # allow for 0

  # print "DEBUG: PTools::SDF::IDX index: recnbr='$recnbr'\n";

    return "$recnbr" if ($params[0] and $params[0] eq "REC_NUMBER");
    local($^W)=0;    # prevent silly "uninitilized value" error ;-/
    return ( length($recnbr) ? $self->param( $recnbr, @params ) : undef );
}

# recNumber simplifies obtaining record number
#
#   usage:    $recNum = $idxRef->recNumber( $fieldName, $fieldValue );
#
# where "$fieldName"  is a valid field name for which the "indexInit"
#                     method was previously invoked, and
#       "$fieldValue" is a value for the named field

sub recNumber { return $_[0]->index($_[1], $_[2], "REC_NUMBER")  }


# recData simplifies obtaining record data
#
#   usage:    $hashRef = $recData->recData( $fieldName, $fieldValue );
#
# where "$fieldName"  is a valid field name for which the "indexInit"
#                     method was previously invoked, and
#       "$fieldValue" is a value for the named field

sub recData { return $_[0]->getRecEntry($_[0]->index($_[1],$_[2],"REC_NUMBER")) }


sub indexDelete
{   my($self,$idxField,$idxValue,$fieldName) = @_;

  # print "DEBUG: enter 'indexDelete( $idxField, $idxValue, $fieldName )'\n";

    return undef unless ($idxField and $idxValue and $fieldName);

    unless ($self->ctrl("idx_$idxField")) {
        #print "DEBUG: INDEX NOT FOUND\n";
	$self->setErr(-1, "Must init index for '$idxField' prior to accessing");
	return undef;
    }
    my $recnbr = $self->ctrl("idx_$idxField")->{$idxValue};
    return undef unless defined($recnbr);                # allow for 0

  # print "DEBUG: calling 'feldDelete( $recnbr, $fieldName )'\n";

    return $self->fieldDelete( $recnbr, $fieldName );    # returns old value
}

# indexCount converts a zero-based array count into 1-based "human" number
#
sub indexCount
{   my($self,$field) = @_;

    $field or return 
	$self->setErr(-1, "Value for 'field' missing in 'indexCount' method of '$PACK'");
    no strict "refs";
    my $idx = $self->ctrl("idx_$field") || "";
    my(@idx)= keys %$idx;

    return $#idx + 1;
}

sub getIndex
{   my($self,$field) = @_;
    return $self->ctrl("idx_$field");
}

sub indexInit
{   my($self,$field,%match) = @_;

    unless (defined $field) {
	$self->setErr(-1,"Undefined value for 'field' in 'indexInit' method of '$PACK'");
	return undef;
    }
    unless ( grep(/^$field$/, $self->ctrl('dataFields') ) ) {
	$self->setErr(-1,"Invalid value for 'field' ('$field') in 'indexInit' method of '$PACK'");
	return undef;
    }

    my $idx = {};
    my($matchField,$value,@matchOrder);

    if (defined $match{MATCH_ORDER}) {
	(@matchOrder) = split(':', $match{MATCH_ORDER});
	delete($match{MATCH_ORDER});
    }
    if (%match) {
	@matchOrder or (@matchOrder) = sort keys %match;
    }

    no strict "subs";
    for my $recNum (0..$self->param) {
	if (!@matchOrder) {

	    #die $self->dump(0,1);
	    #my $value = $self->get($recNum, $field);
	    #die "index='$recNum'  value='$value'\n";

	    my $value = $self->get($recNum, $field) || next;

	    #if ( (!$value) or (!length($recNum)) ) {
	    #	print "DEBUG (IDX): field='$field' rec='$recNum' val='$value'\n";
	    #}
	    $idx->{ $value } = $recNum;
	    next;
	}
	my $match;
	foreach $matchField (@matchOrder) {
	    next if ! ( $value = $self->param($recNum, $matchField) );

	    if ($value =~ /^(.*)$/) { $value = $1;   # untaint $value
	    } else { die "Error: bad values from record"; }

	    $match = $match{$matchField};
	    if ($match =~ /^(.*)$/) { $match = $1;   # untaint $match
	    } else { die "Error: bad values from match"; }

	    #if (eval "\"$value\" $match{$matchField}") {

	    if (eval "\"$value\" $match") {
		$idx->{ $value } = $recNum;
	    } else {
		last;
	    }
	}
    }
    $self->ctrl("idx_$field", $idx);
    return( $idx ) unless wantarray;
    return( $idx, $field );
}

sub compoundInit
{   my($self,@fields) = @_;

    (@fields)   = split("&",$fields[0]) if $#fields == 0;
    my $fields  = join('&', @fields);
    my(@values) = ();
    my $idxRef  = {};

    for my $idx (0..$self->param) {
	(@values) = ();
	foreach my $field (@fields) {
	    push( @values, $self->param($idx,$field) ||"" );
	}
	$idxRef->{ join('&',@values) } = $idx;
    }
    $self->ctrl("idx_$fields", $idxRef);
    return( $idxRef ) unless wantarray;
    return( $idxRef, $fields );
}

sub sort
{   my($self,@params) = @_;

    foreach my $field ( $self->ctrlFields ) {
	next unless $field =~ /^idx_/;
	$self->ctrlDelete( $field );
    }
    $self->SUPER::sort(@params);

    return $self->getError;
}
#_________________________
1; # required by require()

__END__

=head1 NAME

PTools::SDF::IDX - Allow user-defined indices into PTools::SDF::SDF objects

=head1 VERSION

This document describes version 0.15, released October, 2004.

=head1 SYNOPSIS

    # Trivial example reads /etc/passwd, indexes on Uid,
    # and prints the user information for c-shell users.

    use PTools::SDF::IDX;

    @pwFields = qw(uname passwd uid gid gecos home shell );
    $pw = new PTools::SDF::IDX("/etc/passwd", undef, undef, @pwFields);

    $idx = $pw->indexInit('uid', 'shell', '=~/csh$/');

    foreach (sort keys %$idx) {
        @idx = ('uid',$_);
        print $pw->index(@idx, 'gecos'), "\n"
    }

=head1 DESCRIPTION

This perl library extends the PTools::SDF::SDF class to make it easy to
create user defined indices. The SDF class loads a field delimited
file into an array of associative arrays. 

Until now, the only index into the SDF object was the record number. 
This meant that repeated serial reads of an SDF object were necessary
to match on any other fields. Now any arbitrary field can be used to 
index the file.

Match criteria can be used when initializing the index to select
a subset of the records to be indexed. This means that the value
of the field indexed does not necessarily need to be unique for
every record in the file. It does mean, however, that the field
values must be unique with the selection criteria. Therefore, care
may be needed when creating the match criteria.


=head2 Constructor

None. 

As a subclass of B<PTools::SDF::SDF> this uses the constructor in the 
parent class. See L<PTools::SDF::SDF>.


=head2 Methods

=over 4

=item indexInit ( IdxField [, MatchCriteria ] )

The first step is to create a field_value to record_number mapping.
The match criteria used here are slightly different from that used
by the SDF "new" method. The field names must be separated from the
criteria used to select records.

=over 4

=item IdxField

Specify the name of a key field within each record.

=item MatchCriteria

If the values for this field are not unique within the current 
object are not unique, you must specify one or more B<MatchCriteria>
patterns to limit the indexing to a subset of records where the
key field I<will> be unique.

As an alternative to this, see the B<compoundInit> method, below.

=back

Examples:

The 'indexInit' method must be called once for each user-defined
index before invoking the 'index' method using that index. Create an
IDX object as you would any SDF object.

  use PTools::SDF::IDX;
  $sdfObj = new PTools::SDF::IDX( $ProductFile );

This first example simply indexes the SDF object on the 'prodnbr'
field of the file specified in the $ProductFile variable.

  $sdfObj->indexInit('prodnbr');

In this next example, 'prodnbr' records are indexed only when 
the 'type' field does not equal the string "Format".

  $sdfObj->indexInit($fieldname, 'type', 'ne "Format"');
 
This last example show a somewhat more complex set of matching 
criteria.

  %matchCriteria = (
            type => '!~ /Format|Display Only/',
         prodnbr => 'lt "99999"',
     MATCH_ORDER => 'type:prodnbr',
                   );
  $sdfObj->indexInit($fieldname, %matchCriteria);

Since the match criteria are stored in an associative array
no particular selection order is enforced. To impose an order
of priority on a set of criteria, use the B<MATCH_ORDER> key
to specify in which order the matching will occur.


=item compoundInit ( IdxFieldList )

It is possible to create a I<compound> index using two or
more fields withn each record.

=over 4

=item IdxFieldList

This is a list containing the names of two or more fields in the
current B<PTools::SDF::SDF> object.

=back

Example:

    # Determine which type of index to initialize

    $compound = 1;

    $field = ($compound ? 'prodnbr&xyzzy' : 'prodnbr' );

    if ($field =~ /&/) {
        $sdfObj->compoundInit( $field );

    } else {
        $sdfObj->indexInit( $field );
    }
   
See the last example in the B<index> method, below for the
syntax used to access a compund index.


=item index ( IdxFieldName, IdxFieldValue, FieldName [, Value ] )

Once an index has been initialized, use the B<index> method
to access the records.

=over 4

=item IdxFieldName

The name of the field used to initialize the index.

=item IdxFieldValue

The search value for the indexed field.

=item FieldName

The I<other> field name within the record that will be accessed.

=item Value

The B<Value> is an optional parameter that is used to set the
value of the specified B<FieldName>. Without a this parameter,
the current value of the field is returned.

=back

Examples:

    $otherFieldValue = $sdfObj->index('prodnbr',$prodNbrValue, 'otherfield');

Think of the (B<IdxFieldName>,B<IdxFieldValue>) combination as an
B<index> or 'record number' that is passed to the B<PTools::SDF::SDF> B<param>
method. It may be easier to think of this if you build a compound 
record index as shown in this next example.

    @idx = ('prodnbr',$prodNbrValue);

    $fieldValue = $sdfObj->index( @idx, 'otherfield' );

    $sdfObj->index( @idx, 'otherfield', "New Value" );

Any other params that you would normally use with the B<param> method
are sent along through the B<index> method. The return is the same as 
returned by B<param>. See L<PTools::SDF::SDF>.


Finally, when calling the B<index> method on a I<compound> index,
pass a "compound" value for I<both> the B<idxFieldName> and the 
B<idxFieldValue> parameters.

Example:

    @idx = ( 'prodnbr&xyzzy', $prodNbrValue ."&". $xyzzyValue );

    $value = $sdfObj->index( @idx, "otherfieldname" );

    $sdfObj->index( @idx, "otherfieldname", "New Value" );


=item recNumber ( IdxFieldName, IdxFieldValue )

This method returns the record number offset into the current 
B<PTools::SDF::SDF> object. 

The parameters are identical to the first two parameters to the
B<index> method, above.

Example:

    @idx = ('prodnbr',$prodNbrValue);

    $recNum = $sdfObj->recNumber( @idx );


=item recData ( IdxFieldName, IdxFieldValue )

Fetch the entire record indexed by B<RecNumber> as a hash reference.
This can then be used to access and update field values.

WARNING: Modifying data values in the returned hash reference B<will>
update the values in the corresponding data record.

The parameters are identical to the first two parameters to the
B<index> method, above.

This method is equivalent in function to the B<getRecEntry> method in
the B<PTools::SDF::SDF> class. 

Example:

    @idx = ('prodnbr',$prodNbrValue);

    $hashRef = $sdfObj->recData( @idx );

    $hashRef->{fieldname} = "new value";        # updates the $sdfObj, too.


=item getIndex ( IdxFieldName )

The B<getIndex> method returns a hash reference that contains the
internal mapping used to lookup record numbers based on the values
for a given index field.

The parameter is identical to the first parameter to the
B<index> method, above.

Example:

    $hashRef = $sdfObj->getIndex( 'prodnbr' );


=item indexCount ( IdxFieldName )

This method is somewhat analogous to the B<count> method in the
B<PTools::SDF::SDF> class. However, remember that the index may have
been limited to a subset of records in the current object. As
such the return value from these methods may not be equivalent.

The parameter is identical to the first parameter to the
B<index> method, above.

Example:

    $idxCount = $sdfObj->indexCount( 'prodnbr' )


=item indexDelete ( IdxFieldName, IdxFieldValue, FieldName )

Delete the value for a named data field within a record

The parameters are identical to the first three parameters to the
B<index> method, above.

Example:

    # Delete the value for the 'proddesc' field in the record
    # specified by the "@idx" array.

    @idx = ('prodnbr',$prodNbrValue);

    $sdfObj->indexDelete( @idx, 'proddesc');

=item sort ( Options )

The B<sort> method is overridden in this class. Since record
sorting usually rearranges the order of records in the file,
any and all currently defined indices are removed.

The sort B<Options> are passed through unchanged to whatever
sort class happens to be in use with the current object.

Currently this method will not reestablish prior index keys so 
either perform any ncessary sorting prior to index initilization,
or reinitialize indices after each sort.

=back

=head1 INHERITANCE

This B<PTools::SDF::IDX> class inherits from the B<PTools::SDF::SDF> concrete base class.
Additional methods are available via this parent class.

The B<PTools::SDF::DSET> class inherits from this class.

=head1 SEE ALSO

See
L<PTools::SDF::Overview>,
L<PTools::SDF::ARRAY>, L<PTools::SDF::CSV>,  L<PTools::SDF::DB>,
L<PTools::SDF::DIR>,   L<PTools::SDF::DSET>, L<PTools::SDF::File>,
L<PTools::SDF::INI>,
L<PTools::SDF::TAG>,   L<PTools::SDF::SDF>   L<PTools::SDF::Lock::Advisory>,
L<PTools::SDF::Sort::Bubble>, L<PTools::SDF::Sort::Quick> and 
L<PTools::SDF::Sort::Shell>.

In addition, several implementation examples are available.

See
L<PTools::SDF::DSET>, L<PTools::SDF::File::AutoHome>, 
L<PTools::SDF::File::Mnttab> and L<PTools::SDF::File::Passwd>.
These are contained in the 'PTools-SDF-File-Cmd' distribution
available on CPAN

=head1 AUTHOR

Chris Cobb, E<lt>nospamplease@ccobb.netE<gt>

=head1 COPYRIGHT

Copyright (c) 1999-2007 by Chris Cobb. All rights reserved.
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

