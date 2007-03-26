# -*- Perl -*- 
#
# File:  PTools/SDF/TAG.pm
# Desc:  Load data files into associative (hash) arrays
# Date:  Tue Feb 11 10:00:00 1997
# Mods:  Thu Oct 14 10:30:00 1999
# Lang:  Perl 5.0
# Stat:  Prototype
#
# ToDo:
# . Turn docco at end of script into "pod" format
#

package PTools::SDF::TAG;
 require 5.001;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.10';
 @ISA     = qw( PTools::SDF::File );

 use PTools::SDF::File;

 my $PATH = "SDF/TAG.pm";

sub new {
   my($class,$fileName,$mode,@fields) = @_;
   my($self);
   local($/)="\n";    # Temporarially override the input record separator

   $self = {};                                          # use hash array
   bless $self, $class;
   $self->setError(0,"");                               # assume the best
   $self->{'sdfControl'}{'ctrlFields'} = "ctrlFields:dataFields";
 # $self->ctrl('ctrlFields', "ctrlFields:dataFields");  # init ctrl fields
   $self->ctrl('dataFields', @fields);                  # init data fields

   $self->loadFileTAG($fileName,$mode) if $fileName;
   
   return($self,$self->ctrl('status'),$self->ctrl('error')) if wantarray;
   return $self;
}


sub save {
   my($self,$who,$fileName,$heading,$force) = @_;
   local($\)="";      # Temporarially override the output record separator

   $self->saveFile($who,$fileName,$heading,$force);

   return($self->ctrl('status'),$self->ctrl('error')) if wantarray;
   return; 
}


sub sort {
   my($self,$mode,@keys) = @_;
   return $self->setError(-1,"Sort is undefined for this object.");
}


sub ctrl {
   my($self,$param,@values) = @_;
   return $self->ctrlParam($param,@values);
}


sub param {
   my($self,@params) = @_;
   return $self->recParam(@params);
}


sub tag2sdf {
   my($self,@fieldNames) = @_;
   return $self->tag2sdfRec(@fieldNames);
}


sub delete {
  my($self,$fieldName) = @_;
  return $self->{$fieldName} = "";
}

sub ctrlDelete {
   my($self,$param) = @_;

   return undef if ! defined $self->{'sdfControl'}{$param};

   my $value = $self->{'sdfControl'}{$param};
   delete $self->{'sdfControl'}{$param};

   $self->{'sdfControl'}{'ctrlFields'} =~ s/(^|:)$param(:|$)/$2/;

   return $value;
}
#
###############################################################################
#                                                                             #
#  The following methods are intended for PRIVATE use                         #
#                                                                             #
###############################################################################

sub loadFileTAG {
  my($self,$fileName,$mode) = @_;                    # Grab parameters

  $fileName ||= "";
  $mode     ||= "";
  #__________________________________
  # Used to confirm version of THIS subroutine
  #
  my($version)  = "1.0";                             # Version of THIS routine
  if ($mode =~ /^version$/i) {
     return($version);                               # for "writePubControlFile"
  }
  #__________________________________
  # Fill a separate hash with control data.
  #
  $self->{'sdfControl'}{'fileName'}  = $fileName;
  $self->{'sdfControl'}{'version'}   = "$version";
  $self->{'sdfControl'}{'dataFields'}= "";
  $self->{'sdfControl'}{'ctrlFields'}= 
     "status:error:fileName:readOnly:version:ctrlFields:dataFields";
  #__________________________________
  # Now, if we can successfully open the file
  # we'll load each record into a hash array.
  # 
  local *IN;
  if (open(IN,"$fileName")) {

     $self->_loadFileTAG($mode);
     close(IN);

  } else {
     my $error = sprintf("%s: $fileName in 'SDF_loadFileTAG()'",$!);
     $self->{'sdfControl'}{'status'}= sprintf("%d",$!);  # error number
     $self->{'sdfControl'}{'error'} = $error;            # error message
  }
  return;
}


sub _loadFileTAG {
  my($self,$mode) = @_;

  my($fieldName,$newLine,$skipFlag) = ("","","True");
  while(<IN>) {
     chomp;
     if (/^(\s*)#|^(\s*)$/ and $skipFlag) { # skip comments, empties but
        next;                               # ONLY before first field found

     } elsif (/^\[(.*)\]$/) {             # We've got a new field name
        ($fieldName)=/^\[(.*)\]$/;        # Format is  ^[fieldName]$
        $self->{$fieldName}= "";          # Initialize; field may be empty
        $self->{'sdfControl'}{'dataFields'} .= "${fieldName}:";
        $newLine="";
	$skipFlag=undef;                  # skip nothing from here on out

     } else {
        $self->{$fieldName} .= "$newLine" . $_;
        $newLine="\n";
     }
  }
  chop($self->{'sdfControl'}{'dataFields'});         # strip last ":" char
  return;
}


