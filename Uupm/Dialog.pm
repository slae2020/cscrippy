package Uupm::Dialog;
####
# license
###
use 5.010;
use strict;
use warnings;
use Exporter;
use Scalar::Util qw(looks_like_number);
use lib "/home/stefan/perl5/lib/perl5/";  # ???
use UI::Dialog::Backend::Zenity;

use Data::Dumper; # nur für test ausgaben

BEGIN {
  use vars qw ( 
	$VERSION 
	$is_silent_mode 
	$is_test_mode 
	$cancel_option 
	$nb_space 
	
	$error_message
	
	@ISA 
	);
  $VERSION = 'Dialog.pm v0.11'; # for Dialog.pm 2024.09.30
  $is_silent_mode = 0;
  $is_test_mode = 0;
  $cancel_option="#x001B"; # unicode https://www.sonderzeichen.de/ASCII/Unicode-001B.html
  $nb_space="#x0020";
  
  $error_message = "General error.";
  our @ISA = qw ( Exporter );
  our @EXPORT = qw (
    $VERSION
        $is_silent_mode
        $is_test_mode
        $cancel_option
        $nb_space

    set_dialog_item
        add_list_item
        message_exit
        message_test_exit
        message_notification
        ask_to_continue
        ask_to_choose

    %_dialog_config
    $error_message
        );
};

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#: Displaying windows
#:     - with messages-and-exit with error-codes
#:     - notifications
#:

#::: declarations ::::::::::::::#

# Dialog-Variable
my %_dialog_defaults = (
        titles      => [ 'Title-Text (default)', 'text-line (default)', ' ' ],
        columns     => [ '[O]', 'ident', 'item to choose (default)' ],
        window_size => [ 150 ,  400 , ' ' ],
       #list        => not to be defined here!
        not_defined => [ 'nil_1 (default)', 'nil_2 (default)', 'nil_3 (default)' ], # rename  undefined_values ???
    );
our %_dialog_config = %_dialog_defaults;

# Declare zenity-window
our $d = UI::Dialog::Backend::Zenity->new(
        title       => $_dialog_defaults{titles}[0],
        text        => $_dialog_defaults{titles}[1],
        height      => $_dialog_defaults{window_size}[0],
        width       => $_dialog_defaults{window_size}[1],
        listheight  => 5,
        debug       => 0, # debug <>0 from zenity
        test_mode   => $is_test_mode,
        );

#::: main ::::::::::::::::::::::#

printf "------------ %s ('%s')------------\n",$0,$VERSION if $is_test_mode;

#push @{$_dialog_config{list}}, add_list_item (1,'01','first choice');
#push @{$_dialog_config{list}}, add_list_item (0,'02','secondbest');

#my @answer=ask_to_choose (%_dialog_config);
#printf ">%s<\n",$_ for @answer;

#my $ansi=ask_to_continue("'usb_stick_name' is missing: ['usb_stick_path' not found]\n\nDo you want to try again?", 22);
#printf "%s", $ansi;

#@{$_dialog_config{titles}} = set_dialog_item ('titles' , 'Program DoIt', 'Choose your items', '#');

#::: subs ::::::::::::::::::::::#

# Setting-routine for values for the dialogs like title, tesxt, size etc.
# Returns either the three(!) arguments or default-values from %dialog-defaults
# '' for args allowed
sub set_dialog_item {
    my ($dialog_field_name, @dialog_items) = @_;
    my $number_of_arguments = (1 + 3 );

    # Die if no dialog_field_name is provided
    die "No field-name for dialogs defined, empty arguments." unless @_;

    # Use default values if the dialog_field_name is not found or the number of arguments is incorrect
    #my @local_dialog_defaults = @{$_dialog_defaults{$dialog_field_name}} // @{$_dialog_defaults{not_defined}}; funkt nicht
    my @local_dialog_defaults = $_dialog_defaults{not_defined};
    if ($_dialog_defaults{$dialog_field_name}) {
        @local_dialog_defaults = $_dialog_defaults{$dialog_field_name};
    }
    if ( @_ != $number_of_arguments) {
        warn "(t) Error: set-dialog-item for '$dialog_field_name' expects $number_of_arguments arguments, got " . scalar(@_)
            if $is_test_mode;
        #@dialog_items = @local_dialog_defaults;
        @dialog_items = @{$local_dialog_defaults[0]};
    }
    # Die if the dialog_field_name is not found in the list of valid dialog_field_names
    die "Unknown or useless field-name for dialogs '$dialog_field_name'" unless exists $_dialog_defaults{$dialog_field_name};

    @{$_dialog_config{$dialog_field_name}} = @dialog_items;
    #return 0 nicht setzen!
};

