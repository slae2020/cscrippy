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

use Data::Dumper; # nur für test ausgaben

use lib "/home/stefan/prog/bakki/cscrippy/";
use Uupm::Dialog;
use Uupm::Checker;

$is_test_mode = 01;

$VERSION = "1.7"; # 2024-10-07

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#: Reader for xml-files (configuration-file)
#:     - choose in list-dialog
#:     - use commandline for direct execution
#: uses Zenity for dialogs

#::: declarations ::::::::::::::#

## Define general parameters for config-file  ??? durchsehen ob nötig
# script_dir       			=> Directory of the script
# script_name      			=> Name of the script without extension
# script_configfile			=> Name of the used config-file
# default_config_filename 	=> Predefined config-name 
my %_script_metadata = (
	version => $VERSION,
	default_config_filename => 'config.xml',
);
# Retrieve the script name, directory, and suffix
eval {
    ($_script_metadata{script_name},$_script_metadata{script_dir},$_script_metadata{script_suffix}) = fileparse(abs_path($0), qw (.sh .pl) );
    $_script_metadata{LANG} = $ENV{LANG};
};
if ($@) {
    # Handle the error from fileparse() or abs_path()
    warn "Error retrieving script metadata: $@";
    # Set default values or exit the script
    $_script_metadata{script_name} = 'unknown';
    $_script_metadata{script_dir} = '.';
    $_script_metadata{script_suffix} = '';
}
# Set the script configuration file if not already set
if ( !exists $_script_metadata{script_configfile} || $_script_metadata{script_configfile} eq '' ) {
	$_script_metadata{script_configfile} = $_script_metadata{default_config_filename};
} 

# Define vars for config-file, not changeable
my %config_elements;
my %config_std;

# XML-DOM
my $dom;

# Define tag-lists as filling for config-xml-file <attribution></attribution>
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
my @list_column_name = ();  	# m header for the columns
my @list_item_exec = (1,2,3); 	# scheme for the order of list-fields in order to execute

# Replacers ??? Zusaetzliche in xml-file angeben lassen können?
my %_rep = (
	cancel_option => ' ',
	empty => ' ',
	xml_file_name => ' foobar',
	);
# Workparameters
my $start_selection; 	# from args ??? array?
#my $start_selection = '02'; 	# for testing
my @selection; 			# from menue (or args)
my @list_of_programs_to_execute; # for the execution at the end


#::: main ::::::::::::::::::::::#
# Check if in test mode
print "(t) start\n" if $is_test_mode;

# Init messenger#say "\n\n#::::::::::#";
set_dialog_item ('titles' , uc($_script_metadata{script_name})." V".$VERSION , '' , '' );

