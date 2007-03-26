# -*- Perl -*-
#
# File:  PTools/SDF/Lock/Advisory.pm
# Desc:  Lock/Unlock an open filehandle using ADVISORY locking
# Date:  Mon Apr 02 14:30:00 PDT 2001
#
# Abstract:
#        It is up to the calling module to pass an argument to the "lock"
#        method that is one of the following:
#        .  a filename/path
#        .  an open filehandle
#        .  an object that is any subclass of PTools::SDF::File 
#        Three additional optional parameters may be included
#        .  a "retry" count to retry the lock if it fails
#        .  a "sleep" time to pause between tries (defaults to 1 second)
#        .  a "mode"  to specify the file permssions (defaults to 0644)
#
#
# Synopsis:  BASIC -- lock a filename/filepath (note that the default
#            for the "$openMode" variable is 0644, or "-rw-r--r--")
#
#        use PTools::SDF::Lock::Advisory;
#
#        $lockObj = new PTools::SDF::Lock::Advisory;
#
#        ($stat,$err) = $lockObj->lock( $fileName );
#
#  or    $lockObj->lock( $fileName, $maxRetries, $sleepTime, $lockMode );
#
#        ($stat,$err) = $lockObj->status;
#
#        ($stat,$err) = $lockObj->unlock;
#
#        # Note: can either explicitly unlock or simply allow the
#        # "$lockObj" variable to fall out of scope (or exit the
#        # script, undefine, etc.) to release the lock.
#
#
# Synopsis:  ALTERNATE -- lock an open filehandle
#
#        use Fcntl;
#        use PTools::SDF::Lock::Advisory;
#
#        $lockObj = new PTools::SDF::Lock::Advisory;
#
#        local(*FH);
#        sysopen(FH, "/some/file", O_RDWR|O_CREAT, 0644) || die $!;
#        $fh = *FH;
#
#        ($stat,$err) = $lockObj->lock( $fh );
#  or    ($stat,$err) = $lockObj->lock( $fh, $maxRetries, $sleepTime );
#
#        # The "status" and "unlock" methods are the same as above,
#        # and a "$lockMode" parameter is not needed here.
#
#
# Synopsis:  ALTERNATE -- lock an instance of an "PTools::SDF::<module>" class
#            Note that the "$fileName" need not exist prior to calling
#            the "lock" method, but it will exist if the lock succeeds.
#
#        use PTools::SDF::INI;        # or PTools::SDF::SDF,  or PTools::SDF::TAG 
#
#        $iniObj = new PTools::SDF::INI( $fileName );
#
#        ($stat,$err) = $iniObj->lock( $maxRetries, $sleepTime );
#
#        # The "status" and "unlock" methods are the same as above.
#
#
# This module is designed for use as one of several possible "extended"
# lock methods within the PTools::SDF::<module> set of classes. See the
# PTools::SDF::File class for discussion and examples.
#
# WARN:  When this class is invoked by the 'extend' method in class
#        PTools::SDF::File, the invoking SDF object is passed as the first param.
#        However, to make this module more generally useful, the first 
#        param may also be a filename/path or an open filehandle GLOB. 
#        To accomodate this, shift off the first variable if it happens to 
#        be an PTools::SDF::File object or any subclass thereof. Also note that
#        return values from the "lock" method vary based on the caller.
#
# Unless you are using this module while designing PTools::SDF::<module> classes,
# use the syntax shown in the examples, above.
#

package PTools::SDF::Lock::Advisory;
 require 5.001;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw($VERSION @ISA);
 $VERSION = '0.07';
#@ISA     = qw( );

 use Fcntl qw( :DEFAULT :flock );              # in standard Perl distribution


sub new    { bless {}, ref($_[0])||$_[0]; }    # provide correct interitance
sub setErr { return( $_[0]->{STATUS}=$_[1]||0, $_[0]->{ERROR}=$_[2]||"" ) }
sub status { return( $_[0]->{STATUS}||0, $_[0]->{ERROR}||"" )             }
sub stat   { ( wantarray ? ($_[0]->{ERROR}||"") : ($_[0]->{STATUS} ||0) ) }
sub err    { return($_[0]->{ERROR}||"")                                   }

sub isLocked  { return( defined $_[0]->{_lockHandle} ? 1 : 0 ) }
sub notLocked { return( defined $_[0]->{_lockHandle} ? 0 : 1 ) }

   *advisoryLock   = \&lock;
   *advisoryUnlock = \&unlock;