# Function to facilate input of list-array
# add list item (a b c) --> push where, b , [ c , a ] as req. by UI::Backend
# a flag for checkbox: 0 for not checked, else for checked
# b id label, which is finally returned as choosen item(s); max legth 5, aborted if exceeded !
# c text for describing item
sub add_list_item {
    my ($list_checkbox_flag,$list_id,$list_text) = @_;

    # $list_id max length ==5
    if (length $list_id > 5) {
        message_exit ( "Error: list_id '$list_id' length exceeds 5 characters", 41);
    };
    # $list_checkbox_flag muss int sein sonst 0
    if (! looks_like_number ($list_checkbox_flag) ) {
        $list_checkbox_flag = 0
    };

    # order following to UI::Dialog
    my @output = ( $list_id, [ $list_text , $list_checkbox_flag ] );
    return @output;
};

# Error-window & exit with error number;
# default-value 1 when missing; wait for response except for err==0
# ':' replaced by '\n'
sub message_exit {
    my ($txt, $err) = @_;
    $err = 1 unless defined $err;
    $txt =~ s/:\s*/:\n/g;

	 if (! $is_silent_mode) {# ???
            say "(t) ".$_dialog_config{titles}[0]."\n$txt\nLeaving program ($err).";
        };
    if ($err > 0) {
		$@ = ''; # reset necessary cos an error's calling this sub :) 
        if ($is_test_mode) {
            say "(t) ".$_dialog_config{titles}[0]."\n$txt\nLeaving program ($err).";
        } else {		
            eval {
                $d->error(
                    title   => $_dialog_config{titles}[0],
                    text    => "$txt\n\nLeaving program with code $err." ,
                    height  => $_dialog_config{window_size}[0],
                    width   => $_dialog_config{window_size}[1]
                );
            }
        };
        if ($@) {
            warn "Error displaying dialog: $@";
        }
    }
    exit $err
}

# First entry is a test
# exit-message if not zero
#
sub message_test_exit {
    my ($test_result, $txt, $err) = @_;

    if ($test_result != 0 ) {
        if ($is_test_mode) {
            die "(t) $_dialog_config{titles}[0]\n$txt '$test_result' ($err)\n", $err;
        } else {
            message_exit ("$txt\n{Counting revealed $test_result}", $err);
        }
    }
}

# Notification-window
# timout after $2 sec or click (not working)
#
sub message_notification {
    my ($txt, $timeout) = @_; # ??? timeout nicht berücksichtigt
say "mess-notif::Time-->".$timeout."?\n";

    if ($timeout > 0 && ! $is_silent_mode ) {
        if ($is_test_mode) {
            say "(t) ".$_dialog_config{titles}[0]."\n $txt";
        } else {
            eval {
                $d->infobox(
                    title   => $_dialog_config{titles}[0],
                    text    => $txt,
                    timeout => $timeout,
                    height  => $_dialog_config{window_size}[0], # std 150
                    width   => $_dialog_config{window_size}[1]  # std 400
                );
            };
            if ($@) {
                warn "Error displaying notification: $@";
            }
        }
    }
}

