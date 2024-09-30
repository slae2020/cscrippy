#!/usr/bin/perl -w
####
# license
###
use 5.006;
use strict;
use warnings;

use lib "/home/stefan/prog/bakki/cscrippy/";
use dialog; # qw( set_dialog_item );
use checker;

$is_test_mode = 1;

@{$dialog_config{titles}} = set_dialog_item ('titles' , 'Program DoIt', 'Choose your items', '#');

message_exit ("Hääh", 33);
__END__
