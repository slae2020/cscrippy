#!/usr/bin/perl -w
####
# license
###
use 5.010;
use strict;
use warnings;

use File::Basename;
use Cwd 'abs_path';
use XML::LibXML;

use Data::Dumper; # nur für test ausgaben

use lib "/home/stefan/prog/bakki/cscrippy/";
use Uupm::Dialog;
use Uupm::Checker;

$is_test_mode = 0;

#::: decl

# Define vars for config-file, not changeable
my %config_elements;
my %config_std;

# XML-DOM
my $dom;

# Define filling for config-xml-file <attribution></attribution>
# [nn]='attribution|standard-value'
#
my @dialog_attr =       qw ( 3_std_texts        dialog_title    dialog_menue        dialog_column_items ); # dialog_config ???

my @dir_attr =          qw ( 4_dir_to_replace   home_dir        storage_dir         standard_dir    remote_dir ); # asubauen mit den anderen ??? const?

my @prog_attr =         qw ( 3_list_elements    list_prog_id    list_prog_strg      std_program );
my @prog_attr_std =     qw ( 3_default_values   |90             |some_program       |prog_to_exec );

my @config_attr =       qw ( 3_list_elements    list_config_id  list_config_strg    editor_program );
my @config_attr_std =   qw ( 3_default_values   |99             |settings           |gedit );

my @attribution = ( # ??? iwie einlesen
    # general
    'version1',
    'version2',
    'lang|de-DE',

    # s.o.
    $dialog_attr[1] , $dialog_attr[2] , $dialog_attr[3] ,
    $dir_attr[1] , $dir_attr[2] , $dir_attr[3] , $dir_attr[4],  

    # list_cfg # progs for setting & main
    'list_head',
    'list_label',
    'list_items',

    $prog_attr[1].$prog_attr_std [1] , $prog_attr[2].$prog_attr_std [2] , $prog_attr[3].$prog_attr_std [3] ,

    $config_attr[1].$config_attr_std [1] , $config_attr[2].$config_attr_std [2] , $config_attr[3].$config_attr_std [3] ,
);

### ::
# Configuration data
my %program_config = (
    program_id     => 'list_prog_id',
    program_string => 'list_prog_strg',
    program_to_exec => 'std_program',
    default_values => {
        program_id     => '|90',
        program_string => '|some_program',
        program_to_exec => '|prog_to_exec'
    }
);

my %config_config = (
    config_id      => 'list_config_id',
    config_string  => 'list_config_strg',
    editor_program => 'editor_program',
    default_values => {
        config_id      => '|99',
        config_string  => '|settings',
        editor_program => '|gedit'
    }
);

# Generate attribution values
my @program_and_config_attribution = (
    $program_config{program_id} . $program_config{default_values}{program_id},
    $program_config{program_string} . $program_config{default_values}{program_string},
    $program_config{program_to_exec} . $program_config{default_values}{program_to_exec},
    $config_config{config_id} . $config_config{default_values}{config_id},
    $config_config{config_string} . $config_config{default_values}{config_string},
    $config_config{editor_program} . $config_config{default_values}{editor_program}
);

#print Dumper @program_and_config_attribution;
print Dumper %program_config;
say "---";
print Dumper values %program_config;
say "###";
#print Dumper @attribution;
print Dumper @prog_attr;

@prog_attr = sort @prog_attr;

for (my $i = 1 ; $i < 4; $i++) {
 my @kaa = sort keys %program_config;
 my $kk = $kaa[$i];
 my $cc = $program_config{$kk};
print "i:$i-->$prog_attr[$i]<-->$cc<\n";
$prog_attr[$i] = $cc;
};
#@prog_attr = values %program_config;
#die;
### ::

# Define parameter of sync-group-elements
# ??? bakki oder offi aus cofg ziehen
my @list_objects;           # n x m array for n list-items with m fields each
my @list_id = ();       	# n list ids 'integers!'
my @list_item = ('_name');  # m fieldnames of the columns
my @list_item_header = ();  # m header for the columns

# Workparameters
our $start_selection; 	# from args ??? array?
#my $start_selection = '02'; 	# for testing
my @selection; 			# from menue (or args)

#:::

# Check if in test mode
print "(t) start\n" if $is_test_mode > 0;

# Init config elements with standard-values
for my $k (0..$#attribution) {
    my ($key, $value) = split(/\|/, $attribution[$k], 2);
    $config_elements{$key} = "";

    # Fill standard-values
    if (defined $value) {
        $config_std{$key} = $value;
        $attribution[$k] = $key; # Update attribution to only have the key part
    } else {
        $config_std{$key} = "";
    }
}

