#!/usr/bin/perl -w
use strict;

use constant VERSION => "0.1"; # 2024.09.16

use Scalar::Util qw(looks_like_number);

my $is_test_mode = 0; # kw ??? rename is_in_test_mode ???
# for returning string while aborting message
my $is_cancel="#x0020";
# standard titles
my @messenger_text = ("Title-Text", "textline"); # nach set (local ???

use lib "/home/stefan/perl5/lib/perl5/";  # ???
use UI::Dialog::Backend::Zenity;

printf "------------ %s (V%s)------------\n",$0,VERSION; #???

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#: Displaying windows
#:     - with messages-and-exit with error-codes
#:     - notifications
#:

# Dialog-Variable
my %dialog_config;
my %dialog_defaults = (
        titles      => [ 'Title-Text', 'text line', ' ' ],
        columns     => [ '[O]', 'ident', 'item to choose' ],
        window_size => [ '200', '350', ' ' ],
        not_defined => [ 'nil_1', 'nil_2', 'nil_3' ],
    );

# Window ????
my $d;

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


#:::

# Error-window & exit with error number;
# default-value 1 when missing; wait for response except for err==0
# ':' replaced by '\n'
sub message_exit {
    my ($txt, $err) = @_;
    $err = 1 unless defined $err;
    $txt =~ s/:\s*/:\n/g;

    if ($err > 0) {
        if ($is_test_mode) {
            printf "(t) %s\n%s\nExciting program (%s).", $messenger_text[0], $txt, $err;
        } else {
            eval {
                $d->error(
                    title   => $messenger_text[0],
                    text    => "$txt\n\nExciting program ($err)." ,
                    height  => $dialog_config{window_size}[0],
                    width   => $dialog_config{window_size}[1]
                );
            }
        };
        if ($@) {
            warn "Error displaying dialog: $@";
        }
    };
    exit $err;
}

# First entry is a test
# exit-message if not zero
#
sub message_test_exit {
    my ($test_result, $txt, $err) = @_;

    if ($test_result != 0 ) {
        if ($is_test_mode) {
            die "(t) $messenger_text[0]\n$txt '$test_result' ($err)\n", $err;
        } else {
            message_exit ("$txt '$test_result'", $err);
        }
    }
}

