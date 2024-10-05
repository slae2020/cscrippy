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

###############################
# Declarations for Bakki only #
###############################

# Define filling for config-xml-file <attribution></attribution>
# [nn]='attribution|standard-value'
# '\.' for empty attrib.
my @diris = qw ( dir_to_replace  home_dir  storage_dir standard_dir remote_dir); # asubauen mit den anderen ??? const?

my @attribution = ( # ??? iwie einlesen
    'space',

    # general
    'version1',
    'version2',
    'lang|de-DE',

    # for dialogues dialog_cfg
    'dialog_title',
    'dialog_menue',
    'dialog_column1',
    'dialog_config',
#    '\.',  noch nötig ???
#    '\.',

    # directories
    $diris[1].'|' . $ENV{HOME},
    $diris[2],
    $diris[3],
    $diris[4].'|', 
#    '\.',
#    '\.',

	# list_cfg # progs for setting & main
	'list_head',
	'list_label',
	'list_items',
#    '\.',
#    '\.',

	'list_config_strg',
	'list_editor_prog',
	'list_prog_strg',
	
    'std_program|soffice',
    'name_stdprg|Office',
    'editor_program|gedit',
#    '\.',
#    '\.',
	
);

# Define parameter of sync-group-elements
# ??? bakki oder offi aus cofg ziehen
my @list_objects; 			# n x m array for n list-items with m fields each
my @list_id = (); 		# n list ids 'integers!'
my @list_item = ('name'); 	# m fieldnames of the columns


#my @id;

#my $num_elements = 3;
#my @opti1 = ("name");
#my @opti2 = ("dir1");
#my @opti3 = ("dir2");
#my @opti4 = ("" );
#my @opti5 = ("" );
#my @opti6 = ("" );
#my @opti7 = ("" );

# Workparameters
my $cmdNr = 0; 
my $selection = "";
my $selectedIndex = "";

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
## Define general parameters for config-file
my %script_metadata_;
# dir    	=> Directory of the script
# name     	=> Name of the script without extension
# config  	=> Predefined config name
my $config_stdname = exists $ENV{MY_CONFIG_FILE} && -e $ENV{MY_CONFIG_FILE} ? $ENV{MY_CONFIG_FILE} : "config.xml"; # ??? Test MY_CON`
($script_metadata_{name},$script_metadata_{dir},$script_metadata_{suffix}) = fileparse(abs_path($0), qw (.sh .pl) );
$script_metadata_{config} = $config_stdname;

# Init messenger
@{$_dialog_config{titles}} = set_dialog_item ('titles' , uc($script_metadata_{name})." V".$VERSION, '', '');

# Necessary check
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

    # Start
    message_notification("Reading configuration file \n\n$script_metadata_{config}.", 1);

	# Init XML file
	eval {
		$dom = XML::LibXML->load_xml(location => $script_metadata_{config}, no_blanks => 1*0); # <>0 heisst string ohne space \n etc.
	};
	if ($@) {
		message_exit ("Failed to parse XML file: $@", 255);
	};

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
		}
    }

#say "#:cfgK:#"; print Dumper %config_elements;
    # Get special config values Listenelemente
	@list_id = get_xml_attr_array ($dom , '/ordpaar' , 'id' );  # ??? ord paar einlesen 
	message_test_exit (1 , "Missing data: Config-file '$script_metadata_{config}' has no list-item.", 44) if (scalar(@list_id) == 0);

#my $num_items = scalar @list_item; 
#my $num_ids = scalar @list_id;
#say "id:$num_ids<--it>$num_items";
#my @ersatz = get_xml_element_text ($dom , 'directories' );
#say "ERS>@ersatz<";

	my $i = 0;
	my $num_options = 0;
	foreach my $item (@list_item) {
		foreach my $item_id (@list_id) {
			my $text = get_xml_element_text ($dom, $item, 'ordpaar', $item_id );
			
			foreach my $rep (@diris) {
				if ($rep eq $diris[0]) { 
					$text =~ s/~/$config_elements{$diris[1]}/g; # diris 1 muss home-dir sein
				} else {
					$text =~ s/\$$rep/$config_elements{$rep}/g;
				}
			}
			if (defined $text && length($text) > 0) {
				$text =~ s/$is_cancel/ /g ; # ??? testen wenn nnötig
				$text =~ s/\$empty/ /g ;
				$list_objects[$item_id][$i] = $text; 
			}
			++$num_options if ($text ne '' ) ; ;
		}
		++$i;
	};

	message_test_exit ( ( $num_options - scalar @list_id * scalar @list_item ) , 
		"Missing data: Config-file 'cfg_name' is not well-filled." , 45);                     
	
    # End
    #done_configuration($config_name);
    print "(t) File $script_metadata_{config} cmdNr-->$cmdNr<\n" if $is_test_mode > 0;
	message_notification("Reading configuration file done!", 1);

    say "(t) $script_metadata_{config}\n" ;#if $is_test_mode > 0;
    
    return 0;
};

read_configuration ('/home/stefan/prog/bakki/cscrippy/config_N1005.xml');

# Init Dialogs

@{$_dialog_config{titles}} = set_dialog_item ( 'titles' ,$config_elements{dialog_title}, $config_elements{dialog_menue} , $config_elements{dialog_column1}); 
@{$_dialog_config{columns}} = set_dialog_item ( 'columns' , '[@]', 'Id', 'Item');

push @{$_dialog_config{list}}, add_list_item (1,'01','first choice'); 
push @{$_dialog_config{list}}, add_list_item (0,'02','secondbest');

# Loop until a selection is made
my @answer=ask_to_choose (%_dialog_config);
printf ">%s<\n",$_ for @answer;

#while [ -z "$selection" ]; do
    #setdisplay 350 450
    #selection=$(ask_to_choose "${config_elements[dialog_title]}" "${config_elements[dialog_menue]}" "${config_elements[dialog_column1]}"\
                #opti1 "${config_elements[name_stdprg]}" "${config_elements[dialog_config]}")
    #if [[ $selection == $is_cancel ]]; then
        #message_exit "Dialog canceled by user." 0
        #exit
    #fi
#done

# .... ???

#: final test ausgabe ::#

say "#:cfg:#"; print Dumper %config_elements;

say "#:items:#";
#te list items  anzeigen
for my $i (0 .. $#list_id) {
    my $st = join('   ', @{$list_objects[$list_id[$i]]});
    say "5-".$list_id[$i]."<->\t\t".$st;
};
say "5a-\t\t".$list_objects[2][0];
#say "5a-\t\t".$list_objects[5][0];  'double prise id???


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

