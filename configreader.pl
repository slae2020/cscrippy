#!/usr/bin/perl -w
####
# license
###
use 5.010;
use strict;
use warnings;
no warnings 'experimental::smartmatch';

use File::Basename;
use Cwd 'abs_path';
use XML::LibXML;
use Getopt::Long qw(GetOptions :config no_ignore_case );

use Data::Dumper; # nur für test ausgaben

use lib "/home/stefan/prog/bakki/cscrippy/";
use Uupm::Dialog;
use Uupm::Checker;

$VERSION = "1.7d"; # 2024-10-07

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#: Reader for xml-files (configuration-file)
#:     - choose in list-dialog
#:     - use commandline for direct execution
#: uses Zenity for dialogs

#::: declarations ::::::::::::::#
#: Define general parameters for this script
my $suffix = '.pl'; 
my %_script_metadata = (
	version 				=> $VERSION,
	LANG	=> $ENV{LANG},
	# path & name of the script
	script_dir => dirname (abs_path($0)),
	script_name => basename (abs_path($0) , $suffix),   
    script_suffix  => $suffix ,
    # name of the xml-file to parse
	configfile 		=> '',	
);
#: Define vars for config-file, not changeable
my %config_elements;
my %config_std;

#: XML-DOM
my $dom;

#: Define tag-lists as filling for config-xml-file <attribution></attribution>
# DEF_ for to be ignored by get-xml-value
# undef leads to undefined value
# tbd to be committed
#          defines general parameter
my @general_taglist 	=	qw ( DEF_general	cscrippy_name	versionNr			versionTxt		lang ); 
my @general_tagdefault	=	qw ( undef			some_name		undef				undef			undef			);
# defines texts for dialogs
my @dialog_taglist 		=	qw ( DEF_dialogtxts dialog_title    dialog_menue        dialog_column_items 			); 
my @dialog_tagdefault 	=   qw ( undef			cscrippy		undef				[-]-id-list-items );
# defines paths for placeholders
my @dir_taglist 		=	qw ( DEF_dir_subst	home_dir        storage_dir         standard_dir    	remote_dir 	); 
my @dir_tagdefault 		=   qw ( undef   		undef        	undef         		undef    			undef 		);
# defines the xml-construct of list items
my @list_taglist		= 	qw ( DEF_listitems 	list_head		list_label			list_item_tags		list_item_exec_order	); 
my @list_tagdefault		= 	qw ( undef		 	entries			single-entry		_name-tag1-tag2		1-2-3			); 
# defines as list-item standard-prog for execution
my @prog_taglist 		= 	qw ( DEF_stdprog	list_prog_id    list_prog_strg      std_program ); 
my @prog_default 		= 	qw ( undef			90    			prog_to_exec      	command-to-exec );
# defines as list-item program for editing the configfile
my @config_taglist		= 	qw ( DEF_cfgprog	list_config_id  list_config_strg	editor_program ); 
my @config_default		= 	qw ( undef			99  			settings    		undef );

# full lists
my @all_taglist = 		(@general_taglist , 	@dialog_taglist , 	@dir_taglist , 		@list_taglist , 	@prog_taglist , 	@config_taglist);
my @all_tagdefault = 	(@general_tagdefault , 	@dialog_tagdefault, @dir_tagdefault , 	@list_tagdefault , 	@prog_default , 	@config_default);

# Define parameter of sync-group-elements
my @list_item_line;           	# n x m array for n item-lines with m columns each
my @list_id = ();       		# n ids ('integers!') for the lines
my @list_item_name = ('_name');	# m fieldnames (tags) for every line

#: hash with strings to replace & their replacer
my %string_map = (
	cancel_option => $cancel_option, # left string, rigth a value!
	nb_space => $nb_space, 
	empty => ' ',
	xml_file_name => ' foobar',
	);