# Reading configuration file
sub read_configuration {
    my ($config_name) = @_;

    # Check cfg file
    $config_name //= $_script_metadata{default_config_filename};  # If no argument, use $default-config-fname
    $_script_metadata{script_configfile} = $config_name if ensure_file_existence ($config_name);

    # Init XML file
    eval {
        $dom = XML::LibXML->load_xml(location => $_script_metadata{script_configfile}, no_blanks => 1*0); # <>0 heisst string ohne space \n etc.
    };
    if ($@) {
        message_exit ("Failed to parse XML file: $@", 255);
    }

	# Main node reflects type of xml-data
	$_script_metadata{config_main_node} = $dom->documentElement->nodeName;
	$_rep{xml_file_name} = $_script_metadata{script_configfile}; # ???? unsauber hier an dieser sSteelle

    # Start
    message_notification( "Start reading '$_script_metadata{config_main_node}' from\n'$_script_metadata{script_configfile}'." , 1 );

    # Get general config values
    for my $tag_index (0..$#all_taglist) {
		my $found_xml_value;
		$found_xml_value = get_xml_text_by_tag( $dom, $all_taglist[$tag_index] ) if ! ( $all_taglist[$tag_index] =~ /^DEF_/ ); # exclude DEF_something
		if ($found_xml_value) {
			if ($found_xml_value ne '' ) { # string not empty
                $config_elements{$all_taglist[$tag_index]} = $found_xml_value;
            } elsif ($all_tagdefault[$tag_index] =~ /^undef$/) { # undef if string is 'undef' 
                $config_elements{$all_taglist[$tag_index]} = undef;
            } else { # or set to default
				$config_elements{$all_taglist[$tag_index]} = $all_tagdefault[$tag_index];
			}
        }
	};

    ## Replace placeholders from config & Ensure the progs are set
    my @placeholder_list = (@general_taglist , @dir_taglist); # filling hash _rep with new data
    foreach my $placeholder (@placeholder_list)  { 
		$_rep{$placeholder} = $config_elements{$placeholder} if $config_elements{$placeholder};
	}
	my @tag_list = (@dialog_taglist , @prog_taglist , @config_taglist);
    foreach my $tag (@tag_list) {
		$config_elements{$tag}  = replace_strg ( $config_elements{$tag} ); 
		if ( $tag ~~ @dialog_taglist ) { # replaces string from general-tags into dialog-items
			$config_elements{$tag} =~ s/\\n//g if defined $config_elements{$tag}; 
		}
		if ( $tag =~ /_program/ ) { # if a program is given in the config then test it
            ensure_program_available($config_elements{$tag}, ' ' ) if $config_elements{$tag};
            $_rep{$tag} = $config_elements{$tag} if $config_elements{$tag}; # add then prog to hash _rep
        }
	}

	## Pass the splitted config-values (file) to list-configs (program)
	if ($list_taglist[3]) { # name of the tags
		$config_elements{$list_taglist[3]} =~ s/^\s+|\s+$//g;
		@list_item_name = split( /\s+/ , $config_elements{$list_taglist[3]} ); # space-separated
	}
	if ($list_taglist[4]) { # order of the tag to be executed
		$config_elements{$list_taglist[4]} =~ s/^\s+|\s+$//g;
		@list_item_exec = split( /\s+/ , $config_elements{$list_taglist[4]} ); # space-separated
		@list_item_exec = grep { $_ =~ /^[+-]?\d+$/ } @list_item_exec; # integer only
		foreach my $i (@list_item_exec) {
			if ($i > $#list_item_name || $i <= 0) { # must be in range
				message_exit ("Config-Error: entry for execution order is wrong ($i)." , 51 );
			}
		}
	}
	@list_column_name = split(/\s+/, $config_elements{$dialog_taglist[3]}) if $dialog_taglist[3];
		@list_column_name = map { s/$cancel_option/ /g; $_ } @list_column_name; # ??? evtl. special replcer sub; $cancel soll halr weg

    # Get identifier from the list elements in config (keep '/')
    @list_id = get_xml_array_by_attribute ($dom , '/'.$config_elements{'list_label'} , 'id' ); 
    message_exit ( "The configuration file \n'$_script_metadata{script_configfile}'\n is missing data.", 44) if (scalar(@list_id) == 0);

    # Get all list elements in config
    # Check for empty entries & replace placeholder (as defined in config)
    my $item_field = 0;
    my $num_options = 0;

    foreach my $item (@list_item_name) {
        foreach my $item_id (@list_id) {
			my $found_xml_value;
            $found_xml_value = get_xml_text_by_tag ($dom, $item, $config_elements{'list_label'}, $item_id );
            if ($found_xml_value) { 
				$found_xml_value = replace_strg ($found_xml_value); # clean/replace as defind
                $list_item_line[$item_id][$item_field] = $found_xml_value; # put into line
            }
            ++$num_options if ($found_xml_value ne '' ) ; ;
        }
        ++$item_field; # tag for tag
    };

    # Check if the number of entries corresponds with id times id-elements (well filled / no lacks in config)
    message_test_exit ( ( $num_options - scalar @list_id * scalar @list_item_name ) , "The configuration file \n'$_script_metadata{script_configfile}'\n is not well-filled with data or tags are empty." , 46);

    # End of reading config
    if ($start_selection) { print "(t) cmdNr->$start_selection<\n" if $is_test_mode }
    message_notification ("Reading configuration file is done!" , 1);

    return 0;
};

#read_configuration ('/home/stefan/prog/bakki/cscrippy/config_N1005.xml');
read_configuration ('/home/stefan/prog/bakki/cscrippy/config_offN1006.xml'); # ??? wirklich sub? was ist mit cmd-line?

# Init Dialogs
# Set elements for list-dialog
my $addendum = "\n\t\t(processed with '$_script_metadata{script_name} $_script_metadata{version}')"; # ??? unsauber 
set_dialog_item ( 'titles' , $config_elements{dialog_title}, $config_elements{dialog_menue}.$addendum, $config_elements{dialog_column1}); 
set_dialog_item ( 'columns' , $list_column_name[0] , $list_column_name[1] , $list_column_name[2] );
set_dialog_item ( 'window_size' , 350 , 500 , '' );

# Set elements for the listed items (for checklist)
add_items_from_config ( 0 , \@prog_taglist , \@{$_dialog_config{list}} );
add_items_from_config ( 0 , \@config_taglist , \@{$_dialog_config{list}} );
foreach my $i (0 .. $#list_id) {
	push @{$_dialog_config{list}}, add_list_item ( 0 , $list_id[$i] , $list_item_line[$list_id[$i]][0] );
}
@{$_dialog_config{list}} = sort_pairwise ( @{$_dialog_config{list}});;

