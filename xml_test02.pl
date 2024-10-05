#!/usr/bin/perl -w
#use XML::Simple;
#xml-test
use 5.010;
use strict;
use warnings;
#my $data = XMLin("/home/stefan/perl/Bakki-the-stickv1.2beta/config_2408.xml");


use XML::LibXML;

my $filename = '/home/stefan/perl/Bakki-the-stickv1.2beta/config_2408.xml';

### ask


# Function to convert XML nodes to a hash
sub xml_to_hash {
    my ($node) = @_;
    my %hash;

    # Loop through child nodes
    foreach my $child ($node->childNodes) {
        if ($child->nodeType == XML::LibXML::XML_ELEMENT_NODE) {
            my $name = $child->nodeName;
            my $content = $child->textContent;
            

            # Recursively handle child elements
            if ($child->hasChildNodes) {
                $hash{$name} = xml_to_hash($child);
            } else {
                #$hash{$name} = $content;
                $hash{$content} = '??!';
            }
        } elsif ($child->nodeType == XML::LibXML::XML_TEXT_NODE) {
            my $content = $child->textContent;
            
            if ($content =~ /\S/) { # Check if the text node is not empty
                #$hash{'_text'} = $content;
 # say "CCC> $content ".check_variable($content);                 
 # say "HHH>".check_variable(%hash);
               
                $hash{$content} = undef;
            }
        }
    }
    return \%hash;
};



# Main program
my $file = 'config.xml';
my $parser = XML::LibXML->new();

# Parse the XML file
my $doc;
eval {
    $doc = $parser->parse_file($filename);
};
if ($@) {
    die "Failed to parse XML file: $@";
}

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


 

### +
# Convert the document to a hash
#my $hash_ref = xml_to_hash($doc->documentElement);


#.
# Find the specific node 'mynode'
sub get_node_as_hash {
    my ($node_name2, $doc2) = @_;
    my @mynode2 = $doc2->findnodes("//$node_name2");
    
    my %hash_ref2;
    
    if (@mynode2) {
        %hash_ref2 = %{xml_to_hash(@mynode2)};
    } else {
        warn "Node '$node_name2' not found in the XML file.";
        undef %hash_ref2;
    }
    return \%hash_ref2;
};

my $node_name = 'general';
my ($mynode) = $doc->findnodes("//$node_name");
#say "1111111???>$mynode<????";
#say "mynode>".check_variable($mynode);
if ($mynode) {
    # Convert the found node to a hash
    #my $hash_ref = xml_to_hash($mynode);
    
    # Convert the 'mynode' node to a hash
    #my %hash_refN = map { $_ => $node_name->findvalue("./$_") } map { $_->nodeName } $node_name->childNodes;
    my @nodes = $mynode->findnodes('./*');
	my %hash_refN = map { $_->nodeName => $_->textContent } @nodes;

    
    
 # say "hash_refN>".check_variable(%hash_refN);
    
    # Print the resulting hash
    print Dumper(\%hash_refN);
} else {
    warn "Node '$node_name' not found in the XML file.";
};

#say ("neeu");




#my $nodeHash = get_node_as_hash('general', $doc);
#if (keys %$nodeHash) {
    #foreach my $key (keys %$nodeHash) {
		#my $content = $nodeHash->{$key}->{'_text'};
        #say "Key: $key \t\tContent:$content:";
    #}
#} else {
    #warn "No nodes found.";
#}

#my $hash_ref = get_node_as_hash('general', $doc);
#say "TThash_ref>".check_variable($hash_ref);
#if (keys %$hash_ref) {
    #foreach my $kk (keys %$hash_ref) {
		##my $rr = %$hash_ref=>$kk;
		#my $rr = $hash_ref->{$kk}->{'_text'};
		#say "RR>".check_variable($rr);
		#say "§§§>".$kk."<   :".$rr.":";
		##foreach my $newk (keys %$rr) {
		##	say $newk;
		##	};
		#};
#}
#.

# Print the resulting hash
use Data::Dumper;
#print Dumper($nodeHash);

say "fertig";

###ask
my $dom = XML::LibXML->load_xml(location => $filename, no_blanks => 1*0); # <>0 heisst string ohne space \n etc.

# Obertitel / Node
my $configfile_type = $dom->documentElement;
say '$configfile_type is a ', ref($configfile_type);
say '$configfile_type->nodeName is: ', $configfile_type->nodeName;

# Hauotuntertitel/ nodes
my @elements = grep { $_->nodeType == XML_ELEMENT_NODE } $configfile_type->childNodes;
my $count = @elements;
say "\$configfile_type has $count child elements:";
my $i = 0;
foreach my $child (@elements) {
    say $i++, ": is a ", ref($child), ', name = ', $child->nodeName;
}




## Assuming $dom is an XML::LibXML::Document object
#my $ordpaarNodes = $dom->findnodes('//ordpaar');
#if ($ordpaarNodes->size() > 0) {
    #my $ordpaarNode = $ordpaarNodes->get_node(2);
    #my $ordpaarText = $ordpaarNode->findvalue('.');

    #say 'Ordpaar text: ', $ordpaarText;
    #say 'Ordpaar node type: ', ref($ordpaarNode);
#} else {
    #say 'No ordpaar nodes found in the XML document.';
#}

##say "DOM as a string:\n", $dom; if testversion?

#my @inhalt;
#foreach my $title ($dom->findnodes('//ordpaar')) {
	#push @inhalt , $title->to_literal();
##    say $title->to_literal()."...";
#}

#config_ref["$name_element"]=$(xml_grep "$name_element" "${script_[config]}" --text_only 2>/dev/null)
say "#################";

#printf $inhalt[0];

#say @inhalt;

my $resultat = "nil";
#$resultat=$(xml_grep "$name_element" "${script_[config]}" --text_only 2>/dev/null)

printf "\n>$resultat\n";
say "yes\n"
__END__

http://grantm.github.io/perl-libxml-by-example/basics.html#parsing-errors
