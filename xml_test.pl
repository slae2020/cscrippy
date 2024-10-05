#!/usr/bin/perl -w
#use XML::Simple;
#xml-test
use 5.010;
use strict;
use warnings;

use XML::LibXML;

use Data::Dumper; # nur für test ausgaben

my $filename = '/home/stefan/perl/Bakki-the-stickv1.2beta/config_2408.xml';

# Main program


# Parse the XML file
my $dom;
eval {
    $dom = XML::LibXML->load_xml(location => $filename, no_blanks => 1*0); # <>0 heisst string ohne space \n etc.
};
if ($@) {
    die "Failed to parse XML file: $@"; #??? mess exiit
}

######
#sub find_child_generations { #kw ???
    #my ($node) = @_;
    
    ## Base case: if the node has no children, return 0
    #return 0 unless $node->hasChildNodes;

    #my $max_depth = 0;

    ## Iterate over each child node
    #foreach my $child ($node->childNodes) {
        ## Recursively find the depth of this child
        #my $child_depth = find_child_generations($child);
        ## Update the maximum depth found
        #$max_depth = $child_depth if $child_depth > $max_depth;
    #}

    ## Return the maximum depth + 1 (for the current generation)
    #return $max_depth + 1;
#}

sub get_max_depth {
    my ($node) = @_;
    return 0 unless defined $node && $node->hasChildNodes;

    my $max_child_depth = 0;
    eval {
        for my $child ($node->childNodes) {
            my $child_depth = get_max_depth($child);
            $max_child_depth = $child_depth if $child_depth > $max_child_depth;
        }
    };
    if ($@) {
        warn "Error while processing node: $@";
        return 0;
    }

    return $max_child_depth + 1;
}


# Find the number of generations starting from the root node
#my $generations = find_child_generations($dom->documentElement);
 # my $generations = get_max_depth($dom->documentElement);
 # print "Number of child generations: $generations\n";

######

say "#:: Start ::#";

# Obertitel / Node
my $configfile_type = $dom->documentElement;
say '$configfile_type is a ', ref($configfile_type);
say '$configfile_type->nodeName is: ', $configfile_type->nodeName;

# Hauotuntertitel/ nodes
my @elements = grep { $_->nodeType == XML_ELEMENT_NODE } $configfile_type->childNodes;
my $count = @elements;
say "\$configfile_type has $count child elements:";


say "#:: cfg lesen ::#";

my %config_objects;
for my $child (@elements) {
#say ">".uc($child->nodeName);
	#%zz = (%zz, %{get_nodes ($dom,$child,$child->nodeName,2)});
	if ( get_max_depth($child) <= 2 ) {
		eval {
			%config_objects = ( %config_objects , %{get_node_as_hash ($child->nodeName, $dom)} );
		} or do {
			my $error = $@;
			# Handle the error, e.g., log it or display a user-friendly message  # ??? message
			warn "Error retrieving node hash ($child->nodeName): $error";
		};
	};
};

# Function to recursively convert XML elements to hash
sub xml_to_hash {
  my $element = shift;
  my %hash;


  ## Add attributes to the hash
  #for my $attr (sort keys %{$element->attributes}) {
    #$hash{$attr} = $element->getAttribute($attr);
  #}

my $text_content = $element->textContent;
my $node_name = $element->nodeName;

  # Add text content to the hash
  if ($text_content) {
    $hash{$element->nodeName} = $element->textContent;
      
    # Check if the text content is not empty
    if ($text_content =~ /\S/) {
        $hash{$node_name} = $text_content;
    } 
  };

  # Recursively process child elements
  for my $child ($element->childNodes) {
    if ($child->nodeType == XML::LibXML::XML_ELEMENT_NODE) {
      $hash{$child->nodeName} = xml_to_hash($child);    
      #push @{ $hash{$child->nodeName} }, xml_to_hash($child);
    } 
  }
 

  return \%hash;
}