# Workparameters 
my %shell_commands = (
	commandline => [], 					# items via args
	selection => [],					# items from cheklist
	execution_list => [] ,				# as in xml-file, for the execution at the end
	execution_order => [ 4 , 1 , 2 ] ,	# as in xml-file, scheme for the order of list-fields in order to execute
	extract_all => 0					# >0 for grepping full xml-file
);

#::: main ::::::::::::::::::::::#
#::: reading args from commandline
my $usage_exit = 0;
if (@ARGV) {
		sub handler {
			my ($opt_name , $opt_value) = @_;
			# Special-entry in string_map with higher priority
			$string_map{$config_taglist[3]} = "\$ALL$opt_value";
		}
	GetOptions (
		'c=s' 		=> \$_script_metadata{configfile}, # the NECESSARY XML-file
		'g:s' 		=> \&handler, # other edit-prog (with other file-name possible)
		'e'			=> sub { $shell_commands{extract_all} = 1 }, 	## ??? mit ec bundling? - extrakt config file mit -n nur teil?
		'n:i{1,3}' 	=> \@{$shell_commands{commandline}},
		't|testmode'=> sub { $is_test_mode =  1 }, # 'normal' test-mode
		'v|verbose'	=> sub { $is_test_mode = 20}, 	# verbose, show all infos
		'q|quiet'   => sub { $is_silent_mode = 1; say "(t) psst." if $is_test_mode; $is_test_mode = 0 }, # quiet, no messages 
		'h|help|?' 	=> \$usage_exit,
	) or 
	$usage_exit = 1;
	if ($usage_exit || ! $_script_metadata{configfile} ) {
		$error_message = "Usage: $0 $VERSION [-g gEditor] [-e|ec] [-n id max 3] [-t|v|q] [-h] -c Konfiguration.xml \n";
		message_exit ($error_message , 02)
	}
}
# Set the script configuration file if not already set
#if ( !exists $_script_metadata{configfile} || $_script_metadata{configfile} eq '' ) {
	#$error_message = "No XML file defined: '$_script_metadata{configfile}'";
	#message_exit ($error_message , 255);# obsolete...
#} else {
	$string_map{xml_file_name} = $_script_metadata{configfile}; 
	if ($is_test_mode && ! $is_silent_mode ) {
		print "(t) start with '$_script_metadata{configfile}'\n"
	}
#}

#system ('zenity --notification  --height 400 --width 400 --window-icon="info" --text="messenger_top_text\ntxt" --timeout=50 ');

#::: init doc for LibXML
eval {
	$dom = XML::LibXML->load_xml(
							location => $_script_metadata{configfile}, 
							no_blanks => 1*0 # <>0 heisst string ohne space \n etc.
							); 
	$_script_metadata{config_main_node} = $dom->documentElement->nodeName; 
};
if ($@) {
	$error_message = "Failed to parse XML file: $@";
    message_exit ($error_message , 255);
} else { # init window-titles
	set_dialog_item ('titles' , uc($_script_metadata{script_name})." V".$VERSION , '' , '' );
}

#::: Start
$error_message =  "Start reading '$_script_metadata{config_main_node}' from\n'$_script_metadata{configfile}'.";
message_notification ($error_message , 2);

# Get general config values
for my $tag_index (0..$#all_taglist) {
	my $found_xml_value;
	if ( $all_taglist[$tag_index] !~ /^DEF_/ ) { # exclude DEF_something
		$found_xml_value = get_xml_text_by_tag( $dom, $all_taglist[$tag_index] ) 
	}
	if ( defined $found_xml_value && $found_xml_value ne '' ) { # string not empty
		$config_elements{$all_taglist[$tag_index]} = $found_xml_value;
    } elsif ($all_tagdefault[$tag_index] =~ /^undef$/) { # undef if string is 'undef' 
		$config_elements{$all_taglist[$tag_index]} = undef;
    } else { # or set to default
		$config_elements{$all_taglist[$tag_index]} = $all_tagdefault[$tag_index];
	}
}

