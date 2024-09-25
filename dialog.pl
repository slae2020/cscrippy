#!/usr/bin/perl -w
use strict;

use constant VERSION => "0.1"; # 2024.09.16

my $is_test_mode = 0; # kw ???
# For returning string while aborting message
my $is_cancel="#x0020";

use lib "/home/stefan/perl5/lib/perl5/";  # ???
use UI::Dialog::Backend::Zenity;
my $d = UI::Dialog::Backend::Zenity->new 
	  ( title => 'Default' ,
		height => 16, width => 65,
		listheight => 5,
		debug => 1*0,
		test_mode => $is_test_mode,
	  );

# Dialog-Variable
my %dialog_var=(
	titles => [undef, undef],
	colli  => [undef, undef, undef ],
	id     => [undef],
	list   => [undef, [ undef , undef ] ]
); 

my $messenger_top_text = "Top Text";


my $dialog_height;
my $dialog_width;

# Change display-size h & w
sub setdisplay {
	$dialog_height = shift;
	$dialog_width = shift;
}

sub resetdisplay {
	$dialog_height = 200;  #350
	$dialog_width = 240;   #250
}


printf "------------ %s (V%s)------------\n",$0,VERSION;

# Error-window & exit with error number; default-value 1 when missing; wait for response except for err==0
sub message_exit {
	my ($txt, $err) = @_;
    $err = 1 unless defined $err;
    $txt =~ s/:\s*/:\n/g;
	
	#my $d = new UI::Dialog::Backend::Zenity ( title => 'Default' );
	if ($err > 0) {
		$d->error( title => $messenger_top_text, text => "$txt ($err)" , width => $dialog_width );
	};
	exit $err;
}

# Notification-window with timout after $2 sec or click
sub message_notification {
	my ($txt, $time) = @_; # ??? time nicht berücksichtigt
	
	my $d = new UI::Dialog::Backend::Zenity ( title => 'Default' );
	if ($time > 0 ) {
		$is_test_mode ? printf "(t)\n $messenger_top_text\n$txt"  
					  : $d->infobox( text => $messenger_top_text."\n".$txt, timeout => $time, height => $dialog_height, width => $dialog_width );
	};
}

# Test and exit-message if not zero
sub message_test_exit {
	my ($result, $txt, $err) = @_; #
	if ($result != 0 ) {
		$is_test_mode ? printf "(t)\n $messenger_top_text\n$txt \"$result?\" $err"
					  : message_exit ("$txt \’$result?\'", $err);
	};
}

# Ask for conformation to continue (==0) else exit with error $2
sub ask_to_continue {
	my ($txt, $err) = @_; #
    $txt =~ s|: |:\n|g;
    $err = -1 unless defined $err;
	my $d = new UI::Dialog::Backend::Zenity ( title => 'Default' );
	if (! $d->question( title => $messenger_top_text, text => "$txt ($err)" , height => $dialog_height, width => $dialog_width ) ) {
		exit $err;
	}
    return 0;
}

###
# Ask for selection out of list; first 3 strings for titles etc; $is_cancel if no choose
sub ask_to_choose {  
	#my (@dialog_texts, @cc, @ll) = @_;
	my %all = @_;
	
	my $dialog_ref = $all{'titles'}; 
    my $cc_ref = $all{'colli'};
    my $list_ref = $all{'list'};
	
	
	die "Missing required keys in the hash" unless exists $all{'titles'} && exists $all{'colli'}; # ??? :)

    my @dialog_texts = @$dialog_ref;
    my @cc = @$cc_ref;
    my @ll = @$list_ref;

	my @answer =
	$d->checklist ( title => $dialog_texts[0], text => $dialog_texts[1], 
					height => $dialog_height, width => $dialog_width,					
					column1 => $cc[0], column2 => $cc[1], column3 => $cc[2],
					list => $list_ref 
				  );
    
    if ( $? != 0 ) { @answer=$is_cancel};
    
    return @answer;
};

###

resetdisplay;
setdisplay (500, 500);



#my @col22=("K11","k22","KK3");

sub set_dialog_item {
	return @_;
};

sub append_dialog_item {
	my @d=@_;
	push @d, '02', ['Watt anders toll', '1'];

	return @d;
};

push @{$dialog_var{titles}}, 'Oben', 'unten', 'daneben';

#pop @{$dialog_var{colli}};pop @{$dialog_var{colli}};pop @{$dialog_var{colli}};
#push @{$dialog_var{colli}}, 'cc1', 'cc2', 'cc3', 'cc$$';

@{$dialog_var{titles}} = set_dialog_item ('Oberhalb', 'Ünten', 'daneben');
@{$dialog_var{colli}} = set_dialog_item ( 'cc1', 'cc2', 'c33', 'cc$$');

@{$dialog_var{list}} = append_dialog_item ( 'ää', ['TTT', '0']) ;
@{$dialog_var{list}} = append_dialog_item ( '22', ['TTT', '1']) ;

#push @{$dialog_var{list}}, 'ää', ['TTT', '0'];
#push @{$dialog_var{list}}, '01', ['Links für tolle', '0'];
#push @{$dialog_var{list}}, '02', ['Watt anders toll', '1'];

my @ja=ask_to_choose (%dialog_var);

printf "weiter\n";
printf ">%s<\n",$_ for @ja;

printf "\n fertig \n";
__END__
ab hier junk

#message_exit ("Hier stop", 22);

my $tt=22-22;
#message_test_exit (2*3, "Hier die Info", 25);

sub printerr { print STDERR "\n".'UI::Dialog : '.join( " ", @_ )."\n"; sleep(1); }