sub saveFile {
  my($self,$who,$fileName,$heading,$force) = @_;

  my($prev,$line,$folder,$i);
  my($time) = time;
  my($version,$readOnly);
  #__________________________________
  # 1) If we weren't passed a fileName, try to figure it out
  #    (if passed as param use it, otherwise was stored in array when loaded)
  # 2) Get the file type we are dealing with (stored in array when loaded)
  # 3) Get the version the file was created with (stored in array when loaded)
  # 4) Make sure we can write the data  (stored in array when loaded)
  #
  $self->setError(0,"");

  local($^W)=0;
  $fileName = $self->ctrl('fileName') if ! $fileName;
  $version  = $self->ctrl('version');
  $readOnly = $self->ctrl('readOnly');
  $force and $readOnly = "";

  # DEBUG: Check "inode" numbers here not just filenames
  if ($fileName ne $self->ctrl('fileName')) {
     $readOnly = "";
  }
  #__________________________________
  # Don't allow "partial" writes! This flag is set during the
  # "_loadFile" routines. Set when records are excluded due 
  # to <match> criteria passed from calling program
  # OR if file was loaded using "line" mode (we're not
  # currently set up to handle that record type).
  # Also dissallow writes if we can't determine which 
  # version of the loader was used to create the array.
  #
  my($status,$error);
  if (! $fileName) {
     $status = -1;
     $error = "Required param 'fileName' not found in 'SDF_saveFile()'";

  } elsif ($readOnly) {
     $status = -1; $error = $readOnly . " in 'SDF__saveFile()'";

  } else {
     $status = 0; $error = "";
  }
  if ($status) {
     $self->setError($status,$error);
     return;
  }
  #__________________________________
  #
  local *OUT;
  if (! open(OUT,">$fileName")) {
     $error = "Unable to write $fileName in 'SDF_saveFile()'";
     $self->setError(-1,$error);
     return;
  }
  #__________________________________
  # If we have a header, make SURE it's all comments;
  # otherwise, we can expect problems next time we read.
  #
  if ($heading) {
     $heading =~ s/^([^#].*)/# $1/mg;       # add comments if they are missing
     print OUT "$heading\n";

  } else {
     my($time) = time;
     #___________________________________ 
     # Rummage around for a User Id
     # First, check "basic" Web security
     #
     if (!$who && $ENV{'REMOTE_USER'}) {
        $who = "$ENV{'REMOTE_USER'} (web remote_user)";
     }
     #___________________________________ 
     # If nothing found yet, try for a login Id. This will usually 
     # be the Web server so we loose all granularity. What a drag.
     # If that fails, see if we can grab a Web script name.
     # If that fails, grab the Unix script name.
     # If THAT fails ... let's just forget it!
     #
     if (!$who) {
        $who  = getlogin;
        $who .= " (system uname)" if $who;
     }
     if (! $who && $ENV{'SCRIPT_NAME'}) {
        $who = "$ENV{'SCRIPT_NAME'} (CGI port $ENV{'SERVER_PORT'})";
     }
     if (!$who) {
        $who  = "$0";
	$who .= " (unix script)" if $who;
     }
     $who = "(unknown user)" if ! $who; 
     #___________________________________ 
     #
     print OUT "# This is a generated file. Any changes may be lost.\n";
     print OUT "# Created $time ";
     if ($who) {
        print OUT "by $who\n";
     } else {
        print OUT "\n";
     }
  }
  #__________________________________
  #
  $self->_saveFileTAG;

  close(OUT);
  return;
}


sub _saveFileTAG {
  my($self) = @_;
  #__________________________________
  # Which do we want here? Field names from the "dataFields"
  # parameter created when the file was loaded? or the actual
  # fields currently defined in the array? Take your pick.
  #
  my(@tags,$tag);
# @tags = sort keys %$self;             # dereference & get tags
  (@tags) = $self->ctrl('dataFields');  # collect from ctrl fields

  foreach $tag (@tags) {
     if ($tag eq 'sdfControl') {
       next;
     }
     print OUT "[$tag]\n";
     if ($self->{$tag}) {
        print OUT "$self->{$tag}\n";
     }
  }
  return;
}


sub ctrlParam {
   my($self,$param,@values) = @_;

   ## $self->setError(0,"");   # Don't reset these here.

   if ($param) {
      #______________________________________________________
      # If we have both a param and values for the param
      # then determine which file type we have and update.
      # If the param name is not in the list, update the list
      # (but don't add a leading ":" if no list exists yet).
      #
      local($^W) = 0;
      my($sep) = "";    # no leading separator by default.
      if (@values) {
	 if ($param =~ /version|ctrlFields/) {    # can't reset these ...
	    return;
         } else {
            $self->{'sdfControl'}{$param} = $values[0]        if $#values == 0;
            $self->{'sdfControl'}{$param} = join(':',@values) if $#values != 0;
            if ($self->{'sdfControl'}{'ctrlFields'} !~ /(^|:)$param(:|$)/) {
                $sep = ":" if $self->{'sdfControl'}{'ctrlFields'};
                $self->{'sdfControl'}{'ctrlFields'} .= "${sep}${param}";
            }
	 }
	 return;
      #______________________________________________________
      # If we have just a param w/out values for the param then
      # determine which file type we have and return param's value.
      # Also, format return value depending on current context.
      #
      } else {
	 return(split(':',$self->{'sdfControl'}{$param})) if wantarray;
	 return($self->{'sdfControl'}{$param});
      }
   #______________________________________________________
   # If we have no param then determine which file type we have 
   # and return all of the control field names.
   # Also, format return value depending on current context.
   #
   } else {
      return(split(':',$self->{'sdfControl'}{'ctrlFields'})) if wantarray;
      return($self->{'sdfControl'}{'ctrlFields'});
   }
}


sub recParam {
   my($self,$param,$value) = @_;

   $self->setError(0,"");
   #______________________________________________________
   # Figure out if we are setting a parm, merely returning it's 
   # value, or returning all values for the record/array.
   #
   local($^W) = 0;
   $value = "0 but True" if ! $value && length($value) == 1;
   if ($param) {
      #______________________________________________________
      # Update param if we have a new a value; otherwise, 
      # just return the existing parameter value.
      #
      if ($value) {
         $value = "0" if $value eq "0 but True";
	 return $self->{$param} = $value;
      } else {
	 return $self->{$param};
      }
   #______________________________________________________
   # If we have no paramters, return the section count.
   #
   } else {
      my(%dref) = %$self;               # dreference pointer to array
      my(@count)= keys %dref;           # collect hash keys
      return $#count;                   # return section count
   } 
}


sub tag2sdfRec {
   my($self,@fieldNames) = @_;

   if (! $self->isa("PTools::SDF::TAG")) {
     my $error = "Invalid sdf type. Must be 'TAG' object in 'SDF_tag2sdfRec()";
     $self->setError(-1,$error);
     return;
   }
   (@fieldNames) = split(':',$fieldNames[0])  if $#fieldNames == 0;
   (@fieldNames) = $self->ctrl('dataFields')  if ! @fieldNames;

   my($ref) = {};                             # create an empty hash reference
   my($field);
   foreach $field (@fieldNames) {
      $ref->{$field} = $self->{$field};       # convert each data field
   }
   return($ref);                              # return pointer to the hash
}
#
###############################################################################
#                                                                             #
#  Miscellaneous functions, etc.                                              #
#                                                                             #
###############################################################################

sub isLocked  { return $_[0]->{'sdfControl'}{ext_lock} 
		     ? $_[0]->{'sdfControl'}{ext_lock}->isLocked  : "0" }

sub notLocked { return $_[0]->{'sdfControl'}{ext_lock} 
		     ? $_[0]->{'sdfControl'}{ext_lock}->notLocked : "1" }

sub setError { return( $_[0]->{'sdfControl'}{status}=$_[1]||0,
		       $_[0]->{'sdfControl'}{error}=$_[2]||"" )   }

sub status   { return( $_[0]->{'sdfControl'}{status}||0,
		       $_[0]->{'sdfControl'}{error}||"" )         }

sub stat     { ( wantarray ? ($_[0]->{'sdfControl'}{error}||"") 
			   : ($_[0]->{'sdfControl'}{status}||0) ) }

sub err      { return( $_[0]->{'sdfControl'}{error}||"" )         }

   *getError = \&status;     # allow for calling using various method names.
   *getErr   = \&status;     # allow for calling using various method names.
   *setErr   = \&setError;   # allow for calling using both method names.

   *statOnly = \&stat;
   *errOnly  = \&err;

#sub stat {    # Confirm these can be deleted. See reimplementation, above
#  return( $_[0]->{'sdfControl'}{status}||"" ) unless wantarray;
#  return( $_[0]->{'sdfControl'}{status}||0, $_[0]->{'sdfControl'}{error}||"" );
#
#sub err {
#  return( $_[0]->{'sdfControl'}{error}||"" ) unless wantarray;
#  return( $_[0]->{'sdfControl'}{status}||0, $_[0]->{'sdfControl'}{error}||"" );
#}

sub dump {
 my($self)= @_;      # start,end for 'sdf' objects only

 my($field,$text) = ("","");
 my($pack,$file,$line)=caller();
 #_____________________________________________________
 local($^W) = 0;
 my @tags = sort keys %$self;             # dereference & get section tags
 my (@ctrlFields) = $self->ctrl('ctrlFields');  # collect from ctrl fields
 $text  = "DEBUG: (SDF\:\:TAG\:\:dump self='$self'\n";
 $text .= "CALLER $pack at line $line ($file)\n";
 $text .= "Control Fields\n";
 foreach $field (@ctrlFields) {
   $text .= " $field=" . $self->ctrl($field) ."\n";
 }
 $text .= "\n";
 $text .= "TaggedData Fields\n";
 foreach $field (@tags) {
   next if $field eq 'sdfControl';
  #next if grep /^$field$/, @ctrlFields;
   $text .= "[$field]\n";
   $text .= "$self->{$field}\n" if ($self->{$field});
 }
 $text .= "____________\n";
 return($text);
}
#_________________________
1; # required by require()

__END__

=head1 NAME

PTools::SDF::TAG - Implements a Simple Data File in "Tagged Data" format

=head1 VERSION

This document describes version 0.09, released Feb 15, 2003.

=head1 SYNOPSIS

    use PTools::SDF::TAG;

    $tagObj = new PTools::SDF::TAG("$fileName");

Access and set I<data> field values.

    $dataValue = $tagObj->param("fieldName");

    $tagObj->param("fieldName", "new value");

Access and set I<control> field values.

    $ctrlValue = $tagObj->ctrl("fieldName");

    $ctrlValue = $tagObj->ctrl("ctrlField", "new value");

Determine the current field names contained in the $tagObj object.

     $fields = $tagObj->ctrl("dataFields");
   (@fields) = $tagObj->ctrl("dataFields");

    $tagObj->ctrl("fileName",  "data/control.tmp");
    $tagObj->ctrl("dataFields","folder:seqnbr");

    $tagObj->ctrl("fileName", "newFile");
    $tagObj->save;


=head1 DESCRIPTION

B<PTools::SDF::TAG> is used to simplify data file access, and to
eliminate dependance on field positions within files.
This package reads and writes files in the following format.

     [fieldName1]
     some field value
     [fieldName2]
     other field with
     a multiline value
     [fieldName3]
     another field value


=head2 Constructor

=over 4

=item new ( [ FileName ] [, Mode ] [, FieldNames ] )

Creates a new B<PTools::SDF::TAG> object and, if a B<FileName> parameter is
specified and the file currently exists, loads file data into the object.

=over 4

=item FileName

The B<FileName> parameter is optional. When specified and the data file
exists, the file is loaded into the new object. If the specified file
does not exist when the object is created, the filename will be used 
by the B<save> method to create a new file, if possible.

This class is often used simply to store data in memory during the
execution of a script. It is often convenient to use familiar data 
structures, such as this file format, without any actual disk file.

=item Mode

The B<Mode> parameter is not currently implemented in this class.

=item FieldNames

When it is not appropriate to embed a comment header within a
data file to define the field names for each record, pass a
B<FieldNames> parameter to the B<new> method. This can be 
either a colon separated list of fields, or an array.

=back

Examples

 $tagObj = new PTools::SDF::TAG;

 $tagObj = new PTools::SDF::TAG( "/home/cobb/data/testfile.tag" );

=back


=head2 Methods

=over 4

=item param( DataFieldName [ DataFieldValue ] )

Fetch or set a data value.

Examples:

  $fieldCount = $ref->param;

  $fieldValue = $ref->param($fieldName);

  $ref->param($fieldName, $newValue);


=item delete ( FieldName )

Delete the value for a named data field.

Example:

    # Delete the value for the 'proddesc' field

    $tagObj->delete( 'proddesc');



=item ctrl( CtrlFieldName [ CtrlFieldValue ] )

Fetch or set a control parameter.

Examples:

  $ctrlFields = $tagObj->ctrl;                 # string of field names
 (@ctrlFields) = $tagObj->ctrl;                # array of field names

  $fieldValues = $tagObj->ctrl($fieldName);    # string of values for field
 (@fieldValues) = $tagObj->ctrl($fieldName);   # array of values for field 

  $tagObj->ctrl($fieldName, $newValue);
  $tagObj->ctrl($fieldName, @newValues);

Note that the 'version' and 'ctrlFields' values can NOT be changed
using the B<ctrl> method.


=item ctrlDelete ( CtrlField )

Delete the value for a named control field in the current object.

Example:

 $tagObj->ctrlDelete('fileName');



=item tag2sdf( [ FieldNameList ] )

This method is is designed for use with a special form of the B<param> 
method in the B<PTools::SDF::SDF> class. If a hash reference is passed for the
B<FieldName> parameter, this hash ref will I<replace> the data record 
specified by the B<Index> parameter. I<Note that no checking is done>. 
It is up to the programmer to ensure appropriate key names and values.

 use PTools::SDF::SDF;
 use PTools::SDF::TAG;

 $sdfObj = new PTools::SDF::SDF;
 $tagObj = new PTools::SDF::TAG( "myFile.tag" );

 $tagHashRef = $tagObj->tag2sdf;

 $nextRecord = $sdfObj->count;          # (one-based count)

 $sdfObj->param( $nextRecord, $tagHashRef );


=item save ( [ UserID ] [, NewFileName ] [, Heading ] )

Write the data in the current object out to a disk file.

B<Note>: Only those fields that have an entry in the B<dataFields>
I<control parameter> will be written to the disk file. 
See the B<ctrl> method, above, for details on using this attribute.

In addition, the only I<control parameters> that are saved with the
file are the B<field names>.


=over 4

=item UserID

By default the B<PTools::SDF::TAG> module adds a header that includes the
uname of the person running the current script. Use this parameter
to log a different user name.

Example:

    $webUserid = $ENV{'REMOTE_USER'};   # (from Web Server Basic Auth)

    $tagObj->save( $webUserid, $filename );


=item NewFileName

By default the B<PTools::SDF::TAG> module saves the file using the original
name specified when creating the current object. This can be changed
by passing a new file name here.

=item Heading

By default the B<PTools::SDF::TAG> module adds a header that includes a date
stamp (Unix "epoch" number) of when the file was saved. To write a
different header, pass the text here.

=back

Examples:

 $tagObj->save;

 ($stat,$err) = $tagObj->save;

 $tagObj->save( undef, "newfilename" );


Another Example:

 $tagObj->ctrl('fileName', "newfilename" );

 $tagObj->save;

 ($stat,$err) = $tagObj->status;


=item sort

The B<sort> method is not implemented in this class.


=item isLocked

=item notLocked

Determine whether a lock is held on the data file associated
with the current object.


=item status

=item stat

=item err

Determine whether an error occurred during the last call to a method on
this object. The B<stat> method returns different values depending on
the calling context.

 ($stat,$err) = $tagObj->status;

 $stat = $tagObj->stat;     # scalar context returns status number
 ($err)= $tagObj->stat;     # array context returns error message

 $err = $tagObj->err;


=item dump

Display contents of the current B<PTools::SDF::TAG> object. This is useful
during testing and debugging, but does not produce a "pretty" format.
For large data files the output can be quite lengthy.

Example:

 print $tagObj->dump;

=back


=head1 INHERITANCE

This B<PTools::SDF::TAG> class inherits from the B<PTools::SDF::File> 
abstract base class.  Additional methods are available via this parent 
class.


=head1 SEE ALSO

See
L<PTools::SDF::Overview>,
L<PTools::SDF::ARRAY>, L<PTools::SDF::CSV>,  L<PTools::SDF::DB>,
L<PTools::SDF::DIR>,   L<PTools::SDF::DSET>, L<PTools::SDF::File>, 
L<PTools::SDF::IDX>,   L<PTools::SDF::INI>,  L<PTools::SDF::SDF>,
L<PTools::SDF::Lock::Advisory>,  L<PTools::SDF::Lock::Selective>, 
L<PTools::SDF::Sort::Bubble>,    L<PTools::SDF::Sort::Quick> and 
L<PTools::PTools::SDF::Sort::Shell>.


=head1 AUTHOR

Chris Cobb, E<lt>nospamplease@ccobb.netE<gt>

=head1 COPYRIGHT

Copyright (c) 1997-2007 by Chris Cobb. All rights reserved. 
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
