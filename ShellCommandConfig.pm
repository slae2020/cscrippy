package ShellCommandConfig {
    use strict;
    use warnings;

    sub new {
        my $class = shift;
        my %args = @_;

        # Validate input arguments
        die "Missing 'commandline' argument" unless exists $args{commandline};
        die "Missing 'selection' argument" unless exists $args{selection};
        die "Missing 'execution_list' argument" unless exists $args{execution_list};
        die "Missing 'execution_order' argument" unless exists $args{execution_order};

        my $self = {
            commandline => $args{commandline},
            selection => $args{selection},
            execution_list => $args{execution_list},
            execution_order => $args{execution_order},
        };

        bless $self, $class;
        return $self;
    }

    sub number_of_elements_selection {
        my $self = shift;
        return scalar @{$self->{selection}};
    }
}

# Usage example
my $shell_command_config = ShellCommandConfig->new(
    commandline => [],
    selection => [4, 27, 35],
    execution_list => [],
    execution_order => [4, 1, 2],
);

my $num_selected = $shell_command_config->number_of_elements_selection();
