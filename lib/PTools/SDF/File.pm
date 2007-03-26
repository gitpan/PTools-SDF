# -*- Perl -*-
#
# File:  PTools/SDF/File.pm
# Desc:  Abstract base class for "Simple Data File" modules
# Date:  Thu Oct 14 10:30:00 1999
# Note:  See "POD" at end of this module.
#
# The set of "SDF" modules includes several modules for "Simple Data Files"
# while the "PTools::SDF::File" class provides a foundation for these modules.
#
# Note:  Various subclasses violate the Liskov Substitution Principle.
#        The "param" method must take different parameters depending
#        on implementation details in the subclass. Caveat programmer.
#

package PTools::SDF::File;
 require 5.001;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.08';
#@ISA     = qw( );

#______________________________________________
# Template for required methods in subclasses. The
# ABSTRACT METHOD is defined at the end of this module.
#
sub new        { ABSTRACT METHOD @_ }
sub save       { ABSTRACT METHOD @_ }
sub ctrl       { ABSTRACT METHOD @_ }
sub param      { ABSTRACT METHOD @_ }
sub delete     { ABSTRACT METHOD @_ }
sub ctrlDelete { ABSTRACT METHOD @_ }
sub sort       { ABSTRACT METHOD @_ }
sub dump       { ABSTRACT METHOD @_ }
sub setError   { ABSTRACT METHOD @_ }

# Provide a DESTROY method here so the autoloader 
# doesn't need to look any further to find one.
sub DESTROY  { }

#______________________________________________
# Extendible method: Easily add new lock modules.
# For example, create a new SDF/Lock/Custom.pm module.
# Ensure the module has a "new" a "lock" and an "unlock"
# method. Invoke the method on existing PTools::SDF::<Module> 
# objects.
#
#   use PTools::SDF::INI;
#   $iniRef  = new PTools::SDF::INI($filename);
#   $methods = [ "lock", "unlock" ];
#   $iniRef->extend($methods, 'PTools::SDF::Lock::Custom');
#   $iniRef->lock(@lockParams);
#   $iniRef->unlock(@unlockParams);
#
# This way, any client script that makes use of the
# PTools::SDF::<Module> classes can specify which lock module
# to use in any given circumstance. Also, when no
# locking is used, unnecessary code is eliminated.
#
sub lock {
   my($self,@params) = @_;

   my($ref,$stat,$err) = (undef,0,"");
   #
   # If not already extended, use default extension class
   #
   $ref = $self->extended("lock");
   $ref or ($ref,$stat,$err) = 
	$self->extend( ["lock","unlock"], "PTools::SDF::Lock::Advisory" );
   # 
   # Invoke the extended method
   #
   $stat or ($stat,$err) = $self->expand('lock',@params);

   $self->setError( $stat,$err );
   return($stat,$err) if wantarray;
   return $stat;
}

sub unlock {
   my($self,@params) = @_;
   # 
   # Invoke the extended method. This implies 
   # that 'lock' must have been called (or
   # 'unlock' extended) first.
   #
   my($stat,$err) = $self->expand('unlock',@params);

   $self->setError( $stat,$err );
   return($stat,$err) if wantarray;
   return $stat;
}

# The following *assumes* that the extended lock module provides
# both "isLocked" and "notLocked" methods.

sub isLocked  { return $_[0]->{ext_lock} ? $_[0]->{ext_lock}->isLocked  : "0" }
sub notLocked { return $_[0]->{ext_lock} ? $_[0]->{ext_lock}->notLocked : "1" }