sub lock
{   my($self,@params) = @_;

    my $objectMethod = 1;           # 1=called as object method
                                    # 0=called as class method
    if (! ref $self) {
	$self = $PACK->new;
	$objectMethod = 0;
    }
    my $sdfRef;
    $sdfRef = shift @params if ref $params[0] and $params[0]->isa("PTools::SDF::File");

    my($fileParam,$retry,$sleep,$lockMode,$openMode) = ();

    if ($sdfRef) {
	$fileParam = $sdfRef->ctrl('fileName');
	($retry,$sleep,$lockMode,$openMode) = @params;
    } else {
	($fileParam,$retry,$sleep,$lockMode,$openMode) = @params;
    }
    #______________________________________________________
    # Convert whatever we have here into a "file handle"
    #
    my($fh,$stat,$err) = $self->_createFileHandle( $fileParam, $openMode );

    #______________________________________________________
    # Next, attempt to lock the open file handle

    if ( ! $stat ) {
	($stat,$err) = $self->_lockFileHandle( $fh, $retry, $sleep, $lockMode );
    } 
    #______________________________________________________
    # Now, figure out what happened

    if ( (! $stat) and $sdfRef ) {
	# When lock successful and called by an object of PTools::SDF:: class
	# cache the filehandle in the calling object

	$sdfRef->ctrl('ext_lockHandle', $fh);
	# $sdfRef->ctrl('_lockObject', $self);   # See "ctrl('ext_lock')"
    }
    $self->setErr($stat,$err);

    #______________________________________________________
    # Beware that return values differ based on the caller! This
    # must happen to remain consistent with PTools::SDF:: method calls,
    # if we also want this to work as a "general purpose" module.
    # See syntax notes above on ways to invoke this method.

    if ($sdfRef) {                            # Don't return self when
	$sdfRef->setErr($stat,$err);          # called by an PTools::SDF:: obj
	return unless wantarray;
	return( $stat, $err );
    } elsif ($objectMethod) {                 # Don't return self when
   	return unless wantarray;              # called as "object" method
   	return( $stat, $err );
    } else {
	return( $self ) unless wantarray;     # MUST return self when
	return( $self, $stat, $err );         # called as "class" method
    }
}


sub _createFileHandle
{   my($self,$fileParam,$openMode) = @_;

    no strict;

    return $fileParam if fileno( $fileParam );   # is it a file handle? ...

    my $fileName = $fileParam;                   # nope ... it's file name

    $openMode ||= 0644;                          # "-rw-r--r--" is default

  # my $foo = O_RDWR|O_CREAT;
  # print "DEBUG: ARG='$foo' fileName='$fileName'\n";
  # print "DEBUG: creating filehandle in $PACK\n";

    local(*FH);
    if (! sysopen(FH, $fileName, O_RDWR|O_CREAT, $openMode) ) {
        return( undef, -1, "Can't open '$fileName': $!");
    }
    $self->{closeFlag} = 1;    # if we open it, we'll also close it, below

    my $fh = *FH;

  # print "DEBUG: fh='$fh' flieno(fh)='". fileno($fh) ."'\n";

    return( $fh, 0, "" );
}

sub _lockFileHandle
{   my($self,$fh,$retry,$sleep,$lockMode) = @_;

    # Note: The "$lockMode" parameter is ignored in this module
    # See the "PTools::SDF::Lock::Selective" class for details.

    ( $fh and fileno($fh) ) or
	return (-1, "Can't lock: not an open filehandle in '$PACK'");

    $retry = ( defined $retry ? int($retry) || 0 : 0 );
    $sleep = ( defined $sleep ? int($sleep) || 1 : 1 );
    $sleep = 0 unless $retry;                    # by default, skip retries

    my $count = 0;

    while (! flock($fh, LOCK_EX|LOCK_NB) ) {
	sleep $sleep if $sleep;
	if ($count++ > $retry) {
	    return (-1, "Unable to lock filehandle in '$PACK': $!");
	}
    }
    $self->{_lockHandle} = $fh;

    return (0,"");
}

   *DESTROY = \&unlock;         # Unlock FH if/when object falls out of scope

