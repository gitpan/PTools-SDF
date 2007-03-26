# -*- Perl -*-
#
# File:  PTools/SDF/SDF.pm
# Desc:  Implements a Simple Data File in a "Self Defining File" format.
# Date:  Tue Feb 11 10:00:00 1997
# Note:  See "POD" at end of this module.
#
# "PTools-SDF" (the collection) has several modules for "Simple Data Files"
# while "PTools::SDF::SDF" (the class) implements a "Self Defining File."
#
# Performance Note: Parsing every field in each record to encode/decode
# the "IFS" character adds quite a bit of overhead here. To disable this 
# parsing, add the "noparse" option as shown in SYNOPSIS section, below.
# Only do this when you know it is safe to do so (i.e., when there is no
# possibility of an "IFS" character embedded within a field).
#
# ToDo:  . delayed load, after object instantiation
#        . append mode -- can now use "param" method to add entire rec 
#           at a time, but can't just specify a file to "append"
#

package PTools::SDF::SDF;
require 5.001;
use strict;

my $PACK = __PACKAGE__;
use vars qw( $VERSION @ISA );
$VERSION = '0.32';
@ISA     = qw( PTools::SDF::File );

use PTools::SDF::File;                    # Base class for the PTools::SDF::<Modules>

my $ParseIFS = '1';               # Defaults to "yes"

sub new
{   my($class,$fileName,$mode,$IFS,@fields) = @_;

    bless my $self = {}, ref($class)||$class;
    $self->{_Data_}= [];

    $self->ctrl('ctrlFields', "ctrlFields:ifs:parseifs:status:error");
    $self->ctrl('dataFields', @fields     );
    $self->ctrl('ifs',        $IFS || ":" );
    $self->ctrl('parseifs',   $ParseIFS   );

    $self->setError(0,"");

    $self->loadFile($fileName,$mode,@fields) if $fileName;

    return $self  unless wantarray;
    return($self,$self->ctrl('status'),$self->ctrl('error'));
}

sub setError { return( $_[0]->{status}=$_[1]||0, $_[0]->{error}=$_[2]||"" ) }
sub status   { return( $_[0]->{status}||0, $_[0]->{error}||"" )             }
sub stat     { ( wantarray ? ($_[0]->{error}||"") : ($_[0]->{status} ||0) ) }
sub err      { return($_[0]->{error}||"")                                   }

*getError = \&status;
*getErr   = \&status;
*setErr   = \&setError;

*statOnly = \&stat;
*errOnly  = \&err;

# isSortable/notSortable - ensures that there are at least TWO records to sort
# hasData / notEmpty     - "true" if current object DOES contain data records
# noData / isEmpty       - "true" if current object does NOT contain data recs
# count                  - convert zero-based array into 1-based "human" number
#                   (note that 'param' method w/out args returns 0-based count)
#

