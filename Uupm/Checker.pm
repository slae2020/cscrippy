package Uupm::Checker;
###### :::
use 5.010;
use strict;
use warnings;
use Exporter;
use Cwd qw( abs_path );
use File::Spec;
use lib "/home/stefan/prog/bakki/cscrippy/"; # wg. /Uupm... ???
use Uupm::Dialog;

$VERSION = 'Checker.pm 0.2'; # 2024.09.30

BEGIN {
	our @ISA = qw (Exporter);
our @EXPORT = qw ( 
		ensure_program_available
		ensure_file_existence 
		);
}

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#: Check and ensuring the existence and readabilty of
#:     - path & dir
#:     - file
#:

#::: declarations ::::::::::::::#
# Eher Konstant für check ???
my $dir_usb = "media/"; 
my $dir_mnt = "mnt/";

#::: main ::::::::::::::::::::::#
printf "------------ %s ('%s')------------\n",$0,$VERSION if $is_test_mode;

#@{$dialog_config{titles}} = set_dialog_item ('Program DoIt', 'Choose your items'); ??? austasuschen
#push @{$dialog_config{list}}, add_list_item (0,'03','no choice');
#printf "$Uupm::Dialog::is_cancel<->$Uupm::Dialog::VERSION ";

#message_exit ("Hääh", 33);

#::: subs ::::::::::::::::::::::#
# Function to ensure if a path is readable
sub ensure_path_readability {
    my ($path, $name) = @_;

    my $formatted_path = $path // "   ";
    unless (-r $path) {
        message_exit("Config-Error: Path\n'$formatted_path'\nis missing or not readable.", 21);
    }

    if (index($path, $dir_usb) >= 0) {
        ensure_usb_stick($path);
    } elsif (index($path, $dir_mnt) >= 0) {
        ensure_mount($path);
    }
}

# Function to check if a USB stick is present
sub ensure_usb_stick {
    my ($usb_stick_path, $usb_stick_name) = @_;
    my $max_attempts = 5;
    my $attempt = 0;

    while ($attempt < $max_attempts) {
        if (-d $usb_stick_path) {
            return 1;
        } else {
            ask_to_continue("'$usb_stick_name' is missing: ['$usb_stick_path' not found]\n\nDo you want to try again?", 22);
            $attempt++;
        }
    }
    message_exit ("Failed to find USB stick '$usb_stick_name' after $max_attempts attempts.\n", 22);
    return 0;
}

# Function to ensure if a network drive is mounted, and attempt to mount it if not
sub ensure_mount {
    my ($mounted_path) = @_;
    my $test_subdir = "$mounted_path/.";

    # Check if the mount-directory is accessible
    if (! -r $test_subdir) {
        # Attempt to mount the directory
        my $mount_cmd = "$ENV{HOME}/prog/bakki/mounti/mounter.sh \"$mounted_path\""; # ??? muss direkt implementiert weren issue!
        my $mount_result = system($mount_cmd);
        if ($mount_result != 0) {
            message_exit ("Error: $mount_result", 23);
            exit;
        }
    }
    return 1;
}

# Function to ensure availibility of a program
sub ensure_program_available {
    my ($prog_name) = @_;

    if (system("command -v '$prog_name' > /dev/null 2>&1") != 0) {
        message_exit ("Config-Error: program '$prog_name' not found.\n", 24);
    }
}

# Modify and/or ensure that a file exists and is readable
sub ensure_file_existence {
    my ($file_name) = @_;

    my $file_dir = File::Spec->catdir(abs_path(File::Spec->rel2abs($0)), '..'); # actual path of program

    if ($file_name =~ m{^\.\/}) { # replace . with full path
        $file_name = File::Spec->catdir($file_dir, $file_name);
    }

    ensure_path_readability ($file_name);
    return $file_name;
}

1;
__END__
???
transfer ????
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

# Example usage
my $string = "Hello, World!";
my @array = (1, 2, 3);
my %hash = (key1 => 'value1', key2 => 'value2');
my $undefined;

print check_variable($string), "\n";
print check_variable(\@array), "\n"; # Pass array reference
print check_variable(\%hash), "\n";  # Pass hash reference
print check_variable($undefined), "\n";
 ?????
 

ensure_program_available ("meld");


# Example usage:

ensure_path_readability ("/home/stefan/prog/bakki/cscrippy");
ensure_path_readability ("/media/stefan/SLAE01/slaekim");
ensure_path_readability ("/mnt/iserv_laettig/Files/usr");

ensure_usb_stick "/media/stefan/SLAE01/slaekim", "SLAE01";

ensure_mount "/mnt/iserv_laettig/Files";

ensure_program_available ("meld");

my $answer;
$answer = ensure_file_existence ("README.md");
printf $answer;

**Important Notes:**

* **`ensure_mount`:** The script assumes the `mounter.sh` script is available at the specified location (`$ENV{HOME}/prog/bakki/mounti/mounter.sh`).

__Extra__

# Subroutine to sort an array and find double entries
# ??? -> Checker.pm
sub find_duplicate2 {
    my @array = @_;

    # Sort the array
    #@array = sort { $a <=> $b } @array;

    # Find duplicates
    my %count;
    my @duplicates;
    foreach my $item (@array) {
        $count{$item}++;
        push @duplicates, $item if $count{$item} > 1;
    }

    # Return the list of duplicates
    return @duplicates;
}


1;
