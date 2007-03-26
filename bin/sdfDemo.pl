#!/opt/perl/bin/perl
#
# File:  sdfDemo.pl
# Desc:  Run a long list of tasks with limited concurrency (N-Ways)
#
use Cwd;
BEGIN {   # Script is relocatable. See "www.ccobb.net/ptools/"
  my $cwd = $1 if ( $0 =~ m#^(.*/)?.*# );  chdir( "$cwd/.." );
  my($top,$app)=($1,$2) if ( getcwd() =~ m#^(.*)(?=/)/?(.*)#);
  $ENV{'PTOOLS_TOPDIR'} = $top;  $ENV{'PTOOLS_APPDIR'} = $app;
} #-----------------------------------------------------------
use strict;
use warnings;

use PTools::Local;          # PTools local/global vars/methods
use PTools::SDF::SDF;
use PTools::SDF::INI;
use PTools::SDF::TAG;

my($input, $ini,$tag,$sdf);

if (1) {
    $input = PTools::Local->path('app_bindir', 'demo01.sdf');
    $sdf   = new PTools::SDF::SDF( $input );

    $sdf->lock();                # lock it
  # print $sdf->dump();          # dump it out (pre-sort)
    $sdf->sort(undef, 'name');   # sort it
    print $sdf->dump();          # dump it out (post-sort)
    $sdf->unlock();              # unlock it
}
#-----------------------------------------------------------------------

if (0) {
    $input = PTools::Local->path('app_bindir', 'demo02.ini');
    $ini   = new PTools::SDF::INI( $input );

    print $ini->dump();
}
#-----------------------------------------------------------------------

if (1) {
    $input = PTools::Local->path('app_bindir', 'demo03.tag');
    $tag   = new PTools::SDF::TAG( $input );

    print $tag->dump();
}

if ($sdf and $tag) {

    my $addNext = $sdf->count();
    $sdf->param( $addNext, $tag->tag2sdf('name','phone','occupation') );

    print $sdf->dump();          # dump it out, with new addition
}
#-----------------------------------------------------------------------
#die PTools::Local->dump('inclibs');   # locations of 'used' modules

__END__


#-----------------------------------------------------------------------
Where the demo input data files look like this:

#-----------------------------------------------------------------------
demo01.sdf
----------
#FieldNames name:phone:occupation
Mickey Mouse:+1 234 873-0124:'Toon
Mickey Mantle:+1 800 123-4664:Ball player
Donald Duck:+1 234 873-1023:'Toon

#-----------------------------------------------------------------------
demo02.ini
----------
[ Section One ]
 abc = xyz
 def = fed
 xyzzy = magick word
 plugh = funny sound

[ Section Two ]
 This = That
 Up   = Down
 Foo  = Bar

#-----------------------------------------------------------------------
demp03.tag
----------
[name]
Christiaan Barnard
[phone]
+27 21 422 4221
[occupation]
Heart surgeon
[quote]
If the poor overweight jogger only knew how far he had to run to work 
off the calories in a crust of bread, he might find it better in terms 
of pound per mile to go to a massage parlor.

#-----------------------------------------------------------------------