sub retrieve_datasets {
    my ($xml_file, $label) = @_;
    my %datasets;

    ## Initialize the XML parser
    #my $parser = XML::LibXML->new();

    ## Parse the XML file
    #my $doc = eval { $parser->parse_file($xml_file) };
    #if ($@) {
        #die "Failed to parse XML file: $@";
    #}

    # Find all datasets with the specified label
    my $xpath = "//$label";
    my $dataset_nodes = $dom->findnodes($xpath);

#print Dumper $dataset_nodes;

my %newL;
    foreach my $dataset_node ($dataset_nodes->get_nodelist) {
        #my $id = $dataset_node->findvalue('./id');
        my $id = $dataset_node->textContent;
#say  $dataset_node->textContent;
my $parentnode = $dataset_node->parentNode;
 # say $parentnode."\n<-->".check_variable($parentnode);

my $lll = $parentnode->getElementsByTagName('*');

say "§§§".$id;
#print Dumper $lll;
#say 'lll is a ', ref($lll);
#say 'nodeName', $lll->nodeName;

#my $newL = xml_to_hash ($parentnode);
my $newL = xml_to_hash ($dataset_node);
 # print Dumper $newL;
  
  say ":::"."@{[%newL]}";

#my %stst = %{get_node_as_hash ('ordpaar', $parentnode)};
 # my %stst = %{get_node_as_hash ('ordpaar', $parentnode)};
#say %stst;

        #my @strings = map { $_->textContent } $dataset_node->findnodes('./string');
        #my @strings = map { $_->textContent } $dataset_node->parentNode;
		
		#foreach my $strg_node ($parentnode->findnotes("./*")) {
			#say $strg_node;
		#};
		
        #push @datasets, {
         #   $label => $id,
            #strings => \@strings
    #        strings => \@lll

      #  };    
        #%datasets = ( %datasets , $label => $id );   
        #%datasets = ( %datasets , xml_to_hash ($dataset_node) );   
        $datasets{$id} = $newL;
        
        #push @datasets, %{$_} for @datasets, %{$newL}; 
        say "::>>>"."@{[%datasets]}";
    }
	#return \%newL;
    return \%datasets;  # Return reference to the hash
}

# Example usage

my %l_obj= ( 'aaa'=>'bbb');
my $label = 'id';
#$result = retrieve_datasets($filename, $label);
%l_obj = ( %l_obj, %{retrieve_datasets($filename, 'id')} );
%l_obj = ( %l_obj, %{retrieve_datasets($filename, 'dir1')} );

say ":#:";
#print Dumper($result);  # Print the result for debugging
say "@{[%l_obj]}";

my $datasets = retrieve_datasets($filename, 'dir2');

foreach my $dataset_id (keys %$datasets) {
    my $dataset_info = $datasets->{$dataset_id};
    say "Dataset ID: $dataset_id";
    say "Dataset Info: " . join(', ', map { "$_ => $dataset_info->{$_}" } keys %$dataset_info);
}
print Dumper $datasets;

my %list_objects = (
    12 => {
        'id'   => 12,
        'name' => 'erster Listeneintrag',
        'dir1' => '/zuhause',
        'dir2' => '/woanders',
    },
);
my $list_name = 'vergleiche';
my @id_list;

printf  $list_objects{12}{'name'}."\n";

my %zwoter = (
	3 => {
		'id' => 03,
		'name'=> 'zwoter EIntrag',
		'dir1' => '/zuuhauuuse',
		'dir2' => 'wattendenn ',
	},
);

%list_objects = ( %list_objects , %zwoter );
%list_objects = ( %list_objects , %{get_node_as_hash ($list_name, $dom)} );


say "";
say "cfg #::::::::::#";
#print Dumper \%config_objects;

say "lists #::::::::::#";
print Dumper %list_objects;

#foreach my $k (sort {$a <=> $b} keys %list_objects) {
	#printf $k.":\n";
	#foreach my $k2 (sort keys %{$list_objects{$k}}) {
		#printf  "-->".$k2."<>".$list_objects{$k}{$k2}."\n";
	#};