## Replace placeholders from config & Ensure the progs are set
foreach my $placeholder (@general_taglist , @dir_taglist)  { 
	$string_map{$placeholder} = $config_elements{$placeholder} if $config_elements{$placeholder};
}
foreach my $tag (@dialog_taglist , @prog_taglist , @config_taglist) {
	$config_elements{$tag}  = substitute_with_map ( $config_elements{$tag}, $tag , %string_map ); 
	if ( $tag ~~ @dialog_taglist ) { # replace string from general-tags into dialog-items
		$config_elements{$tag} =~ s/\\n//g if $config_elements{$tag}; 
	}		
	if ( $tag =~ /_program/ ) { # if a program is given in the config then test it
        ensure_program_available($config_elements{$tag}, ' ' ) if $config_elements{$tag};
        $string_map{$tag} = $config_elements{$tag} if $config_elements{$tag}; # add then prog to hash string_map
    }
}

## Pass the splitted config-values (file) to list-configs (program)
if ($list_taglist[3]) { # name of the tags
	$config_elements{$list_taglist[3]} =~ s/^\s+|\s+$//g;
	@list_item_name = split( /\s+/ , $config_elements{$list_taglist[3]} ); # space-separated
}
if ($list_taglist[4]) { # order of the tag to be executed
	$config_elements{$list_taglist[4]} =~ s/^\s+|\s+$//g;
	@{$shell_commands{execution_order}} = split( /\s+/ , $config_elements{$list_taglist[4]} ); # space-separated
	@{$shell_commands{execution_order}} = grep { $_ =~ /^[+-]?\d+$/ } @{$shell_commands{execution_order}}; # +-integer only
	foreach my $i (@{$shell_commands{execution_order}}) {
		if ($i > $#list_item_name || $i <= 0) { # must be in range
			$error_message = "Config-Error: entry for execution order is wrong ($i).";
			message_exit ($error_message , 51)
		}
	}
}

# Get identifier from the list elements in config (keep '/')
@list_id = get_xml_array_by_attribute ($dom , '/'.$config_elements{'list_label'} , 'id' ); 
if (scalar(@list_id) == 0) {
	$error_message = "The configuration file \n'$_script_metadata{configfile}'\n is missing data.";
	message_exit ($error_message , 44) 
}

# Get all list elements in config
my $item_field = 0;
my $num_options = 0;

foreach my $item (@list_item_name) {
    foreach my $item_id (@list_id) {
		my $found_xml_value;
        $found_xml_value = get_xml_text_by_tag ($dom, $item, $config_elements{'list_label'}, $item_id );
        if ($found_xml_value) { # clean/replace as defined
			$found_xml_value = substitute_with_map ($found_xml_value , "" , %string_map ); 
            $list_item_line[$item_id][$item_field] = $found_xml_value; # put into line
        }
        ++$num_options if ($found_xml_value ne '' ) ;
    }
    ++$item_field; # tag for tag
};

# Check if the number of entries corresponds with id times id-elements (well filled / no lacks in config)
my $count = ( $num_options - scalar @list_id * scalar @list_item_name );
$error_message = "The configuration file \n'$_script_metadata{configfile}'\n is not well-filled with data or tags are empty.";
message_test_exit ($count , $error_message , 46);

# End of reading config
$error_message = "Reading configuration file is done!";
#message_notification ($error_message , 1); ???

## Init Dialogs with config-values 
# Set elements for list-dialog
	$config_elements{dialog_menue} .= "\n\t\t(processed with '$_script_metadata{script_name} $_script_metadata{version}')"; 
set_dialog_item ( 'titles' , $config_elements{dialog_title}, $config_elements{dialog_menue}, $config_elements{dialog_column1}); 
	my @list_column_name;  # take the xml-value, split into 3, then replace placeholder for splitting with ' '
	@list_column_name = split(/\s+/, $config_elements{$dialog_taglist[3]}) if $dialog_taglist[3];
	@list_column_name = map { s/$nb_space/ /g; $_ } @list_column_name; 