###
## Define general parameters for config-file  ??? durchsehen ob nötig
my %script_metadata_;
# dir       => Directory of the script
# name      => Name of the script without extension
# config    => Predefined config name
my $config_stdname = exists $ENV{MY_CONFIG_FILE} && -e $ENV{MY_CONFIG_FILE} ? $ENV{MY_CONFIG_FILE} : "config.xml"; # ??? Test MY_CON`
($script_metadata_{name},$script_metadata_{dir},$script_metadata_{suffix}) = fileparse(abs_path($0), qw (.sh .pl) );
$script_metadata_{config} = $config_stdname;

print Dumper %script_metadata_ if $is_test_mode > 0;

# Init messenger
set_dialog_item ('titles' , uc($script_metadata_{name})." V".$VERSION, '', '');

# Necessary check ???
if (!defined $config_stdname || $config_stdname eq '') {
    message_exit("Error: Standard path is not set.", 1);
    exit;
}

# Reading configuration file
sub read_configuration {
    my ($config_name) = @_;

    # Check cfg file
#say "1-".$config_name;
    $config_name //= $script_metadata_{config};  # If no argument, use $config_stdname
    Uupm::Checker::ensure_file_existence ($config_name); # ???
    $script_metadata_{config} = $config_name;

#say "2-".$config_name;
#say %script_metadata_;



    # Init XML file
    eval {
        $dom = XML::LibXML->load_xml(location => $script_metadata_{config}, no_blanks => 1*0); # <>0 heisst string ohne space \n etc.
    };
    if ($@) {
        message_exit ("Failed to parse XML file: $@", 255);
    };

# Obertitel / Node
#my $configfile_type = $dom->documentElement;
#say '$configfile_type is a ', ref($configfile_type);
#say '$configfile_type->nodeName is: ', $configfile_type->nodeName;
	$script_metadata_{main_node} = $dom->documentElement->nodeName;

#say "2b-".$config_name;
#print Dumper %script_metadata_;
    # Start
    message_notification( "Start reading '$script_metadata_{main_node}' from\n'$script_metadata_{config}'." , 1 );

    # Get general config values
    for my $k (0..$#attribution) {
        my ($key, $value) = split(/\|/, $attribution[$k], 2);
        my $xml_value = get_xml_element_text($dom, $key);

        if (defined($xml_value)) {
            if ($xml_value ne '' ) {
                $config_elements{$key} = $xml_value;
            } else {
                $config_elements{$key} = $config_std{$key};
            }
        } else {
            message_exit ("Config-error: Unable to retrieve value for key '$key' from the XML document.", 15);
        }
    };

#say "#:cfg:#"; print Dumper %config_elements;

    ## Replace placeholders from config & Ensure the progs are set
    for my $i (0 .. $#attribution) {
        if ($attribution[$i] =~ /dialog_/) {   # ??? suchtetx einlesen
#say "i:$i<->a:$attribution[$i]<----->$config_elements{$attribution[$i]}";
            $config_elements{$attribution[$i]} =~ s/\$version1/$config_elements{version1}/g;
            $config_elements{$attribution[$i]} =~ s/\$version2/$config_elements{version2}/g;
        }
        if ($attribution[$i] =~ /_program/) {          # ??? s.o.
#say "i:$i<->a:$attribution[$i]<----->$config_elements{$attribution[$i]}";
            Uupm::Checker::ensure_program_available($config_elements{$attribution[$i]}); # ???
        }
        if ($attribution[$i] =~ /list_items/) {
            # Fieldnames of the columns
            @list_item = sort split(/\s+/, $config_elements{'list_items'});
            @list_item_header = split(/\s+/, $config_elements{'dialog_column_items'});
             @list_item_header = map { s/$cancel_option/ /g; $_ } @list_item_header;
        }
    }

    # Get identifier from the list elements in config
    @list_id = get_xml_attr_array ($dom , '/'.$config_elements{'list_label'} , 'id' );  # ???  ***/ scheint wichtig
    message_exit ( "The configuration file \n'$script_metadata_{config}'\n is missing data.", 44) if (scalar(@list_id) == 0);
#   message_test_exit ( scalar (find_duplicates(@list_id)) , "The configuration file \n'$script_metadata_{config}'\n contains at least one wrong double identifier." , 45);

    # Get all list elements in config
    # Check fro empty entries & replace placeholder (as defined in config)
    my $i = 0;
    my $num_options = 0;
    foreach my $item (@list_item) {
        foreach my $item_id (@list_id) {
            my $text = get_xml_element_text ($dom, $item, $config_elements{'list_label'}, $item_id );

			my @placeholders = (@dir_attr, @prog_attr);
            foreach my $placeholder (@placeholders) { 
                if ($placeholder eq $dir_attr[1]) { # to replace ~
					my $h = ($ENV{HOME}) ? $ENV{HOME} : $config_elements{$dir_attr[1]}; # take ENV as default or else cfg-value
                    $text =~ s/~/$h/g; 
                } else {
                    $text =~ s/\$$placeholder/$config_elements{$placeholder}/g;
                }
            }
            if (defined $text && length($text) > 0) {
                $text =~ s/$cancel_option/ /g ; # ??? testen ob nnötig
                $text =~ s/\$empty/--/g ; #??? -- weg zu leerzeichen
                $list_objects[$item_id][$i] = $text;
            }
            ++$num_options if ($text ne '' ) ; ;
        }
        ++$i;
    };

    # Check if the number of entries corresponds with id times id-elements (well filled / no lacks in config)
    message_test_exit ( ( $num_options - scalar @list_id * scalar @list_item ) , "The configuration file \n'$script_metadata_{config}'\n is not well-filled with data." , 46);

    # End of reading config
    print "(t) File $script_metadata_{config} cmdNr-->start_selection<\n" if $is_test_mode > 0; #??? 
    message_notification ("Reading configuration file is done!", 1);

    return 0;
};

