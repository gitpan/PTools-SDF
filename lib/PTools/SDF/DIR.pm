# -*- Perl -*-
#
# File:  PTools/SDF/DIR.pm
# Desc:  Load directory entries into an 'PTools::SDF::SDF' style object        
# Date:  Thu Oct 14 10:30:00 1999
# Mods:  Mon Nov 27 12:30:00 2000
# Stat:  Prototype
#
package PTools::SDF::DIR;
require 5.001;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA $DOSTAT);
 $VERSION = '0.11';
 @ISA     = qw( PTools::SDF::SDF );
 $DOSTAT  = '0';                # Delay loading 'stat' and 'type' info 

 use PTools::SDF::SDF 0.04;


sub save {
   $_[0]->setError(-1,
      "Unable to write Unix directories in 'save' method in '$PACK'");

   return($_[0]->ctrl('status'),$_[0]->ctrl('error')) if wantarray;
   return $_[0]->ctrl('status'); 
}


sub loadFile {
  my($self,$dirName) = @_;

  $self->ctrl('fileName',  $dirName);
  $self->ctrl('dataFields',"file:ext:filename:stat:type");
  $self->ctrl('ctrlFields',
     "status:error:fileName:readOnly:ctrlFields:dataFields:ifs:parseifs");

  my $i=0;
  local *DIR;
  if (opendir(DIR,"$dirName")) {

     my($filePath,$file,$ext) = "";
     no strict "refs";

     foreach(readdir(DIR)) {
        next if /\.\.?$/;           # skip "." and ".."
        chomp;
        $filePath = "$dirName/$_";
	($file,$ext) = $_ =~ /([^\.]*)\.?(\w*)$/;

        $self->param($i,'filename', "$_");
        $self->param($i,'file',     $file);
        $self->param($i,'ext',      $ext);

	$self->statFile($i) if ${"$PACK"."::DOSTAT"};
        $i++;
     }
     closedir(DIR);

  } else {
     my($err) = sprintf("%s: $dirName in 'DIR_loadFileDIR'",$!);
     my($stat)= sprintf("%d",$!);          # error number
     $self->setError($stat,$err);          # set error number and message
     return;
  }
  $self->isEmpty    and $self->setError(-1,"Empty directory in '$PACK'");
  $self->isSortable and $self->sort(undef,"filename");

  return;
}

sub import {
  my($class,@args) = @_;
  no strict "refs";
  $args[0] and $args[0] =~ /stat/i ? ${"$PACK"."::DOSTAT"}= '1' : '0';
}

   *ext = \&extension;

sub extension  { $_[0]->param($_[1],'ext'); }

#
# Return status array elements. In the following example
# each of the three 'fileSize' variables are equivalent.
#
#   $dirRef = new PTools::SDF::DIR("/tmp");
#   foreach $recIdx (0 .. $dirRef->param) {
#     @statArray = $dirRef->stat_array($recIdx);
#     $fileSizeA = $dirRef->statFile  ($recIdx, 7);
#     $fileSizeB = $dirRef->stat_size ($recIdx);
#     $fileSizeC = $statArray[7];
#   }
#
sub statFile {
  my($self,$recIdx,$statIdx) = @_;

  return undef if (! defined $recIdx);
  return undef if (! length($recIdx));
  return undef if int($recIdx) > $self->param();
  return undef if int($recIdx) < 0;

  my $statRef = $self->param($recIdx,'stat') || "";
  return undef if ( ($statRef) and (! ref $statRef) );  # Logic error here?

  my @stat = ();
  (@stat)  = @{ $statRef } if $statRef;

  if (! @stat) {
     #
     # If stat and type weren't collected during load, then do so 
     # when 'stat' or 'type' are invoked for a directory entry.
     #
     my $dirName = $self->ctrl('fileName');
     my $fileName= $self->param($recIdx,'filename');
     my $filePath= "$dirName/$fileName";
     my $fileType;

     (@stat) = CORE::stat("$filePath");

     if    (-f _) { $fileType = "file";    }
     elsif (-d _) { $fileType = "dir";     }
     elsif (-l _) { $fileType = "symlink"; }
     elsif (-S _) { $fileType = "socket";  }
     elsif (-p _) { $fileType = "pipe";    }
     else         { $fileType = "other";   }

     $self->param($recIdx,'stat',\@stat);
     $self->param($recIdx,'type',$fileType);
  }
  return @stat    if (! $statIdx) and wantarray;
  return $stat[0] if (! $statIdx);
  $statIdx = int($statIdx) || return undef;
  return undef    if ($statIdx < 0) or ($statIdx > 12);
  return $stat[$statIdx];
}

