#!/usr/bin/perl -w
#use XML::Simple;
#xml-test
use 5.010;
use strict;
use warnings;

use XML::LibXML;

use Data::Dumper; # nur für test ausgaben

my $filename = '/home/stefan/prog/bakki/cscrippy/config_N1005.xml';

#::: Main program ::::::::::::::#

# Parse the XML file
my $dom;

eval {
    $dom = XML::LibXML->load_xml(location => $filename, no_blanks => 1*0); # <>0 heisst string ohne space \n etc.
};
if ($@) {
    die "Failed to parse XML file: $@"; #??? mess exiit
}

say "#:: Start ::#";

# Obertitel / Node
my $configfile_type = $dom->documentElement;
say '$configfile_type is a ', ref($configfile_type);
say '$configfile_type->nodeName is: ', $configfile_type->nodeName;

# Hauotuntertitel/ nodes
my @elements = grep { $_->nodeType == XML_ELEMENT_NODE } $configfile_type->childNodes;
my $count = @elements;
say "\$configfile_type has $count child elements:";

my $header = get_xml_element_text ($dom , '/dialog_cfg/menue_strg' );
say "1-header>$header<";

my @opaar = get_xml_element_text ($dom , '/ordpaar' );
 # say "2-opaar>@opaar<";

my @identifier = get_xml_attr_array ($dom , '/ordpaar' , 'id' ); 
say "3-list id>@identifier<";
say "3a-".$identifier[0];


my $xml_element_text = get_xml_element_text($dom, 'list_items');
my @kinder = sort split(/\s+/, $xml_element_text);
say "4-kind>@kinder<";

my @list_objects;
$list_objects[0][0] = 'nil';
my $i = 0;
foreach my $kk (@kinder) {
	foreach my $ii (@identifier) {
		my $tt = get_xml_element_text ($dom, $kk, 'ordpaar', $ii );
		$list_objects[$ii][$i] = $tt; 
		#say "id:$ii:--k$kk>$i<...:$tt:";
	}
	++$i;
};


for my $i (0 .. $#identifier) {
    my $st = join('   ', @{$list_objects[$identifier[$i]]});
    say "5-".$identifier[$i]."<->".$st;
};
say "5a-".$list_objects[0][1];



#::: subs ::::::::::::::::::::::#

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
    my $xpath_strg = "*/$tag"."/\@$attr"; 
    my @nodes = $doc->findnodes($xpath_strg);

	# Extract literal values from @nodes
	my @literals = map { $_->to_literal } @nodes;

	# Filter @literals to only include integer values
	my @integers = grep { $_ =~ /^[+-]?\d+$/ } @literals;

	# Return the array of integer values
	return @integers;
}


#::: extras :#

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

__END__

+++ junk
sub get_xml_array_attr2 {
    my ($doc, $tag , $attr) = @_;
   
    my @element_text;
    my $xpath_strg = "*/$tag"."/\@$attr";

    my @nodes = $doc->findnodes($xpath_strg);
    if (@nodes) {
        #$element_text = join('', map { $_->to_literal() } @nodes);
#my $r = join('', map { $_->to_literal() } @nodes);    
#my $r = @nodes[1]->to_literal();
#say ("##".$r.'##');
#say (@nodes[0]);
		foreach my $elem (@nodes) {
			push ( @element_text , $elem->to_literal );
		}
    } else {
        warn "Error: No nodes found for tag '$xpath_strg'";
    }

    return @element_text;
}


#    $tag = $attr_tag.'[@id="'.$attr.'"]/'.$tag unless !defined($attr);
#    $tag = "*$tag";