#};
#printf  $list_objects{03}{'dir2'}."\n";

say "#:: end of listes ::#";
### ask


# Function to convert XML nodes to a hash
#sub xml_to_hash {
    #my ($node) = @_;
    #my %hash;

    ## Loop through child nodes
    #foreach my $child ($node->childNodes) {
        #if ($child->nodeType == XML::LibXML::XML_ELEMENT_NODE) {
            #my $name = $child->nodeName;
            #my $content = $child->textContent;
            

            ## Recursively handle child elements
            #if ($child->hasChildNodes) {
                #$hash{$name} = xml_to_hash($child);
            #} else {
                ##$hash{$name} = $content;
                #$hash{$content} = '??!';
            #}
        #} elsif ($child->nodeType == XML::LibXML::XML_TEXT_NODE) {
            #my $content = $child->textContent;
            
            #if ($content =~ /\S/) { # Check if the text node is not empty
                ##$hash{'_text'} = $content;
 ## say "CCC> $content ".check_variable($content);                 
 ## say "HHH>".check_variable(%hash);
               
                #$hash{$content} = undef;
            #}
        #}
    #}
    #return \%hash;
#};

### +
sub check_variable {
    my $var = shift;

    # Check if the variable is defined
    if (!defined $var) {
        return "The variable is not defined.";
    }

    # Determine the type of the variable
    my $type = ref($var);
    
    if ($type eq '') {
        # The variable is a string (or a scalar)
        return "The variable is a string.";
    } 
    elsif ($type eq 'ARRAY') {
        # The variable is an array reference
        return "The variable is an array.";
    } 
    elsif ($type eq 'HASH') {
        # The variable is a hash reference
        return "The variable is a hash.";
    } 
    else {
        return "The variable is of type: $type.";
    }
}


 # say "doc>".check_variable($doc);

### +
# Convert the document to a hash
#my $hash_ref = xml_to_hash($doc->documentElement);

# Find the specific node 'mynode'

sub get_node_as_hash {
    my ($node_name, $doc3) = @_;
    my ($mynode2) = $doc3->findnodes("//$node_name");

say "bin get nod as hash";
#if ( $node_name = "vergleiche") {
#say uc($node_name).">".$mynode2     ;
say "doc3".check_variable ($doc3);
say "myn2".check_variable ($mynode2);

#my 

#};
    my %hash_ref;

    if ($mynode2) {
		my %hash_ref = map { $_->nodeName => $_->textContent } $mynode2->findnodes('./*');
say "hash ref>".%hash_ref;
say "my2".$mynode2->findnodes('./*');
        return \%hash_ref;
		#my @nodes = $mynode->findnodes('./*');
		#%hash_ref = map { $_->nodeName => $_->textContent } @nodes;
	} else {
		warn "Node '$node_name' not found in the XML file.";
		return {};
	};
	#return \%hash_ref;
};

##################################################
#my %generalNodeHash;
#eval {
    #%generalNodeHash = %{get_node_as_hash('general', $dom)};
#} or do {
    #my $error = $@;
    ## Handle the error, e.g., log it or display a user-friendly message
    #warn "Error retrieving node hash: $error";
#};

### Ansicht
#foreach my $key (keys %generalNodeHash) {
		#my $content = $generalNodeHash{$key};
        #say "Key: $key \t\tContent:$content:";
    #};

#'''#

#say "fertig";




###ask


# hier ....

#config_ref["$name_element"]=$(xml_grep "$name_element" "${script_[config]}" --text_only 2>/dev/null)
say "#################";

#printf $inhalt[0];

#say @inhalt;

my $resultat = "nil";
#$resultat=$(xml_grep "$name_element" "${script_[config]}" --text_only 2>/dev/null)

printf "\n>$resultat\n";
say "#:: Ende ::#"

__END__

http://grantm.github.io/perl-libxml-by-example/basics.html#parsing-errors