#______________________________________________
# Allow user-defined replacement for some methods.
# See lock/unlock (above) and sort (in SDF.pm) for
# usage examples. This method can be invoked by any
# client script using the PTools::SDF::<Module> classes;
# however, only "extendible" methods are extended.
#
sub extend {
   my($self,$methods,$class,@params) = @_;

   my($ref,$stat,$err) = (undef,0,"");

   eval "use $class";
   if ( $@ ) {
      my($pack,$file,$line)=caller();
      my $module = $pack .".pm";
         $module =~ s#\:\:#/#g;

      $stat = -1;
      $@ =~ /Can't locate/ and 
	 $err = "Class '$class' not found in '$module' at line $line ($PACK)";
      $err or 
	 $err = "Class '$class' failed in '$module' at line $line ($PACK)";
   } else {
      ($ref,$stat,$err) = $class->new(@params);         # Instantiate extension
      if (! $ref) { 
	 # do nothing if instantiation failed
      } elsif (ref $methods) {
	 map { $self->ctrl("ext_$_", $ref) } @$methods; # eg, ["lock","unlock"]
      } else {
         $self->ctrl("ext_$methods", $ref);             # eg, "sort"
      }
   }
   $self->setError($stat,$err);
   return($ref,$stat,$err) if wantarray;
   return $ref;
}

#______________________________________________
# The "extended" method will return a reference
# to a previously extended method. Clear as mud? 
# See usage in "lock" above and "expand" below.
#
sub extended { $_[0]->ctrl("ext_$_[1]"); }

#______________________________________________
# Remove reference(s) to previously extended method(s).
# ToDo: add a ctrlDelete method similar to 'delete'
#       (but this must be done in the subclasses).
#
sub unextend { 
   my($self,$methods) = @_;

   if (ref $methods) {
      map { $self->{"ext_$_"} = undef } @$methods; # eg, ["lock","unlock"]
   } else {
      $self->{"ext_$methods"} = undef;             # eg, "sort"
   }
   return;
}
#______________________________________________
# The expand method is used by extendible methods to 
# invoke the extended object. This should be considered 
# "protected" or private to subclasses of PTools::SDF::File.
# Note that the current PTools::SDF::<Module> object is
# prepended to the @params list during callback.
#
sub expand {
   my($self,$method,@params) = @_;

   my($ref,$stat,$err);

   $ref = $self->extended($method);
   #_______
   # Verify we actually can invoke $method 
   #
   my($pack,$file,$line)=caller();
   my $module = $pack .".pm";
      $module =~ s#::#/#g;

   ref $ref or ($stat,$err) = 
      (-1,"No object found for '$method' in '$module' at line $line ($PACK)");

   $stat or $ref->can($method) or ($stat,$err) = 
      (-1,"No '$method' method available in '$module' at line $line ($PACK)");
   #_______
   # Invoke the object associated with this method
   # (note that $self is prepended to @params list).
   #
   $stat or ($stat,$err) = $ref->$method($self,@params);

   return($stat,$err) if wantarray;
   return $stat;
}
#______________________________________________
# unescape any IFS characters
#
sub unescapeIFS {
    my($self,$todecode) = @_;
    my $IFS   = $self->ctrl('ifs') || ":";
    my($IFSck)= $IFS;
    $IFSck    =~s/($IFSck)/uc sprintf("%02x",ord($1))/eg;
    local($^W=0);
    $todecode =~ s/%($IFSck)/pack("c",hex($1))/ge;
    return $todecode;
}

# URL-encode any IFS characters
# characters like : ! , work great
# characters like * % ) do not
sub escapeIFS {
    my($self,$toencode) = @_;
    my $IFS   = $self->ctrl('ifs') || ":";
    local($^W=0);
    $toencode =~s/($IFS)/uc sprintf("%%%02x",ord($1))/eg;
    return $toencode;
}

# unencode URL-encoded data          (copied shamelessly from L.Stein's CGI.pm)
sub unescape {
    my($self,$todecode) = @_;
    $todecode =~ tr/+/ /;                                   # plusses to spaces
    $todecode =~ s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;
    return $todecode;
}

# URL-encode data                    (copied shamelessly from L.Stein's CGI.pm)
sub escape {
    my($self,$toencode) = @_;
    $toencode=~s/([^a-zA-Z0-9_\-.])/uc sprintf("%%%02x",ord($1))/eg;
    return $toencode;
}

sub writeLogFile {
  my($self,$logMessage,$logFile) = @_;

  $logFile or $logFile = "/tmp/SDF_log";
  local *LOG;
  open(LOG,">>$logFile") || return;
  print LOG "$logMessage\n";
  close(LOG);
  return;
}

