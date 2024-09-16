#!/usr/bin/perl

use constant VERSION => "0.1"; # 2024.09.16
#declare dialog_height
#declare dialog_width

# Error-window & exit with error number; default-value 1 when missing; wait for response except for err==0
sub message_exit {
    my ($txt, $err) = @_;
    $err = 1 unless defined $err;
    $txt =~ s/:\s*/:\n/g;

    if ($err > 0) {
        #system("zenity --error --width $mwidth --title \"$messenger_top_text\" --text \"$txt ($err)\"");
        system("zenity --error --width 350 --title \"$messenger_top_text\" --text \"$txt ($err)\"");
    }
    exit $err;
    #return $err;
}

printf "------------ %s (V%s)------------\n",$0,VERSION;

message_exit ("Hier stop", 22);


__END__
