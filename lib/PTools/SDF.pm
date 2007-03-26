# -*- Perl -*-
#
# File:  PTools/SDF.pm
# Date:  Sun Mar 18 14:47:11 2007
# Desc:  Simple module to 'use' multiple PTools utility modules
#
package PTools::SDF;
use 5.006001;
use strict;
use warnings;
use Carp qw( croak );

our $PACK = "__PACKAGE__";
our $VERSION = '0.01';
our @ISA = qw();

sub import
{   my($class, @modules) = @_;

    my $package = $PACK;
    my @failed;

    foreach my $module (@modules) {
	my $code = "package $package; use PTools::SDF::$module;";
	# warn $code;
	eval($code);
	if ($@) {
	    warn $@;
	    push(@failed, $module);
	}
    }
    @failed and 
	croak "could not import qw(" . join(' ', @failed) . ") in '$PACK'";
    return;
}
#_________________________
1; # Required by require()

__END__

=head1 NAME

PTools::SDF - A collection of Simple Data File utility tools

=head1 SYNOPSIS

 use PTools::SDF qw( INI  Lock::Advisory );

=head1 DESCRIPTION

PTools-SDF is a collection of tools for manipulating Simple Data Files.
These tools have evolved over the years to simplify the normal, everyday
types of tasks that most scripts, at some point, need to address.

PTools-SDF includes 

PTools-SDF includes a class that 

PTools-SDF also includes such things as 


B<Note>: This module is just used to simplify loading other PTools modules.
This class is not very useful on its own, and is not even necessary, as 
the other PTools-SDF classes load quite nicely all by themselves.

=head1 SEE ALSO

For details of the various PTools-SDF modules, refer to the man
page for that module.

 PTools::SDF::SDF         -  handle all the counters in an application

=head1 AUTHOR

Chris Cobb, E<lt>NoSpamPlease@ccobb.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 1997-2007 by Chris Cobb
This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