set_dialog_item ( 'columns' , @list_column_name );
set_dialog_item ( 'window_size' , 350 , 500 , '' );

# Set elements for the listed items (for checklist)
add_items_from_config ( 0 , \@prog_taglist , \@{$_dialog_config{list}} );
add_items_from_config ( 0 , \@config_taglist , \@{$_dialog_config{list}} );
foreach my $i (0 .. $#list_id) {
	push @{$_dialog_config{list}}, add_list_item ( 0 , $list_id[$i] , $list_item_line[$list_id[$i]][0] );
}

# Check for double entries
my @duplicates = find_array_duplicates (@{$_dialog_config{list}});
$error_message = "The configuration file \n'$_script_metadata{configfile}'\n contains at least one wrong double identifier.";
message_test_exit ( scalar (@duplicates) , $error_message ,  45);

# Sort & define complet-list	
@{$_dialog_config{list}} = sort_pairwise ( @{$_dialog_config{list}});;
$_dialog_config{complete_list} = join (' ',  grep { ref($_) ne 'ARRAY' } @{$_dialog_config{list}} ); 
# Checking items from command-line are given & defined
foreach my $cmd_item ( @{$shell_commands{commandline}} ) {
	if ( $_dialog_config{complete_list} !~ $cmd_item ) {
		$error_message = "Error with commandline: Case '$cmd_item' not defined.";
		message_exit ($error_message , 66) 
	}
}

#::: Main-case: extract OR exec cmd-lines OR ask with checklist
if ($shell_commands{extract_all}) { 
	show_all_items ();
	$error_message = "Extraction done, program will finish.";
	message_exit ($error_message , 0)
} elsif (scalar @{$shell_commands{commandline}} == 0 ) { # ask-for-selection
    eval { @{$shell_commands{selection}} = ask_to_choose (%_dialog_config) };
    if ($@) {
		$error_message = "Error occurred: $@";
        message_exit ($error_message , 0)

    } elsif ($shell_commands{selection}[0] eq $cancel_option) {
		$error_message = "Dialog canceled by user.";
        message_exit ($error_message , 0)
    }
} else  { # take from comd-line
	@{$shell_commands{selection}} = @{$shell_commands{commandline}}
};

#::: Execution
# grepping all selected program-name into list-of-programs to be executed
my $limit = (scalar @{$shell_commands{selection}} - 1); # naja
foreach my $case (0 .. $limit) {
    my $selected_case = @{$shell_commands{selection}}[$case];
    if ( join (' ',@list_id ) =~ $selected_case ) { # if selected in list of ids (imprtant for values from commandline)
        my $program_name = "";
        foreach my $schema_item (@{$shell_commands{execution_order}}) {
            $program_name .= $list_item_line[$selected_case][$schema_item];
        };
        push @{$shell_commands{execution_list}} , $program_name ;
    } elsif ( $_dialog_config{complete_list} =~ /$selected_case/) { # idem for programs from xml-file
        push @{$shell_commands{execution_list}} , extract_progname ($selected_case , '_program' , '_id', @prog_taglist);
        push @{$shell_commands{execution_list}} , extract_progname ($selected_case , '_program' , '_id', @config_taglist)
    } else {
        $error_message = "Config-Error: selected item '$selected_case' not found.";
        message_exit ($error_message , 255)
    }
}
if ( $is_test_mode > 0 ) { 
	say "\n(t) The choice was made:"; 
	say "(t) ".join (' ', @{$shell_commands{selection}}); 
	say join ("\n", @{$shell_commands{execution_list}}) 
}