sub unlock
{   my($self,@params) = @_;

    my $sdfRef;
    $sdfRef = shift @params 
        if ( ref $params[0] and $params[0]->isa("PTools::SDF::File") );
    my($fh) = shift @params;

    if ( ! $fh ) {
	$sdfRef and $fh = $sdfRef->ctrl('ext_lockHandle');
	$sdfRef  or $fh = $self->{_lockHandle};
    }

  # print "DEBUG: unlocking fh='$fh' in '$PACK'\n";

    my($stat,$err) = (0,"");

    if ( ! ($fh and fileno($fh)) ) {
	($stat,$err) = (-1, "Can't unlock: not an open filehandle in '$PACK'");

    } elsif (! flock($fh, LOCK_UN) ) {
	($stat,$err) =  (-1, "Can't unlock filehandle in '$PACK': $!");

    } elsif ( $sdfRef ) {
	# When unlock successful and called by an object of PTools::SDF:: 
	# class remove the cached filehandle

	$sdfRef->ctrlDelete('ext_lockHandle');
    }
    delete $self->{_lockHandle};

    # If we opened it above, close it here ... 'cause we're sooo tidy.
    #
    close( $fh ) if $fh and defined $self->{closeFlag};

    $self->setErr($stat,$err);
    $sdfRef->setErr($stat,$err) if $sdfRef;    # keep errors in synch here

    return unless wantarray;
    return( $stat, $err );
}
#_________________________
1; # Required by require()

__END__

=head1 NAME

SDF::Lock::Advisory - Lock/Unlock a file or filehandle using ADVISORY locking

=head1 VERSION

This document describes version 0.07, released Feb 15, 2003.

=head1 SYNOPSIS

=head2 Obtain lock on a filename or filepath

     use PTools::SDF::Lock::Advisory;

     $lockObj = new PTools::SDF::Lock::Advisory;

     ($stat,$err) = $lockObj->lock( $fileName );

 or  $lockObj->lock( $fileName, $maxRetries, $sleepTime, $lockMode, $openMode );

     ($stat,$err) = $lockObj->status;

     ($stat,$err) = $lockObj->unlock;

The '$lockMode' parameter is valid for the PTools::SDF::Lock::Selective class
but is not currently used in this parent class, and is ignored here.

The '$fileName' need not exist prior to calling the 'lock' method, but
it will exist if the lock succeeds.

Default for the '$openMode' variable is 0644, or '-rw-r--r--')

Explicit unlock is unnecessary. Simply allow the '$lockObj' variable to
fall out of scope (or exit the script, undefine, etc.) to release the lock.


=head2 Obtain lock on an open filehandle

     use Fcntl;
     use PTools::SDF::Lock::Advisory;

     $lockObj = new PTools::SDF::Lock::Advisory;

     local(*FH);
     sysopen(FH, "/some/file", O_RDWR|O_CREAT, 0644) || die $!;
     $fh = *FH;

     ($stat,$err) = $lockObj->lock( $fh );
 or  ($stat,$err) = $lockObj->lock( $fh, $maxRetries, $sleepTime );

The 'status' and 'unlock' methods are the same as above,
and an '$openMode' parameter is obviously not needed here.


=head2 Obtain lock on an instance of an 'SDF::<module>' class

     use PTools::SDF::INI;        # or PTools::SDF::SDF,  or PTools::SDF::TAG 

     $iniObj = new PTools::SDF::INI( $fileName );

     ($stat,$err) = $iniObj->lock( $maxRetries, $sleepTime );

The 'status' and 'unlock' methods are the same as above,


=head2 Invoke lock method from within an 'SDF::<module>' class

The B<lock> and B<unlock> methods are implemented as I<extendible>
methods in an abstract base class. See L<PTools::SDF::File> or L<Extender>
for discussion and examples of this mechanism.


=head1 DESCRIPTION

The discussion and syntax here is intended for:

1) anyone who would like to use this class as a 'standalone' mechanism
to obtain a lock on an arbitrary I<filedescriptor> or open I<filehandle>

2) PTools::SDF::<module> designers who would like to incorporate a locking
mechanism within their modules (whether I<extendible> or not)

B<Note>: For I<end users> of the PTools::SDF::<module> classes 
(e.g., PTools::SDF::INI, SDF::SDF and PTools::SDF::TAG), refer to the 
documentation accompanying these classes for a discussion of the B<lock> 
and B<unlock> methods.

The explanations, below, are intended to be complete enough for the
module designers without being too confusing for users wishing to use
this as a 'standalone' lock/unlock mechanism.

B<WARNING>: This module implements simple B<advisory locking> only. Any
module that chooses not to check for and honor the existance of an advisory
lock has full access to modify and/or delete the 'locked' data file.


=head2 Constructor

=over 4

=item new

Explicit use of the constructor is not necessary. 

When using with a filename or filehandle, as shown in the Synopsis sections,
above, the B<lock> method will return the newly instantiated lock object.

When called from within a PTools::SDF::<module> class, this module is 
expected to be implemented as a I<extendible> method. See the abstract 
base class B<PTools::SDF::File> for further details.

=back


=head2 Public Methods

=over 4

=item lock ( FileParam [, MaxRetries [, SleepTime ]] [, LockMode ] [, OpenMode ] )