# The strange syntax used in creating this subroutine provides
# for using the "indirect notation" shown above. While this is
# usually a bad thing, this time it results in clean semantics.
#
sub METHOD::ABSTRACT
{   my($class,$object,@args) = @_;

    my($file,$line,$method) = (caller(1))[1..3];

    warn "\nError: invalid call to abstract method\n";
    warn "  to method '$method'\n";
    warn "  in object '$object'\n";
    warn "  arguments '@args'\n"     if scalar @args;
    die  "  from file '$file' at line $line\n";
}
#_________________________
1; # required by require()

__END__

=head1 NAME

PTools::SDF::File - Abstract base class for "Simple Data File" modules

=head1 VERSION

This document describes version 0.08, released Nov 12, 2002.

=head1 SYNOPSIS

This class is intended for use by module designers when creating a new
subclass to handle another type of "simple data file."

    package NewFileType;

    use vars qw( $VERSION @ISA );
    $VERSION = '0.01';
    @ISA     = qw( PTools::SDF::File );

    use PTools::SDF::File;

    # After creating this inheritance structure, the designer must
    # implement all of the required abstract methods in the parent 
    # class, including the following.

    sub new        { }
    sub param      { }
    sub ctrl       { }
    sub delete     { }
    sub ctrlDelete { }
    sub save       { }
    sub sort       { }
    sub setError   { }
    sub dump       { }


=head1 DESCRIPTION

B<PTools::SDF::File> is used to provide a foundation for various classes that
provide interfaces to "simple" data file types.

Some of these subclasses violate the Liskov Substitution Principle.
The B<param> method will take different parameters depending on the 
subclass. This is simply due to differences in the format of the
data records in various file types. However, all attempts should be 
made to keep as many of the methods as similar as possible across
the subclasses.

Modules currently exist to implement various "Simple Data Files"
including a "Self Defining File" format, Windows ".INI" files, 
"tagged" data files, and others. See L<PTools::SDF::Overview> for details.


=head2 Constructor

=over 4

=item new ( Options )

This is an abstract method. Implementation is up to the designer
of each particular subclass. 

This method should include the option to load a data file upon 
instantiation or simply return an empty object.

=back


=head2 Abstract Methods

The following methods are expected to exist in each subclass, and
are expected to work in a similar manner to existing subclasses.
Refer to the following notes for implementation guidelines.

See documentation on the existing subclass modules for implementation 
examples including L<PTools::SDF::INI>, L<PTools::SDF::SDF> and L<PTools::SDF::TAG>.

=over 4

=item param ( Options )

Fetch or set field values within a record. When called without any
parameters, returns a zero-based count of entries in the object.


=item ctrl ( CtrlField [, CtrlValue ] )

Fetch or set B<ControlField> parameters within an object. This can
also be used to cache temporary data in the current B<PTools::SDF::> object.
See the B<dump> method for an example of displaying control fields 
and values.

=over 4

=item CtrlField

Specify the field name to access within the indexed record.

=item CtrlValue

The B<CtrlValue> is an optional parameter that is used to set
the value of the specified B<CtrlField>. Without a this parameter,
the current value of the field is returned.

=back

Example:

    # Specify a new file name for the current PTools::SDF::Subclass object

    $sdfObj->ctrl( "fileName", '/tmp/newDataFilename' );

    # Obtain the file name for the current PTools::SDF::Subclass object

    $fileName = $sdfObj->ctrl( "fileName" );


=item ctrlDelete

Delete the value for a named control field in the current object.

Example:

    $sdfObj->ctrlDelete('readOnly');


=item delete ( Options )

Delete one or more entire records from the current B<PTools::SDF::Subclass>
object. The deleted entry/ies should available as a return parameter.


=item save ( Options )

Save any modifications to the file data.

The implementation is left up to the module designer.

Example:

    $sdfObj->save( undef, "newfilename" );


=item sort ( Options )

This is a I<required> method even though some file implementations may
not be in a format where a sort operation would be meaningful. In these
cases, simply define a sort method that sets an error condition.

