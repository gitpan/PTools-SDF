# -*- Perl -*-
#
# File:  PTools/SDF/INI.pm
# Desc:  Load data files into associative (hash) arrays
# Date:  Tue Feb 11 10:00:00 1997
# Mods:  Thu Oct 14 10:30:00 1999
# Lang:  Perl 5.0
# Stat:  Prototype
#
# ToDo:
# . Turn docco at end of script into "pod" format
#

package PTools::SDF::INI;
 require 5.001;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.09';
 @ISA     = qw( PTools::SDF::File );

 use PTools::SDF::File;

sub new {
   my($class,$fileName,$mode,@fields) = @_;
   my($self);
   local($/)="\n";    # Temporarially override the input record separator

   $self = {};                                      # use hash array
   bless $self, $class;
   $self->setError(0,"");                           # assume the best
   $self->ctrl('ctrlFields', "ctrlFields");         # initialize ctrl fields
   $self->ctrl('dataFields', @fields);              # initialize data fields

   $self->loadFileINI($fileName,$mode) if $fileName;

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


sub delete {
  my($self,$section,$fieldName) = @_;
  return delete $self->{$section}{$fieldName};    # delete a key, undef a hash
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


sub loadFileINI {
  my($self,$fileName,$mode) = @_;                    # Grab parameters
  #__________________________________
  # Used to confirm version of THIS subroutine
  #
  my($version)  = "1.0";                             # Version of THIS routine
  if ($mode && $mode =~ /^version$/i) {
     return($version);
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

     $self->_loadFileINI($mode,\*IN);
     close(IN);

  } else {
     my $error = sprintf("%s: $fileName in 'SDF_loadFileINI()'",$!);
     $self->{'sdfControl'}{'status'}= sprintf("%d",$!);  # error number
     $self->{'sdfControl'}{'error'} = $error;            # error message
  }
  return;
}


sub _loadFileINI {
  my($self,$mode,$fd) = @_;

  my($fieldName,$key,$value);
  while(<$fd>) {
     chomp;
     s/\015//g;                                      # Strip any ctl-M char

     if (/^(\s*)#|^(\s*)!|^(\s*);|^(\s*)$/) {        # skip comments, empties 
        next;

     #__________________________________
     # Note that when "$self->{$fieldName}" is NOT defined we MUST
     # initialize a reference to a new hash. When the fieldName
     # DOES exist we will just add to the currently defined array.
     # If the fieldName DOES exist when we check, it means that we 
     # have two field tags in the same file with the same name.
     #
     # Note that "$mode" is used as match criteria to only retreive
     # one section of the INI file.
     #
     } elsif (/^\[(.*)\]$/) {                        # we've got a new array 
	$fieldName = $1;

	if ($mode && $fieldName !~ /$mode/) {        # skip if mode w/o match
	   $self->{sdfControl}{readOnly} = "Data is read only: match excludes";
	   next;

	} elsif (! defined $self->{$fieldName}) {    # create if doesn't exist
           # If we don't init a new hash pointer, 
	   # here, then every "key=value" pair will
	   # show up in every [fieldTag] array. 
	   # Believe it or not. 
           #
           $self->{$fieldName} = {};                 # and init a NEW hash ptr
           $self->{'sdfControl'}{'dataFields'} .= "${fieldName}:";
        }

     } elsif ($mode && $fieldName !~ /$mode/) {      # skip if mode w/o match
	next;
     #__________________________________
     # Each time through this step we simply add to the array we're
     # currently building. This could be a previously defined "fieldName"
     # in which case values for any duplicate "key" names will be replaced
     # [ SHOULD THEY BE APPENDED ??]
     #
     } else {
	my $spa;
	($key,$value) = split(/\s*=\s*/,$_,2);
        $key   =~ s/^\s+//; # delete leading spaces from key
        $key   =~ s/\s+$//; # delete trailing spaces from key
        $value =~ s/^\s+//; # delete leading spaces from value

	if (!$fieldName) {                           # if no fieldName is set 
	   $fieldName = "__UNDEF__";                 # create a default section
           $self->{$fieldName} = {};                 # and init a NEW hash ptr
	}
       ## $self->{$fieldName}{$key} = $value;
        $self->{$fieldName}{$key} .= $value;
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
  $self->_saveFileINI;
  #
  close(OUT);
  return;
}


sub _saveFileINI {
  my($self) = @_;
  #__________________________________
  # Which do we want here? Field names from the "dataFields"
  # parameter created when the file was loaded? or the actual
  # fields currently defined in the array? Take your pick.
  #
  my(@tags,$tag,$dref,$hash,@keys,$key);
# @tags = sort keys %$self;                # dereference & get tags
  (@tags) = $self->ctrl('dataFields');     # collect from ctrl fields
  foreach $tag ("__UNDEF__", @tags) {      # ensure writing "empty" section
     if ($tag eq 'sdfControl') {
       next;
     }
     #
     # Omit our special "empty" section designator
     #
     print OUT ($tag eq "__UNDEF__" ? "\n" : "[$tag]\n");

     $hash = $self->{$tag};                # this one takes 2 steps
     (@keys) = sort keys %$hash;           # dereference & get keys

     foreach $key (@keys) {
        print OUT "$key = $self->{$tag}{$key}\n";
     }
     print OUT "\n";
  }
  return;
}


sub ctrlParam {
   my($self,$param,@values) = @_;

   ## $self->setError(0,"");   # Don't reset these here.

   if ($param) {
      #______________________________________________________
      # Update param if we have a param and values; otherwise,
      # just return the parameter's current value.
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
      #
      } else {
	 return(split(':',$self->{'sdfControl'}{$param})) if wantarray;
	 return($self->{'sdfControl'}{$param});
      }
   } else {
      #______________________________________________________
      # If we have no param then return all of the control field
      # names. Format return value depending on current context.
      #
      return(split(':',$self->{'sdfControl'}{'ctrlFields'})) if wantarray;
      return($self->{'sdfControl'}{'ctrlFields'});
   }
}


sub recParam {
   my($self,$iniSect,$param,$value) = @_;

   $self->setError(0,"");
   ($iniSect ||= "__UNDEF__") if $param;
   #______________________________________________________
   # Figure out if we are setting a parm, merely returning it's 
   # value, or returning all values for the record/array.
   #
   $value ||= "";
   $value = "0 but True" if ! $value && length($value) == 1;
   if ($param) {
      #______________________________________________________
      # Update param if we both a param and a value; otherwise,
      # just return the parameter's current value.
      #
      if ($value) {
         $value = "0" if $value eq "0 but True";
	 return $self->{$iniSect}{$param} = $value;
      } else {
	 return $self->{$iniSect}{$param};
      }
   #______________________________________________________
   # If we ONLY have a section name, format an approprite 
   # return value.  Return values are
   #   array context:  array of fieldnames for the section
   #  scalar context:  string of fieldnames "name1:name2:..."
   #
   # Note that for this test to work when "$recNumber" is "0", we MUST
   # have done the test above to convert "$recNumber" to "0 but True".
   # We don't have to convert it back to "0" (at least with Perl5.002).
   #
   } elsif ($iniSect) {
      my($dref) = $self->{$iniSect};
      my(%hash) = %$dref;
      my(@fields) = sort keys %hash;
      return (@fields) if wantarray;
      return (join(':', @fields));
   #______________________________________________________
   # If we have no paramters, then just return section count
   # or a list of the currently defined section names.
   #
   } else {
      my(%dref) = %$self;                    # dreference pointer to array
      if (wantarray) {
         my(@list) = ();
         map { push @list, $_ unless /^sdfControl/ } sort keys %dref;
         return @list;                       # return section list ...?
      }
      my(@count) = keys %dref;               # collect hash keys
      return $#count;       # ONE based      # or ... return section count
    # return $#count - 1;   # ZERO based     # or ... return section count
   } 
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
		       $_[0]->{'sdfControl'}{error}=$_[2]||"" ) }

sub status   { return( $_[0]->{'sdfControl'}{status}||0,
		       $_[0]->{'sdfControl'}{error}||"" )       }

sub stat     { ( wantarray ? ($_[0]->{'sdfControl'}{error}||"") 
			   : ($_[0]->{'sdfControl'}{status}||0) ) }

sub err      { return( $_[0]->{'sdfControl'}{error}||"" )         }

   *getError = \&status;     # allow for calling using various method names.
   *getErr   = \&status;     # allow for calling using various method names.
   *setErr   = \&setError;   # allow for calling using both method names.

   *statOnly = \&stat;
   *errOnly  = \&err;

#sub stat {     # Confirm these can be removed. See reimplementation, above
#  return( $_[0]->{'sdfControl'}{status}||"" ) unless wantarray;
#  return( $_[0]->{'sdfControl'}{status}||0, $_[0]->{'sdfControl'}{error}||"" );
#}
#sub err {
#  return( $_[0]->{'sdfControl'}{error}||"" ) unless wantarray;
#  return( $_[0]->{'sdfControl'}{status}||0, $_[0]->{'sdfControl'}{error}||"" );
#}

sub dump {
 my($self)= @_;

 my $field;
 my $text = "";
 my($pack,$file,$line)=caller();
 #_____________________________________________________
 my @tags = sort keys %$self;             # dereference & get section tags
 my (@ctrlFields) = $self->ctrl('ctrlFields');
 $text  = "DEBUG: (INI\:\:dump) self='$self'\n";
 $text .= "CALLER $pack at line $line ($file)\n";
 $text .= "Control Fields\n";
 my $tmp;
 foreach $field (@ctrlFields) {
    $tmp = $self->{'sdfControl'}->{$field}||"";
    $text .= " $field=$tmp\n";
 }
 $text .= "\n";
 foreach $field (@tags) {
    next if $field eq 'sdfControl';
    $text .= "[$field]\n";
    my $hash = $self->{$field};
    my (@keys) = sort keys %$hash;        # dereference & get data keys
    my $key;
    foreach $key (@keys) {
      $text .= " $key = $self->{$field}{$key}\n";
    }
 }
 $text .= "____________\n";
 return($text);
}
#_________________________
1; # required by require()

__END__

=head1 NAME

PTools::SDF::INI - Implements a Simple Data File in "Windows INI" format

=head1 VERSION

This document describes version 0.08, released Feb 15, 2003.

=head1 SYNOPSIS

     use PTools::SDF::INI;

     $iniObj = new PTools::SDF::INI( $fileName );

 or  $iniObj = new PTools::SDF::INI( $fileName, $iniSection, @fields );

     $fieldNames    = $iniObj->param($sectName);    # "name1:name2:name3"
     (@fieldNames)  = $iniObj->param($sectName);    # array of field names

     $fieldValue    = $iniObj->param($sectName, $fieldName);

     $iniObj->param($sectName, $fieldName, $newValue);

     $sectionCount  = $iniObj->param;               # number of "sections"
    (@sectionNames) = $iniObj->param;               # name of each section

The following is roughly equivalent to the B<dump> method used to
display the contents of objects of this class.

    foreach my $secName ( $iniObj->param ) {

         print "$secName\n";

         foreach my $fieldName ( $iniObj->param( $secName ) ) {

             my($fieldValue) = $iniObj->param($secName, $fieldName);

             print "  $fieldName = $fieldValue\n";
         }
     }


=head1 DESCRIPTION

The B<PTools::SDF::INI> class reads and writes files in the MS Windows '.INI' 
format.

   [personalData]
     first = field value
     last = other field value
     telnet = another field value

B<Warning>: I never found any documentation regarding this file format.
If you can point me to official MicroSoft documentation on this format,
I would appreciate it. Thanks in advance.

=head2 Constructor

=over 4

=item new ( [ FileName ]  [, Match ] [, FieldNames ] )

Creates a new B<PTools::SDF::INI> object and, if a B<FileName> parameter is
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

=item Match

To load only a subset of the data file, pass a B<Match> value. This
value will be used to load only those I<section> names that match
the pattern.

Note that when a "subset" of a data file is loaded, the B<save>
method is disabled. Use the B<Force> parameter of the B<save>
method to override, or use the B<ctrl> method to specify a
different B<FileName> prior to calling B<save>.

=item FieldNames

When it is not appropriate to embed a comment header within a
data file to define the field names for each record, pass a
B<FieldNames> parameter to the B<new> method. This can be 
either a colon separated list of fields, or an array.

=back

Examples

 $iniObj = new PTools::SDF::INI;

 $iniObj = new PTools::SDF::INI( "/application_dir/data/testfile.ini" );

=back


=head2 Methods

=over 4

=item param ( [ SectionName, FieldName ] [, Value ] )

Fetch or set field values within a record. When called without any
parameters, returns a zero-based count of entries in the object.
Use the B<count> method to obtain a one-based count of entries.

=over 4

=item SectionName

Specify the B<SectionName> as defined in the B<PTools::SDF::INI> object.

=item FieldName

Specify the B<FieldName> to access within a particular B<SectionName>.

=item Value

The B<Value> is an optional parameter that is used to set the
value of the specified B<FieldName>. Without a this parameter,
the current value of the field is returned.

=back

Examples:

 $fieldValue = $iniObj->param( 'SectionOne', 'FieldOne' );

 $iniObj->param( 'SectionOne', 'FieldOne', "New Value" );



=item ctrl ( CtrlField [, CtrlValue ] )

Fetch or set I<control> field parameters within an object. This can
also be used to cache temporary data in the current B<PTools::SDF::INI> 
object.  Just be sure to use a unique attribute name and remember that 
this data will not be saved with the file data. See the B<dump> method 
for an example of displaying control fields and values.

=over 4

=item CtrlField

Specify the field name to access within the indexed record.

=item CtrlValue

The B<CtrlValue> is an optional parameter that is used to set
the value of the specified B<CtrlField>. Without a this parameter,
the current value of the field is returned.

=back

Examples:

 # Specify a new file name for the current PTools::SDF::INI object

 $fieldValue = $iniObj->ctrl( "fileName", '/tmp/newDataFilename' );

 # Fetch a colon-separated list of field names in the file.
 # In list context, an array of field names is returned.

 $fieldList   = $iniObj->ctrl( "dataFields" );
 (@fieldList) = $iniObj->ctrl( "dataFields" );

 # Specify a new list of fieldnames for the current object
 # WARN: this will *not* change any existing field names, and
 # only existing fields that appear in this list will be written
 # to the data file via the "save" method. This is provided as
 # a way to create a subset of a file, to add new fields, and/or
 # to re-arrange the field order when file is saved to disk.

 $iniObj->ctrl( "dataFields", "colon:separated:list:of:names" );
 $iniObj->ctrl( "dataFields", @fieldNameList );


=item ctrlDelete ( CtrlField )

Delete the value for a named control field in the current object.

Example:

 # Loading a subset of a data file sets an attribute to disable the
 # "save" method. This removes the attribute and re-enables "save":

 $iniObj->ctrlDelete('readOnly');


=item delete ( SectionName [, FieldName ] )

Delete one variable from the B<SectionName> in the current B<PTools::SDF::INI> object.
The deleted value is available as a return parameter. This will be whatever
was originally stored in this variable.

Examples:

 $value = $iniObj->delete( "SectionOne", "FieldTwo" );


=item save ( [ UserID ] [, NewFileName ] [, Heading ] [, Force ] )

Write the data in the current object out to a disk file.

B<Note>: Only those B<SectionNames> that have an entry in the B<dataFields>
I<control parameter> will be written to the disk file. 
See the B<ctrl> method, above, for details on using this attribute.

Note that no I<control parameters> are saved with the file.

=over 4

=item UserID

By default the B<PTools::SDF::INI> module adds a header that includes the
uname of the person running the current script. Use this parameter
to log a different user name.

Example:

 $webUserid = $ENV{'REMOTE_USER'};   # (from Web Server Basic Auth)

 $iniObj->save( $webUserid, $filename );


=item NewFileName

By default the B<PTools::SDF::INI> module saves the file using the original
name specified when creating the current object. This can be changed
by passing a new file name here.

=item Heading

By default the B<PTools::SDF::INI> module adds a header that includes a date
stamp (Unix "epoch" number) of when the file was saved. To write a
different header, pass the text here.

=item Force

If a "subset" of the original data file was loaded using "match"
criteria, the B<save> parameter is disabled by default. Pass any
non-null parameter here to override this default and force a save. 

B<WARN>: This will cause any records omitted during the load to be lost.

=back

Examples:

 $iniObj->save;

 ($stat,$err) = $iniObj->save;

 $iniObj->save( undef, "newfilename" );


Another Example:

 $iniObj->ctrl('fileName', "newfilename" );

 $iniObj->save;

 ($stat,$err) = $iniObj->status;

 $stat and die $err


=item isLocked 

=item notLocked

Determine whether or not the data file associated with the
current object has an 'advisory lock' in effect.

 if ( $iniObj->isLocked ) do { . . . }

 if ( $iniObj->notLocked ) do { . . . }


=item status

=item stat

=item err

Determine whether an error occurred during the last call to a method on
this object. The B<stat> method returns different values depending on
the calling context.

 ($stat,$err) = $iniObj->status;

 $stat = $iniObj->stat;     # scalar context returns status number
 ($err)= $iniObj->stat;     # array context returns error message

 $err = $iniObj->err;


=item dump 

Display contents of the current B<PTools::SDF::INI> object. This is useful
during testing and debugging, but does not produce a "pretty" format.
For large data files the output will be rather lengthy.

Examples:

 print $iniObj->dump;          # can produce a *lot* of output

=back


=head1 INHERITANCE

This B<PTools::SDF::INI> class inherits from the B<PTools::SDF::File> abstract base class.
Additional methods are available via this parent class.


=head1 SEE ALSO

See
L<PTools::SDF::Overview>,
L<PTools::SDF::ARRAY>, L<PTools::SDF::CSV>,  L<PTools::SDF::DB>,
L<PTools::SDF::DIR>,   L<PTools::SDF::DSET>, L<PTools::SDF::File>, 
L<PTools::SDF::IDX>,    L<PTools::SDF::SDF>, L<PTools::SDF::TAG>,
L<PTools::SDF::Lock::Advisory>, 
L<PTools::SDF::Sort::Bubble>, L<PTools::SDF::Sort::Quick> and 
L<PTools::SDF::Sort::Shell>.

=head1 AUTHOR

Chris Cobb, E<lt>nospamplease@ccobb.netE<gt>

=head1 COPYRIGHT

Copyright (c) 1997-2007 by Chris Cobb. All rights reserved. 
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
