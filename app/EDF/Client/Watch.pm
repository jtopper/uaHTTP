package EDF::Client::Watch;

use strict;

###

sub add {

my($object, $name, $value, $code) = @_;

return unless (defined($code));

$name  = "" unless (defined($name));
$value = "" unless (defined($value));

$object->{$name}->{$value} = $code;

}

###

sub delete {

my($object, $name, $value) = @_;

$name  = "" unless (defined($name));
$value = "" unless (defined($value));

delete $object->{$name}->{$value};

}

###

sub new {

my $object = shift;

my $class = ref($object) || $object;

my $self = { "" => { "" => sub { ; } } };

bless($self, $class);

$self->add(@_) if (@_);

return $self;

}

###

sub process {

my($object, $edf) = @_;

my($name, $value) = $edf->each;

my $code = $object->{$name}->{$value} ||
           $object->{$name}->{""}     ||
           $object->{""}->{$value}    ||
           $object->{""}->{""};

&$code($edf) if $code;

}

###

###
1;
