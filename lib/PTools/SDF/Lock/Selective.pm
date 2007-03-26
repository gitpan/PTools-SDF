# -*- Perl -*-
#
# File:  PTools/SDF/Lock/Selective.pm
# Desc:  Lock/Unlock an open filehandle using SELECTIVE locking
# Date:  Mon Apr 02 14:30:00 PDT 2001
#
# ToDo:  Clean up documentation (it's left over after copying from "Advisory")
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
#        use PTools::SDF::Lock::Selective;
#
#        $lockObj = new PTools::SDF::Lock::Selective;
#
#        ($stat,$err) = $lockObj->lock( $fileName );
#
#  or    $lockObj->lock( $fileName, $maxRetries, $sleepTime, $openMode );
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
#        use PTools::SDF::Lock::Selective;
#
#        $lockObj = new PTools::SDF::Lock::Selective;
#
#        local(*FH);
#        sysopen(FH, "/some/file", O_RDWR|O_CREAT, 0644) || die $!;
#        $fh = *FH;
#
#        ($stat,$err) = $lockObj->lock( $fh );
#  or    ($stat,$err) = $lockObj->lock( $fh, $maxRetries, $sleepTime );
#
#        # The "status" and "unlock" methods are the same as above,
#        # and an "$openMode" parameter is obviously not needed here.
#
#
# Synopsis:  ALTERNATE -- lock an instance of an "PTools::SDF::<module>" class
#            Note that the "$fileName" need not exist prior to calling
#            the "lock" method, but it will exist if the lock succeeds.
#
#        use PTools::SDF::INI;    # or PTools::SDF::SDF,  or PTools::SDF::TAG 
#
#        $iniObj = new PTools::SDF::INI( $fileName );
#
#        ($stat,$err) = $iniObj->lock( $maxRetries, $sleepTime );
#
#        # The "status" and "unlock" methods are the same as above.
#
#
# This module is designed for use as one of several possible "extended"
# lock methods within the PTools::SDF::<module> set of classes. See 
# the PTools::SDF::File class for discussion and examples.
#
# WARN:  When this class is invoked by the 'extend' method in class
#        PTools::SDF::File, the invoking SDF object is passed as the 
#        first param.
#
#        However, to make this module more generally useful, the first 
#        param may also be a filename/path or an open filehandle GLOB. 
#        To accomodate this, shift off the first variable if it happens to 
#        be an PTools::SDF::File object or any subclass thereof. Also note 
#        that return values from the "lock" method vary based on the caller.
#
# Unless you are using this module while designing PTools::SDF::<module> 
# classes, use the syntax shown in the examples, above.
#

package PTools::SDF::Lock::Selective;
 require 5.001;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw($VERSION @ISA);
 $VERSION = '0.05';
 @ISA     = qw( PTools::SDF::Lock::Advisory );

 use Fcntl;
 use PTools::SDF::Lock::Advisory;

sub _lockFileHandle
{   my($self,$fh,$retry,$sleep,$lockMode) = @_;

    ( $fh and fileno($fh) ) or
	return (-1, "Can't lock: not an open filehandle in '$PACK'");

    # FIX: ensure correct value for F_SETLK value ... Per Ray:
    # "I do believe the is a defect in the shipping perl. The value returned 
    #  from use Fcntl for F_SETLK is not compatable with the perl fcntl 
    #  function. On a 64 bit system the value returned is "9" which is the
    #  64 bit value for F_SETLK. The only value which does not cause the fcntl
    #  function to get an error is "6", the 32 bit value for F_SETLK."
    
    my( $F_SETLK, $F_WRLCK, $F_RDLCK, $F_UNLCK );

    # $F_SETLK=F_SETLK();
    $F_SETLK=6;                  # Hack, yuck.

#   my $f_wrlck=F_WRLCK();
#   my $f_rdlck=F_RDLCK();
#   my $f_unlck=F_UNLCK();
#   $F_WRLCK=pack("ssiii",$f_wrlck,0,0,0,0);
#   $F_RDLCK=pack("ssiii",$f_rdlck,0,0,0,0);
#   $F_UNLCK=pack("ssiii",$f_unlck,0,0,0,0);

    my($F_LockMode, $stat, $err);

  # $lockMode ||= "read";     # request "reader" lock by default.
    $lockMode ||= "write";    # request "exclusive" lock by default.

    if ($lockMode =~ /(write|Write|WRITE)/) {
	my $f_wrlck = F_WRLCK();
	$F_LockMode = pack("ssiii",$f_wrlck,0,0,0,0);

    } elsif ($lockMode =~ /(read|Read|READ)/) {
	my $f_rdlck = F_RDLCK();
	$F_LockMode = pack("ssiii",$f_rdlck,0,0,0,0);

    } else {
	return (-1, "Invalid lock mode '$lockMode' in '$PACK': Expecting read or write");
    }

    $retry = ( defined $retry ? int($retry) || 0 : 0 );
    $sleep = ( defined $sleep ? int($sleep) || 1 : 1 );
    $sleep = 0 unless $retry;                    # by default, skip retries

    my $count = 0;

    while (! fcntl($fh,$F_SETLK,$F_LockMode) ) {
 	sleep $sleep if $sleep;
 	if ($count++ > $retry) {
	    ($stat,$err) = ( scalar($!), $! );
 	    return ($stat, "Unable to lock filehandle in '$PACK': $!");
 	}
    }
    $stat ||= 0;  $err ||= "";
    print STDERR "RESULTS: fcntl returned, errno=$stat, errmsg='$err'\n";

    $self->{_lockHandle} = $fh;

    return (0,"");
}
#_________________________
1; # Required by require()

__END__

=head1 NAME