# EXEC
if (@{$shell_commands{execution_list}} &&  1 == 2 ) {
    for my $cmd_to_execute (@{$shell_commands{execution_list}}) {
        my $pid = fork();
        if ($pid == 0) {
            # Child process
            exec($cmd_to_execute);
            exit(1);
        } elsif ($pid > 0) {
            # Parent process
            waitpid($pid, 0);
            if ($? != 0) {
                warn("Failed to execute file: $?");
            }
        } else {
            warn("Failed to fork: $!");
        }
    }
}

#: final test ausgabe ::#
if ( $is_test_mode > 10 ) {
	show_all_items ();
}

#::: subs ::::::::::::::::::::::#
sub nothimng { };
#::#

# Checking for no double-ids in the list
sub find_array_duplicates {
	my @array = @_;
	my %count;
	my @dupl;

	for my $j (@array) {
		if (ref($j) ne 'ARRAY') {
			$count{$j}++;
			push @dupl, $j if $count{$j} > 1;
		}
	}
	return @dupl;
}

# Replace in string substr using global hash string_map
# working-strg is the string to be changed
# key-tag is for (string_map{key-tag} = > replacer ) entries in string_map
sub substitute_with_map { 
	my ($working_strg , $key_tag, %strg_map ) = @_;
	
	if ($working_strg) {
		foreach my $keyword (keys %strg_map ) {	
			my $value = $strg_map{$keyword};
			if ( $is_test_mode > 10 && $working_strg =~ /\$$keyword/ ) { # testmode
				say "Repl '$value' for '\$$keyword' in ->".$working_strg;
			};
			$working_strg =~ s/\$$keyword/$value/g ;
		
			if ( $keyword eq $key_tag ) {
				if ( $value =~ /^\$ALL/ ) { # $ALL at the beginning replaces complete string 
				$working_strg = substr ($value, 4) ;
				}
			}
		
		}
		if ($working_strg =~ /^\s*~/) { # starts with ~
			if ($ENV{HOME}) {
				$working_strg =~ s/~/$ENV{HOME}/g;
			} else {
				warn "'Error:ENV(HOME} not found.'";
			}
		}

	}
				
	return $working_strg;
};

# Getting the array with xpath
# with error handling
#
sub get_array_with_xpath {
	my ($xml_document, $xpath_expression) = @_;
	my @nodes;
    my @text_values;
	
	# Find nodes with attributes from $xdoc
	eval { @nodes = $xml_document->findnodes($xpath_expression) };
    if ($@) {
		message_exit ("Error while searching element in xml-file\n$@" , 255)
    }
	if (@nodes) {	
	# Extract literal values from @nodes
		@text_values = map { $_->to_literal } @nodes;
	} else {
        message_exit ("Error: No nodes found for tag '$xpath_expression'" , 255 )
    }
	
	return @text_values;
}