=item lock ( SDFReference [, MaxRetries [, SleepTime ]] [, LockMode ] [, OpenMode ] )

Use the first format when this class is used 'standalone' to lock a
I<filepath> or I<filehandle>.

Use the second format of the B<lock> method from within the various 
SDF::<module> classes to lock the file associated with that object.

(For information on how to obtain a lock on an instantiated PTools::SDF::<module>
object, see the documentation accompanying that class.)

=over 4

=item FileParam

=item SDFReference

The first parameter to this method must be either:

1) one of a filename, a filepath or a filehandle to an open file

2) a reference to an PTools::SDF::<module>


=item MaxRetries

An integer indicating the number of times that this class should
attempt to obtain an advisory lock.

=item SleepTime

An integer indicating the number of seconds this class should 'sleep'
between retries. The default B<SleepTime>, when a B<MaxRetries>
parameter is specified, is 1 second.

=item LockMode

The '$lockMode' parameter is valid for the PTools::SDF::Lock::Selective class
but is not currently used in this parent class, and is ignored here.

=item OpenMode

An octal number that will be used for the 'open mode' of a B<FileParam>
of either I<filename> or I<filepath>. Obviously this is not used when the
B<FileParam> parameter passed is a currently open I<filehandle>.

=back

Examples of locking a filename or filehandle:

 ($stat,$err) = $lockObj->lock( "myFile" );

 ($stat,$err) = $lockObj->lock( "/some/path/to/myFile" );

 ($stat,$err) = $lockObj->lock( $fh );

See the Synopsis examples, above, for a full example of obtaining
and passing an open filehandle.

An Example of invoking a lock from within an PTools::SDF::<module> class can
be found in the abstract base class B<PTools::SDF::File>.


=item unlock ( [ FH ] )

=item unlock ( SDFReference [, FH ]] )

Use the first format when using this class 'standalone' to unlock an
open I<filehandle>.

The second format of the B<unlock> method is used by the various PTools::SDF::<module>
classes to unlock the file associated with that object. 

In either case the B<FH> parameter is optional. The filehandle used to release
the advisory lock is expected to be maintained within the various objects 
involved. Module designers should make a note of this.

=over 4

=item FH

The same I<filehandle> used to obtain the advisory lock in the B<lock>
method.

=item SDFReference

The same parameter used to obtain the advisory lock in the B<lock>
method.


=back

Examples:

 ($stat,$err) = $lockObj->unlock;

 ($stat,$err) = $lockObj->unlock( $fileHandle );


=item status 

=item stat

=item err

Obtain the status and, when non-zero, the accompanying error message.

 ($stat,$err) = $lockObj->status;

 $stat  = $lockObj->stat;           # scalar context returns status number
 ($err) = $lockObj->stat;           # array context returns error message

 ($err) = $lockObj->err;

Module designers should note that the PTools::SDF::<module> objects should
make any error status and message available from within the calling
objects, too.


=item isLocked

=item notLocked

 $boolean = $lockObj->isLocked;

 $boolean = $lockObj->notLocked;

=back

=head2 Private Methods

=over 4

=item setErr ( [ Status ] [, Error ] )

Used to set an internal error state when problems are detected
during method calls.

 $self->setErr( 0, "" );               # initialize to "no error" state

 $self->setErr( -1, "Error text" );    # set to an "error" state


=item _createFileHandle ( FileParam [, Mode ] )

Ensure the B<FileParam> passed to the B<lock> method is a I<FileHandle>.
If not, create one based on the B<FileParam>.


=item _lockFileHandle ( FH [, Retry [, Sleep ]] )

Attempt to obtain an advisory lock on a I<FileHandle>.


=back

=head1 INHERITANCE

None currently.

=head1 SEE ALSO

See
L<PTools::SDF::Overview>, 
L<PTools::SDF::ARRAY>, L<PTools::SDF::CSV>,  L<PTools::SDF::DB>,
L<PTools::SDF::DIR>,   L<PTools::SDF::DSET>, L<PTools::SDF::File>, 
L<PTools::SDF::IDX>,   L<PTools::SDF::INI>,  L<PTools::SDF::SDF>,
L<PTools::SDF::TAG>,   L<PTools::SDF::Lock::Selective>,
L<PTools::SDF::Sort::Bubble>, L<PTools::SDF::Sort::Quick> and 
L<PTools::SDF::Sort::Shell>.

=head1 AUTHOR

Chris Cobb, E<lt>nospamplease@ccobb.netE<gt>

=head1 COPYRIGHT

Copyright (c) 1997-2007 by Chris Cobb. All rights reserved. 
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