# Ask for conformation to continue with internal error code
# returns 1 for yes
#         is_cancel else
sub ask_to_continue {
    my ($txt, $err) = @_;
    $err = -1 unless defined $err;
    $txt =~ s/: /:\n/g;

    die "(t) $_dialog_config{titles}[0]\n$txt ($err)\n", -1
        if $is_test_mode;

    my $answer;
    eval {
        $answer = $d->question(
            title   => $_dialog_config{titles}[0],
            text    => "$txt ($err)" ,
            height  => $_dialog_config{window_size}[0],
            width   => $_dialog_config{window_size}[1]
        );
    };
    if ($@) {
        warn "Error displaying notification: $@";
        return 0;
    }
    return $answer == 1 ? 1 : $cancel_option;
}

# Ask for selection out of checklist;
# first 3 strings for titles etc;
# $cancel_option if no choose
sub ask_to_choose {
    my @answer;

    # Die if no list-items are provided
    die "Error with checklist: no items found to choose."
        unless defined( $_dialog_config{list}[0] ) && length($_dialog_config{list}[0]) > 0 ;

    eval {
        @answer = $d->checklist (
                    title   => $_dialog_config{titles}[0],
                    text    => $_dialog_config{titles}[1],
                    height  => $_dialog_config{window_size}[0],
                    width   => $_dialog_config{window_size}[1],
                    column1 => $_dialog_config{columns}[0],
                    column2 => $_dialog_config{columns}[1],
                    column3 => $_dialog_config{columns}[2],
                    list    => $_dialog_config{list}
                  );
    };
    if ($@) {
            warn "Error with checklist: $@";
            return 0;
    };
    if (! $answer[0] gt '' ) {
        @answer = $cancel_option;
    } elsif ($answer[0] eq "0") {
        @answer = $cancel_option;
    };

    return @answer;
}

1;

__END__

???
examples
#
resetdisplay;


#
message_exit ("Unknown Error!", 22);

#
message_notification (":done:", 0);
message_notification ("Reading list!",10);

#
message_test_exit ( 3* 4, "Wrong result:", 33);

#
my $ansi=ask_to_continue("'usb_stick_name' is missing: ['usb_stick_path' not found]\n\nDo you want to try again?", 22);
printf "%s", $ansi;

#
@{$_dialog_config{titles}} = set_dialog_item ('titles','Program DoIt', 'Choose your items'); 
@{$_dialog_config{columns}} = set_dialog_item ('colums', '[@]', 'Id', 'Item');
#@{$_dialog_config{schnulli}} = set_dialog_item ( 'fixie' ); # faulty

push @{$_dialog_config{list}}, add_list_item (1,'01','first choice');
push @{$_dialog_config{list}}, add_list_item (0,'02','secondbest');

my @answer=ask_to_choose (%dialog_config);

my @answer=ask_to_choose (%dialog_config);
printf ">%s<\n",$_ for @answer;

#
foreach my $key (keys %dialog_config) {
    printf "$key is >". join ('/',@{ $_dialog_config{$key} })."<\n";
}
printf "\nWindows h:%s/w:%s<", $dialog_defaults{window_size}[0],$dialog_defaults{window_size}[1];
printf "\nWindows h:%s/w:%s<", $_dialog_config{window_size}[0],$_dialog_config{window_size}[1];

printf "\n :done: \n";

ab hier junk


sub set_dialog_itemKW {
    my ($dialog_field_name, @dialog_items) = @_;
    my $number_of_arguments = (1 + 3 );

    # Die if no dialog_field_name is provided
    die "No field-name for dialogs defined, empty arguments." unless @_;

    # Use default values if the dialog_field_name is not found or the number of arguments is incorrect
    my $local_dialog_defaults = $_dialog_defaults{$dialog_field_name} // $_dialog_defaults{not_defined};
    if (@_ != $number_of_arguments) {
        warn "(t) Error: set-dialog-item for '$dialog_field_name' expects $number_of_arguments arguments, got " . scalar(@_)
            if $is_test_mode;
        @dialog_items = @$local_dialog_defaults;
    }

    # Die if the dialog_field_name is not found in the list of valid dialog_field_names
    die "Unknown or useless field-name for dialogs '$dialog_field_name'" unless exists $_dialog_defaults{$dialog_field_name};

    return @dialog_items;
};