# Getting the string @tag
# option: within @attr_tag with attribute (leave empty if not desired)
#
sub get_xml_text_by_tag {
    my ($doc, $tag , $attr_tag, $attr ) = @_;
    
    warn "Error: Invalid XML document object" unless ref($doc) eq 'XML::LibXML::Document';
    warn "Error: Tag name cannot be empty" unless defined($tag) && length($tag) > 0;

    $tag = "/$tag"; $tag =~ s{^/+}{//};
    if (defined $attr_tag) {
        $attr_tag = "/$attr_tag"; $attr_tag =~ s{^/+}{//};
        };
    my $xpath = $attr_tag ? '*'.$attr_tag.'[@id="'.$attr.'"]'.$tag : "*$tag";
    my @element_text = get_array_with_xpath ($doc, $xpath );

    @element_text = ( join (' ', @element_text) ); # all into [0]

    return $element_text[0];
}

# Get the array @tag of all attributes
#
#
sub get_xml_array_by_attribute {
    my ($doc, $tag, $attr) = @_;

    warn "Error: Invalid XML document object" unless ref($doc) eq 'XML::LibXML::Document';
    warn "Error: Tag name cannot be empty ($tag)" unless defined($tag) && length($tag) > 0;
    warn "Error: Attribute name cannot be empty" unless defined($attr) && length($attr) > 0;

    my $xpath = "*/$tag"."/\@$attr"; # @nnn for attribute
	my @integers = get_array_with_xpath ($doc, $xpath );
	
    # Filter @literals to only include integer values
    @integers = grep { $_ =~ /^[+-]?\d+$/ } @integers;

    return @integers;
}

# Push check & the item 1,2 into dialog-list 
sub add_items_from_config {
    my ($checker, $items, $list_ref ) = @_;
    if (scalar @$items < 2) { 
		die "Not enough items to add from config";
    }
    #
    my @result = add_list_item( 
					$checker , # 0 for off. >=1 for on
					$config_elements{@$items[1]} , # id (integer)
					$config_elements{@$items[2]}   # that's an array !
				 );
    if (@result) {
        push @$list_ref, @result;
    }
    return 0;
}

# Function to sort the array pairwise
sub sort_pairwise {
    my @array = @_;

    # Extract odd-indexed elements (1st, 3rd, 5th, etc.)
    my @odd_elements = @array[0..$#array/2*2];  # Get elements at indices 0, 2, 4, ...
    
    # Create pairs from the odd-indexed elements
    my @pairs;
    for (my $i = 0; $i < @odd_elements; $i += 2) {
        push @pairs, [$odd_elements[$i], $odd_elements[$i+1]] if defined $odd_elements[$i+1];
    }
    
    # Sort pairs
    my @sorted_pairs = sort { $a->[0] <=> $b->[0] } @pairs;

    # Flatten the sorted pairs back into an array
    my @sorted_array;
    foreach my $pair (@sorted_pairs) {
        push @sorted_array, @$pair;
    }

    return @sorted_array;
}

# Get the prog-name from item
sub extract_progname { # mit Umstellung auf oo vielelicht weg
	my ($selector , $substr_tag , $substr_attrib , @tag_list) = @_;
#	my ($substr_tag1 , $substr_attrib1 ) = ('_program' , '_id' );
#    my ( $selector, $tag_pattern, $attribute_pattern, @tag_list) = @_;
	my @program_name;

	for my $j (@tag_list) {
		if ($config_elements{$j} && $j =~ /$substr_attrib/ && $config_elements{$j} eq $selector ) {
			for my $k (@tag_list) {
				if  ( $k =~ /$substr_tag/) {
#say $j."::$k<===>$config_elements{$j}###".$config_elements{$k};
					push @program_name , $config_elements{$k};
				}
			}
		}
	}

	return @program_name;
}

# for debugging
sub show_all_items {
# use Dmper ??? in final version
	say "\nEingelesene Daten\n\t'$_script_metadata{configfile}'";
	
	say "\n\tALL DEFAULT tags";
	for my $run (0..$#all_taglist) { 
		say "tag_$run :$all_taglist[$run]:    \t:$all_tagdefault[$run]:";
	}

	say "\n\tLIST ids  (count:$#list_id+)";
	print Dumper \@list_id;
	say "\n\tFIELDS per id";
	print Dumper @list_item_name;
	
	say ("\n\tFULL list (replaced strings)");
	for my $i (0 .. $#list_id) {
		my $st = join(":\t    :", @{$list_item_line[$list_id[$i]]});
		say "  #".$list_id[$i]."<->".$st;
	}

	say "\n\tSTRING MAP";
	print Dumper %string_map;

	say "\nCONFIG\n\tMETAs";
	print Dumper %_script_metadata;
	say "#\n\tELEMENTS";
	print Dumper %config_elements;
	
	say "##\n\tDIALOG configs";
	print Dumper %_dialog_config;
	
	say "###\n\tSHELL CMDS";
	print Dumper %shell_commands;
	
	say "End:::";
}

__END__


#### junk 