Currently, only the B<PTools::SDF::SDF> subclass support a sort method.
The options used for sorting depend entirely on which sort
module is loaded at the time of the call. There are several
sort modules available. See L<PTools::SDF::SDF> for further details.


=item setError ( Status, ErrorText )

This method is used internally in an B<PTools::SDF::Subclass> to set an
error condition. Note, however, that any script may call this method.

=over 4

=item status

A numeric status code where any non-zero value indicates an error.

=item errortext

A text string indicating the nature of the error condition.

=back

Examples:

    $sdfObj->setError(0,"");        # restore object to a "no error" state

    $sdfObj->setError(-1, "Edit failed for field '$field' in record '$idx'");


=item dump ( Options )

Display contents of the current B<PTools::SDF::Subclass> object. This is useful
during testing and debugging, but does not need to produce a "pretty" 
format.  For data files that can contain many records, providing a way
to limit the output will be most useful.

The implementation is left up to the module designer.

Examples:

    print $sdfObj->dump;          # can produce a *lot* of output

    print $sdfObj->dump( 0, -1 )  # dump only the "control field" values

    print $sdfObj->dump( 10, 5 )  # dump recs 10 through 15.

=back
 

=head2 Concrete Methods

=over 4

=item lock ( [Retry [, Sleep ] [, CreateMode ] )

This method locks the physical file associated with the
various B<PTools::SDF::Subclass> objects. If the B<filename> passed to
the B<new> method did not exist at object instantiation,
the file will exist after a successful lock.

The options used for locking depend entirely on which lock
module is loaded at the time of the call. Currently there is
one lock module available (listed in the SEE ALSO section, below).

Options used by the default L<PTools::SDF::Lock::Advisory> module includes
the following. See description of the B<extend> method, below,
on how to select other lock modules.

=over 4

=item Retry

If the lock fails, the B<retry> parameter indicates how many 
times the lock module should rety. Default is 0 retries.

=item Sleep

If the lock fails, and the B<retry> parameter is non-zero,
the B<sleep> parameter indicates how many seconds to sleep
between reties. Default is 1 second.

=item CreateMode

If the file represented by the current B<PTools::SDF::Subclass> object
does not exist, the B<createmode> parameter indicates what open
mode will be used to create the file. The default value
is B<0644> (equivalent to "-rw-r--r--").

=back

Example:

    ($stat,$err) = $sdfObj->lock;
    $stat and die $err;


Note that the B<PTools::SDF::Lock::Advisory> module is designed to work with
I<any> script as a stand-alone lock manager. However, when this module
is not used via one of the B<PTools::SDF::Subclass> modules the calling
syntax changes. See L<PTools::SDF::Lock::Advisory> for details.


=item isLocked, notLocked

These methods exist to test the "lock state" of the 
current B<PTools::SDF::Subclass> object.

Examples:

    $sdfObj->isLocked  or do { ... };

    $sdfObj->notLocked or do { ... };


=item unlock

Unlock the physical file associated with the current object.
The default B<PTools::SDF::> lock module uses simple advisory locking,
so any lock held will be released upon object destruction,
when the script ends, etc.

Example:

    $sdfObj->unlock;


=item extend ( MethodList, ClassName )

The B<extend> method is the mechanism used to select which external
class will be used for the B<lock> method in this class. Each new
subclass based on this module should support this lock strategy.

Currently a method must be explicitly created as I<extendible>,
and currently only the B<lock> / B<unlock> methods in this
class and the B<PTools::SDF::SDF> B<sort> method are I<extendible>
using this mechanism.

Module designers are free to include I<extendible> methods in
their modules as appropriate. Refer to the code for examples
of implementation.

=over 4

=item MethodList

Either a string naming a single method (e.g., B<sort>), or an array 
reference naming multilpe methods (e.g., B<lock> / B<unlock>). The
methods must be B<object methods>, not class methods.

=item ClassName

The name of the Perl class that will be used to perform the method(s)
indicated in the B<MethodList> parameter.

=back

Examples:

    $sdfObj->extend('sort', "PTools::SDF::Sort::Quick");

    $sdfObj->extend( [ "lock","unlock" ], "PTools::SDF::Lock::Advisory");

Note that, in the last example above, the syntax shown using braces 
("[]") is the actual syntax used to pass an array reference to the 
extend method, and not an indication of "optional" parameters.


Any Perl module can be specified but, at a minimum, it should be able
to do the following.

=over 4

=item *

successfully be included via the "use" statement

=item *

contain a B<new> method that instantiates an object (necessary
so the object may be cached in the B<PTools::SDF::Subclass> object).

=item *

contain the necessary methods for the desired operation
(e.g., "sort" for a B<sort> module and "lock/unlock" for
a B<lock> module).

=back


=item extended ( MethodName )

Returns a boolean value that indicates whether the B<MethodName>
is currently I<extended>. Intended for use by module designers
who wish to provide a default method/Class for an I<extendible>
method.

Example:

    $sdfObj->extended( "method" )  or  $sdfObj->extend( "method", "Class" );


=item unextend ( MethodList )

Used to delete the current definition for an I<extended> method. The
B<MethodList> parameter here is identical as in the B<extend> method.


=item expand ( MethodName )

This method is used by module designers to invoke an I<extended> method.
Refer to the implementation of the B<lock> method in this class for
details.


=item escapeIFS ( TextString )

Implementations of certain file types specify a record separator
or "internal field separator" (IFS) character used to delimit 
data fields. For these file types, it is imperative that no user
entered data contain the IFS character. Otherwise that particular
record will become corrupt and, in effect, contain an "extra field."

To avoid this situation, the B<escapeIFS> method is provided to 
encode any IFS character(s). Module designers can use this in the
B<save> method while writing the data file to disk.

Note that characters like colon (":"), exclamation point ("!") and
pipe ("|") work great as field delimiters. Characters such as
asterisk ("*") and percent ("%") do not.

B<Performance Note>: for large files this operation is an expensive
overhead. Modules that use this method should contain a mechanism to 
disable this functionality when it is not necessary.


=item unescapeIFS ( TextString )

If there is a possibility that data fields may contain an I<escaped>
IFS character, as described above, this method will reverse the
encoding of these characters. Module designers can use this in the
B<new> method while reading the data file from disk.


=item escape ( TextString )

This method will encode all characters in the B<TextString>
parameter per I<URL encoding> guidelines.

=item unescape ( TextString )

This method will decode all characters in the B<TextString>
parameter per I<URL encoding> guidelines.


=item writeLogFile ( TextString [, LogFileName ] )

This utility method is provided as many projects include some
type of message logging.

=over 4

=item TextString

Message text to be written on the log file.

=item LogFileName

A valid filename to which B<TextString> will be appended.

=back

Example:

    $sdfObj->writeLog( "$date: Error: $err at $line in $PACK", $logFile );

=back


=head1 INHERITANCE

This B<PTools::SDF::File> is an abstract base class intended for use by the 
various "Simple Data File" subclasses that implement a particular
file format.

=head1 SEE ALSO

See
L<PTools::SDF::Overview>,
L<PTools::SDF::ARRAY>, L<PTools::SDF::CSV>,  L<PTools::SDF::DB>,
L<PTools::SDF::DIR>,   L<PTools::SDF::DSET>, L<PTools::SDF::IDX>,
L<PTools::SDF::INI>,   L<PTools::SDF::SDF>,  L<PTools::SDF::TAG>,
L<PTools::SDF::Lock::Advisory>, 
L<PTools::SDF::Sort::Bubble>, L<PTools::SDF::Sort::Quick> and 
L<PTools::SDF::Sort::Shell>.

In addition, several implementation examples are available.

See
L<PTools::SDF::File::AutoHome>, L<PTools::SDF::File::Mnttab> and 
L<PTools::SDF::File::Passwd>. These are contained in the
'PTools-File-Cmd' distribution available on C

=head1 AUTHOR

Chris Cobb, E<lt>nospamplease@ccobb.netE<gt>

=head1 COPYRIGHT

Copyright (c) 1999-2007 by Chris Cobb. All rights reserved. 
This module is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

=cut