sub stat_array { $_[0]->statFile($_[1]);    }
sub stat_dev   { $_[0]->statFile($_[1],0);  }
sub stat_ino   { $_[0]->statFile($_[1],1);  }
sub stat_mode  { $_[0]->statFile($_[1],2);  }
sub stat_nlink { $_[0]->statFile($_[1],3);  }
sub stat_uid   { $_[0]->statFile($_[1],4);  }
sub stat_gid   { $_[0]->statFile($_[1],5);  }
sub stat_rdev  { $_[0]->statFile($_[1],6);  }
sub stat_size  { $_[0]->statFile($_[1],7);  }
sub stat_atime { $_[0]->statFile($_[1],8);  }
sub stat_mtime { $_[0]->statFile($_[1],9);  }
sub stat_ctime { $_[0]->statFile($_[1],10); }
sub stat_bsize { $_[0]->statFile($_[1],11); }
sub stat_block { $_[0]->statFile($_[1],12); }

*stat_owner = \&stat_uid;
*stat_group = \&stat_gid;

#
# Return file type.
#
sub type { 
   my($self,$recIdx) = @_;

   my($type) = $self->param($recIdx,'type');
   if (! $type) {
     $self->statFile($recIdx);
     $type = $self->param($recIdx,'type');
   }

 # print "IDX='$recIdx'  TYPE='$type'\n";
 # die $self->dump($recIdx,1);

   return $type;
}
sub type_file    { $_[0]->type($_[1]) eq "file";    }
sub type_dir     { $_[0]->type($_[1]) eq "dir";     }
sub type_symlink { $_[0]->type($_[1]) eq "symlink"; }
sub type_socket  { $_[0]->type($_[1]) eq "socket";  }
sub type_pipe    { $_[0]->type($_[1]) eq "pipe";    }
sub type_undef   { $_[0]->type($_[1]) eq "other";   }

*isaFile = \&type_file;
*isaDir  = \&type_dir;
*isaSymlink = \&type_symlink;
*isaSocket  = \&type_socket;
*isaPipe    = \&type_pipe;
*isUnknown  = \&type_undef;
#_________________________
1; # Required by require()

__END__

=head1 NAME

PTools::SDF::DIR - Load dir entries into an 'PTools::SDF::SDF' object        

=head1 VERSION

This document describes version 0.11, released February, 2006.

=head1 DEPENDENCIES

This class depends directly on the B<PTools::SDF::SDF> class.

=head1 SYNOPSIS

Load the contentes of a subdirectory into an object of this class.

     use PTools::SDF::DIR;

 or  use PTools::SDF::DIR ("stat");

     $dirObj = new PTools::SDF::DIR( "/subdir/path" );

Obtain information about the subdirectory's entries.

     $dirname = $dirObj->ctrl('fileName');

     print " Contents of $dirname:\n";

     foreach my $idx ( 0 .. $dirObj->param() ) {

	 $filename = $dirObj->param( $idx, 'filename' );
	 $fileBase = $dirObj->param( $idx, 'file'     );
	 $fileExt  = $dirObj->param( $idx, 'ext'      );

	 if ( $dirObj->isaFile( $idx ) ) {

             $size  = $dirObj->stat_size( $idx );
             $atime = $dirObj->stat_atime( $idx );

	     print "  $filename is a FILE, size=$size, atime=$atime\n";

	 } elsif ( $dirObj->isaDir( $idx ) ) {

             $uid   = $dirObj->stat_uid( $idx );
             $mode  = $dirObj->stat_mode( $idx );

	     print "  $filename is a DIR, uid=$uid, mode=$mode\n";

	 } else {

             $type  = $dirObj->type( $idx );
             $dev   = $dirObj->stat_dev( $idx );

	     print "  $filename type is $type, on dev=$dev\n";
	 }
     }


=head1 DESCRIPTION

=head2 Constructor

=over 4

=item new

This class relies on a constructor in the parent class. See 
L<PTools::SDF::SDF> for details.

However, this class is influenced by the B<use> directive. If
a "B<stat>" parameter is added, a I<stat(2)> is performed on 
I<each entry> in a directory as it is loaded into an object
of this class.

The default is to skip the 'stat' calls while loading the directory
entries. This is for performance reasons. In this case, a 'stat' is
not called on a particular entry until a method is invoked that
needs to return some or all of the stat data for that entry.

In either case, only one 'stat' call is made per entry during the
life of a given object of this class.

Examples:

Delay "stat" calls on dir entries until they are actually needed.

 use PTools::SDF::DIR;

 $dirObj = new PTools::SDF::DIR( "/subdir/path" );


Alternatively, call "stat" on every dir entry during object creation.

 use PTools::SDF::DIR ("stat");

 $dirObj = new PTools::SDF::DIR( "/subdir/path" );

=back


=head2 General Methods

