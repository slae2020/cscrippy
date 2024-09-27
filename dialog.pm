#!/usr/bin/perl -w
use strict;

use constant VERSION => "0.1"; # 2024.09.16

use Scalar::Util qw(looks_like_number);

my $is_test_mode = 0; # kw ???
# for returning string while aborting message
my $is_cancel="#x0020";
# standard titles
my @messenger_text = ("Title-Text", "textline");

use lib "/home/stefan/perl5/lib/perl5/";  # ???
use UI::Dialog::Backend::Zenity;
my $d = UI::Dialog::Backend::Zenity->new 
	  ( title => $messenger_text[0],
		text =>  $messenger_text[1],
		height => 16, width => 65,
		listheight => 5,
		debug => 1*0,
		test_mode => $is_test_mode,
	  );

# Dialog-Variable
my %dialog_var;
my @dialo = qw (titles colli id list); # ???
#=(
	#titles => [undef, undef],
	#colli  => [undef, undef, undef ],
	#id     => [undef],
	##list   => [undef, [ undef , undef ] ]
	#list    => ['', [ '' , '' ] ],
#); 



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

sub set_messenger_text {
	@messenger_text = @_;
}

printf "------------ %s (V%s)------------\n",$0,VERSION;

# Error-window & exit with error number; default-value 1 when missing; wait for response except for err==0
sub message_exit {
	my ($txt, $err) = @_;
    $err = 1 unless defined $err;
    $txt =~ s/:\s*/:\n/g;
	
	#my $d = new UI::Dialog::Backend::Zenity ( title => 'Default' );
	if ($err > 0) {
		$d->error( title => $messenger_text[0], text => "$txt ($err)" , width => $dialog_width );
	};
	exit $err;
}

# Notification-window with timout after $2 sec or click
sub message_notification {
	my ($txt, $time) = @_; # ??? time nicht berücksichtigt
printf $time."\n";
	#my $d = new UI::Dialog::Backend::Zenity ( title => 'Default' );
	if ($time > 0 ) {
		$is_test_mode ? printf "(t)\n $messenger_text[0]\n$txt"  
					  : $d->infobox( title => $messenger_text[0], text => $messenger_text[1]."\n".$txt, timeout => $time, height => $dialog_height, width => $dialog_width );
	};
}

# Test and exit-message if not zero
sub message_test_exit {
	my ($result, $txt, $err) = @_; #
	if ($result != 0 ) {
		$is_test_mode ? printf "(t)\n $messenger_text[0]\n$txt \"$result?\" $err"
					  : message_exit ("$txt \’$result?\'", $err);
	};
}

# Ask for conformation to continue (==0) else exit with error $2
sub ask_to_continue {
	my ($txt, $err) = @_; #
    $txt =~ s|: |:\n|g;
    $err = -1 unless defined $err;
	#my $d = new UI::Dialog::Backend::Zenity ( title => 'Default' );
	if (! $d->question( title => $messenger_text[0], text => "$txt ($err)" , height => $dialog_height, width => $dialog_width ) ) {
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

sub set_dialog_item {
	return @_;
};

@{$dialog_var{titles}} = set_dialog_item ('Program DoIt', 'Choose your items');
@{$dialog_var{colli}} = set_dialog_item ( '[@]', 'Id', 'Item');

sub new_list_item {
	my ($a,$b,$c) = @_;
	my @d;
	
	# $b max length ==5
	if (length $b > 5) {die "length(list-id):$b >5"};
	# $a muss int sein sonst 0
	if (! looks_like_number ($a) ) { $a=0 };

	# order following to UI::Dialog
	push @d, $b, [ $c , $a ];
	return @d;
};

push @{$dialog_var{list}}, new_list_item (1,'01','first choice');
push @{$dialog_var{list}}, new_list_item (0,'02','secondbest');

#my @answer=ask_to_choose (%dialog_var);
#printf ">%s<\n",$_ for @answer;


message_notification ("Reading list!",10);
#message_notification (":done:", 0);
#printf "\n :done: \n";
__END__

examples
#
resetdisplay;
set_messenger_text ("New Title", "new line");

#
message_exit ("Unknown Error", 22);

#
message_notification (":done:", 0);
message_notification ("Reading list!",10);

#
message_test_exit ( 3* 4, "Wrong result:", 33);

#
@{$dialog_var{titles}} = set_dialog_item ('Program DoIt', 'Choose your items');
@{$dialog_var{colli}} = set_dialog_item ( '[@]', 'Id', 'Item');
push @{$dialog_var{list}}, new_list_item (1,'01','first choice');
push @{$dialog_var{list}}, new_list_item (0,'02','secondbest');

my @answer=ask_to_choose (%dialog_var);

my @answer=ask_to_choose (%dialog_var);
printf ">%s<\n",$_ for @answer;

printf "\n :done: \n";




ab hier junk

#

my $tt=22-22;
#message_test_exit (2*3, "Hier die Info", 25);

sub printerr { print STDERR "\n".'UI::Dialog : '.join( " ", @_ )."\n"; sleep(1); }