#read_configuration ('/home/stefan/prog/bakki/cscrippy/config_N1005.xml');
read_configuration ('/home/stefan/prog/bakki/cscrippy/config_offN1006.xml');

# Init Dialogs

# Push check & the item 1,2 into dialog-list
sub add_items_from_config {
    my ($checker, $items, $list_ref ) = @_;

    if (scalar @$items < 2) {
        # Handle the case where there are not enough items
        die "Not enough items";
    }

    #
    my @result = add_list_item( $checker , $config_elements{@$items[1]} , $config_elements{@$items[2]} );
    if (@result) {
        push @$list_ref, @result;
    }

    return 0;
}

# to sub ???
# Set elements for list-dialog
set_dialog_item ( 'titles' ,$config_elements{dialog_title}, $config_elements{dialog_menue} , $config_elements{dialog_column1});
set_dialog_item ( 'columns' , $list_item_header[0] , $list_item_header[1] , $list_item_header[2] );
set_dialog_item ( 'window_size' , 350 , 500 , '' );

# Fill dialog-list
for my $i (0 .. $#list_id) {
    push @{$_dialog_config{list}}, add_list_item ( 0 , $list_id[$i] , $list_objects[$list_id[$i]][0] );
}
add_items_from_config ( 0 , \@prog_attr , \@{$_dialog_config{list}} );
add_items_from_config ( 0 , \@config_attr , \@{$_dialog_config{list}} );

# Checking for no double-ids in the list
my %count;
my @duplicates;
for my $j (@{$_dialog_config{list}}) {
    if (ref($j) ne 'ARRAY') {
        $count{$j}++;
        push @duplicates, $j if $count{$j} > 1;
    }
}
message_test_exit ( scalar (@duplicates) , "The configuration file \n'$script_metadata_{config}'\n contains at least one wrong double identifier." , 45);

# Checking command-number if given & defined
if ($start_selection) {
    if ( @list_id && grep { $_ eq $start_selection } @list_id) {
        @selection = $start_selection;
    } else {
        message_exit ("Error with commandline: Case '$start_selection' not defined." , 66);
    }
}

# Get choice of list-elements
if (! @selection) { 
    eval { @selection = ask_to_choose (%_dialog_config) };
    if ($@) {
        message_exit("Error occurred: $@", 0);
    } elsif ($selection[0] eq $cancel_option) {
        message_exit ("Dialog canceled by user." , 0 ); 
    }
};
if ($is_test_mode > 0) {
    say "(t) The choice was made:";
    say "(t) ".join (' ', @selection);
    for my $i (0 .. $#selection) {
        say "(t) \t$selection[$i]";
        for my $j (0 .. $#list_item) {
            say "$j>".$list_objects[$selection[$i]][$j]."<" if ($selection[$i] < 90) ;
        }
    }
};

# case execute

# .... ???

#: final test ausgabe ::#

 # say "#:cfg:#"; print Dumper %config_elements;

 say "#:items:#";
#te list items  anzeigen
for my $i (0 .. $#list_id) {
    my $st = join('   ', @{$list_objects[$list_id[$i]]});
    say "5-".$list_id[$i]."<->\t\t".$st;
};
say "5a-\t\t".$list_objects[2][0];
say "5a-\t\t".$list_objects[5][0]; # 'double prise id???


say "End:::";


#:::

#message_notification ('Hallo World', 100);
#:::
###