# Notification-window
# timout after $2 sec or click (not working)
#
sub message_notification {
    my ($txt, $timeout) = @_; # ??? timeout nicht berücksichtigt
printf "Time?-->".$timeout."\n";

    if ($timeout > 0 ) {
        if ($is_test_mode) {
            printf "(t) %s\n%s", $messenger_text[0], $txt;
        } else {
            eval {
                $d->infobox(
                    title   => $messenger_text[0],
                    text    => $txt,
                    timeout => $timeout,
                    height  => $dialog_config{window_size}[0],
                    width   => $dialog_config{window_size}[1]
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

    if ($is_test_mode) {
        die "(t) $messenger_text[0]\n$txt ($err)\n", -1;
    } else {
        my $answer;
        eval {
            $answer = $d->question(
                title   => $messenger_text[0],
                text    => "$txt ($err)" ,
                height  => $dialog_config{window_size}[0],
                width   => $dialog_config{window_size}[1]
            );
        };
        if ($@) {
            warn "Error displaying notification: $@";
            return 0;
        }
        return $answer == 1 ? 1 : $is_cancel;
    }
}

###
# Ask for selection out of list;
# first 3 strings for titles etc;
# $is_cancel if no choose
sub ask_to_choose {
    #my (@dialog_texts, @cc, @ll) = @_;
    my %all = @_;

    my $dialog_ref = $all{'titles'};
    my $cc_ref = $all{'columns'};
    my $list_ref = $all{'list'};


    #die "Missing required keys in the hash" unless exists $all{'titles'} && exists $all{'columns'}; # ??? :)

    my @dialog_texts = @$dialog_ref;
    my @cc = @$cc_ref;
    my @ll = @$list_ref;

    my @answer;
    eval {
        @answer = $d->checklist (
                    title   => $dialog_texts[0],
                    text    => $dialog_texts[1],
                    height  => $dialog_config{window_size}[0],
                    width   => $dialog_config{window_size}[1],
                    column1 => $cc[0],
                    column2 => $cc[1],
                    column3 => $cc[2],
                    list    => $list_ref
                  );
    };
    if ($@) {
            warn "Error displaying notification: $@";
            return 0;
    };
    if (! $answer[0] gt '' ) {
        @answer = $is_cancel;
    } elsif ($answer[0] eq "0") {
        @answer = $is_cancel;
    };

    return @answer;
}

#:::




# Returns either the three(!) arguments or default-values from %dialog-defaults
sub set_dialog_item {
    my ($dialog_field_name, @dialog_items) = @_;
    my $number_of_arguments = (1 + 3 );

    # Die if no dialog_field_name is provided
    die "No field-name for dialogs defined, empty arguments." unless @_;

    # Use default values if the dialog_field_name is not found or the number of arguments is incorrect
    my $local_dialog_defaults = $dialog_defaults{$dialog_field_name} // $dialog_defaults{not_defined};
    if (@_ != $number_of_arguments) {
        warn "(t) Error: set_dialog_item for '$dialog_field_name' expects $number_of_arguments arguments, got " . scalar(@_)
            if $is_test_mode;
        @dialog_items = @$local_dialog_defaults;
    }

    # Die if the dialog_field_name is not found in the list of valid dialog_field_names
    die "Unknown or useless field-name for dialogs '$dialog_field_name'" unless exists $dialog_defaults{$dialog_field_name};

    return @dialog_items;
};

#resetdisplay;
#setdisplay (500, 500);
#set_messenger_text ("New Title", "new line");

# first init
sub init_dialog() {
    # Window ????
    $d = UI::Dialog::Backend::Zenity->new(
            title       => $dialog_defaults{titles}[0],
            text        => $dialog_defaults{titles}[1],
            height      => $dialog_defaults{window_size}[0],
            width       => $dialog_defaults{window_size}[1],
            #columns????
            listheight  => 5,
            debug       => 1*0, ##???
            test_mode   => $is_test_mode, #???
            );

    #reset display
    @{$dialog_config{window_size}} = set_dialog_item ( 'window_size' );

    @{$dialog_config{titles}} = set_dialog_item ( 'titles' , "New Title" , "new line" , '#');
    @{$dialog_config{columns}} = set_dialog_item ( 'columns' );
};


################


init_dialog;

push @{$dialog_config{list}}, add_list_item (1,'01','first choice'); # first belegung nach ini oder was????
push @{$dialog_config{list}}, add_list_item (0,'02','secondbest');

my @answer=ask_to_choose (%dialog_config);
printf ">%s<\n",$_ for @answer;


__END__

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
@{$dialog_config{titles}} = set_dialog_item ('Program DoIt', 'Choose your items'); ??? austasuschen
@{$dialog_config{columns}} = set_dialog_item ( '[@]', 'Id', 'Item');
#@{$dialog_config{schnulli}} = set_dialog_item ( 'fixie' ); # faulty

push @{$dialog_config{list}}, add_list_item (1,'01','first choice');
push @{$dialog_config{list}}, add_list_item (0,'02','secondbest');

my @answer=ask_to_choose (%dialog_config);

my @answer=ask_to_choose (%dialog_config);
printf ">%s<\n",$_ for @answer;

#
foreach my $key (keys %dialog_config) {
    printf "$key is >". join ('/',@{ $dialog_config{$key} })."<\n";
}
printf "\nWindows h:%s/w:%s<", $dialog_defaults{window_size}[0],$dialog_defaults{window_size}[1];
printf "\nWindows h:%s/w:%s<", $dialog_config{window_size}[0],$dialog_config{window_size}[1];

printf "\n :done: \n";

ab hier junk