SDF::Lock::Selective - Lock/Unlock a file or filehandle using 'selective' locking

=head1 VERSION

This document describes version 0.01, released Feb 05, 2003.

=head1 SYNOPSIS

=head2 Obtain lock on a filename or filepath

     use PTools::SDF::Lock::Selective;

     $lockObj = new PTools::SDF::Lock::Selective;

     ($stat,$err) = $lockObj->lock( $fileName );

 or  $lockObj->lock( $fileName, $maxRetries, $sleepTime, $lockMode, $openMode );

     ($stat,$err) = $lockObj->status;

     ($stat,$err) = $lockObj->unlock;

The '$fileName' need not exist prior to calling the 'lock' method, but
it will exist if the lock succeeds.

Default for the '$openMode' variable is 0644, or '-rw-r--r--')

Explicit unlock is unnecessary. Simply allow the '$lockObj' variable to
fall out of scope (or exit the script, undefine, etc.) to release the lock.


=head2 Obtain lock on an open filehandle

     use Fcntl;
     use PTools::SDF::Lock::Selective;

     $lockObj = new PTools::SDF::Lock::Selective;

     local(*FH);
     sysopen(FH, "/some/file", O_RDWR|O_CREAT, 0644) || die $!;
     $fh = *FH;

     ($stat,$err) = $lockObj->lock( $fh );
 or  ($stat,$err) = $lockObj->lock( $fh, $maxRetries, $sleepTime, $lockMode );

The 'status' and 'unlock' methods are the same as above,
and an '$openMode' parameter is obviously not needed here.


=head2 Obtain lock on an instance of an 'SDF::<module>' class

     use PTools::SDF::INI;        # or PTools::SDF::SDF,  or PTools::SDF::TAG 

     $iniObj = new PTools::SDF::INI( $fileName );

     $iniObj->extend( [ "lock","unlock" ], "PTools::SDF::Lock::Selective");

     ($stat,$err) = $iniObj->lock( $maxRetries, $sleepTime, $lockMode );

The 'status' and 'unlock' methods are the same as above. 

B<Note> that the braces (B<[>, B<]>) used in the above example show
the litersl syntax used to pass an array reference into a subroutine.
They are not used here to imply optional parameters. Optionally, use:

     $arrayRef = [ "lock", "unlock" ];

     $iniObj->extend( $arrayRef, "PTools::SDF::Lock::Selective");


=head2 Invoke lock method from within an 'SDF::<module>' class

The B<lock> and B<unlock> methods are implemented as I<extendible>
methods in an abstract base class. See L<PTools::SDF::File> or 
L<EPTools::xtender> for discussion and examples of this mechanism.


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

FIX: is the following still true?

 B<WARNING>: This module implements simple B<selective locking> only. Any
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

(For information on how to obtain a lock on an instantiated 
PTools::SDF::<module> object, see the documentation accompanying 
that class.)

=over 4

=item FileParam

=item SDFReference

The first parameter to this method must be either:

1) one of a filename, a filepath or a filehandle to an open file

2) a reference to an PTools::SDF::<module>


=item MaxRetries

An integer indicating the number of times that this class should
attempt to obtain the lock.

=item SleepTime

An integer indicating the number of seconds this class should 'sleep'
between retries. The default B<SleepTime>, when a B<MaxRetries>
parameter is specified, is 1 second.

=item LockMode

Files can be locked using a B<LockMode> of either 'B<read>' or 'B<write>'.

A 'B<read>' lock allows multiple 'I<read>' locks but no 'I<write>' locks.
Only one 'B<write>' lock may be held at a time, and this disallows any
concurrent 'I<read>' locks.

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

The second format of the B<unlock> method is used by the various 
PTools::SDF::<module> classes to unlock the file associated with 
that object. 

In either case the B<FH> parameter is optional. The filehandle used 
to release the lock is expected to be maintained within the various 
objects involved. Module designers should make a note of this.

=over 4

=item FH

The same I<filehandle> used to obtain the lock in the B<lock>
method.

=item SDFReference

The same parameter used to obtain the lock in the B<lock>
method.


=back

Examples:

 ($stat,$err) = $lockObj->unlock;

 ($stat,$err) = $lockObj->unlock( $fileHandle );


=item status 

Obtain the status and, when non-zero, the accompanying error message.

 ($stat,$err) = $lockObj->status;

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

Attempt to obtain a read or write lock on a I<FileHandle>.


=back

=head1 INHERITANCE

This class inherits directly from the B<PTools::SDF::Lock::Advisory> class.

=head1 SEE ALSO

See
L<PTools::SDF::Overview>,
L<PTools::SDF::ARRAY>, L<PTools::SDF::CMD::BDF> L<PTools::SDF::CSV>,
L<PTools::SDF::DB>,    L<PTools::SDF::DIR>,     L<PTools::SDF::DSET>,
L<PTools::SDF::File>,  L<PTools::SDF::IDX>,     L<PTools::SDF::INI>, 
L<PTools::SDF::SDF>,  L<PTools::SDF::TAG>,
L<PTools::SDF::Lock::Advisory>,
L<PTools::SDF::Sort::Bubble>, L<PTools::SDF::Sort::Quick> and
L<PTools::SDF::Sort::Shell>.

Also see
L<PTools::SDF::File::AutoHome>, L<PTools::SDF::File::AutoView>,
L<PTools::SDF::File::Mnttab> and L<PTools::SDF::File::Passwd>.
These are contained in the 'PTools-File-Cmd' distribution
available on CPAN

=head1 AUTHOR

Chris Cobb, E<lt>nospamplease@ccobb.netE<gt>

=head1 COPYRIGHT

Copyright (c) 2003-2007 by Chris Cobb. All rights reserved.
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