#::: subs ::::::::::::::::::::::#
sub nothimng { };
#::#
# Getting the string @tag
# option: within @attr_tag with attribute (leave empty if not desired)
#
sub get_xml_element_text {
    my ($doc, $tag , $attr_tag, $attr ) = @_;
    my $element_text;

    warn "Error: Invalid XML document object" unless ref($doc) eq 'XML::LibXML::Document';
    warn "Error: Tag name cannot be empty" unless defined($tag) && length($tag) > 0;

    $tag = "/$tag"; $tag =~ s{^/+}{//};
    if (defined $attr_tag) {
        $attr_tag = "/$attr_tag"; $attr_tag =~ s{^/+}{//};
        };

    # Find tag-literal with xpath from @nodes
    my $xpath = $attr_tag ? '*'.$attr_tag.'[@id="'.$attr.'"]'.$tag : "*$tag";
    #say "test:$tag<-->$xpath" if testxversuion ????
    my @nodes = $doc->findnodes($xpath);
    if (@nodes) {
        $element_text = join('', map { $_->to_literal() } @nodes);
    } else {
        warn "Error: No nodes found for tag '$xpath'";
    }

    return $element_text;
}

# Get the array @tag of all attributes
#
#
sub get_xml_attr_array {
    my ($doc, $tag, $attr) = @_;

    warn "Error: Invalid XML document object" unless ref($doc) eq 'XML::LibXML::Document';
    warn "Error: Tag name cannot be empty" unless defined($tag) && length($tag) > 0;
    warn "Error: Attribute name cannot be empty" unless defined($attr) && length($attr) > 0;

    # Find nodes with attributes from $doc
    my $xpath_strg = "*/$tag"."/\@$attr"; #??? / checking!
    my @nodes = $doc->findnodes($xpath_strg);

    # Extract literal values from @nodes
    my @literals = map { $_->to_literal } @nodes;

    # Filter @literals to only include integer values
    my @integers = grep { $_ =~ /^[+-]?\d+$/ } @literals;

    # Return the array of integer values
    return @integers;
}


__END__
#### junk
# Remove newline characters from command results
chomp($script_metadata_{dir}); ???
chomp($script_metadata_{name});

# Uncomment to print the hashes
 use Data::Dumper;
 #print Dumper(\%config_elements);
 #print Dumper(\%config_std);

 print Dumper(\%script_metadata_);
 #print "Messenger Top Text: $messenger_top_text\n";


$is_test_mode = 0;

@{$_dialog_config{titles}} = set_dialog_item ('titles' , 'Program DoIt', 'Choose your items','#');

printf "####\n";
foreach my $key (keys %Uupm::Dialog::_dialog_config) {
    printf "$key is >". join ('/',@{ $Uupm::Dialog::_dialog_config{$key} })."<\n";
};

#&Uupm::Dialog::message_exit ("Hääh", 33);

message_exit ("Und der??", 34);
__END__

#te list items  anzeigen
for my $i (0 .. $#list_id) {
    my $st = join('   ', @{$list_objects[$list_id[$i]]});
    say "5-".$list_id[$i]."<->\t\t".$st;
};
 ## say "5a-".$list_objects[0][1];

##te
if (find_duplicates(@list_id)) {
    my $sc = scalar (find_duplicates(@list_id));
    message_test_exit ( $sc , "The configuration file \n'$script_metadata_{config}'\n contains at least one wrong double identifier." , 45);
    say "num:$sc<";
    } else {
        say "ok!";
    }

###
# Configuration data
my %program_config = (
    program_id     => 'list_prog_id',
    program_string => 'list_prog_strg',
    program_to_exec => 'std_program',
    default_values => {
        program_id     => '|90',
        program_string => '|some_program',
        program_to_exec => '|prog_to_exec'
    }
);

my %config_config = (
    config_id      => 'list_config_id',
    config_string  => 'list_config_strg',
    editor_program => 'editor_program',
    default_values => {
        config_id      => '|99',
        config_string  => '|settings',
        editor_program => '|gedit'
    }
);

# Generate attribution values
my @program_and_config_attribution = (
    $program_config{program_id} . $program_config{default_values}{program_id},
    $program_config{program_string} . $program_config{default_values}{program_string},
    $program_config{program_to_exec} . $program_config{default_values}{program_to_exec},
    $config_config{config_id} . $config_config{default_values}{config_id},
    $config_config{config_string} . $config_config{default_values}{config_string},
    $config_config{editor_program} . $config_config{default_values}{editor_program}
);

#push @{$_dialog_config{list}}, add_list_item (0,$config_elements{list_prog_id},$config_elements{list_prog_strg});
#push @{$_dialog_config{list}}, add_list_item (0,$config_elements{list_config_id},$config_elements{list_config_strg});