sub isSortable  { no strict "refs"; ( $#{$_[0]->{_Data_}} > 0 ? 1 : 0 ) }
sub hasData     { no strict "refs"; ( $#{$_[0]->{_Data_}} < 0 ? 0 : 1 ) }
sub notSortable { no strict "refs"; ( $#{$_[0]->{_Data_}} < 1 ? 1 : 0 ) }
sub noData      { no strict "refs"; ( $#{$_[0]->{_Data_}} < 0 ? 1 : 0 ) }
sub count       { no strict "refs"; ( $#{$_[0]->{_Data_}} + 1 ) }

*notEmpty = \&hasData;
*isEmpty  = \&noData;

*ctrl     = \&ctrlParam;
*param    = \&recParam;
*get      = \&recParam;
*set      = \&recParam;
*write    = \&save;

sub save
{   my($self,$who,$fileName,$heading,$force) = @_;

    $self->saveFile($who,$fileName,$heading,$force);

    return($self->ctrl('status'),$self->ctrl('error')) if wantarray;
    return; 
}

sub delete
{   my($self,$recNumber,$numRecs) = @_;

    ($recNumber > $self->param) and
	return $self->setError(-1,
	    "Rec number > than rec count in 'delete' method of '$PACK' class");

    # Splice returns the element(s) deleted from the array.
    # In this case, it will be one or more HASH ref(s).
    #
    $numRecs ||= 1;
    my(@deleteList) = splice( @{ $self->{_Data_} }, $recNumber, $numRecs);

    return(@deleteList);
}

#______________________________________________
# Extendible method: Easily add new sort modules.
# For example, create a "PTools/SDF/Sort/Custom.pm" module.
# Ensure the module has a "new" and a "sort" method.
# Then invoke on existing PTools::SDF::SDF objects.
#
#   use PTools::SDF::SDF;
#   $sdfRef = new PTools::SDF::SDF($filename);
#   $sdfRef->extend('sort', 'PTools::SDF::Sort::Custom');
#   $sdfRef->sort($mode, @sortKeys);
#
# This way, any client script that makes use of the
# PTools::SDF::SDF class can specify which sort module to
# use in any given circumstance. Also, when no
# sorting is used, unnecessary code is eliminated.
#
sub sort
{   my($self,@params) = @_;

    my $default = 'PTools::SDF::Sort::Bubble';
    my($ref,$stat,$err) = (undef,0,"");

    $ref = $self->extended("sort");                             # Use prior? or
    $ref or ($ref,$stat,$err) = $self->extend('sort',$default); # use default.

    $stat or ($stat,$err) = $self->expand('sort',@params);      # See File.pm

    $self->setError( $stat,$err );
    return($stat,$err) if wantarray;
    return $stat;
}

###############################################################################

sub import
{   my($class,@args) = @_;
    $args[0] and $ParseIFS = ( $args[0] =~ /noparse/i ? '0' : '1' );
}


sub loadFile
{   my($self,$fileName,$mode,@fields) = @_;            # Grab parameters

    $mode ||= "";
    my($match) = "";
    #__________________________________
    # Create some additional control elements; fill one
    # with the field names used in creating the associations.
    # Don't use an array here as dereferencing it would be
    # rather more painful than simply using a split().
    #
    $self->{'fileName'}  = $fileName;
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
	$dataFields = join(":",@fields);

    } else {
	$dataFields = "line";                      # assume line mode for now
	$mode = "line";                                # and force the $mode
	$self->{'readOnly'} = "unknown field names";   # disallow writes for now
    }
    $self->{'dataFields'}= $dataFields;
    #__________________________________
    # Now, if we can successfully open the file
    # we'll load each record into a hash array.
    # 
    local *IN;
    if (open(IN,"$fileName")) {
	my $fh = \*IN;

	$self->_loadFileSDF($dataFields,$mode,$fh);    # pass field names list 

	if ($self->{'status'}) {
	    $self->{'error'}.= " for file $fileName";  # add to any error msg
	}
	close(IN);

    } else {
	my $error = sprintf("%s: $fileName in 'SDF_loadFileSDF()'",$!);
	$self->{'status'}= sprintf("%d",$!);           # error number 
	$self->{'error'} = $error;                     # error message
    }
    return;
}

sub _loadFileSDF
{   my($self,$fields,$mode,$fh) = @_;

    # collect list of fields ... if any were passed in
    my(@fields) = split(":",$fields) unless $fields eq "line";

    my($IFS) = ( $self->ctrl('ifs') || ":" );
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
    while(<$fh>) {

	if (/^#FieldNames / && $i == 0) {     # It's a "self describing" file
	    # If any fieldnames were passed into this module,
	    # these will override the fieldnames in the file,
	    # and fieldnames in file override "line" mode.

	    next if @fields;
	    $mode = "";
	    #
	    ($fields) = /^#FieldNames (.*)$/;       
	    (@fields) = split(":",$fields);        

	    $self->{'dataFields'} = $fields;         
	    $self->{'readOnly'}   = "";       # allow writes ... for now

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

	} elsif (/^(\s*)#|^(\s*)$/) {         # skip comments, empties 
	    next;

	} elsif ($mode eq "line") {
	    chomp;
	    $self->{_Data_}[$i++]{'line'} = $_; # grab entire line

	} else {
	    #__________________________________________
	    # Create an array of the field values ... we just ass*u*me 
	    # that there will be as many @values as @fields here!
	    #
	    chomp;
	    @values = split($splitIFS);       # split rec into fields

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
		${$field}         = $values[$j];       # this is NOT "$field"
		$tmpPtr->{$field} = $values[$j];       # fill hash record too
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
	if ($i == 0);

    return;
}

sub saveFile
{   my($self,$who,$fileName,$heading,$force) = @_;

    my($prev,$line,$folder,$i);
    my($time) = time;
    my($readOnly);
    #__________________________________
    # 1) If we weren't passed a fileName, try to figure it out
    #    (if passed as param use it, otherwise was stored in array when loaded)
    # 2) Get the file type we are dealing with (stored in array when loaded)
    # 3) Get the version the file was created with (stored in array when loaded)
    # 4) Make sure we can write the data  (stored in array when loaded)
    #
    $self->setError(0,"");
 
    $force    ||= "";
    $heading  ||= "";
    $fileName ||= $self->ctrl('fileName');
    $readOnly   = $self->ctrl('readOnly');
    $readOnly   = "" if $force;
 
    # DEBUG: Check "inode" numbers here not just filenames?
    if ($fileName ne $self->ctrl('fileName')) {
	$readOnly = "";
    }
    #__________________________________
    # Don't allow "partial" writes! This flag is set during the "_loadFile" 
    # routines. Set when records are excluded due to <match> criteria passed 
    # from calling program OR if file was loaded using "line" mode (we're not
    # currently set up to handle that record type).
    #
    my($stat,$err) = (0,"");
    $fileName or
	($stat,$err) = (-1,"Required 'fileName' not found in 'SDF_saveFile()'");

    $readOnly and
	($stat,$err) = (-1,"$readOnly in 'SDF__saveFile(x)'");

    $stat and return $self->setError($stat,$err);
    #__________________________________
    #
    local *OUT;
    if (! open(OUT,">$fileName")) {
	$err = "Unable to write $fileName in 'saveFile' method of '$PACK' ($!)";
	return $self->setError(-1,$err);
    }
    #__________________________________
    # If we have a header, make SURE it's all comments;
    # otherwise, we can expect problems next time we read.
    #
    my $noHeading = 0;                        # default: write an PTools::SDF header

    if ($heading =~ /^no(head|header|heading|ne)$/i) {
	    $noHeading = 1;

    } elsif ($heading) {
	    $heading =~ s/^([^#].*)/# $1/mg;  # add comments if missing
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
    $self->_saveFile($noHeading);

    close(OUT);
    return;
}


sub _saveFile
{   my($self,$noHeading) = @_;

    my $IFS = $self->ctrl('ifs') || ":";
    my($splitIFS) = "\\" . $IFS;

    local($\)="";      # Temporarially override the output record separator
    my($writeMode,$field,$line,$temp,@fields) = ( "","","","",() );

    if ($self->ctrl('dataFields') eq 'line') {
	$writeMode = "LINE";

    } else {
	@fields = split(":",$self->{'dataFields'});
	if (!@fields) {
	    my $err = "Unable to determine data fields in 'saveFileSDF' of '$PACK'";
	    return $self->setError(-1, $err);
	}
	unless ($noHeading) {
	    print OUT "#FieldNames $self->{'dataFields'}\n";
	    print OUT "#IFSChar $IFS\n"  unless ( $IFS eq ":" );
	    print OUT "\n";
	}
    }

    my($i)         = 0;
    my $parseIFS   = $self->ctrl('parseifs') || "";
    my $fieldCount = $#fields;
    my $fieldCheck = ":" x $fieldCount;

    while ($self->{_Data_}[$i]) {

	if ($writeMode eq "LINE") {
	    print OUT "$self->{_Data_}[$i]{'line'}\n";

	} else {
	    $line = "";
	    foreach $field (@fields) {
		$temp  = $self->{_Data_}[$i]{$field};
		$temp  = $self->escapeIFS( $temp ) if ($temp and $parseIFS);
		$line .= $temp . $IFS;
	    }
	    chop($line);                            # remove trailing IFS char
	    #
	    # Remove this when no "ctrl" fields in record zero. This is to
	    # skip writing a line if we have no data fields and only one record.

	    last if $self->param == 0 and $line =~ /^$fieldCheck$/o;
	    print OUT "$line\n";

	} # end of if ($writeMode eq "LINE") {

	$i++;

    } # end of while ($self->{_Data_}[$i]) {
    return;
}

sub ctrlFields
{   my($self) = @_;
    return(split(":",$self->{'ctrlFields'})) if wantarray;
    return($self->{'ctrlFields'});
}

sub ctrlDelete
{   my($self,$param) = @_;

    return undef if ! defined $self->{$param};

    my $value = $self->{$param};
    delete $self->{$param};

    $self->{'ctrlFields'} =~ s/(^|:)$param(:|$)/$2/;

    return $value;
}

sub ctrlParam
{   my($self,$param,@values) = @_;

    ## $self->setError(0,"");   # Don't reset these here.

    ## my $IFS = ":";           # ctrl field IFS is always a colon char.

    # WARN: Modifying the 'ctrl*' methods to use an alternate IFS 
    #       character as a field separator (other than colon) can
    #       cause methods to can cause "Out of Memory" errors.
    #       Do we need to allow this?? If so, fix the problem.
    #
    if ($param) {
	#______________________________________________________
	# Update if we have both a param and values; otherwise,
	# just return the parameter's current value.
	# If the param name is not in the list, update the list
	# (but don't add a leading ":" if no list exists yet).
	#
	my($sep) = "";    # no leading separator by default.
	if (@values) {
	    $self->{$param} = $values[0]        if $#values == 0;
	    $self->{$param} = join(":",@values) if $#values != 0;
	    if ($self->{'ctrlFields'} !~ /(^|:)$param(:|$)/) {
		$sep = ":" if $self->{'ctrlFields'}; 
		$self->{'ctrlFields'} .= "${sep}${param}";
	    }
	    return;
	#______________________________________________________
	# If we have just a param w/out values for the param then
	# determine which file type we have and return param's value.
	# Also, format return value depending on current context.
	#
	} else {
	    return($self->{$param}) if ($param =~ /^(parse)?ifs$/i);

	    # else ... ($self =~ /ARRAY/) {
	    return undef if ! defined $self->{$param};
	    return(split(":",$self->{$param})) if wantarray;
	    return($self->{$param});
	}
    #______________________________________________________
    # If we have no param then determine which file type we have 
    # and return all of the control field names.
    # Also, format return value depending on current context.
    #
    } else {
	return(split(":",$self->{'ctrlFields'})) if wantarray;
	return($self->{'ctrlFields'});
    }
}

*reset = \&fieldDelete;
*unset = \&fieldDelete;

sub fieldDelete  
{   my($self,$recNumber,$param) = @_;

    return undef unless defined $recNumber;
    return undef unless defined $param;
    return undef unless defined $self->{_Data_}[$recNumber]{$param};

    my $value = $self->{_Data_}[$recNumber]{$param};

  # delete $self->{_Data_}[$recNumber]{$param} = "";
    $self->{_Data_}[$recNumber]{$param} = "";

    return $value;
}

sub recParam  
{   my($self,$recNumber,$param,$value) = @_;

    (defined $recNumber and length($recNumber)) or ($recNumber = "");
    $param  = "" unless defined $param;
    $value  = "" unless defined $value;
    ## $self->setError(0,"");
    #______________________________________________________
    # If we have no paramters, just return the record count.
    # This will return a 0-based array count. For a 1-based
    # number, use the 'count' method, defined above.
    #
    if (! length($recNumber)) {
	my(@dref) = @{ $self->{_Data_} };    # dreference pointer to array
	return $#dref;                       # return record count
    }
    #______________________________________________________
    # Figure out if we are setting a parm, merely returning it's 
    # value, or returning all values for the record/array.
    #
    if ($param) {
	if ($param =~ /HASH/) {     ### and $param->isa("PTools::SDF::TAG")) {
	    #____________________________________________
	    # First is a special case to set entire "sdf" record 
	    # for use with the "tag2sdf" method in PTools::SDF::TAG.pm.
	    # This piece is the "receiving" end that allows loading
	    # converted "tag" fields into an "sdf" record. 
	    #
	    $self->{_Data_}[$recNumber] = $param;
	#______________________________________________________
	# If we have both a param and a value for the param
	# then determine which file type we have and update.
	#
	} elsif (length($value)) {                      # allow for "0"
	    #print "DEBUG (recParam): set $recNumber/$param to '$value'\n";
	    $self->{_Data_}[$recNumber]{$param} = $value;
	    return;
	    #______________________________________________________
	    # If we have just a param w/out a value for the param then
	    # determine which file type we have and return param's value 
	    # OR return the param name and value in array context.
	    # At this point we will have a $recNumber (sdf format) a
	    # $sectionName (ini format) or just a $param (tag format).
	    # Return values are
	    #   array context:   ($paramName, $paramValue)  # OBSOLETE!
	    #   array context:   $paramValue
	    #  scalar context:   $paramValue
	    #
	} else {
	    return $self->{_Data_}[$recNumber]{$param};
	}
    #______________________________________________________
    # If we ONLY have a record number, return values are
    #   array context:  array of data values
    #  scalar context:  "TRUE" if record exists
    #
    } elsif (length($recNumber)) {                     # allow for "0"
  	return "" if ($recNumber > $#{ $self->{_Data_} } or  $recNumber < 0);

	if (wantarray) {
	    my(@fields) = $self->ctrl('dataFields');
	    my(@values);
	    my($i) = 0;
	    foreach my $field (@fields) {
		$values[$i++] = $self->{_Data_}[$recNumber]{$field};
	    }
	    return (@values);

	} else {  # does rec exist? or not?
	    return ($self->{_Data_}[$recNumber] ? 1 : 0); 
	}
    }
}

*recEntry = \&getRecEntry;

sub getRecEntry                    # Return a data record as a hash reference
{   my($self,$recNumber) = @_;
    return undef unless defined $recNumber and $recNumber =~ /\d+/;
 ## return undef unless length( int( $recNumber ) );
    return undef unless ref $self->{_Data_}[$recNumber];
    return $self->{_Data_}[$recNumber];
}

sub dump
{   my($self,$start,$end)= @_;      # start,end for 'sdf' objects only
    my($field,$text)=("","");
    my($pack,$file,$line)=caller();
    my($value);
    #_____________________________________________________
    # How many records before it's no longer a "Simple" Data File?
    $start ||= 0;
    $end   ||= 9999999999;
    $text  = "DEBUG: (SDF\:\:dump) self='$self'\n";
    $text .= "CALLER $pack at line $line ($file)\n";
    $text .= "Control Fields\n";
    foreach $field ( sort keys %{ $self } ) {
	$value = $self->ctrl($field);
	$value = "'$value'" if ($field eq "ifs" and $value =~ m#\s#);
	$text .= " $field=$value\n";
    }
    $text .= "\n";
    my @tags = sort keys %{ $self->{_Data_}[0] };
    for my $i (int($start) .. $self->param) {
	last unless $i < $end;
	$text .= "DataRecord $i\n";
	foreach $field (@tags) {
	    $value = $self->param($i,$field);
	    $value = $self->zeroStr($value, "");  # handle undef, "0" and ""
	    $text .= " $field=$value\n";
	}
    }
    $text .= "____________\n";
    return($text);
}

sub zeroStr
{   my($self,$value,$undef) = @_;
    return $undef unless defined $value;
    return "0"    if (length($value) and ! $value);
    return $value;
}
#_________________________
1; # required by require()

__END__

=head1 NAME

PTools::SDF::SDF - Implements a Simple Data File as a 'Self Defining File'

=head1 VERSION

This document describes version 0.32, released February, 2006.

=head1 SYNOPSIS

    use PTools::SDF::SDF;

    use PTools::SDF::SDF qw( noparse );     # see Performance Note, below

    $fileName= "/etc/passwd";
    (@fields)= qw(name passwd uid gid gcos dir shell);

    $sdfObj = new PTools::SDF::SDF($fileName,"","",@fields);

    $sdfObj->sort("","",'uname');     # sort on user name

    foreach $idx (0 .. $sdfObj->param) {
        $uname = $sdfObj->param($idx, 'uname');
        $gcos  = $sdfObj->param($idx, 'gcos');

        printf(" %10s %-30s\n", $uname, $gcos);
    }

=head1 DESCRIPTION

B<PTools::SDF::SDF> is used to eliminate dependence on field positions within
file records. This package reads and writes files with an arbitrary 
character used as the 'internal field separator,' or 'IFS,' usually a 
colon (':') or perhaps a pipe ('|') character.

A given data file becomes 'self defining' when it includes one or
more special comment headers that define the file's characteristics.
This includes naming each of the fields within a record, and specifying
the IFS character used within each record.

As shown in the SYNOPSIS, above, for files where it is not feasible to
embed the header within the file, the fields are named as the file is
loaded during object instantiation.

Optional field definition header(s) must appear before first record
For example, an application log file might have the following fields
and, in this case, record fields are separated by an exclamation mark.

 #FieldNames date:uname:pid:event_message
 #IFSChar !

The B<#FieldNames field1:field2:field3...> header is read by this 
class and used to name each field within records in the file during
object creation. By default the B<save> method writes this back into
the file.

This class also allows for special cases with the '#IFSChar' header.
White space characters can be used singly, as a 'space', a 'tab', or 
Perl's special '\s' meta character. In addition multiple white space
characters can be specified using Perl's special '\s+' syntax. The
IFS character can be quoted using double quotes within the header.

 #IFSChar "     "              # single tab character
 #IFSChar " "                  # single space character
 #IFSChar "\s"                 # single space character
 #IFSChar "\s+"                # multiple space character

This implies that the double quote character can not be used as a
field separator within a data file.

B<Warning>: When specifying a single white space character, make
I<sure> that there is only B<one> of them in between each field
within a record.

=head2 Performance Note

Parsing every field in each record to encode/decode the 'IFS' character 
adds quite a bit of overhead here. To disable this parsing, add a 'noparse' 
parameter as shown in SYNOPSIS section, above. Only do this when you know 
it is safe to do so (i.e., when there is no possibility of an 'IFS' 
character embedded within a field).

Other modules exist to manipulate B<PTools::SDF::SDF> objects in various ways
including user defined indices and a 'Simple Data Base' definition.
Other modules also exist that implement other types of 'Simple Data Files'
including Windows '.INI' files, 'tagged' data files, and others. See 
L<PTools::SDF::Overview> for further details.


=head2 Constructor

=over 4

=item new ( [ FileName ]  [, Match ] [, IFSChar ] [, FieldNames ] )

Creates a new B<PTools::SDF::SDF> object and, if a B<FileName> parameter is
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

To load only a subset of the data file, pass a B<Match> value. The
match can either be for the entire data record or limited to a specific
field within each record. Any valid Perl expression will work, including
'regular expression' matches.

Examples:

    (@fields)= qw(name passwd uid gid gcos dir shell);

    # Load passwd entries for "root" users only

    $sdfObj->new("/etc/passwd", "\$uid eq '0'", undef, @fields);


    # Load passwd entries for "C Shell" users only

    $sdfObj->new("/etc/passwd", "\$shell =~ /csh$/", undef, @fields);


    # Load entries where "smith" is found in any of the fields

    $sdfObj->new("/etc/passwd", "/smith/i", undef, @fields);

Note that when a 'subset' of a data file is loaded, the B<save>
method is disabled. Use the B<Force> parameter of the B<save>
method to override, or use the B<ctrl> method to specify a
different B<FileName> prior to calling B<save>.

=item IFSChar

The 'internal field separator' (IFS) character that is used to delimit 
fields within each record in the data file. The default is a colon (':') 
character. See the 'L<Performance Note|Performance Note>' in the
L<Description|"DESCRIPTION"> section, above, regarding parsing each and
every field for this character.

Note that when the '#FieldName' header is used for the 'Self Defining File' 
format,  B<always> use a colon (':') character to separate field names
within the header.

=item FieldNames

When it is not appropriate to embed a comment header within a
data file to define the field names for each record, pass a
B<FieldNames> parameter to the B<new> method. This can be 
either a colon separated list of fields, or an array.

=back

Examples

    $sdfObj = new PTools::SDF::SDF;

    $sdfObj = new PTools::SDF::SDF( "/home/cobb/data/testfile.sdf" );

=back


=head2 Methods

=over 4

=item param ( [ Index, FieldName ] [, Value ] )

Fetch or set field values within a record. When called without any
parameters, returns a zero-based count of entries in the object.
Use the B<count> method to obtain a one-based count of entries.

=over 4

=item Index

Specify the relative record number within the B<PTools::SDF::SDF> object.

=item FieldName

Specify the field name to access within the indexed record.

=item Value

The B<Value> is an optional parameter that is used to set the
value of the specified B<FieldName>. Without a this parameter,
the current value of the field is returned.

Examples:

    $fieldValue = $sdfObj->param( 0, 'fieldname' );

    $sdfObj->param( 0, 'fieldname', "new value" );

=back

There is a special form of the B<param> method. If a hash reference 
is passed for the B<FieldName> parameter, this hash ref will I<replace>
the data record specified by the B<Index> parameter. 
I<Note that no checking is done>. It is up to the programmer to ensure 
appropriate key names and values.

This mechanism has many uses, one of which is with the B<tag2sdf>
method in the B<PTools::SDF::TAG> class. For example,

    use PTools::SDF::SDF;
    use PTools::SDF::TAG;

    $sdfObj = new PTools::SDF::SDF;
    $tagObj = new PTools::SDF::TAG( "myFile.tag" );

    $tagHashRef = $tagObj->tag2sdf;

    $nextRecord = $sdfObj->count;          # (one-based count)

    $sdfObj->param( $nextRecord, $tagHashRef );



=item getRecEntry ( RecNumber )

Fetch the entire record indexed by B<RecNumber> as a hash reference.
This can then be used to access and update field values. 

WARNING: Modifying data values in the returned hash reference B<will>
update the values in the corresponding data record.

Example:

    $hashRef = $sdfObj->getRecEntry( $index );

    $hashRef->{shell} = "/bin/ksh";        # updates the $sdfObj, too.


=item ctrl ( CtrlField [, CtrlValue ] )

Fetch or set I<control> field parameters within an object. This can
also be used to cache temporary data in the current B<PTools::SDF::SDF> 
object.  Just be sure to use a unique attribute name and remember that 
this data will not be saved with the file data. See the L<dump|dump> 
method for an example of displaying control fields and values.

=over 4

=item CtrlField

Specify the field name to access within the indexed record.

=item CtrlValue

The B<CtrlValue> is an optional parameter that is used to set
the value of the specified B<CtrlField>. Without a this parameter,
the current value of the field is returned.

Examples:

    # Specify a new file name for the current PTools::SDF::SDF object

    $fieldValue = $sdfObj->ctrl( "fileName", '/tmp/newDataFilename' );

    # Fetch a colon-separated list of field names in the file.
    # In list context, an array of field names is returned.

    $fieldList   = $sdfObj->ctrl( "dataFields" );
    (@fieldList) = $sdfObj->ctrl( "dataFields" );

    # Specify a new list of fieldnames for the current object
    # WARN: this will *not* change any existing field names, and
    # only existing fields that appear in this list will be written
    # to the data file via the "save" method. This is provided as
    # a way to create a subset of a file, to add new fields, and/or
    # to re-arrange the field order when file is saved to disk.

    $sdfObj->ctrl( "dataFields", "colon:separated:list:of:names" );
    $sdfObj->ctrl( "dataFields", @fieldNameList );

=back


=item fieldDelete ( RecNumber, FieldName )

Delete the value for a named data field within a record.

Example:

    # Delete the value for the 'proddesc' field in record 24

    $sdfObj->fieldDelete( 24, 'proddesc');


=item ctrlDelete ( CtrlField )

Delete the value for a named control field in the current object.

Example:

    # Loading a subset of a data file sets an attribute to disable the
    # "save" method. This removes the attribute and re-enables "save":

    $sdfObj->ctrlDelete('readOnly');


=item delete ( RecNum [, NumRecs ] )

Delete one or more entire records from the current B<PTools::SDF::SDF> 
object.  The deleted records are available as a return parameter. This 
will be returned as a list of hash references.

=over 4

=item RecNum

Record number at which to start deleting.

=item NumRecs

Number of record entries to delete. Defaults to 1;

=back

Examples:

    $hashRef = $sdfObj->delete( 5 );

    (@arrayRef) = $sdfObj->delete( 10, 30 );


=item save ( [ UserID ] [, NewFileName ] [, Heading ] [, Force ] )

Write the data in the current object out to a disk file.

B<Note>: Only those fields that have an entry in the B<dataFields>
I<control parameter> will be written to the disk file. 
See the L<ctrl|ctrl> method, above, for details on using this attribute.

In addition, the only I<control parameters> that are saved with the
file are the B<field names>.

=over 4

=item UserID

By default the B<PTools::SDF::SDF> module adds a header that includes the
uname of the person running the current script. Use this parameter
to log a different user name.

Example:

    $webUserid = $ENV{'REMOTE_USER'};   # (from Web Server Basic Auth)

    $sdfObj->save( $webUserid, $filename );


=item NewFileName

By default the B<PTools::SDF::SDF> module saves the file using the original
name specified when creating the current object. This can be changed
by passing a new file name here.

=item Heading

By default the B<PTools::SDF::SDF> module adds a header that includes a date
stamp (Unix 'epoch' number) of when the file was saved. To write a
different header, pass the text here.

=item Force

If a 'subset' of the original data file was loaded using 'match'
criteria, the B<save> parameter is disabled by default. Pass any
non-null parameter here to override this default and force a save. 

B<WARN>: This will cause any records omitted during the load to be lost.

=back

Examples:

    $sdfObj->save;

    ($stat,$err) = $sdfObj->save;

    $sdfObj->save( undef, "newfilename" );


Another Example:

    $sdfObj->ctrl('fileName', "newfilename" );

    $sdfObj->save;

    ($stat,$err) = $sdfObj->status;

=item sort ( Options )

The options used for sorting depend entirely on which sort
module is loaded at the time of the call. There are several
sort modules available (listed in the L<See Also|"SEE ALSO"> 
section, below).

Options used by the default B<PTools::SDF::Sort::Bubble> module include the 
following. See description of the B<extend> method, in the L<PTools::SDF::File>
class, on how to select other sort modules. See descriptions of the
other sort modules for details of the parameters they expect.

The sort modules that accompany the B<SDF> modules will B<ONLY>
work with 'PTools::SDF::SDF type' objects.

=over 4

=item Mode

The B<Mode> parameter can be any of the following. Remember
that this list is for the default sorter only. Other sort
modules may not allow a mode parameter.

=over 4

=item *
reverse

Reverse the sort order. Note that when reversing
the sort order, the B<KeyFields> should still be in decending 
order (primary, secondary, tertiary, etc).

=item *
ignorecase

Ignore upper/lower case when sorting.

=item *
reverse:ignorecase

Both of the above.

=back


=item KeyFields

For the default sort module, this parameter accepts a list of 
field names starting with the primary sort key. Other sort
modules included with the B<PTools::SDF::SDF> module will only accept
a single sort key.

=back


=item isSortable,  notSortable

There must be at least two records in an B<PTools::SDF::SDF> object
for a sort to be effective. 

Example:

    $sdfObj->isSortable  and  $sdfObj->sort( $mode, @keyFields );


=item hasData, noData

These methods exist for convenience to query the state of the object. 

Examples:

    # The following two examples are equivalent

    $sdfObj->hasData  and do { ... }
    $sdfObj->param    and do { ... }


    # The following two examples are equivalent

    $sdfObj->noData   and do { ... }
    $sdfObj->param     or do { ... }


=item status

=item stat

=item err

Determine whether an error occurred during the last call to a method on
this object. The B<stat> method returns different values depending on
the calling context.

 ($stat,$err) = $sdfObj->status;

 $stat = $sdfObj->stat;     # scalar context returns status number
 ($err)= $sdfObj->stat;     # array context returns error message

 $err = $sdfObj->err;


=item dump ( [ StartRec [, NumRecs ] ] )

Display contents of the current B<PTools::SDF::SDF> object. This is useful
during testing and debugging, but does not produce a 'pretty' format.
For large data files limiting the output will be most useful.

Examples:

    print $sdfObj->dump;          # can produce a *lot* of output

    print $sdfObj->dump( 0, -1 )  # dump only the "control field" values

    print $sdfObj->dump( 10, 5 )  # dump recs 10 through 15.

=back

=head1 WARNINGS

B<Warning>: When specifying a single white space IFS character, make
I<sure> that there is only B<one> of delimiter character in between 
each field within a record.

=head1 INHERITANCE

This B<PTools::SDF::SDF> class inherits from the B<PTools::SDF::File> 
abstract base class.  Additional methods are available via this parent 
class.

The following B<SDF> classes inherit from this class either directly
or indirectly. B<PTools::SDF::ARRAY>, B<PTools::SDF::DIR>, 
B<PTools::SDF::DSET> and B<PTools::SDF::IDX>. These are contained
in the 'PTools-SDF-DB' distribution available on CPAN.

=head1 SEE ALSO

See
L<PTools::SDF::Overview>,
L<PTools::SDF::ARRAY>, L<PTools::SDF::CSV>,  L<PTools::SDF::DB>,
L<PTools::SDF::DIR>,   L<PTools::SDF::DSET>, L<PTools::SDF::File>, 
L<PTools::SDF::IDX>,   L<PTools::SDF::INI>,  L<PTools::SDF::TAG>,
L<PTools::SDF::Lock::Advisory>, 
L<PTools::SDF::Sort::Bubble>, L<PTools::SDF::Sort::Quick>,
L<PTools::SDF::Sort::Random> and L<PTools::SDF::Sort::Shell>.

In addition, several implementation examples are available. See
L<PTools::SDF::File::AutoHome>, L<PTools::SDF::File::Mnttab> and 
L<PTools::SDF::File::Passwd>. These are contained in the
'PTools-File-Cmd' distribution available on CPAN.

=head1 AUTHOR

Chris Cobb, E<lt>nospamplease@ccobb.netE<gt>

=head1 COPYRIGHT

Copyright (c) 1997-2007 by Chris Cobb. All rights reserved. 
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