This class inherits from the B<PTools::SDF::SDF> class which, in turn,
inherits from the B<PTools::SDF::File> class. Many other methods exist
in these classes for accessing, sorting, locking and manipulating
the contents of objects of this class.

In addition, several methods exist in this class to facilitate
obtaining information about entries in a given subdirectory.

=over 4

=item ext

=item extension ( RecIdx )

The B<extension> method returns the I<extension> name, if any,
of the directory entry specified by the given B<RecIdx>.


=item save 

The B<save> method in the B<PTools::SDF::SDF> class is overridden here.
This class provides read-only access to subdirectories.

=back


=head2 Type Methods

The following methods provide access to file type information
for any directory entries contained in the current object.

=over 4

=item type ( RecIdx )

Return a string identifying the I<type> of the directory 
at the B<RecIdx> location in the current object.

The I<type> returned will be one of the following.

 file    - vanilla file
 dir     - directory
 symlink - symbolic link
 socket  - socket
 pipe    - named pipe
 other   - other / unknown


=item type_file    ( RecIdx )

=item type_dir     ( RecIdx )

=item type_symlink ( RecIdx )

=item type_socket  ( RecIdx )

=item type_pipe    ( RecIdx )

=item type_undef   ( RecIdx )

=item isaFile      ( RecIdx )

=item isaDir       ( RecIdx )

=item isaSymlink   ( RecIdx )

=item isaSocket    ( RecIdx )

=item isaPipe      ( RecIdx )

=item isUnknown    ( RecIdx )

Returns a boolean indicating the particular type value for a 
given subdirectory entry.

Example:

 $filename = $dirObj->param( $idx, 'filename' );

 if ( $dirObj->isaFile( $idx ) ) {
     print "  $filename is a FILE\n";

 } elsif ( $dirObj->isaDir( $idx ) ) {
     print "  $filename is a DIR\n";

 } else {
     $type  = $dirObj->type( $idx );
     print "  $filename is a $type\n";
 }

=back


=head2 Stat Methods

The following methods provide access to status information
for any directory entries contained in the current object.

For performance reasons, no 'stat' is performed on a given directory
entry until a method is invoked that accesses stat data for that
particular entry. Once obtained, the 'stat' data is cached so there
is no further performance penalty for requesting additional 'stat'
data for that particular directory entry.

To stat every directory entry while the entries are loaded during
object creation, see the B<Constructor> section, above.


=over 4

=item statFile ( RecIdx, StatIdx )

Return status array elements. In the following example each of the
three 'fileSize' variables are equivalent.

The B<RecIdx> is the record index into the current object of directory
entries and B<StatIdx> is the offset into the 'stat(2)' array.

Example:

 # In this example each of the three 'fileSize' variables are equivalent.

 $dirRef = new PTools::SDF::DIR("/tmp");

 $statIdx = 7;

 foreach $recIdx ( 0 .. $dirRef->param() ) {

      (@statArray)= $dirRef->stat_array( $recIdx );

      $fileSizeA  = $dirRef->statFile( $recIdx, $statIdx );

      $fileSizeB  = $dirRef->stat_size( $recIdx );

      $fileSizeC  = $statArray[ $statIdx ];
 }

=item stat_array ( RecIdx )

=item stat_dev   ( RecIdx )

=item stat_ino   ( RecIdx )

=item stat_mode  ( RecIdx )

=item stat_nlink ( RecIdx )

=item stat_uid   ( RecIdx )

=item stat_gid   ( RecIdx )

=item stat_rdev  ( RecIdx )

=item stat_size  ( RecIdx )

=item stat_atime ( RecIdx )

=item stat_mtime ( RecIdx )

=item stat_ctime ( RecIdx )

=item stat_bsize ( RecIdx )

=item stat_block ( RecIdx )

Return the particular stat value for a given subdirectory entry.
The B<stat_array()> method returns the entire status list for 
the given entry.

Examples:

 (@statArray)= $dirRef->stat_array( $recIdx );

 $fileSize   = $dirRef->stat_size( $recIdx );

 $fileInode  = $dirRef->stat_ino( $recIdx );

=back


=head1 INHERITANCE

This B<PTools::SDF::DIR> class inherits from the B<PTools::SDF::SDF> and B<PTools::SDF::File>
classes. Additional methods are available via these parent classes.

=head1 SEE ALSO

See
L<PTools::SDF::Overview>,
L<PTools::SDF::ARRAY>, L<PTools::SDF::CSV>,  L<PTools::SDF::DB>,
L<PTools::SDF::DSET>,  L<PTools::SDF::File>, L<PTools::SDF::IDX>,
L<PTools::SDF::INI>,    L<PTools::SDF::SDF>, L<PTools::SDF::TAG>, 
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