# Check for double entries
my @duplicates = find_array_duplicates (@{$_dialog_config{list}});
message_test_exit ( 
	scalar (@duplicates) , 
	"The configuration file \n'$_script_metadata{script_configfile}'\n contains at least one wrong double identifier." , 
	45
	);

# Checking command-number if given & defined
if ($start_selection) {
    if ( @list_id && grep { $_ eq $start_selection } @list_id) {
       @selection = $start_selection;
    } else {
        message_exit (
			"Error with commandline: Case '$start_selection' not defined." , 
			66
		);
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

# fehlt noch testin cmdNr ???
if ($is_test_mode) {
    say "\n(t) The choice was made:";
    say "(t) ".join (' ', @selection);
    
    #for my $i (0 .. $#selection) {
        #say "(t) \t$selection[$i]";
        #for my $j (0 .. $#list_item_name) {
		  #if ( $selection[$i]  ~~ @list_id ) {
	
            #say "$j>".$list_item_line[$selection[$i]][$j]."<" if ($selection[$i] < 100) ;
          #};
        #}
    #}
};

# Goin for exec :)


# grepping all selected program-name into list-of-programs to be executed
my   @combined_config_elements = map { %config_elements{$_} } grep { !/^DEF/ } ( @prog_taglist , @config_taglist);
@combined_config_elements = ( join(' ', @combined_config_elements) ); # all into [0]
foreach my $case (0 .. $#selection) {
	if ( $selection[$case] ~~ @list_id ) {
		push @list_of_programs_to_execute , extract_commandline ( $list_item_line[$selection[$case]] )
    } elsif ( $combined_config_elements[0] =~ /$selection[$case]/) {
		push @list_of_programs_to_execute , extract_progname ($selection[$case] , @prog_taglist);
		push @list_of_programs_to_execute , extract_progname ($selection[$case] , @config_taglist);
	} else {
		die "Config-Error: selected item '$selection[$case]' not found.";
	}
}

say "#########";
say "\nlist_of_programs_to_executeS";
print Dumper @list_of_programs_to_execute;
say "\n";

## tiny? fork statt &
#if (@list_of_programs_to_execute)  {
	#for my $cmd_to_execute (@list_of_programs_to_execute) {
		#say $cmd_to_execute;
		#eval {
			#system($cmd_to_execute." &" );  
        #if ($@) {
        #warn ("Failed to pdsadse???  file: $@", 255);
		#}
		#}
	#}
#}
die "nicht exec";
if (@list_of_programs_to_execute) {
    for my $cmd_to_execute (@list_of_programs_to_execute) {
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
# done :)

# ideen:
#  - Ausgabe aller items als check

###"Config-Error: selected item '$selection[$case]' not found."
#: final test ausgabe ::#
show_all_items () if $is_test_mode > 10;


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

# Replace in string substr using global hash _rep
#
sub replace_strg { 
	my $working_strg = shift;
	
	# Replace ~ with ENV-value
	sub replace_homedir {
		my $home_dir = $ENV{HOME} // $config_elements{$dir_taglist[1]};  # ??? hard coding dir_tag?
		my $home_path = shift;
		if (defined $home_dir) {
			$home_path =~ s/~/$home_dir/g;
		} else {
			# Handle the case where $home_dir is not defined
			warn "Unable to replace '~' placeholder: HOME environment variable and config value for '$dir_taglist[1]' are not set.";
		}

		return $home_path;
	}

	if ($working_strg) {
		foreach my $key (keys %_rep ) {	
			my $value = $_rep{$key};
			if ( $is_test_mode > 10 && $working_strg =~ /\$$key/ ) { # testmode
				say "Repl '$value' for '\$$key' in ->".$working_strg;
			};
		$working_strg =~ s/\$$key/$value/g ;
		}
		if ($working_strg =~ /~/) {
			$working_strg = replace_homedir ($working_strg);
		};
	}
				
	return $working_strg;
};

# Getting the string @tag
# option: within @attr_tag with attribute (leave empty if not desired)
#
sub get_xml_text_by_tag {
    my ($doc, $tag , $attr_tag, $attr ) = @_;
    my @nodes;
    my $element_text;
    
    warn "Error: Invalid XML document object" unless ref($doc) eq 'XML::LibXML::Document';
    warn "Error: Tag name cannot be empty" unless defined($tag) && length($tag) > 0;

    $tag = "/$tag"; $tag =~ s{^/+}{//};
    if (defined $attr_tag) {
        $attr_tag = "/$attr_tag"; $attr_tag =~ s{^/+}{//};
        };

    # Find tag-literal with xpath from @nodes
    my $xpath = $attr_tag ? '*'.$attr_tag.'[@id="'.$attr.'"]'.$tag : "*$tag";
    eval { @nodes = $doc->findnodes($xpath) };
    if ($@) {
		message_exit ("Error while searching element in xml-file\n$@" , 255);
    };
    if (@nodes) {
        $element_text = join('', map { $_->to_literal() } @nodes);
    } else {
        message_exit ("Error: No nodes found for tag '$xpath'" , 255 );
    }

    return $element_text;
}

# Get the array @tag of all attributes
#
#
sub get_xml_array_by_attribute {
    my ($doc, $tag, $attr) = @_;

    warn "Error: Invalid XML document object" unless ref($doc) eq 'XML::LibXML::Document';
    warn "Error: Tag name cannot be empty ($tag)" unless defined($tag) && length($tag) > 0;
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

# Push check & the item 1,2 into dialog-list 
sub add_items_from_config {
    my ($checker, $items, $list_ref ) = @_;
    if (scalar @$items < 2) { 
		die "Not enough items to add from config";
    }
    #
    my @result = add_list_item( 
					$checker , # 0 for off. >=1 for on
					$config_elements{@$items[1]} , # id
					$config_elements{@$items[2]}   # array !
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

# Get the commandline from item 
sub extract_commandline {
	my (@tag_list ) = @_;
	my $program_name = "";

	foreach my $schema_item (@list_item_exec) {
		$program_name .= $tag_list[0][$schema_item];
	}
	return $program_name;
}

# Get the prog-name from item
sub extract_progname {
	my ($selector , @tag_list) = @_;
	my @program_name;

	for my $j (@tag_list) {
		for my $k (@tag_list) {
			if ($config_elements{$j} && $j =~ /_id/ && $config_elements{$j} eq $selector && $k =~ /_program/) {
#say $j."::$k<===>$config_elements{$j}###".$config_elements{$k};
				push @program_name , $config_elements{$k};
				}
			}
		}

	return @program_name;
}

# for debugging
sub show_all_items {
# use Dmper ??? in final version
	say "\nEingelesene Daten";
	
	say "\n#:items: ($#list_id+) #\n";
	print Dumper @list_id;
	say "";
	print Dumper @list_item_name;
	
	say ("\nlist items");
	for my $i (0 .. $#list_id) {
		my $st = join("\t", @{$list_item_line[$list_id[$i]]});
		say "Nr.-".$list_id[$i]."<->\t".$st;
	}

	say "\n all replacer";
	print Dumper %_rep;

	say "\n all tags";
	for my $run (0..$#all_taglist) { 
		say "$run :$all_taglist[$run]:\t\t\t:$all_tagdefault[$run]:";
	}

	say "\n configs";
	print Dumper %_script_metadata;
	say "";
	print Dumper %config_elements;
	say "End:::";
}

__END__
#### junk ???

# Uncomment to print the hashes
 use Data::Dumper;
 #print Dumper(\%config_elements);
 #print Dumper(\%config_std);

 print Dumper(\%_script_metadata);
 #print "Messenger Top Text: $messenger_top_text\n";


$is_test_mode = 0;

@{$_dialog_config{titles}} = set_dialog_item ('titles' , 'Program DoIt', 'Choose your items','#');

printf "####\n";
foreach my $key (keys %_dialog_config) {
    printf "$key is >". join ('/',@{ _dialog_config{$key} })."<\n";
};

message_exit ("Hääh", 33);

message_exit ("Und der??", 34);
__END__

#te list items  anzeigen
for my $i (0 .. $#list_id) {
    my $st = join('   ', @{$list_item_line[$list_id[$i]]});
    say "5-".$list_id[$i]."<->\t\t".$st;
};
 ## say "5a-".$list_item_line[0][1];

##te
if (find_duplicates(@list_id)) {
    my $sc = scalar (find_duplicates(@list_id));
    message_test_exit ( $sc , "The configuration file \n'$_script_metadata{script_configfile}'\n contains at least one wrong double identifier." , 45);
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

kw ai-verion nicht übernommen
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

#say "##############<<!";
 ## print Dumper %config_elements;
#for my $run (0..$#all_taglist) {
	#say "$run :$all_taglist[$run]:-<$config_elements{$all_taglist[$run]}>-:$all_tagdefault[$run]:";
#}
#say join ('. ', @list_item_name);
#say join ('. ', @list_column_name);

#say "\n$selecter";
#print Dumper @tag_list; 
#for my $i (@schema) {
	#for my $k (0..$#list_item_name) {
		#if ($i == $k) {
			#$progname = $progname." ".@{$tag_list[0]}[$k];
		#}
	#}
#}
	#return $progname;# if defined;
#}
